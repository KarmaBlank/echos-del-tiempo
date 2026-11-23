import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'ds_button.dart';
import 'ds_tokens.dart';

/// Carrusel horizontal (design_system.md): tantos ítems como entren en el
/// ancho, con el elegido lo más centrado posible, y flechas anterior /
/// siguiente a los costados. Los ítems los arma quien lo usa
/// ([itemBuilder]); el carrusel solo decide cuáles se ven.
class DsCarousel extends StatelessWidget {
  const DsCarousel({
    super.key,
    required this.itemCount,
    required this.index,
    required this.itemExtent,
    required this.itemBuilder,
    this.onChanged,
    this.selectableCount,
  });

  /// Total de ítems (incluidos los que no se eligen, p. ej. "+ NUEVO").
  final int itemCount;

  /// El elegido (el que se intenta centrar).
  final int index;

  /// Ancho de cada ítem, ya escalado.
  final double itemExtent;
  final IndexedWidgetBuilder itemBuilder;

  /// Las flechas eligen el anterior / siguiente (`null`: deshabilitadas).
  final ValueChanged<int>? onChanged;

  /// Cuántos de los primeros ítems eligen las flechas (por defecto, todos).
  final int? selectableCount;

  @override
  Widget build(BuildContext context) {
    final gap = DsSpace.md;
    final selectable = selectableCount ?? itemCount;
    final cb = onChanged;
    return Row(
      key: const ValueKey('carousel'),
      children: [
        DsButton.icon(const Text('<'),
            key: const ValueKey('carousel-prev'),
            tooltip: 'Anterior',
            onPressed: cb == null || index <= 0 ? null : () => cb(index - 1)),
        SizedBox(width: gap),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final fit = math.max(
                1, ((c.maxWidth + gap) / (itemExtent + gap)).floor());
            final visible = math.min(fit, itemCount);
            final start = math.max(
                0, math.min(index - visible ~/ 2, itemCount - visible));
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = start; i < start + visible; i++) ...[
                  if (i > start) SizedBox(width: gap),
                  SizedBox(width: itemExtent, child: itemBuilder(context, i)),
                ],
              ],
            );
          }),
        ),
        SizedBox(width: gap),
        DsButton.icon(const Text('>'),
            key: const ValueKey('carousel-next'),
            tooltip: 'Siguiente',
            onPressed: cb == null || index >= selectable - 1
                ? null
                : () => cb(index + 1)),
      ],
    );
  }
}
