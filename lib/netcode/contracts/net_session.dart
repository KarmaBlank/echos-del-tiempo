import '../../game_engine/models/game_session.dart';
import '../../game_engine/models/player_profile.dart';
import '../../game_engine/models/session_action.dart';
import '../../game_engine/models/session_event.dart';
import 'net_event.dart';

export 'net_event.dart';

/// Configuración para crear o unirse a una sala.
class SessionConfig {
  const SessionConfig({required this.profile, this.roomCode});

  /// El perfil del jugador local: viaja en el `hello` (cliente). El host
  /// lo usa él mismo para entrar a su sala.
  final PlayerProfile profile;

  /// `null` → crear sala nueva (host); si no, el código para unirse.
  final String? roomCode;
}

/// Error de conexión con un mensaje listo para mostrarle al jugador
/// (`Sala X no encontrada`, `La sala está llena`...).
class NetException implements Exception {
  const NetException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// El contrato que TODO el resto del juego usa para hablar por red.
/// `game_engine` y `features/*` dependen únicamente de esta interfaz.
/// Ver docs/specs/netcode.md § "Contrato".
///
/// Host autoritativo (como el prototipo): el host corre `SessionEngine`,
/// recibe acciones de los clientes ([PeerActionEvent]) y les manda el
/// estado completo con [broadcast]; el cliente manda sus acciones con
/// [sendAction] y recibe [SnapshotEvent].
///
/// Implementaciones (`lib/netcode/`): `loopback` (tests), `lan`
/// (WebSocket), `p2p_webrtc` (WebRTC + señalización por Firestore).
/// Futuras: `dedicated_server`, `rollback`. Cambiar de implementación es
/// registrar otra en el composition root (`app/flavors/main_*.dart`).
///
/// Una instancia = una sala: después de [disconnect] no se reutiliza.
abstract class NetSession {
  /// true si esta instancia es la autoridad del estado (creó la sala).
  bool get isHost;

  /// Id de este jugador dentro de la sala (`h` el host, `p1`... los
  /// clientes). Vacío antes de [connect].
  String get localId;

  /// Código de la sala (para mostrar / compartir). `null` antes de
  /// [connect].
  String? get roomCode;

  /// Eventos entrantes. Stream de **una sola suscripción**: guarda lo que
  /// llega hasta que el controlador de la sesión empieza a escuchar.
  Stream<NetEvent> get events;

  /// Crea la sala (`config.roomCode == null`) o se une. Lanza
  /// [NetException] si no se pudo.
  Future<void> connect(SessionConfig config);

  /// Cliente: manda una acción al host. Quién decide si es válida es el
  /// host, nunca quien envía.
  void sendAction(SessionAction action);

  /// Host: manda el estado completo y los eventos ocurridos desde el
  /// envío anterior a todos los clientes unidos.
  void broadcast(GameSession state, List<SessionEvent> events);

  /// Cierra la sala o sale de ella. Idempotente.
  Future<void> disconnect();
}
