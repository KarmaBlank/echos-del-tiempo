import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/game_session.dart';
import '../../combat/presentation/battle_screen.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../missions/presentation/mission_board_panel.dart';
import '../../missions/presentation/prep_panel.dart';
import '../../missions/presentation/results_panel.dart';
import 'hud/world_hud.dart';
import 'map/map_game.dart';
import 'panels/character_panel.dart';
import 'session_battle_screen.dart';
import 'session_controller.dart';
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
  final _battleKey = GlobalKey<BattleViewState>();
  MapGame? _game;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
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
    final bool used;
    if (view.mode == SessionMode.battle) {
      used = _battleKey.currentState?.handleKey(event.logicalKey) ?? false;
    } else {
      used = controller.handleKey(event.logicalKey);
    }
    return used ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(sessionControllerProvider);
    final sprites = ref.watch(gameSpritesProvider);
    final controller = ref.read(sessionControllerProvider.notifier);

    // Recupera el foco si un cambio de pantalla lo dejó sin dueño.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focus.hasFocus) _focus.requestFocus();
    });

    final Widget body;
    if (view == null || !sprites.hasValue) {
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
        return [
          Positioned.fill(
            child: SessionBattleScreen(
              view: view,
              sprites: sprites,
              battleKey: _battleKey,
              onCommand: controller.battleCommand,
            ),
          ),
        ];
      case SessionMode.result:
        final r = s.result;
        if (r == null) return const [];
        final weapons = controller.engine.catalog.weapons;
        return [
          const Positioned.fill(
            child: ColoredBox(color: Color(0xCC0F0F1B)),
          ),
          Positioned.fill(
            child: ResultsPanel(
              result: r,
              localId: view.localId,
              playerName: (id) => s.players[id]?.name ?? '?',
              weaponName: (id) => weapons[id]?.name ?? id,
              onBack: controller.backToLobby,
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
            ),
          ),
          if (view.panel case final panel?)
            Positioned.fill(child: _panel(panel, view, controller)),
        ];
    }
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
          classes: catalog.classes,
          currentClassId: me.profile.classId,
          voteOpen: s.vote != null,
          onPropose: controller.proposeMission,
          onChangeClass: controller.changeClass,
          onClose: controller.closePanel,
        );
      case WorldPanel.armory:
        return PanelFrame(
          title: 'ARMERÍA',
          actions: [
            PanelButton('CERRAR [ESC]', onPressed: controller.closePanel),
          ],
          child: const ComingSoon('Armas, pociones, herrería y fusión'),
        );
      case WorldPanel.character:
        return CharacterPanel(view: view, controller: controller);
      case WorldPanel.prep:
        final prep = s.prep;
        final mission = prep == null ? null : catalog.mission(prep.missionId);
        if (prep == null || mission == null) return const SizedBox.shrink();
        return PrepPanel(
          mission: mission,
          players: [
            for (final p in s.playerList)
              PrepEntry(
                p.name,
                catalog.classes[p.profile.classId]?.name ?? p.profile.classId,
                p.profile.level,
                ready: prep.ready[p.id] ?? false,
              ),
          ],
          ready: prep.ready[view.localId] ?? false,
          credits: me.profile.credits,
          weaponName: me.profile.equipped == null
              ? '-'
              : rules.weaponDisplayName(me.profile, me.profile.equipped!),
          onReady: controller.setReady,
          onCancel: controller.cancelPrep,
          onCharacter: () => controller.openPanel(WorldPanel.character),
        );
    }
  }
}
