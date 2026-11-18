import 'dart:convert';

import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// JSON del endgame v0.4: ida y vuelta, red y saves v0.3
/// (docs/specs/ecos_atlas.md § 7 y la persistencia aditiva).
Json _wire(Object? j) => asJson(jsonDecode(jsonEncode(j)));

const _eco = EcoItem(
  uid: 'e3',
  tier: 9,
  zone: 7,
  boss: 4,
  rarity: Rarity.raro,
  mods: [EcoModRoll('vida', 25), EcoModRoll('brasas', 2)],
  floors: 3,
  seed: 123456,
  name: 'Eco Roto del Reloj',
);

/// Un perfil como lo guardaba la v0.3.0 (sin `ecos`, `eco` ni `ms`).
const _v03Profile = <String, Object?>{
  'pv': 3,
  'name': 'Ana',
  'cls': 'maga',
  'lvl': 50,
  'xp': 40000,
  'cr': 1200,
  'st': {'VIT': 10, 'ESP': 10, 'AGI': 10, 'FUE': 10, 'DES': 10},
  'pts': 0,
  'items': [
    {'u': 'baculo_roble', 'b': 'baculo_roble'},
  ],
  'eq': 'baculo_roble',
  'pot': 3,
  'eter': 1,
  'mats': {'esquirla': 4},
  'tree': <String>[],
  'tv': 2,
  'zu': 10,
};

void main() {
  // v0.5 subió a 5 (ascension.md § 6); lo de los Ecos sigue igual.
  test('protocolo 4 o más', () => expect(kProtocolVersion, greaterThanOrEqualTo(4)));

  group('Eco y drop', () {
    test('EcoItem: ida y vuelta y lectura tolerante', () {
      expect(EcoItem.fromJson(_wire(_eco.toJson())), _eco);
      expect(EcoItem.fromJson({'u': 'x'}), isNull);
      final clamp = EcoItem.fromJson(
          {'u': 'x', 't': 99, 'z': 0, 'b': 12, 'f': 9, 'm': 'mal'})!;
      expect(clamp.tier, 16);
      expect(clamp.zone, 1);
      expect(clamp.boss, 10);
      expect(clamp.floors, 3);
      expect(clamp.mods, isEmpty);
    });

    test('LootDrop.eco', () {
      final d = LootDrop.fromJson(_wire(const LootDrop.eco(_eco).toJson()))!;
      expect(d.isEco, isTrue);
      expect(d.eco, _eco);
      expect(
          LootDrop.fromJson(
                  _wire(const LootDrop.stack(StackKind.ancla, 2).toJson()))!
              .stack,
          StackKind.ancla);
    });
  });

  group('perfil', () {
    test('un save v0.3 carga con los valores por defecto', () {
      final p = PlayerProfile.fromJson(_wire(_v03Profile));
      expect(p.ecos, isEmpty);
      expect(p.ecosUnlocked, isFalse);
      expect(p.mastery, 0);
      expect(p.level, 50);
      final json = p.toJson();
      expect(json.containsKey('ecos'), isFalse);
      expect(json.containsKey('eco'), isFalse);
      expect(json.containsKey('ms'), isFalse);
      // La XP de sobra del 50 se vuelve Maestría con la próxima ganancia.
      final g = zoneProgression.gainXp(zoneProgression.normalize(p), 0);
      expect(g.profile.mastery, 2, reason: '40000 = 12000 + 15000 + 13000');
      expect(g.profile.xp, 13000);
    });

    test('Ecos, portal y Maestría: ida y vuelta', () {
      final p = InventoryRules.addEco(
              newProfile('Bo', 'guerrero')
                  .copyWith(ecosUnlocked: true, mastery: 3),
              _eco)
          .$1;
      final back = PlayerProfile.fromJson(_wire(p.toJson()));
      expect(back.ecos.single.tier, 9);
      expect(back.ecos.single.mods, _eco.mods);
      expect(back.ecosUnlocked, isTrue);
      expect(back.mastery, 3);
      expect(back.grid, p.grid);
    });
  });

  group('red', () {
    test('acciones nuevas', () {
      for (final a in const <SessionAction>[
        ProposeEcoAction('e3'),
        EcoCraftAction('e3', EcoCraftOp.tier),
        DevGrantEcoAction(16),
      ]) {
        final back = ActionJson.fromJson(_wire(ActionJson.toJson(a)));
        expect(jsonEncode(ActionJson.toJson(back)),
            jsonEncode(ActionJson.toJson(a)));
      }
      final c = ActionJson.fromJson(_wire(
              ActionJson.toJson(const EcoCraftAction('e3', EcoCraftOp.addMod))))
          as EcoCraftAction;
      expect(c.op, EcoCraftOp.addMod);
    });

    test('eventos nuevos', () {
      const ej = EventJson();
      for (final e in const <SessionEvent>[
        EcoCompletedEvent(['h', 'p1'], tier: 9, zone: 7, boss: 4),
        MasteryUpEvent('h', 5),
        EcosUnlockedEvent('p1'),
      ]) {
        final back = ej.fromJson(_wire(ej.toJson(e)));
        expect(jsonEncode(ej.toJson(back)), jsonEncode(ej.toJson(e)));
      }
      final done = ej.fromJson(_wire(ej.toJson(
              const EcoCompletedEvent(['h', 'p1'], tier: 9, zone: 7, boss: 4))))
          as EcoCompletedEvent;
      expect(done.playerIds, ['h', 'p1']);
      expect(done.tier, 9);
    });

    test('LootDropEvent con un Eco', () {
      const ej = EventJson();
      final back = ej.fromJson(_wire(ej.toJson(const LootDropEvent(
              'h', LootDrop.eco(_eco), LootSource.boss, uid: 'e3'))))
          as LootDropEvent;
      expect(back.drop.eco, _eco);
      expect(back.uid, 'e3');
    });
  });

  group('cuenta y alijo', () {
    test('una cuenta v0.3 (sin atlas) carga con el Atlas vacío', () {
      final a = Account.fromJson(_wire({
        'v': 1,
        'sel': 'c1',
        'seq': 1,
        'chars': [
          {'id': 'c1', 'p': _v03Profile},
        ],
        'stash': {'cells': []},
      }));
      expect(a.atlas.nodes, isEmpty);
      expect(a.atlas.done, isEmpty);
      expect(a.toJson().containsKey('atlas'), isFalse);
      expect(a.selected!.profile.ecos, isEmpty);
    });

    test('Atlas en la cuenta: ida y vuelta (y se sanea al leer)', () {
      final atlas = AtlasProgress(
          nodes: ['gratis', 'potencia', 'nada'],
          done: ['t1', 'z1', 'b1', 'z2']);
      final a = Account().withAtlas(atlas);
      final back = Account.fromJson(_wire(a.toJson()));
      expect(back.atlas.nodes, ['gratis', 'potencia']);
      expect(back.atlas.done, atlas.done);
    });

    test('los Ecos van y vienen del alijo', () {
      const rules = StashRules();
      final p = InventoryRules.addEco(newProfile('Ana', 'guerrero'), _eco).$1;
      final uid = p.ecos.single.uid;
      final dep = rules.deposit(p, Stash.empty(), uid);
      expect(dep.ok, isTrue);
      expect(dep.profile!.ecos, isEmpty);
      final s = Stash.fromJson(_wire(dep.stash!.toJson()));
      final cell = s.cells.indexWhere((c) => c?.eco != null);
      expect(s.cells[cell]!.eco!.tier, 9);
      final w = rules.withdraw(dep.profile!, s, cell);
      expect(w.ok, isTrue);
      expect(w.profile!.ecos.single.tier, 9);
      expect(w.stash!.cells[cell], isNull);
    });
  });

  group('filtro de loot', () {
    const f = LootFilterRules();
    FilterContext ctx() => FilterContext(
        level: 50, attributes: newProfile('Ana', 'guerrero').attributes);

    test('Objeto Eco, Tier, Rareza y Mods', () {
      final r = f.parse('Ocultar\n  Objeto Eco\n  Tier < 5\n'
          'Mostrar # altos\n  Objeto Eco\n  Rareza >= Raro\n  Mods >= 2\n');
      expect(r.ok, isTrue, reason: r.errors.join());
      const low = LootDrop.eco(EcoItem(uid: 'a', tier: 2, zone: 1, boss: 1));
      expect(f.evaluate(r.filter, low, ctx()).visible, isFalse);
      expect(
          f.evaluate(r.filter, const LootDrop.eco(_eco), ctx()).ruleIndex, 1);
      expect(f.serialize(r.filter), contains('Tier < 5'));
      expect(f.parse(f.serialize(r.filter)).filter.rules, r.filter.rules);
    });

    test('el filtro por defecto resalta los Ecos', () {
      final v = f.evaluate(
          LootFilterRules.defaultFilter, const LootDrop.eco(_eco), ctx());
      expect(v.visible, isTrue);
      expect(v.style.sound, 'gema');
      expect(v.style.icon,
          const MapIcon(MapIconShape.cuadrado, MapIconColor.celeste));
      expect(EcoRules.missionId, 'eco');
    });
  });
}
