import 'package:material_ui/material_ui.dart';

import '../theme/retro_theme.dart';
import 'ds_button.dart';
import 'ds_components.dart';
import 'ds_tokens.dart';

/// Plantilla TRASPASO (docs/specs/ui_minimal.md § 9): dos grillas de
/// casillas (izquierda = lo tuyo, derecha = el otro contenedor), filtros
/// y búsqueda compartidos arriba, botones de pasar en el medio y una línea
/// con el ítem elegido abajo. Solo dibuja: los datos y las acciones
/// llegan por parámetros y callbacks.

/// De qué lado está una casilla.
enum DsTransferSide { left, right }

/// Una casilla de la plantilla.
class DsTransferItem {
  const DsTransferItem({
    required this.id,
    required this.icon,
    required this.name,
    required this.border,
    required this.count,
    this.search,
    this.tag,
    this.info,
  });

  /// Clave estable (también arma la `ValueKey` de la casilla).
  final String id;

  /// Ícono de 32 px.
  final Widget icon;
  final String name;

  /// Color de la rareza o calidad (borde y nombre en la línea de info).
  final Color border;
  final int count;

  /// Texto del buscador (por defecto [name]).
  final String? search;

  /// Valor que miran los filtros (p. ej. la rareza).
  final String? tag;

  /// Dato corto en la línea de abajo ("La huerta tiene 3").
  final String? info;
}

/// Filtro de chip: [tag] `null` = todas.
class DsTransferFilter {
  const DsTransferFilter(this.label, this.tag);
  final String label;
  final String? tag;
}

/// Casilla de ítem (átomo): ícono, borde de rareza y cantidad.
class DsItemCell extends StatelessWidget {
  const DsItemCell({
    super.key,
    required this.icon,
    required this.border,
    this.count,
    this.selected = false,
    this.onTap,
  });

  static const size = 48.0;

  final Widget icon;
  final Color border;
  final int? count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fixed = RetroType.fixedScaler(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: DsColors.surfaceSunken,
            border: Border.all(
                color: selected ? DsColors.selected : border,
                width: selected ? 3 : RetroTheme.thinBorderWidth),
          ),
          child: Stack(children: [
            Center(child: icon),
            if (count != null)
              Positioned(
                right: 2,
                bottom: 0,
                child: Text('$count',
                    textScaler: fixed,
                    style: DsText.detail(DsColors.textPrimary).copyWith(
                        fontSize: RetroType.label,
                        shadows: const [Shadow(offset: Offset(1, 1))])),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Plantilla TRASPASO entre dos contenedores.
class DsTransferTemplate extends StatefulWidget {
  const DsTransferTemplate({
    super.key,
    required this.keyPrefix,
    required this.leftTitle,
    required this.rightTitle,
    required this.left,
    required this.right,
    required this.onMove,
    this.canMove,
    this.filters = const [],
    this.searchHint = 'BUSCAR',
    this.quantities = const [1, 0],
    this.leftEmpty = 'Vacío.',
    this.rightEmpty = 'Vacío.',
    this.allowLeftToRight = true,
    this.allowRightToLeft = true,
    this.extraActions = const [],
    this.gridHeight = 240,
  });

  /// Prefijo de las claves: `<p>-cell-l-<id>`, `<p>-give-1`,
  /// `<p>-give-TODO`, `<p>-take-1`, `<p>-take-TODO`, `<p>-search`,
  /// `<p>-filter-<i>`, `<p>-info`.
  final String keyPrefix;
  final String leftTitle;
  final String rightTitle;
  final List<DsTransferItem> left;
  final List<DsTransferItem> right;

  /// Mover [qty] (0 = todo) del ítem [id] desde [from] al otro lado.
  final void Function(DsTransferSide from, String id, int qty) onMove;

  /// Motivo para no poder mover (botón gris con tooltip); `null` = se puede.
  final String? Function(DsTransferSide from, String id)? canMove;
  final List<DsTransferFilter> filters;
  final String searchHint;

  /// Cantidades de los botones (0 = TODO).
  final List<int> quantities;
  final String leftEmpty;
  final String rightEmpty;
  final bool allowLeftToRight;
  final bool allowRightToLeft;

  /// Botones extra abajo (RECOGER TODO...).
  final List<Widget> extraActions;
  final double gridHeight;

  @override
  State<DsTransferTemplate> createState() => _DsTransferTemplateState();
}

class _DsTransferTemplateState extends State<DsTransferTemplate> {
  String _query = '';
  int _filter = 0;
  DsTransferSide? _side;
  String? _id;

  bool _pass(DsTransferItem it) {
    if (widget.filters.isNotEmpty) {
      final t = widget.filters[_filter.clamp(0, widget.filters.length - 1)].tag;
      if (t != null && it.tag != t) return false;
    }
    final q = _query.toLowerCase();
    return q.isEmpty || (it.search ?? it.name).toLowerCase().contains(q);
  }

  List<DsTransferItem> _items(DsTransferSide s) =>
      (s == DsTransferSide.left ? widget.left : widget.right)
          .where((i) => i.count > 0 && _pass(i))
          .toList();

  DsTransferItem? _selected() {
    final s = _side;
    if (s == null) return null;
    return _items(s).where((i) => i.id == _id).firstOrNull;
  }

  String _p(String s) => '${widget.keyPrefix}-$s';

  Widget _pane(DsTransferSide s, String title, String empty) {
    final items = _items(s);
    final all = s == DsTransferSide.left ? widget.left : widget.right;
    final total = all.fold<int>(0, (a, i) => a + i.count);
    final sel = _selected();
    final tag = s == DsTransferSide.left ? 'l' : 'r';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsSectionHeader(title,
            key: ValueKey(_p('title-$tag')),
            trailing: DsBadge('$total')),
        SizedBox(height: DsSpace.xs),
        Container(
          height: widget.gridHeight,
          decoration: BoxDecoration(
              border: Border.all(
                  color: DsColors.border, width: RetroTheme.thinBorderWidth)),
          padding: EdgeInsets.all(DsSpace.xs),
          child: items.isEmpty
              ? Text(empty, style: DsText.detail())
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: DsSpace.xs,
                    runSpacing: DsSpace.xs,
                    children: [
                      for (final it in items)
                        DsItemCell(
                          key: ValueKey(_p('cell-$tag-${it.id}')),
                          icon: it.icon,
                          border: it.border,
                          count: it.count,
                          selected: sel != null &&
                              _side == s &&
                              sel.id == it.id,
                          onTap: () => setState(() {
                            _side = s;
                            _id = it.id;
                          }),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _moveButton(DsTransferSide from, int q) {
    final right = from == DsTransferSide.left;
    final allowed = right ? widget.allowLeftToRight : widget.allowRightToLeft;
    final ql = q == 0 ? 'TODO' : '$q';
    final sel = _selected();
    String? why;
    if (!allowed) {
      why = null;
    } else if (sel == null || _side != from) {
      why = null;
    } else {
      why = widget.canMove?.call(from, sel.id);
    }
    final enabled =
        allowed && sel != null && _side == from && why == null;
    return SizedBox(
      width: 132,
      child: DsButton(right ? 'PASAR $ql →' : '← PASAR $ql',
          key: ValueKey(_p('${right ? 'give' : 'take'}-$ql')),
          size: DsButtonSize.compact,
          kind: right ? DsButtonKind.primary : DsButtonKind.secondary,
          tooltip: why,
          onPressed: enabled
              ? () => widget.onMove(from, sel.id, q)
              : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          DsSearchField(
              key: ValueKey(_p('search')),
              hint: widget.searchHint,
              width: 200,
              onChanged: (v) => setState(() => _query = v)),
          SizedBox(width: DsSpace.sm),
          Expanded(
            child: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              for (var i = 0; i < widget.filters.length; i++)
                DsButton(widget.filters[i].label,
                    key: ValueKey(_p('filter-$i')),
                    size: DsButtonSize.compact,
                    selected: _filter == i,
                    onPressed: () => setState(() => _filter = i)),
            ]),
          ),
        ]),
        SizedBox(height: DsSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _pane(
                    DsTransferSide.left, widget.leftTitle, widget.leftEmpty)),
            SizedBox(width: DsSpace.sm),
            Padding(
              padding: EdgeInsets.only(top: DsSpace.xl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.allowLeftToRight)
                  for (final q in widget.quantities) ...[
                    _moveButton(DsTransferSide.left, q),
                    SizedBox(height: DsSpace.xs),
                  ],
                if (widget.allowRightToLeft)
                  for (final q in widget.quantities) ...[
                    _moveButton(DsTransferSide.right, q),
                    SizedBox(height: DsSpace.xs),
                  ],
                for (final w in widget.extraActions) ...[
                  SizedBox(width: 132, child: w),
                  SizedBox(height: DsSpace.xs),
                ],
              ]),
            ),
            SizedBox(width: DsSpace.sm),
            Expanded(
                child: _pane(DsTransferSide.right, widget.rightTitle,
                    widget.rightEmpty)),
          ],
        ),
        SizedBox(height: DsSpace.xs),
        Text(
          sel == null
              ? 'Elegí un ítem de cualquiera de los dos lados.'
              : '${sel.name} ×${sel.count}'
                  '${sel.info == null ? '' : ' · ${sel.info}'}',
          key: ValueKey(_p('info')),
          style: sel == null ? DsText.detail() : DsText.body(sel.border),
        ),
      ],
    );
  }
}
