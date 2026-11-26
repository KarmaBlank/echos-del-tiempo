import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/action_box.dart';
import '../../../../game_engine/rules/cooking_rules.dart' show MealBuff, MealDef;
import '../../../inventory/domain/item_names.dart' show MealDefText;
import '../panels/cooking_view.dart' show activeMealLines;
import '../../../../app/theme/panel_frame.dart' show RetroTooltip;
import '../../../../app/theme/party_box.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/proto_markup.dart';
import '../../../../app/theme/retro_bar.dart';
import '../../../../app/theme/retro_panel.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../app/widgets/memo.dart';
import '../../../../game_engine/data/biomes_catalog.dart' show biomeLayout, kBiomes;
import '../../../../game_engine/rules/biome_regions.dart' show BiomeLayout;
import '../../../../game_engine/rules/map_discovery_rules.dart';
import '../../../../game_engine/rules/mining_rules.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/models/loot_filter.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/progression_rules.dart';
import '../../../../game_engine/rules/world_rules.dart';
import '../../../../game_engine/data/trials_catalog.dart';
import '../../../ascension/domain/ascension_text.dart';
import '../../../build_planner/presentation/build_feed.dart';
import '../../../endgame/domain/endgame_text.dart';
import '../../../missions/domain/mission_text.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../../../missions/presentation/vote_panel.dart';
import '../../../settings/presentation/settings_menu.dart';
import '../map/loot_painter.dart';
import '../map/map_game.dart';
import '../../../../core/settings/game_settings.dart';
import '../../../../core/settings/notices.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../characters/domain/unused_points.dart';
import '../../../characters/domain/xp_text.dart';
import 'chat_box.dart';
import 'exploration_lines.dart';
import 'full_map.dart';
import 'loot_feed.dart';
import 'minimap.dart';
import 'potion_shortcuts.dart';
import 'save_indicator.dart';
import 'day_clock.dart';
import 'tool_hud.dart';
import 'tracked_quests_hud.dart';
import 'update_notice.dart';
import 'unused_points_notice.dart';
import '../world_strings.dart';

/// `m:ss` con minutos de dos dígitos (`mm:ss` del HUD del prototipo).
String clockText(double seconds) {
  final s = seconds.floor();
  return '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';
}

/// HUD del mapa como overlays Flutter (`hud()`, `drawObjectives`,
/// `drawMinimap` y los avisos de `render`). Ver
/// docs/specs/exploration.md § "HUD".
/// Ancho fijo de la fila de atajos (pociones y faroles) sobre el grupo:
/// entran en un renglón y no cambia con el tamaño del grupo (v0.49.21).
const kQuickSlotsWidth = 440.0;

class WorldHud extends StatelessWidget {
  const WorldHud({
    super.key,
    required this.view,
    required this.controller,
    this.onExit,
    this.onMenu,
    this.chatFocus,
    this.onChatDone,
  });

  final SessionView view;
  final SessionController controller;

  /// Volver al título (solo en el lobby).
  final VoidCallback? onExit;

  /// Abre el menú de pausa (`≡ MENÚ [ESC]`); sin él no hay botón.
  final VoidCallback? onMenu;

  /// Foco del campo de chat (sin él no se muestra el campo).
  final FocusNode? chatFocus;

  /// Se terminó de escribir: el foco vuelve al juego.
  final VoidCallback? onChatDone;

  static const _gap = 16.0;

  /// Filas de cajas desplegadas que se permiten antes de pasar a
  /// compactas (v0.13).
  static const maxPartyRows = 2;

  /// Smallest scale of the party row when many members do not fit
  /// (v0.49.22): below this the text is no longer readable.
  static const minPartyScale = 0.8;

  @override
  Widget build(BuildContext context) {
    final s = view.session;
    final field = s.mode == SessionMode.field;
    final world = s.mode == SessionMode.lobby && view.map.entrances.isNotEmpty;
    // Mines show it too: the discovered veins (mining_smithing.md § 1.11).
    final showMinimap = world ||
        (view.map.lobby && MiningRules.isMine(view.map.place)) ||
        ((field || s.mode == SessionMode.levelUp) &&
            !view.map.lobby &&
            s.mission != null);
    final small = Theme.of(context).textTheme.bodySmall!;
    final players = s.playerList;
    // Cajas del grupo compactas por defecto; H o clic las despliega
    // (v0.8.2, exploration.md § "HUD").
    return Consumer(builder: (context, ref, _) {
      final expanded =
          ref.watch(gameSettingsProvider.select((g) => g.partyExpanded));
      return _layout(context, s, players, expanded, small, field,
          showMinimap: showMinimap);
    });
  }

  Widget _layout(
      BuildContext context,
      GameSession s,
      Iterable<SessionPlayer> players,
      bool expandedPref,
      TextStyle small,
      bool field,
      {required bool showMinimap}) {
    return LayoutBuilder(builder: (context, box) {
      // Con texto grande las cajas del grupo pasan a dos filas antes que
      // pisar el chat (mínimo 240 px de chat).
      // Compactas (v0.8.2): el chat cede un poco más (es una píldora por
      // defecto), así con texto ENORME entran dos cajas por fila.
      // Una sola fila (v0.49.21): presentes + los que están en otro lugar,
      // misma caja para todos; si no entra, la fila entera se achica.
      final n = players.length + s.away.length;
      // Compact cards as wide as the longest first line (v0.49.22): the
      // text keeps its size; same width for every card.
      var compactW = PartyBox.compactWidthOf(context);
      for (final p in players) {
        final w = CompactPlayerBox.naturalWidthOf(
            context, p, controller.engine.progression);
        if (w > compactW) compactW = w;
      }
      double rowWidth(bool exp) {
        final w = exp ? PartyBox.widthOf(context) : compactW;
        return (n == 0 ? 1 : n) * (w + 6);
      }

      double roomFor(bool exp) =>
          (box.maxWidth - RetroType.width(context, exp ? 240 : 200) - _gap * 3)
              .clamp(PartyBox.compactWidthOf(context), double.infinity);
      // Desplegadas solo si la fila entra entera.
      final expanded = expandedPref && rowWidth(true) <= roomFor(true);
      final boxW = expanded ? PartyBox.widthOf(context) : compactW;
      final chatMin = RetroType.width(context, expanded ? 240 : 200);
      final natural = rowWidth(expanded);
      final room = roomFor(expanded);
      // Only a row wider than its room shrinks, down to [minPartyScale]
      // (still readable) by taking chat room; never past the screen.
      final partyWidth = natural <= room
          ? natural
          : math.min(math.max(room, natural * minPartyScale),
              math.max(room, box.maxWidth - _gap * 2));
      final cardH = expanded ? null : PartyBox.compactHeightOf(context);
      // Con una herramienta en la mano el chat cede lugar a la barra de
      // abajo al centro (v0.24.4).
      // A la derecha, lo más ancho entre el grupo y las pociones.
      final quickW = RetroType.width(context, kQuickSlotsWidth)
          .clamp(0.0, room > partyWidth ? room : partyWidth);
      final rightWidth = partyWidth < quickW
          ? quickW
          : partyWidth;
      final toolRoom =
          controller.activeTool == null ? 0.0 : ToolHud.width + _gap;
      var chatWidth = (box.maxWidth - rightWidth - _gap * 3 - toolRoom)
          .clamp(chatMin, RetroType.width(context, 520));
      // Con herramienta, el chat termina antes de la barra centrada.
      if (toolRoom > 0) {
        final free = (box.maxWidth - ToolHud.width) / 2 - _gap * 2;
        if (free < chatWidth) chatWidth = free < chatMin ? chatMin : free;
      }
      return DefaultTextStyle.merge(
        style: small,
        child: Stack(
          children: [
            // Fila de arriba (v0.10.1): botones a la izquierda, la línea
            // de misión en el medio y sala / minimapa a la derecha, sin
            // superponerse nunca (`_TopRowLayout`).
            Positioned.fill(
              child: CustomMultiChildLayout(
                delegate: _TopRowLayout(
                    gap: _gap,
                    minimapTop: _gap + 48,
                    objectivesTop: _gap + RetroType.width(context, 48)),
                children: [
                  LayoutId(
                    id: _TopSlot.bar,
                    // Sin banner de misión en la mazmorra (exploration.md § "HUD"): el
                    // resumen de objetivos ya lo dice. Arriba al centro queda
                    // `SALIR DE LA MAZMORRA`, sin pisar nada.
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.canLeaveDungeon)
                          DsButton(context.t('ui.world.hud.leave_dungeon'),
                              key: const ValueKey('hud-leave-dungeon'),
                              onPressed: controller.leaveDungeon),
                        Memo(
                          deps: [
                            _MissionBar.textFor(view, worldStrings(context)),
                            turnTimerNote(view),
                          ],
                          builder: (_) => _MissionBar(view: view),
                        ),
                      ],
                    ),
                  ),
                  // `< TITULO` (solo en el lobby) y `≡ MENÚ` (siempre): la pausa
                  // con sonido, pantalla, juego, controles y salidas.
                  LayoutId(
                    id: _TopSlot.left,
                    child: Memo(
                      deps: [
                        s.mode == SessionMode.lobby,
                        onExit != null,
                        onMenu != null,
                        controller.canEditParty,
                        controller.stashBlock == null,
                        controller.isRun,
                        s.mode == SessionMode.battle,
                        view.companions.length,
                        _unusedKey(_unused(s)),
                      ],
                      builder: (_) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (s.mode == SessionMode.lobby &&
                                  onExit != null) ...[
                                DsButton(context.t('ui.world.hud.to_title'),
                                    key: const ValueKey('hud-exit'),
                                    size: DsButtonSize.compact,
                                    onPressed: onExit),
                                const SizedBox(width: 8),
                              ],
                              if (onMenu != null)
                                PauseMenuButton(onPressed: onMenu!),
                              // Alijo de la cuenta, fuera de batalla (characters.md
                              // § 3.2).
                              if (controller.stashBlock == null) ...[
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  key: const ValueKey('hud-stash'),
                                  style: RetroTheme.compactButton(),
                                  onPressed: controller.toggleStash,
                                  child: Text(context.t('ui.world.hud.stash')),
                                ),
                              ],
                              // DIARIO de encargos (roles.md § 8.1), fuera de la
                              // Travesía.
                              if (!controller.isRun &&
                                  s.mode != SessionMode.battle) ...[
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  key: const ValueKey('hud-journal'),
                                  style: RetroTheme.compactButton(),
                                  onPressed: controller.toggleJournal,
                                  child:
                                      Text(context.t('ui.world.hud.journal')),
                                ),
                              ],
                              // Party jugando solo, en el pueblo (solo_party.md § 2.3).
                              if (controller.canEditParty) ...[
                                const SizedBox(width: 8),
                                DsButton(
                                    context.t('ui.world.hud.party',
                                        {'n': view.companions.length + 1}),
                                    key: const ValueKey('hud-party'),
                                    size: DsButtonSize.compact,
                                    onPressed: controller.toggleParty),
                              ],
                              // `PERSONAJE [TAB]` siempre; con `+N` si hay puntos
                              // sin usar (passive_tree_v4.md § 7, v0.49.20).
                              ...[
                                const SizedBox(width: 8),
                                Consumer(
                                  builder: (context, ref, _) =>
                                      UnusedPointsButton(
                                    points: _unused(s),
                                    reduceMotion: ref.watch(gameSettingsProvider
                                        .select((g) => g.reduceMotion)),
                                    onPressed: controller.toggleCharacter,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Hay versión nueva (update_notice.md).
                          const UpdateNotice(),
                        ],
                      ),
                    ),
                  ),
                  // `Sala: CODIGO [Copiar]` del prototipo (HTML línea 87).
                  if (view.roomCode case final code?)
                    LayoutId(
                      id: _TopSlot.room,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.t('ui.world.hud.room', {'code': code}),
                              key: const ValueKey('hud-room-code'),
                              style: DsText.body(DsColors.textTitle)),
                          SizedBox(width: DsSpace.sm),
                          DsButton(context.t('ui.world.hud.copy'),
                              key: const ValueKey('hud-room-copy'),
                              size: DsButtonSize.compact,
                              tooltip: context.t('ui.world.hud.copy_tip'),
                              onPressed: () =>
                                  Clipboard.setData(ClipboardData(text: code))),
                        ],
                      ),
                    ),
                  // Minimapa con zoom (rueda o `-` `+`, se recuerda) y
                  // `MAPA [M]` (v0.8.1).
                  if (showMinimap || s.mode == SessionMode.lobby)
                    LayoutId(
                      id: _TopSlot.minimap,
                      child: Consumer(builder: (context, ref, _) {
                        // Biome exteriors open close, framed on the way from
                        // the arrival to the portals; the player's own zoom
                        // is kept for the session (biome_exploration.md §
                        // 11.3).
                        final biome = biomeExteriorOf(view);
                        final picked = ref.watch(biomeMinimapZoomProvider);
                        final saved = ref.watch(
                            gameSettingsProvider.select((g) => g.minimapZoom));
                        final double? biomeCell = biome == null
                            ? null
                            : picked == null
                                ? biomeMinimapCell(biome)
                                : hudMinimapCell(view, picked);
                        final zoom = biome == null
                            ? saved
                            : picked ?? biomeMinimapLevel(view, biomeCell!);
                        // From the framed default `-` steps to the level just
                        // below it (which may share the level number).
                        final cur = biomeCell ?? hudMinimapCell(view, zoom);
                        final down = biomeCell != null &&
                                cur > hudMinimapCell(view, zoom) + 1e-6
                            ? zoom
                            : zoom - 1;
                        void setZoom(int z) => biome == null
                            ? setMinimapZoom(ref, z)
                            : ref.read(biomeMinimapZoomProvider.notifier).state =
                                z.clamp(1, GameSettings.minimapZooms);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Town has no minimap but still shows the clock (v0.48.4).
                            if (showMinimap) ...[
                            RetroPanel(
                              padding: const EdgeInsets.all(4),
                              child: Listener(
                                onPointerSignal: (e) {
                                  if (e is PointerScrollEvent) {
                                    setZoom(
                                        zoom + (e.scrollDelta.dy < 0 ? 1 : -1));
                                  }
                                },
                                child: hudMinimap(view, controller,
                                    zoom: zoom, cell: biomeCell),
                              ),
                            ),
                            // Tiempo en la mazmorra bajo el minimapa
                            // (exploration.md § "HUD").
                            if (field && s.mission != null) ...[
                              const SizedBox(height: 4),
                              Text(retroText(clockText(s.mission!.elapsed)),
                                  key: const ValueKey('hud-mission-time'),
                                  style: DsText.body(DsColors.textPrimary)),
                            ],
                            const SizedBox(height: 4),
                            // Los botones no toman el foco (el teclado sigue en
                            // el juego).
                            Memo(
                              deps: [zoom, down],
                              builder: (_) => ExcludeFocus(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DsButton.icon(const Text('-'),
                                        key: const ValueKey('minimap-zoom-out'),
                                        tooltip: context
                                            .t('ui.world.hud.minimap_out'),
                                        size: DsButtonSize.compact,
                                        onPressed: down >= 1
                                            ? () => setZoom(down)
                                            : null),
                                    SizedBox(width: DsSpace.xs),
                                    DsButton.icon(const Text('+'),
                                        key: const ValueKey('minimap-zoom-in'),
                                        tooltip: context
                                            .t('ui.world.hud.minimap_in'),
                                        size: DsButtonSize.compact,
                                        onPressed: zoom <
                                                GameSettings.minimapZooms
                                            ? () =>
                                                setZoom(zoom + 1)
                                            : null),
                                    SizedBox(width: DsSpace.xs),
                                    DsButton(context.t('ui.world.hud.map'),
                                        key: const ValueKey('minimap-open-map'),
                                        size: DsButtonSize.compact,
                                        onPressed: controller.toggleMap),
                                  ],
                                ),
                              ),
                            ),
                            ],
                            // Reloj del día (day_night_weather.md § 1.1):
                            // arriba, lejos de la barra de herramientas.
                            if (s.mode == SessionMode.lobby &&
                                s.town.sky.started) ...[
                              const SizedBox(height: 4),
                              DayClock(sky: s.town.sky, place: s.place),
                            ],
                            // Herramienta en la mano (v0.49.21): columna
                            // fija bajo el reloj; el aviso sigue abajo.
                            if (controller.activeTool != null)
                              if (view.me?.profile case final prof?) ...[
                                const SizedBox(height: 4),
                                ToolHud(controller: controller, profile: prof),
                              ],
                            // Encargos seguidos (roles.md § 8.2).
                            if (s.mode == SessionMode.lobby &&
                                view.me?.profile != null) ...[
                              const SizedBox(height: 4),
                              TrackedQuestsHud(
                                  profile: view.me!.profile,
                                  town: s.town,
                                  onOpen: controller.toggleJournal),
                            ],
                          ],
                        );
                      }),
                    ),
                  // Objetivos plegables (J o clic en la cabecera; el estado
                  // se guarda), debajo de los botones y de la línea de
                  // misión si le queda encima.
                  if (field && s.mission != null)
                    LayoutId(
                      id: _TopSlot.objectives,
                      child: Consumer(
                        builder: (context, ref, _) => _Objectives(
                            mission: s.mission!,
                            zoneName: _missionName(s, worldStrings(context)),
                            floorLevel: MapGame.currentFloor(view)?.level,
                            floor: MapGame.currentFloor(view),
                            time: s.time,
                            collapsed: ref.watch(gameSettingsProvider
                                .select((g) => g.objectivesCollapsed)),
                            onToggle: () => toggleObjectives(ref)),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: _gap,
              bottom: _gap,
              width: chatWidth,
              child: Memo(
                deps: [
                  view.chat,
                  view.messages,
                  chatFocus,
                  _localNameOf(s),
                  view.saving,
                ],
                builder: (_) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Registro de loot (`Ana encontró: ...`) encima del chat.
                    Consumer(
                      builder: (context, ref, _) =>
                          LootLog(feed: ref.watch(lootFeedProvider)),
                    ),
                    const SizedBox(height: 6),
                    chatFocus == null
                        ? _MessageLog(messages: view.messages)
                        // CHAT: OCULTO / SIEMPRE VISIBLE (v0.8.1).
                        : Consumer(builder: (context, ref, _) {
                            final (chat, notices, duration) = ref.watch(
                                gameSettingsProvider.select((g) =>
                                    (g.chat, g.chatNotices, g.noticeDuration)));
                            final me = s.players[view.localId];
                            return ChatBox(
                              lines: view.chat,
                              focusNode: chatFocus!,
                              onSend: controller.sendChat,
                              onDone: onChatDone ?? () {},
                              collapsible: chat == ChatVisibility.hidden,
                              notices: notices,
                              // DURACIÓN DE LOS AVISOS (accessibility.md § 9.5).
                              noticeDuration:
                                  duration.scale(ChatBox.toastDuration),
                              dismissSignal: ref.watch(noticeDismissProvider),
                              localName: me == null
                                  ? null
                                  : heroTitle(me.name, me.profile.classId,
                                      me.profile.ascension.id),
                            );
                          }),
                    // Aviso de guardado bajo el chat (save_indicator.md § 2).
                    if (view.saving) ...[
                      const SizedBox(height: 4),
                      const SaveIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            if (_voteBox(s) case final vote?)
              Positioned(
                top: _gap + 48,
                left: 0,
                right: 0,
                child: Center(child: vote),
              ),
            // Herramienta en la mano y su aviso (solo en el pueblo): barra
            // centrada en la PANTALLA (v0.25.9): el chat se angosta para no
            // correrla; solo la columna derecha en pantallas chicas.
            if (s.players[view.localId] case final me?
                when controller.activeTool != null)
              Positioned(
                left: toolSide(box.maxWidth, _gap * 2 + chatWidth,
                        _gap * 2 + rightWidth)
                    .$1,
                right: toolSide(box.maxWidth, _gap * 2 + chatWidth,
                        _gap * 2 + rightWidth)
                    .$2,
                bottom: _gap,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ToolPrompt(
                        key: ValueKey('hud-tool-prompt-${me.id}'),
                        controller: controller),
                  ),
                ),
              ),
            // `#party`: UNA fila fija de cajas del mismo tamaño
            // (free_movement.md § 4): no salta de alto ni de ancho cuando
            // alguien cambia de lugar.
            Positioned(
              right: _gap,
              bottom: _gap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pociones fuera de batalla (loot.md § 17.5).
                  if (s.mode != SessionMode.battle)
                    if (s.players[view.localId] case final me?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SizedBox(
                            key: const ValueKey('hud-quick-slots'),
                            width: quickW,
                            child: PotionShortcuts(
                                controller: controller, player: me)),
                      ),
                  SizedBox(
                    key: const ValueKey('hud-party-boxes'),
                    width: partyWidth,
                    height: cardH == null
                        ? null
                        : cardH * (partyWidth / natural).clamp(0.0, 1.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final c in [
                            // Los que están en otro lugar: misma caja,
                            // atenuada, con dónde y UNIRSE (§ 2.5).
                            for (final a in s.away)
                              _AwayBox(
                                  key: ValueKey('hud-away-${a.id}'),
                                  player: a,
                                  width: boxW,
                                  height: cardH,
                                  onJoin: controller.canJoinPlayer(a)
                                      ? () => controller.joinPlayer(a)
                                      : null,
                                  blocked: controller.joinPlayerBlock(a)),
                            // Cada caja se arma solo si cambió lo que muestra.
                            for (final p in players)
                              Memo(
                                key: ValueKey('hud-party-memo-${p.id}'),
                                deps: [_boxKey(p, expanded), boxW],
                                builder: (_) => Consumer(
                                  builder: (context, ref, _) => _Toggle(
                                    key: ValueKey('hud-party-${p.id}'),
                                    expanded: expanded,
                                    onTap: () => togglePartyBoxes(ref),
                                    child: SizedBox(
                                      height: cardH,
                                      child: expanded
                                          ? _PlayerBox(
                                              player: p,
                                              local: p.id == view.localId,
                                              progression:
                                                  controller.engine.progression,
                                            )
                                          : CompactPlayerBox(
                                              player: p,
                                              local: p.id == view.localId,
                                              progression:
                                                  controller.engine.progression,
                                              width: boxW,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                          ])
                            Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: c),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 200,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avances del plan de build (build_planner.md § 5).
                    Memo(
                      deps: const [],
                      builder: (_) => Consumer(
                        builder: (context, ref, _) =>
                            BuildToasts(feed: ref.watch(buildFeedProvider)),
                      ),
                    ),
                    Memo(
                      deps: const [],
                      builder: (_) => Consumer(
                        builder: (context, ref, _) =>
                            LootToasts(feed: ref.watch(lootFeedProvider)),
                      ),
                    ),
                    // Aviso al subir de nivel con puntos de árbol sin usar.
                    Memo(
                      deps: [
                        _unusedKey(_unused(s)),
                        s.players[view.localId]?.profile.treeLevel,
                        s.players[view.localId]?.profile.ascension.earned,
                        s.mode == SessionMode.levelUp || view.panel != null,
                      ],
                      builder: (_) => Consumer(
                        builder: (context, ref, _) => UnusedPointsToast(
                          points: _unused(s),
                          treeLevel:
                              s.players[view.localId]?.profile.treeLevel ?? 0,
                          ascensionEarned: s.players[view.localId]?.profile
                                  .ascension.earned ??
                              0,
                          blocked: s.mode == SessionMode.levelUp ||
                              view.panel != null,
                          reduceMotion: ref.watch(gameSettingsProvider
                              .select((g) => g.reduceMotion)),
                          duration: ref
                              .watch(gameSettingsProvider
                                  .select((g) => g.noticeDuration))
                              .scale(UnusedPointsToast.shown),
                          dismissSignal: ref.watch(noticeDismissProvider),
                        ),
                      ),
                    ),
                    for (final line in _banners(context, s))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: DsToast(retroText(line),
                            key: const ValueKey('hud-banner'),
                            kind: DsToastKind.reward),
                      ),
                    // `[E] ...`: caja `#000a` y texto dorado (sello violeta).
                    // Pesca y huerta: el aviso va en el HUD de herramienta.
                    // Ayudante con la barra de herramienta abierta: ya lo
                    // dice la barra (no repetirlo).
                    if (view.prompt == WorldPrompt.fishing ||
                        view.prompt == WorldPrompt.farm ||
                        (view.prompt == WorldPrompt.helper &&
                            controller.toolPrompt != null))
                      const SizedBox.shrink()
                    else if ((view.promptText ??
                            switch (view.prompt) {
                              final p? => context.t(p.key),
                              null => null,
                            })
                        case final label?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _CanvasLabel(label,
                            key: const ValueKey('hud-prompt'),
                            fontSize: label.startsWith('[E')
                                ? RetroType.title
                                : RetroType.small,
                            color: view.prompt == WorldPrompt.seal
                                ? ProtoColors.violet
                                : view.prompt == WorldPrompt.spent
                                    ? ProtoColors.dim
                                    : label.startsWith('[E')
                                        ? ProtoColors.gold
                                        : ProtoColors.sky),
                      )
                    else if (_pickPrompt(context, s) case final text?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _CanvasLabel(text,
                            key: const ValueKey('hud-pickup-prompt'),
                            fontSize: RetroType.title,
                            color: ProtoColors.gold),
                      ),
                  ],
                ),
              ),
            ),
            if (s.mode == SessionMode.levelUp) _LevelUpBanner(session: s),
          ],
        ),
      );
    });
  }

  /// [UnusedPoints] comparable (para [Memo]).
  static (int, int, int, int) _unusedKey(UnusedPoints u) =>
      (u.attributes, u.tree, u.ascension, u.companionTotal);

  /// Lo que el chat muestra del jugador local (su nombre en las burbujas).
  (String, String, String?)? _localNameOf(GameSession s) {
    final me = s.players[view.localId];
    return me == null
        ? null
        : (me.name, me.profile.classId, me.profile.ascension.id);
  }

  /// Todo lo que muestra la caja de [p] (compacta o desplegada): si no
  /// cambió, la caja no se reconstruye.
  Object _boxKey(SessionPlayer p, bool expanded) {
    final prof = p.profile;
    return (
      p.id,
      p.id == view.localId,
      p.name,
      p.alive,
      p.hp,
      p.maxHp,
      p.mp,
      p.maxMp,
      prof.classId,
      prof.ascension.id,
      prof.level,
      prof.points,
      expanded
          ? (
              prof.equipped == null
                  ? null
                  : controller.engine.progression
                      .weaponDisplayName(prof, prof.equipped!),
              prof.xp,
              prof.credits,
              prof.potions,
              prof.ethers,
              prof.mastery,
            )
          : null,
    );
  }

  /// Puntos sin usar del jugador local (atributos, árbol, ascensión).
  /// Con party jugando solo, más los de cada compañero (solo_party.md
  /// § 6.3).
  UnusedPoints _unused(GameSession s) {
    final me = s.players[view.localId];
    if (me == null) return UnusedPoints.none;
    final rules = controller.engine.progression;
    final own = UnusedPoints.of(me.profile, rules);
    if (view.companions.isEmpty) return own;
    return own.withCompanions([
      for (final id in view.companions)
        if (s.players[id] case final p?)
          (p.name, UnusedPoints.of(p.profile, rules).total),
    ]);
  }

  /// Nombre de la misión en curso: la zona si es de zona.
  String _missionName(GameSession s, Strings str) {
    final m = s.mission;
    if (m == null) return '';
    final cat = controller.engine.catalog;
    // Eco: `Eco T7 · Grieta Ígnea` (docs/specs/ecos_atlas.md § 4).
    final eco = s.eco;
    if (eco != null && m.missionId == 'eco') {
      final z = cat.zone(eco.zone);
      return str.t('ui.missions.hud.eco_name', {
        'tier': eco.tier,
        'zone': z == null ? '' : zoneNameText(str, z),
      });
    }
    // Prueba del Tiempo (docs/specs/ascension.md § 1).
    final trial = trialDef(s.trial);
    if (trial != null && m.missionId == 'trial') {
      return str.t('ui.missions.hud.trial_name', {'roman': trial.roman});
    }
    final z = cat.zone(m.zone);
    if (z != null) return zoneNameText(str, z);
    final md = cat.mission(m.missionId);
    return md == null ? m.missionId : missionNameText(str, md);
  }

  /// Lo que el jugador local ve del piso (con Alt, también lo oculto).
  List<LootOnFloor> _floor(GameSession s) {
    final me = s.players[view.localId];
    if (me == null ||
        (s.mode != SessionMode.field && s.mode != SessionMode.lobby)) {
      return const [];
    }
    return visibleLoot(
        s,
        view.localId,
        (d) => controller.engine
            .lootVerdict(me.profile, d, wants: controller.localWants),
        showAll: MapGame.altHeld());
  }

  /// `[E] Recoger <objeto>` a <= 24 px de algo dibujado (sin otra
  /// interacción a mano; ver `MapGame.tryPickUp`).
  String? _pickPrompt(BuildContext context, GameSession s) {
    if (view.panel != null) return null;
    final l =
        nearestPickable(_floor(s), controller.local.x, controller.local.y);
    if (l == null) return null;
    return context.t('ui.world.hud.pick_up',
        {'item': MapGame.lootName(controller, l.ground.drop)});
  }

  /// Votación en curso (`renderVote`), solo en el lobby.
  Widget? _voteBox(GameSession s) {
    final v = s.vote;
    if (s.mode != SessionMode.lobby || v == null) return null;
    final m = controller.engine.missionOf(s, v.missionId);
    return VotePanel(
      proposedBy: v.proposedBy,
      missionName: m?.name ?? v.missionId,
      rank: m?.rank ?? '?',
      players: [
        for (final p in s.playerList)
          VoteEntry(p.name, yes: v.yes.contains(p.id)),
      ],
      voted: v.yes.contains(view.localId),
      onVote: controller.vote,
    );
  }

  /// Avisos de una línea: barrera abierta (escalera o jefe).
  List<String> _banners(BuildContext context, GameSession s) {
    final out = <String>[];
    final m = s.mission;
    final f = MapGame.currentFloor(view);
    if (m != null && f != null && !f.last) {
      final d = f.stairsDown;
      if (s.mode == SessionMode.field &&
          s.gateOpen &&
          d != null &&
          WorldRules.distance(
                  controller.local.x, controller.local.y, d.x, d.y) >
              140) {
        out.add(context.t('ui.world.hud.stairs_open', {'floor': m.floor + 2}));
      }
      return out;
    }
    final boss = f?.boss ?? view.map.boss;
    if (s.mode == SessionMode.field &&
        s.gateOpen &&
        boss != null &&
        WorldRules.distance(
                controller.local.x, controller.local.y, boss.x, boss.y) >
            140) {
      out.add(context.t('ui.world.hud.barrier_open'));
    }
    return out;
  }
}

/// `Turnos: sin límite (anfitrión)`: el tiempo de turno de la sala en el
/// pueblo y la preparación, si no es el normal; `null` si no hay que
/// decir nada.
String? turnTimerNote(SessionView view) {
  final s = view.session;
  if (s.turnTimer == TurnTimer.normal) return null;
  if (s.mode != SessionMode.lobby && s.mode != SessionMode.prep) return null;
  final host = view.roomCode != null ? ' (anfitrión)' : '';
  return 'Turnos: ${s.turnTimer.label}$host';
}

enum _TopSlot { left, bar, room, minimap, objectives }

/// Fila de arriba del HUD (v0.10.1, exploration.md § "HUD"): los botones
/// arriba a la izquierda, la sala arriba a la derecha y el minimapa
/// debajo de ella; la línea de misión centrada en el hueco del medio
/// (más angosta si hace falta). Si el hueco es muy chico, va debajo de
/// los botones. Nunca se superponen.
class _TopRowLayout extends MultiChildLayoutDelegate {
  _TopRowLayout(
      {required this.gap,
      required this.minimapTop,
      required this.objectivesTop});

  final double gap;
  final double minimapTop;

  /// Alto mínimo de la caja de objetivos (debajo de los botones).
  final double objectivesTop;

  /// Hueco mínimo del medio para la línea de misión (más chico: va
  /// debajo de los botones).
  static const minBar = 120.0;

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(size);
    var leftRect = Rect.fromLTWH(gap, gap, 0, 0);
    if (hasChild(_TopSlot.left)) {
      final l = layoutChild(_TopSlot.left, loose);
      positionChild(_TopSlot.left, Offset(gap, gap));
      leftRect = Offset(gap, gap) & l;
    }
    var right = size.width - gap;
    var roomBottom = gap;
    if (hasChild(_TopSlot.room)) {
      final r = layoutChild(_TopSlot.room, loose);
      final o = Offset(size.width - gap - r.width, gap);
      positionChild(_TopSlot.room, o);
      right = o.dx;
      roomBottom = gap + r.height;
    }
    if (hasChild(_TopSlot.minimap)) {
      final m = layoutChild(_TopSlot.minimap, loose);
      final top = minimapTop > roomBottom + 4 ? minimapTop : roomBottom + 4;
      final o = Offset(size.width - gap - m.width, top);
      positionChild(_TopSlot.minimap, o);
      if (o.dx < right) right = o.dx;
    }
    Rect? barRect;
    if (hasChild(_TopSlot.bar)) {
      final from = leftRect.right + 8;
      final to = right - 8;
      if (to - from >= minBar) {
        final b = layoutChild(_TopSlot.bar,
            BoxConstraints(maxWidth: to - from, maxHeight: size.height));
        // Centrada en la pantalla si entra; si no, en el hueco.
        final x = ((size.width - b.width) / 2).clamp(from, to - b.width);
        positionChild(_TopSlot.bar, Offset(x, gap));
        barRect = Offset(x, gap) & b;
      } else {
        final w = (right - 8 - gap).clamp(0.0, size.width);
        final b = layoutChild(
            _TopSlot.bar, BoxConstraints(maxWidth: w, maxHeight: size.height));
        final o = Offset(gap, leftRect.bottom + 4);
        positionChild(_TopSlot.bar, o);
        barRect = o & b;
      }
    }
    if (hasChild(_TopSlot.objectives)) {
      final o = layoutChild(_TopSlot.objectives, loose);
      var top = objectivesTop;
      if (leftRect.bottom + 4 > top) top = leftRect.bottom + 4;
      final bar = barRect;
      if (bar != null &&
          !bar.isEmpty &&
          bar.left < gap + o.width &&
          bar.bottom + 4 > top) {
        top = bar.bottom + 4;
      }
      positionChild(_TopSlot.objectives, Offset(gap, top));
    }
  }

  @override
  bool shouldRelayout(_TopRowLayout old) =>
      old.gap != gap ||
      old.minimapTop != minimapTop ||
      old.objectivesTop != objectivesTop;
}

class _MissionBar extends StatelessWidget {
  const _MissionBar({required this.view});

  final SessionView view;

  /// El texto de la barra (también es la clave de su [Memo]): solo la
  /// preparación. En misión no hay banner (exploration.md § "HUD": zona, piso y
  /// objetivos van en el resumen de la izquierda; el tiempo, bajo el
  /// minimapa).
  static String? textFor(SessionView view, Strings str) =>
      view.session.mode == SessionMode.prep
          ? str.t('ui.missions.hud.prep')
          : null;

  @override
  Widget build(BuildContext context) {
    final text = textFor(view, worldStrings(context));
    // Tiempo de turno de la sala si no es el normal (en co-op lo fija el
    // anfitrión; accessibility.md § 7).
    final turns = turnTimerNote(view);
    if (text == null && turns == null) return const SizedBox.shrink();
    // `#mission`: verde `#7bed9f`. Una línea; si no entra en el hueco
    // entre los botones y el minimapa, se achica (v0.10.1: nunca se
    // superpone ni empuja los objetivos hacia abajo).
    return FittedBox(
      fit: BoxFit.scaleDown,
      // Superficie sin borde (design_system.md § 2, principio 0): la
      // misión en Cuerpo, el tiempo de turno en Detalle.
      child: Container(
        key: const ValueKey('hud-mission-bar'),
        color: DsColors.surface,
        padding:
            EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text != null)
              Text(retroText(text),
                  maxLines: 1, style: DsText.body(DsColors.textPrimary)),
            if (turns != null)
              Text(retroText(turns),
                  key: const ValueKey('hud-turn-timer'),
                  maxLines: 1,
                  style: DsText.detail()),
          ],
        ),
      ),
    );
  }
}

/// Texto dibujado en el canvas del prototipo sobre una caja `#000a`.
class _CanvasLabel extends StatelessWidget {
  const _CanvasLabel(this.text,
      {super.key, required this.color, this.fontSize = RetroType.small});

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
        color: ProtoColors.scrim(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(retroText(text),
            style: RetroType.style(fontSize, color: color)),
      );
}

/// Zoom del minimapa del HUD (1..3) guardado en los ajustes.
void setMinimapZoom(WidgetRef ref, int zoom) {
  final s = ref.read(gameSettingsProvider);
  unawaited(ref
      .read(gameSettingsProvider.notifier)
      .update(s.copyWith(minimapZoom: zoom)));
}

/// Tamaño (px) de la ventana del minimapa: a zoom 3 son ~22×16 tiles
/// alrededor del jugador; con zoom 1 el piso entero se encoge para caber
/// (biome_exploration.md § 11.3). Para ver más está el mapa grande (M).
const kMinimapWindow = Size(168, 118);

/// The overworld map layer (biome_exploration.md § 11) when the party is
/// in a biome exterior; `null` in town, dungeons and the world map.
OverworldOverlay? overworldOverlayFor(
    SessionView view, SessionController controller) {
  final s = view.session;
  if (s.mode != SessionMode.lobby) return null;
  final lay = biomeLayout(s.place);
  if (lay == null || view.map.place != lay.id) return null;
  final town = s.town;
  return OverworldOverlay(
    known: MapDiscoveryRules.known(town, lay),
    cacheKey: (lay.id, lay.seed, town.discovery[lay.id] ?? ''),
    marks: MapDiscoveryRules.marks(lay),
    entranceOpen: _entranceOpen(view, controller),
    waystoneActive: controller.waystoneActive,
  );
}

/// The dungeon map layer (biome_exploration.md § 11.8) on a mission
/// floor; `null` in town, biomes and the world map.
DungeonOverlay? dungeonOverlayFor(SessionView view) {
  final s = view.session;
  final m = s.mission;
  if (m == null || s.mode == SessionMode.lobby) return null;
  final map = view.map;
  return DungeonOverlay(
    mask: DiscoveryMask(
      known: DungeonDiscoveryRules.known(m, map),
      cols: DungeonDiscoveryRules.cols(map),
      rows: DungeonDiscoveryRules.rows(map),
      cacheKey: (m.missionId, m.seed, m.discoveryRev, identityHashCode(map)),
    ),
    goals: DungeonDiscoveryRules.goals(map, m.floor),
  );
}

/// The minimap zoom the player picked in biome exteriors this session
/// (`null` = the framed default, [biomeMinimapCell]).
final biomeMinimapZoomProvider = StateProvider<int?>((ref) => null);

/// The biome exterior the party stands in, or `null`.
BiomeLayout? biomeExteriorOf(SessionView view) {
  final s = view.session;
  if (s.mode != SessionMode.lobby) return null;
  final lay = biomeLayout(s.place);
  if (lay == null || view.map.place != lay.id) return null;
  return lay;
}

/// Cell (px per tile) of zoom level [zoom] on [view]'s map.
double hudMinimapCell(SessionView view, int zoom) {
  final area = MapGame.currentFloor(view)?.bounds ??
      TileRect(0, 0, view.map.width, view.map.height);
  return zoom <= 1
      ? [
          Minimap.baseCell,
          kMinimapWindow.width / area.w,
          kMinimapWindow.height / area.h,
        ].reduce((a, b) => a < b ? a : b)
      : Minimap.baseCell * zoom;
}

/// Default minimap cell in a biome exterior: the box from the arrival to
/// the zone portals (plus a margin) fills the window, clamped between
/// the whole-biome fit and the closest level. It does not change as
/// more is discovered.
double biomeMinimapCell(BiomeLayout lay, {int margin = 3}) {
  final pts = <(int, int)>[
    (lay.mainPath.first.$1, BiomeLayout.height - 3),
    for (final (_, x, y) in lay.entrances) (x, y),
  ];
  var x0 = pts.first.$1, x1 = x0, y0 = pts.first.$2, y1 = y0;
  for (final (x, y) in pts) {
    if (x < x0) x0 = x;
    if (x > x1) x1 = x;
    if (y < y0) y0 = y;
    if (y > y1) y1 = y;
  }
  final bw = (x1 - x0 + 1 + 2 * margin).toDouble();
  final bh = (y1 - y0 + 1 + 2 * margin).toDouble();
  final need = [kMinimapWindow.width / bw, kMinimapWindow.height / bh]
      .reduce((a, b) => a < b ? a : b);
  final fit = [
    Minimap.baseCell,
    kMinimapWindow.width / BiomeLayout.width,
    kMinimapWindow.height / BiomeLayout.height,
  ].reduce((a, b) => a < b ? a : b);
  return need.clamp(fit, Minimap.baseCell * GameSettings.minimapZooms);
}

/// The zoom level a [cell] is closest to (for the `-` / `+` buttons).
int biomeMinimapLevel(SessionView view, double cell) {
  var best = 1;
  for (var z = 1; z <= GameSettings.minimapZooms; z++) {
    if (hudMinimapCell(view, z) <= cell + 1e-6) best = z;
  }
  return best;
}

/// El minimapa del HUD con el zoom [zoom]: 1 = el piso entero; 2 y 3 =
/// ventana de [kMinimapWindow] centrada en el jugador (exploration.md §
/// "HUD").
Minimap hudMinimap(SessionView view, SessionController controller,
    {int zoom = 1, double? cell}) {
  // Zoom 1: the whole floor, shrunk to fit the window (§ 11.3).
  final fit = hudMinimapCell(view, 1);
  cell ??= hudMinimapCell(view, zoom);
  return Minimap(
    key: const ValueKey('hud-minimap'),
    map: view.map,
    session: view.session,
    localId: view.localId,
    localX: controller.local.x,
    localY: controller.local.y,
    time: view.session.time,
    loot: minimapLootFor(view, controller),
    bounds: MapGame.currentFloor(view)?.bounds,
    entranceOpen: _entranceOpen(view, controller),
    fog: controller.fog,
    overworld: overworldOverlayFor(view, controller),
    dungeon: dungeonOverlayFor(view),
    exit: switch (MapGame.dungeonExitAt(view,
        freeMovement: controller.engine.freeMovement, run: controller.isRun)) {
      (final x, final y) => Offset(x, y),
      null => null,
    },
    cell: cell,
    view: cell <= fit + 1e-6
        ? null
        : Size(kMinimapWindow.width / cell, kMinimapWindow.height / cell),
  );
}

bool Function(int) _entranceOpen(
    SessionView view, SessionController controller) {
  final world =
      view.session.mode == SessionMode.lobby && view.map.entrances.isNotEmpty;
  final zones = world
      ? {for (final z in controller.zones) z.zone.index: z.open}
      : const <int, bool>{};
  return (z) => zones[z] ?? false;
}

/// Íconos de minimapa que pide el filtro (`Icono`), de lo visible.
List<MinimapLoot> minimapLootFor(
    SessionView view, SessionController controller) {
  final s = view.session;
  final me = s.players[view.localId];
  if (me == null) return const [];
  return [
    for (final g in s.groundFor(view.localId))
      if (controller.engine
              .lootVerdict(me.profile, g.drop, wants: controller.localWants)
          case FilterVerdict(visible: true, :final style)
          when style.icon != null)
        MinimapLoot(g.x, g.y, style.icon!),
  ];
}

/// El mapa en grande (tecla M; panel `WorldPanel.map`).
Widget fullMapPanel(SessionView view, SessionController controller,
    {bool reduceMotion = false, Strings? strings}) {
  final s = view.session;
  final m = s.mission;
  final str = strings ?? worldFallbackStrings();
  final name =
      WorldHud(view: view, controller: controller)._missionName(s, str);
  final overworld = overworldOverlayFor(view, controller);
  final biome = overworld == null
      ? null
      : kBiomes.where((b) => b.id == view.map.place).firstOrNull?.name;
  final title = biome ??
      (m == null || s.mode == SessionMode.lobby
          ? str.t('ui.missions.hud.world_map')
          : m.floors > 1
              ? floorLabelText(str, name, m.floor, m.floors)
              : name);
  return FullMap(
    key: const ValueKey('panel-map'),
    title: title,
    map: view.map,
    session: s,
    localId: view.localId,
    localX: controller.local.x,
    localY: controller.local.y,
    time: s.time,
    loot: minimapLootFor(view, controller),
    bounds: MapGame.currentFloor(view)?.bounds,
    entranceOpen: _entranceOpen(view, controller),
    fog: controller.fog,
    overworld: overworld,
    dungeon: overworld == null ? dungeonOverlayFor(view) : null,
    exit: MapGame.dungeonExitAt(view,
            freeMovement: controller.engine.freeMovement,
            run: controller.isRun) !=
        null,
    waystones: _seenWaystones(view, controller),
    destinations: controller.travelDestinations,
    originId: controller.travelOrigin?.id,
    onTravel: controller.travelTo,
    reduceMotion: reduceMotion,
    onClose: controller.closePanel,
  );
}

/// Piedras de paso descubiertas del piso actual (§ 11.7), activada o no.
List<(MapPoi, bool)> _seenWaystones(
    SessionView view, SessionController controller) {
  // Overworld: the activated ones and those in discovered ground (§ 11.4).
  if (overworldOverlayFor(view, controller) case final ow?) {
    return [
      for (final m in ow.marks)
        if (m.kind == OverworldMarkKind.waystone)
          if (controller.waystoneActive(m.index!) || ow.knownTile(m.x, m.y))
            (
              MapPoi(id: m.index!, kind: PoiKind.waystone, tx: m.x, ty: m.y),
              controller.waystoneActive(m.index!)
            ),
    ];
  }
  final m = view.session.mission;
  final f = MapGame.currentFloor(view);
  if (m == null || f == null || view.session.mode != SessionMode.field) {
    return const [];
  }
  return [
    for (final p in f.pois)
      if (p.kind == PoiKind.waystone && m.poiSeen.contains(p.id))
        (p, m.poiUsed.contains(p.id)),
  ];
}

/// Despliega / compacta las cajas del grupo del HUD y lo guarda (tecla H
/// o clic en una caja; docs/specs/exploration.md § "HUD").
void togglePartyBoxes(WidgetRef ref) {
  final s = ref.read(gameSettingsProvider);
  unawaited(ref
      .read(gameSettingsProvider.notifier)
      .update(s.copyWith(partyExpanded: !s.partyExpanded)));
}

/// Una caja del grupo que se puede tocar para desplegar / compactar.
class _Toggle extends StatelessWidget {
  const _Toggle(
      {super.key,
      required this.expanded,
      required this.onTap,
      required this.child});

  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: expanded
            ? context.t('ui.world.hud.party_compact')
            : context.t('ui.world.hud.party_expand'),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: child,
          ),
        ),
      );
}

/// Caja compacta de un miembro del grupo (v0.8.2): `Nombre Clase LvN`
/// con chips (K.O., `+N` puntos sin usar) y `[+]`, y debajo las barras
/// finas de HP y MP con sus números. Dos líneas de alto.
class CompactPlayerBox extends StatelessWidget {
  const CompactPlayerBox({
    super.key,
    required this.player,
    required this.local,
    required this.progression,
    this.width,
  });

  final SessionPlayer player;
  final bool local;
  final ProgressionRules progression;

  /// Fixed width; `null` = [PartyBox.compactWidthOf].
  final double? width;

  /// Text of the first line as laid out by the box (tight line height).
  static TextStyle _lineStyle() => TextStyle(
      fontFamily: RetroType.bodyFamily,
      letterSpacing: RetroType.letterSpacing,
      fontFamilyFallback: RetroType.bodyFallback,
      fontSize: RetroType.small,
      height: RetroType.lineTight);

  /// Name, ascension and class.
  static TextSpan _nameSpan(SessionPlayer p, ProgressionRules progression) {
    final prof = p.profile;
    final cls = progression.catalog.classes[prof.classId]?.name ?? prof.classId;
    final asc = ascensionFor(prof.classId, prof.ascension.id);
    return TextSpan(children: [
      TextSpan(
          text: retroText(p.name),
          style: const TextStyle(color: DsColors.textTitle)),
      if (asc != null)
        TextSpan(
            text: retroText(', ${asc.name}'),
            style: TextStyle(color: Color(asc.color))),
      TextSpan(
          text: retroText(' $cls'),
          style: const TextStyle(color: DsColors.textSecondary)),
    ]);
  }

  /// Level, status chips and `[+]`.
  static TextSpan _levelSpan(BuildContext context, SessionPlayer p) {
    final prof = p.profile;
    return TextSpan(children: [
      TextSpan(
          text: ' ${context.t('ui.world.hud.level', {'n': prof.level})}',
          style: const TextStyle(color: DsColors.textPrimary)),
      // Chips de estado: texto de color (sin caja: no agranda la línea).
      if (!p.alive)
        const TextSpan(
            text: ' K.O.', style: TextStyle(color: DsColors.danger)),
      if (prof.points > 0)
        TextSpan(
            text: ' +${prof.points}',
            style: const TextStyle(color: DsColors.reward)),
      const TextSpan(
          text: ' [+]', style: TextStyle(color: DsColors.textSecondary)),
    ]);
  }

  /// Width the box needs so its first line fits at full size (v0.49.22):
  /// never less than [PartyBox.compactWidthOf], at most twice it.
  static double naturalWidthOf(BuildContext context, SessionPlayer p,
      ProgressionRules progression) {
    final scaler = MediaQuery.textScalerOf(context);
    double measure(TextSpan span) {
      final tp = TextPainter(
          text: TextSpan(style: _lineStyle(), children: [span]),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1)
        ..layout();
      final w = tp.width;
      tp.dispose();
      return w;
    }

    // 6 + 6 of padding, 2 + 2 of border and air for the spacing the
    // laid-out line adds over a bare measure.
    final need = measure(_nameSpan(p, progression)) +
        measure(_levelSpan(context, p)) +
        40;
    final min = PartyBox.compactWidthOf(context);
    return need.clamp(min, min * 2);
  }

  /// Barra fina + `n/max` a la derecha; el número toma a lo sumo el 65 %
  /// (cifras grandes o texto ENORME: se recorta antes que desbordar).
  Widget _barWithValue(Widget bar, String value, Key key) => LayoutBuilder(
        builder: (context, c) => Row(
          children: [
            Expanded(child: bar),
            const SizedBox(width: 3),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth * 0.65),
              child: Text(value,
                  key: key,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = player;
    final prof = p.profile;
    final tight = TextStyle(height: RetroType.lineTight);
    return PartyBox(
      key: ValueKey('hud-compact-${p.id}'),
      local: local,
      knockedOut: !p.alive,
      width: width ?? PartyBox.compactWidthOf(context),
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
      children: [
        DefaultTextStyle.merge(
          style: tight,
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            return Row(
              children: [
                // Nombre (y ascensión) entero: se achica antes que cortarse.
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey('hud-name-${p.id}'),
                    child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      _nameSpan(p, progression),
                      maxLines: 1,
                      softWrap: false,
                    ),
                    ),
                  ),
                ),
                // Nivel, chips y `[+]`: a lo sumo el 60 % (se recorta antes
                // que desbordar con cifras o texto enormes).
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: w * 0.6),
                  child: Text.rich(
                    _levelSpan(context, p),
                    key: ValueKey('hud-level-${p.id}'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ],
            );
          }),
        ),
        DefaultTextStyle.merge(
          style: tight,
          child: Row(
            children: [
              Expanded(
                  child: _barWithValue(hpBar(p.hp, p.maxHp),
                      '${p.hp.ceil()}/${p.maxHp}', ValueKey('hud-hp-${p.id}'))),
              const SizedBox(width: 6),
              Expanded(
                  child: _barWithValue(
                      mpBar(p.mp, p.maxMp),
                      '${p.mp.floor()}/${p.maxMp}',
                      ValueKey('hud-mp-${p.id}'))),
            ],
          ),
        ),
        // XP: barra fina; el detalle (cuánto falta) al pasar el mouse.
        if (xpProgress(prof) case final x?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RetroTooltip(
              message: retroText(xpProgressText(prof, next: true)),
              child: RetroBar(
                  key: ValueKey('hud-compact-xp-${p.id}'),
                  value: x.value,
                  max: x.max,
                  height: 2,
                  color: x.mastery ? ProtoColors.violet : DsColors.reward),
            ),
          ),
      ],
    );
  }
}

/// Pliega / despliega la caja de objetivos y lo guarda (tecla O o clic en
/// la cabecera; docs/specs/exploration.md § "HUD").
void toggleObjectives(WidgetRef ref) {
  final s = ref.read(gameSettingsProvider);
  unawaited(ref
      .read(gameSettingsProvider.notifier)
      .update(s.copyWith(objectivesCollapsed: !s.objectivesCollapsed)));
}

/// Resumen de una línea de la caja plegada: `Piso 1/4 · Grupos 4/4 ·
/// Opcional 1/2` (y `★ JEFE` con la barrera abierta).
String objectivesSummaryText(MissionRun m, MapFloor? floor, [Strings? str]) {
  final s = str ?? worldFallbackStrings();
  final floors = m.floors > 1;
  final f = m.floor;
  final parts = <String>[];
  if (floors) {
    final goal = f < m.floorGoals.length ? m.floorGoals[f] : 0;
    parts
      ..add(s.t('ui.missions.hud.floor', {'floor': f + 1, 'floors': m.floors}))
      ..add('${objectiveShortText(s, ObjectiveKind.kills)} '
          '${m.floorKills(f).clamp(0, goal)}/$goal');
  }
  for (final o in m.objectives) {
    if (floors && o.kind == ObjectiveKind.kills) continue;
    parts.add('${objectiveShortText(s, o.kind)} '
        '${o.count.clamp(0, o.goal)}/${o.goal}');
  }
  if (optionalSummary(m, floor) case final opt?) parts.add(opt);
  if (m.open && (!floors || m.isLastFloor)) {
    parts.add(s.t('ui.missions.hud.boss_star'));
  }
  return parts.join(' · ');
}

/// Caja de objetivos (`drawObjectives`), plegable y compacta (v0.8.1).
class _Objectives extends StatelessWidget {
  const _Objectives({
    required this.mission,
    this.zoneName = '',
    this.floorLevel,
    this.floor,
    this.time = 0,
    this.collapsed = false,
    this.onToggle,
  });

  final MissionRun mission;

  /// Piso actual y reloj de la sala (exploración v0.6).
  final MapFloor? floor;
  final double time;

  /// Nombre de la zona (cabecera `<zona> · Piso N/F`).
  final String zoneName;

  /// Nivel de los enemigos del piso actual.
  final int? floorLevel;

  /// Plegada: una sola fila con el resumen y `[+]`.
  final bool collapsed;
  final VoidCallback? onToggle;

  /// Ancho máximo (base, crece con el tamaño del texto).
  static const maxWidth = 380.0;

  /// Plegada: más ancha, para que el resumen entre en una línea.
  static const collapsedMaxWidth = 520.0;

  @override
  Widget build(BuildContext context) {
    final str = worldStrings(context);
    final floors = mission.floors > 1;
    final f = mission.floor;
    final goal =
        floors && f < mission.floorGoals.length ? mission.floorGoals[f] : 0;
    final floorDone = floors && mission.floorKills(f) >= goal;
    final title = floors
        ? '${floorLabelText(str, zoneName, f, mission.floors)}'
            '${floorLevel == null ? '' : ' · Lv $floorLevel'}'
        : zoneName;
    final header = ActionLink(
      key: const ValueKey('hud-objectives-header'),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(bottom: kObjectiveLineGap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plegada, la cabecera ES el resumen (el nombre ya está en
            // la barra de misión).
            Flexible(
              child: collapsed
                  ? Text(retroText(objectivesSummaryText(mission, floor, str)),
                      key: const ValueKey('hud-objectives-summary'),
                      style: const TextStyle(color: DsColors.textPrimary))
                  : Text(retroText(title),
                      key: ValueKey(
                          floors ? 'hud-floor' : 'hud-objectives-title'),
                      style: const TextStyle(color: DsColors.textTitle)),
            ),
            SizedBox(width: DsSpace.sm),
            Text(collapsed ? '[+]' : '[-]',
                key: const ValueKey('hud-objectives-toggle'),
                style: const TextStyle(color: DsColors.textSecondary)),
          ],
        ),
      ),
    );
    // `drawObjectives`: caja `#000a` con borde `#5b74c9`.
    return Container(
      key: const ValueKey('hud-objectives'),
      constraints: BoxConstraints(
          maxWidth: RetroType.width(
              context, collapsed ? collapsedMaxWidth : maxWidth)),
      padding: EdgeInsets.fromLTRB(DsSpace.sm, 6, DsSpace.sm, 4),
      // Superficie sin borde (design_system.md § 2, principio 0).
      color: DsColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          if (!collapsed) ...[
            if (floors) ...[
              if (mission.isLastFloor)
                objectiveLine(str.t('ui.missions.hud.boss_floor'),
                    mark: '',
                    color: ProtoColors.crimson,
                    key: const ValueKey('hud-boss-floor')),
              objectiveLine(
                  str.t('ui.missions.hud.floor_groups',
                      {'n': '${mission.floorKills(f).clamp(0, goal)}/$goal'}),
                  done: floorDone),
              if (!mission.isLastFloor)
                mission.floorOpen(f)
                    ? objectiveLine(str.t('ui.missions.hud.stairs_open'),
                        mark: '>', color: ProtoColors.green)
                    : objectiveLine(str.t('ui.missions.hud.stairs_closed')),
            ],
            for (final o in mission.objectives)
              if (!floors || o.kind != ObjectiveKind.kills)
                objectiveLine(
                    '${objectiveLongText(str, o.kind)} '
                    '${o.count.clamp(0, o.goal)}/${o.goal}',
                    done: o.done),
            if (!floors || mission.isLastFloor)
              mission.open
                  ? objectiveLine(str.t('ui.missions.hud.go_boss'),
                      mark: '★', color: ProtoColors.gold)
                  : objectiveLine(str.t('ui.missions.hud.boss_locked')),
            ...explorationLines(mission, floor, time),
          ],
        ],
      ),
    );
  }
}

class _MessageLog extends StatelessWidget {
  const _MessageLog({required this.messages});

  final List<String> messages;

  static const lines = 5;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    final last = messages.length > lines
        ? messages.sublist(messages.length - lines)
        : messages;
    return Container(
      color: DsColors.surface,
      padding: EdgeInsets.all(DsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in last)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(retroText('» $m'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ProtoColors.green)),
            ),
        ],
      ),
    );
  }
}

/// Caja de un jugador (`.pbox` del prototipo, fuera de batalla; `hud()`
/// línea 1195): nombre, `Clase LvN` en `#9fb4ff`, arma en `#ff9f43` con
/// `+N pts` dorado, barras HP/MP, `XP · ₵` y pociones (`♥` verde, `✦`
/// celeste).
class _PlayerBox extends StatelessWidget {
  const _PlayerBox({
    required this.player,
    required this.local,
    required this.progression,
  });

  final SessionPlayer player;
  final bool local;
  final ProgressionRules progression;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final prof = p.profile;
    final cls = progression.catalog.classes[prof.classId]?.name ?? prof.classId;
    final weapon = prof.equipped == null
        ? '—'
        : progression.weaponDisplayName(prof, prof.equipped!);
    return PartyBox(
      local: local,
      knockedOut: !p.alive,
      children: [
        ProtoText(
            key: ValueKey('hud-name-${p.id}'),
            '${protoEsc(p.name)}'
            '${switch (ascensionFor(prof.classId, prof.ascension.id)) {
              final a? => ', ${protoColor(Color(a.color), protoEsc(a.name))}',
              null => '',
            }} '
            '<span class="k">$cls ${context.t('ui.world.hud.level', {
                  'n': prof.level
                })}</span>'),
        ProtoText(protoColor(
            ProtoColors.orange,
            '⚔ ${protoEsc(weapon)}'
            '${prof.points > 0 ? ' ${protoColor(ProtoColors.gold, context.t('ui.world.hud.points', {
                      'n': prof.points
                    }))}' : ''}')),
        hpBar(p.hp, p.maxHp),
        Text(context
            .t('ui.world.hud.hp_value', {'hp': p.hp.ceil(), 'max': p.maxHp})),
        mpBar(p.mp, p.maxMp),
        Text(context
            .t('ui.world.hud.mp_value', {'mp': p.mp.floor(), 'max': p.maxMp})),
        // Con nivel 50 la XP llena la Maestría (ecos_atlas.md § 6).
        if (prof.level >= ProgressionRules.maxLevel) ...[
          RetroBar(
              key: const ValueKey('hud-mastery-bar'),
              value: prof.mastery >= PlayerProfile.maxMastery ? 1 : prof.xp,
              max: prof.mastery >= PlayerProfile.maxMastery
                  ? 1
                  : ProgressionRules.masteryNeed(prof.mastery),
              height: 4,
              color: ProtoColors.violet),
          DsGoldText(
            key: const ValueKey('hud-mastery'),
            (prof.mastery >= PlayerProfile.maxMastery
                ? '${masteryText(prof)} · ₵${prof.credits}'
                : '${masteryText(prof)} · XP ${prof.xp}/'
                    '${ProgressionRules.masteryNeed(prof.mastery)} · '
                    '₵${prof.credits}'),
            style: const TextStyle(color: ProtoColors.violet),
          ),
        ] else ...[
          RetroBar(
              key: ValueKey('hud-xp-bar-${p.id}'),
              value: xpProgress(prof)!.value,
              max: xpProgress(prof)!.max,
              height: 4,
              color: ProtoColors.gold),
          Text(
            key: ValueKey('hud-xp-${p.id}'),
            retroText('${xpProgressText(prof)} · ₵${prof.credits}'),
            style: const TextStyle(color: DsColors.textSecondary),
          ),
        ],
        ProtoText(
          '${protoEsc(context.t('ui.world.hud.potions'))} ${protoColor(ProtoColors.green, '♥${prof.potions}')} '
          '${protoColor(ProtoColors.ice, '✦${prof.ethers}')}',
          style: const TextStyle(color: DsColors.textSecondary),
        ),
        // Comida activa (farming.md § 17).
        if (prof.life.farm.meal case final MealBuff b?)
          if (b.def case final MealDef d?)
            RetroTooltip(
              message: activeMealLines(context, b).map(retroText).join('<br>'),
              child: Text(
                key: ValueKey('hud-meal-${p.id}'),
                retroText(context.t('ui.world.hud.meal',
                    {'meal': d.text, 'n': b.left})),
                style: const TextStyle(color: DsColors.reward),
              ),
            ),
      ],
    );
  }
}

class _LevelUpBanner extends StatelessWidget {
  const _LevelUpBanner({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final waiting = session.playerList
        .where((p) => p.levelUpPending && p.profile.points > 0)
        .map((p) => p.name)
        .join(', ');
    return Positioned(
      left: 0,
      right: 0,
      top: 96,
      // Franja `#000c` a todo el ancho, como el canvas del prototipo.
      child: Container(
        color: ProtoColors.scrim(0.8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t('ui.world.hud.level_up'), style: DsText.title()),
            SizedBox(height: DsSpace.sm),
            Text(
                retroText(
                    context.t('ui.world.hud.waiting', {'names': waiting})),
                style: DsText.body(DsColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// Márgenes (izq, der) de la barra de herramienta: centrada en la
/// pantalla de ancho [w]. Solo si la columna de la derecha ([minR]) no
/// deja lugar se corre lo justo; el chat ([minL]) ya se angosta para no
/// empujarla (v0.25.9).
(double, double) toolSide(double w, double minL, double minR) {
  final c = (w - ToolHud.width) / 2;
  if (c >= minL && c >= minR) return (c, c);
  return (minL, minR);
}

/// Caja de un jugador que está en otro lugar (free_movement.md § 4):
/// atenuada, con su nombre, dónde está e IR CON (gris si no se puede).
class _AwayBox extends StatelessWidget {
  const _AwayBox(
      {super.key,
      required this.player,
      required this.width,
      this.height,
      this.onJoin,
      this.blocked});

  final AwayPlayer player;
  final double width;

  /// Alto fijo de la fila compacta (`null` = desplegadas).
  final double? height;
  final VoidCallback? onJoin;

  /// Why UNIRSE is off (grey button + tooltip), or `null`.
  final String? blocked;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: Opacity(
          opacity: 0.6,
          child: Container(
            color: DsColors.surface,
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
            child: Row(
              children: [
                // Nombre y lugar enteros: se achican antes que cortarse.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(retroText(player.name),
                            maxLines: 1,
                            softWrap: false,
                            style: DsText.body(DsColors.textPrimary)),
                        Text(retroText(player.where),
                            key: ValueKey('hud-away-where-${player.id}'),
                            maxLines: 1,
                            softWrap: false,
                            style: DsText.detail()),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: DsSpace.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: DsButton(
                      context.t('ui.world.hud.join', {'name': player.name}),
                      key: ValueKey('hud-join-${player.id}'),
                      size: DsButtonSize.compact,
                      tooltip: onJoin == null ? blocked : null,
                      onPressed: onJoin),
                ),
              ],
            ),
          ),
        ),
      );
}
