import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/balance/balance_patch.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_registries.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/items_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/revive_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

BattleEngine _engine() => BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99,
    );

BattlePartyMember _member(String id, String classId,
    {int? hp, String? weapon, int esp = 0, int aethers = 0}) {
  final cls = kClasses[classId]!;
  final attrs = PlayerAttributes.base(cls.baseAttributes);
  return BattlePartyMember(
    id: id,
    name: '${cls.name} $id',
    hp: hp,
    mp: 999,
    aethers: aethers,
    build: PlayerBuild(
      classId: classId,
      level: 12,
      attributes: esp == 0
          ? attrs
          : PlayerAttributes({...attrs.values, Attribute.esp: esp}),
      equippedWeapon: kWeapons[weapon ?? cls.startWeaponId]!,
    ),
  );
}

/// Turno de p1 con p2 caído.
BattleState _turn(BattleEngine e, BattlePartyMember p1) {
  final start = e.start(
    party: [p1, _member('p2', 'guerrero', hp: 0)],
    enemyTypes: ['slime'],
    triggeredBy: 'p1',
  );
  final t = e.nextTurn(start.state).state;
  expect(t.currentId, 'p1');
  return t;
}

String _install(Map<String, Object?> overrides) {
  final r = BalancePatch.parse(
      jsonEncode({'schema': 1, 'basedOn': 't', 'overrides': overrides}),
      BalanceBase.standard());
  expect(r.issues.where((i) => i.error), isEmpty, reason: '${r.issues}');
  r.patch.installRegistries();
  return r.patch.hash;
}

void main() {
  tearDown(BalanceRegistries.restore);

  group('armas de soporte de nivel bajo', () {
    test('hay revivir antes del nivel 12, solo en 2 bases raras sin venta', () {
      final revivers = [
        for (final w in GameCatalog.standard.weapons.values)
          if (w.level <= 12 &&
              w.skillIds.any((s) => GameCatalog.standard.skills[s]!.revive > 0))
            w,
      ];
      expect(revivers.map((w) => w.id).toSet(),
          {'maza_escudo_retorno', 'tomo_regreso'});
      for (final w in revivers) {
        expect(w.price, 0, reason: 'no se vende');
        expect(w.dropWeight, lessThan(1), reason: 'sale poco');
      }
      // Eco de Regreso es más débil que Resurrección.
      final eco = GameCatalog.standard.skills['ecoRegreso']!;
      final res = GameCatalog.standard.skills['resurreccion']!;
      expect(eco.revive, lessThan(res.revive));
    });

    test('Paladín y Maga tienen apoyo antes del nivel 7', () {
      final ids = GameCatalog.standard.weapons.keys;
      expect(ids, containsAll(['baculo_rocio', 'maza_escudo_vigilia', 'arco_alivio']));
      expect(kWeapons['maza_escudo_vigilia']!.level, 5);
    });
  });

  group('sinergia de revivir (ReviveRules)', () {
    test('ESP y Curación suben la vida, con tope 100%', () {
      expect(ReviveRules.lifeFraction(0.25, esp: 0, healBonus: 0), 0.25);
      expect(ReviveRules.lifeFraction(0.25, esp: 20, healBonus: 0),
          closeTo(0.31, 1e-9));
      expect(ReviveRules.lifeFraction(0.25, esp: 40, healBonus: 0.2),
          closeTo(0.47, 1e-9));
      expect(ReviveRules.lifeFraction(0.7, esp: 200, healBonus: 1), 1.0);
    });

    test('escudo del Velo: Curación × 1, tope 25%', () {
      expect(ReviveRules.shieldFraction(0), 0);
      expect(ReviveRules.shieldFraction(0.2), closeTo(0.2, 1e-9));
      expect(ReviveRules.shieldFraction(0.6), 0.25);
    });
  });

  group('revivir con habilidad', () {
    test('Eco de Regreso revive con 25% + ESP', () {
      final e = _engine();
      final t = _turn(e, _member('p1', 'maga', weapon: 'tomo_regreso', esp: 20));
      final p2 = t.party[1];
      final step = e.command(t, 'p1', const SkillCommand('ecoRegreso'))!;
      final q = step.state.party[1];
      expect(q.alive, isTrue);
      expect(q.hp, (p2.maxHp * 0.31).round());
      expect(step.events.whereType<RevivedEvent>().single.targetId, 'p2');
      expect(q.shield, 0);
    });

    test('con Curación del árbol también deja escudo', () {
      final e = _engine();
      final t = _turn(e, _member('p1', 'maga', weapon: 'tomo_regreso', esp: 20));
      t.party[0].healBonus = 0.2;
      final max = t.party[1].maxHp;
      final step = e.command(t, 'p1', const SkillCommand('ecoRegreso'))!;
      final q = step.state.party[1];
      expect(q.hp, (max * 0.41).round());
      expect(q.shield, (max * 0.2).round());
      expect(step.events.whereType<ShieldEvent>(), isNotEmpty);
    });
  });

  group('Éter', () {
    test('revive con toda la vida y se gasta', () {
      final e = _engine();
      final t = _turn(e, _member('p1', 'paladin', aethers: 1));
      final step = e.command(t, 'p1',
          const ItemCommand(BattleItem.aether, targetPlayerId: 'p2'))!;
      final q = step.state.party[1];
      expect(q.hp, q.maxHp);
      expect(step.state.party[0].aethers, 0);
      expect(step.events.whereType<RevivedEvent>().single.targetId, 'p2');
    });

    test('sin caídos o sin Éter no vale', () {
      final e = _engine();
      final start = e.start(
        party: [_member('p1', 'paladin', aethers: 1), _member('p2', 'guerrero')],
        enemyTypes: ['slime'],
        triggeredBy: 'p1',
      );
      final t = e.nextTurn(start.state).state;
      expect(e.command(t, 'p1', const ItemCommand(BattleItem.aether)), isNull);
      final t2 = _turn(e, _member('p1', 'paladin'));
      expect(e.command(t2, 'p1', const ItemCommand(BattleItem.aether)), isNull);
    });

    test('viaja por red y en el perfil', () {
      expect(ActionJson.itemFromKey(ActionJson.itemKey(BattleItem.aether)),
          BattleItem.aether);
      final p = PlayerProfile(aethers: 3);
      expect(PlayerProfile.fromJson(p.toJson()).aethers, 3);
      expect(InventoryRules.stackCount(p, StackKind.aether), 3);
    });
  });

  group('tienda y balance', () {
    test('Éter cuesta 5 × la Poción de vida', () {
      expect(kItems[BattleItem.potion]!.price, 30);
      expect(kItems[BattleItem.aether]!.price, 150);
      final rules = ProgressionRules(
          stats: StatsCalculator(
              classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)));
      final p = PlayerProfile(credits: 200);
      final b = rules.buyItem(p, BattleItem.aether)!;
      expect(b.aethers, 1);
      expect(b.credits, 50);
      expect(rules.buyItem(PlayerProfile(credits: 149), BattleItem.aether),
          isNull);
      expect(rules.buyItem(PlayerProfile(credits: 999, aethers: 9),
          BattleItem.aether), isNull);
    });

    test('Editor → Balance: precios y sinergia se parchean', () {
      _install({
        'consumables': {
          'consumables': {'potionPrice': 40, 'aetherMult': 4, 'espPer': 0.01},
        },
      });
      expect(kItems[BattleItem.aether]!.price, 160);
      expect(ReviveRules.lifeFraction(0.25, esp: 10, healBonus: 0),
          closeTo(0.35, 1e-9));
      BalanceRegistries.restore();
      expect(kItems[BattleItem.aether]!.price, 150);
    });

    test('Editor → Balance: dropWeight del arma se parchea', () {
      _install({
        'weapon': {
          'tomo_regreso': {'dropWeight': 0.5},
        },
      });
    });
  });
}
