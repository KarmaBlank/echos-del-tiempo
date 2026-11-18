import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/bestiary.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/game_map.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/rules/atlas_rules.dart';

/// Panel abierto sobre el mapa (`panel` del prototipo).
///
/// `inventory` es el panel de personaje abierto en la pestaña INVENTARIO
/// (tecla I).
/// `ecoPortal`: el Portal del Eco del pueblo (ECOS y ATLAS,
/// docs/specs/ecos_atlas.md).
/// `ascension`: la Estatua del Tiempo (PRUEBAS y ASCENSIÓN,
/// docs/specs/ascension.md).
enum WorldPanel {
  missionBoard,
  armory,
  character,
  prep,
  inventory,
  ecoPortal,
  ascension,
}

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
  merchant('[E] Tienda y herrería'),

  /// Frente al Portal del Eco del pueblo.
  ecoPortal('[E] Portal del Eco'),

  /// Frente a la Estatua del Tiempo (ascension.md § 1).
  statue('[E] Estatua del Tiempo'),

  /// Frente a la entrada de una zona (mapa del mundo). El texto real
  /// (`[E] Entrar: <zona>`, bloqueada, próximamente) va en
  /// [SessionView.promptText].
  entrance('[E] Entrar'),

  /// Sobre una escalera (`[E] Bajar al piso N` / `[E] Subir al piso N`).
  stairs('[E] Escalera'),

  /// Frente a un punto de interés del piso (worldgen.md § 11.3). El texto
  /// real va en [SessionView.promptText].
  poi('[E] Usar');

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
    this.saveError,
    this.missionLoot = const [],
    this.promptText,
    this.atlas,
    this.atlasGain,
    this.bestiary,
  });

  /// El bestiario de la cuenta de este dispositivo (`null` hasta
  /// cargarlo; docs/specs/bestiary.md § 2).
  final BestiaryProgress? bestiary;

  /// El Atlas de la cuenta de este dispositivo (`null` hasta cargarlo).
  final AtlasProgress? atlas;

  /// Lo que ganó el Atlas local con el último Eco completado (para el
  /// resultado); `null` si todavía no hubo uno en esta misión.
  final AtlasGain? atlasGain;

  /// Texto del aviso cuando depende del contexto (entradas de zona,
  /// escaleras); si es `null` se usa `prompt.label`.
  final String? promptText;

  /// Lo que dice el aviso de interacción (o `null`).
  String? get promptLabel => promptText ?? prompt?.label;

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

  /// El progreso no se pudo guardar (se sigue intentando): el HUD lo
  /// avisa en rojo (docs/specs/characters.md § 1.4). `null` = guardado.
  final String? saveError;

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
        saveError: saveError,
        missionLoot: missionLoot,
        promptText: prompt != null ? null : promptText,
        atlas: atlas,
        atlasGain: atlasGain,
        bestiary: bestiary,
      );
}
