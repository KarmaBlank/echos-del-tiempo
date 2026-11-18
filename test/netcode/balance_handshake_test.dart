import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/balance/balance_patch.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_registries.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

GameCatalog _patched(double power) => BalancePatch.parse(
        jsonEncode({
          'schema': 1,
          'overrides': {
            'skill': {
              'sismo': {'power': power}
            }
          },
        }),
        BalanceBase.standard())
    .patch
    .applyTo(GameCatalog.standard);

void main() {
  test('hello lleva el hash de balance y un hello viejo no', () {
    final codec = WireCodec();
    final p = newProfile('Ana', 'maga');
    final text = codec.encode(HelloMessage(p, balance: 'b1-0000abcd'));
    expect(jsonDecode(text)['b'], 'b1-0000abcd');
    expect((codec.decode(text) as HelloMessage).balance, 'b1-0000abcd');
    final old = codec.encode(HelloMessage(p));
    expect((jsonDecode(old) as Map).containsKey('b'), isFalse);
    expect((codec.decode(old) as HelloMessage).balance, isNull);
  });

  test('regla de rechazo por balance', () {
    const base = GameCatalog.baseBalanceHash;
    expect(balanceReject(base, base), isNull);
    expect(balanceReject(null, base), isNull, reason: 'cliente viejo, sin parche');
    expect(balanceReject('b1-1', 'b1-1'), isNull);
    expect(balanceReject('b1-1', 'b1-2'), RejectReason.balance);
    expect(balanceReject(base, 'b1-2'), RejectReason.balance);
    expect(balanceReject(null, 'b1-2'), RejectReason.version,
        reason: 'el cliente viejo no conoce el motivo "balance"');
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

    Future<LoopbackNetSession> open(GameCatalog c, {String? code}) async {
      final n = LoopbackNetSession(hub, catalog: c);
      opened.add(n);
      await n.connect(SessionConfig(
          profile: newProfile(code == null ? 'Host' : 'Ana', 'guerrero'),
          roomCode: code));
      return n;
    }

    test('mismo parche entra; otro parche es rechazado con el motivo', () async {
      final h = await open(_patched(1.5));
      final ok = await open(_patched(1.5), code: h.roomCode);
      expect(ok.localId, 'p1');
      await expectLater(
          open(GameCatalog.standard, code: h.roomCode),
          throwsA(isA<NetException>()
              .having((e) => e.message, 'message', contains('parche de balance'))));
    });
  });
}
