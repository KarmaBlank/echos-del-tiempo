import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../game_engine/data/game_catalog.dart';
import '../contracts/net_session.dart';
import '../protocol/protocol_net_session.dart';
import 'firestore_signaling_service.dart';

/// [NetSession] P2P por internet: un `RTCDataChannel` por cliente
/// (estrella alrededor del host, hasta 3 clientes) y Firestore solo para
/// la señalización ([FirestoreSignalingService]). El protocolo del juego
/// es el de [ProtocolNetSession]; este archivo es el único del proyecto
/// que sabe que existe WebRTC. Ver docs/specs/netcode.md § "P2P".
///
/// **Sin probar en dispositivo real**: hace falta un proyecto Firebase
/// (pasos en el spec).
class WebRTCNetSession extends ProtocolNetSession {
  WebRTCNetSession({
    required FirestoreSignalingService signaling,
    super.catalog = GameCatalog.standard,
    math.Random? random,
  })  : _signaling = signaling,
        _random = random ?? math.Random();

  final FirestoreSignalingService _signaling;
  final math.Random _random;

  static const _config = <String, dynamic>{
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  /// Alfabeto de `randCode` (sin 0/O, 1/I).
  static const codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Tiempo máximo para que el cliente abra el canal.
  static const joinTimeout = Duration(seconds: 20);

  /// Conexiones a medio armar que el host acepta a la vez (las de más se
  /// ignoran; el protocolo igual rechaza al quinto jugador).
  static const maxPeerConnections = 6;

  String? _code;
  bool _host = false;
  String? _clientPeerId;
  final _rtcLinks = <_RtcLink>{};
  final _subs = <StreamSubscription<Object?>>[];

  String _randomCode() => List.generate(
      5, (_) => codeAlphabet[_random.nextInt(codeAlphabet.length)]).join();

  // ------------------------------------------------------------------
  // Host
  // ------------------------------------------------------------------

  @override
  Future<String> openRoom(void Function(PeerLink link) onPeer) async {
    _host = true;
    String? code;
    try {
      for (var i = 0; i < 8 && code == null; i++) {
        final c = _randomCode();
        // `unavailable-id` del prototipo: si el código existe, otro.
        if (await _signaling.createRoom(c)) code = c;
      }
    } on Object catch (e) {
      throw NetException('Error de red al crear la sala ($e). '
          '¿Tienes internet? Prueba de nuevo.');
    }
    if (code == null) {
      throw const NetException('No se pudo crear la sala. Prueba de nuevo.');
    }
    final room = code;
    _code = room;
    _subs.add(_signaling.watchOffers(room).listen(
          (offer) => unawaited(_accept(room, offer, onPeer)),
          onError: (Object _) =>
              transportLost('Se perdió la conexión con el servidor de salas.'),
        ));
    return room;
  }

  Future<void> _accept(
      String code, PeerOffer offer, void Function(PeerLink) onPeer) async {
    if (_rtcLinks.length >= maxPeerConnections) return;
    try {
      final pc = await createPeerConnection(_config);
      final link = _RtcLink(pc, onClosed: (l) => _rtcLinks.remove(l));
      _rtcLinks.add(link);
      final ice = _IceQueue(pc);
      pc.onIceCandidate = (c) {
        if (c.candidate == null) return;
        unawaited(_signaling
            .addCandidate(code, offer.peerId,
                fromHost: true, candidate: Map<String, dynamic>.from(c.toMap() as Map))
            .catchError((Object _) {}));
      };
      // El cliente crea el canal (es quien ofrece): llega acá. El host
      // no escribe hasta recibir el `hello`, así que no hace falta
      // esperar a que esté abierto.
      pc.onDataChannel = (channel) {
        link.attach(channel);
        onPeer(link);
      };
      await pc.setRemoteDescription(RTCSessionDescription(offer.sdp, offer.type));
      ice.remoteReady();
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await _signaling.publishAnswer(
          code, offer.peerId, answer.sdp ?? '', answer.type ?? 'answer');
      link.addSubscription(_signaling
          .watchCandidates(code, offer.peerId, fromHost: false)
          .listen(ice.add, onError: (Object _) {}));
    } on Object {
      // Una oferta rota no tumba la sala.
    }
  }

  // ------------------------------------------------------------------
  // Cliente
  // ------------------------------------------------------------------

  @override
  Future<PeerLink> joinRoom(String code) async {
    final c = code.trim().toUpperCase();
    if (c.length < 4) {
      throw const NetException('Escribe el código de la sala.');
    }
    _code = c;
    try {
      if (!await _signaling.roomExists(c)) {
        throw NetException(
            'Sala $c no encontrada. ¿El host sigue con el juego abierto?');
      }
    } on NetException {
      rethrow;
    } on Object catch (e) {
      throw NetException('Error de red: $e');
    }

    final pc = await createPeerConnection(_config);
    final link = _RtcLink(pc, onClosed: (l) => _rtcLinks.remove(l));
    _rtcLinks.add(link);
    final ice = _IceQueue(pc);
    final pendingLocal = <Map<String, dynamic>>[];
    String? peerId;
    pc.onIceCandidate = (cand) {
      if (cand.candidate == null) return;
      final m = Map<String, dynamic>.from(cand.toMap() as Map);
      final id = peerId;
      if (id == null) {
        pendingLocal.add(m); // todavía no existe el documento
      } else {
        unawaited(_signaling
            .addCandidate(c, id, fromHost: false, candidate: m)
            .catchError((Object _) {}));
      }
    };
    final channel = await pc.createDataChannel(
        'game', RTCDataChannelInit()..ordered = true);
    final opened = Completer<void>();
    link.attach(channel, onOpen: () {
      if (!opened.isCompleted) opened.complete();
    });

    try {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      final id = await _signaling.createPeer(c, offer.sdp ?? '', offer.type ?? 'offer');
      peerId = id;
      _clientPeerId = id;
      for (final m in pendingLocal) {
        unawaited(_signaling
            .addCandidate(c, id, fromHost: false, candidate: m)
            .catchError((Object _) {}));
      }
      pendingLocal.clear();
      link.addSubscription(_signaling.watchAnswer(c, id).listen((a) async {
        if (ice.ready) return;
        await pc.setRemoteDescription(RTCSessionDescription(a.sdp, a.type));
        ice.remoteReady();
      }, onError: (Object _) {}));
      link.addSubscription(_signaling
          .watchCandidates(c, id, fromHost: true)
          .listen(ice.add, onError: (Object _) {}));

      await opened.future.timeout(joinTimeout);
    } on Object {
      await link.close();
      await _cleanupClientDoc();
      throw NetException('No se pudo conectar a la sala $c (tiempo agotado). '
          'Puede ser la red (NAT estricta) o que el host ya no esté.');
    }
    // Conectados: la señalización ya no hace falta.
    Timer(const Duration(seconds: 5), () => unawaited(_cleanupClientDoc()));
    return link;
  }

  Future<void> _cleanupClientDoc() async {
    final code = _code, id = _clientPeerId;
    _clientPeerId = null;
    if (code == null || id == null) return;
    try {
      await _signaling.deletePeer(code, id);
    } on Object {
      // la sala ya no existe o no hay red: lo limpia el TTL
    }
  }

  // ------------------------------------------------------------------
  // Cierre
  // ------------------------------------------------------------------

  @override
  Future<void> closeTransport() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final l in [..._rtcLinks]) {
      await l.close();
    }
    _rtcLinks.clear();
    final code = _code;
    if (_host && code != null) {
      try {
        await _signaling.closeRoom(code);
      } on Object {
        // sin red: lo limpia el TTL
      }
    } else {
      await _cleanupClientDoc();
    }
  }
}

/// Candidatos ICE remotos que llegan antes de la descripción remota:
/// se guardan y se aplican después.
class _IceQueue {
  _IceQueue(this.pc);
  final RTCPeerConnection pc;
  final _pending = <RTCIceCandidate>[];
  bool ready = false;

  void add(Map<String, dynamic> m) {
    final cand = m['candidate'];
    if (cand is! String) return;
    final idx = m['sdpMLineIndex'];
    final c = RTCIceCandidate(
        cand, m['sdpMid'] as String?, idx is num ? idx.toInt() : null);
    if (ready) {
      unawaited(pc.addCandidate(c).catchError((Object _) {}));
    } else {
      _pending.add(c);
    }
  }

  void remoteReady() {
    ready = true;
    for (final c in _pending) {
      unawaited(pc.addCandidate(c).catchError((Object _) {}));
    }
    _pending.clear();
  }
}

/// Un `RTCDataChannel` (y su `RTCPeerConnection`) como [PeerLink].
class _RtcLink implements PeerLink {
  _RtcLink(this._pc, {required void Function(_RtcLink) onClosed})
      : _onClosed = onClosed {
    _pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        unawaited(close());
      }
    };
  }

  final RTCPeerConnection _pc;
  final void Function(_RtcLink) _onClosed;
  RTCDataChannel? _channel;
  final _in = StreamController<String>();
  final _subs = <StreamSubscription<Object?>>[];
  bool _closed = false;

  void attach(RTCDataChannel channel, {void Function()? onOpen}) {
    _channel = channel;
    channel.onMessage = (m) {
      if (!m.isBinary && !_in.isClosed) _in.add(m.text);
    };
    channel.onDataChannelState = (s) {
      if (s == RTCDataChannelState.RTCDataChannelOpen) onOpen?.call();
      if (s == RTCDataChannelState.RTCDataChannelClosed) unawaited(close());
    };
    if (channel.state == RTCDataChannelState.RTCDataChannelOpen) onOpen?.call();
  }

  void addSubscription(StreamSubscription<Object?> s) => _subs.add(s);

  @override
  Stream<String> get incoming => _in.stream;

  @override
  void send(String text) {
    final ch = _channel;
    if (_closed || ch == null) return;
    unawaited(ch.send(RTCDataChannelMessage(text)).catchError((Object _) {}));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    try {
      await _channel?.close();
    } on Object {
      // ya cerrado
    }
    try {
      await _pc.close();
      await _pc.dispose();
    } on Object {
      // ya cerrado
    }
    if (!_in.isClosed) unawaited(_in.close());
    _onClosed(this);
  }
}
