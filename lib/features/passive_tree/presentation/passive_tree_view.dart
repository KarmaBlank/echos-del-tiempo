import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/passive_tree.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/passive_tree_rules.dart';
import '../domain/passive_text.dart';

/// El árbol de pasivas (`treeHtml`, líneas 363-376): lienzo con enlaces y
/// nodos, info del nodo bajo el mouse / elegido y botones de tomar y
/// reiniciar. Ver docs/specs/panels.md § "Árbol".
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
  });

  final PassiveTreeRules rules;
  final PlayerProfile profile;
  final bool inBattle;
  final ValueChanged<String> onTake;

  /// Motivo por el que no se puede reiniciar (`null` = se puede).
  final String? resetReason;
  final VoidCallback? onReset;

  /// El prototipo solo ofrece reiniciar en lobby/preparación.
  final bool showReset;

  /// Lado del lienzo (el prototipo usa 320 px con `SC = 34`).
  static const size = 400.0;
  static const scale = 42.5;

  /// Centro del nodo [n] en el lienzo.
  static Offset nodeCenter(PassiveNode n) =>
      Offset(size / 2 + n.x * scale, size / 2 + n.y * scale);

  /// Radio del nodo (`r` de `treeHtml` × 1.25).
  static double nodeRadius(PassiveNode n, {required bool start}) =>
      (n.kind == 'k'
          ? 9
          : start
              ? 8
              : 6) *
      1.25;

  @override
  State<PassiveTreeView> createState() => _PassiveTreeViewState();
}

class _PassiveTreeViewState extends State<PassiveTreeView> {
  String? _hover;
  String? _selected;

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
    final start = cat.startNodeByClass[widget.profile.classId];
    String? best;
    var bestD = double.infinity;
    for (final n in cat.nodes.values) {
      final d = (PassiveTreeView.nodeCenter(n) - pos).distance;
      final r = PassiveTreeView.nodeRadius(n, start: n.id == start) + 4;
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

  @override
  Widget build(BuildContext context) {
    final rules = widget.rules;
    final p = widget.profile;
    final points = rules.pointsAvailable(p.level, p.passiveProgress);
    final focus = _hover ?? _selected;
    final states = {
      for (final id in rules.catalog.nodes.keys) id: _status(id).state,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: retroText('Puntos de árbol disponibles: ')),
              TextSpan(
                  text: '$points',
                  style: const TextStyle(color: RetroPalette.gold)),
            ])),
            if (widget.showReset)
              PanelButton('REINICIAR ÁRBOL',
                  key: const ValueKey('tree-reset'),
                  reason: widget.resetReason,
                  onPressed: widget.onReset),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MouseRegion(
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
                    startId: rules.catalog.startNodeByClass[p.classId],
                    states: states,
                    focus: focus,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _info(focus)),
          ],
        ),
      ],
    );
  }

  Widget _info(String? id) {
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, color) in const [
          ('Inicio de tu clase', RetroPalette.gold),
          ('Tomado', RetroPalette.green),
          ('Keystone tomada', RetroPalette.red),
          ('Disponible: clic para tomar', RetroPalette.ink),
          ('Bloqueado', RetroPalette.muted),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Container(width: 8, height: 8, color: color),
              const SizedBox(width: 8),
              Text(retroText(label)),
            ]),
          ),
      ],
    );
    final node = id == null ? null : widget.rules.catalog.nodes[id];
    if (node == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pasa el mouse o toca un nodo para ver qué da.',
              style: TextStyle(color: RetroPalette.muted)),
          const SizedBox(height: 16),
          legend,
        ],
      );
    }
    final st = _status(node.id);
    final (stateText, stateColor) = switch (st.state) {
      TreeNodeState.start => ('Nodo inicial', RetroPalette.muted),
      TreeNodeState.taken => ('Tomado', RetroPalette.green),
      TreeNodeState.available => ('Disponible: clic para tomar', RetroPalette.ink),
      TreeNodeState.locked => (st.reason ?? 'Bloqueado', RetroPalette.red),
    };
    return Column(
      key: const ValueKey('tree-info'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(retroText(node.name),
            style: const TextStyle(color: RetroPalette.gold)),
        if (node.kind == 'k' || node.kind == 'n')
          Text(node.kind == 'k' ? 'KEYSTONE' : 'NOTABLE',
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

/// Dibuja enlaces y nodos con la paleta de 8 colores.
class PassiveTreePainter extends CustomPainter {
  PassiveTreePainter({
    required this.catalog,
    required this.startId,
    required this.states,
    this.focus,
  });

  final PassiveTreeCatalog catalog;
  final String? startId;
  final Map<String, TreeNodeState> states;
  final String? focus;

  bool _has(String id) {
    final s = states[id];
    return s == TreeNodeState.start || s == TreeNodeState.taken;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = RetroPalette.night);
    canvas.drawRect(
      (Offset.zero & size).deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = RetroTheme.thinBorderWidth
        ..color = RetroPalette.panel,
    );
    final link = Paint()..strokeWidth = 2;
    final seen = <String>{};
    for (final n in catalog.nodes.values) {
      for (final l in n.links) {
        final key = n.id.compareTo(l) < 0 ? '${n.id}|$l' : '$l|${n.id}';
        if (!seen.add(key)) continue;
        final b = catalog.nodes[l];
        if (b == null) continue;
        link.color = _has(n.id) && _has(l)
            ? RetroPalette.green
            : RetroPalette.panel;
        canvas.drawLine(PassiveTreeView.nodeCenter(n),
            PassiveTreeView.nodeCenter(b), link);
      }
    }
    for (final n in catalog.nodes.values) {
      final c = PassiveTreeView.nodeCenter(n);
      final r = PassiveTreeView.nodeRadius(n, start: n.id == startId);
      final state = states[n.id] ?? TreeNodeState.locked;
      final fill = switch (state) {
        TreeNodeState.start => RetroPalette.gold,
        TreeNodeState.taken =>
          n.kind == 'k' ? RetroPalette.red : RetroPalette.green,
        TreeNodeState.available => RetroPalette.ink,
        TreeNodeState.locked => RetroPalette.panel,
      };
      canvas.drawCircle(c, r, Paint()..color = fill);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = state == TreeNodeState.locked
              ? RetroPalette.muted
              : RetroPalette.night,
      );
      if (n.id == focus) {
        canvas.drawCircle(
          c,
          r + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = RetroPalette.gold,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PassiveTreePainter old) =>
      old.focus != focus ||
      old.startId != startId ||
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
