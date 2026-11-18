import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';
import 'proto_markup.dart';
import 'retro_theme.dart';

/// Dónde aparece la caja respecto de lo que se señala.
enum RetroTipPlacement {
  /// A la derecha (si no entra, a la izquierda), alineada arriba. Fichas
  /// grandes (comparación de armas).
  side,

  /// Debajo y centrada (si no entra, arriba), como el `#tip` del
  /// prototipo y el `Tooltip` de Flutter.
  below,
}

/// Caja del `#tip` (docs/specs/ui_style.md § "Tooltips") con lo que arme
/// [builder], al lado de [child] mientras el mouse está encima. No toma
/// el mouse; un clic la esconde.
///
/// Nunca se sale de la pantalla (margen [margin]): se corre hacia adentro
/// y, si es más alta que la pantalla, primero el texto se reparte en
/// columnas ([RetroTipText]) y, como último recurso, se achica lo justo
/// para entrar (sin recortar nada). Ver docs/specs/panels.md § "Comparar
/// armas".
class RetroHoverCard extends StatefulWidget {
  const RetroHoverCard({
    super.key,
    required this.builder,
    required this.child,
    this.gap = 8,
    this.margin = 8,
    this.placement = RetroTipPlacement.side,
  });

  /// Contenido; se arma recién al mostrarse.
  final WidgetBuilder builder;
  final Widget child;
  final double gap;
  final double margin;
  final RetroTipPlacement placement;

  /// Texto del `#tip`: lectura ([RetroType.small], VT323) `#e8ecff`.
  static TextStyle get textStyle => TextStyle(
      fontFamily: RetroType.bodyFamily,
      fontFamilyFallback: RetroType.bodyFallback,
      fontSize: RetroType.small,
      height: RetroType.line,
      color: ProtoColors.ink);

  /// Ancho máximo del texto de un tip en Normal (~45 letras de VT323);
  /// crece con el tamaño del texto ([RetroType.width]).
  static const textWidth = 360.0;

  /// Padding interno de la caja (8 × 10 del `#tip`) + borde.
  static const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);

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
              delegate: _HoverLayout(rect, widget.gap, widget.margin,
                  widget.placement, MediaQuery.devicePixelRatioOf(ctx)),
              child: _box(ctx),
            ),
          ),
        );
      },
      // Con el teclado: aparece mientras el foco está en el objetivo (o
      // adentro), como con el mouse (docs/specs/panels.md § "Teclado").
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => f &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional
            ? _show()
            : _hide(),
        child: MouseRegion(
          onEnter: (_) => _show(),
          onExit: (_) => _hide(),
          // Como el Tooltip: un clic o un arrastre lo esconde.
          child: Listener(
            onPointerDown: (_) => _hide(),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _box(BuildContext ctx) => Container(
        padding: RetroHoverCard.padding,
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
          style: RetroHoverCard.textStyle,
          child: LayoutBuilder(
            builder: (context, c) => FittedBox(
              // Último recurso: si ni en columnas entra, se achica.
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth),
                child: RetroTipBounds(
                  maxHeight: c.maxHeight,
                  child: Builder(builder: widget.builder),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Alto disponible dentro de la caja de un tip (la pantalla menos los
/// márgenes y el padding), para que el contenido se reparta en columnas.
class RetroTipBounds extends InheritedWidget {
  const RetroTipBounds(
      {super.key, required this.maxHeight, required super.child});

  final double maxHeight;

  static double? maxHeightOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RetroTipBounds>()?.maxHeight;

  @override
  bool updateShouldNotify(RetroTipBounds old) => old.maxHeight != maxHeight;
}

/// Texto de un tip (markup, `ProtoMarkup`) de ancho máximo [maxWidth]
/// (ya agrandado por el tamaño del texto). Si no entra en el alto de la
/// pantalla se reparte en columnas, cortando en los `<br>`.
class RetroTipText extends StatelessWidget {
  const RetroTipText(this.markup, {super.key, required this.maxWidth});

  final String markup;
  final double maxWidth;

  /// Separación entre columnas.
  static const columnGap = 16.0;

  @override
  Widget build(BuildContext context) {
    final maxH = RetroTipBounds.maxHeightOf(context);
    final text = ProtoText(markup);
    if (maxH == null || !maxH.isFinite) {
      return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth), child: text);
    }
    final lines = protoSplitLines(markup);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Wrap(
        direction: Axis.vertical,
        runSpacing: columnGap,
        children: [
          for (final l in lines)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ProtoText(l),
            ),
        ],
      ),
    );
  }
}

/// Al lado de [target] ([RetroTipPlacement.side]: derecha, si no entra
/// izquierda; [RetroTipPlacement.below]: debajo centrada, si no entra
/// arriba), siempre dentro de la pantalla con [margin].
class _HoverLayout extends SingleChildLayoutDelegate {
  _HoverLayout(this.target, this.gap, this.margin, this.placement, this.dpr);

  final Rect target;
  final double gap;
  final double margin;
  final RetroTipPlacement placement;

  /// Para caer en px físicos enteros: la fuente pixel se ve nítida solo
  /// si el texto arranca en un píxel entero.
  final double dpr;

  double _px(double v) => (v * dpr).roundToDouble() / dpr;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(
        (constraints.maxWidth - 2 * margin).clamp(0, double.infinity),
        (constraints.maxHeight - 2 * margin).clamp(0, double.infinity),
      ));

  @override
  Offset getPositionForChild(Size size, Size child) {
    final maxX =
        (size.width - margin - child.width).clamp(margin, double.infinity);
    final maxY =
        (size.height - margin - child.height).clamp(margin, double.infinity);
    double x, y;
    switch (placement) {
      case RetroTipPlacement.side:
        x = target.right + gap;
        if (x + child.width > size.width - margin) {
          x = target.left - gap - child.width;
        }
        y = target.top;
      case RetroTipPlacement.below:
        x = target.center.dx - child.width / 2;
        y = target.bottom + gap;
        if (y + child.height > size.height - margin) {
          final above = target.top - gap - child.height;
          // Arriba si entra; si no, del lado con más lugar (y se corre).
          y = above >= margin || target.top > size.height - target.bottom
              ? above
              : y;
        }
    }
    return Offset(_px(x.clamp(margin, maxX)), _px(y.clamp(margin, maxY)));
  }

  @override
  bool shouldRelayout(_HoverLayout old) =>
      old.target != target ||
      old.gap != gap ||
      old.margin != margin ||
      old.placement != placement ||
      old.dpr != dpr;
}
