import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = StatsCalculator(
    classes: kClasses,
    treeRules: PassiveTreeRules(PassiveTreeCatalog(
        nodes: {}, startNodeByClass: {}, exclusions: {})));

BattleEngine _engine() =>
    BattleEngine(stats: _stats, random: () => 0.99, breakEnabled: false);

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

/// Prisa in the round modes (docs/specs/turn_modes.md § 4.2).
void main() {
  final engine = _engine();

  /// p0 casts Prisa; speeds by id fix the round order.
  BattleState start(TurnRule rule, Map<String, double> speeds,
      {List<String> enemies = const ['slime', 'slime'], int players = 2}) {
    final s = engine
        .start(
          party: [
            for (var i = 0; i < players; i++)
              _member('p$i', i == 0 ? 'maga' : 'guerrero'),
          ],
          enemyTypes: enemies,
          turnRule: rule,
        )
        .state;
    for (final e in s.enemies) {
      e.hp = e.maxHp = 99999;
    }
    for (final p in s.party) {
      p
        ..maxMp = 999
        ..mp = 999
        ..hp = p.maxHp = 99999;
    }
    s.party.first.skillIds = [...s.party.first.skillIds, 'prisa', 'apuntar'];
    for (final MapEntry(:key, :value) in speeds.entries) {
      s.byId(key)!.speed = value;
    }
    return s;
  }

  List<String> rest(BattleState s) => [for (final c in s.roundRemaining) c.id];
  List<String> block(BattleState s) => [for (final p in s.pendingGroup) p.id];

  /// Runs the turns until a player block waits for commands.
  BattleState toBlock(BattleState s) {
    for (var i = 0; i < 20 && !s.awaitingGroup; i++) {
      s = s.current != null && !s.current!.isPlayer
          ? engine.enemyTurn(s)!.state
          : engine.nextTurn(s).state;
    }
    return s;
  }

  group('Por rondas', () {
    test('Prisa on an ally still to act: it acts next', () {
      var s = start(TurnRule.porRonda,
          {'p0': 50, 'e0': 40, 'p1': 30, 'e1': 1});
      s = engine.nextTurn(s).state;
      expect(rest(s), ['p0', 'e0', 'p1', 'e1']);
      s = engine.command(s, 'p0', const SkillCommand('prisa'))!.state;
      expect(rest(s), ['p1', 'e0', 'e1']);
      expect(block(s), ['p1'], reason: 'its turn already started');
      expect(s.hasteNext, isEmpty);
      s = engine.command(s, 'p1', const DefendCommand())!.state;
      s = engine.nextTurn(s).state;
      expect(s.current!.id, 'e0');
    });

    test('Prisa can form a block (shared coop queue)', () {
      var s = start(TurnRule.porRonda,
          {'p0': 50, 'p1': 45, 'e0': 40, 'p2': 30, 'e1': 1},
          players: 3);
      s = engine.nextTurn(s).state;
      expect(block(s), ['p0', 'p1']);
      final pulse = s.byId('p1')!.pulse;
      s = engine.command(s, 'p0', const SkillCommand('prisa'))!.state;
      expect(block(s), ['p1', 'p2']);
      expect(rest(s), ['p1', 'p2', 'e0', 'e1']);
      expect(s.byId('p1')!.pulse, pulse, reason: 'p1 does not restart');
      // Any order inside the block.
      s = engine.command(s, 'p2', const DefendCommand())!.state;
      s = engine.command(s, 'p1', const DefendCommand())!.state;
      s = engine.nextTurn(s).state;
      expect(s.current!.id, 'e0');
    });

    test('Prisa on someone who already acted: first next round', () {
      var s = start(TurnRule.porRonda,
          {'p1': 60, 'p0': 50, 'e0': 40, 'e1': 1});
      s = engine.nextTurn(s).state;
      s = engine.command(s, 'p1', const DefendCommand())!.state;
      s = engine.command(s, 'p0', const SkillCommand('prisa'))!.state;
      expect(s.hasteNext, ['p1']);
      // Rest of the round.
      for (var i = 0; i < 2; i++) {
        s = engine.nextTurn(s).state;
        s = engine.enemyTurn(s)!.state;
      }
      s.byId('p1')!.speed = 1; // even slower now, it opens the round
      s = engine.nextTurn(s).state;
      expect(s.round, 2);
      expect(s.roundOrder.first, 'p1');
      expect(s.hasteNext, isEmpty);
    });

    test('self-haste: acts first next round, in speed order', () {
      var s = start(TurnRule.porRonda,
          {'p1': 60, 'p0': 50, 'e0': 40, 'e1': 1});
      // e1 hasted itself too (enemy side): both lead, by speed.
      s = engine.nextTurn(s).state;
      s = engine.command(s, 'p1', const DefendCommand())!.state;
      s = engine.command(s, 'p0', const SkillCommand('apuntar'))!.state;
      expect(s.hasteNext, ['p0']);
      s.hasteNext.add('e1');
      final j = jsonDecode(jsonEncode(const SessionJson().battleStateToJson(s)));
      s = const SessionJson().battleStateFromJson(asJson(j));
      expect(s.hasteNext, ['p0', 'e1']);
      for (var i = 0; i < 2; i++) {
        s = engine.nextTurn(s).state;
        s = engine.enemyTurn(s)!.state;
      }
      s = engine.nextTurn(s).state;
      expect(s.round, 2);
      expect(s.roundOrder.take(2), ['p0', 'e1']);
      expect(s.roundOrder.skip(2), ['p1', 'e0']);
    });

    test('enemy haste (Distorsión): the boss opens the next round', () {
      var s = start(TurnRule.porRonda, {'p0': 50, 'p1': 45},
          enemies: ['golemAbismo']);
      s.enemies.first.speed = 1;
      var warped = false;
      for (var i = 0; i < 60 && !warped; i++) {
        s.enemies.first.ult = 0;
        if (s.awaitingGroup) {
          s = engine.command(s, s.pendingGroup.first.id, const DefendCommand())!
              .state;
        } else if (s.current != null && !s.current!.isPlayer) {
          final step = engine.enemyTurn(s)!;
          warped = step.events.any((e) =>
              e is BossMechanicEvent && e.phase == BossMechanicPhase.timeWarp);
          s = step.state;
        } else {
          s = engine.nextTurn(s).state;
        }
      }
      expect(warped, isTrue);
      expect(s.hasteNext, ['e0']);
      final round = s.round;
      s = engine.nextTurn(s).state;
      expect(s.round, round + 1);
      expect(s.roundOrder.first, 'e0');
      expect(s.current!.id, 'e0');
    });
  });

  group('Por fases', () {
    test('Prisa stays within the phase; a pending haste opens its phase', () {
      var s = start(TurnRule.porFases, {});
      s = toBlock(s);
      expect(s.awaitingGroup, isTrue);
      // A player's Prisa never reorders the shared player phase.
      s = engine.command(s, 'p0', const SkillCommand('prisa'))!.state;
      expect(s.roundOrder, isEmpty);
      expect(block(s), ['p1']);
      s = engine.command(s, 'p1', const DefendCommand())!.state;
      // Enemy phase of round 2: e1 hasted after acting last round opens it.
      s.hasteNext.add('e1');
      s = engine.nextTurn(s).state;
      expect(s.round, 2);
      expect(s.current!.id, 'e1');
      s = engine.enemyTurn(s)!.state;
      s = engine.nextTurn(s).state;
      expect(s.current!.id, 'e0');
    });
  });

  test('timeline: Prisa only moves the clock, no round reorder', () {
    var s = start(TurnRule.velocidad, {'p0': 999});
    s = engine.nextTurn(s).state;
    expect(s.currentId, 'p0');
    final before = s.byId('p1')!.nextTurn;
    s = engine.command(s, 'p0', const SkillCommand('prisa'))!.state;
    expect(s.byId('p1')!.nextTurn, lessThan(before));
    expect(s.roundOrder, isEmpty);
    expect(s.hasteNext, isEmpty);
  });
}
