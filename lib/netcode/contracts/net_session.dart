import 'game_action.dart';
import 'game_event.dart';

/// Configuración para conectar/crear una sesión. Cada implementación de
/// [NetSession] decide qué campos de `extra` usa (código de sala para
/// P2P, host:port para servidor dedicado, etc.) — el resto del juego
/// solo le pasa este objeto, no sabe qué hay adentro.
class SessionConfig {
  final String displayName;
  final String? roomCode; // null => crear sala nueva
  final Map<String, dynamic> extra;
  const SessionConfig({
    required this.displayName,
    this.roomCode,
    this.extra = const {},
  });
}

/// El contrato que TODO el resto del juego usa para hablar por red.
/// `game_engine` y `features/*` dependen únicamente de esta interfaz.
///
/// Implementaciones previstas:
///  - `netcode/p2p_webrtc`      → WebRTC + señalización por Firestore (HOY)
///  - `netcode/dedicated_server` → cliente↔servidor autoritativo (futuro)
///  - `netcode/rollback`         → rollback netcode para la exploración
///                                  de campo en tiempo real (futuro, opcional)
///
/// Cambiar de implementación es escribir una clase nueva que cumpla este
/// contrato y registrarla en el composition root (`app/flavors/main_*.dart`).
/// Nada en `features/*` cambia.
abstract class NetSession {
  /// true si esta instancia es la autoridad del estado (host P2P,
  /// o el servidor dedicado desde la perspectiva del servidor).
  bool get isHost;

  /// Id único de este peer/cliente dentro de la sesión.
  String get localId;

  /// Eventos entrantes: snapshots de estado, peers que entran/salen, etc.
  Stream<GameEvent> get events;

  Future<void> connect(SessionConfig config);

  /// Envía una acción. En P2P: al host (o se auto-aplica si soy el host).
  /// En servidor dedicado: al servidor. La implementación decide el viaje;
  /// quien llama no necesita saberlo.
  void sendAction(GameAction action);

  Future<void> disconnect();
}
