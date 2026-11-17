import 'package:cloud_firestore/cloud_firestore.dart';

import 'signaling_service.dart';

/// [SignalingService] con el SDK `cloud_firestore` (listeners en tiempo
/// real). Se usa en web/Android/iOS; en escritorio va
/// `FirestoreRestSignaling` (el SDK C++ pierde eventos de los listeners).
/// Ver docs/specs/netcode.md § "P2P por internet".
class FirestoreSignalingService implements SignalingService {
  FirestoreSignalingService({FirebaseFirestore? firestore})
      : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;

  /// Se resuelve recién al usarse: sin `Firebase.initializeApp` crear el
  /// servicio no falla (solo usarlo).
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _room(String code) =>
      _db.collection('rooms').doc(code);

  CollectionReference<Map<String, dynamic>> _peers(String code) =>
      _room(code).collection('peers');

  DocumentReference<Map<String, dynamic>> _peer(String code, String peerId) =>
      _peers(code).doc(peerId);

  Map<String, Object> _stamps() => {
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt':
            Timestamp.fromDate(DateTime.now().add(SignalingService.ttl)),
      };

  // ------------------------------------------------------------------
  // Sala (host)
  // ------------------------------------------------------------------

  /// Crea `rooms/{code}` si no existe. `false` si el código ya está usado.
  @override
  Future<bool> createRoom(String code, {int version = 1}) =>
      _db.runTransaction((tx) async {
        final ref = _room(code);
        final snap = await tx.get(ref);
        if (snap.exists) return false;
        tx.set(ref, {'v': version, ..._stamps()});
        return true;
      });

  @override
  Future<bool> roomExists(String code) async =>
      (await _room(code).get()).exists;

  /// Ofertas nuevas de clientes (solo los documentos agregados).
  @override
  Stream<PeerOffer> watchOffers(String code) => _peers(code)
      .snapshots()
      .expand((q) => q.docChanges)
      .where((c) => c.type == DocumentChangeType.added)
      .map((c) {
        final offer = c.doc.data()?['offer'];
        if (offer is! Map) return null;
        final sdp = offer['sdp'], type = offer['type'];
        if (sdp is! String || type is! String) return null;
        return PeerOffer(c.doc.id, sdp, type);
      })
      .where((o) => o != null)
      .cast<PeerOffer>();

  @override
  Future<void> publishAnswer(
          String code, String peerId, String sdp, String type) =>
      _peer(code, peerId).update({
        'answer': {'sdp': sdp, 'type': type},
      });

  /// Borra la sala y todo lo que cuelga de ella (Firestore no borra
  /// subcolecciones solo).
  @override
  Future<void> closeRoom(String code) async {
    final peers = await _peers(code).get();
    for (final p in peers.docs) {
      await deletePeer(code, p.id);
    }
    await _room(code).delete();
  }

  // ------------------------------------------------------------------
  // Cliente
  // ------------------------------------------------------------------

  /// Crea `peers/{auto}` con la oferta; devuelve el id.
  @override
  Future<String> createPeer(String code, String sdp, String type) async {
    final ref = await _peers(code).add({
      'offer': {'sdp': sdp, 'type': type},
      ..._stamps(),
    });
    return ref.id;
  }

  /// La respuesta del host, cuando llega.
  @override
  Stream<({String sdp, String type})> watchAnswer(String code, String peerId) =>
      _peer(code, peerId)
          .snapshots()
          .map((d) {
            final a = d.data()?['answer'];
            if (a is! Map) return null;
            final sdp = a['sdp'], type = a['type'];
            if (sdp is! String || type is! String) return null;
            return (sdp: sdp, type: type);
          })
          .where((a) => a != null)
          .cast<({String sdp, String type})>();

  // ------------------------------------------------------------------
  // ICE (ambos)
  // ------------------------------------------------------------------

  @override
  Future<void> addCandidate(String code, String peerId,
          {required bool fromHost, required Map<String, dynamic> candidate}) =>
      _peer(code, peerId)
          .collection(fromHost
              ? SignalingService.hostCandidates
              : SignalingService.clientCandidates)
          .add({
        ...candidate,
        'expiresAt':
            Timestamp.fromDate(DateTime.now().add(SignalingService.ttl))
      });

  /// Candidatos nuevos del otro lado.
  @override
  Stream<Map<String, dynamic>> watchCandidates(String code, String peerId,
          {required bool fromHost}) =>
      _peer(code, peerId)
          .collection(fromHost
              ? SignalingService.hostCandidates
              : SignalingService.clientCandidates)
          .snapshots()
          .expand((q) => q.docChanges)
          .where((c) => c.type == DocumentChangeType.added)
          .map((c) => c.doc.data() ?? const <String, dynamic>{});

  /// Borra el documento de un cliente y sus candidatos.
  @override
  Future<void> deletePeer(String code, String peerId) async {
    final ref = _peer(code, peerId);
    for (final side in [
      SignalingService.clientCandidates,
      SignalingService.hostCandidates
    ]) {
      final cands = await ref.collection(side).get();
      for (final c in cands.docs) {
        await c.reference.delete();
      }
    }
    await ref.delete();
  }
}
