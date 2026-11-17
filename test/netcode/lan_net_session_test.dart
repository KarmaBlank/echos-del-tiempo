import 'dart:async';

import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/lan/lan_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/protocol_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Sockets reales en localhost: host (HttpServer + WebSocket) y cliente
/// en el mismo proceso. Ver docs/specs/netcode.md § "LAN".
void main() {
  const timeout = Duration(seconds: 10);

  test('código IP:PUERTO', () {
    expect(LanNetSession.parseCode('192.168.1.23:47800'), ('192.168.1.23', 47800));
    expect(LanNetSession.parseCode(' 10.0.0.5 '), ('10.0.0.5', LanNetSession.defaultPort));
    expect(LanNetSession.parseCode('localhost:1234'), ('localhost', 1234));
    expect(LanNetSession.parseCode('1.2.3.4:abc'), isNull);
    expect(LanNetSession.parseCode(''), isNull);
  });

  test('unirse, una acción y un snapshot por WebSocket en localhost', () async {
    final host = LanNetSession(
        port: 0, advertisedHost: '127.0.0.1', bindLoopbackOnly: true);
    final client = LanNetSession();
    addTearDown(() async {
      await client.disconnect();
      await host.disconnect();
    });

    await host.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    final code = host.roomCode!;
    expect(code, startsWith('127.0.0.1:'));
    final hostEvents = StreamIterator(host.events);

    await client
        .connect(SessionConfig(profile: newProfile('Ana', 'maga'), roomCode: code))
        .timeout(timeout);
    expect(client.localId, 'p1');
    expect(client.roomCode, code);

    // Unirse.
    expect(await hostEvents.moveNext().timeout(timeout), isTrue);
    final joined = hostEvents.current as PeerJoinedEvent;
    expect(joined.peerId, 'p1');
    expect(joined.profile.name, 'Ana');

    // Una acción.
    client.sendAction(const MoveAction(10.5, 20, epoch: 2, moving: true));
    expect(await hostEvents.moveNext().timeout(timeout), isTrue);
    final act = hostEvents.current as PeerActionEvent;
    expect(act.peerId, 'p1');
    final move = act.action as MoveAction;
    expect([move.x, move.y, move.epoch, move.moving], [10.5, 20.0, 2, true]);

    // Un snapshot.
    final e = sessionEngine();
    var s = e.addPlayer(e.create(), 'h', newProfile('Host', 'guerrero'))!.state;
    s = e.addPlayer(s, 'p1', joined.profile)!.state;
    final clientEvents = StreamIterator(client.events);
    host.broadcast(s, const [SystemMessageEvent('Ana se unió a la sala.')]);
    expect(await clientEvents.moveNext().timeout(timeout), isTrue);
    final snap = clientEvents.current as SnapshotEvent;
    expect(snap.session.players.keys, ['h', 'p1']);
    expect(snap.session.players['p1']!.profile.classId, 'maga');
    expect((snap.events.single as SystemMessageEvent).text,
        'Ana se unió a la sala.');

    // El host cierra: el cliente se entera.
    await host.disconnect();
    expect(await clientEvents.moveNext().timeout(timeout), isTrue);
    expect((clientEvents.current as ConnectionLostEvent).reason,
        ProtocolNetSession.lostMessage);
  });

  test('sin sala en esa dirección → NetException', () async {
    final client = LanNetSession();
    addTearDown(client.disconnect);
    // Puerto 1 en localhost: nadie escucha.
    await expectLater(
        client.connect(SessionConfig(
            profile: newProfile('Ana', 'maga'), roomCode: '127.0.0.1:1')),
        throwsA(isA<NetException>()));
  });
}
