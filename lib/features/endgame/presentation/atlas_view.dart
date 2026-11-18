import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/rules/atlas_rules.dart';

/// Color de una rama del Atlas.
Color atlasBranchColor(AtlasBranch b) => switch (b) {
      AtlasBranch.origen => ProtoColors.ink,
      AtlasBranch.cartografia => ProtoColors.sky,
      AtlasBranch.tesoro => ProtoColors.gold,
      AtlasBranch.caza => ProtoColors.orange,
      AtlasBranch.dominio => ProtoColors.violet,
      AtlasBranch.grieta => ProtoColors.dim,
    };

/// Ficha de un nodo (markup).
String atlasNodeMarkup(AtlasNodeDef n, {String? state}) =>
    '<b>${protoEsc(n.name)}</b>'
    '${n.notable ? ' ${protoColor(ProtoColors.pink, '(notable)')}' : ''}<br>'
    '${protoColor(atlasBranchColor(n.branch), protoEsc(n.branch.label))}'
    '${n.locked || n.cost == 0 ? '' : ' · costo ${n.cost}'}<br>'
    '${protoEsc(n.text)}'
    '${state == null ? '' : '<br>${protoColor(ProtoColors.dim, protoEsc(state))}'}';

/// El Atlas del Tiempo (docs/specs/ecos_atlas.md § 5): la grilla de
/// nodos a la izquierda y el detalle del elegido a la derecha. Tomar y
/// reiniciar los decide quien lo usa ([onTake], [onReset]).
class AtlasView extends StatefulWidget {
  const AtlasView({
    super.key,
    required this.progress,
    this.rules = const AtlasRules(),
    this.editBlocked,
    this.onTake,
    this.onReset,
    this.note,
  });

  final AtlasProgress progress;
  final AtlasRules rules;

  /// Por qué no se puede editar ahora (p. ej. fuera del pueblo).
  final String? editBlocked;
  final ValueChanged<String>? onTake;
  final VoidCallback? onReset;

  /// Aviso debajo de los puntos (p. ej. "En grupo vale el del anfitrión").
  final String? note;

  /// Lado de la grilla (9 × 7).
  static const cols = 9, rows = 7;

  @override
  State<AtlasView> createState() => _AtlasViewState();
}

class _AtlasViewState extends State<AtlasView> {
  String _sel = AtlasRules.rootId;

  AtlasRules get rules => widget.rules;
  AtlasProgress get p => widget.progress;

  /// Estado de un nodo para la ficha.
  String _state(AtlasNodeDef n) {
    if (n.locked) return 'Próximamente';
    if (rules.has(p, n.id)) return 'Tomado';
    return rules.cannotTake(p, n.id) ?? 'Disponible';
  }

  @override
  Widget build(BuildContext context) {
    final free = rules.free(p);
    final earned = rules.earned(p);
    int count(String prefix) =>
        p.done.where((k) => k.startsWith(prefix)).length;
    final node = rules.node(_sel) ?? rules.nodes.first;
    final why = widget.editBlocked ?? rules.cannotTake(p, node.id);
    final taken = rules.has(p, node.id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final cell = (box.maxWidth / AtlasView.cols)
                  .clamp(0.0, box.maxHeight / AtlasView.rows)
                  .toDouble();
              final w = cell * AtlasView.cols, h = cell * AtlasView.rows;
              Offset at(AtlasNodeDef n) => Offset(
                  (n.x + AtlasView.cols ~/ 2 + 0.5) * cell,
                  (n.y + AtlasView.rows ~/ 2 + 0.5) * cell);
              return Center(
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _LinksPainter(rules, p, at),
                        ),
                      ),
                      for (final n in rules.nodes) _node(n, at(n), cell),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          // Crece con el texto (sin pasar de 45 % del panel).
          width: RetroType.width(context, 340)
              .clamp(340.0, MediaQuery.sizeOf(context).width * 0.45),
          child: PanelDetail(
            footer: [
              PanelButton('REINICIAR',
                  key: const ValueKey('atlas-reset'),
                  onPressed: widget.editBlocked != null || p.nodes.isEmpty
                      ? null
                      : widget.onReset),
              if (!node.locked && !taken)
                PanelButton('TOMAR',
                    key: const ValueKey('atlas-take'),
                    accent: ProtoColors.green,
                    reason: why,
                    onPressed: () => widget.onTake?.call(node.id)),
            ],
            children: [
              // Primero el nodo elegido (lo que se decide), después el resto.
              ProtoText(
                  key: const ValueKey('atlas-detail'),
                  atlasNodeMarkup(node, state: _state(node))),
              const SizedBox(height: 8),
              ProtoText(
                  key: const ValueKey('atlas-points'),
                  'Puntos libres <b>$free</b> · ganados $earned/'
                  '${AtlasRules.maxPoints}'),
              if (widget.note != null)
                ProtoText(protoColor(ProtoColors.sky, protoEsc(widget.note!))),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: RetroTooltip(
                  key: const ValueKey('atlas-legend'),
                  message: '${protoColor(ProtoColors.dim, 'Primeras veces: tiers '
                      '${count('t')}/16 · zonas ${count('z')}/10 · jefes '
                      '${count('b')}/10')}<br>'
                      'Lleno = tomado · borde fuerte = podés tomarlo · ? = '
                      'próximamente · el número es el costo. Reiniciar es '
                      'gratis.<br>'
                      '${[
                        for (final (b, where) in const [
                          (AtlasBranch.cartografia, 'arriba'),
                          (AtlasBranch.tesoro, 'derecha'),
                          (AtlasBranch.caza, 'abajo'),
                          (AtlasBranch.dominio, 'izquierda'),
                        ])
                          '${protoColor(atlasBranchColor(b), b.label)} $where',
                      ].join(' · ')}',
                  child: const Text('[? Leyenda]',
                      style: TextStyle(color: ProtoColors.sky)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _node(AtlasNodeDef n, Offset c, double cell) {
    final size = (n.notable ? 0.62 : 0.48) * cell;
    final taken = rules.has(p, n.id);
    final open = !taken && !n.locked && rules.cannotTake(p, n.id) == null;
    final color = atlasBranchColor(n.branch);
    final selected = _sel == n.id;
    return Positioned(
      left: c.dx - size / 2,
      top: c.dy - size / 2,
      width: size,
      height: size,
      child: RetroTooltip(
        message: atlasNodeMarkup(n, state: _state(n)),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: ValueKey('atlas-node-${n.id}'),
            onTap: () => setState(() => _sel = n.id),
            child: Container(
              decoration: BoxDecoration(
                color: taken
                    ? color
                    : n.locked
                        ? ProtoColors.bg
                        : ProtoColors.input,
                border: Border.all(
                  color: selected
                      ? ProtoColors.white
                      : open
                          ? color
                          : n.locked
                              ? ProtoColors.panelBorder
                              : color.withValues(alpha: 0.45),
                  width: selected || open ? 3 : RetroTheme.thinBorderWidth,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                n.locked
                    ? '?'
                    : taken || n.cost == 0
                        ? ''
                        : '${n.cost}',
                // Nodo de tamaño fijo: nítido pero sin agrandarse.
                textScaler: RetroType.fixedScaler(context),
                style: TextStyle(
                    fontFamily: RetroType.pixelFamily, fontSize: RetroType.label,
                    color: n.locked ? ProtoColors.dim : color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Las uniones entre nodos: llenas si los dos están tomados.
class _LinksPainter extends CustomPainter {
  _LinksPainter(this.rules, this.p, this.at);

  final AtlasRules rules;
  final AtlasProgress p;
  final Offset Function(AtlasNodeDef) at;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2;
    for (final n in rules.nodes) {
      for (final l in n.links) {
        final o = rules.node(l);
        if (o == null) continue;
        final both = rules.has(p, n.id) && rules.has(p, o.id);
        paint.color =
            both ? atlasBranchColor(n.branch) : ProtoColors.panelBorder;
        canvas.drawLine(at(n), at(o), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LinksPainter old) => old.p != p;
}
