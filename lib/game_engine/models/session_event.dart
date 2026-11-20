import 'ascension.dart' show TrapKind;
import 'battle_command.dart';
import 'battle_event.dart';
import 'game_map.dart' show PoiKind, QuestKind;
import 'game_session.dart';
import 'item.dart' show CraftOp;
import 'loot.dart';

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

/// [playerId] ([name]) pausó la sala (docs/specs/settings.md § "Pausa").
class PausedEvent extends SessionEvent {
  final String playerId;
  final String name;
  const PausedEvent(this.playerId, this.name);
}

/// [playerId] ([name]) reanudó la sala.
class ResumedEvent extends SessionEvent {
  final String playerId;
  final String name;
  const ResumedEvent(this.playerId, this.name);
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

  /// Calidad del cofre (v0.6, loot.md § 23).
  final ChestTier tier;
  const ChestOpenedEvent(this.playerId, this.credits,
      {this.item, this.weaponId, this.tier = ChestTier.madera});
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

// ---------------- mundo por zonas (docs/specs/worldgen.md § 7.5) ----------------

/// El grupo cambió al piso [floor] (desde 0) de la zona.
class FloorChangedEvent extends SessionEvent {
  final int floor;
  final bool down;
  const FloorChangedEvent(this.floor, {required this.down});
}

/// [playerId] usó el punto de interés [poiId] (worldgen.md § 11.3): abrió
/// una sala secreta o un atajo, activó un santuario o una piedra de paso,
/// encendió un brasero, levantó una reliquia o viajó ([toPoi]).
class PoiUsedEvent extends SessionEvent {
  final String playerId;
  final int poiId;
  final PoiKind kind;
  final BlessingKind? blessing;

  /// Viaje rápido: la piedra de destino.
  final int? toPoi;
  const PoiUsedEvent(this.playerId, this.poiId, this.kind,
      {this.blessing, this.toPoi});
}

/// Se cumplió la misión opcional [questId] del piso [floor] (fanfarria).
class QuestDoneEvent extends SessionEvent {
  final int questId;
  final int floor;
  final QuestKind kind;
  const QuestDoneEvent(this.questId, this.floor, this.kind);
}

/// Se despejó el piso [floor]: se abrió la barrera de su escalera.
class StairsOpenedEvent extends SessionEvent {
  final int floor;
  const StairsOpenedEvent(this.floor);
}

/// [playerId] pisó el vacío en el piso [floor] y volvió al spawn del piso
/// (sin daño; worldgen.md § 9.3).
class FellIntoVoidEvent extends SessionEvent {
  final String playerId;
  final int floor;
  const FellIntoVoidEvent(this.playerId, this.floor);
}

/// [playerId] desbloqueó la zona [zone] (1..10).
class ZoneUnlockedEvent extends SessionEvent {
  final String playerId;
  final int zone;
  const ZoneUnlockedEvent(this.playerId, this.zone);
}

// ---------------- loot v2 (docs/specs/loot.md) ----------------

/// A [playerId] le tocó [drop] de [source] (`battle`, `elite`, `boss`,
/// `chest`, `mission`). [groundId] != null: quedó en el piso (modo con
/// loot en el mapa, o inventario lleno); si no, ya está en su inventario
/// con el `uid` [uid].
class LootDropEvent extends SessionEvent {
  final String playerId;
  final LootDrop drop;
  final LootSource source;
  final int? groundId;
  final String? uid;
  const LootDropEvent(this.playerId, this.drop, this.source,
      {this.groundId, this.uid});
}

/// [playerId] levantó del piso el objeto [groundId].
class LootPickedEvent extends SessionEvent {
  final String playerId;
  final int groundId;
  final LootDrop drop;
  const LootPickedEvent(this.playerId, this.groundId, this.drop);
}

/// [fromId] le dio [drop] a [toId].
class ItemGivenEvent extends SessionEvent {
  final String fromId;
  final String toId;
  final LootDrop drop;
  const ItemGivenEvent(this.fromId, this.toId, this.drop);
}

/// Una operación de forja / fusión de [playerId] sobre el arma [uid].
class CraftedEvent extends SessionEvent {
  final String playerId;
  final CraftOp op;
  final String uid;
  const CraftedEvent(this.playerId, this.op, this.uid);
}

// ---------------- endgame v0.4 (docs/specs/ecos_atlas.md) ----------------

/// Se completó un Eco. Cada cliente cuyo id está en [playerIds] anota
/// las "primeras veces" (tier, zona, jefe) en el Atlas de SU cuenta.
class EcoCompletedEvent extends SessionEvent {
  final List<String> playerIds;
  final int tier;
  final int zone;
  final int boss;
  const EcoCompletedEvent(this.playerIds,
      {required this.tier, required this.zone, required this.boss});
}

/// [playerId] subió a la Maestría [mastery] (+1 punto de árbol, progresión v2).
class MasteryUpEvent extends SessionEvent {
  final String playerId;
  final int mastery;
  const MasteryUpEvent(this.playerId, this.mastery);
}

/// [playerId] activó el Portal del Eco (venció al Devorador).
class EcosUnlockedEvent extends SessionEvent {
  final String playerId;
  const EcosUnlockedEvent(this.playerId);
}

// ---------------- ascensión v0.5 (docs/specs/ascension.md) ----------------

/// Se venció al jefe de la Prueba [trial]. [playerIds]: los que ganaron
/// sus puntos de ascensión (la primera vez, con nivel y requisito).
class TrialCompletedEvent extends SessionEvent {
  final int trial;
  final List<String> playerIds;
  const TrialCompletedEvent(this.trial, this.playerIds);
}

/// [playerId] eligió la ascensión [ascensionId]: cinemática para todos.
class AscensionChosenEvent extends SessionEvent {
  final String playerId;
  final String ascensionId;
  const AscensionChosenEvent(this.playerId, this.ascensionId);
}

/// Se venció al Jefe del Abismo [boss] (1..5). Cada cliente cuyo id está
/// en [playerIds] lo anota en el Atlas de SU cuenta (`x<boss>`,
/// docs/specs/abyss_bosses.md § 1.3).
class AbyssDefeatedEvent extends SessionEvent {
  final int boss;
  final List<String> playerIds;
  const AbyssDefeatedEvent(this.boss, this.playerIds);
}

/// Saltó una trampa de la Prueba sobre [playerId] ([damage] = vida que
/// perdió con las púas; 0 en el pulso).
class TrapTriggeredEvent extends SessionEvent {
  final String playerId;
  final TrapKind kind;
  final int damage;
  const TrapTriggeredEvent(this.playerId, this.kind, this.damage);
}

// ---------------- TUTORIAL v0.9 (docs/specs/combat_tutorial.md) ----------

/// Se completó el TUTORIAL: cada cliente cuyo id está en [playerIds]
/// marca SU cuenta con `tutV = version` y la guarda (§ 6).
class TutorialDoneEvent extends SessionEvent {
  final List<String> playerIds;
  final int version;
  const TutorialDoneEvent(this.playerIds, this.version);
}

// ---------------- Hazañas v0.14 (docs/specs/achievements.md) ----------

/// [playerId] logró la hazaña [id]; el host ya le pagó la recompensa en
/// su perfil de sesión (JSON `ach`: `{p, id}`). El toast lo ve solo él.
class AchievementUnlockedEvent extends SessionEvent {
  final String playerId;
  final String id;
  const AchievementUnlockedEvent(this.playerId, this.id);
}
