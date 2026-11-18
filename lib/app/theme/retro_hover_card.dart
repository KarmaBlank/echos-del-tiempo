import 'package:material_ui/material_ui.dart';

import 'panel_frame.dart';
import 'proto_colors.dart';
import 'retro_theme.dart';

/// Tooltip con widgets (no solo texto): la caja del `#tip`
/// ([RetroTooltip]) con lo que arme [builder], al lado de [child] mientras
/// el mouse está encima. Se pone a la derecha del objetivo (si no entra,
/// a la izquierda) y se corre hacia adentro para no salirse nunca de la
/// pantalla (margen [margin]). No toma el mouse. Ver docs/specs/panels.md
/// § "Comparar armas".
class RetroHoverCard extends StatefulWidget {
  const RetroHoverCard({
    super.key,
    required this.builder,
    required this.child,
    this.gap = 8,
    this.margin = 8,
  });

  /// Contenido; se arma recién al mostrarse.
  final WidgetBuilder builder;
  final Widget child;
  final double gap;
  final double margin;

  @override
  State<RetroHoverCard> createState() => _RetroHoverCardState();
}

class _RetroHoverCardState extends State<RetroHoverCard> {
  final _portal = OverlayPortalController();

  void _show() {
    if (!_portal.isShowing) _portal.show();
  }

  void _hide() {
    if (_portal.isShowing) _portal.hide();
  }

  Rect? _targetRect(BuildContext overlayContext) {
    final box = context.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || overlay is! RenderBox) {
      return null;
    }
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (ctx) {
        final rect = _targetRect(ctx);
        if (rect == null) return const SizedBox.shrink();
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomSingleChildLayout(
              delegate: _HoverLayout(rect, widget.gap, widget.margin),
              child: _box(ctx),
            ),
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _hide(),
        // Como el Tooltip: un clic o un arrastre lo esconde.
        child: Listener(
          onPointerDown: (_) => _hide(),
          child: widget.child,
        ),
      ),
    );
  }

  Widget _box(BuildContext ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ProtoColors.bg.withValues(alpha: 0xF5 / 0xFF),
          border: Border.all(
              color: ProtoColors.gold, width: RetroTheme.thinBorderWidth),
          boxShadow: const [
            BoxShadow(
                color: Color(0xAA000000), offset: Offset(0, 4), blurRadius: 18),
          ],
        ),
        // El overlay no hereda el estilo de texto del panel.
        child: DefaultTextStyle(
          style: RetroTooltip.textStyle,
          // Si no entrara en la pantalla se recorta (sin franjas de overflow).
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Builder(builder: widget.builder),
          ),
        ),
      );
}

/// Al lado de [target] (derecha, si no entra izquierda), dentro de la
/// pantalla con [margin].
class _HoverLayout extends SingleChildLayoutDelegate {
  _HoverLayout(this.target, this.gap, this.margin);

  final Rect target;
  final double gap;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(
        (constraints.maxWidth - 2 * margin).clamp(0, double.infinity),
        (constraints.maxHeight - 2 * margin).clamp(0, double.infinity),
      ));

  @override
  Offset getPositionForChild(Size size, Size child) {
    var x = target.right + gap;
    if (x + child.width > size.width - margin) {
      x = target.left - gap - child.width;
    }
    final maxX =
        (size.width - margin - child.width).clamp(margin, double.infinity);
    final maxY =
        (size.height - margin - child.height).clamp(margin, double.infinity);
    return Offset(x.clamp(margin, maxX), target.top.clamp(margin, maxY));
  }

  @override
  bool shouldRelayout(_HoverLayout old) =>
      old.target != target || old.gap != gap || old.margin != margin;
}
