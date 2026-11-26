import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Co-op mission entry over the network (v0.49.20, free_movement.md
/// § 2.1): no gathering or countdown. PROPONER enters at once; the others
/// join the running mission with UNIRSE on that player's card.
void main() {
  final controllers = <SessionController>[];

  tearDown(() {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
  });

  SessionController make(NetSession? net, PlayerProfile p) {
    final c = SessionController(
      engine: sessionEngine(freeMovement: true),
      store: InMemoryProfileStore(p),
      clock: const SessionClock(autoStart: false),
      net: net,
    );
    controllers.add(c);
    return c;
  }

  Future<void> tick(List<SessionController> all) async {
    for (final c in all.skip(1)) {
      c.advance(0.05);
    }
    await pumpEventQueue();
    all.first.advance(0.05);
    await pumpEventQueue();
  }

  for (final names in const [
    ['Ana', 'Beto', 'Héroe'],
    ['Ana', 'Héroe', 'Héroe'],
  ]) {
    test(
        '3 humans (${names.join(', ')}): a client enters at once, '
        'the others join with UNIRSE', () async {
      final ps = [
        for (final n in names)
          progression.normalize(PlayerProfile(name: n, classId: 'guerrero'))
      ];
      final hub = LoopbackHub();
      final hn = LoopbackNetSession(hub);
      await hn.connect(SessionConfig(profile: ps[0]));
      final host = make(hn, ps[0]);
      await host.start();
      final clients = <SessionController>[];
      for (final p in ps.skip(1)) {
        final cn = LoopbackNetSession(hub);
        await cn.connect(SessionConfig(profile: p, roomCode: hn.roomCode));
        final c = make(cn, p);
        await c.start();
        clients.add(c);
      }
      final all = [host, ...clients];
      await tick(all);
      await tick(all);

      final caller = clients.first;
      expect(caller.proposeMission('m1'), isTrue);
      await tick(all);
      await tick(all);
      expect(caller.session!.mode, SessionMode.field, reason: 'no countdown');
      expect(host.session!.mode, SessionMode.lobby);

      for (final c in [host, clients.last]) {
        final card =
            c.session!.away.firstWhere((a) => a.id == caller.localId);
        expect(c.joinPlayerBlock(card), isNull);
        expect(c.joinPlayer(card), isTrue);
        await tick(all);
        await tick(all);
        expect(c.session!.mode, SessionMode.field, reason: c.localId);
      }
      expect(host.session!.players.keys,
          containsAll([for (final c in all) c.localId]));
      // The arrival grace runs out on every screen (nothing lingers).
      for (var i = 0; i < 80; i++) {
        await tick(all);
      }
      for (final c in all) {
        expect(c.session!.graceLeft, 0, reason: c.localId);
      }
    });
  }

  test('solo: PROPONER goes straight in', () async {
    final me = make(
        null,
        progression
            .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero')));
    await me.start();
    await tick([me]);
    expect(me.proposeMission('m1'), isTrue);
    await tick([me]);
    expect(me.session!.mode, SessionMode.field);
  });
}
