import 'dart:async';
import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/protocol_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Un cliente "a mano": anota lo que el host le manda y confirma solo
/// cuando el test lo pide (una conexión lenta).
class _SlowLink implements PeerLink {
  final sent = <String>[];
  final incomingCtl = StreamController<String>();

  @override
  void send(String text) => sent.add(text);

  @override
  Stream<String> get incoming => incomingCtl.stream;

  @override
  Future<void> close() async => incomingCtl.close();

  List<Map<String, Object?>> get states => [
        for (final t in sent)
          if (jsonDecode(t) case final Map<String, Object?> m
              when m['t'] == 'state')
            m,
      ];
}

class _Host extends ProtocolNetSession {
  void Function(PeerLink)? onPeer;

  @override
  Future<String> openRoom(void Function(PeerLink link) onPeer) async {
    this.onPeer = onPeer;
    return 'SLOW1';
  }

  @override
  Future<PeerLink> joinRoom(String code) => throw UnimplementedError();

  @override
  Future<void> closeTransport() async {}
}

/// Control de flujo (docs/specs/netcode.md § "Control de flujo",
/// protocolo 12).
void main() {
  test('sin confirmar, el host no amontona: saltea y guarda los eventos',
      () async {
    final host = _Host();
    await host.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    final link = _SlowLink();
    host.onPeer!(link);
    link.incomingCtl.add(host.codec.encode(HelloMessage(
        newProfile('Ana', 'maga'),
        balance: host.balanceHash)));
    await pumpEventQueue();
    final e = sessionEngine();
    var s = e.create();
    s = e.addPlayer(s, 'h', newProfile('Host', 'guerrero'))!.state;
    s = e.addPlayer(s, 'p1', newProfile('Ana', 'maga'))!.state;

    // 10 envíos sin ninguna confirmación: solo viajan maxInFlight.
    for (var i = 0; i < 10; i++) {
      host.broadcast(s, [SystemMessageEvent('m$i')]);
    }
    expect(link.states, hasLength(ProtocolNetSession.maxInFlight));
    expect(host.skippedStates, 10 - ProtocolNetSession.maxInFlight);

    // Confirma todo: el próximo sale con los eventos salteados.
    final last = link.states.last['q']! as int;
    link.incomingCtl.add(host.codec.encode(AckMessage(last)));
    await pumpEventQueue();
    host.broadcast(s, [const SystemMessageEvent('nuevo')]);
    expect(link.states, hasLength(ProtocolNetSession.maxInFlight + 1));
    final ev = [
      for (final x in link.states.last['ev']! as List)
        (x as Map<String, Object?>)['txt'],
    ];
    expect(ev, [
      for (var i = ProtocolNetSession.maxInFlight; i < 10; i++) 'm$i',
      'nuevo',
    ]);
    await host.disconnect();
  });

  test('un cliente real confirma solo: nunca se saltea', () async {
    final hub = LoopbackHub();
    final host = LoopbackNetSession(hub);
    await host.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    final ana = LoopbackNetSession(hub);
    await ana.connect(SessionConfig(
        profile: newProfile('Ana', 'maga'), roomCode: host.roomCode));
    final got = <SnapshotEvent>[];
    ana.events.listen((e) {
      if (e is SnapshotEvent) got.add(e);
    });
    final e = sessionEngine();
    var s = e.create();
    s = e.addPlayer(s, 'h', newProfile('Host', 'guerrero'))!.state;
    s = e.addPlayer(s, 'p1', newProfile('Ana', 'maga'))!.state;
    for (var i = 0; i < 30; i++) {
      host.broadcast(s, const []);
      await pumpEventQueue();
    }
    expect(got, hasLength(30));
    expect(host.skippedStates, 0);
    await ana.disconnect();
    await host.disconnect();
  });

  test('ack ida y vuelta; state lleva su número', () {
    final codec = WireCodec();
    expect((codec.decode(codec.encode(const AckMessage(7))) as AckMessage).seq,
        7);
    final s = GameSession();
    final m = codec.decode(WireCodec.stateText(
            codec.stateBody(s), '[]', const {},
            seq: 42),
        profiles: {}) as StateMessage;
    expect(m.seq, 42);
  });
}
