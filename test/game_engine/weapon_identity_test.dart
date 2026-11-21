import 'dart:math' as math;

import 'package:echos_del_tiempo/core/procedural/weapon_look.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapon_elements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Identidad de las armas (docs/specs/weapon_identity.md, aprobado):
// elemento de base, botín, migración, motor y aspecto.

const _loot = LootRules();
const _items = ItemRules();

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine() =>
    BattleEngine(stats: _stats, random: () => 0.99, breakEnabled: false);

ItemInstance _weapon(GameElement? el, {String base = 'baculo_aprendiz'}) =>
    ItemInstance(uid: 'w1', baseId: base, rarity: Rarity.raro, element: el);

Combatant _hero(ItemInstance item, {List<String> skills = const []}) =>
    Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: skills,
      classId: 'maga',
      weaponType: 'báculo',
      build: PlayerBuild(
        classId: 'maga',
        level: 1,
        attributes: PlayerAttributes.base(kClasses['maga']!.baseAttributes),
        equippedWeapon: kWeapons[item.baseId]!,
        item: item,
      ),
    );

Combatant _foe({Map<StatusKind, int>? st}) => Combatant(
      id: 'e0',
      name: 'Slime',
      isPlayer: false,
      hp: 5000,
      maxHp: 5000,
      speed: 5,
      attack: 1,
      critChance: 0,
      enemyType: 'slime',
      statuses: st,
      nextTurn: 50,
    );

BattleStep _act(BattleEngine e, BattleState s, BattleCommand c) {
  s.currentId = 'p1';
  return e.command(s, 'p1', c)!;
}

/// Ataca [n] veces seguidas (cada paso parte del estado anterior).
BattleState _attacks(BattleEngine e, BattleState s, int n) {
  for (var i = 0; i < n; i++) {
    s = _act(e, s, const AttackCommand(targetId: 'e0')).state;
  }
  return s;
}

double Function() _rng(int seed) {
  final r = math.Random(seed);
  return r.nextDouble;
}

void main() {
  group('botín', () {
    double share(Rarity r, {String base = 'espada_bronce', int n = 4000}) {
      final rng = _rng(r.index + 7);
      var hits = 0;
      for (var i = 0; i < n; i++) {
        final it = _loot.generate(rng, itemLevel: 10, rarity: r, baseId: base);
        if (it.element != null) hits++;
      }
      return hits / n;
    }

    test('probabilidad por rareza: Épico 40 %, Raro 15 %, Común/Mágico 0',
        () {
      expect(share(Rarity.epico), closeTo(kWeaponElementChanceEpic, 0.03));
      expect(share(Rarity.raro), closeTo(kWeaponElementChanceRare, 0.03));
      expect(share(Rarity.magico), 0);
      expect(share(Rarity.comun), 0);
    });

    test('bases con elemento en el nombre: desde Raro siempre el suyo', () {
      expect(share(Rarity.raro, base: 'baculo_fuego', n: 200), 1);
      final it = _loot.generate(_rng(1),
          itemLevel: 10, rarity: Rarity.raro, baseId: 'lanza_escarcha');
      expect(it.element, GameElement.hielo);
      expect(share(Rarity.magico, base: 'baculo_fuego', n: 200), 0);
    });

    test('el elemento sale del pool del tipo', () {
      final rng = _rng(3);
      for (var i = 0; i < 500; i++) {
        final it = _loot.generate(rng,
            itemLevel: 20, rarity: Rarity.epico, baseId: 'arco_compuesto');
        if (it.element != null) {
          expect(weaponElementPool('arco'), contains(it.element));
        }
      }
    });

    test('Épico con elemento rueda 1 mod menos', () {
      final rng = _rng(11);
      var maxWith = 0, maxWithout = 0, minWith = 99, minWithout = 99;
      for (var i = 0; i < 1500; i++) {
        final it = _loot.generate(rng,
            itemLevel: 30, rarity: Rarity.epico, baseId: 'espada_bronce');
        if (it.element != null) {
          maxWith = math.max(maxWith, it.modCount);
          minWith = math.min(minWith, it.modCount);
        } else {
          maxWithout = math.max(maxWithout, it.modCount);
          minWithout = math.min(minWithout, it.modCount);
        }
      }
      expect(maxWith, maxWithout - 1);
      expect(minWith, minWithout - 1);
    });

    test('todo legendario tiene elemento y sale con él', () {
      for (final u in kUniques.values) {
        expect(kUniqueWeaponElement, contains(u.id), reason: u.id);
        final it = _loot.generateUnique(_rng(5), u, 50);
        expect(it.element, uniqueWeaponElement(u.id));
        expect(weaponElementOf(it), isNotNull);
      }
      expect(uniqueWeaponElement('corazonAscua'), GameElement.fuego);
      expect(uniqueWeaponElement('inviernoPerpetuo'), GameElement.hielo);
    });
  });

  group('guardado y migración', () {
    test('JSON: `el` va y vuelve; sin el campo, sin elemento', () {
      final it = _weapon(GameElement.electro);
      expect(it.toJson()['el'], 'electro');
      expect(ItemInstance.fromJson(it.toJson()), it);
      expect(_weapon(null).toJson().containsKey('el'), isFalse);
      expect(ItemInstance.fromJson({'u': 'a', 'b': 'espada_bronce', 'el': 'x'})!
          .element, isNull);
    });

    test('legendarios guardados reciben el elemento de su tema', () {
      final old = ItemInstance.fromJson({
        'u': 'leg1',
        'b': 'baculo_fuego',
        'r': 'legendario',
        'q': 'corazonAscua',
        'p': 'ascuaEterna',
      })!;
      expect(old.element, isNull);
      // Se lee igual antes de sanear…
      expect(weaponElementOf(old), GameElement.fuego);
      // …y el saneo lo deja guardado.
      expect(_items.sanitize(old)!.element, GameElement.fuego);
    });

    test('las demás armas viejas quedan sin elemento; Común/Mágico nunca',
        () {
      final raro = ItemInstance.fromJson(
          {'u': 'r1', 'b': 'baculo_fuego', 'r': 'raro'})!;
      expect(_items.sanitize(raro)!.element, isNull);
      final magico = ItemInstance.fromJson(
          {'u': 'm1', 'b': 'baculo_fuego', 'r': 'magico', 'el': 'fuego'})!;
      expect(_items.sanitize(magico)!.element, isNull);
      expect(weaponElementOf(magico), isNull);
      final epico = ItemInstance.fromJson(
          {'u': 'e1', 'b': 'espada_bronce', 'r': 'epico', 'el': 'agua'})!;
      expect(_items.sanitize(epico)!.element, GameElement.agua);
    });

    test('no se puede quitar: copyWith y mejoras lo conservan', () {
      final it = _weapon(GameElement.veneno);
      expect(it.copyWith(rarity: Rarity.epico).element, GameElement.veneno);
      expect(it.copyWith(extraSkills: ['bola']).element, GameElement.veneno);
    });
  });

  group('motor', () {
    test('básico elemental: 1 pila cada 2 golpes', () {
      final e = _engine();
      final s = BattleState(
          party: [_hero(_weapon(GameElement.fuego))], enemies: [_foe()]);
      final s1 = _attacks(e, s, 1);
      expect(s1.byId('e0')!.stacks(StatusKind.burn), 0);
      final s2 = _attacks(e, s1, 1);
      expect(s2.byId('e0')!.stacks(StatusKind.burn), 1);
      final s4 = _attacks(e, s2, 2);
      expect(s4.byId('e0')!.stacks(StatusKind.burn), greaterThanOrEqualTo(1));
      expect(s4.byId('p1')!.basicHits, 4);
    });

    test('sin elemento: básico físico y sin pilas', () {
      final e = _engine();
      final s = BattleState(party: [_hero(_weapon(null))], enemies: [_foe()]);
      final s4 = _attacks(e, s, 4);
      expect(s4.byId('e0')!.statuses.values.where((v) => v > 0), isEmpty);
      expect(s4.byId('p1')!.basicHits, 0);
    });

    test('el básico elemental reacciona (Convergencia con Veneno)', () {
      final e = _engine();
      final s = BattleState(
          party: [_hero(_weapon(GameElement.fuego))],
          enemies: [_foe(st: {StatusKind.poison: 5})]);
      final step = _act(e, s, const AttackCommand(targetId: 'e0'));
      expect(
          step.events.whereType<ReactionEvent>().map((r) => r.kind),
          contains(ReactionKind.explosionToxica));
    });

    test('+8 % a las habilidades del mismo elemento, sin penalidad al resto',
        () {
      int dmg(GameElement? el, String skill) {
        final e = _engine();
        final s = BattleState(
            party: [_hero(_weapon(el), skills: [skill])], enemies: [_foe()]);
        final out = _act(e, s, SkillCommand(skill, targetId: 'e0')).state;
        return 5000 - out.byId('e0')!.hp;
      }

      final plain = dmg(null, 'bola');
      final same = dmg(GameElement.fuego, 'bola');
      expect(same / plain, closeTo(1 + kWeaponElementSynergy, 0.02));
      expect(dmg(GameElement.hielo, 'bola'), plain);
    });

    test('snapshot: el contador de básicos viaja (bh)', () {
      const j = SessionJson();
      final c = _hero(_weapon(GameElement.fuego))..basicHits = 3;
      expect(j.combatantFromJson(j.combatantToJson(c)).basicHits, 3);
    });
  });

  group('aspecto', () {
    test('co-op: el aura del compañero sale de su build del snapshot', () {
      const j = SessionJson();
      final mate = _hero(const ItemInstance(
          uid: 'mate-7',
          baseId: 'baculo_fuego',
          rarity: Rarity.epico,
          element: GameElement.fuego,
          ultId: 'x'));
      final remote = j.combatantFromJson(j.combatantToJson(mate));
      final look = lookOfCombatant(remote)!;
      expect(look.auraColor, elementColor(GameElement.fuego));
      expect(look.hasUlt, isTrue);
      expect(look, lookOfCombatant(mate));
    });

    test('variación determinista por uid (3 variantes)', () {
      expect(WeaponLook.variantOf('abc'), WeaponLook.variantOf('abc'));
      final seen = {
        for (var i = 0; i < 60; i++) WeaponLook.variantOf('item-$i'),
      };
      expect(seen, {0, 1, 2});
      final a = WeaponLook.of(_weapon(null));
      final b = WeaponLook.of(_weapon(null));
      expect(a, b);
    });

    test('legendario: destello y elemento; común sin aura', () {
      final u = kUniques['corazonAscua']!;
      final leg = WeaponLook.of(_loot.generateUnique(_rng(2), u, 20));
      expect(leg.legendary, isTrue);
      expect(leg.element, GameElement.fuego);
      expect(WeaponLook.of(const ItemInstance(uid: 'c', baseId: 'espada_bronce'))
          .auraColor, isNull);
    });
  });
}
