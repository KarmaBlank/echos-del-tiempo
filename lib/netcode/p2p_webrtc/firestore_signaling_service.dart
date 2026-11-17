import 'package:cloud_firestore/cloud_firestore.dart';

/// Señalización para armar la conexión WebRTC inicial (intercambio de
/// SDP offer/answer + ICE candidates) usando Firestore como "buzón".
///
/// Importante: esto NO transporta el juego. Una vez que el `RTCPeerConnection`
/// queda establecido, todo el tráfico de [GameAction]/[GameEvent] viaja
/// directo P2P por el DataChannel — Firestore deja de usarse hasta la
/// próxima vez que alguien necesite reconectar.
///
/// Documento en Firestore: `rooms/{roomCode}` con sub-colecciones
/// `offerCandidates` / `answerCandidates` (patrón estándar de WebRTC +
/// Firestore, ver https://webrtc.org/getting-started/firebase-rtc-codelab).
class FirestoreSignalingService {
  FirestoreSignalingService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> roomRef(String roomCode) =>
      _db.collection('rooms').doc(roomCode);

  Future<void> publishOffer(String roomCode, Map<String, dynamic> offer) =>
      roomRef(roomCode).set({'offer': offer, 'createdAt': FieldValue.serverTimestamp()});

  Future<void> publishAnswer(String roomCode, Map<String, dynamic> answer) =>
      roomRef(roomCode).update({'answer': answer});

  Stream<Map<String, dynamic>?> watchRoom(String roomCode) =>
      roomRef(roomCode).snapshots().map((d) => d.data());

  Future<void> addIceCandidate(
    String roomCode,
    String subcollection, // 'offerCandidates' | 'answerCandidates'
    Map<String, dynamic> candidate,
  ) =>
      roomRef(roomCode).collection(subcollection).add(candidate);

  Stream<List<Map<String, dynamic>>> watchIceCandidates(
    String roomCode,
    String subcollection,
  ) =>
      roomRef(roomCode).collection(subcollection).snapshots().map(
            (s) => s.docs.map((d) => d.data()).toList(),
          );

  /// Limpieza al terminar la partida — evita acumular basura en Firestore.
  Future<void> closeRoom(String roomCode) => roomRef(roomCode).delete();
}
