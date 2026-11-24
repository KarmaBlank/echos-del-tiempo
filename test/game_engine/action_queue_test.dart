import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/combat_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Action queue (turn_modes.md § 3.1).
void main() {
  /// A 3-player fight in [mode] with sturdy enemies and party.
  GameSession fight(SessionEngine e, CombatMode mode) {
    var s = inField(e, 'm1',
        classes: ['guerrero', 'maga', 'guerrero'], mode: mode);
    s = wait(e, s, 2.6);
    final en = s.mission!.enemies.firstWhere((x) => !x.boss && !x.elite);
    s = moveTo(e, s, 'p0', en.x, en.y);
    s = e.tick(s, 0.05).state;
    expect(s.mode, SessionMode.battle);
    return s;
  }

  void sturdy(GameSession s) {
    for (final c in [...s.battle!.state.party, ...s.battle!.state.enemies]) {
      c.hp = c.maxHp * 50;
    }
  }

  /// Ticks until the party phase opens with everybody pending.
  GameSession partyPhase(SessionEngine e, GameSession s) {
    for (var i = 0; i < 4000; i++) {
      final b = s.battle!;
      sturdy(s);
      if (b.waitingForPlayer &&
          b.state.awaitingGroup &&
          b.state.pendingGroup.length == 3) {
        return s;
      }
      s = e.tick(s, 0.05).state;
    }
    fail('no party phase');
  }

  group('Por fases', () {
    test('queue keeps arrival order, cancel and change in place', () {
      final e = sessionEngine();
      var s = partyPhase(e, fight(e, CombatMode.phases));
      // p0 acts at once; the host animates (wait > 0).
      s = act(e, s, 'p0', const BattleAction(DefendCommand()));
      expect(s.battle!.wait, greaterThan(0));
      expect(s.battle!.queue, isEmpty);
      // While it animates p2 then p1 confirm: both queue, in that order.
      s = act(e, s, 'p2', const BattleAction(DefendCommand()));
      s = act(e, s, 'p1', const BattleAction(AttackCommand()));
      expect([for (final q in s.battle!.queue) q.playerId], ['p2', 'p1']);
      // p0 already acted: refused.
      expect(e.apply(s, 'p0', const BattleAction(DefendCommand())), isNull);
      // Change in place keeps the position.
      s = act(e, s, 'p2', const BattleAction(AttackCommand()));
      expect([for (final q in s.battle!.queue) q.playerId], ['p2', 'p1']);
      expect(s.battle!.queue.first.command, isA<AttackCommand>());
      // Cancel and re-queue: goes to the back.
      s = act(e, s, 'p2', const CancelQueuedBattleAction());
      expect([for (final q in s.battle!.queue) q.playerId], ['p1']);
      s = act(e, s, 'p2', const BattleAction(DefendCommand()));
      expect([for (final q in s.battle!.queue) q.playerId], ['p1', 'p2']);
      // Travels in the snapshot.
      const j = SessionJson();
      final seen = j.fromJson(asJson(jsonDecode(jsonEncode(j.toJson(s)))));
      expect([for (final q in seen.battle!.queue) q.playerId], ['p1', 'p2']);
      expect(seen.battle!.queue.first.command, isA<AttackCommand>());
      final un = ActionJson.fromJson(
          asJson(jsonDecode(jsonEncode(
              ActionJson.toJson(const CancelQueuedBattleAction())))));
      expect(un, isA<CancelQueuedBattleAction>());

      // Resolves one by one, in queue order, each with its own pause.
      final order = <String>[];
      for (var i = 0; i < 400 && s.battle!.queue.isNotEmpty; i++) {
        final before = {...s.battle!.state.acted};
        s = e.tick(s, 0.05).state;
        final now = s.battle?.state.acted ?? const <String>{};
        final added = now.difference(before);
        if (added.isNotEmpty) {
          expect(s.battle!.wait, greaterThan(0));
          order.addAll(added);
        }
      }
      expect(order, ['p1', 'p2']);
    });

    test('dead target: the queued attack retargets to a living enemy', () {
      final e = sessionEngine();
      var s = partyPhase(e, fight(e, CombatMode.phases));
      final enemies = s.battle!.state.enemies;
      if (enemies.length < 2) {
        // Make room for a second target.
        return markTestSkipped('single-enemy encounter');
      }
      final doomed = enemies.first.id;
      s = act(e, s, 'p0', const BattleAction(DefendCommand()));
      s = act(e, s, 'p1', BattleAction(AttackCommand(targetId: doomed)));
      expect(s.battle!.queue.single.playerId, 'p1');
      s.battle!.state.byId(doomed)!.hp = 0;
      for (var i = 0; i < 400 && s.battle!.queue.isNotEmpty; i++) {
        s = e.tick(s, 0.05).state;
      }
      expect(s.battle!.state.acted, contains('p1'));
    });

    test('duo: partner queued is busy', () {
      final e = sessionEngine();
      var s = partyPhase(e, fight(e, CombatMode.phases));
      s = act(e, s, 'p0', const BattleAction(DefendCommand()));
      s = act(e, s, 'p1', const BattleAction(DefendCommand()));
      expect(e.apply(s, 'p2', const BattleAction(DualCommand('p1'))), isNull);
      expect(e.apply(s, 'p2', const BattleAction(DualCommand('p0'))), isNull);
    });
  });

  test('Por fases: queue only with 2+ humans', () {
    final e = sessionEngine();
    expect(battleQueueEnabled(fight(e, CombatMode.phases)), isTrue);
    var s = inField(e, 'm1', classes: ['guerrero'], mode: CombatMode.phases);
    s = wait(e, s, 2.6);
    final en = s.mission!.enemies.firstWhere((x) => !x.boss && !x.elite);
    s = moveTo(e, s, 'p0', en.x, en.y);
    s = e.tick(s, 0.05).state;
    expect(battleQueueEnabled(s), isFalse);
  });

  /// Ticks until [who] may act now in Por rondas (its block or turn).
  GameSession turnOf(SessionEngine e, GameSession s, String who) {
    for (var i = 0; i < 6000; i++) {
      sturdy(s);
      final b = s.battle!;
      final st = b.state;
      if (b.waitingForPlayer &&
          (st.currentId == who ||
              st.awaitingGroup && st.pendingGroup.any((c) => c.id == who))) {
        return s;
      }
      if (b.waitingForPlayer && st.awaitingGroup) {
        final other = st.pendingGroup.first.id;
        final step = e.apply(s, other, const BattleAction(DefendCommand()));
        if (step != null) {
          s = step.state;
          continue;
        }
      }
      s = e.tick(s, 0.05).state;
    }
    fail('no turn for $who');
  }

  /// Por rondas coop: ticks to a front block with nobody acted yet, then
  /// rewrites what remains of the round as [order] (ids; 'E' = the first
  /// living enemy, 'F' = the second one or the first again).
  GameSession roundsWith(SessionEngine e, List<String> order) {
    var s = fight(e, CombatMode.rounds);
    for (var i = 0; i < 6000; i++) {
      sturdy(s);
      final b = s.battle!;
      final st = b.state;
      if (b.wait <= 0 &&
          b.waitingForPlayer &&
          st.awaitingGroup &&
          b.queue.isEmpty &&
          ['p0', 'p1', 'p2'].every((id) => !st.acted.contains(id))) {
        final foes = [for (final x in st.enemies) if (x.alive) x.id];
        final ids = [
          for (final o in order)
            o == 'E'
                ? foes.first
                : o == 'F'
                    ? foes.last
                    : o
        ];
        final rest = [
          for (final id in st.roundOrder)
            if (!ids.contains(id)) id
        ];
        st.roundOrder
          ..clear()
          ..addAll([...ids, ...rest]);
        st.acted.removeWhere(ids.contains);
        return s;
      }
      if (b.waitingForPlayer && st.awaitingGroup) {
        final step = e.apply(
            s, st.pendingGroup.first.id, const BattleAction(DefendCommand()));
        if (step != null) {
          s = step.state;
          continue;
        }
      }
      s = e.tick(s, 0.05).state;
    }
    fail('no fresh round block');
  }

  /// Ticks until the queue is empty; returns players in the order they
  /// acted, and fails if an enemy acts before [before] acted.
  List<String> drain(SessionEngine e, GameSession Function() get,
      void Function(GameSession) set, String before) {
    final order = <String>[];
    var s = get();
    final enemies = {for (final x in s.battle!.state.enemies) x.id};
    for (var i = 0; i < 400 && s.battle!.queue.isNotEmpty; i++) {
      final was = {...s.battle!.state.acted};
      s = e.tick(s, 0.05).state;
      final added = s.battle!.state.acted.difference(was);
      if (!order.contains(before)) {
        expect(added.intersection(enemies), isEmpty,
            reason: 'enemy acted inside the block');
      }
      order.addAll(added.where((id) => !enemies.contains(id)));
    }
    set(s);
    return order;
  }

  group('Por rondas coop', () {
    test('block of 2: both queue, arrival order, no enemy in between', () {
      final e = sessionEngine();
      var s = roundsWith(e, ['p0', 'p1', 'E', 'p2']);
      expect(battleQueueEnabled(s), isTrue);
      expect([for (final c in s.battle!.state.pendingGroup) c.id],
          ['p0', 'p1']);
      s = act(e, s, 'p0', const BattleAction(DefendCommand()));
      expect(s.battle!.wait, greaterThan(0));
      // p1 confirms while p0 animates: queued.
      s = act(e, s, 'p1', const BattleAction(DefendCommand()));
      expect([for (final q in s.battle!.queue) q.playerId], ['p1']);
      // p2 is behind an enemy: refused, not queued.
      expect(e.apply(s, 'p2', const BattleAction(DefendCommand())), isNull);
      final order = drain(e, () => s, (x) => s = x, 'p1');
      expect(order, ['p1']);
      expect(s.battle!.state.acted, containsAll(['p0', 'p1']));
    });

    test('enemy between: the second player waits for their own turn', () {
      final e = sessionEngine();
      var s = roundsWith(e, ['p0', 'E', 'p1', 'p2']);
      expect([for (final c in s.battle!.state.pendingGroup) c.id], ['p0']);
      s = act(e, s, 'p0', const BattleAction(DefendCommand()));
      expect(e.apply(s, 'p1', const BattleAction(DefendCommand())), isNull);
      expect(s.battle!.queue, isEmpty);
    });

    test('player 1 delays the enemy between 2 and 3: they queue a combo',
        () {
      final e = sessionEngine();
      var s = roundsWith(e, ['p0', 'p1', 'E', 'p2']);
      final st = s.battle!.state;
      final foe = st.roundOrder[2];
      // Owner's case: p0 acts first, the enemy sits between p1 and p2.
      st.byId('p0')!
        ..skillIds = [...st.byId('p0')!.skillIds, 'grietaTemporal']
        ..mp = 999;
      // Order: p0, p1, E, p2 (p2 cut off by the enemy).
      expect([for (final c in s.battle!.state.pendingGroup) c.id],
          ['p0', 'p1']);
      s = act(e, s, 'p0',
          BattleAction(SkillCommand('grietaTemporal', targetId: foe)));
      if (s.battle!.state.byId('p0')!.chained) {
        s = act(e, s, 'p0', const BattleAction(DefendCommand()));
      }
      // The enemy went to the end: p1 and p2 are the block and queue.
      expect([for (final c in s.battle!.state.pendingGroup) c.id],
          ['p1', 'p2']);
      expect(s.battle!.wait, greaterThan(0));
      s = act(e, s, 'p2', const BattleAction(DefendCommand()));
      s = act(e, s, 'p1', const BattleAction(DefendCommand()));
      expect([for (final q in s.battle!.queue) q.playerId], ['p2', 'p1']);
      final order = drain(e, () => s, (x) => s = x, 'p1');
      expect(order, ['p2', 'p1']);
    });

    test('INSTANT then a skill in a block resolves; partner keeps its entry',
        () {
      final e = sessionEngine();
      var s = roundsWith(e, ['p0', 'p1', 'E', 'p2']);
      final foe = s.battle!.state.enemies.firstWhere((x) => x.alive).id;
      s = act(e, s, 'p0',
          BattleAction(SkillCommand('brasaEco', targetId: foe)));
      expect(s.battle!.state.byId('p0')!.chained, isTrue);
      expect(s.battle!.wait, greaterThan(0));
      // Partner confirms during the INSTANT animation; the actor too.
      s = act(e, s, 'p1', const BattleAction(DefendCommand()));
      s = act(e, s, 'p0', BattleAction(AttackCommand(targetId: foe)));
      final order = drain(e, () => s, (x) => s = x, 'p1');
      // The turn holder's follow-up first, then the partner.
      expect(order, ['p0', 'p1']);
      expect(s.battle!.queue, isEmpty);
    });
  });

  test('Por rondas solo: never a queue', () {
    final e = sessionEngine();
    var s = inField(e, 'm1', classes: ['guerrero'], mode: CombatMode.rounds);
    s = wait(e, s, 2.6);
    final en = s.mission!.enemies.firstWhere((x) => !x.boss && !x.elite);
    s = moveTo(e, s, 'p0', en.x, en.y);
    s = e.tick(s, 0.05).state;
    expect(battleQueueEnabled(s), isFalse);
  });

  test('Por rondas solo: INSTANT then a skill both resolve; no enemy early',
      () {
    final e = sessionEngine();
    var s = inField(e, 'm1', classes: ['guerrero'], mode: CombatMode.rounds);
    s = wait(e, s, 2.6);
    final en = s.mission!.enemies.firstWhere((x) => !x.boss && !x.elite);
    s = moveTo(e, s, 'p0', en.x, en.y);
    s = e.tick(s, 0.05).state;
    expect(s.mode, SessionMode.battle);
    s = turnOf(e, s, 'p0');
    final foe = s.battle!.state.enemies.firstWhere((x) => x.alive).id;
    final enemyIds = {for (final x in s.battle!.state.enemies) x.id};
    final actedBefore = {...s.battle!.state.acted};
    s = act(e, s, 'p0',
        BattleAction(SkillCommand('brasaEco', targetId: foe)));
    expect(s.battle!.state.byId('p0')!.chained, isTrue);
    // While the INSTANT animates: refused, not queued (solo never queues).
    expect(s.battle!.wait, greaterThan(0));
    expect(
        e.apply(s, 'p0', BattleAction(AttackCommand(targetId: foe))), isNull);
    expect(s.battle!.queue, isEmpty);
    // After the animation it is still p0's turn; no enemy acted.
    for (var i = 0; i < 60 && !s.battle!.waitingForPlayer; i++) {
      sturdy(s);
      s = e.tick(s, 0.05).state;
    }
    final st = s.battle!.state;
    expect(s.battle!.waitingForPlayer, isTrue);
    expect(
        st.currentId == 'p0' ||
            st.awaitingGroup && st.pendingGroup.any((c) => c.id == 'p0'),
        isTrue);
    expect(st.acted.difference(actedBefore).intersection(enemyIds), isEmpty);
    // The follow-up runs now.
    s = act(e, s, 'p0', BattleAction(AttackCommand(targetId: foe)));
    expect(s.battle!.state.acted, contains('p0'));
    expect(s.battle!.queue, isEmpty);
  });
}
