import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/party_box.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/proto_markup.dart';
import '../../../../app/theme/retro_bar.dart';
import '../../../../app/theme/retro_panel.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
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
import 'chat_box.dart';
import 'loot_feed.dart';
import 'minimap.dart';

/// `m:ss` con minutos de dos dígitos (`mm:ss` del HUD del prototipo).
String clockText(double seconds) {
  final s = seconds.floor();
  return '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';
}

/// HUD del mapa como overlays Flutter (`hud()`, `drawObjectives`,
/// `drawMinimap` y los avisos de `render`). Ver
/// docs/specs/exploration.md § "HUD".
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

  @override
  Widget build(BuildContext context) {
    final s = view.session;
    final field = s.mode == SessionMode.field;
    final world = s.mode == SessionMode.lobby && view.map.entrances.isNotEmpty;
    final showMinimap = world ||
        ((field || s.mode == SessionMode.levelUp) &&
            !view.map.lobby &&
            s.mission != null);
    final zones = world
        ? {for (final z in controller.zones) z.zone.index: z.open}
        : const <int, bool>{};
    final small = Theme.of(context).textTheme.bodySmall!;
    final players = s.playerList;
    final boxW = PartyBox.widthOf(context);
    return LayoutBuilder(builder: (context, box) {
      // Con texto grande las cajas del grupo pasan a dos filas antes que
      // pisar el chat (mínimo 240 px de chat).
      final chatMin = RetroType.width(context, 240);
      final partyRoom =
          (box.maxWidth - chatMin - _gap * 3).clamp(boxW, double.infinity);
      final perRow = ((partyRoom + 6) / (boxW + 6))
          .floor()
          .clamp(1, players.isEmpty ? 1 : players.length);
      final partyWidth = perRow * (boxW + 6);
      final chatWidth = (box.maxWidth - partyWidth - _gap * 3)
          .clamp(chatMin, RetroType.width(context, 520));
      return DefaultTextStyle.merge(
        style: small,
        child: Stack(
          children: [
            Positioned(
              top: _gap,
              left: 0,
              right: 0,
              child: Center(
                child: _MissionBar(
                  view: view,
                  missionName: _missionName(s),
                ),
              ),
            ),
            // `< TITULO` (solo en el lobby) y `≡ MENÚ` (siempre): la pausa
            // con sonido, pantalla, juego, controles y salidas.
            Positioned(
              top: _gap,
              left: _gap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.mode == SessionMode.lobby && onExit != null) ...[
                    ElevatedButton(
                      style: RetroTheme.compactButton(),
                      onPressed: onExit,
                      child: const Text('< TITULO'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onMenu != null) PauseMenuButton(onPressed: onMenu!),
                ],
              ),
            ),
            // `Sala: CODIGO [Copiar]` del prototipo (HTML línea 87).
            if (view.roomCode case final code?)
              Positioned(
                top: _gap,
                right: _gap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sala: $code',
                        key: const ValueKey('hud-room-code'),
                        style: const TextStyle(color: RetroPalette.gold)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: RetroTheme.compactButton(),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: code)),
                      child: const Text('COPIAR'),
                    ),
                  ],
                ),
              ),
            if (field && s.mission != null)
              Positioned(
                top: _gap + 48,
                left: _gap,
                child: _Objectives(
                    mission: s.mission!,
                    zoneName: _missionName(s),
                    floorLevel: MapGame.currentFloor(view)?.level),
              ),
            if (showMinimap)
              Positioned(
                top: _gap + 48,
                right: _gap,
                child: RetroPanel(
                  padding: const EdgeInsets.all(4),
                  child: Minimap(
                    map: view.map,
                    session: s,
                    localId: view.localId,
                    localX: controller.local.x,
                    localY: controller.local.y,
                    time: s.time,
                    loot: _minimapLoot(s),
                    bounds: MapGame.currentFloor(view)?.bounds,
                    entranceOpen: (z) => zones[z] ?? false,
                  ),
                ),
              ),
            Positioned(
              left: _gap,
              bottom: _gap,
              width: chatWidth,
              child: Column(
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
                      : ChatBox(
                          lines: view.chat,
                          focusNode: chatFocus!,
                          onSend: controller.sendChat,
                          onDone: onChatDone ?? () {},
                        ),
                ],
              ),
            ),
            if (_voteBox(s) case final vote?)
              Positioned(
                top: _gap + 48,
                left: 0,
                right: 0,
                child: Center(child: vote),
              ),
            // `#party`: una fila de `.pbox`.
            Positioned(
              right: _gap,
              bottom: _gap,
              child: SizedBox(
                width: partyWidth,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  verticalDirection: VerticalDirection.up,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in players)
                      _PlayerBox(
                        player: p,
                        local: p.id == view.localId,
                        progression: controller.engine.progression,
                      ),
                  ],
                ),
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
                    Consumer(
                      builder: (context, ref, _) =>
                          BuildToasts(feed: ref.watch(buildFeedProvider)),
                    ),
                    Consumer(
                      builder: (context, ref, _) =>
                          LootToasts(feed: ref.watch(lootFeedProvider)),
                    ),
                    for (final line in _banners(s))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _CanvasLabel(line.$1, color: line.$2),
                      ),
                    // `[E] ...`: caja `#000a` y texto dorado (sello violeta).
                    if (view.promptLabel case final label?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _CanvasLabel(label,
                            key: const ValueKey('hud-prompt'),
                            fontSize: label.startsWith('[E]')
                                ? RetroType.title
                                : RetroType.small,
                            color: view.prompt == WorldPrompt.seal
                                ? ProtoColors.violet
                                : label.startsWith('[E]')
                                    ? ProtoColors.gold
                                    : ProtoColors.sky),
                      )
                    else if (_pickPrompt(s) case final text?)
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

  /// Nombre de la misión en curso: la zona si es de zona.
  String _missionName(GameSession s) {
    final m = s.mission;
    if (m == null) return '';
    final cat = controller.engine.catalog;
    // Eco: `Eco T7 · Grieta Ígnea` (docs/specs/ecos_atlas.md § 4).
    final eco = s.eco;
    if (eco != null && m.missionId == 'eco') {
      return 'Eco T${eco.tier} · ${cat.zone(eco.zone)?.name ?? ''}';
    }
    // Prueba del Tiempo (docs/specs/ascension.md § 1).
    final trial = trialDef(s.trial);
    if (trial != null && m.missionId == 'trial') {
      return 'Prueba del Tiempo ${trial.roman}';
    }
    return cat.zone(m.zone)?.name ??
        cat.mission(m.missionId)?.name ??
        m.missionId;
  }

  /// Lo que el jugador local ve del piso (con Alt, también lo oculto).
  List<LootOnFloor> _floor(GameSession s) {
    final me = s.players[view.localId];
    if (me == null ||
        (s.mode != SessionMode.field && s.mode != SessionMode.lobby)) {
      return const [];
    }
    return visibleLoot(
        s, view.localId, (d) => controller.engine.lootVerdict(me.profile, d),
        showAll: MapGame.altHeld());
  }

  /// `[E] Recoger <objeto>` a <= 24 px de algo dibujado (sin otra
  /// interacción a mano; ver `MapGame.tryPickUp`).
  String? _pickPrompt(GameSession s) {
    if (view.panel != null) return null;
    final l =
        nearestPickable(_floor(s), controller.local.x, controller.local.y);
    if (l == null) return null;
    return '[E] Recoger ${MapGame.lootName(controller, l.ground.drop)}';
  }

  /// Íconos de minimapa que pide el filtro (`Icono`), de lo visible.
  List<MinimapLoot> _minimapLoot(GameSession s) {
    final me = s.players[view.localId];
    if (me == null) return const [];
    return [
      for (final g in s.groundFor(view.localId))
        if (controller.engine.lootVerdict(me.profile, g.drop)
            case FilterVerdict(visible: true, :final style)
            when style.icon != null)
          MinimapLoot(g.x, g.y, style.icon!),
    ];
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
  List<(String, Color)> _banners(GameSession s) {
    final out = <(String, Color)>[];
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
        out.add((
          'La escalera se abrió → bajá al piso ${m.floor + 2}',
          ProtoColors.gold
        ));
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
      out.add((
        'La barrera se abrió → busca al JEFE (★ en el minimapa)',
        ProtoColors.gold
      ));
    }
    return out;
  }
}

class _MissionBar extends StatelessWidget {
  const _MissionBar({required this.view, required this.missionName});

  final SessionView view;
  final String missionName;

  @override
  Widget build(BuildContext context) {
    final s = view.session;
    final m = s.mission;
    final String text;
    if (m != null &&
        s.mode != SessionMode.lobby &&
        s.mode != SessionMode.prep) {
      final goals = m.open
          ? '¡Derrota al jefe!'
          : m.objectives
              .map((o) =>
                  '${o.kind.label.split(' ').first} ${o.count.clamp(0, o.goal)}/${o.goal}')
              .join(' · ');
      final name = m.floors > 1
          ? floorLabelText(missionName, m.floor, m.floors)
          : missionName;
      text = '$name · $goals · ${clockText(m.elapsed)}';
    } else if (s.mode == SessionMode.prep) {
      text = 'Preparación de misión';
    } else if (view.map.entrances.isNotEmpty) {
      text = 'Lobby · Mostrador [E] · Armería [E] · Zonas: puertas [E] · '
          'Personaje [C]';
    } else {
      text = 'Lobby · Mostrador [E] · Armería [E] · Personaje [C]';
    }
    // `#mission`: verde `#7bed9f`.
    return RetroPanel(
      padding: const EdgeInsets.all(8),
      child: Text(retroText(text),
          style: const TextStyle(color: ProtoColors.green)),
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
        color: const Color(0xAA000000),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(retroText(text),
            style: RetroType.style(fontSize, color: color)),
      );
}

class _Objectives extends StatelessWidget {
  const _Objectives({
    required this.mission,
    this.zoneName = '',
    this.floorLevel,
  });

  final MissionRun mission;

  /// Nombre de la zona (cabecera `<zona> · Piso N/F`).
  final String zoneName;

  /// Nivel de los enemigos del piso actual.
  final int? floorLevel;

  @override
  Widget build(BuildContext context) {
    Widget line(String text, bool ok) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(retroText(text),
              style:
                  TextStyle(color: ok ? ProtoColors.green : ProtoColors.ink)),
        );
    final floors = mission.floors > 1;
    final f = mission.floor;
    final goal =
        floors && f < mission.floorGoals.length ? mission.floorGoals[f] : 0;
    final floorDone = floors && mission.floorKills(f) >= goal;
    // `drawObjectives`: caja `#000a` con borde `#5b74c9`.
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        border: Border.all(color: ProtoColors.buttonBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (floors) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  retroText('${floorLabelText(zoneName, f, mission.floors)}'
                      '${floorLevel == null ? '' : ' · Lv $floorLevel'}'),
                  key: const ValueKey('hud-floor'),
                  style: const TextStyle(color: ProtoColors.gold)),
            ),
            if (mission.isLastFloor)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(retroText('¡Piso del JEFE!'),
                    key: const ValueKey('hud-boss-floor'),
                    style: const TextStyle(color: ProtoColors.crimson)),
              ),
            line(
                '${floorDone ? '> ' : '· '}Grupos del piso '
                '${mission.floorKills(f).clamp(0, goal)}/$goal',
                floorDone),
            if (!mission.isLastFloor)
              line(
                  mission.floorOpen(f)
                      ? '> Escalera abierta: bajá [E]'
                      : 'Escalera: despejá el piso',
                  mission.floorOpen(f)),
          ],
          for (final o in mission.objectives)
            if (!floors || o.kind != ObjectiveKind.kills)
              line(
                  '${o.done ? '> ' : '· '}${o.kind.label} '
                  '${o.count.clamp(0, o.goal)}/${o.goal}',
                  o.done),
          if (!floors || mission.isLastFloor)
            line(
                mission.open
                    ? '★ ¡Ve por el JEFE!'
                    : 'Jefe: completa los objetivos',
                mission.open),
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
    return RetroPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in last)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(retroText('» $m'),
                  maxLines: 2,
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
            '<span class="k">$cls Lv${prof.level}</span>'),
        ProtoText(protoColor(
            ProtoColors.orange,
            '⚔ ${protoEsc(weapon)}'
            '${prof.points > 0 ? ' ${protoColor(ProtoColors.gold, '+${prof.points} pts')}' : ''}')),
        hpBar(p.hp, p.maxHp),
        Text('HP ${p.hp.ceil()}/${p.maxHp}'),
        mpBar(p.mp, p.maxMp),
        Text('MP ${p.mp.floor()}/${p.maxMp}'),
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
          Text(
            key: const ValueKey('hud-mastery'),
            retroText(prof.mastery >= PlayerProfile.maxMastery
                ? '${masteryText(prof)} · ₵${prof.credits}'
                : '${masteryText(prof)} · XP ${prof.xp}/'
                    '${ProgressionRules.masteryNeed(prof.mastery)} · '
                    '₵${prof.credits}'),
            style: const TextStyle(color: ProtoColors.violet),
          ),
        ] else
          Text(
            retroText('XP ${prof.xp}/${ProgressionRules.xpNeed(prof.level)} · '
                '₵${prof.credits}'),
            style: const TextStyle(color: ProtoColors.dim),
          ),
        ProtoText(
          'Pociones: ${protoColor(ProtoColors.green, '♥${prof.potions}')} '
          '${protoColor(ProtoColors.ice, '✦${prof.ethers}')}',
          style: const TextStyle(color: ProtoColors.dim),
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
        color: const Color(0xCC000000),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¡SUBIDA DE NIVEL!',
                style: TextStyle(
                    fontFamily: RetroType.pixelFamily,
                    fontSize: 16,
                    color: ProtoColors.gold)),
            const SizedBox(height: 8),
            Text(retroText('Esperando a: $waiting'),
                style: const TextStyle(color: ProtoColors.white)),
          ],
        ),
      ),
    );
  }
}
