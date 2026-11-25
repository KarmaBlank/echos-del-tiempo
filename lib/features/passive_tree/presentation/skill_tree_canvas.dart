import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../game_engine/models/passive_tree.dart';
import '../domain/passive_text.dart';
import 'passive_tree_view.dart';

/// A level gate drawn as a faint ring around the tree centre
/// (radius in tree units); [open] = already reached.
class SkillTreeRing {
  const SkillTreeRing(this.radius, {required this.open});
  final double radius;
  final bool open;
}

/// Generic skill-tree organism (passive_tree_v3.md Â§ 13, life_trees_v2.md
/// Â§ 3): a pan/zoom viewport that draws any [PassiveTreeCatalog] with the
/// same painters as the ARBOL tab ([PassiveTreePainter] for links and
/// nodes, [TreeLabelsPainter] for the group names in screen pixels).
/// Names never sit next to the nodes: they go in the hover card and in
/// the caller's detail pane. Zoom buttons, "Show all" and the first frame
/// frame the whole tree.
class SkillTreeCanvas extends ConsumerStatefulWidget {
  const SkillTreeCanvas({
    super.key,
    required this.catalog,
    required this.states,
    required this.onSelect,
    required this.tooltip,
    this.startId,
    this.selected,
    this.rings = const [],
    this.keyPrefix = 'tree-node',
  });

  final PassiveTreeCatalog catalog;
  final Map<String, TreeNodeState> states;
  final ValueChanged<String> onSelect;

  /// Hover card of a node (a fixed-size [DsTooltipCard]).
  final Widget Function(String id) tooltip;
  final String? startId;
  final String? selected;
  final List<SkillTreeRing> rings;

  /// Each node gets a hit box keyed `<keyPrefix>-<id>` with a child keyed
  /// `<keyPrefix>-<id>-<state>` (tests and accessibility).
  final String keyPrefix;

  /// Margin (screen px) around the tree when it is framed.
  static const fitMargin = 24.0;

  @override
  ConsumerState<SkillTreeCanvas> createState() => _SkillTreeCanvasState();
}

class _SkillTreeCanvasState extends ConsumerState<SkillTreeCanvas> {
  final _transform = TransformationController();
  Size _view = Size.zero;
  PassiveTreeCatalog? _framed;
  String? _hover;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  double get _zoom => _transform.value.storage[0];

  /// Centres [focus] at zoom [k]. Without [notify] the matrix changes in
  /// place (used while building: everything below reads it again).
  void _look(Offset focus, double k, {bool notify = true}) {
    final z = k.clamp(PassiveTreeView.minZoom, PassiveTreeView.maxZoom);
    final m = Matrix4.diagonal3Values(z, z, 1)
      ..setTranslationRaw(
          _view.width / 2 - focus.dx * z, _view.height / 2 - focus.dy * z, 0);
    if (notify) {
      _transform.value = m;
    } else {
      _transform.value.setFrom(m);
    }
  }

  void _fit({bool notify = true}) {
    Rect? box;
    for (final n in widget.catalog.nodes.values) {
      final r = Rect.fromCircle(center: Offset(n.x, n.y), radius: 1);
      box = box?.expandToInclude(r) ?? r;
    }
    for (final p in widget.catalog.paths.values) {
      final r = Rect.fromCircle(center: Offset(p.labelX, p.labelY), radius: 1);
      box = box?.expandToInclude(r) ?? r;
    }
    if (box == null || _view.isEmpty) return;
    const s = PassiveTreeView.scale;
    const m = SkillTreeCanvas.fitMargin;
    final z = math.min((_view.width - 2 * m) / (box.width * s),
        (_view.height - 2 * m) / (box.height * s));
    _look(PassiveTreeView.toCanvas(box.center.dx, box.center.dy), z,
        notify: notify);
  }

  void _zoomBy(double f) => setState(() => _look(
      MatrixUtils.transformPoint(Matrix4.inverted(_transform.value),
          Offset(_view.width / 2, _view.height / 2)),
      _zoom * f));

  Widget _iconButton(
          String key, PixelIconKind icon, String tip, VoidCallback f) =>
      DsButton.icon(
          Semantics(
              label: tip,
              child: PixelIcon(icon, size: 16, color: DsColors.textPrimary)),
          key: ValueKey(key),
          tooltip: tip,
          size: DsButtonSize.compact,
          onPressed: f);

  @override
  Widget build(BuildContext context) {
    final cat = widget.catalog;
    final focus = _hover ?? widget.selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _iconButton('${widget.keyPrefix}-zoom-out', PixelIconKind.minus,
              ref.t('ui.passive_tree.zoom_out'), () => _zoomBy(1 / 1.25)),
          SizedBox(width: DsSpace.xs),
          _iconButton('${widget.keyPrefix}-zoom-in', PixelIconKind.plus,
              ref.t('ui.passive_tree.zoom_in'), () => _zoomBy(1.25)),
          SizedBox(width: DsSpace.xs),
          _iconButton('${widget.keyPrefix}-fit', PixelIconKind.fit,
              ref.t('ui.passive_tree.fit'), () => setState(_fit)),
        ]),
        SizedBox(height: DsSpace.xs),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final view = box.biggest;
            if (view != _view || !identical(_framed, cat)) {
              _view = view;
              _framed = cat;
              _fit(notify: false);
            }
            return DecoratedBox(
              key: ValueKey('${widget.keyPrefix}-viewport'),
              decoration: BoxDecoration(
                color: ProtoColors.bg,
                border: Border.all(
                    color: ProtoColors.panelBorder,
                    width: RetroTheme.thinBorderWidth),
              ),
              child: ClipRect(
                child: Stack(children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _transform,
                      constrained: false,
                      minScale: PassiveTreeView.minZoom,
                      maxScale: PassiveTreeView.maxZoom,
                      boundaryMargin: const EdgeInsets.all(600),
                      child: SizedBox.square(
                        dimension: PassiveTreeView.size,
                        child: Stack(children: [
                          Positioned.fill(
                            child: CustomPaint(
                                painter: _RingsPainter(widget.rings)),
                          ),
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: ValueListenableBuilder<Matrix4>(
                                valueListenable: _transform,
                                builder: (context, m, _) => CustomPaint(
                                  painter: PassiveTreePainter(
                                    zoom: m.storage[0],
                                    devicePixelRatio:
                                        MediaQuery.devicePixelRatioOf(context),
                                    catalog: cat,
                                    startId: widget.startId,
                                    states: widget.states,
                                    focus: focus,
                                    highlightPath: cat.nodes[focus]?.pathId,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          for (final n in cat.nodes.values) _hit(n),
                        ]),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _transform,
                        builder: (context, _) => CustomPaint(
                          key: ValueKey('${widget.keyPrefix}-labels'),
                          painter: TreeLabelsPainter(
                            catalog: cat,
                            transform: _transform.value.clone(),
                            highlightPath: cat.nodes[focus]?.pathId,
                            textScaler: MediaQuery.textScalerOf(context),
                            devicePixelRatio:
                                MediaQuery.devicePixelRatioOf(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Invisible hit box over node [n]: hover card, hover focus and tap.
  Widget _hit(PassiveNode n) {
    final c = PassiveTreeView.nodeCenter(n);
    final r = math.max(PassiveTreeView.nodeRadius(n, start: n.id == widget.startId) + 4,
        PassiveTreeView.minHitRadius);
    final st = widget.states[n.id] ?? TreeNodeState.locked;
    final p = widget.keyPrefix;
    return Positioned(
      left: c.dx - r,
      top: c.dy - r,
      width: r * 2,
      height: r * 2,
      child: DsTooltip(
        card: widget.tooltip(n.id),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = n.id),
          onExit: (_) {
            if (_hover == n.id) setState(() => _hover = null);
          },
          child: GestureDetector(
            key: ValueKey('$p-${n.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onSelect(n.id),
            child: SizedBox.expand(key: ValueKey('$p-${n.id}-${st.name}')),
          ),
        ),
      ),
    );
  }
}

/// Level-gate rings behind the tree: reached ones in the panel border
/// colour, the rest dimmer.
class _RingsPainter extends CustomPainter {
  _RingsPainter(this.rings);
  final List<SkillTreeRing> rings;

  @override
  void paint(Canvas canvas, Size size) {
    final c = PassiveTreeView.toCanvas(0, 0);
    for (final r in rings) {
      canvas.drawCircle(
          c,
          r.radius * PassiveTreeView.scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r.open ? 2 : 1
            ..color = (r.open ? DsColors.border : DsColors.surfaceSunken)
                .withValues(alpha: r.open ? 0.6 : 0.8));
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.rings.length != rings.length ||
      [for (var i = 0; i < rings.length; i++) rings[i].open != old.rings[i].open]
          .any((d) => d);
}
