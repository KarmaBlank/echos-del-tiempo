import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemy_families.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/battle_log_helper.dart';

// Tanks and "nobody alone in one phase" (docs/specs/combat.md §
// "Tanques" and § "Nadie solo en una fase").

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

/// No randomness: never a crit or a proc.
BattleEngine _plain({bool families = true}) => BattleEngine(
    stats: _stats, random: () => 0.99, familiesEnabled: families);

Combatant _hero(String id,
        {int attack = 20, List<String> skills = const [], double next = 0}) =>
    Combatant(
      id: id,
      name: id,
      isPlayer: true,
      pulse: BattleEngine.pulseMax,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: attack,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: skills,
      classId: 'guerrero',
      weaponType: 'espada',
      nextTurn: next,
    );

Combatant _foe(String id, String type, {int hp = 100, double next = 50}) =>
    Combatant(
      id: id,
      name: id,
      isPlayer: false,
      hp: hp,
      maxHp: 100,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: type,
      nextTurn: next,
    );

void _tune(Map<String, num> values) {
  final d = kTuningDefaults[TuningId.combatLimits]!;
  kTuning[TuningId.combatLimits] = TuningDef(d.name, {...d.values, ...values});
}

void main() {
  tearDown(() =>
      kTuning[TuningId.combatLimits] = kTuningDefaults[TuningId.combatLimits]!);

  test('tanks in the catalog', () {
    expect(
        [
          for (final e in kEnemies.values)
            if (e.tank) e.id
        ]..sort(),
        ['caballeroCaido', 'elementalEscarcha', 'golem', 'golemMagma',
          'guardianReloj']..sort());
  });

  group('ward', () {
    test('picks the weakness the party hits with', () {
      final e = _plain();
      final tank = _foe('e0', 'golemMagma'); // weak to ice and water
      BattleState with_(List<String> skills) => BattleState(
          party: [_hero('p1', skills: skills)], enemies: [tank]);
      expect(e.chooseWard(with_(['lanzaH']), tank), DamageTag.ice);
      expect(e.chooseWard(with_(['chorro']), tank), DamageTag.water);
      expect(e.chooseWard(with_(['chorro', 'chorro', 'lanzaH']), tank),
          DamageTag.water);
    });

    test('pre-applied when the party opens the fight', () {
      final s = BattleState(
          party: [_hero('p1', skills: ['lanzaH'])],
          enemies: [_foe('e0', 'golemMagma'), _foe('e1', 'slime')],
          turnRule: TurnRule.porBando);
      _plain().applyOpeningWards(s);
      expect(s.enemies[0].ward, DamageTag.ice.index + 1);
      expect(s.enemies[0].wardTurns, BattleEngine.wardTurns);
      expect(s.enemies[1].ward, 0, reason: 'not a tank');
      expect(s.log, isNotEmpty);
    });

    test('not pre-applied when the tank opens the fight', () {
      final fases = BattleState(
          party: [_hero('p1', skills: ['lanzaH'])],
          enemies: [_foe('e0', 'golemMagma')],
          turnRule: TurnRule.porFases);
      _plain().applyOpeningWards(fases);
      expect(fases.enemies[0].ward, 0);
      final timeline = BattleState(
          party: [_hero('p1', next: 80)],
          enemies: [_foe('e0', 'golemMagma', next: 10)]);
      _plain().applyOpeningWards(timeline);
      expect(timeline.enemies[0].ward, 0);
    });

    test('the tank defends and raises it on its turn', () {
      final s = BattleState(
          party: [_hero('p1', skills: ['chorro'])],
          enemies: [_foe('e0', 'golemMagma')],
          currentId: 'e0');
      final out = _plain().enemyTurn(s)!.state;
      final t = out.enemies.first;
      expect(t.ward, DamageTag.water.index + 1);
      expect(t.defending, isTrue);
      expect(out.party.first.hp, 100, reason: 'guarding uses its action');
    });

    test('cuts the warded element and survives a round trip', () {
      BattleState fight(int ward) {
        final tank = _foe('e0', 'golemMagma')
          ..ward = ward
          ..wardTurns = 2;
        return BattleState(
            party: [_hero('p1', attack: 30, skills: ['lanzaH'])],
            enemies: [tank],
            currentId: 'p1');
      }

      int dealt(int ward) {
        final s = _plain()
            .command(fight(ward), 'p1',
                const SkillCommand('lanzaH', targetId: 'e0'))!
            .state;
        return 100 - s.enemies.first.hp;
      }

      final open = dealt(0);
      final warded = dealt(DamageTag.ice.index + 1);
      expect(warded, lessThan(open));
      const codec = SessionJson();
      final back = codec.battleStateFromJson(
          codec.battleStateToJson(fight(DamageTag.ice.index + 1)));
      expect(back.enemies.first.ward, DamageTag.ice.index + 1);
      expect(back.enemies.first.wardTurns, 2);
    });
  });

  group('nobody alone in one phase', () {
    BattleState fight({int hp = 55, bool solo = false}) => BattleState(
          party: [
            _hero('p1', attack: 9999),
            if (!solo) _hero('p2', attack: 9999, next: 50),
          ],
          enemies: [_foe('e0', 'slime', hp: hp)],
          currentId: 'p1',
          // p2 already acted: "holds a round" does not apply.
          acted: {'p2'},
        );

    test('one character cannot kill it from above half', () {
      final s = _plain(families: false)
          .command(fight(), 'p1', const AttackCommand(targetId: 'e0'))!
          .state;
      expect(s.enemies.first.hp, 1);
    });

    test('a second character can finish it', () {
      final a = _plain(families: false)
          .command(fight(), 'p1', const AttackCommand(targetId: 'e0'))!
          .state
        ..currentId = 'p2';
      final b = _plain(families: false)
          .command(a, 'p2', const AttackCommand(targetId: 'e0'))!
          .state;
      expect(b.enemies.first.alive, isFalse);
    });

    test('below half, one character kills it', () {
      final s = _plain(families: false)
          .command(fight(hp: 40), 'p1', const AttackCommand(targetId: 'e0'))!
          .state;
      expect(s.enemies.first.alive, isFalse);
    });

    test('alone with nobody else, it dies (no stalemate)', () {
      final s = _plain(families: false)
          .command(
              fight(solo: true), 'p1', const AttackCommand(targetId: 'e0'))!
          .state;
      expect(s.enemies.first.alive, isFalse);
    });

    test('off in Balance', () {
      _tune({'phaseHold': 0});
      final s = _plain(families: false)
          .command(fight(), 'p1', const AttackCommand(targetId: 'e0'))!
          .state;
      expect(s.enemies.first.alive, isFalse);
    });
  });
}
