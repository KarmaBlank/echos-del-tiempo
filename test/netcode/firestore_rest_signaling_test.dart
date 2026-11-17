import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:echos_del_tiempo/netcode/p2p_webrtc/firestore_rest_codec.dart';
import 'package:echos_del_tiempo/netcode/p2p_webrtc/firestore_rest_signaling.dart';
import 'package:echos_del_tiempo/netcode/p2p_webrtc/signaling_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servidor falso de la API REST v1 de Firestore: guarda documentos en
/// memoria y aplica las mismas restricciones que `firestore.rules`
/// (campos permitidos, sala existente, `answer` como única
/// actualización, sin `list` de salas).
class FakeFirestore {
  FakeFirestore._(this._server);

  static const project = 'demo';
  static const key = 'test-key';
  static const _prefix = ['v1', 'projects', project, 'databases', '(default)'];

  final HttpServer _server;
  final docs = <String, Map<String, Object?>>{};
  final requests = <String>[];
  final _rnd = math.Random(7);

  /// Simula que una colisión de código llega como 403 (reglas) en vez de
  /// 409.
  bool collisionAs403 = false;

  /// Todos los pedidos responden este estado (si no es null).
  int? forceStatus;

  /// No responde nunca (para probar los timeouts).
  bool hang = false;

  Uri get base => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<FakeFirestore> start() async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final f = FakeFirestore._(s);
    s.listen(f._handle);
    return f;
  }

  Future<void> close() => _server.close(force: true);

  int count(String method) =>
      requests.where((r) => r.startsWith(method)).length;

  String _name(List<String> p) =>
      'projects/$project/databases/(default)/documents/${p.join('/')}';

  Map<String, Object?> _json(List<String> p) =>
      {'name': _name(p), 'fields': docs[p.join('/')]};

  Future<void> _handle(HttpRequest req) async {
    final body = await utf8.decoder.bind(req).join();
    final segs = req.uri.pathSegments;
    final path = segs.skip(_prefix.length + 1).toList(); // + 'documents'
    final q = req.uri.queryParameters;
    requests.add('${req.method} ${path.join('/')}');
    if (hang) return; // sin respuesta
    final res = req.response..headers.contentType = ContentType.json;
    void reply(int status, [Object? json]) {
      res.statusCode = status;
      res.write(jsonEncode(json ?? const <String, Object?>{}));
      unawaited(res.close());
    }

    void error(int status, String code, String msg) => reply(status, {
          'error': {'code': status, 'status': code, 'message': msg},
        });

    if (forceStatus != null) {
      return error(forceStatus!, 'INTERNAL', 'forzado');
    }
    if (q['key'] != key) {
      return error(400, 'INVALID_ARGUMENT', 'API key not valid.');
    }
    final isDoc = path.length.isEven;
    final id = path.join('/');
    final fields = body.isEmpty
        ? const <String, Object?>{}
        : ((jsonDecode(body) as Map)['fields'] as Map? ?? const {})
            .cast<String, Object?>();
    bool keysOnly(Set<String> allowed) => fields.keys.every(allowed.contains);

    switch (req.method) {
      case 'GET' when isDoc:
        return docs.containsKey(id)
            ? reply(200, _json(path))
            : error(404, 'NOT_FOUND', 'No document');
      case 'GET':
        if (path.length == 1) return error(403, 'PERMISSION_DENIED', 'list');
        final prefix = '$id/';
        final children = docs.keys
            .where((k) =>
                k.startsWith(prefix) &&
                !k.substring(prefix.length).contains('/'))
            .toList()
          ..sort();
        return reply(200, {
          if (children.isNotEmpty)
            'documents': [for (final k in children) _json(k.split('/'))],
        });
      case 'POST' when !isDoc:
        final docId = q['documentId'] ??
            List.generate(
                    20, (_) => 'abcdefghijklmnopqrstuvwxyz'[_rnd.nextInt(26)])
                .join();
        final full = [...path, docId];
        final collection = path.last;
        final ok = switch (collection) {
          'rooms' => RegExp(r'^[A-HJ-NP-Z2-9]{5}$').hasMatch(docId) &&
              keysOnly({'v', 'createdAt', 'expiresAt'}),
          'peers' => docs.containsKey(path.take(2).join('/')) &&
              keysOnly({'offer', 'createdAt', 'expiresAt'}),
          'clientCandidates' || 'hostCandidates' => fields.length <= 6,
          _ => false,
        };
        if (docs.containsKey(full.join('/'))) {
          return collisionAs403
              ? error(403, 'PERMISSION_DENIED', 'update')
              : error(409, 'ALREADY_EXISTS', 'Document already exists');
        }
        if (!ok) return error(403, 'PERMISSION_DENIED', 'rules');
        docs[full.join('/')] = fields;
        return reply(200, _json(full));
      case 'PATCH' when isDoc:
        final mask = req.uri.queryParametersAll['updateMask.fieldPaths'];
        if (mask == null || mask.length != 1 || mask.single != 'answer') {
          return error(403, 'PERMISSION_DENIED', 'mask');
        }
        if (q['currentDocument.exists'] == 'true' && !docs.containsKey(id)) {
          return error(404, 'NOT_FOUND', 'No document');
        }
        docs[id] = {...?docs[id], 'answer': fields['answer']};
        return reply(200, _json(path));
      case 'DELETE' when isDoc:
        docs.remove(id);
        return reply(200);
    }
    error(400, 'INVALID_ARGUMENT', 'ruta');
  }
}

void main() {
  group('FirestoreRestCodec', () {
    test('ida y vuelta de todos los tipos usados', () {
      final when = DateTime.utc(2026, 11, 17, 12, 30, 5, 123);
      final value = <String, Object?>{
        's': 'hola',
        'i': 42,
        'neg': -7,
        'd': 1.5,
        'b': true,
        'n': null,
        't': when,
        'm': {
          'sdp': 'v=0\r\no=- 1 2 IN IP4 127.0.0.1',
          'type': 'offer',
          'deep': {'x': 1},
        },
        'l': [1, 'dos', false, null],
      };
      final encoded = FirestoreRestCodec.encodeFields(value);
      expect(encoded['i'], {'integerValue': '42'});
      expect(encoded['s'], {'stringValue': 'hola'});
      expect(encoded['t'], {'timestampValue': '2026-11-17T12:30:05.123Z'});
      // Pasa por JSON como en la red.
      final back =
          FirestoreRestCodec.decodeFields(jsonDecode(jsonEncode(encoded)));
      expect(back['t'], isA<DateTime>());
      expect((back['t'] as DateTime).isAtSameMomentAs(when), isTrue);
      expect({...back}..remove('t'), {...value}..remove('t'));
    });

    test('decodifica lo que manda el servidor', () {
      expect(FirestoreRestCodec.decodeValue({'integerValue': '0'}), 0);
      expect(FirestoreRestCodec.decodeValue({'doubleValue': 2}), 2.0);
      expect(FirestoreRestCodec.decodeValue({'mapValue': {}}), isEmpty);
      expect(FirestoreRestCodec.decodeValue({'arrayValue': {}}), isEmpty);
      expect(FirestoreRestCodec.decodeFields(null), isEmpty);
    });
  });

  group('FirestoreRestSignaling', () {
    late FakeFirestore fake;
    late FirestoreRestSignaling host;
    late FirestoreRestSignaling client;

    FirestoreRestSignaling make(
            {Duration timeout = const Duration(seconds: 5)}) =>
        FirestoreRestSignaling(
          projectId: FakeFirestore.project,
          apiKey: FakeFirestore.key,
          baseUri: fake.base,
          pollInterval: const Duration(milliseconds: 20),
          offerPollInterval: const Duration(milliseconds: 20),
          requestTimeout: timeout,
          maxPollFailures: 3,
        );

    setUp(() async {
      fake = await FakeFirestore.start();
      host = make();
      client = make();
    });

    tearDown(() async {
      host.close();
      client.close();
      await fake.close();
    });

    test('crea la sala y detecta un código usado (409 y 403)', () async {
      expect(await host.createRoom('ABCDE'), isTrue);
      final room = fake.docs['rooms/ABCDE']!;
      expect(room.keys.toSet(), {'v', 'createdAt', 'expiresAt'});
      expect(room['createdAt'], contains('timestampValue'));
      expect(await host.createRoom('ABCDE'), isFalse);
      fake.collisionAs403 = true;
      expect(await host.createRoom('ABCDE'), isFalse);
      expect(await client.roomExists('ABCDE'), isTrue);
      expect(await client.roomExists('ZZZZZ'), isFalse);
    });

    test('oferta → el host la ve por consulta → respuesta → el cliente la ve',
        () async {
      await host.createRoom('QWERT');
      final offers = <PeerOffer>[];
      final sub = host.watchOffers('QWERT').listen(offers.add);

      final peerId = await client.createPeer('QWERT', 'sdp-offer', 'offer');
      expect(fake.docs['rooms/QWERT/peers/$peerId']!.keys.toSet(),
          {'offer', 'createdAt', 'expiresAt'});
      await _until(() => offers.isNotEmpty);
      // Cada oferta se emite una sola vez aunque se siga consultando.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(offers, hasLength(1));
      expect(offers.single.peerId, peerId);
      expect(offers.single.sdp, 'sdp-offer');
      expect(offers.single.type, 'offer');

      final answer = client.watchAnswer('QWERT', peerId).first;
      await host.publishAnswer('QWERT', peerId, 'sdp-answer', 'answer');
      expect(await answer.timeout(const Duration(seconds: 5)),
          (sdp: 'sdp-answer', type: 'answer'));
      expect(fake.docs['rooms/QWERT/peers/$peerId']!.keys.toSet(),
          {'offer', 'createdAt', 'expiresAt', 'answer'});
      await sub.cancel();
    });

    test('candidatos ICE en ambos sentidos, cada uno una vez', () async {
      await host.createRoom('HJKLM');
      final peerId = await client.createPeer('HJKLM', 'o', 'offer');
      final atHost = <Map<String, dynamic>>[];
      final atClient = <Map<String, dynamic>>[];
      final s1 = host
          .watchCandidates('HJKLM', peerId, fromHost: false)
          .listen(atHost.add);
      final s2 = client
          .watchCandidates('HJKLM', peerId, fromHost: true)
          .listen(atClient.add);

      Map<String, dynamic> cand(String c, int idx) =>
          {'candidate': c, 'sdpMid': '0', 'sdpMLineIndex': idx};
      await client.addCandidate('HJKLM', peerId,
          fromHost: false, candidate: cand('candidate:cli', 0));
      await client.addCandidate('HJKLM', peerId,
          fromHost: false, candidate: cand('candidate:cli2', 1));
      await host.addCandidate('HJKLM', peerId,
          fromHost: true, candidate: cand('candidate:host', 0));

      await _until(() => atHost.length == 2 && atClient.length == 1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(atHost.map((m) => m['candidate']).toSet(),
          {'candidate:cli', 'candidate:cli2'});
      expect(atHost, hasLength(2));
      expect(atClient.single['candidate'], 'candidate:host');
      expect(atClient.single['sdpMid'], '0');
      expect(atClient.single['sdpMLineIndex'], 0);
      expect(atClient.single['expiresAt'], isA<DateTime>());
      await s1.cancel();
      await s2.cancel();
    });

    test('cancelar la suscripción deja de consultar', () async {
      await host.createRoom('PQRST');
      final sub = host.watchOffers('PQRST').listen((_) {});
      await _until(() => fake.count('GET rooms/PQRST/peers') >= 3);
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final after = fake.count('GET rooms/PQRST/peers');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(fake.count('GET rooms/PQRST/peers'), after);
    });

    test('la respuesta se consulta solo hasta que llega', () async {
      await host.createRoom('UVWXY');
      final peerId = await client.createPeer('UVWXY', 'o', 'offer');
      await host.publishAnswer('UVWXY', peerId, 'a', 'answer');
      final got = await client.watchAnswer('UVWXY', peerId).toList();
      expect(got, hasLength(1));
      expect(fake.count('GET rooms/UVWXY/peers/$peerId'), 1);
    });

    test('limpieza: deletePeer y closeRoom no dejan documentos', () async {
      await host.createRoom('ABCDF');
      final a = await client.createPeer('ABCDF', 'o', 'offer');
      final b = await client.createPeer('ABCDF', 'o', 'offer');
      for (final id in [a, b]) {
        await client.addCandidate('ABCDF', id,
            fromHost: false, candidate: {'candidate': 'c'});
        await host.addCandidate('ABCDF', id,
            fromHost: true, candidate: {'candidate': 'h'});
      }
      await client.deletePeer('ABCDF', a);
      expect(fake.docs.keys.where((k) => k.contains(a)), isEmpty);
      await host.closeRoom('ABCDF');
      expect(fake.docs, isEmpty);
    });

    test('oferta a una sala que no existe: error claro', () async {
      await expectLater(
          client.createPeer('NOPE2', 'o', 'offer'),
          throwsA(isA<SignalingException>()
              .having((e) => e.message, 'message', contains('ya no existe'))));
    });

    test('errores HTTP y de red salen como SignalingException', () async {
      fake.forceStatus = 500;
      await expectLater(
          host.createRoom('ABCDE'),
          throwsA(isA<SignalingException>()
              .having((e) => e.message, 'message', contains('HTTP 500'))));
      fake.forceStatus = 403;
      await expectLater(
          client.publishAnswer('ABCDE', 'x', 's', 'answer'),
          throwsA(isA<SignalingException>()
              .having((e) => e.message, 'message', contains('reglas'))));
      fake.forceStatus = null;

      final badKey = FirestoreRestSignaling(
          projectId: FakeFirestore.project, apiKey: 'otra', baseUri: fake.base);
      await expectLater(
          badKey.roomExists('ABCDE'),
          throwsA(isA<SignalingException>()
              .having((e) => e.message, 'message', contains('clave'))));
      badKey.close();

      final slow = make(timeout: const Duration(milliseconds: 200));
      fake.hang = true;
      await expectLater(
          slow.roomExists('ABCDE'),
          throwsA(isA<SignalingException>()
              .having((e) => e.message, 'message', contains('no respondió'))));
      slow.close();
      fake.hang = false;

      final down = FirestoreRestSignaling(
          projectId: FakeFirestore.project,
          apiKey: FakeFirestore.key,
          baseUri: Uri.parse('http://127.0.0.1:1'));
      await expectLater(
          down.roomExists('ABCDE'),
          throwsA(isA<SignalingException>()
              .having((e) => e.message, 'message', contains('internet'))));
      down.close();
    });

    test('una consulta que falla seguido termina el stream con error',
        () async {
      fake.forceStatus = 503;
      final done = Completer<Object>();
      host
          .watchOffers('ABCDE')
          .listen((_) {}, onError: (Object e) => done.complete(e));
      expect(await done.future.timeout(const Duration(seconds: 5)),
          isA<SignalingException>());
      expect(fake.count('GET'), 3); // maxPollFailures
    });
  });
}

Future<void> _until(bool Function() cond,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('timeout esperando la condición');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
