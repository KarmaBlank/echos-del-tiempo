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

  test('Por rondas: an intent waits for the speed order', () {
    final e = sessionEngine();
    var s = fight(e, CombatMode.rounds);
    var queuedSomeone = false;
    var resolved = false;
    for (var i = 0; i < 6000 && !resolved; i++) {
      sturdy(s);
      final b = s.battle!;
      final st = b.state;
      if (!queuedSomeone && b.queue.isEmpty) {
        final block = {for (final c in st.pendingGroup) c.id};
        final later = [
          for (final c in st.roundRemaining)
            if (c.isPlayer && !c.isSummon && !block.contains(c.id)) c.id
        ];
        if (later.isNotEmpty && st.roundRemaining.first.id != later.first) {
          final who = later.first;
          final step = e.apply(s, who, const BattleAction(DefendCommand()));
          expect(step, isNotNull, reason: 'intent of $who refused');
          s = step!.state;
          expect(s.battle!.queue.single.playerId, who);
          queuedSomeone = true;
          continue;
        }
      }
      if (queuedSomeone && b.queue.isNotEmpty) {
        final who = b.queue.single.playerId;
        final next = e.tick(s, 0.05).state;
        if (next.battle!.queue.isEmpty &&
            next.battle!.state.acted.contains(who)) {
          // Everybody ahead in the round order had already acted.
          final order = st.roundOrder;
          for (final id in order.sublist(0, order.indexOf(who))) {
            final c = st.byId(id);
            if (c != null && c.alive) expect(st.acted, contains(id));
          }
          resolved = true;
        }
        s = next;
        continue;
      }
      if (b.waitingForPlayer && st.awaitingGroup) {
        final who = st.pendingGroup.first.id;
        final step = e.apply(s, who, const BattleAction(DefendCommand()));
        if (step != null) {
          s = step.state;
          continue;
        }
      }
      s = e.tick(s, 0.05).state;
    }
    expect(queuedSomeone, isTrue);
    expect(resolved, isTrue);
  });
}
