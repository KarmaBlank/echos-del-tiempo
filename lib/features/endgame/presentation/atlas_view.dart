import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/rules/atlas_rules.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../domain/endgame_names.dart';
import '../domain/endgame_text.dart';

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
String atlasNodeMarkup(Strings t, AtlasNodeDef n, {String? state}) =>
    '<b>${protoEsc(n.tr)}</b>'
    '${n.notable ? ' ${protoColor(ProtoColors.pink, t.t('ui.endgame.atlas.notable'))}' : ''}<br>'
    '${protoColor(atlasBranchColor(n.branch), protoEsc(n.branch.tr))}'
    '${n.locked || n.cost == 0 ? '' : t.t('ui.endgame.atlas.cost', {'cost': n.cost})}<br>'
    '${protoEsc(n.textTr)}'
    '${state == null ? '' : '<br>${protoColor(ProtoColors.dim, protoEsc(state))}'}';

/// El Atlas del Tiempo (docs/specs/ecos_atlas.md § 5): la grilla de
/// nodos a la izquierda y el detalle del elegido a la derecha. Tomar y
/// reiniciar los decide quien lo usa ([onTake], [onReset]).
class AtlasView extends ConsumerStatefulWidget {
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
  ConsumerState<AtlasView> createState() => _AtlasViewState();
}

class _AtlasViewState extends ConsumerState<AtlasView> {
  String _sel = AtlasRules.rootId;

  AtlasRules get rules => widget.rules;
  AtlasProgress get p => widget.progress;

  /// Estado de un nodo para la ficha.
  String _state(AtlasNodeDef n) {
    if (n.locked) return ref.t('ui.endgame.atlas.soon');
    if (rules.has(p, n.id)) return ref.t('ui.endgame.atlas.taken');
    return rules.cannotTake(p, n.id) ?? ref.t('ui.endgame.atlas.available');
  }

  @override
  Widget build(BuildContext context) {
    final free = rules.free(p);
    final earned = rules.earned(p);
    int count(String prefix) =>
        p.done.where((k) => k.startsWith(prefix)).length;
    final node = rules.node(_sel) ?? rules.nodes.first;
    final why = widget.editBlocked ?? atlasTakeBlocked(rules, p, node.id);
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
              PanelButton(ref.t('ui.endgame.reset'),
                  key: const ValueKey('atlas-reset'),
                  onPressed: widget.editBlocked != null || p.nodes.isEmpty
                      ? null
                      : widget.onReset),
              if (!node.locked && !taken)
                PanelButton(ref.t('ui.endgame.take'),
                    key: const ValueKey('atlas-take'),
                    accent: ProtoColors.green,
                    reason: why,
                    onPressed: () => widget.onTake?.call(node.id)),
            ],
            children: [
              // Primero el nodo elegido (lo que se decide), después el resto.
              ProtoText(
                  key: const ValueKey('atlas-detail'),
                  atlasNodeMarkup(ref.strings, node, state: _state(node))),
              const SizedBox(height: 8),
              ProtoText(
                  key: const ValueKey('atlas-points'),
                  ref.t('ui.endgame.atlas.points', {
                    'free': free,
                    'earned': earned,
                    'max': AtlasRules.maxPoints,
                  })),
              if (widget.note != null)
                ProtoText(protoColor(ProtoColors.sky, protoEsc(widget.note!))),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: RetroTooltip(
                  key: const ValueKey('atlas-legend'),
                  message: '${protoColor(ProtoColors.dim, ref.t('ui.endgame.atlas.firsts', {
                        'tiers': count('t'),
                        'zones': count('z'),
                        'bosses': count('b'),
                      }))}<br>'
                      '${ref.t('ui.endgame.atlas.legend_text')}<br>'
                      '${[
                        for (final (b, where) in const [
                          (AtlasBranch.cartografia, 'up'),
                          (AtlasBranch.tesoro, 'right'),
                          (AtlasBranch.caza, 'down'),
                          (AtlasBranch.dominio, 'left'),
                        ])
                          '${protoColor(atlasBranchColor(b), b.tr)} ${ref.t('ui.endgame.atlas.dir.$where')}',
                      ].join(' · ')}',
                  child: Text(ref.t('ui.endgame.atlas.legend'),
                      style: const TextStyle(color: ProtoColors.sky)),
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
        message: atlasNodeMarkup(ref.strings, n, state: _state(n)),
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
