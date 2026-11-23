import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../game_engine/models/run_state.dart';
import '../../../game_engine/rules/run_tuning.dart';
import '../../../core/i18n/i18n_providers.dart';

/// Color de cada tipo de nodo (siempre acompañado de su letra, no solo el
/// color).
Color runNodeColor(RunNodeType t) => switch (t) {
      RunNodeType.combate => ProtoColors.common,
      RunNodeType.elite => ProtoColors.orange,
      RunNodeType.jefe => ProtoColors.red,
      RunNodeType.tienda => ProtoColors.gold,
      RunNodeType.armeria => ProtoColors.ice,
      RunNodeType.descanso => ProtoColors.green,
    };

/// Letra del nodo en el mapa.
String runNodeLetter(Strings s, RunNodeType t) =>
    s.t('ui.run.node.${t.name}.letter');

/// Name of the node type (`COMBATE`, `TIENDA`...).
String runNodeLabel(Strings s, RunNodeType t) =>
    s.t('ui.run.node.${t.name}.label');

/// Qué hace cada tipo de nodo (tooltip del mapa y de la leyenda).
String runNodeHelp(Strings s, RunNodeType t) => s.t(
    'ui.run.node.${t.name}.help', {'pct': (RunTuning.restHeal * 100).round()});

/// Tooltip de un tipo de nodo (molécula).
Widget runNodeTip(Strings s, RunNodeType t, {String? extra}) => DsTooltipCard(
      title: runNodeLabel(s, t),
      titleColor: runNodeColor(t),
      children: [
        Text(runNodeHelp(s, t)),
        if (extra != null) Text(extra, style: DsText.detail()),
      ],
    );

/// Un nodo del mapa (átomo): cuadrado con la letra del tipo. [reachable]
/// lo resalta y lo hace votable; [current] es donde está el grupo;
/// [mine] es el voto propio.
class RunNodeTile extends ConsumerWidget {
  const RunNodeTile({
    super.key,
    required this.type,
    this.size = 30,
    this.reachable = false,
    this.current = false,
    this.mine = false,
    this.onTap,
  });

  final RunNodeType type;
  final double size;
  final bool reachable;
  final bool current;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = runNodeColor(type);
    final dim = !reachable && !current;
    Widget box(bool hot) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: current
                ? c
                : hot
                    ? DsColors.hover
                    : DsColors.surfaceSunken,
            border: Border.all(
              color: mine
                  ? DsColors.selected
                  : reachable
                      ? c
                      : DsColors.border,
              width: mine || reachable ? 3 : 1,
            ),
          ),
          child: Text(
            runNodeLetter(ref.strings, type),
            style: DsText.subtitle(current
                ? ProtoColors.bg
                : dim
                    ? DsColors.textDisabled
                    : c),
          ),
        );
    final tip = runNodeTip(ref.strings, type,
        extra: current
            ? ref.t('ui.run.map.group_here')
            : reachable
                ? ref.t('ui.run.map.click_to_vote')
                : null);
    if (onTap == null) return DsTooltip(card: tip, child: box(false));
    return DsTooltip(
        card: tip,
        child: DsPressable(onTap: onTap, builder: (_, s) => box(s.hot)));
  }
}

/// El mapa del piso (organismo): capas de izquierda a derecha, las 3
/// líneas de arriba a abajo, aristas entre capas. Los votos de todos se
/// ven como iniciales debajo de cada nodo.
class RunMapView extends StatelessWidget {
  const RunMapView({
    super.key,
    required this.floor,
    required this.current,
    required this.reachable,
    required this.votes,
    required this.myVote,
    this.onVote,
  });

  final RunFloor floor;
  final int? current;
  final Set<int> reachable;

  /// Nodo → iniciales de quienes lo votaron.
  final Map<int, List<String>> votes;
  final int? myVote;
  final ValueChanged<int>? onVote;

  static const tile = 30.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final layers = floor.layers;
      final w = box.maxWidth, h = box.maxHeight;
      final dx = (w - tile * 2) / layers;
      final dy = (h - tile * 2) / 3;
      Offset at(RunNode n) => Offset(
            tile + dx * (n.layer + 0.5) - tile / 2,
            tile + dy * (n.x + 0.5) - tile / 2,
          );
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _EdgesPainter(floor, at, tile, current),
            ),
          ),
          for (final n in floor.nodes)
            Positioned(
              left: at(n).dx,
              top: at(n).dy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RunNodeTile(
                    key: ValueKey('run-node-${n.id}'),
                    type: n.type,
                    size: tile,
                    reachable: reachable.contains(n.id),
                    current: n.id == current,
                    mine: n.id == myVote,
                    onTap: reachable.contains(n.id) && onVote != null
                        ? () => onVote!(n.id)
                        : null,
                  ),
                  if (votes[n.id] case final v? when v.isNotEmpty)
                    Text(v.join(' '),
                        style: DsText.detail(DsColors.selected)),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _EdgesPainter extends CustomPainter {
  _EdgesPainter(this.floor, this.at, this.tile, this.current);
  final RunFloor floor;
  final Offset Function(RunNode) at;
  final double tile;
  final int? current;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()
      ..color = DsColors.border
      ..strokeWidth = 2;
    final hot = Paint()
      ..color = DsColors.selected
      ..strokeWidth = 3;
    final half = Offset(tile / 2, tile / 2);
    for (final n in floor.nodes) {
      for (final t in n.next) {
        canvas.drawLine(at(n) + half, at(floor.node(t)) + half,
            n.id == current ? hot : dim);
      }
    }
  }

  @override
  bool shouldRepaint(_EdgesPainter old) =>
      old.floor != floor || old.current != current;
}
