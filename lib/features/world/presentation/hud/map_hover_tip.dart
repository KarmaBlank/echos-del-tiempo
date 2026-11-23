import 'package:flutter/widgets.dart';

/// Tooltip del mapa (ayudantes, carteles) junto al cursor, siempre dentro
/// de la pantalla: a la derecha y abajo del mouse; si no entra, del otro
/// lado. Cerca del borde de abajo sube sobre el cursor para no tapar ni
/// quedar tapado por la barra de herramienta y su aviso ([bottomReserve]).
class MapHoverTip extends StatelessWidget {
  const MapHoverTip({
    super.key,
    required this.cursor,
    required this.child,
    this.offset = 16,
    this.bottomReserve = 160,
  });

  final Offset cursor;
  final Widget child;
  final double offset;
  final double bottomReserve;

  @override
  Widget build(BuildContext context) => CustomSingleChildLayout(
        delegate: MapHoverTipLayout(cursor, offset, bottomReserve),
        child: child,
      );
}

/// Ubicación de [MapHoverTip] (pública para los tests).
class MapHoverTipLayout extends SingleChildLayoutDelegate {
  MapHoverTipLayout(this.cursor, this.offset, this.bottomReserve);

  final Offset cursor;
  final double offset;
  final double bottomReserve;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = cursor.dx + offset;
    if (x + childSize.width > size.width) {
      x = cursor.dx - offset - childSize.width;
    }
    var y = cursor.dy + offset;
    if (y + childSize.height > size.height - bottomReserve) {
      y = cursor.dy - offset - childSize.height;
    }
    final maxX = size.width - childSize.width,
        maxY = size.height - childSize.height;
    return Offset(
      x.clamp(0, maxX < 0 ? 0 : maxX).toDouble(),
      y.clamp(0, maxY < 0 ? 0 : maxY).toDouble(),
    );
  }

  @override
  bool shouldRelayout(MapHoverTipLayout old) =>
      old.cursor != cursor ||
      old.offset != offset ||
      old.bottomReserve != bottomReserve;
}
