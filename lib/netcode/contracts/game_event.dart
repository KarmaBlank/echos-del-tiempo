/// Lo que la sesión de red entrega a `features/*` cuando el estado
/// autoritativo cambia. Igual que [GameAction], es un DTO puro.
sealed class GameEvent {
  const GameEvent();
}

/// El snapshot completo del estado del juego, serializado por quien sea
/// la autoridad (host P2P hoy, servidor dedicado mañana) y repartido a
/// todos los peers/clientes. `features/*` reconstruye su UI a partir de
/// esto — nunca mantiene estado de juego propio por fuera de esto.
class StateSnapshotEvent extends GameEvent {
  final Map<String, dynamic> raw;
  const StateSnapshotEvent(this.raw);
}

class PeerJoinedEvent extends GameEvent {
  final String peerId;
  final String displayName;
  const PeerJoinedEvent(this.peerId, this.displayName);
}

class PeerLeftEvent extends GameEvent {
  final String peerId;
  const PeerLeftEvent(this.peerId);
}

class ConnectionLostEvent extends GameEvent {
  final String reason;
  const ConnectionLostEvent(this.reason);
}

class SystemMessageEvent extends GameEvent {
  final String text;
  const SystemMessageEvent(this.text);
}
