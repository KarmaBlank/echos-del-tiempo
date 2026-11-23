import 'package:material_ui/material_ui.dart';

import '../theme/retro_text.dart';
import 'ds_tokens.dart';

/// Una columna de [DsColumnsTemplate].
class DsColumn {
  const DsColumn({
    required this.header,
    required this.child,
    this.scrollable = true,
    this.key,
  });

  /// Encabezado (va en mayúsculas).
  final String header;
  final Widget child;

  /// `false`: el contenido queda fijo (no scrollea).
  final bool scrollable;

  /// Clave del cuerpo de la columna (tests).
  final Key? key;
}

/// Plantilla COLUMNAS (docs/specs/ui_minimal.md § 9.3): N columnas del
/// mismo ancho, con encabezado, línea vertical entre columnas y scroll
/// propio en cada una. Solo dibuja: el contenido llega por parámetro.
class DsColumnsTemplate extends StatefulWidget {
  const DsColumnsTemplate({super.key, required this.columns});

  final List<DsColumn> columns;

  @override
  State<DsColumnsTemplate> createState() => _DsColumnsTemplateState();
}

class _DsColumnsTemplateState extends State<DsColumnsTemplate> {
  final _scrolls = <ScrollController>[];

  @override
  void dispose() {
    for (final c in _scrolls) {
      c.dispose();
    }
    super.dispose();
  }

  ScrollController _scroll(int i) {
    while (_scrolls.length <= i) {
      _scrolls.add(ScrollController());
    }
    return _scrolls[i];
  }

  @override
  Widget build(BuildContext context) {
    final cols = widget.columns;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: DsColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cols.length; i++) ...[
            if (i > 0) Container(width: 1, color: DsColors.border),
            Expanded(child: _column(i, cols[i])),
          ],
        ],
      ),
    );
  }

  Widget _column(int i, DsColumn c) {
    final pad = EdgeInsets.all(DsSpace.sm);
    final body = c.scrollable
        ? Scrollbar(
            controller: _scroll(i),
            thumbVisibility: true,
            child: SingleChildScrollView(
                controller: _scroll(i), padding: pad, child: c.child))
        // Fija: no scrollea; si no entra, se recorta sin desbordar.
        : SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: pad,
            child: c.child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: ValueKey('ds-column-header-$i'),
          padding: EdgeInsets.symmetric(
              horizontal: DsSpace.sm, vertical: DsSpace.xs),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DsColors.border))),
          child: Text(retroText(c.header.toUpperCase()),
              style: DsText.subtitle(), softWrap: true),
        ),
        Expanded(child: KeyedSubtree(key: c.key, child: body)),
      ],
    );
  }
}
