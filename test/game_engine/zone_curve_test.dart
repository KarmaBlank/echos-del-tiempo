// Curva por tramos, grupo y loot atado a la zona (docs/specs/combo_balance.md
// § 1, § 2 y § 3.3; pasos 5 y 6).

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/rules/zone_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

Combatant _hero(String id) => Combatant(
      id: id,
      name: id,
      isPlayer: true,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 50,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      classId: 'guerrero',
      weaponType: 'espada',
      skillIds: const ['embestida'],
    );

Combatant _foe({int level = 0}) => Combatant(
      id: 'e0',
      name: 'Foe',
      isPlayer: false,
      hp: 5000,
      maxHp: 5000,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: 'golem',
      level: level,
      nextTurn: 50,
    );

/// Daño de un ataque de p1 con [players] en el grupo a un enemigo de
/// nivel [level].
(int, String) _attack(int players, {int level = 0}) {
  final engine = BattleEngine(
      stats: _stats, random: () => 0.99, familiesEnabled: false);
  final s = BattleState(
      party: [for (var i = 1; i <= players; i++) _hero('p$i')],
      enemies: [_foe(level: level)]);
  s.currentId = 'p1';
  final step = engine.command(s, 'p1', const AttackCommand(targetId: 'e0'))!;
  return (5000 - step.state.enemies.first.hp, step.state.log);
}

void main() {
  const curve = CurveDef();

  group('curva por tramos (§ 1)', () {
    test('A = 1-3, B = 4-6, C = 7-10, y se repite por tramo', () {
      expect([for (var l = 1; l <= 10; l++) curve.partOf(l).name].join(),
          'aaabbbcccc');
      expect(curve.partOf(11), TramoPart.a);
      expect(curve.partOf(30), TramoPart.c);
      expect(ZoneRules.isZoneC(10), isTrue);
      expect(ZoneRules.isZoneC(5), isFalse);
      expect(ZoneRules.isZoneC(0), isFalse);
    });

    test('vida: +10%/nivel en A y B, +22% en C, y la pendiente vuelve al '
        'empezar el tramo', () {
      expect(curve.hpScale(1), 1);
      expect(curve.hpScale(6), closeTo(1.5, 1e-9));
      expect(curve.hpScale(10), closeTo(1.5 + 4 * 0.22, 1e-9));
      expect(curve.hpScale(11) - curve.hpScale(10), closeTo(0.10, 1e-9));
      // Al final de cada tramo queda cerca de la curva vieja (+15%/nivel).
      expect(curve.hpScale(30), closeTo(1 + 0.15 * 29, 0.05));
    });

    test('zonas C: los comunes pegan +15%; élites y jefes no', () {
      BattleState battle() => BattleState(party: [
            _hero('p1')
          ], enemies: [
            Combatant(
                id: 'e0',
                name: 'a',
                isPlayer: false,
                hp: 50,
                maxHp: 50,
                speed: 5,
                attack: 20,
                critChance: 0,
                enemyType: 'arana'),
            Combatant(
                id: 'e1',
                name: 'b',
                isPlayer: false,
                hp: 50,
                maxHp: 50,
                speed: 5,
                attack: 20,
                critChance: 0,
                enemyType: 'arana',
                elite: true),
          ]);
      // Araña: nivel base 6. A nivel 6 (B) no escala; a nivel 7 (C) sí.
      final b = battle();
      ZoneRules.scaleBattle(b, 6);
      expect(b.enemies.map((e) => e.attack), [20, 20]);
      final c = battle();
      ZoneRules.scaleBattle(c, 7);
      final af = curve.atkScale(7) / curve.atkScale(6);
      expect(c.enemies[0].attack, (20 * af * 1.15).round());
      expect(c.enemies[1].attack, (20 * af).round());
    });
  });

  group('grupo (§ 3.3)', () {
    test('vida en cooperativo 0.6 + 0.3 × jugadores; el quiebre usa la '
        'misma fórmula', () {
      expect(curve.groupHp(1), closeTo(0.9, 1e-9));
      expect(curve.groupHp(4), closeTo(1.8, 1e-9));
      const cat = GameCatalog.standard;
      expect(cat.combo.groupBreak(4), closeTo(1.8, 1e-9));
      final engine = BattleEngine(stats: _stats, random: () => 0.5);
      final s = engine
          .start(party: [
            for (var i = 1; i <= 4; i++)
              BattlePartyMember(
                  id: 'p$i', name: 'p$i', build: _build()),
          ], enemyTypes: ['slime'])
          .state;
      expect(s.enemies.first.maxHp, (30 * 1.8).round());
    });

    test('mitigación: −8% por jugador extra y −10% en zonas C, con el '
        'desglose en el log', () {
      final (solo, _) = _attack(1);
      final (four, log4) = _attack(4);
      final (fourC, logC) = _attack(4, level: 10);
      final (soloC, _) = _attack(1, level: 10);
      expect(solo, 50);
      expect(four, (50 * 0.76).round());
      expect(log4, contains('× 0.76 grupo (4 jug.)'));
      expect(soloC, 45);
      expect(fourC, (50 * 0.76 * 0.9).round());
      expect(logC, contains('× 0.76 grupo (4 jug.) × 0.9 zona C'));
    });

    test('ATQ enemigo +40% por jugador extra; en C a 2+ jugadores actúan '
        'antes', () {
      expect(curve.groupAtk(1), 1);
      expect(curve.groupAtk(4), closeTo(2.2, 1e-9));
      final engine = BattleEngine(stats: _stats, random: () => 0.5);
      BattleState start(int n) => engine
          .start(party: [
            for (var i = 1; i <= n; i++)
              BattlePartyMember(id: 'p$i', name: 'p$i', build: _build()),
          ], enemyTypes: ['arana'])
          .state;
      final solo = start(1), duo = start(2);
      expect(duo.enemies.first.attack, (11 * 1.4).round());
      final t0 = duo.enemies.first.nextTurn;
      ZoneRules.scaleBattle(duo, 10);
      expect(duo.enemies.first.nextTurn, closeTo(t0 * 0.2, 1e-9));
      final s0 = solo.enemies.first.nextTurn;
      ZoneRules.scaleBattle(solo, 10);
      expect(solo.enemies.first.nextTurn, s0);
    });

    test('retraso con rendimiento decreciente hasta el turno del enemigo',
        () {
      final engine = BattleEngine(
          stats: _stats, random: () => 0.99, familiesEnabled: false);
      final s = BattleState(
          party: [_hero('p1'), _hero('p2')], enemies: [_foe()]);
      final gains = <double>[];
      for (var i = 0; i < 3; i++) {
        final who = i.isEven ? 'p1' : 'p2';
        s.currentId = who;
        s.party.firstWhere((p) => p.id == who).mp = 50;
        final before = s.enemies.first.nextTurn;
        final st = engine.command(
            s, who, const SkillCommand('embestida', targetId: 'e0'))!;
        gains.add(st.state.enemies.first.nextTurn - before);
        s.enemies.first
          ..nextTurn = st.state.enemies.first.nextTurn
          ..delayStreak = st.state.enemies.first.delayStreak
          ..hp = 5000;
      }
      expect(gains[1] / gains[0], closeTo(0.3, 1e-6));
      expect(gains[2] / gains[0], closeTo(0.09, 1e-6));
    });

    test('jefe en solitario: sin escolta y con vida × soloBossHp', () {
      final engine = BattleEngine(stats: _stats, random: () => 0.5);
      const cat = GameCatalog.standard;
      final solo = engine
          .start(
              party: [BattlePartyMember(id: 'p1', name: 'p1', build: _build())],
              enemyTypes: ['reyLimo', 'slime', 'slime'])
          .state;
      expect(solo.enemies.where((e) => e.enemyType == 'slime'), isEmpty);
      expect(solo.enemies.first.maxHp,
          (cat.enemies['reyLimo']!.hp * 0.9 * cat.curve.soloBossHp).round());
      final duo = engine
          .start(party: [
            BattlePartyMember(id: 'p1', name: 'p1', build: _build()),
            BattlePartyMember(id: 'p2', name: 'p2', build: _build()),
          ], enemyTypes: ['reyLimo', 'slime', 'slime'])
          .state;
      expect(duo.enemies.where((e) => e.enemyType == 'slime').length,
          greaterThanOrEqualTo(2));
    });
  });

  group('loot atado a la zona (§ 2)', () {
    test('nivel de objeto ≤ nivel tope de la zona', () {
      expect(LootRules.itemLevelFor(5, LootSource.boss), 7);
      expect(LootRules.itemLevelFor(5, LootSource.boss, cap: 5), 5);
      expect(LootRules.itemLevelFor(4, LootSource.elite, cap: 5), 5);
      expect(LootRules.itemLevelFor(3, LootSource.battle, cap: 5), 3);
    });

    test('los mods fijos de las legendarias escalan con el nivel del '
        'objeto, dos tiers por encima de los aleatorios', () {
      final u = kUniques['juramentoAlba']!;
      final feroz = u.fixed.firstWhere((f) => f.affixId == 'feroz');
      // Feroz 20-30. Nivel 5: sale T5 → T3 (máx 24) / 40 = 0.6.
      expect(ItemRules.fixedRangeAt(feroz, 5), (12, 18));
      // Nivel 10: T4 → T2 (32 / 40).
      expect(ItemRules.fixedRangeAt(feroz, 10), (16, 24));
      // Nivel 20+: rango completo.
      expect(ItemRules.fixedRangeAt(feroz, 20), (20, 30));
      expect(ItemRules.fixedRangeAt(feroz, 50), (20, 30));
      const loot = LootRules();
      final low = loot.generateUnique(mulberry32(3), u, 5);
      final high = loot.generateUnique(mulberry32(3), u, 40);
      // La base pide un nivel mínimo: el objeto sale a ese nivel.
      final (lo, hi) = ItemRules.fixedRangeAt(feroz, low.itemLevel);
      expect(hi, lessThanOrEqualTo(30));
      final lv = low.affixes.firstWhere((a) => a.affixId == 'feroz').value;
      final hv = high.affixes.firstWhere((a) => a.affixId == 'feroz').value;
      expect(lv, inInclusiveRange(lo, hi));
      expect(hv, inInclusiveRange(20, 30));
      // La Esquirla vuelve a tirar dentro del rango escalado.
      final again = loot.rerollValues(mulberry32(9), low);
      expect(again.affixes.firstWhere((a) => a.affixId == 'feroz').value,
          inInclusiveRange(lo, hi));
    });

    test('tope de común en zona C: 35%; en A/B, 60%', () {
      expect(_cappedHit(level: 10), 35);
      expect(_cappedHit(level: 5), 60);
    });

    test('tope de forja: min(tope de rareza, 2 + nivel / 5)', () {
      expect(ItemRules.forgeCapAt(Rarity.legendario, 5), 3);
      expect(ItemRules.forgeCapAt(Rarity.legendario, 40), 10);
      expect(ItemRules.forgeCapAt(Rarity.legendario, 50), 10);
      expect(ItemRules.forgeCapAt(Rarity.raro, 1), 2);
      expect(ItemRules.forgeCapAt(Rarity.raro, 30), 6);
      const item = ItemInstance(
          uid: 'x',
          baseId: 'espada_bronce',
          rarity: Rarity.legendario,
          itemLevel: 5,
          forge: WeaponUpgradeLevels(pow: 3));
      expect(ItemRules.forgeCapOf(item), 3);
    });

    test('forjar nuevo respeta el tope por nivel de objeto', () {
      const it = ItemInstance(
          uid: 'w1',
          baseId: 'espada_bronce',
          rarity: Rarity.epico,
          itemLevel: 1,
          forge: WeaponUpgradeLevels(pow: 2));
      final p = PlayerProfile(
              classId: 'guerrero', credits: 100000, items: const [it]);
      final r = const CraftRules().forge(p, 'w1', UpgradeStat.pow);
      expect(r.ok, isFalse);
      expect(r.error, contains('Tope de forja (2)'));
    });
  });
}

PlayerBuild _build() => PlayerBuild(
      classId: 'guerrero',
      level: 1,
      attributes: PlayerAttributes.base(kClasses['guerrero']!.baseAttributes),
      equippedWeapon: GameCatalog.standard.weapons['espada_bronce']!,
    );

/// Golpe enorme de un jugador solo a un común de 100 de vida a [level].
int _cappedHit({required int level}) {
  final engine = BattleEngine(
      stats: _stats, random: () => 0.99, familiesEnabled: false);
  final foe = _foe(level: level)
    ..hp = 100
    ..maxHp = 100;
  final hero = _hero('p1')..attack = 500;
  final s = BattleState(party: [hero], enemies: [foe]);
  s.currentId = 'p1';
  final st = engine.command(s, 'p1', const AttackCommand(targetId: 'e0'))!;
  return 100 - st.state.enemies.first.hp;
}
