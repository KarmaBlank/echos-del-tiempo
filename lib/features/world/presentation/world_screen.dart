import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../build_planner/presentation/build_feed.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../core/settings/game_settings.dart';
import '../../../core/settings/notices.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../game_engine/data/uniques_catalog.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/session_event.dart';
import '../../../game_engine/rules/eco_rules.dart';
import '../../../game_engine/rules/trial_rules.dart';
import '../../characters/presentation/stash_panel.dart';
import '../../../app/theme/panel_frame.dart';
import '../../ascension/domain/ascension_text.dart';
import '../../ascension/presentation/ascension_cinematic.dart';
import '../../ascension/presentation/ascension_panel.dart';
import '../../ascension/presentation/ascension_views.dart';
import '../../combat/presentation/battle_screen.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/scene/arena/arena_transition.dart';
import '../../combat/presentation/scene/battle_scene.dart';
import '../../endgame/domain/endgame_text.dart';
import '../../endgame/presentation/eco_portal_panel.dart';
import '../../inventory/domain/item_text.dart';
import '../../inventory/presentation/armory_panel.dart';
import '../../inventory/presentation/item_widgets.dart';
import '../../inventory/presentation/shop_sections.dart';
import '../../missions/domain/mission_text.dart';
import '../../missions/presentation/mission_board_panel.dart';
import '../../missions/presentation/prep_panel.dart';
import '../../missions/presentation/results_panel.dart';
import '../../settings/presentation/settings_menu.dart';
import 'hud/pause_banner.dart';
import 'hud/world_hud.dart';
import 'map/map_game.dart';
import 'panels/character_panel.dart';
import 'panels/party_member_bar.dart';
import 'panels/party_panel.dart';
import '../../../game_engine/models/tutorial.dart' show TutorialPhase;
import '../../tutorial/presentation/tutorial_widgets.dart';
import 'session_battle_screen.dart';
import 'session_controller.dart';
import 'session_music.dart';
import 'session_sfx.dart';
import 'session_view.dart';

/// Pantalla raíz del juego: dibuja lo que pide `session.mode` (mapa +
/// HUD + paneles, batalla o resultado) y reparte el teclado. Ver
/// docs/specs/exploration.md § "Flujo de pantallas".
class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key, this.moveInput});

  /// Entrada de movimiento alternativa (tests); por defecto el teclado.
  final MoveInputReader? moveInput;

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  final _focus = FocusNode(debugLabel: 'world');
  final _chatFocus = FocusNode(debugLabel: 'chat');
  final _battleKey = GlobalKey<BattleViewState>();
  MapGame? _game;

  /// Ya se pidió volver al título por una desconexión.
  bool _leaving = false;

  /// El menú de pausa está abierto (docs/specs/settings.md § "Pausa").
  bool _pauseOpen = false;

  /// Eventos de la sesión (para el aviso `X reanudó`).
  StreamSubscription<SessionEvent>? _events;

  /// Quién reanudó hace poco (aviso de unos segundos) y su temporizador.
  String? _resumedBy;
  Timer? _resumedTimer;

  /// Abre la pausa: el jugador local deja de moverse. Jugando solo (sin
  /// red) también pausa la partida de verdad; con red el mundo sigue
  /// salvo que se use PAUSAR AL GRUPO.
  void _openPause() {
    if (_pauseOpen) return;
    final c = ref.read(sessionControllerProvider.notifier);
    if (c.mounted) {
      c.menuOpen = true;
      if (c.net == null && !c.paused) c.pauseGroup(true);
    }
    setState(() => _pauseOpen = true);
  }

  void _closePause() {
    if (!_pauseOpen) return;
    final c = ref.read(sessionControllerProvider.notifier);
    if (c.mounted) {
      c.menuOpen = false;
      if (c.net == null && c.paused) c.pauseGroup(false);
    }
    setState(() => _pauseOpen = false);
    _focus.requestFocus();
  }

  /// Cinemáticas de ascensión pendientes (docs/specs/ascension.md § 5):
  /// (nombre, clase, ascensión). Se muestra la primera.
  final _cinematics = <(String, String, String)>[];
  final _cineKey = GlobalKey<AscensionCinematicState>();

  /// La elección de ascensión abierta sobre el resultado de una Prueba.
  bool _choosing = false;

  void _onSessionEvent(SessionEvent e) {
    if (e is AscensionChosenEvent && mounted) {
      final c = ref.read(sessionControllerProvider.notifier);
      final p = c.session?.players[e.playerId];
      if (p != null) {
        setState(() {
          _choosing = false;
          _cinematics.add((p.name, p.profile.classId, e.ascensionId));
        });
      }
      return;
    }
    if (e is! ResumedEvent || !mounted) return;
    final c = ref.read(sessionControllerProvider.notifier);
    if (c.net == null) return; // solo: no hace falta avisar
    _resumedTimer?.cancel();
    _resumedTimer = Timer(PauseBanner.resumedFor, () {
      if (mounted) setState(() => _resumedBy = null);
    });
    setState(() => _resumedBy = e.name);
  }

  /// SALIR AL TÍTULO: cierra la pantalla (el controlador guarda y deja
  /// la sala al descartarse).
  void _exitToTitle() {
    _closePause();
    Navigator.of(context).maybePop();
  }

  /// SALIR DEL JUEGO: guarda el perfil, deja la sala y cierra la app.
  Future<void> _quitGame() async {
    final c = ref.read(sessionControllerProvider.notifier);
    final exit = ref.read(appExitProvider);
    if (c.mounted) {
      await c.saveNow();
      await c.net?.disconnect();
    }
    await exit();
  }

  @override
  void initState() {
    super.initState();
    // Mientras se escribe, el jugador no se mueve (las teclas son texto).
    _chatFocus.addListener(() {
      final c = ref.read(sessionControllerProvider.notifier);
      if (c.mounted) c.typing = _chatFocus.hasFocus;
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _resumedTimer?.cancel();
    _chatFocus.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Fin del chat (Enter o Esc): el foco vuelve a la pantalla.
  void _chatDone() => _focus.requestFocus();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Escribiendo: ninguna tecla es del juego (ni atajos ni movimiento);
    // así llegan al campo de texto.
    if (_chatFocus.hasFocus) return KeyEventResult.ignored;
    // Escribiendo en un campo de un panel (p. ej. el filtro de loot): las
    // teclas son del campo, no atajos del mapa.
    final focusCtx = FocusManager.instance.primaryFocus?.context;
    if (focusCtx != null &&
        focusCtx.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    // Con la pausa abierta, sus teclas las maneja el menú; nada llega al
    // juego (ni atajos de batalla).
    if (_pauseOpen) return KeyEventResult.ignored;
    // Cinemática de ascensión: Esc / Enter / Espacio la saltan.
    if (_cinematics.isNotEmpty) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        _cineKey.currentState?.skip();
      }
      return KeyEventResult.handled;
    }
    // TUTORIAL: ESPACIO / Enter = SIGUIENTE, el voto para cerrar el
    // cartel (combat_tutorial.md § 4.1).
    final tc = ref.read(sessionControllerProvider.notifier);
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        tc.tutorialCard != null) {
      tc.ackTutorial();
      return KeyEventResult.handled;
    }
    if (_choosing &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _choosing = false);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        _chatFocus.context != null) {
      _chatFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) {
      // Las de movimiento se leen del estado del teclado: que no lleguen
      // a los atajos de foco.
      return SessionController.movementKeys.contains(event.logicalKey)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    final view = ref.read(sessionControllerProvider);
    final controller = ref.read(sessionControllerProvider.notifier);
    if (view == null) return KeyEventResult.ignored;
    // Esc: cierra el submenú de batalla o el panel abierto; si no hay
    // nada que cerrar, abre la pausa (docs/specs/settings.md § "Pausa").
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      final battle = _battleKey.currentState;
      final submenu = view.mode == SessionMode.battle &&
          battle != null &&
          battle.hasSubmenu;
      if (submenu) {
        battle.handleKey(event.logicalKey);
      } else if (view.mode != SessionMode.battle && view.panel != null) {
        controller.handleKey(event.logicalKey);
      } else {
        _openPause();
      }
      return KeyEventResult.handled;
    }
    // Retroceso: cierra todos los avisos del HUD (DURACIÓN DE LOS AVISOS
    // = HASTA CERRAR, accessibility.md § 9.5; con otra duración también
    // los despeja).
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      ref.read(noticeDismissProvider).dismissAll();
      _game?.dismissNotices();
      return KeyEventResult.handled;
    }
    // J: pliega / despliega la caja de objetivos (campo, sin panel).
    if (event.logicalKey == LogicalKeyboardKey.keyJ &&
        view.mode == SessionMode.field &&
        view.panel == null) {
      toggleObjectives(ref);
      return KeyEventResult.handled;
    }
    // H: despliega / compacta las cajas del grupo (fuera de batalla, sin
    // panel; v0.8.2).
    if (event.logicalKey == LogicalKeyboardKey.keyH &&
        view.mode != SessionMode.battle &&
        view.panel == null) {
      togglePartyBoxes(ref);
      return KeyEventResult.handled;
    }
    final bool used;
    if (view.mode == SessionMode.battle) {
      used = _battleKey.currentState?.handleKey(event.logicalKey) ?? false;
    } else {
      used = controller.handleKey(event.logicalKey);
    }
    return used ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  /// Se perdió la sala: cierra lo que haya encima (pausa, diálogos) y
  /// vuelve al título con el motivo. `maybePop` solo cerraba el diálogo de
  /// arriba y la pantalla quedaba trabada en DESCONECTADO.
  void _leaveLost(String reason) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    final nav = Navigator.of(context);
    nav.popUntil((r) => r == route);
    if (route.isCurrent && nav.canPop()) nav.pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(sessionControllerProvider);
    final sprites = ref.watch(gameSpritesProvider);
    final controller = ref.read(sessionControllerProvider.notifier);
    _events ??= controller.events.listen(_onSessionEvent);
    // Sonido: escucha los eventos de la sesión mientras la pantalla vive.
    ref.watch(sessionSfxProvider);
    // Avisos del plan de build: viven toda la sesión (no solo el HUD).
    ref.watch(buildFeedProvider);
    // Música: el bucle y los jingles según el estado (session_music.dart).
    ref.watch(sessionMusicProvider);

    // Recupera el foco si un cambio de pantalla lo dejó sin dueño.
    // No con un diálogo encima (p. ej. el panel de sonido).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !_focus.hasFocus &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        _focus.requestFocus();
      }
    });

    // Se perdió la sala (el host se fue): vuelve al título con el motivo.
    final lost = view?.disconnected;
    if (lost != null && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _leaveLost(lost));
    }

    final Widget body;
    if (lost != null) {
      // Respaldo: si la vuelta automática no pudo salir, un botón.
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('DESCONECTADO',
                style: TextStyle(color: RetroPalette.gold)),
            const SizedBox(height: 8),
            Text(lost, style: const TextStyle(color: RetroPalette.muted)),
            const SizedBox(height: 16),
            TextButton(
              key: const Key('lost-back'),
              autofocus: true,
              onPressed: () => _leaveLost(lost),
              child: const Text('VOLVER AL TÍTULO'),
            ),
          ],
        ),
      );
    } else if (view == null || !sprites.hasValue) {
      body = Center(
        child: Text(
          sprites.hasError ? 'ERROR AL CARGAR SPRITES' : 'CARGANDO...',
          style: const TextStyle(color: RetroPalette.gold),
        ),
      );
    } else {
      final game = _game ??= MapGame(
        controller: controller,
        sprites: sprites.requireValue,
        input: widget.moveInput,
      );
      // Ajustes gráficos del mapa (docs/specs/settings.md § 3).
      final gfx = ref.watch(gameSettingsProvider);
      game
        ..scaleMode = gfx.scale
        ..particleDensity = gfx.particles.factor
        // Texto del mapa (accessibility.md § 9.5 y 9.6).
        ..noticeFactor = gfx.noticeDuration.factor
        ..labelBackdrop = gfx.mapLabelBackdrop;
      body = Stack(
        children: [
          // El GameWidget se queda con todas las teclas si tiene el foco:
          // el teclado lo maneja esta pantalla (ver `_onKey`).
          Positioned.fill(
            child: ExcludeFocus(
              child: GameWidget(game: game, autofocus: false),
            ),
          ),
          ..._overlays(view, controller, sprites.requireValue),
          // Vuelta de la arena al mapa: fundido de bloques
          // (docs/specs/battle_presentation.md § "Arenas" → "Transición").
          Positioned.fill(
            child: BattleExitWipe(
                inBattle: view.mode == SessionMode.battle,
                fade: ref
                    .watch(gameSettingsProvider.select((s) => s.reduceMotion))),
          ),
          // Elegir ascensión desde el resultado de la Prueba I.
          if (_choosing && view.me != null)
            Positioned.fill(
              child: ColoredBox(
                color: ProtoColors.scrim(0.8),
                child: PanelFrame(
                  title: 'ELEGÍ TU ASCENSIÓN',
                  width: 1040,
                  fill: true,
                  onClose: () => setState(() => _choosing = false),
                  actions: [
                    PanelButton('MÁS TARDE [ESC]',
                        onPressed: () => setState(() => _choosing = false)),
                  ],
                  child: AscensionChoiceView(
                    classId: view.me!.profile.classId,
                    sprites: sprites.requireValue,
                    onChoose: controller.chooseAscension,
                  ),
                ),
              ),
            ),
          if (_cinematics.isNotEmpty)
            Positioned.fill(
              child: AscensionCinematic(
                key: _cineKey,
                playerName: _cinematics.first.$1,
                classId: _cinematics.first.$2,
                ascensionId: _cinematics.first.$3,
                sprites: sprites.requireValue,
                // DESTELLOS y REDUCIR MOVIMIENTO (accessibility.md § 4).
                flash: ref
                    .watch(gameSettingsProvider.select((s) => s.flashFactor)),
                reduceMotion: ref
                    .watch(gameSettingsProvider.select((s) => s.reduceMotion)),
                onDone: () {
                  if (mounted) setState(() => _cinematics.removeAt(0));
                },
              ),
            ),
          // El progreso no llegó a disco (se reintenta solo): aviso en
          // rojo, nunca en silencio (docs/specs/characters.md § 1.4).
          if (view.saveError case final err?)
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    key: const ValueKey('world-save-error'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: ProtoColors.scrim(0.8),
                    child: Text(
                      '$err (ver ecos.log)',
                      style: TextStyle(
                          fontFamily: RetroType.titleFamily,
                          fontSize: RetroType.label,
                          color: RetroPalette.red),
                    ),
                  ),
                ),
              ),
            ),
          // Pausa de grupo: cartel para todos (o `X reanudó` un momento).
          if (!_pauseOpen && (view.session.paused || _resumedBy != null))
            Positioned.fill(
              child: PauseBanner(
                pausedBy:
                    view.session.paused ? view.session.pausedName ?? '?' : null,
                resumedBy: _resumedBy,
                onResume: () => controller.pauseGroup(false),
              ),
            ),
          if (_pauseOpen) ...[
            // Tapa (y bloquea los clics a) lo de abajo; el mundo sigue
            // dibujándose.
            Positioned.fill(
              child: ColoredBox(color: ProtoColors.scrim(0.6)),
            ),
            Positioned.fill(
              child: SettingsMenu(
                inGame: true,
                multiplayer: controller.net != null,
                groupPaused: view.session.paused,
                onGroupPause: controller.net == null
                    ? null
                    : (on) => controller.pauseGroup(on),
                inMission: view.session.mission != null,
                onClose: _closePause,
                onExitToTitle: _exitToTitle,
                onQuitGame: _quitGame,
              ),
            ),
          ],
        ],
      );
    }
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(body: body),
    );
  }

  List<Widget> _overlays(
      SessionView view, SessionController controller, GameSprites sprites) {
    final s = view.session;
    switch (s.mode) {
      case SessionMode.battle:
        // TUTORIAL (combat_tutorial.md § 4): cartel del paso, botones del
        // paso y cartel de efecto.
        final tut = s.tutorial;
        final tb = s.battle?.state;
        final rules = controller.tutorialRules;
        final humans = s.playerList.where((p) => !p.isCompanion).toList();
        final battle = SessionBattleScreen(
          view: view,
          sprites: sprites,
          battleKey: _battleKey,
          onCommand: controller.battleCommand,
          onAuto: controller.setAuto,
          sceneOptions: _sceneOptions(ref.watch(gameSettingsProvider)),
          actionGate: tut == null || tb == null
              ? null
              : (id) => rules.gate(tut, tb, tb.currentId ?? view.localId, id),
        );
        return [
          Positioned.fill(
            child: tut == null
                ? battle
                : TutorialOverlay(
                    key: const ValueKey('tutorial-overlay'),
                    battle: battle,
                    banner: rules.banner(s, controller.members.toSet()),
                    card: controller.tutorialCard,
                    last: tut.last,
                    waitingText: rules.waitingText(s),
                    voted: controller.tutorialVoted,
                    hud: tutorialHudParts(rules.hudFocus(tut)),
                    rules: rules,
                    canControl: humans.length <= 1 ||
                        humans.first.id == view.localId,
                    onNext: () => controller.ackTutorial(),
                    onControl: (op) => controller.tutorialControl(op),
                    options: rules.options(tut),
                    pickLines: rules.pickLines(s),
                    myPick: tut.picks[view.localId],
                    onPick: (c) => controller.tutorialPick(c),
                    narration: tut.phase == TutorialPhase.train ||
                            tut.phase == TutorialPhase.trainOver
                        ? tut.narration
                        : const [],
                  ),
          ),          // `≡ MENÚ`: la pausa también se abre con el mouse en batalla.
          // Abajo a la izquierda de la escena, justo encima de la barra
          // (arriba está la franja de turnos).
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Positioned(
                    left: 8,
                    bottom: BattleViewState.barHeight(
                            box.maxHeight,
                            RetroType.factorOf(context),
                            s.battle?.state.party.length ?? 1) +
                        8,
                    child: PauseMenuButton(onPressed: _openPause),
                  ),
                ],
              ),
            ),
          ),
        ];
      case SessionMode.result:
        final r = s.result;
        if (r == null) return const [];
        final weapons = controller.engine.catalog.weapons;
        return [
          Positioned.fill(
            child: ColoredBox(color: ProtoColors.scrim(0.8)),
          ),
          Positioned.fill(
            child: ResultsPanel(
              result: r,
              localId: view.localId,
              playerName: (id) => s.players[id]?.name ?? '?',
              weaponName: (id) => weapons[id]?.name ?? id,
              onBack: controller.backToLobby,
              zoneProgress: _zoneProgress(s, r, controller),
              unlocked: switch (r.unlocked[view.localId]) {
                final z? =>
                  zoneUnlockedText(z, controller.engine.catalog.zone(z)?.name),
                null => null,
              },
              othersUnlocked: _othersUnlocked(s, r, view.localId),
              finalVictory: ResultsPanel.isFinalVictory(r),
              ecoAtlas: r.missionId == EcoRules.missionId && r.success
                  ? ecoAtlasText(view.atlasGain)
                  : null,
              abyss: switch (controller.lastAbyss) {
                (final n, final points) when r.success =>
                  abyssResultText(
                      controller.engine.catalog.abyssBosses[n]?.name ?? '?',
                      points),
                _ => null,
              },
              trial: switch (controller.lastTrial) {
                (final n, final gained) when r.success =>
                  trialResultText(n, gained),
                _ => null,
              },
              onAscend: r.success &&
                      (view.me?.profile.ascension.trials.contains(1) ??
                          false) &&
                      view.me?.profile.ascension.id == null
                  ? () => setState(() => _choosing = true)
                  : null,
              loot: [
                for (final d in view.missionLoot)
                  if (view.me case final me?)
                    ResultDrop(
                      dropLabelText(controller.engine.progression, d),
                      controller.engine.lootVerdict(me.profile, d,
                          wants: controller.localWants),
                      exclusive:
                          kUniques[d.item?.uniqueId]?.exclusive ?? false,
                      tooltip: d.eco != null
                          ? ecoTooltipMarkup(
                              controller.engine.progression, d.eco!)
                          : d.item == null
                              ? stackTooltipMarkup(d.stack!, d.count)
                              : itemTooltipMarkup(
                                  controller.engine.progression, d.item!,
                                  level: me.profile.level,
                                  attributes: me.profile.attributes),
                    ),
              ],
            ),
          ),
        ];
      default:
        return [
          Positioned.fill(
            child: WorldHud(
              view: view,
              controller: controller,
              onExit: () => Navigator.of(context).maybePop(),
              onMenu: _openPause,
              chatFocus: _chatFocus,
              onChatDone: _chatDone,
            ),
          ),
          if (view.panel case final panel?)
            Positioned.fill(child: _panel(panel, view, controller)),
        ];
    }
  }

  /// Lo que la escena de batalla toma de los ajustes del jugador.
  static SceneOptions _sceneOptions(GameSettings s) => SceneOptions(
        // REDUCIR MOVIMIENTO apaga la sacudida y deja los destellos a lo
        // sumo SUAVES (accessibility.md § 4).
        shake: s.shakeOn,
        flash: s.flashFactor,
        reduceMotion: s.reduceMotion,
        damageNumbers: s.damageNumbers,
        pixelPerfect: s.scale == ScaleMode.pixelPerfect,
        particles: s.particles.factor,
        extendedLog: s.battleLog == BattleLogMode.extended,
      );

  /// `Zona 2 · Bosque Hondo · Piso 3/3` del resultado de una misión de
  /// zona (piso alcanzado; todos en una victoria).
  static String? _zoneProgress(
      GameSession s, MissionResult r, SessionController controller) {
    final z = controller.engine.catalog.zone(r.zone);
    if (z == null) return null;
    final floors = s.mission?.floors ?? z.floors;
    final reached = r.success ? floors : (s.mission?.floor ?? 0) + 1;
    final eco = s.eco;
    if (r.missionId == TrialRules.missionId) {
      return '${z.name} · Piso $reached/$floors';
    }
    if (r.missionId == EcoRules.missionId && eco != null) {
      return 'Eco T${eco.tier} · ${z.name} · '
          '${controller.engine.ecoRules.bossName(eco)} · Piso $reached/$floors';
    }
    return 'Zona ${z.index} · ${z.name} · Piso $reached/$floors';
  }

  /// Los demás jugadores que desbloquearon una zona (`Bo: Zona 3`).
  static String? _othersUnlocked(
      GameSession s, MissionResult r, String localId) {
    final others = [
      for (final e in r.unlocked.entries)
        if (e.key != localId)
          '${s.players[e.key]?.name ?? e.key}: Zona ${e.value}',
    ];
    return others.isEmpty
        ? null
        : 'También desbloquearon · ${others.join(' · ')}';
  }

  Widget _panel(
      WorldPanel panel, SessionView view, SessionController controller) {
    final s = view.session;
    final me = view.me!;
    final catalog = controller.engine.catalog;
    final rules = controller.engine.progression;
    switch (panel) {
      case WorldPanel.missionBoard:
        return MissionBoardPanel(
          missions: catalog.missions,
          voteOpen: s.vote != null,
          bossName: (m) => missionBossName(catalog, m),
          playerLevel: me.profile.level,
          zones: controller.zones,
          // TUTORIAL: Ecos de práctica (combat_tutorial.md § 1-2).
          lockText: controller.tutorialRules.lockText(s),
          tutorialDone:
              controller.tutorialRules.upToDate(me.tutorialVersion),
          tutorial: TutorialSealDetail(
            rules: controller.tutorialRules,
            done: controller.tutorialRules.upToDate(me.tutorialVersion),
            humans: s.playerList.where((p) => !p.isCompanion).length,
            companions: s.playerList.where((p) => p.isCompanion).length,
            isHost: s.playerList.firstOrNull?.id == view.localId,
            lockText: controller.tutorialRules.lockText(s),
            onStart: (companions) {
              if (controller.startTutorial(companions: companions)) {
                controller.closePanel();
              }
            },
          ),
          // Proponer cierra el mostrador (línea 1363).
          onPropose: (id) {
            if (controller.proposeMission(id)) controller.closePanel();
          },
          onClose: controller.closePanel,
          onCharacter: () => controller.openPanel(WorldPanel.character),
        );
      case WorldPanel.armory:
        return ArmoryPanel(view: view, controller: controller);
      case WorldPanel.party:
        return PartyPanel(view: view, controller: controller);
      case WorldPanel.stash:
        return StashPanel(view: view, controller: controller);
      case WorldPanel.map:
        return fullMapPanel(view, controller);
      case WorldPanel.ecoPortal:
        return EcoPortalPanel(
            view: view,
            controller: controller,
            sprites: ref.read(gameSpritesProvider).valueOrNull);
      case WorldPanel.ascension:
        return AscensionPanel(
            view: view,
            controller: controller,
            sprites: ref.read(gameSpritesProvider).valueOrNull);
      case WorldPanel.character:
        return CharacterPanel(
            key: const ValueKey('panel-character'),
            view: view,
            controller: controller);
      case WorldPanel.inventory:
        return CharacterPanel(
            key: const ValueKey('panel-inventory'),
            view: view,
            controller: controller,
            initialTab: CharacterTab.inventory);
      case WorldPanel.prep:
        final prep = s.prep;
        final mission = prep == null
            ? null
            : controller.engine.missionOf(s, prep.missionId);
        if (prep == null || mission == null) return const SizedBox.shrink();
        // Créditos, consumibles y arma: del miembro activo (las pestañas de
        // tienda actúan sobre él; solo_party.md § 6.2).
        final actor = view.actor ?? me;
        return PartyMemberKeys(
            view: view,
            controller: controller,
            child: PrepPanel(
              members: PartyMemberBar.shows(view)
                  ? PartyMemberBar(view: view, controller: controller)
                  : null,
              mission: mission,
              players: [
                for (final p in s.playerList)
                  PrepEntry(
                    profileTitle(p.profile),
                    catalog.classes[p.profile.classId]?.name ??
                        p.profile.classId,
                    p.profile.level,
                    // Los compañeros siguen al líder (solo_party.md § 3.3).
                    ready: p.isCompanion || (prep.ready[p.id] ?? false),
                    isLocal: p.id == view.localId,
                  ),
              ],
              ready: prep.ready[view.localId] ?? false,
              credits: actor.profile.credits,
              potions: actor.profile.potions,
              ethers: actor.profile.ethers,
              tier: s.eco?.tier ?? missionTier(catalog, mission),
              bossName: missionBossName(catalog, mission),
              weaponName: actor.profile.equippedUid == null
                  ? '-'
                  : rules.weaponDisplayName(
                      actor.profile, actor.profile.equippedUid!),
              onReady: controller.setReady,
              onCancel: controller.cancelPrep,
              onCharacter: () => controller.openPanel(WorldPanel.character),
              turnTimer: s.turnTimer,
              // Las pestañas de la armería (en `prep` la del lobby no se abre).
              shopTabs: [
                for (final t in ArmoryTab.values)
                  t.spec(() => ShopContext(view, controller)),
              ],
            ));
    }
  }
}
