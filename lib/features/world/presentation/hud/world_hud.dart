import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/party_box.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/proto_markup.dart';
import '../../../../app/theme/retro_panel.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/rules/progression_rules.dart';
import '../../../../game_engine/rules/world_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../../../missions/presentation/vote_panel.dart';
import 'chat_box.dart';
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
    this.chatFocus,
    this.onChatDone,
  });

  final SessionView view;
  final SessionController controller;

  /// Volver al título (solo en el lobby).
  final VoidCallback? onExit;

  /// Foco del campo de chat (sin él no se muestra el campo).
  final FocusNode? chatFocus;

  /// Se terminó de escribir: el foco vuelve al juego.
  final VoidCallback? onChatDone;

  static const _gap = 16.0;

  @override
  Widget build(BuildContext context) {
    final s = view.session;
    final field = s.mode == SessionMode.field;
    final showMinimap = (field || s.mode == SessionMode.levelUp) &&
        !view.map.lobby &&
        s.mission != null;
    final small = Theme.of(context).textTheme.bodySmall!;
    final players = s.playerList;
    final partyWidth = players.length * (PartyBox.defaultWidth + 6);
    return LayoutBuilder(builder: (context, box) {
      final chatWidth =
          (box.maxWidth - partyWidth - _gap * 3).clamp(240.0, 520.0);
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
                  missionName: s.mission == null
                      ? ''
                      : controller.engine.catalog
                              .mission(s.mission!.missionId)
                              ?.name ??
                          s.mission!.missionId,
                ),
              ),
            ),
            if (s.mode == SessionMode.lobby && onExit != null)
              Positioned(
                top: _gap,
                left: _gap,
                child: ElevatedButton(
                  style: RetroTheme.compactButton(),
                  onPressed: onExit,
                  child: const Text('< TITULO'),
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
                child: _Objectives(mission: s.mission!),
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
                  ),
                ),
              ),
            Positioned(
              left: _gap,
              bottom: _gap,
              width: chatWidth,
              child: chatFocus == null
                  ? _MessageLog(messages: view.messages)
                  : ChatBox(
                      lines: view.chat,
                      focusNode: chatFocus!,
                      onSend: controller.sendChat,
                      onDone: onChatDone ?? () {},
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, p) in players.indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _PlayerBox(
                      player: p,
                      local: p.id == view.localId,
                      progression: controller.engine.progression,
                    ),
                  ],
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
                    for (final line in _banners(s))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _CanvasLabel(line.$1, color: line.$2),
                      ),
                    // `[E] ...`: caja `#000a` y texto dorado (sello violeta).
                    if (view.prompt case final prompt?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _CanvasLabel(prompt.label,
                            fontSize: 16,
                            color: prompt == WorldPrompt.seal
                                ? ProtoColors.violet
                                : ProtoColors.gold),
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

  /// Votación en curso (`renderVote`), solo en el lobby.
  Widget? _voteBox(GameSession s) {
    final v = s.vote;
    if (s.mode != SessionMode.lobby || v == null) return null;
    final m = controller.engine.catalog.mission(v.missionId);
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

  /// Avisos de una línea: barrera abierta.
  List<(String, Color)> _banners(GameSession s) {
    final out = <(String, Color)>[];
    final boss = view.map.boss;
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
      text = '$missionName · $goals · ${clockText(m.elapsed)}';
    } else if (s.mode == SessionMode.prep) {
      text = 'Preparación de misión';
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
  const _CanvasLabel(this.text, {required this.color, this.fontSize = 8});

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xAA000000),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(retroText(text),
            style: TextStyle(fontSize: fontSize, color: color)),
      );
}

class _Objectives extends StatelessWidget {
  const _Objectives({required this.mission});

  final MissionRun mission;

  @override
  Widget build(BuildContext context) {
    Widget line(String text, bool ok) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(retroText(text),
              style:
                  TextStyle(color: ok ? ProtoColors.green : ProtoColors.ink)),
        );
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
          for (final o in mission.objectives)
            line(
                '${o.done ? '> ' : '· '}${o.kind.label} '
                '${o.count.clamp(0, o.goal)}/${o.goal}',
                o.done),
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
        ProtoText('${protoEsc(p.name)} '
            '<span class="k">$cls Lv${prof.level}</span>'),
        ProtoText(protoColor(
            ProtoColors.orange,
            '⚔ ${protoEsc(weapon)}'
            '${prof.points > 0 ? ' ${protoColor(ProtoColors.gold, '+${prof.points} pts')}' : ''}')),
        hpBar(p.hp, p.maxHp),
        Text('HP ${p.hp.ceil()}/${p.maxHp}'),
        mpBar(p.mp, p.maxMp),
        Text('MP ${p.mp.floor()}/${p.maxMp}'),
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
                style: TextStyle(fontSize: 16, color: ProtoColors.gold)),
            const SizedBox(height: 8),
            Text(retroText('Esperando a: $waiting'),
                style: const TextStyle(color: ProtoColors.white)),
          ],
        ),
      ),
    );
  }
}
