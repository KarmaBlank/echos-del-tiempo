import 'package:material_ui/material_ui.dart';

import 'ds_button.dart';
import 'ds_components.dart';
import 'ds_detail_pane.dart';
import 'ds_tokens.dart';
import 'ds_transfer_template.dart' show DsItemCell, DsTransferFilter;

/// Plantilla TALLER (docs/specs/ui_minimal.md § 4.1, v0.32.3): chips de
/// filtro arriba, grilla de casillas estilo INVENTARIO y el detalle de la
/// elegida a la derecha (arriba si la columna es angosta). Solo dibuja:
/// recetas, textos y botones llegan por parámetros.

/// Una receta de la grilla.
class DsCraftItem {
  const DsCraftItem({
    required this.id,
    required this.icon,
    required this.border,
    required this.name,
    this.tag,
    this.search,
    this.count,
    this.description,
    this.lines = const [],
    this.actions = const [],
    this.cellWrap,
    this.body,
  });

  /// Wraps the grid cell (e.g. a hover tooltip); the template stays
  /// agnostic of what the tooltip shows.
  final Widget Function(Widget cell)? cellWrap;

  /// Rich detail content, drawn under [description] and above [lines].
  final Widget? body;

  /// Clave estable: la casilla es `<prefijo>-cell-<id>`.
  final String id;

  /// Ícono de 32 px.
  final Widget icon;
  final Color border;
  final String name;

  /// Valor que miran los filtros (el oficio).
  final String? tag;

  /// Texto del buscador (por defecto [name]).
  final String? search;

  /// Cuántos tenés (abajo a la derecha de la casilla).
  final int? count;
  final String? description;

  /// Datos del detalle, uno por línea (receta, cuántos alcanzan).
  final List<String> lines;

  /// Botones del detalle (abajo).
  final List<Widget> actions;
}

/// Detalle de una receta (organismo): nombre, descripción, datos y botones.
/// Sobre [DsDetailPane]: los botones quedan FIJOS abajo y solo el texto
/// se desplaza (mining_smithing.md § 8: el botón principal se cortaba).
class DsCraftDetail extends StatelessWidget {
  const DsCraftDetail(this.item, {super.key});

  final DsCraftItem item;

  @override
  Widget build(BuildContext context) => DsDetailPane(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.name, style: DsText.subtitle(DsColors.textTitle)),
            if (item.description != null) ...[
              SizedBox(height: DsSpace.xs),
              Text(item.description!, style: DsText.detail()),
            ],
            if (item.body != null) ...[
              SizedBox(height: DsSpace.xs),
              item.body!,
            ],
            SizedBox(height: DsSpace.xs),
            for (final l in item.lines) Text(l, style: DsText.body()),
          ],
        ),
        actions: item.actions.isEmpty
            ? null
            : Wrap(
                spacing: DsSpace.xs,
                runSpacing: DsSpace.xs,
                children: item.actions),
      );
}

/// Plantilla TALLER: filtros + grilla + detalle.
class DsCraftGridTemplate extends StatefulWidget {
  const DsCraftGridTemplate({
    super.key,
    required this.keyPrefix,
    required this.items,
    this.filters = const [],
    this.empty = 'Nada para hacer.',
    this.searchHint,
    this.side,
  });

  /// Optional left column (`<p>-side`), rebuilt with the item under the
  /// mouse, or the selected one when nothing is hovered.
  final Widget Function(DsCraftItem? focus)? side;

  /// Con texto, buscador arriba de los chips (`<p>-search`).
  final String? searchHint;

  /// Prefijo de las claves: `<p>-filter-<i>`, `<p>-cell-<id>`,
  /// `<p>-detail`, `<p>-empty`.
  final String keyPrefix;
  final List<DsCraftItem> items;
  final List<DsTransferFilter> filters;
  final String empty;

  /// Ancho del detalle y desde qué ancho va al costado.
  static const detailWidth = 300.0, wideFrom = 560.0;

  @override
  State<DsCraftGridTemplate> createState() => _DsCraftGridTemplateState();
}

class _DsCraftGridTemplateState extends State<DsCraftGridTemplate> {
  int _filter = 0;
  String? _id;
  String _query = '';

  String? _hoverId;

  String _p(String s) => '${widget.keyPrefix}-$s';

  Widget _cell(DsCraftItem i, DsCraftItem? sel) {
    Widget cell = DsItemCell(
      key: ValueKey(_p('cell-${i.id}')),
      icon: i.icon,
      border: i.border,
      count: i.count,
      selected: i.id == sel?.id,
      onTap: () => setState(() => _id = i.id),
    );
    if (i.cellWrap != null) cell = i.cellWrap!(cell);
    if (widget.side == null) return cell;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoverId = i.id),
      onExit: (_) {
        if (_hoverId == i.id) setState(() => _hoverId = null);
      },
      child: cell,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.filters.isEmpty ? null : widget.filters[_filter].tag;
    final shown = [
      for (final i in widget.items)
        if ((tag == null || i.tag == tag) &&
            (_query.isEmpty ||
                (i.search ?? i.name).toLowerCase().contains(_query)))
          i
    ];
    final sel = shown.where((i) => i.id == _id).firstOrNull ??
        shown.firstOrNull;
    final grid = shown.isEmpty
        ? Text(widget.empty,
            key: ValueKey(_p('empty')), style: DsText.detail())
        : Wrap(
            spacing: DsSpace.xs,
            runSpacing: DsSpace.xs,
            children: [
              for (final i in shown) _cell(i, sel),
            ],
          );
    final detail = sel == null
        ? null
        : KeyedSubtree(
            key: ValueKey(_p('detail')), child: DsCraftDetail(sel));
    final focus = shown.where((i) => i.id == _hoverId).firstOrNull ?? sel;
    final side = widget.side == null
        ? null
        : KeyedSubtree(key: ValueKey(_p('side')), child: widget.side!(focus));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.searchHint != null || widget.filters.length > 1) ...[
          Wrap(
              spacing: DsSpace.xs,
              runSpacing: DsSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
            if (widget.searchHint != null)
              DsSearchField(
                  key: ValueKey(_p('search')),
                  hint: widget.searchHint!,
                  width: 200,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase())),
            if (widget.filters.length > 1)
            for (var i = 0; i < widget.filters.length; i++)
              DsButton(widget.filters[i].label,
                  key: ValueKey(_p('filter-$i')),
                  size: DsButtonSize.compact,
                  selected: _filter == i,
                  onPressed: () => setState(() => _filter = i)),
          ]),
          SizedBox(height: DsSpace.sm),
        ],
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            if (box.maxWidth >= DsCraftGridTemplate.wideFrom) {
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (side != null) ...[
                      SingleChildScrollView(child: side),
                      SizedBox(width: DsSpace.sm),
                    ],
                    Expanded(child: SingleChildScrollView(child: grid)),
                    if (detail != null) ...[
                      SizedBox(width: DsSpace.sm),
                      SizedBox(
                          width: DsCraftGridTemplate.detailWidth,
                          height: box.maxHeight,
                          child: detail),
                    ],
                  ]);
            }
            return SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (detail != null) ...[
                      detail,
                      SizedBox(height: DsSpace.sm)
                    ],
                    if (side != null) ...[
                      Align(alignment: Alignment.topLeft, child: side),
                      SizedBox(height: DsSpace.sm),
                    ],
                    grid,
                  ]),
            );
          }),
        ),
      ],
    );
  }
}
