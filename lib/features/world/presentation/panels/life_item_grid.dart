import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/retro_theme.dart';
import '../world_strings.dart';
import 'item_source_text.dart';

/// Detalle de un ítem de oficio (panel de la derecha): todo escrito
/// completo, nunca con "…".
class LifeItemDetail {
  const LifeItemDetail({
    required this.name,
    required this.nameColor,
    this.tags = const [],
    this.lines = const [],
    this.description,
    this.actions = const [],
    this.compare,
    this.hoverTip = false,
    this.itemId,
    this.cost,
    this.chips = const [],
    this.info,
  });

  /// Trade item id: adds its "where to get it" lines (item_sources.md).
  final String? itemId;

  /// What it costs, as an item grid ([itemCostGrid]); shown in the
  /// detail pane under a REQUIERE header.
  final Widget? cost;

  /// Compact chips (rewards, record): short label, color and the long
  /// text as tooltip (quest_audit.md § 8).
  final List<({String label, Color color, String? tip})> chips;

  /// Flavor or explanation behind a "?" chip next to the name.
  final String? info;

  /// Cambios contra la equipada del mismo tipo (texto, mejora); `null` =
  /// no aplica, vacío = es la equipada o igual.
  final List<(String, bool)>? compare;

  /// También como tooltip al pasar el mouse por la casilla.
  final bool hoverTip;

  final String name;
  final Color nameColor;

  /// Etiquetas (tipo, rareza, calidad) con su color.
  final List<(String, Color)> tags;

  /// Datos (nivel, rinde, rareza, precio, cantidad), uno por línea.
  final List<String> lines;
  final String? description;

  /// Botones (COMPRAR, VENDER, EQUIPAR...), con sus claves de siempre.
  final List<Widget> actions;
}

/// Una casilla de la grilla de oficios.
class LifeItemCellData {
  const LifeItemCellData({
    required this.id,
    required this.icon,
    required this.border,
    required this.search,
    required this.detail,
    this.count,
    this.caption,
    this.equipped = false,
  });

  /// Clave estable de la casilla (`ValueKey(id)`).
  final String id;

  /// Ícono de 32 px (LifeIcon).
  final Widget icon;

  /// Color de la rareza o calidad.
  final Color border;

  /// Texto para el buscador.
  final String search;
  final LifeItemDetail detail;

  /// Cantidad (abajo a la derecha).
  final int? count;

  /// Dato chico debajo de la casilla (precio, nivel).
  final String? caption;

  /// Marca EQUIPADA (arriba a la derecha).
  final bool equipped;
}

/// Grupo con título (CAÑAS, SEMILLAS...).
class LifeItemGroup {
  const LifeItemGroup(this.title, this.cells, {this.headerKey});
  final String? title;
  final List<LifeItemCellData> cells;
  final Key? headerKey;
}

/// Organismo: grilla de casillas de oficio (pesca, cultivo) con la misma
/// casilla que INVENTARIO (44 px, solo ícono y marco de rareza, ficha al
/// pasar el mouse) y el detalle de la elegida a la derecha. Varios grupos
/// con título se eligen con filtros arriba (nunca secciones apiladas).
/// Lo usan el AGROPECUARIO, PESCA Y CULTIVO y los menús de los NPC.
class LifeItemGrid extends StatefulWidget {
  const LifeItemGrid({
    super.key,
    required this.groups,
    required this.empty,
    this.emptyKey,
    this.extra,
    this.initial,
    this.maxDetail = detailWidth,
  });

  final List<LifeItemGroup> groups;

  /// Cell selected first (`null`: the first one).
  final String? initial;
  /// Widest the detail column gets (wide panels with few cells give it
  /// more room so there is no big empty area).
  final double maxDetail;

  /// Text shown when there are no cells.
  final String empty;
  final Key? emptyKey;

  /// Extra row above the grid (e.g. the barn).
  final Widget? extra;

  /// Cell (same as INVENTARIO), icon, gap and max detail width.
  static const cell = 44.0, iconSize = 32.0, gap = 4.0, detailWidth = 280.0;

  /// From this width on the detail goes to the right.
  static const wideFrom = 420.0;

  /// Detail column width for a given available width.
  static double detailFor(double maxWidth, [double max = detailWidth]) =>
      (maxWidth * 0.45).clamp(180.0, max);

  @override
  State<LifeItemGrid> createState() => _LifeItemGridState();
}

class _LifeItemGridState extends State<LifeItemGrid> {
  late String? _sel = widget.initial;

  /// Title of the group filter (`null`: all).
  String? _group;

  @override
  Widget build(BuildContext context) {
    final titled = [
      for (final g in widget.groups)
        if (g.title != null && g.cells.isNotEmpty) g
    ];
    final filters = titled.length > 1;
    final group =
        filters ? titled.where((g) => g.title == _group).firstOrNull : null;
    final all = group != null
        ? group.cells
        : [for (final g in widget.groups) ...g.cells];
    final sel = all.where((c) => c.id == _sel).firstOrNull ?? all.firstOrNull;
    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.extra != null) ...[
          widget.extra!,
          SizedBox(height: DsSpace.xs)
        ],
        if (filters) ...[
          Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
            DsButton(context.t('ui.town.trader.kind.all'),
                key: const ValueKey('life-group-all'),
                size: DsButtonSize.compact,
                selected: group == null,
                onPressed: () => setState(() => _group = null)),
            for (final g in titled)
              DsButton(g.title!,
                  key: g.headerKey,
                  size: DsButtonSize.compact,
                  selected: group == g,
                  onPressed: () => setState(() => _group = g.title)),
          ]),
          SizedBox(height: DsSpace.xs),
        ],
        if (all.isEmpty)
          Padding(
            padding: EdgeInsets.all(DsSpace.sm),
            child: Text(widget.empty,
                key: widget.emptyKey, style: DsText.detail()),
          )
        else
          Wrap(
            spacing: LifeItemGrid.gap,
            runSpacing: LifeItemGrid.gap,
            children: [
              for (final c in all)
                LifeItemCell(
                    data: c,
                    selected: c.id == sel?.id,
                    onTap: () => setState(() => _sel = c.id)),
            ],
          ),
      ],
    );
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= LifeItemGrid.wideFrom;
      final bounded = box.hasBoundedHeight;
      if (wide) {
        // Bounded: grid and detail fill the panel body; the detail keeps
        // its actions pinned at the bottom (DsDetailPane).
        return Row(
            crossAxisAlignment:
                bounded ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: bounded ? SingleChildScrollView(child: grid) : grid),
              if (sel != null) ...[
                SizedBox(width: DsSpace.sm),
                SizedBox(
                    width: LifeItemGrid.detailFor(
                        box.maxWidth, widget.maxDetail),
                    child: lifeDetailPane(context, sel)),
              ],
            ]);
      }
      final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sel != null) ...[
              lifeDetailPane(context, sel),
              SizedBox(height: DsSpace.sm),
            ],
            grid,
          ]);
      return bounded ? SingleChildScrollView(child: column) : column;
    });
  }
}

/// Detail of a trade cell: info scrolls, actions pinned (DsDetailPane).
/// Inside an unbounded height (narrow, stacked) it takes its natural size.
Widget lifeDetailPane(BuildContext context, LifeItemCellData c) {
  final d = c.detail;
  final body = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        c.icon,
        SizedBox(width: DsSpace.sm),
        Expanded(
          child: Text(d.name,
              key: const ValueKey('life-detail-name'),
              style: DsText.subtitle(d.nameColor)),
        ),
        if (d.info case final i?) ...[
          SizedBox(width: DsSpace.xs),
          DsChip('?',
              key: const ValueKey('life-detail-info'),
              color: DsColors.textSecondary,
              tip: i),
        ],
      ]),
      if (d.tags.isNotEmpty) ...[
        SizedBox(height: DsSpace.xs),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final (t, col) in d.tags) DsTag(t, color: col),
        ]),
      ],
      SizedBox(height: DsSpace.xs),
      for (final l in lifeDetailLines(context, d)) Text(l, style: DsText.body()),
      if (d.cost case final cost?) ...[
        SizedBox(height: DsSpace.sm),
        Text(context.t('ui.town.source.requires'),
            style: DsText.subtitle(DsColors.textSecondary)),
        SizedBox(height: DsSpace.xs),
        cost,
      ],
      ...lifeChips(d),
      ...lifeCompareLines(context, d),
      if (d.description != null) ...[
        SizedBox(height: DsSpace.xs),
        Text(d.description!, style: DsText.detail()),
      ],
    ],
  );
  final actions = d.actions.isEmpty
      ? null
      : Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: d.actions);
  return DsDetailPane(
      key: const ValueKey('life-detail'), body: body, actions: actions);
}

/// Data lines of a detail plus, with [LifeItemDetail.itemId], where the
/// item is obtained.
List<String> lifeDetailLines(BuildContext context, LifeItemDetail d) => [
      ...d.lines,
      if (d.itemId case final id?) ...itemSourceLines(context, id),
    ];

/// The chips row of a detail (empty when it has none).
List<Widget> lifeChips(LifeItemDetail d) => d.chips.isEmpty
    ? const []
    : [
        SizedBox(height: DsSpace.xs),
        Wrap(
          key: const ValueKey('life-detail-chips'),
          spacing: DsSpace.xs,
          runSpacing: DsSpace.xs,
          children: [
            for (final c in d.chips) DsChip(c.label, color: c.color, tip: c.tip)
          ],
        ),
      ];

/// "vs equipped" lines of a detail (empty when not applicable).
List<Widget> lifeCompareLines(BuildContext context, LifeItemDetail d) {
  final cmp = d.compare;
  if (cmp == null || cmp.isEmpty) return const [];
  return [
    SizedBox(height: DsSpace.xs),
    Text(context.t('ui.town.trades.vs_equipped'), style: DsText.detail()),
    for (final (t, better) in cmp)
      Text(t, style: DsText.body(better ? DsColors.success : DsColors.danger)),
  ];
}

/// Standard hover card of a trade cell: name, tags, data lines.
Widget lifeTooltipCard(BuildContext context, LifeItemDetail d) => DsTooltipCard(
      title: d.name,
      titleColor: d.nameColor,
      tags: [for (final (t, col) in d.tags) DsTag(t, color: col)],
      children: [
        for (final l in lifeDetailLines(context, d))
          Text(l, style: DsText.body()),
        ...lifeChips(d),
        ...lifeCompareLines(context, d),
      ],
    );

/// Molécula: casilla de oficio igual a la de INVENTARIO (44 px, ícono,
/// marco de rareza, cantidad abajo y E de equipada), sin texto debajo;
/// el nombre y los datos van en la ficha estándar al pasar el mouse.
class LifeItemCell extends StatelessWidget {
  const LifeItemCell(
      {super.key, required this.data, this.selected = false, this.onTap});

  final LifeItemCellData data;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const s = LifeItemGrid.cell;
    final c = data;
    final fixed = RetroType.fixedScaler(context);
    final box = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: ProtoColors.input,
        border: Border.all(
            color: selected ? ProtoColors.gold : c.border,
            width: selected ? 3 : RetroTheme.thinBorderWidth),
      ),
      child: Stack(children: [
        Center(child: c.icon),
        if (c.equipped)
          Positioned(
            right: 2,
            top: 1,
            child: Text('E',
                key: ValueKey('${c.id}-equipped'),
                textScaler: fixed,
                style: const TextStyle(
                    fontFamily: RetroType.pixelFamily,
                    fontSize: RetroType.label,
                    height: 1,
                    color: ProtoColors.gold,
                    shadows: [Shadow(offset: Offset(1, 1))])),
          ),
        if (c.count != null)
          Positioned(
            right: 2,
            bottom: 0,
            child: Text(c.count.toString(),
                textScaler: fixed,
                style: const TextStyle(
                    fontFamily: RetroType.pixelFamily,
                    fontSize: RetroType.label,
                    color: ProtoColors.ink,
                    shadows: [Shadow(offset: Offset(1, 1))])),
          ),
      ]),
    );
    return GestureDetector(
      key: ValueKey(c.id),
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: DsTooltip(
            card: lifeTooltipCard(context, c.detail),
            child: KeyedSubtree(key: ValueKey('${c.id}-tip'), child: box)),
      ),
    );
  }
}
