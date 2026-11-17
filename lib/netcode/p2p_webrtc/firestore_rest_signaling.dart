import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'firestore_rest_codec.dart';
import 'signaling_service.dart';

/// [SignalingService] sobre la API REST v1 de Firestore, con
/// `dart:io` `HttpClient` y sin el SDK nativo. Es la que se usa en
/// escritorio (Windows/Linux/macOS): el plugin `cloud_firestore` de
/// escritorio (SDK C++, "solo para desarrollo") entrega los eventos de
/// sus listeners desde un hilo que no es el de la plataforma y se pierden
/// mensajes — el host nunca veía al cliente. Ver docs/specs/netcode.md
/// § "Señalización REST en escritorio".
///
/// - Sin `Firebase.initializeApp`: alcanza con `projectId` + `apiKey`.
/// - Sin listeners: los `watch*` consultan cada [pollInterval] (ofertas:
///   [offerPollInterval]) mientras alguien esté suscripto. La sesión
///   WebRTC cancela las suscripciones apenas abre el canal.
/// - Cada pedido tiene [requestTimeout]; los errores salen como
///   [SignalingException] con un mensaje en castellano.
///
/// Dart puro (lo usa también `tool/p2p_signaling_smoke.dart`).
class FirestoreRestSignaling implements SignalingService {
  FirestoreRestSignaling({
    required this.projectId,
    required this.apiKey,
    Uri? baseUri,
    HttpClient? httpClient,
    this.pollInterval = const Duration(milliseconds: 500),
    this.offerPollInterval = const Duration(seconds: 1),
    this.requestTimeout = const Duration(seconds: 10),
    this.maxPollFailures = 10,
    DateTime Function()? now,
  })  : baseUri = baseUri ?? Uri.parse('https://firestore.googleapis.com'),
        _http = httpClient ?? HttpClient(),
        _now = now ?? DateTime.now {
    _http.connectionTimeout = requestTimeout;
  }

  final String projectId;
  final String apiKey;

  /// `https://firestore.googleapis.com` (los tests apuntan a un servidor
  /// falso local).
  final Uri baseUri;

  /// Cadencia de consulta de respuesta y candidatos ICE.
  final Duration pollInterval;

  /// Cadencia de consulta de ofertas nuevas (el host, mientras la sala
  /// está abierta).
  final Duration offerPollInterval;

  final Duration requestTimeout;

  /// Fallas seguidas de una consulta antes de dar el stream por perdido.
  final int maxPollFailures;

  final HttpClient _http;
  final DateTime Function() _now;

  /// Cierra el cliente HTTP (tests y la herramienta de humo; la app lo
  /// usa durante toda su vida).
  void close() => _http.close(force: true);

  // ------------------------------------------------------------------
  // Sala (host)
  // ------------------------------------------------------------------

  @override
  Future<bool> createRoom(String code, {int version = 1}) async {
    final r = await _request('POST', _uri(['rooms'], {'documentId': code}),
        body: _doc({'v': version, ..._stamps()}));
    if (r.ok) return true;
    // Código usado: 409 ALREADY_EXISTS. Según cómo evalúe las reglas
    // puede llegar como 403 (un `create` sobre algo que existe es un
    // `update`, prohibido): se distingue mirando si la sala existe.
    if (r.status == 409) return false;
    if (r.status == 403 && await roomExists(code)) return false;
    throw _failure(r, 'crear la sala $code');
  }

  @override
  Future<bool> roomExists(String code) async =>
      await _getDoc(['rooms', code], 'buscar la sala $code') != null;

  @override
  Stream<PeerOffer> watchOffers(String code) {
    final seen = <String>{};
    return _poll(offerPollInterval, () async {
      final out = <PeerOffer>[];
      for (final d in await _list(['rooms', code, 'peers'], 'leer ofertas')) {
        if (!seen.add(d.name)) continue;
        final offer = d.fields['offer'];
        if (offer is! Map) continue;
        final sdp = offer['sdp'], type = offer['type'];
        if (sdp is String && type is String) {
          out.add(PeerOffer(d.id, sdp, type));
        }
      }
      return out;
    });
  }

  @override
  Future<void> publishAnswer(
      String code, String peerId, String sdp, String type) async {
    final r = await _request(
        'PATCH',
        _uri([
          'rooms',
          code,
          'peers',
          peerId
        ], {
          'updateMask.fieldPaths': 'answer',
          'currentDocument.exists': 'true',
        }),
        body: _doc({
          'answer': {'sdp': sdp, 'type': type},
        }));
    if (!r.ok) throw _failure(r, 'publicar la respuesta');
  }

  @override
  Future<void> closeRoom(String code) async {
    for (final p in await _list(['rooms', code, 'peers'], 'cerrar la sala')) {
      await deletePeer(code, p.id);
    }
    await _delete(['rooms', code], 'borrar la sala');
  }

  // ------------------------------------------------------------------
  // Cliente
  // ------------------------------------------------------------------

  @override
  Future<String> createPeer(String code, String sdp, String type) async {
    final r = await _request('POST', _uri(['rooms', code, 'peers']),
        body: _doc({
          'offer': {'sdp': sdp, 'type': type},
          ..._stamps(),
        }));
    if (!r.ok) {
      // La regla `roomExists(room)` da 403 si la sala desapareció.
      if (r.status == 403 && !await roomExists(code)) {
        throw SignalingException(
            'La sala $code ya no existe. ¿El host sigue con el juego abierto?');
      }
      throw _failure(r, 'enviar la oferta');
    }
    return _RestDoc.parse(r.json).id;
  }

  @override
  Stream<({String sdp, String type})> watchAnswer(String code, String peerId) =>
      _poll(pollInterval, () async {
        final d = await _getDoc(
            ['rooms', code, 'peers', peerId], 'leer la respuesta');
        final a = d?.fields['answer'];
        if (a is! Map) return const [];
        final sdp = a['sdp'], type = a['type'];
        if (sdp is! String || type is! String) return const [];
        return [(sdp: sdp, type: type)];
      }, once: true);

  // ------------------------------------------------------------------
  // ICE (ambos)
  // ------------------------------------------------------------------

  @override
  Future<void> addCandidate(String code, String peerId,
      {required bool fromHost, required Map<String, dynamic> candidate}) async {
    final r = await _request(
        'POST', _uri(['rooms', code, 'peers', peerId, _side(fromHost)]),
        body: _doc(
            {...candidate, 'expiresAt': _now().add(SignalingService.ttl)}));
    if (!r.ok) throw _failure(r, 'enviar un candidato ICE');
  }

  @override
  Stream<Map<String, dynamic>> watchCandidates(String code, String peerId,
      {required bool fromHost}) {
    final seen = <String>{};
    return _poll(pollInterval, () async {
      final docs = await _list(
          ['rooms', code, 'peers', peerId, _side(fromHost)],
          'leer candidatos ICE');
      return [
        for (final d in docs)
          if (seen.add(d.name)) d.fields,
      ];
    });
  }

  @override
  Future<void> deletePeer(String code, String peerId) async {
    final peer = ['rooms', code, 'peers', peerId];
    for (final side in [
      SignalingService.clientCandidates,
      SignalingService.hostCandidates,
    ]) {
      for (final c in await _list([...peer, side], 'limpiar candidatos')) {
        await _delete([...peer, side, c.id], 'borrar un candidato');
      }
    }
    await _delete(peer, 'borrar la oferta');
  }

  // ------------------------------------------------------------------
  // REST
  // ------------------------------------------------------------------

  static String _side(bool fromHost) => fromHost
      ? SignalingService.hostCandidates
      : SignalingService.clientCandidates;

  /// `createdAt` con la hora local: las reglas solo limitan qué campos
  /// hay, no su valor (el SDK usa la hora del servidor).
  Map<String, Object> _stamps() {
    final now = _now();
    return {'createdAt': now, 'expiresAt': now.add(SignalingService.ttl)};
  }

  static Map<String, Object?> _doc(Map<String, Object?> fields) =>
      {'fields': FirestoreRestCodec.encodeFields(fields)};

  Uri _uri(List<String> path, [Map<String, String>? query]) => baseUri.replace(
        pathSegments: [
          ...baseUri.pathSegments.where((s) => s.isNotEmpty),
          'v1',
          'projects',
          projectId,
          'databases',
          '(default)',
          'documents',
          ...path,
        ],
        queryParameters: {...?query, 'key': apiKey},
      );

  Future<_RestDoc?> _getDoc(List<String> path, String what) async {
    final r = await _request('GET', _uri(path));
    if (r.status == 404) return null;
    if (!r.ok) throw _failure(r, what);
    return _RestDoc.parse(r.json);
  }

  Future<List<_RestDoc>> _list(List<String> path, String what) async {
    final out = <_RestDoc>[];
    String? token;
    do {
      final r = await _request(
          'GET',
          _uri(path,
              {'pageSize': '100', if (token != null) 'pageToken': token}));
      if (!r.ok) throw _failure(r, what);
      final json = r.json;
      final docs = json is Map ? json['documents'] : null;
      if (docs is List) out.addAll(docs.map(_RestDoc.parse));
      final next = json is Map ? json['nextPageToken'] : null;
      token = next is String && next.isNotEmpty ? next : null;
    } while (token != null);
    return out;
  }

  Future<void> _delete(List<String> path, String what) async {
    final r = await _request('DELETE', _uri(path));
    if (!r.ok && r.status != 404) throw _failure(r, what);
  }

  Future<_RestResponse> _request(String method, Uri uri, {Object? body}) async {
    HttpClientRequest? req;
    Future<_RestResponse> send() async {
      final rq = req = await _http.openUrl(method, uri);
      rq.headers.contentType = ContentType.json;
      if (body != null) rq.add(utf8.encode(jsonEncode(body)));
      final resp = await rq.close();
      final text = await resp.transform(utf8.decoder).join();
      Object? json;
      if (text.isNotEmpty) {
        try {
          json = jsonDecode(text);
        } on FormatException {
          json = null;
        }
      }
      return _RestResponse(resp.statusCode, json);
    }

    try {
      return await send().timeout(requestTimeout);
    } on TimeoutException {
      req?.abort();
      throw const SignalingException(
          'El servidor de salas (Firestore) no respondió a tiempo. '
          '¿Tienes internet?');
    } on SocketException {
      throw const SignalingException(
          'No hay conexión con el servidor de salas (Firestore). '
          '¿Tienes internet?');
    } on HandshakeException {
      throw const SignalingException(
          'Falló la conexión segura con Firestore (¿hora del sistema o '
          'proxy?).');
    } on HttpException catch (e) {
      throw SignalingException('Error HTTP con Firestore: ${e.message}');
    }
  }

  static SignalingException _failure(_RestResponse r, String what) {
    final err = r.json is Map ? (r.json as Map)['error'] : null;
    final status = err is Map ? '${err['status'] ?? ''}' : '';
    final msg = err is Map ? '${err['message'] ?? ''}' : '';
    final detail = msg.isEmpty ? '' : ' ($msg)';
    return SignalingException(switch (r.status) {
      400 when msg.toLowerCase().contains('api key') =>
        'Firestore rechazó la clave de la app al $what$detail. '
            'Revisa lib/firebase_options.dart.',
      400 => 'Firestore rechazó el pedido al $what$detail.',
      401 || 403 => 'Firestore denegó el permiso al $what$detail. '
          '¿Están publicadas las reglas (firestore.rules)?',
      404 => 'No se encontró lo pedido al $what.',
      409 => 'Ya existía al $what.',
      429 => 'Firestore: cuota agotada al $what. Prueba más tarde.',
      >= 500 => 'El servidor de salas falló al $what '
          '(HTTP ${r.status}${status.isEmpty ? '' : ' $status'}). '
          'Prueba de nuevo.',
      _ => 'Respuesta inesperada de Firestore al $what '
          '(HTTP ${r.status})$detail.',
    });
  }

  /// Stream que consulta [tick] cada [every] mientras haya alguien
  /// suscripto, sin solapar pedidos. Con [once] se cierra tras la primera
  /// tanda no vacía. Tras [maxPollFailures] fallas seguidas emite el error
  /// y se cierra (una falla suelta de red no tumba la señalización).
  Stream<T> _poll<T>(Duration every, Future<List<T>> Function() tick,
      {bool once = false}) {
    late final StreamController<T> c;
    var active = false;
    Future<void> loop() async {
      var failures = 0;
      while (active) {
        try {
          final items = await tick();
          failures = 0;
          for (final i in items) {
            if (!active) return;
            c.add(i);
          }
          if (once && items.isNotEmpty) break;
        } on Object catch (e, st) {
          if (++failures >= maxPollFailures) {
            if (active) c.addError(e, st);
            break;
          }
        }
        if (!active) return;
        await Future<void>.delayed(every);
      }
      active = false;
      if (!c.isClosed) unawaited(c.close());
    }

    c = StreamController<T>(
      onListen: () {
        active = true;
        unawaited(loop());
      },
      onCancel: () => active = false,
    );
    return c.stream;
  }
}

class _RestResponse {
  const _RestResponse(this.status, this.json);
  final int status;
  final Object? json;
  bool get ok => status >= 200 && status < 300;
}

/// Documento REST: `name` completo (`projects/.../documents/rooms/X`),
/// su id (último segmento) y los campos ya decodificados.
class _RestDoc {
  const _RestDoc(this.name, this.fields);

  factory _RestDoc.parse(Object? json) {
    final m = json is Map ? json : const <String, Object?>{};
    return _RestDoc(
        '${m['name'] ?? ''}', FirestoreRestCodec.decodeFields(m['fields']));
  }

  final String name;
  final Map<String, dynamic> fields;

  String get id => name.substring(name.lastIndexOf('/') + 1);
}
