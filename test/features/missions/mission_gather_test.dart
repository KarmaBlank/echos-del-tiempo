import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Mission gathering over the network (free_movement.md § 2.1.1):
/// PROPONER opens it, a client joins, IR puts both in the same instance.
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

  final ana = progression
      .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'));
  final beto =
      progression.normalize(PlayerProfile(name: 'Beto', classId: 'maga'));

  test('host proposes, client joins, IR puts both in the same dungeon',
      () async {
    final hub = LoopbackHub();
    final hn = LoopbackNetSession(hub);
    final cn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: ana));
    final host = make(hn, ana);
    await host.start();
    await cn.connect(SessionConfig(profile: beto, roomCode: hn.roomCode));
    final client = make(cn, beto);
    await client.start();
    final all = [host, client];
    await tick(all);
    await tick(all);

    expect(host.proposeMission('m1'), isTrue);
    await tick(all);
    expect(host.session!.mode, SessionMode.lobby, reason: 'waits for IR');
    final g = client.session!.gather;
    expect(g?.byId, host.localId);
    expect(g?.missionId, 'm1');
    expect(client.view!.chat.any((l) => l.text.contains('convoca a')), isTrue);

    expect(client.gather(GatherOp.join), isTrue);
    await tick(all);
    expect(host.session!.gather!.has(client.localId), isTrue);

    expect(host.gather(GatherOp.go), isTrue);
    await tick(all);
    await tick(all);
    expect(host.session!.mode, SessionMode.field);
    expect(client.session!.mode, SessionMode.field);
    expect(host.session!.players.keys,
        containsAll([host.localId, client.localId]));
    expect(client.session!.players.keys,
        containsAll([host.localId, client.localId]));
    expect(host.session!.gather, isNull);
  });

  test('solo: PROPONER goes straight in', () async {
    final me = make(null, ana);
    await me.start();
    await tick([me]);
    expect(me.proposeMission('m1'), isTrue);
    await tick([me]);
    expect(me.session!.mode, SessionMode.field);
    expect(me.session!.gather, isNull);
  });
}
