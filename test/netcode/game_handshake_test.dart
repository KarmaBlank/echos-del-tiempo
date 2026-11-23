import 'dart:convert';

import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Un protocolo por juego (docs/specs/netcode.md § "Un protocolo por
/// juego"): Mundo y Travesía no comparten salas.
void main() {
  test('Mundo en 57 (v0.33.0: movimiento libre por jugador) y Travesía arranca su secuencia en 1', () {
    expect(WireGame.mundo.protocol, 57);
    expect(kProtocolVersion, 57);
    expect(WireGame.travesia.protocol, 4);
    expect(WireGame.mundo.id, isNot(WireGame.travesia.id));
  });

  test('hello lleva g; uno viejo sin g se decodifica como null', () {
    final codec = WireCodec();
    final p = newProfile('Ana', 'maga');
    final t = codec.encode(HelloMessage(p,
        game: 'travesia', version: kTravesiaProtocolVersion));
    expect(jsonDecode(t)['g'], 'travesia');
    expect((codec.decode(t) as HelloMessage).game, 'travesia');
    final old = Map<String, Object?>.from(
        jsonDecode(codec.encode(HelloMessage(p))) as Map)
      ..remove('g');
    expect((codec.decode(jsonEncode(old)) as HelloMessage).game, isNull);
  });

  test('reject game nombra el juego del host', () {
    const r = RejectMessage(RejectReason.game, game: 'travesia');
    expect(r.text, contains('Ecos del Tiempo: Travesía'));
    final codec = WireCodec();
    final back = codec.decode(codec.encode(r)) as RejectMessage;
    expect(back.reason, RejectReason.game);
    expect(back.game, 'travesia');
  });

  group('sala por loopback', () {
    late LoopbackHub hub;
    final opened = <NetSession>[];
    setUp(() => hub = LoopbackHub());
    tearDown(() async {
      for (final n in opened) {
        await n.disconnect();
      }
      opened.clear();
    });

    Future<LoopbackNetSession> open(WireGame g, {String? code}) async {
      final n = LoopbackNetSession(hub, game: g);
      opened.add(n);
      await n.connect(SessionConfig(
          profile: newProfile(code == null ? 'Host' : 'Ana', 'guerrero'),
          roomCode: code));
      return n;
    }

    test('mismo juego entra', () async {
      final h = await open(WireGame.travesia);
      final ok = await open(WireGame.travesia, code: h.roomCode);
      expect(ok.localId, 'p1');
    });

    test('Mundo no entra a una sala de Travesía', () async {
      final h = await open(WireGame.travesia);
      await expectLater(
          open(WireGame.mundo, code: h.roomCode),
          throwsA(isA<NetException>().having((e) => e.message, 'message',
              contains('Ecos del Tiempo: Travesía'))));
    });

    test('Travesía no entra a una sala de Mundo', () async {
      final h = await open(WireGame.mundo);
      await expectLater(
          open(WireGame.travesia, code: h.roomCode),
          throwsA(isA<NetException>().having((e) => e.message, 'message',
              contains('«Ecos del Tiempo»'))));
    });
  });
}
