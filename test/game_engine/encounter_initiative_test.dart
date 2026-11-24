import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/encounter_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = StatsCalculator(
    classes: kClasses,
    treeRules: PassiveTreeRules(PassiveTreeCatalog(
        nodes: {}, startNodeByClass: {}, exclusions: {})));

BattlePartyMember _member(String id, String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: id,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

/// Encounter initiative (docs/specs/combat.md § "Iniciativa del encuentro").
void main() {
  group('EncounterRules.kind', () {
    EncounterKind k(double mdx, double mdy, {bool moving = true}) =>
        EncounterRules.kind(
            px: 0, py: 0, ex: 10, ey: 0, mdx: mdx, mdy: mdy, moving: moving);
    test('moving toward the enemy is a first strike', () {
      expect(k(2, 0), EncounterKind.firstStrike);
      expect(k(1, 1), EncounterKind.firstStrike);
    });
    test('moving away is an ambush', () {
      expect(k(-2, 0), EncounterKind.ambush);
    });
    test('standing still is an ambush', () {
      expect(k(0, 0), EncounterKind.ambush);
      expect(k(0.05, 0), EncounterKind.ambush);
      expect(k(2, 0, moving: false), EncounterKind.ambush);
    });
  });

  // random 0.99: without the initiative rule p1 would not open the timeline.
  final engine =
      BattleEngine(stats: _stats, random: () => 0.99, breakEnabled: false);

  BattleState opened(TurnRule rule, EncounterKind kind) {
    final s = engine
        .start(
          party: [_member('p0', 'guerrero'), _member('p1', 'maga')],
          enemyTypes: ['slime', 'slime'],
          triggeredBy: 'p1',
          encounter: kind,
          turnRule: rule,
        )
        .state;
    for (final e in s.enemies) {
      e
        ..hp = 99999
        ..maxHp = 99999;
    }
    return engine.nextTurn(s).state;
  }

  for (final rule in TurnRule.values) {
    test('$rule first strike: party opens, toucher first', () {
      final s = opened(rule, EncounterKind.firstStrike);
      if (s.grouped) {
        expect(s.awaitingGroup, isTrue);
        expect(s.pendingGroup.map((c) => c.id), contains('p1'));
        if (s.porRonda) expect(s.roundOrder.first, 'p1');
      } else {
        expect(s.currentId, 'p1');
      }
    });
    test('$rule ambush: enemies open, touching enemy first', () {
      final s = opened(rule, EncounterKind.ambush);
      expect(s.currentId, 'e0');
      expect(s.awaitingGroup, isFalse);
    });
  }

  test('start line: first strike vs ambush', () {
    BattleState st(EncounterKind? k) => engine
        .start(
            party: [_member('p0', 'guerrero')],
            enemyTypes: ['slime'],
            triggeredBy: 'p0',
            encounter: k)
        .state;
    expect(st(EncounterKind.firstStrike).logLine,
        isNot(st(EncounterKind.ambush).logLine));
    expect(st(null).logLine, st(EncounterKind.ambush).logLine);
  });
}
