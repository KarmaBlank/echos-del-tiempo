import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/encounter_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/skill_requirements.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Enemy Silence and the player break bar (docs/specs/combat.md §
// "Silencio", combo_balance.md § 5.4).

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _plain() =>
    BattleEngine(stats: _stats, random: () => 0.99, breakEnabled: false);

Combatant _hero(String id,
        {int magic = 20,
        List<String> skills = const [],
        double next = 0,
        int hp = 100}) =>
    Combatant(
      id: id,
      name: id,
      isPlayer: true,
      hp: hp,
      maxHp: hp,
      speed: 10,
      attack: 20,
      magic: magic,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: skills,
      classId: 'maga',
      weaponType: 'baston',
      nextTurn: next,
    );

Combatant _foe(String id, String type,
        {double next = 50, int attack = 10}) =>
    Combatant(
      id: id,
      name: id,
      isPlayer: false,
      hp: 1000,
      maxHp: 1000,
      speed: 5,
      attack: attack,
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

  test('silencers in the catalog', () {
    expect(
        [
          for (final e in kEnemies.values)
            if (e.silencer) e.id
        ]..sort(),
        ['almaErrante', 'espectroCoronado', 'hechicera', 'ojoAbismo']..sort());
  });

  group('silence', () {
    test('blocks MP skills and the ULT, not the attack or the turn', () {
      _tune({'pBreakOn': 0});
      final p = _hero('p1', skills: ['misil'])
        ..silenced = 2
        ..ult = 100;
      final s = BattleState(
          party: [p], enemies: [_foe('e0', 'slime')], currentId: 'p1');
      final e = _plain();
      expect(SkillRequirements.missing(kSkills['misil']!, p, null),
          contains('Silenciado'));
      expect(e.command(s, 'p1', const SkillCommand('misil', targetId: 'e0')),
          isNull);
      expect(ultReady(p), isFalse);
      expect(e.command(s, 'p1', const UltimateCommand(targetId: 'e0')),
          isNull);
      final hit = e.command(s, 'p1', const AttackCommand(targetId: 'e0'));
      expect(hit, isNotNull);
      expect(hit!.state.enemies.first.hp, lessThan(1000));
    });

    test('ticks down on its own turns and travels', () {
      final p = _hero('p1')..silenced = 3;
      const j = SessionJson();
      final back = j.battleStateFromJson(j.battleStateToJson(
          BattleState(party: [p], enemies: [_foe('e0', 'slime')])));
      expect(back.party.first.silenced, 3);
      final s = BattleState(party: [p], enemies: [_foe('e0', 'slime')]);
      final out = _plain().nextTurn(s).state;
      expect(out.currentId, 'p1');
      expect(out.party.first.silenced, 2);
    });
  });

  group('player break', () {
    test('enemy hits fill the bar and break the player', () {
      _tune({'pBreakMax': 30, 'pBreakHit': 10, 'pBreakHp': 0});
      var s = BattleState(
          party: [_hero('p1', hp: 1000)],
          enemies: [_foe('e0', 'slime')],
          currentId: 'e0');
      final e = _plain();
      s = e.enemyTurn(s)!.state;
      expect(s.party.first.breakGauge, 10);
      s.currentId = 'e0';
      s = e.enemyTurn(s)!.state;
      s.currentId = 'e0';
      s = e.enemyTurn(s)!.state;
      final p = s.party.first;
      expect(p.breakSkip, isTrue);
      expect(p.vulnerable, BattleEngine.playerBrokenTurns);
      // Broken: takes more damage.
      final before = p.hp;
      s.currentId = 'e0';
      s = e.enemyTurn(s)!.state;
      expect(before - s.party.first.hp,
          (10 * BattleEngine.playerBrokenMult).round());
      // And loses its next turn.
      s.party.first.nextTurn = 0;
      s.enemies.first.nextTurn = 999;
      final skipped = e.nextTurn(s).state;
      expect(skipped.party.first.breakSkip, isFalse);
    });

    test('off in Balance: no bar', () {
      _tune({'pBreakOn': 0});
      final s = BattleState(
          party: [_hero('p1')],
          enemies: [_foe('e0', 'slime')],
          currentId: 'e0');
      expect(_plain().enemyTurn(s)!.state.party.first.breakGauge, 0);
    });
  });

  group('silencer AI', () {
    test('silences the highest skill power when it opens in an ambush', () {
      _tune({'pBreakOn': 0});
      final e = _plain();
      var s = BattleState(
          party: [
            _hero('weak', magic: 10, skills: ['misil'], next: 80),
            _hero('mage', magic: 40, skills: ['rayoArcano'], next: 80),
          ],
          enemies: [_foe('e0', 'almaErrante', next: 10)]);
      e.applyOpeningSilence(s);
      expect(s.enemies.first.once, contains(BattleEngine.silenceOpenKey));
      s.currentId = 'e0';
      s = e.enemyTurn(s)!.state;
      final mage = s.party.firstWhere((p) => p.id == 'mage');
      expect(mage.silenced, BattleEngine.silenceTurns + 1);
      expect(s.party.firstWhere((p) => p.id == 'weak').silenced, 0);
      expect(mage.hp, 100, reason: 'casting uses its action');
    });

    test('ambush start arms the opening silence', () {
      final s = _plain()
          .start(
            party: [
              BattlePartyMember(
                id: 'p1',
                name: 'p1',
                build: PlayerBuild(
                  classId: 'maga',
                  level: 1,
                  attributes: PlayerAttributes.base(kClasses['maga']!.baseAttributes),
                  equippedWeapon: kWeapons[kClasses['maga']!.startWeaponId]!,
                ),
              ),
            ],
            enemyTypes: ['almaErrante'],
            encounter: EncounterKind.ambush,
            // porBando: without the ambush the party would open.
            turnRule: TurnRule.porBando,
          )
          .state;
      expect(s.enemies.first.once, contains(BattleEngine.silenceOpenKey));
    });

    test('does not silence when the party opens', () {
      final s = BattleState(
          party: [_hero('mage', skills: ['rayoArcano'])],
          enemies: [_foe('e0', 'almaErrante')],
          turnRule: TurnRule.porBando);
      _plain().applyOpeningSilence(s);
      expect(s.enemies.first.once, isEmpty);
    });
  });
}
