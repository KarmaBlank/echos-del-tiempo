import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/combat_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Action queue over the real protocol (turn_modes.md § 3.1): the client
/// keeps its turn (menu up) while the host's action animates, and its
/// command queues behind it.
void main() {
  late SessionController host, ana;
  final controllers = <SessionController>[];

  Future<SessionController> make(NetSession net, ProfileStore store) async {
    final c = SessionController(
      engine: sessionEngine(),
      store: store,
      clock: const SessionClock(autoStart: false),
      net: net,
      combatMode: CombatMode.phases,
    );
    controllers.add(c);
    await c.start();
    return c;
  }

  Future<void> net([double seconds = 0.05]) async {
    ana.advance(0.05);
    await pumpEventQueue();
    host.advance(seconds);
    await pumpEventQueue();
  }

  tearDown(() async {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
    await pumpEventQueue();
  });

  test('client queues while the host animates; its turn never closes',
      () async {
    final hub = LoopbackHub();
    final hn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    host = await make(hn, InMemoryProfileStore(newProfile('Host', 'guerrero')));
    final an = LoopbackNetSession(hub);
    await an.connect(SessionConfig(
        profile: newProfile('Ana', 'maga'), roomCode: hn.roomCode));
    ana = await make(an, InMemoryProfileStore());
    await net();
    host.setCombatMode(CombatMode.phases);
    await net();

    host.proposeMission('m1');
    await net();
    ana.vote(true);
    await net(0.1);
    host.setReady(true);
    ana.setReady(true);
    await net(0.1);
    expect(host.session!.mode, SessionMode.field);
    await net(host.session!.graceLeft + 0.1);
    final en = host.session!.mission!.enemies
        .firstWhere((e) => e.alive && !e.boss && !e.elite);
    host.teleport(en.x, en.y);
    await net();
    await net();
    expect(host.session!.mode, SessionMode.battle);
    expect(host.session!.battle!.state.porFases, isTrue);

    void sturdy() {
      final b = host.session!.battle!;
      for (final c in [...b.state.party, ...b.state.enemies]) {
        c.hp = c.maxHp * 50;
      }
    }

    // Wait for the party phase with both pending.
    for (var i = 0; i < 2000; i++) {
      sturdy();
      if (host.view!.myTurn && ana.view!.myTurn) break;
      await net();
    }
    expect(host.view!.myTurn, isTrue);
    expect(ana.view!.myTurn, isTrue);

    // The host acts: its action animates.
    expect(host.battleCommand(const DefendCommand()), isTrue);
    // (If the phase opening still animated, it queued first: arrival order.)
    final hostId = host.view!.localId;
    for (var i = 0;
        i < 200 && !host.session!.battle!.state.acted.contains(hostId);
        i++) {
      await net();
    }
    expect(host.session!.battle!.wait, greaterThan(0));
    // Ana's turn stays open while it animates (her menu is not pulled).
    expect(ana.view!.myTurn, isTrue);
    expect(ana.battleCommand(const AttackCommand()), isTrue);
    await net();
    await net();
    final hostQueue = host.session!.battle!.queue;
    final anaId = ana.view!.localId;
    expect([for (final q in hostQueue) q.playerId], [anaId]);
    // The client sees its entry and its menu closes (queued).
    expect(ana.session!.battle!.queued(anaId), isTrue);
    expect(ana.view!.myTurn, isFalse);
    // Then it resolves in order.
    for (var i = 0;
        i < 200 && !host.session!.battle!.state.acted.contains(anaId);
        i++) {
      sturdy();
      await net();
    }
    expect(host.session!.battle!.queue, isEmpty);
  });
}
