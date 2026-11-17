import 'battle_command.dart';
import 'battle_event.dart';
import 'game_session.dart';

/// Lo que pasó en un paso de la sesión, en orden, para que la UI lo
/// muestre (mensajes, sonidos, animaciones). El estado nuevo siempre
/// alcanza para dibujar; los eventos son para lo que "ocurre una vez".
sealed class SessionEvent {
  const SessionEvent();
}

/// Mensaje de sistema para el chat (`sysChatAll`).
class SystemMessageEvent extends SessionEvent {
  final String text;
  const SystemMessageEvent(this.text);
}

/// Mensaje de chat de un jugador (`{t:'chat', from, txt}` del host).
class ChatMessageEvent extends SessionEvent {
  final String playerId;

  /// Nombre del jugador cuando escribió.
  final String from;
  final String text;
  const ChatMessageEvent(this.playerId, this.from, this.text);
}

class PlayerJoinedEvent extends SessionEvent {
  final String playerId;
  const PlayerJoinedEvent(this.playerId);
}

class PlayerLeftEvent extends SessionEvent {
  final String playerId;
  const PlayerLeftEvent(this.playerId);
}

class MissionStartedEvent extends SessionEvent {
  final String missionId;
  final int seed;
  const MissionStartedEvent(this.missionId, this.seed);
}

class ObjectiveProgressEvent extends SessionEvent {
  final ObjectiveKind kind;
  final int count;
  final int goal;
  const ObjectiveProgressEvent(this.kind, this.count, this.goal);
}

/// Se abrió la barrera del jefe.
class GateOpenedEvent extends SessionEvent {
  const GateOpenedEvent();
}

class ChestOpenedEvent extends SessionEvent {
  final String playerId;
  final int credits;

  /// Poción que salió, si salió alguna.
  final BattleItem? item;
  final String? weaponId;
  const ChestOpenedEvent(this.playerId, this.credits, {this.item, this.weaponId});
}

class BattleStartedEvent extends SessionEvent {
  final int battleId;
  final int fieldEnemyId;
  final bool boss;
  final bool elite;
  const BattleStartedEvent(this.battleId, this.fieldEnemyId,
      {this.boss = false, this.elite = false});
}

/// Eventos del `BattleEngine` de un paso de la batalla, para animarlos.
class BattleStepEvent extends SessionEvent {
  final List<BattleEvent> events;
  const BattleStepEvent(this.events);
}

class LevelUpEvent extends SessionEvent {
  final String playerId;
  final int level;
  const LevelUpEvent(this.playerId, this.level);
}

/// Terminó la pausa final de la batalla y se volvió al campo / resultado.
class BattleFinishedEvent extends SessionEvent {
  final bool victory;
  const BattleFinishedEvent(this.victory);
}

class WeaponDropEvent extends SessionEvent {
  final String playerId;
  final String weaponId;

  /// `elite` o `mission` (fin de misión).
  final String source;
  const WeaponDropEvent(this.playerId, this.weaponId, this.source);
}

class MissionEndedEvent extends SessionEvent {
  final MissionResult result;
  const MissionEndedEvent(this.result);
}

class ReturnedToLobbyEvent extends SessionEvent {
  const ReturnedToLobbyEvent();
}
