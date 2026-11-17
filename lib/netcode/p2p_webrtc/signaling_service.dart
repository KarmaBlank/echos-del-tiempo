/// Una oferta de un cliente que quiere entrar a la sala.
class PeerOffer {
  const PeerOffer(this.peerId, this.sdp, this.type);
  final String peerId;
  final String sdp;
  final String type;
}

/// Falla de la señalización con un mensaje en castellano listo para
/// mostrar (la sesión WebRTC lo envuelve en una `NetException`).
class SignalingException implements Exception {
  const SignalingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Operaciones de señalización que necesita `WebRTCNetSession` para
/// armar las conexiones (SDP offer/answer + ICE). **No** transporta el
/// juego: una vez abierto el `RTCDataChannel`, todo viaja P2P. Ver
/// docs/specs/netcode.md § "P2P por internet" (documentos y reglas).
///
/// ```
/// rooms/{code}                                   {v, createdAt, expiresAt}
/// rooms/{code}/peers/{peerId}                    {offer, answer?, createdAt, expiresAt}
/// rooms/{code}/peers/{peerId}/clientCandidates/* ICE del cliente
/// rooms/{code}/peers/{peerId}/hostCandidates/*   ICE del host
/// ```
///
/// Implementaciones: `FirestoreSignalingService` (SDK `cloud_firestore`,
/// web/Android/iOS) y `FirestoreRestSignaling` (API REST, escritorio).
/// Los `watch*` son streams: cancelar la suscripción deja de escuchar
/// (en REST, deja de consultar).
///
/// Este archivo es Dart puro (sin Flutter) a propósito: lo usa también
/// `tool/p2p_signaling_smoke.dart`.
abstract interface class SignalingService {
  /// Cuánto vive un documento si nadie lo borra (política TTL).
  static const ttl = Duration(hours: 6);

  static const clientCandidates = 'clientCandidates';
  static const hostCandidates = 'hostCandidates';

  // --- Sala (host) ---

  /// Crea `rooms/{code}` si no existe. `false` si el código ya está usado.
  Future<bool> createRoom(String code, {int version = 1});

  Future<bool> roomExists(String code);

  /// Ofertas nuevas de clientes (cada `peers/*` se emite una sola vez).
  Stream<PeerOffer> watchOffers(String code);

  Future<void> publishAnswer(
      String code, String peerId, String sdp, String type);

  /// Borra la sala y todo lo que cuelga de ella.
  Future<void> closeRoom(String code);

  // --- Cliente ---

  /// Crea `peers/{auto}` con la oferta; devuelve el id.
  Future<String> createPeer(String code, String sdp, String type);

  /// La respuesta del host, cuando llega.
  Stream<({String sdp, String type})> watchAnswer(String code, String peerId);

  // --- ICE (ambos) ---

  Future<void> addCandidate(String code, String peerId,
      {required bool fromHost, required Map<String, dynamic> candidate});

  /// Candidatos nuevos de un lado ([fromHost]: los del host).
  Stream<Map<String, dynamic>> watchCandidates(String code, String peerId,
      {required bool fromHost});

  /// Borra el documento de un cliente y sus candidatos.
  Future<void> deletePeer(String code, String peerId);
}
