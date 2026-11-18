import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../game_engine/data/exploration_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/rules/exploration_rules.dart';

/// Líneas de la exploración en la caja de objetivos (worldgen.md § 11.7 y
/// § 11.8): resumen del piso, bendición, Viento del Eco y misiones
/// opcionales con su progreso.
List<Widget> explorationLines(MissionRun m, MapFloor? f, double time) {
  if (f == null) return const [];
  Widget line(String text, Color color, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(retroText(text), style: TextStyle(color: color)),
      );
  final out = <Widget>[
    line(ExplorationRules.floorSummary(m, f).text, ProtoColors.ink,
        key: const ValueKey('hud-floor-summary')),
  ];
  final b = m.blessing;
  if (b != null) {
    out.add(line('✦ ${kBlessings[b]!.name}', const Color(0xFF5AE6D2),
        key: const ValueKey('hud-blessing')));
  }
  if (time < m.windUntil) {
    out.add(line('» Viento del Eco ${(m.windUntil - time).ceil()} s',
        const Color(0xFFBFEFFF),
        key: const ValueKey('hud-wind')));
  }
  for (final q in f.quests) {
    final done = m.questsDone.contains(q.id);
    final failed = m.questsFailed.contains(q.id);
    final text = failed
        ? 'x Opcional: ${questText(q.kind)}'
        : '${done ? '>' : '•'} Opcional: '
            '${ExplorationRules.questLine(q, m, f)}';
    out.add(line(
        text,
        failed
            ? const Color(0xFF9AA0AC)
            : done
                ? ProtoColors.green
                : ProtoColors.gold,
        key: ValueKey('hud-quest-${q.id}')));
  }
  return out;
}
