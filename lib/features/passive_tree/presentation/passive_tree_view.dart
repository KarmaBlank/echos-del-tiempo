import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/passive_tree.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/passive_tree_rules.dart';
import '../domain/passive_text.dart';

/// El árbol de pasivas v2 (docs/specs/passive_tree_v2.md § 7): lienzo con
/// arrastre y zoom, caminos que se resaltan al pasar el mouse, tooltip
/// con el efecto completo, info del nodo elegido y botones de tomar y
/// reiniciar. Ver también docs/specs/panels.md § "Árbol".
class PassiveTreeView extends StatefulWidget {
  const PassiveTreeView({
    super.key,
    required this.rules,
    required this.profile,
    required this.inBattle,
    required this.onTake,
    this.resetReason,
    this.onReset,
    this.showReset = true,
    this.resetLabel = 'REINICIAR ÁRBOL',
    this.height = PassiveTreeView.viewportHeight,
    this.showHelp = true,
  });

  final PassiveTreeRules rules;
  final PlayerProfile profile;
  final bool inBattle;
  final ValueChanged<String> onTake;

  /// Motivo por el que no se puede reiniciar (`null` = se puede).
  final String? resetReason;
  final VoidCallback? onReset;
  final bool showReset;
  final String resetLabel;

  /// Alto del visor (el panel lo ajusta al espacio que tiene).
  final double height;

  /// Línea de ayuda propia (el panel de personaje ya pone la suya).
  final bool showHelp;

  /// Lado del lienzo (mundo) y píxeles por unidad de árbol.
  static const size = 680.0;
  static const scale = 30.0;

  /// Alto del visor por defecto.
  static const viewportHeight = 420.0;

  /// Centro del nodo [n] en el lienzo (coordenadas del mundo).
  static Offset nodeCenter(PassiveNode n) =>
      Offset(size / 2 + n.x * scale, size / 2 + n.y * scale);

  /// Radio del nodo: keystone 12 (hexágono), notable e inicio 9, resto 6.
  static double nodeRadius(PassiveNode n, {required bool start}) =>
      switch (n.kind) {
        'k' => 12,
        'n' || 'st' => 9,
        _ => start ? 9 : 6,
      };

  @override
  State<PassiveTreeView> createState() => _PassiveTreeViewState();
}

class _PassiveTreeViewState extends State<PassiveTreeView> {
  final _transform = TransformationController();
  String? _hover;
  String? _selected;
  Size? _fittedFor;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  TreeNodeStatus _status(String id) => treeNodeStatus(
        widget.rules,
        classId: widget.profile.classId,
        level: widget.profile.level,
        progress: widget.profile.passiveProgress,
        nodeId: id,
        inBattle: widget.inBattle,
      );

  String? _hit(Offset pos) {
    final cat = widget.rules.catalog;
    String? best;
    var bestD = double.infinity;
    for (final n in cat.nodes.values) {
      final d = (PassiveTreeView.nodeCenter(n) - pos).distance;
      final r = PassiveTreeView.nodeRadius(n, start: n.kind == 'st') + 4;
      if (d <= r && d < bestD) {
        best = n.id;
        bestD = d;
      }
    }
    return best;
  }

  void _tap(Offset pos) {
    final id = _hit(pos);
    if (id == null) return;
    setState(() => _selected = id);
    if (_status(id).canTake) widget.onTake(id);
  }

  /// Encuadre inicial: escala para ver casi todo el árbol, centrado en la
  /// zona de tu clase.
  void _fit(Size view) {
    if (_fittedFor == view) return;
    _fittedFor = view;
    const s = PassiveTreeView.size;
    final k = (math.min(view.width, view.height) / (s * 0.8)).clamp(0.6, 1.2);
    final start = widget.rules.catalog
        .nodes[widget.rules.catalog.startNodeByClass[widget.profile.classId]];
    var focus = const Offset(s / 2, s / 2);
    if (start != null && s * k > math.min(view.width, view.height)) {
      final c = PassiveTreeView.nodeCenter(start);
      focus = focus + (c - focus) * 1.6;
    }
    _transform.value = Matrix4.diagonal3Values(k, k, 1)
      ..setTranslationRaw(
          view.width / 2 - focus.dx * k, view.height / 2 - focus.dy * k, 0);
  }

  @override
  Widget build(BuildContext context) {
    final rules = widget.rules;
    final p = widget.profile;
    final points = rules.pointsAvailable(p.level, p.passiveProgress);
    final states = {
      for (final id in rules.catalog.nodes.keys) id: _status(id).state,
    };
    final hoverPath =
        _hover == null ? null : rules.catalog.nodes[_hover]?.pathId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(TextSpan(
                style: const TextStyle(color: ProtoColors.sky),
                children: [
                  TextSpan(text: retroText('Puntos de árbol disponibles: ')),
                  TextSpan(
                      text: '$points',
                      style: const TextStyle(
                          color: ProtoColors.gold,
                          fontWeight: FontWeight.bold)),
                ])),
            if (widget.showReset)
              PanelButton(widget.resetLabel,
                  key: const ValueKey('tree-reset'),
                  reason: widget.resetReason,
                  onPressed: widget.onReset),
          ],
        ),
        if (widget.showHelp) ...[
          const SizedBox(height: 4),
          const Text('Arrastrá para mover, rueda para zoom. Clic: tomar nodo.',
              style: TextStyle(color: ProtoColors.dim)),
        ],
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: widget.height,
                child: LayoutBuilder(builder: (context, box) {
                  _fit(box.biggest);
                  return _viewport(box.biggest, states, hoverPath);
                }),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: 352, child: _info(_selected ?? _hover)),
          ],
        ),
      ],
    );
  }

  Widget _viewport(
      Size view, Map<String, TreeNodeState> states, String? hoverPath) {
    final rules = widget.rules;
    return DecoratedBox(
      key: const ValueKey('tree-viewport'),
      decoration: BoxDecoration(
        color: ProtoColors.bg,
        border: Border.all(
            color: ProtoColors.panelBorder, width: RetroTheme.thinBorderWidth),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                minScale: 0.5,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(500),
                child: MouseRegion(
                  onHover: (e) {
                    final id = _hit(e.localPosition);
                    if (id != _hover) setState(() => _hover = id);
                  },
                  onExit: (_) => setState(() => _hover = null),
                  child: GestureDetector(
                    key: const ValueKey('tree-canvas'),
                    onTapUp: (d) => _tap(d.localPosition),
                    child: CustomPaint(
                      size: const Size.square(PassiveTreeView.size),
                      painter: PassiveTreePainter(
                        catalog: rules.catalog,
                        startId: rules
                            .catalog.startNodeByClass[widget.profile.classId],
                        states: states,
                        focus: _hover ?? _selected,
                        highlightPath: hoverPath,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_hover != null)
              AnimatedBuilder(
                animation: _transform,
                builder: (context, _) => _tooltip(view, _hover!),
              ),
          ],
        ),
      ),
    );
  }

  /// Tooltip junto al nodo bajo el mouse: nombre, tipo, camino, efectos
  /// completos y estado.
  Widget _tooltip(Size view, String id) {
    final cat = widget.rules.catalog;
    final node = cat.nodes[id];
    if (node == null) return const SizedBox.shrink();
    final at = MatrixUtils.transformPoint(
        _transform.value, PassiveTreeView.nodeCenter(node));
    // En la esquina del visor opuesta al nodo: no tapa su camino.
    const w = 250.0;
    final left = at.dx > view.width / 2 ? 8.0 : view.width - w - 8;
    final onTop = at.dy > view.height / 2;
    final path = cat.paths[node.pathId];
    final st = _status(id);
    final kind = switch (node.kind) {
      'k' => 'KEYSTONE',
      'n' => 'NOTABLE',
      'st' => 'INICIO DE CLASE',
      _ => null,
    };
    final (stateText, stateColor) = _stateText(st);
    return Positioned(
      left: math.max(4.0, left),
      top: onTop ? 8 : null,
      bottom: onTop ? null : 8,
      width: w,
      child: IgnorePointer(
        child: Container(
          key: const ValueKey('tree-tooltip'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ProtoColors.bg.withValues(alpha: 0.96),
            border: Border.all(
                color: node.kind == 'n' || node.kind == 'k'
                    ? ProtoColors.gold
                    : ProtoColors.buttonBorder,
                width: 2),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 8, height: 1.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(retroText(node.name),
                    style: const TextStyle(
                        color: ProtoColors.gold, fontWeight: FontWeight.bold)),
                if (kind != null || path != null)
                  Text(
                      retroText([
                        if (kind != null) kind,
                        if (path != null) 'Camino ${path.name}: ${path.theme}',
                      ].join(' · ')),
                      style: const TextStyle(color: ProtoColors.dim)),
                const SizedBox(height: 4),
                for (final line in passiveEffectsText(node))
                  Text(retroText(line)),
                const SizedBox(height: 4),
                Text(retroText(stateText), style: TextStyle(color: stateColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (String, Color) _stateText(TreeNodeStatus st) => switch (st.state) {
        TreeNodeState.start => ('Nodo inicial', RetroPalette.muted),
        TreeNodeState.taken => ('Tomado', RetroPalette.green),
        TreeNodeState.available => (
            'Disponible: clic para tomar',
            ProtoColors.sky
          ),
        TreeNodeState.locked => (st.reason ?? 'Bloqueado', RetroPalette.red),
      };

  Widget _info(String? id) {
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, color) in const [
          ('Inicio de tu clase', RetroPalette.gold),
          ('Tomado', RetroPalette.green),
          ('Keystone tomada', Color(0xFFFF6B6B)),
          ('Disponible: clic para tomar', ProtoColors.sky),
          ('Bloqueado', Color(0xFF3A4570)),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Container(width: 8, height: 8, color: color),
              const SizedBox(width: 8),
              Flexible(child: Text(retroText(label))),
            ]),
          ),
        const SizedBox(height: 4),
        const Text(
            'Borde dorado: notable (mecánica nueva). Hexágono: '
            'keystone (efecto fuerte con contra).',
            style: TextStyle(color: ProtoColors.dim)),
      ],
    );
    final node = id == null ? null : widget.rules.catalog.nodes[id];
    if (node == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Pasa el mouse o toca un nodo para ver qué da. Cada camino '
              'lleva a 2 notables y una keystone; el anillo del centro '
              'conecta con las otras clases.',
              style: TextStyle(color: RetroPalette.muted)),
          const SizedBox(height: 16),
          legend,
        ],
      );
    }
    final st = _status(node.id);
    final (stateText, stateColor) = _stateText(st);
    final path = widget.rules.catalog.paths[node.pathId];
    return Column(
      key: const ValueKey('tree-info'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(retroText(node.name),
            style: const TextStyle(
                color: ProtoColors.gold, fontWeight: FontWeight.bold)),
        if (node.kind == 'k' || node.kind == 'n')
          Text(node.kind == 'k' ? 'KEYSTONE' : 'NOTABLE',
              style: const TextStyle(color: RetroPalette.muted)),
        if (path != null)
          Text(retroText('Camino ${path.name}'),
              style: const TextStyle(color: RetroPalette.muted)),
        const SizedBox(height: 8),
        for (final line in passiveEffectsText(node))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(retroText(line)),
          ),
        const SizedBox(height: 8),
        // Bloqueado: el motivo ya va junto al botón de tomar.
        if (st.state != TreeNodeState.locked)
          Text(retroText(stateText), style: TextStyle(color: stateColor)),
        if (st.state != TreeNodeState.start &&
            st.state != TreeNodeState.taken) ...[
          const SizedBox(height: 8),
          PanelButton('TOMAR NODO',
              key: const ValueKey('tree-take'),
              reason: st.reason,
              onPressed: () => widget.onTake(node.id)),
        ],
        const SizedBox(height: 16),
        legend,
      ],
    );
  }
}

/// Dibuja el anillo, los enlaces, los nodos (círculo, notable con borde
/// dorado, keystone hexagonal) y el nombre de cada camino.
class PassiveTreePainter extends CustomPainter {
  PassiveTreePainter({
    required this.catalog,
    required this.startId,
    required this.states,
    this.focus,
    this.highlightPath,
  });

  final PassiveTreeCatalog catalog;
  final String? startId;
  final Map<String, TreeNodeState> states;
  final String? focus;

  /// Camino resaltado (el del nodo bajo el mouse).
  final String? highlightPath;

  static const _locked = Color(0xFF3A4570);
  static const _keyTaken = Color(0xFFFF6B6B);

  bool _has(String id) {
    final s = states[id];
    return s == TreeNodeState.start || s == TreeNodeState.taken;
  }

  bool _inPath(PassiveNode n) =>
      highlightPath != null && n.pathId == highlightPath;

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(PassiveTreeView.size / 2, PassiveTreeView.size / 2);
    // Anillo central compartido.
    canvas.drawCircle(
        center,
        1.5 * PassiveTreeView.scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = ProtoColors.panelBorder.withValues(alpha: 0.35));

    final link = Paint()..strokeWidth = 2;
    final seen = <String>{};
    for (final n in catalog.nodes.values) {
      for (final l in n.links) {
        final key = n.id.compareTo(l) < 0 ? '${n.id}|$l' : '$l|${n.id}';
        if (!seen.add(key)) continue;
        final b = catalog.nodes[l];
        if (b == null) continue;
        final lit = _inPath(n) || _inPath(b);
        link
          ..color = _has(n.id) && _has(l)
              ? ProtoColors.green
              : lit
                  ? ProtoColors.gold
                  : ProtoColors.panelBorder
          ..strokeWidth = lit ? 3 : 2;
        canvas.drawLine(
            PassiveTreeView.nodeCenter(n), PassiveTreeView.nodeCenter(b), link);
      }
    }

    for (final n in catalog.nodes.values) {
      final c = PassiveTreeView.nodeCenter(n);
      final r = PassiveTreeView.nodeRadius(n, start: n.id == startId);
      final state = states[n.id] ?? TreeNodeState.locked;
      final fill = switch (state) {
        TreeNodeState.start => ProtoColors.gold,
        TreeNodeState.taken => n.kind == 'k' ? _keyTaken : ProtoColors.green,
        TreeNodeState.available => ProtoColors.sky,
        TreeNodeState.locked => _locked,
      };
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = n.kind == 'n' || n.kind == 'k' ? 2.5 : 1.5
        ..color =
            n.kind == 'n' || n.kind == 'k' ? ProtoColors.gold : ProtoColors.bg;
      if (n.kind == 'k') {
        final hex = _hexagon(c, r);
        canvas.drawPath(hex, Paint()..color = fill);
        canvas.drawPath(hex, border);
      } else {
        canvas.drawCircle(c, r, Paint()..color = fill);
        canvas.drawCircle(c, r, border);
      }
      if (_inPath(n) || n.id == focus) {
        canvas.drawCircle(
          c,
          r + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = n.id == focus ? 2 : 1
            ..color = ProtoColors.gold,
        );
      }
    }

    // Nombre de cada camino, más allá de su keystone.
    for (final path in catalog.paths.values) {
      final k = catalog.nodes['${path.id}_k'];
      if (k == null) continue;
      final dir = Offset(k.x, k.y) / Offset(k.x, k.y).distance;
      final tp = TextPainter(
        text: TextSpan(
          text: retroText(path.name.toUpperCase()),
          style: TextStyle(
            fontFamily: RetroTheme.fontFamily,
            fontSize: 8,
            color:
                path.id == highlightPath ? ProtoColors.gold : ProtoColors.dim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final gap =
          18 + dir.dx.abs() * tp.width / 2 + dir.dy.abs() * tp.height / 2;
      final at = PassiveTreeView.nodeCenter(k) + dir * gap;
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  static Path _hexagon(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final v = c + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        p.moveTo(v.dx, v.dy);
      } else {
        p.lineTo(v.dx, v.dy);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(PassiveTreePainter old) =>
      old.focus != focus ||
      old.startId != startId ||
      old.highlightPath != highlightPath ||
      !_sameStates(old.states, states);

  static bool _sameStates(
      Map<String, TreeNodeState> a, Map<String, TreeNodeState> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
