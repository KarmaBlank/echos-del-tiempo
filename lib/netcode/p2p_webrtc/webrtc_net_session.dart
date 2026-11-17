import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../contracts/game_action.dart';
import '../contracts/game_event.dart';
import '../contracts/net_session.dart';
import 'firestore_signaling_service.dart';

/// Implementación P2P de [NetSession]: WebRTC para el transporte,
/// Firestore solo para la señalización inicial (ver
/// [FirestoreSignalingService]). El host es la autoridad del estado,
/// igual que en el prototipo original — este archivo es el único lugar
/// del proyecto que sabe que existe WebRTC.
///
/// TODO(migración): portar acá la lógica de host autoritativo que hoy
/// vive en el prototipo HTML (hostTick / aplicar GameAction → mutar
/// estado → rebroadcast StateSnapshotEvent). Ese código de resolución
/// de reglas debe vivir en `game_engine`, no acá: esta clase solo
/// transporta bytes.
class WebRTCNetSession implements NetSession {
  WebRTCNetSession({required FirestoreSignalingService signaling})
      : _signaling = signaling;

  final FirestoreSignalingService _signaling;

  final _eventsController = StreamController<GameEvent>.broadcast();
  final _config = <String, RTCPeerConnection>{}; // peerId -> conexión
  final _channels = <String, RTCDataChannel>{};

  bool _isHost = false;
  String _localId = '';
  String? _roomCode;

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  @override
  bool get isHost => _isHost;

  @override
  String get localId => _localId;

  @override
  Stream<GameEvent> get events => _eventsController.stream;

  @override
  Future<void> connect(SessionConfig config) async {
    _localId = DateTime.now().microsecondsSinceEpoch.toString();
    _isHost = config.roomCode == null;
    _roomCode = config.roomCode ?? _generateRoomCode();

    if (_isHost) {
      await _hostRoom(_roomCode!);
    } else {
      await _joinRoom(_roomCode!);
    }
  }

  Future<void> _hostRoom(String roomCode) async {
    final pc = await createPeerConnection(_iceServers);
    _config[roomCode] = pc;

    final channel = await pc.createDataChannel(
      'game',
      RTCDataChannelInit()..ordered = true,
    );
    _wireChannel(channel);

    pc.onIceCandidate = (c) => _signaling.addIceCandidate(
          roomCode,
          'offerCandidates',
          c.toMap(),
        );

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _signaling.publishOffer(roomCode, {
      'sdp': offer.sdp,
      'type': offer.type,
    });

    // `getRemoteDescription()` en flutter_webrtc es async, así que no se
    // puede usar como guarda sincrónica dentro del listener — se trackea
    // acá con un flag local si ya aplicamos la respuesta del otro peer.
    var remoteDescriptionSet = false;
    _signaling.watchRoom(roomCode).listen((data) async {
      final answer = data?['answer'] as Map<String, dynamic>?;
      if (answer != null && !remoteDescriptionSet) {
        remoteDescriptionSet = true;
        await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
      }
    });

    _signaling.watchIceCandidates(roomCode, 'answerCandidates').listen((cands) {
      for (final c in cands) {
        pc.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
      }
    });
  }

  Future<void> _joinRoom(String roomCode) async {
    final pc = await createPeerConnection(_iceServers);
    _config[roomCode] = pc;

    pc.onDataChannel = (channel) => _wireChannel(channel);
    pc.onIceCandidate = (c) => _signaling.addIceCandidate(
          roomCode,
          'answerCandidates',
          c.toMap(),
        );

    final roomData = await _signaling.watchRoom(roomCode).first;
    final offer = roomData?['offer'] as Map<String, dynamic>?;
    if (offer == null) {
      _eventsController.add(const ConnectionLostEvent('Sala no encontrada'));
      return;
    }
    await pc.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await _signaling.publishAnswer(roomCode, {'sdp': answer.sdp, 'type': answer.type});

    _signaling.watchIceCandidates(roomCode, 'offerCandidates').listen((cands) {
      for (final c in cands) {
        pc.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
      }
    });
  }

  void _wireChannel(RTCDataChannel channel) {
    _channels[_roomCode ?? 'default'] = channel;
    channel.onMessage = (RTCDataChannelMessage msg) {
      final decoded = jsonDecode(msg.text) as Map<String, dynamic>;
      _eventsController.add(_eventFromWire(decoded));
    };
  }

  GameEvent _eventFromWire(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'snapshot':
        return StateSnapshotEvent(data['payload'] as Map<String, dynamic>);
      case 'peerJoined':
        return PeerJoinedEvent(data['peerId'], data['name']);
      case 'peerLeft':
        return PeerLeftEvent(data['peerId']);
      case 'sysMsg':
        return SystemMessageEvent(data['text']);
      default:
        return SystemMessageEvent('evento desconocido: ${data['type']}');
    }
  }

  @override
  void sendAction(GameAction action) {
    final channel = _channels[_roomCode];
    if (channel == null) return;
    channel.send(RTCDataChannelMessage(jsonEncode(_actionToWire(action))));
  }

  Map<String, dynamic> _actionToWire(GameAction action) {
    // TODO(migración): mapear cada subtipo de GameAction a un DTO wire
    // serializable, simétrico a _eventFromWire. Dejar acá, no en game_engine.
    return {'type': action.runtimeType.toString()};
  }

  @override
  Future<void> disconnect() async {
    for (final pc in _config.values) {
      await pc.close();
    }
    if (_isHost && _roomCode != null) {
      await _signaling.closeRoom(_roomCode!);
    }
    await _eventsController.close();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = DateTime.now().microsecondsSinceEpoch;
    return List.generate(5, (i) => chars[(rnd ~/ (i + 1)) % chars.length]).join();
  }
}
