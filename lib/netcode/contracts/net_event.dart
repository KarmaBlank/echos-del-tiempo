import '../../game_engine/models/game_session.dart';
import '../../game_engine/models/player_profile.dart';
import '../../game_engine/models/session_action.dart';
import '../../game_engine/models/session_event.dart';

/// Lo que la red le entrega a la sesión (`NetSession.events`). Ver
/// docs/specs/netcode.md § "Contrato".
sealed class NetEvent {
  const NetEvent();
}

/// Host: un cliente se unió (mandó un `hello` válido y recibió su id).
class PeerJoinedEvent extends NetEvent {
  const PeerJoinedEvent(this.peerId, this.profile);
  final String peerId;
  final PlayerProfile profile;
}

/// Host: llegó una acción de [peerId] (el id es el del enlace, nunca uno
/// que venga dentro del mensaje).
class PeerActionEvent extends NetEvent {
  const PeerActionEvent(this.peerId, this.action);
  final String peerId;
  final SessionAction action;
}

/// Host: se cerró la conexión de un cliente que estaba unido.
class PeerLeftEvent extends NetEvent {
  const PeerLeftEvent(this.peerId);
  final String peerId;
}

/// Cliente: el estado autoritativo + los eventos desde el anterior.
class SnapshotEvent extends NetEvent {
  const SnapshotEvent(this.session, this.events);
  final GameSession session;
  final List<SessionEvent> events;
}

/// Se perdió la conexión (cliente: con el host; host: su transporte).
class ConnectionLostEvent extends NetEvent {
  const ConnectionLostEvent(this.reason);
  final String reason;
}
