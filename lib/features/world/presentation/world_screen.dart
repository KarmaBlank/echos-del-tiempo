import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/game_session.dart';
import '../../combat/presentation/battle_screen.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../inventory/domain/item_text.dart';
import '../../inventory/presentation/armory_panel.dart';
import '../../inventory/presentation/item_widgets.dart';
import '../../inventory/presentation/shop_sections.dart';
import '../../missions/domain/mission_text.dart';
import '../../missions/presentation/mission_board_panel.dart';
import '../../missions/presentation/prep_panel.dart';
import '../../missions/presentation/results_panel.dart';
import 'hud/world_hud.dart';
import 'map/map_game.dart';
import 'panels/character_panel.dart';
import 'session_battle_screen.dart';
import 'session_controller.dart';
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
    // Sonido: escucha los eventos de la sesión mientras la pantalla vive.
    ref.watch(sessionSfxProvider);

    // Recupera el foco si un cambio de pantalla lo dejó sin dueño.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focus.hasFocus) _focus.requestFocus();
    });

    // Se perdió la sala (el host se fue): vuelve al título con el motivo.
    final lost = view?.disconnected;
    if (lost != null && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop(lost);
      });
    }

    final Widget body;
    if (view == null || !sprites.hasValue || lost != null) {
      body = Center(
        child: Text(
          lost != null
              ? 'DESCONECTADO'
              : sprites.hasError
                  ? 'ERROR AL CARGAR SPRITES'
                  : 'CARGANDO...',
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
              zoneProgress: _zoneProgress(s, r, controller),
              unlocked: switch (r.unlocked[view.localId]) {
                final z? => zoneUnlockedText(
                    z, controller.engine.catalog.zone(z)?.name),
                null => null,
              },
              othersUnlocked: _othersUnlocked(s, r, view.localId),
              loot: [
                for (final d in view.missionLoot)
                  if (view.me case final me?)
                    ResultDrop(
                      dropLabelText(controller.engine.progression, d),
                      controller.engine.lootVerdict(me.profile, d),
                      tooltip: d.item == null
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
              chatFocus: _chatFocus,
              onChatDone: _chatDone,
            ),
          ),
          if (view.panel case final panel?)
            Positioned.fill(child: _panel(panel, view, controller)),
        ];
    }
  }

  /// `Zona 2 · Bosque Hondo · Piso 3/3` del resultado de una misión de
  /// zona (piso alcanzado; todos en una victoria).
  static String? _zoneProgress(
      GameSession s, MissionResult r, SessionController controller) {
    final z = controller.engine.catalog.zone(r.zone);
    if (z == null) return null;
    final floors = s.mission?.floors ?? z.floors;
    final reached = r.success ? floors : (s.mission?.floor ?? 0) + 1;
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
    return others.isEmpty ? null : 'También desbloquearon · ${others.join(' · ')}';
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
          // Proponer cierra el mostrador (línea 1363).
          onPropose: (id) {
            if (controller.proposeMission(id)) controller.closePanel();
          },
          onClose: controller.closePanel,
          onCharacter: () => controller.openPanel(WorldPanel.character),
        );
      case WorldPanel.armory:
        return ArmoryPanel(view: view, controller: controller);
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
                isLocal: p.id == view.localId,
              ),
          ],
          ready: prep.ready[view.localId] ?? false,
          credits: me.profile.credits,
          potions: me.profile.potions,
          ethers: me.profile.ethers,
          tier: missionTier(catalog, mission),
          bossName: missionBossName(catalog, mission),
          weaponName: me.profile.equippedUid == null
              ? '-'
              : rules.weaponDisplayName(me.profile, me.profile.equippedUid!),
          onReady: controller.setReady,
          onCancel: controller.cancelPrep,
          onCharacter: () => controller.openPanel(WorldPanel.character),
          // Las pestañas de la armería (en `prep` la del lobby no se abre).
          shopTabs: [
            for (final t in ArmoryTab.values)
              t.spec(() => ShopContext(view, controller)),
          ],
        );
    }
  }
}
