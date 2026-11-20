import 'package:material_ui/material_ui.dart';

import '../design/ds_components.dart';
import '../theme/proto_colors.dart';

/// Insignia chica `N` de puntos sin usar (passive_tree_v4.md § 7):
/// un [DsBadge] (la misma pastilla que en las pestañas), dentro del botón
/// a la derecha del texto (v0.10.1, nunca encima). No depende solo del color:
/// el número se lee igual con cualquier paleta de daltonismo.
///
/// Con [pulse] late suave (solo opacidad); con "Reducir movimiento"
/// ([reduceMotion]) queda quieta.
class PointsBadge extends StatefulWidget {
  const PointsBadge({
    super.key,
    required this.count,
    this.pulse = true,
    this.reduceMotion = false,
  });

  final int count;
  final bool pulse;
  final bool reduceMotion;

  /// Color del texto (oscuro sobre dorado: contraste alto).
  static const ink = ProtoColors.bg;

  @override
  State<PointsBadge> createState() => _PointsBadgeState();
}

class _PointsBadgeState extends State<PointsBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  bool get _animate => widget.pulse && !widget.reduceMotion && widget.count > 0;

  void _sync() {
    if (_animate) {
      _c ??= AnimationController(
          vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);
    } else {
      _c?.dispose();
      _c = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PointsBadge old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  // Siempre la misma insignia del sistema (design_system.md § 6): forma,
  // tamaño, colores y tipografía de [DsBadge], igual que en las pestañas.
  Widget _box() => DsBadge('${widget.count}');

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();
    final c = _c;
    final label = Semantics(
      label: '${widget.count} punto${widget.count == 1 ? '' : 's'} sin usar',
      child: const SizedBox.shrink(),
    );
    if (c == null) {
      return KeyedSubtree(
        key: const ValueKey('points-badge-static'),
        child: Stack(children: [label, _box()]),
      );
    }
    return KeyedSubtree(
      key: const ValueKey('points-badge-pulse'),
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) => Opacity(
          opacity: 0.7 + 0.3 * c.value,
          child: Stack(children: [label, _box()]),
        ),
      ),
    );
  }
}
