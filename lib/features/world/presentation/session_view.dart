import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/game_map.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/loot.dart';

/// Panel abierto sobre el mapa (`panel` del prototipo).
///
/// `inventory` es el panel de personaje abierto en la pestaña INVENTARIO
/// (tecla I).
enum WorldPanel { missionBoard, armory, character, prep, inventory }

/// Una línea del chat (`addChat`): de un jugador o de sistema (`sys`).
class ChatLine {
  const ChatLine(this.from, this.text);
  const ChatLine.system(this.text) : from = null;

  /// Nombre de quien escribió; `null` = mensaje de sistema.
  final String? from;
  final String text;

  bool get system => from == null;
}

/// Aviso de interacción cerca de algo (`[E] ...` del prototipo).
enum WorldPrompt {
  missionBoard('[E] Ver misiones'),
  armory('[E] Armería'),
  seal('[E] Activar sello'),
  merchant('[E] Tienda y herrería');

  const WorldPrompt(this.label);
  final String label;
}

/// Lo que la UI dibuja: el snapshot autoritativo de la sesión + el
/// estado propio del cliente (panel, avisos, registro). Inmutable; el
/// `SessionController` emite uno nuevo en cada tick o acción.
class SessionView {
  const SessionView({
    required this.session,
    required this.localId,
    required this.map,
    this.panel,
    this.prompt,
    this.messages = const [],
    this.chat = const [],
    this.battleEvents = const [],
    this.battleEventSeq = 0,
    this.roomCode,
    this.disconnected,
    this.missionLoot = const [],
  });

  /// Drops del jugador local desde que empezó la misión actual (o la
  /// última), en orden (`LootDropEvent`). Para la pantalla de resultado.
  final List<LootDrop> missionLoot;

  final GameSession session;
  final String localId;

  /// Mapa actual (`mapFor`): lobby o el de la misión.
  final GameMap map;
  final WorldPanel? panel;
  final WorldPrompt? prompt;

  /// Mensajes de sistema, el más nuevo al final (máx. 50).
  final List<String> messages;

  /// Chat y mensajes de sistema mezclados, el más nuevo al final (máx. 50).
  final List<ChatLine> chat;

  /// Eventos del último paso de batalla (para números de daño).
  final List<BattleEvent> battleEvents;

  /// Sube con cada `BattleStepEvent` (para animar una sola vez).
  final int battleEventSeq;

  /// Código de la sala de red (`Sala: X` del HUD); `null` sin red.
  final String? roomCode;

  /// Motivo si se perdió la sala (p. ej. el host se fue): la pantalla
  /// del juego vuelve al título y lo muestra.
  final String? disconnected;

  SessionMode get mode => session.mode;
  SessionPlayer? get me => session.players[localId];
  bool get mustAllocate => session.mustAllocate(localId);

  /// Le toca al jugador local y el host espera su comando.
  bool get myTurn {
    final b = session.battle;
    return b != null &&
        b.waitingForPlayer &&
        b.state.currentId == localId &&
        (me?.alive ?? false);
  }

  SessionView copyWith({
    GameSession? session,
    GameMap? map,
    WorldPanel? Function()? panel,
    WorldPrompt? Function()? prompt,
    List<String>? messages,
    List<ChatLine>? chat,
    List<BattleEvent>? battleEvents,
    int? battleEventSeq,
  }) =>
      SessionView(
        session: session ?? this.session,
        localId: localId,
        map: map ?? this.map,
        panel: panel != null ? panel() : this.panel,
        prompt: prompt != null ? prompt() : this.prompt,
        messages: messages ?? this.messages,
        chat: chat ?? this.chat,
        battleEvents: battleEvents ?? this.battleEvents,
        battleEventSeq: battleEventSeq ?? this.battleEventSeq,
        roomCode: roomCode,
        disconnected: disconnected,
        missionLoot: missionLoot,
      );
}
