import 'package:material_ui/material_ui.dart';

import '../theme/proto_colors.dart';
import '../theme/retro_type.dart';

/// Insignia chica `+N` de puntos sin usar (passive_tree_v4.md § 7): caja
/// dorada con texto oscuro y borde claro. No depende solo del color: el
/// `+N` se lee igual con cualquier paleta de daltonismo.
///
/// Con [pulse] late suave (opacidad y brillo del borde); con "Reducir
/// movimiento" ([reduceMotion]) queda quieta con un borde más grueso.
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
  static const ink = Color(0xFF14172B);

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

  Widget _box(double t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Color.lerp(ProtoColors.gold, const Color(0xFFFFE08A), t)!,
          border: Border.all(
              color: Color.lerp(const Color(0xFFE8ECFF), ProtoColors.white, t)!,
              width: widget.reduceMotion ? 2 : 1),
        ),
        child: Text('+${widget.count}',
            style: RetroType.style(RetroType.small,
                color: PointsBadge.ink, fontWeight: FontWeight.bold)),
      );

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
        child: Stack(children: [label, _box(0)]),
      );
    }
    return KeyedSubtree(
      key: const ValueKey('points-badge-pulse'),
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) => Opacity(
          opacity: 0.7 + 0.3 * c.value,
          child: Stack(children: [label, _box(c.value)]),
        ),
      ),
    );
  }
}
