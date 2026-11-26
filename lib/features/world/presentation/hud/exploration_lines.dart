import 'package:material_ui/material_ui.dart';

import '../../../../app/design/ds_tokens.dart';
import '../../../../app/theme/map_palette.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../game_engine/data/exploration_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/rules/exploration_rules.dart';
import '../world_strings.dart';

/// Separación entre líneas de la caja de objetivos (compacta, v0.8.1).
const kObjectiveLineGap = 2.0;

/// Una línea de la caja de objetivos: marca + texto. Cumplida: `>` en
/// `green` y el texto atenuado; si no, la marca y el texto en [color].
Widget objectiveLine(String text,
    {bool done = false, String mark = '•', Color? color, Key? key}) {
  final c = color ?? ProtoColors.ink;
  return Padding(
    key: key,
    padding: const EdgeInsets.only(bottom: kObjectiveLineGap),
    child: Text.rich(TextSpan(children: [
      TextSpan(
          text: done ? '> ' : (mark.isEmpty ? '' : '$mark '),
          style: TextStyle(color: done ? ProtoColors.green : c)),
      TextSpan(
          text: retroText(text),
          style: TextStyle(color: done ? ProtoColors.dim : c)),
    ])),
  );
}

/// Líneas de la exploración en la caja de objetivos (worldgen.md § 11.7 y
/// § 11.8): resumen del piso, bendición, Viento del Eco y las misiones
/// opcionales bajo la sub-cabecera `Opcional` con su progreso.
List<Widget> explorationLines(MissionRun m, MapFloor? f, double time) {
  if (f == null) return const [];
  final out = <Widget>[
    objectiveLine(ExplorationRules.floorSummary(m, f).text,
        mark: '', key: const ValueKey('hud-floor-summary')),
  ];
  final b = m.blessing;
  if (b != null) {
    out.add(objectiveLine('✦ ${kBlessings[b]!.name}',
        mark: '',
        color: MapPalette.mark(MapMark.shrine),
        key: const ValueKey('hud-blessing')));
  }
  if (time < m.windUntil) {
    out.add(objectiveLine('» Viento del Eco ${(m.windUntil - time).ceil()} s',
        mark: '',
        color: MapPalette.mark(MapMark.wind),
        key: const ValueKey('hud-wind')));
  }
  if (f.quests.isNotEmpty) {
    out.add(Padding(
      key: const ValueKey('hud-optional-header'),
      padding: const EdgeInsets.only(top: 2, bottom: kObjectiveLineGap),
      child: Builder(
          builder: (context) => Text(
              retroText(context.t('ui.world.hud.optional')),
              style: const TextStyle(color: DsColors.textMuted))),
    ));
  }
  for (final q in f.quests) {
    final done = m.questsDone.contains(q.id);
    final failed = m.questsFailed.contains(q.id);
    out.add(Padding(
      padding: const EdgeInsets.only(left: 8),
      child: objectiveLine(
          failed ? questText(q.kind) : ExplorationRules.questLine(q, m, f),
          done: done && !failed,
          mark: failed ? 'x' : '•',
          color: failed ? ProtoColors.dim : ProtoColors.gold,
          key: ValueKey('hud-quest-${q.id}')),
    ));
  }
  return out;
}

/// `Opcional hechas/total` del piso, o `null` si no tiene opcionales.
String? optionalSummary(MissionRun m, MapFloor? f) {
  if (f == null || f.quests.isEmpty) return null;
  final done = f.quests.where((q) => m.questsDone.contains(q.id)).length;
  return 'Opcional $done/${f.quests.length}';
}
