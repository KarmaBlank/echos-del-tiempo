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

  test('countdown reaches the client; at 0 both enter; late join by card',
      () async {
    final caro =
        progression.normalize(PlayerProfile(name: 'Caro', classId: 'maga'));
    final hub = LoopbackHub();
    final hn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: ana));
    final host = make(hn, ana);
    await host.start();
    final clients = <SessionController>[];
    for (final p in [beto, caro]) {
      final cn = LoopbackNetSession(hub);
      await cn.connect(SessionConfig(profile: p, roomCode: hn.roomCode));
      final c = make(cn, p);
      await c.start();
      clients.add(c);
    }
    final [client, caroC] = clients;
    final all = [host, ...clients];
    await tick(all);
    await tick(all);

    expect(host.proposeMission('m1'), isTrue);
    await tick(all);
    expect(client.session!.gather!.leftSeconds, greaterThan(15));
    expect(client.gather(GatherOp.join), isTrue);
    await tick(all);
    // IGNORAR is local: the gathering stays for everyone else.
    caroC.ignoreGather();
    expect(caroC.ignoredGather, caroC.session!.gather!.id);
    // Nobody presses ENTRAR YA: the host clock runs it out.
    for (var i = 0; i < 25; i++) {
      host.advance(1);
      await pumpEventQueue();
    }
    await tick(all);
    await tick(all);
    expect(host.session!.mode, SessionMode.field);
    expect(client.session!.mode, SessionMode.field);
    expect(caroC.session!.mode, SessionMode.lobby, reason: 'did not join');
    // UNIRSE on the host's card joins the running mission.
    final card =
        caroC.session!.away.firstWhere((a) => a.id == host.localId);
    expect(caroC.joinPlayerBlock(card), isNull);
    expect(caroC.joinPlayer(card), isTrue);
    await tick(all);
    await tick(all);
    expect(caroC.session!.mode, SessionMode.field);
    expect(host.session!.players.keys, contains(caroC.localId));
  });
}
