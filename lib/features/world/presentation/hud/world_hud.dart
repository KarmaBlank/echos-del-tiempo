import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/retro_bar.dart';
import '../../../../app/theme/retro_panel.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/rules/progression_rules.dart';
import '../../../../game_engine/rules/world_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
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
  });

  final SessionView view;
  final SessionController controller;

  /// Volver al título (solo en el lobby).
  final VoidCallback? onExit;

  static const _gap = 16.0;

  @override
  Widget build(BuildContext context) {
    final s = view.session;
    final field = s.mode == SessionMode.field;
    final showMinimap = (field || s.mode == SessionMode.levelUp) &&
        !view.map.lobby &&
        s.mission != null;
    final small = Theme.of(context).textTheme.bodySmall!;
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
            width: 520,
            child: _MessageLog(messages: view.messages),
          ),
          Positioned(
            right: _gap,
            bottom: _gap,
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in s.playerList)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _PlayerBox(
                      player: p,
                      local: p.id == view.localId,
                      progression: controller.engine.progression,
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
                  for (final line in _banners(s))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: RetroPanel(
                        padding: const EdgeInsets.all(8),
                        child: Text(retroText(line.$1),
                            style: TextStyle(color: line.$2)),
                      ),
                    ),
                  if (view.prompt case final prompt?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: RetroPanel(
                        selected: true,
                        padding: const EdgeInsets.all(8),
                        child: Text(prompt.label,
                            style: const TextStyle(
                                fontSize: 16, color: RetroPalette.gold)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (s.mode == SessionMode.levelUp) _LevelUpBanner(session: s),
        ],
      ),
    );
  }

  /// Avisos de una línea: votación y barrera abierta.
  List<(String, Color)> _banners(GameSession s) {
    final out = <(String, Color)>[];
    final v = s.vote;
    if (s.mode == SessionMode.lobby && v != null && !v.yes.contains(view.localId)) {
      final m = controller.engine.catalog.mission(v.missionId);
      out.add(('Votación: ${m?.name ?? v.missionId} · [Y] sí / [N] no',
          RetroPalette.gold));
    }
    final boss = view.map.boss;
    if (s.mode == SessionMode.field &&
        s.gateOpen &&
        boss != null &&
        WorldRules.distance(
                controller.local.x, controller.local.y, boss.x, boss.y) >
            140) {
      out.add(('La barrera se abrió → busca al JEFE (★ en el minimapa)',
          RetroPalette.gold));
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
    if (m != null && s.mode != SessionMode.lobby && s.mode != SessionMode.prep) {
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
    return RetroPanel(
      padding: const EdgeInsets.all(8),
      child: Text(retroText(text)),
    );
  }
}

class _Objectives extends StatelessWidget {
  const _Objectives({required this.mission});

  final MissionRun mission;

  @override
  Widget build(BuildContext context) {
    Widget line(String text, bool ok) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(retroText(text),
              style: TextStyle(color: ok ? RetroPalette.green : RetroPalette.ink)),
        );
    return RetroPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in mission.objectives)
            line('${o.done ? '> ' : '· '}${o.kind.label} '
                '${o.count.clamp(0, o.goal)}/${o.goal}', o.done),
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
              child: Text(retroText(m),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: RetroPalette.muted)),
            ),
        ],
      ),
    );
  }
}

/// Caja de un jugador (`.pbox` del prototipo, fuera de batalla).
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
        ? '-'
        : progression.weaponDisplayName(prof, prof.equipped!);
    return RetroPanel(
      selected: local,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(retroText('${p.name}  $cls Lv${prof.level}'),
              style: TextStyle(
                  color: p.alive ? RetroPalette.ink : RetroPalette.red)),
          const SizedBox(height: 4),
          Text(
            retroText('$weapon${prof.points > 0 ? '  +${prof.points} pts' : ''}'),
            style: const TextStyle(color: RetroPalette.gold),
          ),
          const SizedBox(height: 6),
          RetroBar(
              value: p.hp, max: p.maxHp, color: RetroPalette.green, height: 10),
          const SizedBox(height: 2),
          Text('HP ${p.hp.ceil()}/${p.maxHp}'),
          const SizedBox(height: 4),
          RetroBar(
              value: p.mp, max: p.maxMp, color: RetroPalette.muted, height: 10),
          const SizedBox(height: 2),
          Text('MP ${p.mp.floor()}/${p.maxMp}'),
          const SizedBox(height: 4),
          Text(
            retroText('XP ${prof.xp}/${ProgressionRules.xpNeed(prof.level)} · '
                '₵${prof.credits} · Poc. ${prof.potions} · Éter ${prof.ethers}'),
            style: const TextStyle(color: RetroPalette.muted),
          ),
        ],
      ),
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
      child: Center(
        child: RetroPanel(
          selected: true,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¡SUBIDA DE NIVEL!',
                  style: TextStyle(fontSize: 16, color: RetroPalette.gold)),
              const SizedBox(height: 8),
              Text(retroText('Esperando a: $waiting')),
            ],
          ),
        ),
      ),
    );
  }
}
