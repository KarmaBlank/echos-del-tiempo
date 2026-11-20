import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';

import '../../game_engine/session_test_helpers.dart';

/// Sala de [n] jugadores por loopback (host + clientes con el protocolo
/// real), ya en el campo de la misión `m1`. Devuelve todos los
/// controladores (el host primero) y un "frame" de red.
Future<(List<SessionController>, Future<void> Function([double]))> bigRoom(
    int n,
    {int max = 12}) async {
  const classes = ['guerrero', 'maga', 'tirador', 'paladin'];
  const names = ['Ana', 'Leo', 'Mia', 'Cid', 'Bea', 'Tomás', 'Uma', 'Rocío',
      'Iván', 'Sol', 'Noa', 'Eli'];
  final hub = LoopbackHub();
  final all = <SessionController>[];
  Future<SessionController> make(NetSession net, ProfileStore store) async {
    final c = SessionController(
      engine: sessionEngine(maxPlayers: max),
      store: store,
      clock: const SessionClock(autoStart: false),
      net: net,
    );
    all.add(c);
    await c.start();
    return c;
  }

  final hn = LoopbackNetSession(hub, maxPlayers: max);
  final hp = newProfile(names[0], classes[0]);
  await hn.connect(SessionConfig(profile: hp));
  final host = await make(hn, InMemoryProfileStore(hp));
  for (var i = 1; i < n; i++) {
    final cn = LoopbackNetSession(hub, maxPlayers: max);
    final p = newProfile(names[i % names.length], classes[i % classes.length]);
    await cn.connect(SessionConfig(profile: p, roomCode: hn.roomCode));
    await make(cn, InMemoryProfileStore(p));
  }
  Future<void> net([double seconds = 0.05]) async {
    for (final c in all.skip(1)) {
      c.advance(0.05);
    }
    await Future<void>.delayed(Duration.zero);
    host.advance(seconds);
    await Future<void>.delayed(Duration.zero);
  }

  await net();
  host.proposeMission('m1');
  await net();
  for (final c in all) {
    c.vote(true);
  }
  await net(0.1);
  for (final c in all) {
    c.setReady(true);
  }
  await net(0.1);
  await net();
  assert(host.session!.mode == SessionMode.field);
  return (all, net);
}
