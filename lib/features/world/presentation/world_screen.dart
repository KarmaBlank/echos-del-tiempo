import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../build_planner/presentation/build_feed.dart';
import '../../../app/design/design.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../core/settings/game_settings.dart';
import '../../../core/settings/notices.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../game_engine/data/uniques_catalog.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/session_action.dart' show GatherOp;
import '../../../game_engine/models/session_event.dart';
import '../../../game_engine/rules/eco_rules.dart';
import '../../../game_engine/rules/helper_rules.dart';
import '../../../game_engine/rules/trial_rules.dart';
import '../../../game_engine/rules/zone_rules.dart';
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
import '../../endgame/presentation/eco_zone_portal_panel.dart';
import '../../inventory/domain/item_text.dart';
import '../../inventory/presentation/armory_panel.dart';
import '../../inventory/presentation/workshop_panel.dart';
import '../../inventory/presentation/item_widgets.dart';
import '../../inventory/presentation/shop_sections.dart';
import '../../missions/domain/mission_text.dart';
import '../../missions/presentation/mission_board_panel.dart';
import '../../missions/presentation/prep_panel.dart';
import '../../missions/presentation/results_panel.dart';
import '../../settings/presentation/settings_menu.dart';
import 'hud/departure_cinematic.dart';
import 'hud/pause_banner.dart';
import 'hud/world_hud.dart';
import 'map/map_game.dart';
import 'panels/trader_panel.dart';
import 'panels/fountain_panel.dart';
import 'panels/biome_npc_panel.dart';
import 'panels/biome_fisher_panel.dart';
import 'panels/custom_npc_panel.dart';
import 'panels/world_event_panel.dart';
import 'panels/quest_log_panel.dart';
import 'panels/travel_panel.dart';
import 'panels/helper_panel.dart';
import 'panels/offering_panel.dart';
import 'panels/town_edit_overlay.dart';
import 'panels/town_strip_cards.dart';
import 'panels/character_panel.dart';
import 'panels/party_member_bar.dart';
import 'panels/lost_loot_panel.dart';
import 'panels/party_panel.dart';
import '../../../game_engine/models/tutorial.dart' show TutorialPhase;
import '../../tutorial/presentation/tutorial_widgets.dart';
import 'session_battle_screen.dart';
import '../../achievements/presentation/achievement_feed.dart';
import 'session_controller.dart';
import 'session_music.dart';
import 'session_sfx.dart';
import 'session_view.dart';
import '../../run/presentation/run_character_panel.dart';
import '../../run/presentation/run_screen.dart';
import 'hud/map_hover_tip.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../domain/player_locations.dart';

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
  /// Parcela bajo el mouse (tile, posición en pantalla).
  ((int, int), Offset)? _hover;

  /// Edición del pueblo: dónde arrancó el clic y si ya es un arrastre.
  Offset? _editDown;
  bool _editDragged = false;
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
    // Pesca en el mapa: soltar E / Espacio tira el lance o baja la zona
    // (fishing.md § 4).
    if (event is KeyUpEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyE ||
            event.logicalKey == LogicalKeyboardKey.space) &&
        tc.isFishing) {
      tc.fishRelease();
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
      } else if (view.mode != SessionMode.battle &&
          (view.panel != null ||
              controller.isFishing ||
              controller.editingTown)) {
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
    // O: pliega / despliega la caja de objetivos (campo, sin panel; J
    // abre el DIARIO).
    if (event.logicalKey == LogicalKeyboardKey.keyO &&
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
    // A language change rebuilds the HUD and panels (world_strings.dart).
    ref.watch(stringsProvider);
    final view = ref.watch(sessionControllerProvider);
    final sprites = ref.watch(gameSpritesProvider);
    final controller = ref.read(sessionControllerProvider.notifier);
    _events ??= controller.events.listen(_onSessionEvent);
    // Sonido: escucha los eventos de la sesión mientras la pantalla vive.
    ref.watch(sessionSfxProvider);
    // Avisos del plan de build: viven toda la sesión (no solo el HUD).
    ref.watch(buildFeedProvider);
    // Toasts de hazañas (achievements.md § 7): ídem, también en batalla.
    final achFeed = ref.watch(achievementFeedProvider);
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
            Text(ref.t('ui.world.screen.disconnected'),
                style: const TextStyle(color: RetroPalette.gold)),
            const SizedBox(height: 8),
            Text(lost, style: const TextStyle(color: RetroPalette.muted)),
            const SizedBox(height: 16),
            TextButton(
              key: const Key('lost-back'),
              autofocus: true,
              onPressed: () => _leaveLost(lost),
              child: Text(ref.t('ui.world.screen.back_to_title')),
            ),
          ],
        ),
      );
    } else if (view == null || !sprites.hasValue) {
      body = Center(
        child: Text(
          sprites.hasError
              ? ref.t('ui.world.screen.sprites_error')
              : ref.t('ui.world.screen.loading'),
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
        // Destellos del rayo y lluvia (accessibility.md; day_night_weather.md § 4).
        ..flashFactor = gfx.flashFactor
        ..reduceMotion = gfx.reduceMotion
        // Oscuridad (lighting.md § 7).
        ..darknessKeep = gfx.darkness.keep
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
          // Edición del pueblo (town_editor.md § 1): arrastrar mueve la
          // cámara, la rueda hace zoom y un clic sin arrastre elige.
          if (controller.editingTown)
            Positioned.fill(
              key: const ValueKey('town-edit-pointer'),
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  _editDown = e.localPosition;
                  _editDragged = false;
                },
                onPointerMove: (e) {
                  final d = _editDown;
                  if (d == null) return;
                  if ((e.localPosition - d).distance > 4) _editDragged = true;
                  if (_editDragged) game.panBy(e.delta);
                },
                onPointerUp: (e) {
                  final dragged = _editDragged;
                  _editDown = null;
                  _editDragged = false;
                  if (dragged) return;
                  final t = game.tileAtScreen(e.localPosition);
                  if (t != null) controller.editClick(t.$1, t.$2);
                },
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) {
                    game.zoomBy(e.scrollDelta.dy > 0 ? 1 : -1);
                  }
                },
              ),
            ),
          // Carteles: el mouse sobre el cartel de un lago o una huerta
          // muestra qué hay (town_editor.md § 6); sobre parcelas o agua,
          // nada.
          if (view.mode == SessionMode.lobby && view.panel == null)
            Positioned.fill(
              key: const ValueKey('farm-hover'),
              // Clic sobre un ayudante: abre su pantalla (como [G]).
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  if (e.buttons != kPrimaryMouseButton) return;
                  final tile = game.tileAtScreen(e.localPosition);
                  if (tile == null) return;
                  if (controller.helperAt(tile.$1, tile.$2) case final h?) {
                    controller.openHelper(h.build.id, h.index);
                  } else if (controller.residentAt(tile.$1, tile.$2)
                      case final n?) {
                    // Clic sobre un habitante: abre su pantalla (como E).
                    controller.openResident(n);
                  } else if (controller.fisherAt(tile.$1, tile.$2)) {
                    controller.openPanel(WorldPanel.biomeFisher);
                  } else if (controller.customNpcAt(tile.$1, tile.$2)
                      case final n?) {
                    controller.openCustomNpc(n.def.id);
                  }
                },
                child: MouseRegion(
                  opaque: false,
                  hitTestBehavior: HitTestBehavior.translucent,
                  onExit: (_) => setState(() => _hover = null),
                  onHover: (e) {
                    final tile = game.tileAtScreen(e.localPosition);
                    if (tile != null) controller.editHover(tile.$1, tile.$2);
                    final helper = tile == null
                        ? null
                        : controller.helperAt(tile.$1, tile.$2);
                    controller.hoverHelper = helper;
                    final next = tile != null &&
                            (helper != null ||
                                controller.chestAt(tile.$1, tile.$2) != null ||
                                controller.signAt(tile.$1, tile.$2) != null)
                        ? (tile, e.localPosition)
                        : null;
                    if (next?.$1 != _hover?.$1) setState(() => _hover = next);
                  },
                ),
              ),
            ),
          if (controller.editingTown)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) => TownStripCards(
                  game: game,
                  controller: controller,
                  top: TownEditOverlay.barHeight,
                  right: TownEditOverlay.sideOpen(controller)
                      ? TownEditOverlay.sideWidth(box.maxWidth) + 16
                      : 0,
                ),
              ),
            ),
          if (controller.editingTown)
            Positioned.fill(child: TownEditOverlay(controller: controller)),
          // Pesca en el mapa: clic mantenido = E mantenida (sin ventana).
          if (controller.isFishing)
            Positioned.fill(
              key: const ValueKey('fish-pointer'),
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => controller.fishPress(),
                onPointerUp: (_) => controller.fishRelease(),
              ),
            )
          // Con una herramienta en la mano: clic = E (sacar la caña, arar,
          // plantar, regar, cosechar); la rueda cambia de herramienta.
          else if (view.panel == null && controller.activeTool != null)
            Positioned.fill(
              key: const ValueKey('tool-pointer'),
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  if (e.buttons != kPrimaryMouseButton) return;
                  // El clic sobre un ayudante abre su pantalla, no trabaja.
                  if (controller.hoverHelper != null) return;
                  final tile = game.tileAtScreen(e.localPosition);
                  if (tile != null &&
                      (controller.residentAt(tile.$1, tile.$2) != null ||
                          controller.fisherAt(tile.$1, tile.$2) ||
                          controller.customNpcAt(tile.$1, tile.$2) != null)) {
                    return;
                  }
                  if (controller.activeTool == ActiveTool.rod) {
                    controller.startFishing();
                  } else {
                    controller.farmWork();
                  }
                },
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent &&
                      controller.activeTool == ActiveTool.hoe) {
                    controller.cycleFarmHand(e.scrollDelta.dy < 0 ? -1 : 1);
                  }
                },
              ),
            ),
          ..._overlays(view, controller, sprites.requireValue),
          // Tooltips del mapa (ayudantes, carteles): siempre al frente,
          // encima del HUD y de sus avisos.
          if (_hover case final h?
              when view.mode == SessionMode.lobby &&
                  view.panel == null &&
                  controller.hoverHelper != null)
            Positioned.fill(
              key: const ValueKey('helper-tooltip'),
              child: MapHoverTip(
                cursor: h.$2,
                child: IgnorePointer(
                  child: switch (controller.hoverHelper) {
                    (:final build, :final index)? => () {
                        final (title, lines) =
                            controller.helperInfo(build, index);
                        return DsTooltipCard(
                          title: title,
                          children: [
                            for (final l in lines)
                              Text(l, style: DsText.detail())
                          ],
                        );
                      }(),
                    null => const SizedBox.shrink(),
                  },
                ),
              ),
            )
          else if (_hover case final h?
              when view.mode == SessionMode.lobby &&
                  view.panel == null &&
                  !controller.editingTown)
            Positioned.fill(
              key: const ValueKey('farm-tooltip'),
              child: MapHoverTip(
                cursor: h.$2,
                child: IgnorePointer(
                  child: switch ((
                    controller.chestAt(h.$1.$1, h.$1.$2),
                    controller.signAt(h.$1.$1, h.$1.$2)
                  )) {
                    (final chest?, _) => DsTooltipCard(
                        key: const ValueKey('chest-tooltip'),
                        title: HelperRules.chestText(chest),
                        children: const [],
                      ),
                    (_, (final title, final text)?) => DsTooltipCard(
                        key: const ValueKey('sign-tooltip'),
                        title: title,
                        children: [Text(text, style: DsText.detail())],
                      ),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ),
          // Hazaña lograda: arriba a la derecha, sobre el mapa y la batalla.
          Positioned(
            top: 56,
            right: 12,
            child: AchievementToasts(feed: achFeed),
          ),
          // Vuelta de la arena al mapa: fundido de bloques
          // (docs/specs/battle_presentation.md § "Arenas" → "Transición").
          Positioned.fill(
            child: BattleExitWipe(
                inBattle: view.mode == SessionMode.battle,
                fade: ref
                    .watch(gameSettingsProvider.select((s) => s.reduceMotion))),
          ),
          // Partida del pueblo a la zona (town_loop.md § 2, v0.21.0).
          // Con clave: los overlays de antes cambian de cantidad entre la
          // preparación y el campo, y sin ella se perdería el estado.
          Positioned.fill(
            key: const ValueKey('departure-layer'),
            child: DepartureCinematic(
              mode: view.mode,
              enabled: !controller.isRun,
              destination: switch (view.session.mission?.missionId) {
                final id? => controller.engine.catalog.mission(id)?.name,
                null => null,
              },
              reduceMotion:
                  ref.watch(gameSettingsProvider.select((s) => s.reduceMotion)),
            ),
          ),
          // Elegir ascensión desde el resultado de la Prueba I.
          if (_choosing && view.me != null)
            Positioned.fill(
              child: ColoredBox(
                color: ProtoColors.scrim(0.8),
                child: PanelFrame(
                  title: ref.t('ui.world.screen.choose_ascension'),
                  width: 1040,
                  fill: true,
                  onClose: () => setState(() => _choosing = false),
                  actions: [
                    PanelButton(ref.t('ui.world.screen.later'),
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
                      ref.t('ui.world.screen.save_error', {'error': err}),
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
          onCancelQueued: controller.cancelQueued,
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
                    canControl:
                        humans.length <= 1 || humans.first.id == view.localId,
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
          ), // `≡ MENÚ`: la pausa también se abre con el mouse en batalla.
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
                            s.battle?.state.party.length ?? 1,
                            // Grupo compacto: sin compañeros propios.
                            !s.playerList.any((p) => p.isCompanion)) +
                        8,
                    child: PauseMenuButton(onPressed: _openPause),
                  ),
                ],
              ),
            ),
          ),
        ];
      case SessionMode.result:
        return _resultOverlay(view, controller);
      // Travesía (roguelike.md): sus pantallas en vez del pueblo / campo.
      case SessionMode.lobby || SessionMode.run when controller.isRun:
        return [
          Positioned.fill(
            child: RunScreen(
              view: view,
              controller: controller,
              onExit: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (view.panel case final panel?)
            Positioned.fill(child: _panel(panel, view, controller)),
        ];
      default:
        return [
          // Edición del pueblo: solo su barra y su panel (town_editor.md
          // § 1); el HUD normal se oculta para que nada se pise.
          if (!controller.editingTown)
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
          if (s.victoryLap) ...[
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(child: _leaveReadyBar(view, controller)),
            ),
            if (!controller.resultClosed) ..._resultOverlay(view, controller),
          ],
        ];
    }
  }

  /// LISTO para volver tras la victoria, con `LISTO (2/3)`.
  Widget _leaveReadyBar(SessionView view, SessionController controller) {
    final s = view.session;
    final humans = s.playerList.where((p) => !p.isCompanion).toList();
    final n = humans.where((p) => s.leaveReady.contains(p.id)).length;
    final mine = s.leaveReady.contains(view.localId);
    return DsButton(
      mine
          ? ref.t(
              'ui.world.screen.ready_cancel', {'n': n, 'total': humans.length})
          : ref.t('ui.world.screen.ready', {'n': n, 'total': humans.length}),
      key: const ValueKey('leave-ready'),
      kind: mine ? DsButtonKind.secondary : DsButtonKind.primary,
      selected: mine,
      tooltip: ref.t('ui.world.screen.ready_tip'),
      onPressed: () => controller.setLeaveReady(!mine),
    );
  }

  /// Ventana de resultado: derrota (modo `result`) o victoria (campo
  /// con `result`, se cierra localmente; missions.md § "Fin de misión").
  List<Widget> _resultOverlay(SessionView view, SessionController controller) {
    final s = view.session;
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
          onBack: controller.closeResult,
          victoryLap: s.victoryLap,
          zoneProgress: _zoneProgress(ref.strings, s, r, controller),
          unlocked: switch (r.unlocked[view.localId]) {
            final z? => zoneUnlockedText(
                ref.strings,
                z,
                switch (controller.engine.catalog.zone(z)) {
                  final zd? => zoneNameText(ref.strings, zd),
                  null => null
                }),
            null => null,
          },
          othersUnlocked: _othersUnlocked(ref.strings, s, r, view.localId),
          finalVictory: ResultsPanel.isFinalVictory(r),
          ecoAtlas: r.missionId == EcoRules.missionId && r.success
              ? ecoAtlasText(view.atlasGain)
              : null,
          abyss: switch (controller.lastAbyss) {
            (final n, final points) when r.success => abyssResultText(
                controller.engine.catalog.abyssBosses[n]?.name ?? '?', points),
            _ => null,
          },
          trial: switch (controller.lastTrial) {
            (final n, final gained) when r.success =>
              trialResultText(n, gained),
            _ => null,
          },
          onAscend: r.success &&
                  (view.me?.profile.ascension.trials.contains(1) ?? false) &&
                  view.me?.profile.ascension.id == null
              ? () => setState(() => _choosing = true)
              : null,
          loot: [
            for (final d in view.missionLoot)
              if (view.me case final me?)
                ResultDrop(
                  dropLabelText(controller.engine.progression, d),
                  controller.engine
                      .lootVerdict(me.profile, d, wants: controller.localWants),
                  exclusive: kUniques[d.item?.uniqueId]?.exclusive ?? false,
                  tooltip: d.eco != null
                      ? ecoTooltipMarkup(controller.engine.progression, d.eco!)
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
  static String? _zoneProgress(Strings str, GameSession s, MissionResult r,
      SessionController controller) {
    final z = controller.engine.catalog.zone(r.zone);
    if (z == null) return null;
    final floors = s.mission?.floors ?? ZoneRules.missionFloors(z);
    final reached = r.success ? floors : (s.mission?.floor ?? 0) + 1;
    final eco = s.eco;
    if (r.missionId == TrialRules.missionId) {
      return str.t('ui.world.screen.trial_progress',
          {'zone': z.name, 'n': reached, 'floors': floors});
    }
    if (r.missionId == EcoRules.missionId && eco != null) {
      return str.t('ui.world.screen.eco_progress', {
        'tier': eco.tier,
        'zone': z.name,
        'boss': controller.engine.ecoRules.bossName(eco),
        'n': reached,
        'floors': floors
      });
    }
    return str.t('ui.world.screen.zone_progress',
        {'index': z.index, 'zone': z.name, 'n': reached, 'floors': floors});
  }

  /// Los demás jugadores que desbloquearon una zona (`Bo: Zona 3`).
  static String? _othersUnlocked(
      Strings str, GameSession s, MissionResult r, String localId) {
    final others = [
      for (final e in r.unlocked.entries)
        if (e.key != localId)
          str.t('ui.world.screen.unlocked_zone',
              {'name': s.players[e.key]?.name ?? e.key, 'n': e.value}),
    ];
    return others.isEmpty
        ? null
        : str
            .t('ui.world.screen.others_unlocked', {'list': others.join(' · ')});
  }

  Widget _panel(
          WorldPanel panel, SessionView view, SessionController controller) =>
      withCharacterTab(
          panel, view, controller, _panelBody(panel, view, controller));

  Widget _panelBody(
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
          // Someone else's gathering not joined yet (§ 2.1).
          gather: (s.gather?.has(view.localId) ?? true) ? null : s.gather,
          onJoin: () {
            if (controller.gather(GatherOp.join)) controller.closePanel();
          },
          bossName: (m) => missionBossName(ref.strings, catalog, m),
          playerLevel: me.profile.level,
          zones: controller.zones,
          // TUTORIAL: Ecos de práctica (combat_tutorial.md § 1-2).
          lockText: controller.tutorialRules.lockText(s),
          tutorialDone: controller.tutorialRules.upToDate(me.tutorialVersion),
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
          // Dónde están los demás (free_movement.md § 4.1).
          playersAt: {
            for (final e in playersByPlace(s, view.localId).entries)
              if (e.key.startsWith('m:')) e.key.substring(2): e.value,
          },
        );
      case WorldPanel.armory:
        return ArmoryPanel(view: view, controller: controller);
      case WorldPanel.forge:
        return ForgePanel(view: view, controller: controller);
      case WorldPanel.workshop:
        return WorkshopPanel(view: view, controller: controller);
      case WorldPanel.party:
        return PartyPanel(view: view, controller: controller);
      case WorldPanel.lostLoot:
        return LostLootPanel(view: view, controller: controller);
      case WorldPanel.trader:
        return TraderPanel(view: view, controller: controller);
      case WorldPanel.fountain:
        return FountainPanel(view: view, controller: controller);
      case WorldPanel.travel:
        return TravelPanel(view: view, controller: controller);
      case WorldPanel.biomeNpc:
        return BiomeNpcPanel(view: view, controller: controller);
      case WorldPanel.biomeFisher:
        return BiomeFisherPanel(view: view, controller: controller);
      case WorldPanel.customNpc:
        return CustomNpcPanel(view: view, controller: controller);
      case WorldPanel.worldEvent:
        return WorldEventPanel(view: view, controller: controller);
      case WorldPanel.questLog:
        return QuestLogPanel(view: view, controller: controller);
      case WorldPanel.helper:
        return HelperPanel(view: view, controller: controller);
      case WorldPanel.offering:
        return OfferingPanel(view: view, controller: controller);
      case WorldPanel.stash:
        return StashPanel(view: view, controller: controller);
      case WorldPanel.map:
        return fullMapPanel(view, controller,
            strings: ref.strings,
            reduceMotion:
                ref.watch(gameSettingsProvider.select((g) => g.reduceMotion)));
      case WorldPanel.ecoPortal:
        return EcoPortalPanel(
            view: view,
            controller: controller,
            sprites: ref.read(gameSpritesProvider).valueOrNull);
      case WorldPanel.ecoZone:
        return EcoZonePortalPanel(view: view, controller: controller);
      case WorldPanel.ascension:
        return AscensionPanel(
            view: view,
            controller: controller,
            sprites: ref.read(gameSpritesProvider).valueOrNull);
      // Travesía: el personaje de la run (roguelike.md § 12), sin árbol
      // ni pestañas del Mundo.
      case WorldPanel.character when controller.isRun:
        return RunCharacterPanel(
            key: const ValueKey('panel-run-character'),
            view: view,
            controller: controller);
      case WorldPanel.inventory when controller.isRun:
        return RunCharacterPanel(
            key: const ValueKey('panel-run-inventory'),
            view: view,
            controller: controller,
            initialTab: RunCharacterTab.inventory);
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
              bossName: missionBossName(ref.strings, catalog, mission),
              weaponName: actor.profile.equippedUid == null
                  ? '-'
                  : rules.weaponDisplayName(
                      actor.profile, actor.profile.equippedUid!),
              onReady: controller.setReady,
              onCancel: controller.cancelPrep,
              onCharacter: () => controller.openPanel(WorldPanel.character),
              turnTimer: s.turnTimer,
              combatMode: s.effectiveCombatMode,
              onCombatMode: controller.isClient
                  ? null
                  : (m) {
                      final g = ref.read(gameSettingsProvider.notifier);
                      g.update(ref
                          .read(gameSettingsProvider)
                          .copyWith(combatMode: m.name));
                    },
              // Las pestañas de la armería (en `prep` la del lobby no se abre).
              shopTabs: [
                for (final t in ArmoryTab.values)
                  t.spec(() => ShopContext(view, controller), ref.strings),
                for (final t in ForgeHallTab.values)
                  t.spec(() => ShopContext(view, controller), ref.strings),
              ],
            ));
    }
  }
}

/// Every panel but PERSONAJE / INVENTARIO (they close on Tab) and the big
/// map (Tab picks a destination) shows `PERSONAJE [TAB]`: plain Tab opens
/// it from anywhere in [body], text fields and grids included
/// (panels.md § "Teclado en los menús").
Widget withCharacterTab(WorldPanel panel, SessionView view,
    SessionController controller, Widget body) {
  final ownTab = panel == WorldPanel.character ||
      panel == WorldPanel.inventory ||
      panel == WorldPanel.map ||
      view.session.mode == SessionMode.battle;
  if (ownTab) return body;
  return PanelTabShortcut(
      onTab: () => controller.openPanel(WorldPanel.character), child: body);
}