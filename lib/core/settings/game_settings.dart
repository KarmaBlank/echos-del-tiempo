import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_engine/models/turn_timer.dart';
import '../../game_engine/rules/ult_browse_rules.dart';
import '../text/text_detail.dart';
import 'frame_limiter.dart';
import 'graphics.dart';
import 'window_mode.dart';

export '../../game_engine/models/turn_timer.dart';
export '../text/text_detail.dart' show TextDetail;
export 'graphics.dart';

/// Destellos de pantalla completa en batalla (accesibilidad): el rojo de
/// "te pegaron fuerte", el blanco de los golpes brutales y del quiebre y
/// el tinte de "tiempo detenido". Ver docs/specs/settings.md § "PANTALLA".
enum FlashLevel {
  normal(1),
  reduced(0.35),
  off(0);

  const FlashLevel(this.factor);

  /// Multiplica el alfa de cada destello.
  final double factor;
}

/// "Oscuridad" (accesibilidad, lighting.md § 7): cuánto oscurecen la
/// noche y las mazmorras oscuras. [keep]: parte de la oscuridad que queda
/// (1 = toda, 0 = nada: todo se ve como de día).
enum DarknessLevel {
  normal(1),
  soft(0.45),
  off(0);

  const DarknessLevel(this.keep);
  final double keep;
}

/// "Tamaño del texto" (accesibilidad): cuánto se agranda el texto de la
/// UI sobre la escala base (`RetroType`, `RetroTextScaler`). Ver
/// docs/specs/settings.md § 3 y docs/specs/ui_style.md § "Tipografía".
enum TextSize {
  normal(1),
  large(1.25),
  huge(1.5),

  /// ENORME (v0.8.1, accessibility.md § 9.3): ×2 sobre Normal. Los
  /// paneles scrollean y los tooltips pasan a columnas.
  enormous(2);

  const TextSize(this.factor);

  /// Multiplica el texto chico (los títulos crecen menos).
  final double factor;

  static TextSize fromName(Object? v, TextSize def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// "Fuente de lectura" (accesibilidad): la fuente del texto de lectura
/// (tooltips, fichas, chat, menús). Títulos y botones siguen en Press
/// Start 2P (salvo [GameSettings.readingTitles]). Ver
/// docs/specs/settings.md § 3.7 y accessibility.md § 9.1.
enum ReadingFont {
  /// VT323 (por defecto, v0.5).
  vt323,

  /// CLÁSICA: Press Start 2P, como en v0.4.
  classic,

  /// ATKINSON (v0.8.1): Atkinson Hyperlegible, hecha para baja visión.
  /// No es pixel: px enteros sin grilla.
  atkinson;

  static ReadingFont fromName(Object? v, ReadingFont def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// "Modo daltónico" (accesibilidad, docs/specs/accessibility.md § 3):
/// cambia los colores con significado (mejora / empeora, HP / MP,
/// rarezas, barras de los enemigos, números de daño y cura) por una
/// paleta que se distingue con ese tipo de visión. Ver `VisionPalette`.
enum ColorVision {
  off,

  /// Verde / rojo (la más común).
  deuteranopia,

  /// Rojo (el rojo se ve oscuro).
  protanopia,

  /// Azul / amarillo.
  tritanopia;

  static ColorVision fromName(Object? v, ColorVision def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// "Tema de interfaz" (accesibilidad, docs/specs/accessibility.md § 8):
/// los colores de paneles, botones, campos, bordes y texto de toda la UI
/// (menús, tooltips, HUD, batalla). El arte (arenas, mapa, sprites) no
/// cambia. Ver `UiTheme`.
enum InterfaceTheme {
  /// El de siempre: paneles azul marino.
  blue,

  /// Paneles casi negros (escala neutra), bordes grises apagados y dorado solo
  /// para la selección y el foco.
  dark,

  /// Fondo negro, texto blanco, foco amarillo, bordes gruesos; color solo
  /// donde significa algo.
  highContrast;

  static InterfaceTheme fromName(Object? v, InterfaceTheme def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// "Colores del texto" (accesibilidad, accessibility.md § 8): COMPLETO
/// (cada markup con sus colores) o REDUCIDO (pocos colores con
/// significado; el resto, texto base o atenuado).
enum TextColorMode {
  full,
  reduced;

  static TextColorMode fromName(Object? v, TextColorMode def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// "Espaciado" (accesibilidad, accessibility.md § 8): NORMAL o AMPLIO
/// (más interlineado, separación entre líneas de las fichas, más aire en
/// filas y tarjetas y separadores entre secciones de los tooltips).
enum UiSpacing {
  normal,
  wide;

  static UiSpacing fromName(Object? v, UiSpacing def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// "Espaciado entre letras" (accessibility.md § 9.4): NORMAL o AMPLIO
/// (+0.08 em en el texto de lectura).
enum LetterSpacing {
  normal,
  wide;

  static LetterSpacing fromName(Object? v, LetterSpacing def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// "Duración de los avisos" (accessibility.md § 9.5): cuánto se ven los
/// avisos del HUD (loot, build, chat plegado, puntos sin usar, misión
/// opcional). HASTA CERRAR: quedan hasta tocar su × o `Retroceso`.
enum NoticeDuration {
  normal(1),
  long(2),
  untilDismissed(double.infinity);

  const NoticeDuration(this.factor);

  /// Multiplica la duración de cada aviso (infinito = hasta cerrarlo).
  final double factor;

  bool get persistent => factor.isInfinite;

  /// [base] con esta duración (`null` = hasta cerrarlo).
  Duration? scale(Duration base) => persistent
      ? null
      : Duration(microseconds: (base.inMicroseconds * factor).round());

  static NoticeDuration fromName(Object? v, NoticeDuration def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// "Fondo del texto en el mapa" (accessibility.md § 9.6): detrás de los
/// nombres, carteles, avisos y etiquetas de loot del mapa.
enum MapLabelBackdrop {
  /// Como siempre: sombra de 1 px.
  none,

  /// Franja oscura translúcida detrás del texto.
  shaded,

  /// Caja opaca con borde.
  box;

  static MapLabelBackdrop fromName(Object? v, MapLabelBackdrop def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// "Registro de batalla" (accessibility.md § 9.7): NORMAL (una línea que
/// se reemplaza) o EXTENDIDO (las 3 últimas, cada una más tiempo).
enum BattleLogMode {
  normal,
  extended;

  static BattleLogMode fromName(Object? v, BattleLogMode def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// Esquina del indicador de FPS y ping (docs/specs/settings.md § 3.9).
enum OverlayCorner {
  topRight,
  topLeft,
  bottomRight,
  bottomLeft;

  bool get top => this == topRight || this == topLeft;
  bool get right => this == topRight || this == bottomRight;

  static OverlayCorner fromName(Object? v, OverlayCorner def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// "Chat" (JUEGO, v0.8.1): plegado en una píldora `CHAT [ENTER]` hasta
/// que se abre, o siempre visible como antes. Ver
/// docs/specs/exploration.md § "Chat".
enum ChatVisibility {
  hidden,
  always;

  static ChatVisibility fromName(Object? v, ChatVisibility def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}

/// Ajustes de pantalla y de juego (todo lo que no es audio). Se guardan
/// en `game.json` junto al perfil. Ver docs/specs/settings.md.
class GameSettings {
  const GameSettings({
    this.fullscreen = false,
    this.screenShake = true,
    this.flashes = FlashLevel.normal,
    this.darkness = DarknessLevel.normal,
    this.damageNumbers = true,
    this.confirmDrop = true,
    this.scale = ScaleMode.fit,
    this.crt = CrtLevel.soft,
    this.particles = ParticleLevel.high,
    this.reflections = ReflectionLevel.high,
    this.fpsLimit = FpsLimit.fps60,
    this.textSize = TextSize.normal,
    this.readingFont = ReadingFont.vt323,
    this.buildNotices = true,
    this.colorVision = ColorVision.off,
    this.reduceMotion = false,
    this.turnTimer = TurnTimer.normal,
    this.combatMode = '',
    this.seenPatchNotes = '',
    this.perfOverlay = false,
    this.perfCorner = OverlayCorner.topRight,
    this.uiTheme = InterfaceTheme.highContrast,
    this.textColors = TextColorMode.reduced,
    this.spacing = UiSpacing.normal,
    this.chat = ChatVisibility.hidden,
    this.chatNotices = true,
    this.objectivesCollapsed = false,
    this.partyExpanded = false,
    this.minimapZoom = 3,
    this.readingTitles = true,
    this.letterSpacing = LetterSpacing.normal,
    this.noticeDuration = NoticeDuration.normal,
    this.mapLabelBackdrop = MapLabelBackdrop.none,
    this.battleLog = BattleLogMode.normal,
    this.ultBrowse = const UltBrowsePrefs(),
    this.textDetail = TextDetail.summary,
    this.locale = '',
  });

  /// Pantalla completa sin bordes (solo Windows; ver `WindowMode`).
  final bool fullscreen;

  /// Sacudida de la escena de batalla en golpes fuertes.
  final bool screenShake;
  final FlashLevel flashes;

  /// Oscuridad de la noche y las mazmorras oscuras (lighting.md § 7).
  final DarknessLevel darkness;

  /// Números de daño / cura flotantes en la escena de batalla.
  final bool damageNumbers;

  /// Pedir confirmación antes de tirar un objeto al piso.
  final bool confirmDrop;

  /// Escalado del mundo pixelado (mapa y batalla).
  final ScaleMode scale;

  /// Filtro retro CRT sobre toda la pantalla. SUAVE por defecto desde
  /// v0.49.9 (FUERTE desde v0.8.2, antes NORMAL). Un `game.json` de
  /// versión < 3 pasa una sola vez a SUAVE (sea cual sea el nivel
  /// guardado); desde la versión 3 se respeta cualquier valor guardado.
  final CrtLevel crt;

  /// Cantidad de partículas.
  final ParticleLevel particles;

  /// Water reflections (water_reflections.md § 6).
  final ReflectionLevel reflections;

  /// Tope de cuadros por segundo.
  final FpsLimit fpsLimit;

  /// Tamaño del texto de la UI (accesibilidad).
  final TextSize textSize;

  /// Fuente del texto de lectura (accesibilidad).
  final ReadingFont readingFont;

  /// Avisos de avance del plan de build en el HUD y el chat
  /// (docs/specs/build_planner.md § 5).
  final bool buildNotices;

  /// Paleta para daltonismo (accesibilidad).
  final ColorVision colorVision;

  /// "Reducir movimiento" (accesibilidad): sin sacudida, destellos a lo
  /// sumo SUAVES, sin parpadeos, sin zoom de cámara de las ULT, arena
  /// quieta y fundido corto en vez del barrido de bloques. Ver
  /// docs/specs/accessibility.md § 4.
  final bool reduceMotion;

  /// Tiempo de turno en batalla. Jugando solo vale este; en co-op, el
  /// del anfitrión de la sala.
  final TurnTimer turnTimer;

  /// Modo de combate de la sala que arma este jugador como anfitrión
  /// (turn_modes.md § 1): el `name` de un `CombatMode`; vacío = el de por
  /// defecto.
  final String combatMode;

  /// Versión más nueva de las notas del parche que el jugador ya abrió
  /// (title_screen.md § 4.1): `0.37.1`; vacío = nunca las abrió.
  final String seenPatchNotes;

  /// "FPS Y PING": indicador en una esquina (settings.md § 3.9).
  final bool perfOverlay;

  /// En qué esquina va el indicador.
  final OverlayCorner perfCorner;

  /// Tema de interfaz (accesibilidad, v0.8.1). ALTO CONTRASTE por defecto
  /// desde v0.8.2 (antes OSCURO); un `game.json` con `uiTheme` lo conserva.
  final InterfaceTheme uiTheme;

  /// Colores del texto (accesibilidad, v0.8.1).
  final TextColorMode textColors;

  /// Espaciado de la UI (accesibilidad, v0.8.1).
  final UiSpacing spacing;

  /// Chat plegado o siempre visible (HUD, v0.8.1).
  final ChatVisibility chat;

  /// Con el chat plegado, las líneas de sistema importantes aparecen 4 s
  /// encima de la píldora (v0.8.1).
  final bool chatNotices;

  /// Caja de objetivos plegada (se recuerda; tecla J, v0.8.1).
  final bool objectivesCollapsed;

  /// Cajas del grupo del HUD del mapa desplegadas (arma, pts, XP, pociones)
  /// en vez de compactas (una fila por miembro). Se recuerda; tecla H o
  /// clic en una caja (v0.8.2, exploration.md § "HUD").
  final bool partyExpanded;

  /// Zoom del minimapa del HUD: 1 = el piso entero (como antes de v0.8.1),
  /// 2 y 3 = ventana centrada en el jugador (rueda del mouse / `+` `−`).
  final int minimapZoom;

  static const minimapZooms = 3;

  /// "Títulos con la fuente de lectura" (accesibilidad, v0.8.1): títulos,
  /// botones y pestañas en la fuente de lectura en vez de Press Start 2P.
  final bool readingTitles;

  /// Espaciado entre letras del texto de lectura (v0.8.1).
  final LetterSpacing letterSpacing;

  /// Cuánto duran los avisos del HUD (v0.8.1).
  final NoticeDuration noticeDuration;

  /// Fondo detrás de las etiquetas del mapa (v0.8.1).
  final MapLabelBackdrop mapLabelBackdrop;

  /// Banda del log de batalla: una línea o las 3 últimas (v0.8.1).
  final BattleLogMode battleLog;

  /// Filtros y orden de PERSONAJE → ULT (ultimates_v2.md § 2.1.1), por
  /// equipo.
  final UltBrowsePrefs ultBrowse;

  /// TEXTOS (ui_minimal.md § 8, settings.md § 3.10): RESUMIDO (por
  /// defecto, también para quien ya tenía `game.json`) o DETALLADO.
  final TextDetail textDetail;

  /// IDIOMA (docs/specs/i18n.md § 3.1): tag del idioma elegido (`en`,
  /// `es-AR`); vacío = automático (Steam / sistema).
  final String locale;

  /// Sacudida efectiva (REDUCIR MOVIMIENTO la apaga).
  bool get shakeOn => screenShake && !reduceMotion;

  /// Alfa efectivo de los destellos: REDUCIR MOVIMIENTO los deja a lo
  /// sumo en SUAVES.
  double get flashFactor => reduceMotion
      ? (flashes.factor < FlashLevel.reduced.factor
          ? flashes.factor
          : FlashLevel.reduced.factor)
      : flashes.factor;

  GameSettings copyWith({
    bool? fullscreen,
    bool? screenShake,
    FlashLevel? flashes,
    DarknessLevel? darkness,
    bool? damageNumbers,
    bool? confirmDrop,
    ScaleMode? scale,
    CrtLevel? crt,
    ParticleLevel? particles,
    ReflectionLevel? reflections,
    FpsLimit? fpsLimit,
    TextSize? textSize,
    ReadingFont? readingFont,
    bool? buildNotices,
    ColorVision? colorVision,
    bool? reduceMotion,
    TurnTimer? turnTimer,
    String? combatMode,
    String? seenPatchNotes,
    bool? perfOverlay,
    OverlayCorner? perfCorner,
    InterfaceTheme? uiTheme,
    TextColorMode? textColors,
    UiSpacing? spacing,
    ChatVisibility? chat,
    bool? chatNotices,
    bool? objectivesCollapsed,
    bool? partyExpanded,
    int? minimapZoom,
    bool? readingTitles,
    LetterSpacing? letterSpacing,
    NoticeDuration? noticeDuration,
    MapLabelBackdrop? mapLabelBackdrop,
    BattleLogMode? battleLog,
    UltBrowsePrefs? ultBrowse,
    TextDetail? textDetail,
    String? locale,
  }) =>
      GameSettings(
        fullscreen: fullscreen ?? this.fullscreen,
        screenShake: screenShake ?? this.screenShake,
        flashes: flashes ?? this.flashes,
        darkness: darkness ?? this.darkness,
        damageNumbers: damageNumbers ?? this.damageNumbers,
        confirmDrop: confirmDrop ?? this.confirmDrop,
        scale: scale ?? this.scale,
        crt: crt ?? this.crt,
        particles: particles ?? this.particles,
        reflections: reflections ?? this.reflections,
        fpsLimit: fpsLimit ?? this.fpsLimit,
        textSize: textSize ?? this.textSize,
        readingFont: readingFont ?? this.readingFont,
        buildNotices: buildNotices ?? this.buildNotices,
        colorVision: colorVision ?? this.colorVision,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        turnTimer: turnTimer ?? this.turnTimer,
        combatMode: combatMode ?? this.combatMode,
        seenPatchNotes: seenPatchNotes ?? this.seenPatchNotes,
        perfOverlay: perfOverlay ?? this.perfOverlay,
        perfCorner: perfCorner ?? this.perfCorner,
        uiTheme: uiTheme ?? this.uiTheme,
        textColors: textColors ?? this.textColors,
        spacing: spacing ?? this.spacing,
        chat: chat ?? this.chat,
        chatNotices: chatNotices ?? this.chatNotices,
        objectivesCollapsed: objectivesCollapsed ?? this.objectivesCollapsed,
        partyExpanded: partyExpanded ?? this.partyExpanded,
        minimapZoom: (minimapZoom ?? this.minimapZoom).clamp(1, minimapZooms),
        readingTitles: readingTitles ?? this.readingTitles,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        noticeDuration: noticeDuration ?? this.noticeDuration,
        mapLabelBackdrop: mapLabelBackdrop ?? this.mapLabelBackdrop,
        battleLog: battleLog ?? this.battleLog,
        ultBrowse: ultBrowse ?? this.ultBrowse,
        textDetail: textDetail ?? this.textDetail,
        locale: locale ?? this.locale,
      );

  /// Versión del formato guardado. v2 (v0.13.1): `readingTitles` pasó a SÍ
  /// por defecto; un archivo sin versión (v1) que lo tenga en NO lo tenía
  /// por el default viejo (v1 no distingue "elegido"), así que migra a SÍ.
  static const formatVersion = 3;

  Map<String, Object?> toJson() => {
        'version': formatVersion,
        'fullscreen': fullscreen,
        'shake': screenShake,
        'flashes': flashes.name,
        'darkness': darkness.name,
        'damageNumbers': damageNumbers,
        'confirmDrop': confirmDrop,
        'scale': scale.name,
        'crt': crt.name,
        'particles': particles.name,
        'reflections': reflections.name,
        'fpsLimit': fpsLimit.json,
        'textSize': textSize.name,
        'readingFont': readingFont.name,
        'buildNotices': buildNotices,
        'colorVision': colorVision.name,
        'reduceMotion': reduceMotion,
        'turnTimer': turnTimer.name,
        'combatMode': combatMode,
        'seenPatchNotes': seenPatchNotes,
        'perfOverlay': perfOverlay,
        'perfCorner': perfCorner.name,
        'uiTheme': uiTheme.name,
        'textColors': textColors.name,
        'spacing': spacing.name,
        'chat': chat.name,
        'chatNotices': chatNotices,
        'objectivesCollapsed': objectivesCollapsed,
        'partyExpanded': partyExpanded,
        'minimapZoom': minimapZoom,
        'readingTitles': readingTitles,
        'letterSpacing': letterSpacing.name,
        'noticeDuration': noticeDuration.name,
        'mapLabelBackdrop': mapLabelBackdrop.name,
        'battleLog': battleLog.name,
        'ultBrowse': ultBrowse.toJson(),
        'textDetail': textDetail.name,
        'locale': locale,
      };

  /// Valores inválidos o ausentes caen al de por defecto. Claves viejas
  /// (`battleSpeed` de v0.2.1) se ignoran.
  factory GameSettings.fromJson(Map<String, Object?> json) {
    const d = GameSettings();
    bool flag(Object? v, bool def) => v is bool ? v : def;
    final version = json['version'] is int ? json['version'] as int : 1;
    return GameSettings(
      fullscreen: flag(json['fullscreen'], d.fullscreen),
      screenShake: flag(json['shake'], d.screenShake),
      flashes: FlashLevel.values.firstWhere((f) => f.name == json['flashes'],
          orElse: () => d.flashes),
      darkness: DarknessLevel.values.firstWhere(
          (f) => f.name == json['darkness'],
          orElse: () => d.darkness),
      damageNumbers: flag(json['damageNumbers'], d.damageNumbers),
      confirmDrop: flag(json['confirmDrop'], d.confirmDrop),
      scale: ScaleMode.fromName(json['scale'], d.scale),
      // v0.49.9: todo `game.json` anterior pasa una vez a SUAVE.
      crt: version < 3 ? CrtLevel.soft : CrtLevel.fromName(json['crt'], d.crt),
      particles: ParticleLevel.fromName(json['particles'], d.particles),
      reflections:
          ReflectionLevel.fromName(json['reflections'], d.reflections),
      fpsLimit: FpsLimit.fromJson(json['fpsLimit'], d.fpsLimit),
      textSize: TextSize.fromName(json['textSize'], d.textSize),
      readingFont: ReadingFont.fromName(json['readingFont'], d.readingFont),
      buildNotices: flag(json['buildNotices'], d.buildNotices),
      colorVision: ColorVision.fromName(json['colorVision'], d.colorVision),
      reduceMotion: flag(json['reduceMotion'], d.reduceMotion),
      turnTimer: TurnTimer.fromName(json['turnTimer'], d.turnTimer),
      combatMode: json['combatMode'] is String
          ? json['combatMode'] as String
          : d.combatMode,
      seenPatchNotes: json['seenPatchNotes'] is String
          ? json['seenPatchNotes'] as String
          : d.seenPatchNotes,
      perfOverlay: flag(json['perfOverlay'], d.perfOverlay),
      perfCorner: OverlayCorner.fromName(json['perfCorner'], d.perfCorner),
      uiTheme: InterfaceTheme.fromName(json['uiTheme'], d.uiTheme),
      textColors: TextColorMode.fromName(json['textColors'], d.textColors),
      spacing: UiSpacing.fromName(json['spacing'], d.spacing),
      chat: ChatVisibility.fromName(json['chat'], d.chat),
      chatNotices: flag(json['chatNotices'], d.chatNotices),
      objectivesCollapsed:
          flag(json['objectivesCollapsed'], d.objectivesCollapsed),
      partyExpanded: flag(json['partyExpanded'], d.partyExpanded),
      minimapZoom: switch (json['minimapZoom']) {
        final int z when z >= 1 && z <= minimapZooms => z,
        _ => d.minimapZoom,
      },
      readingTitles: version < 2
          ? d.readingTitles
          : flag(json['readingTitles'], d.readingTitles),
      letterSpacing:
          LetterSpacing.fromName(json['letterSpacing'], d.letterSpacing),
      noticeDuration:
          NoticeDuration.fromName(json['noticeDuration'], d.noticeDuration),
      mapLabelBackdrop: MapLabelBackdrop.fromName(
          json['mapLabelBackdrop'], d.mapLabelBackdrop),
      battleLog: BattleLogMode.fromName(json['battleLog'], d.battleLog),
      ultBrowse: UltBrowsePrefs.fromJson(json['ultBrowse']),
      textDetail: TextDetail.fromName(json['textDetail'], d.textDetail),
      locale: json['locale'] is String ? json['locale'] as String : d.locale,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameSettings &&
      other.fullscreen == fullscreen &&
      other.screenShake == screenShake &&
      other.flashes == flashes &&
      other.darkness == darkness &&
      other.damageNumbers == damageNumbers &&
      other.confirmDrop == confirmDrop &&
      other.scale == scale &&
      other.crt == crt &&
      other.particles == particles &&
      other.reflections == reflections &&
      other.fpsLimit == fpsLimit &&
      other.textSize == textSize &&
      other.readingFont == readingFont &&
      other.buildNotices == buildNotices &&
      other.colorVision == colorVision &&
      other.reduceMotion == reduceMotion &&
      other.turnTimer == turnTimer &&
      other.combatMode == combatMode &&
      other.seenPatchNotes == seenPatchNotes &&
      other.perfOverlay == perfOverlay &&
      other.perfCorner == perfCorner &&
      other.uiTheme == uiTheme &&
      other.textColors == textColors &&
      other.spacing == spacing &&
      other.chat == chat &&
      other.chatNotices == chatNotices &&
      other.objectivesCollapsed == objectivesCollapsed &&
      other.partyExpanded == partyExpanded &&
      other.minimapZoom == minimapZoom &&
      other.readingTitles == readingTitles &&
      other.letterSpacing == letterSpacing &&
      other.noticeDuration == noticeDuration &&
      other.mapLabelBackdrop == mapLabelBackdrop &&
      other.battleLog == battleLog &&
      other.ultBrowse == ultBrowse &&
      other.textDetail == textDetail &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(
      fullscreen,
      screenShake,
      flashes,
      damageNumbers,
      confirmDrop,
      scale,
      crt,
      particles,
      fpsLimit,
      textSize,
      readingFont,
      buildNotices,
      colorVision,
      reduceMotion,
      turnTimer,
      Object.hash(combatMode, seenPatchNotes, reflections),
      perfOverlay,
      perfCorner,
      Object.hash(uiTheme, textColors, spacing, chat, chatNotices,
          objectivesCollapsed, minimapZoom),
      Object.hash(readingTitles, letterSpacing, noticeDuration,
          mapLabelBackdrop, battleLog, partyExpanded, ultBrowse, textDetail,
          darkness, locale));

  @override
  String toString() => 'GameSettings(${toJson()})';
}

/// Dónde se guardan los ajustes de juego.
abstract interface class GameSettingsStore {
  Future<GameSettings?> load();
  Future<void> save(GameSettings settings);
}

/// En memoria (tests, plataformas sin carpeta de datos conocida).
class InMemoryGameSettingsStore implements GameSettingsStore {
  InMemoryGameSettingsStore([this.saved]);

  GameSettings? saved;

  @override
  Future<GameSettings?> load() async => saved;

  @override
  Future<void> save(GameSettings settings) async => saved = settings;
}

/// `game.json` junto al perfil (escritura atómica), al lado de
/// `audio.json` (que sigue siendo el de los volúmenes).
class JsonFileGameSettingsStore implements GameSettingsStore {
  JsonFileGameSettingsStore(this.file);

  JsonFileGameSettingsStore.inDirectory(String dir)
      : file = File('$dir${Platform.pathSeparator}$fileName');

  static const fileName = 'game.json';

  final File file;

  @override
  Future<GameSettings?> load() async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, Object?> ? GameSettings.fromJson(json) : null;
    } catch (_) {
      return null; // corrupto: por defecto
    }
  }

  @override
  Future<void> save(GameSettings settings) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}

/// Los ajustes de juego vivos: cada cambio se aplica (la ventana y el
/// límite de FPS; el resto lo leen el mapa, la batalla, el filtro CRT y
/// el inventario del provider) y se guarda.
class GameSettingsController extends StateNotifier<GameSettings> {
  GameSettingsController({
    required this.store,
    this.window = const WindowMode.unsupported(),
    this.frameLimiter,
    GameSettings initial = const GameSettings(),
  }) : super(initial) {
    frameLimiter?.fps = initial.fpsLimit.fps;
  }

  final GameSettingsStore store;
  final WindowMode window;

  /// El limitador de cuadros de la app (`null` en tests: no hay binding).
  final FrameLimiter? frameLimiter;

  /// Carga lo guardado (si hay) y lo aplica (p. ej. arranca en pantalla
  /// completa si así quedó).
  Future<void> load() async {
    GameSettings? s;
    try {
      s = await store.load();
    } catch (_) {
      s = null;
    }
    if (s == null || !mounted) return;
    state = s;
    frameLimiter?.fps = s.fpsLimit.fps;
    if (s.fullscreen) await window.setFullscreen(true);
  }

  /// Cambia, aplica y guarda.
  Future<void> update(GameSettings s) async {
    if (s == state) return;
    final old = state;
    state = s;
    frameLimiter?.fps = s.fpsLimit.fps;
    if (s.fullscreen != old.fullscreen) {
      await window.setFullscreen(s.fullscreen);
    }
    try {
      await store.save(s);
    } catch (_) {
      // Sin disco: se usa igual en esta ejecución.
    }
  }
}
