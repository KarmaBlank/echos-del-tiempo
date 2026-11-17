import 'dart:async';

import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/protocol_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

void main() {
  late LoopbackHub hub;
  final opened = <NetSession>[];

  Future<LoopbackNetSession> host() async {
    final n = LoopbackNetSession(hub);
    opened.add(n);
    await n.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    return n;
  }

  Future<LoopbackNetSession> join(String code, String name) async {
    final n = LoopbackNetSession(hub);
    opened.add(n);
    await n.connect(
        SessionConfig(profile: newProfile(name, 'maga'), roomCode: code));
    return n;
  }

  setUp(() => hub = LoopbackHub());
  tearDown(() async {
    for (final n in opened) {
      await n.disconnect();
    }
    opened.clear();
  });

  test('host h, clientes p1/p2 con su perfil; acciones con el id del enlace',
      () async {
    final h = await host();
    expect(h.isHost, isTrue);
    expect(h.localId, ProtocolNetSession.hostId);
    expect(h.roomCode, 'LOOP1');
    final hostEvents = <NetEvent>[];
    h.events.listen(hostEvents.add);

    final a = await join('loop1', 'Ana'); // el código no distingue mayúsculas
    final b = await join('LOOP1', 'Bea');
    expect(a.isHost, isFalse);
    expect([a.localId, b.localId], ['p1', 'p2']);
    expect(a.roomCode, 'LOOP1');

    a.sendAction(const ChatAction('hola'));
    await pumpEventQueue();
    final joined = hostEvents.whereType<PeerJoinedEvent>().toList();
    expect(joined.map((e) => e.peerId), ['p1', 'p2']);
    expect(joined.first.profile.name, 'Ana');
    final act = hostEvents.whereType<PeerActionEvent>().single;
    expect(act.peerId, 'p1');
    expect((act.action as ChatAction).text, 'hola');
  });

  test('broadcast llega a cada cliente con estado y eventos', () async {
    final h = await host();
    final a = await join(h.roomCode!, 'Ana');
    final got = <NetEvent>[];
    a.events.listen(got.add);
    final e = sessionEngine();
    final s = e.addPlayer(e.create(), 'h', newProfile('Host', 'guerrero'))!.state;
    h.broadcast(s, const [SystemMessageEvent('hola a todos')]);
    await pumpEventQueue();
    final snap = got.whereType<SnapshotEvent>().single;
    expect(snap.session.players.keys, ['h']);
    expect((snap.events.single as SystemMessageEvent).text, 'hola a todos');
  });

  test('sala llena: el quinto jugador es rechazado', () async {
    final h = await host();
    for (final n in ['A', 'B', 'C']) {
      await join(h.roomCode!, n);
    }
    expect(h.clientCount, 3);
    await expectLater(
        join(h.roomCode!, 'E'),
        throwsA(isA<NetException>()
            .having((e) => e.message, 'message', contains('llena'))));
  });

  test('código inexistente', () async {
    await host();
    await expectLater(join('NOPE', 'Ana'),
        throwsA(isA<NetException>().having((e) => e.message, 'm', contains('no encontrada'))));
  });

  test('cliente que se va → PeerLeft; host que se va → ConnectionLost', () async {
    final h = await host();
    final hostEvents = <NetEvent>[];
    h.events.listen(hostEvents.add);
    final a = await join(h.roomCode!, 'Ana');
    final b = await join(h.roomCode!, 'Bea');
    final bEvents = <NetEvent>[];
    final lost = Completer<ConnectionLostEvent>();
    b.events.listen((e) {
      bEvents.add(e);
      if (e is ConnectionLostEvent) lost.complete(e);
    });

    await a.disconnect();
    await pumpEventQueue();
    expect(hostEvents.whereType<PeerLeftEvent>().single.peerId, 'p1');
    expect(h.clientCount, 1);

    await h.disconnect();
    final e = await lost.future.timeout(const Duration(seconds: 2));
    expect(e.reason, ProtocolNetSession.lostMessage);
    expect(hub.rooms, isEmpty);
  });

  test('basura por el enlace se ignora', () async {
    final h = await host();
    final a = await join(h.roomCode!, 'Ana');
    final hostEvents = <NetEvent>[];
    h.events.listen(hostEvents.add);
    // Un mensaje inválido no corta la sala.
    expect(h.codec.decode('{no es json'), isNull);
    expect(h.codec.decode('{"t":"pos"}'), isNull);
    a.sendAction(const VoteMissionAction(true));
    await pumpEventQueue();
    expect(hostEvents.whereType<PeerActionEvent>(), hasLength(1));
  });
}
