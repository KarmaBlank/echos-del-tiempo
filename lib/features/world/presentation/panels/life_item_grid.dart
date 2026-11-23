import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/retro_theme.dart';
import '../world_strings.dart';

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
  });

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

/// Organismo: grilla de casillas de oficio (pesca, cultivo) estilo
/// inventario, con el detalle de la elegida a la derecha (o arriba si la
/// columna es angosta). Lo usan el AGROPECUARIO y PESCA Y CULTIVO.
class LifeItemGrid extends StatefulWidget {
  const LifeItemGrid({
    super.key,
    required this.groups,
    required this.empty,
    this.emptyKey,
    this.extra,
  });

  final List<LifeItemGroup> groups;

  /// Texto cuando no hay casillas.
  final String empty;
  final Key? emptyKey;

  /// Fila extra arriba de la grilla (p. ej. el granero).
  final Widget? extra;

  /// Casilla, ícono y ancho del detalle.
  static const cell = 48.0, iconSize = 32.0, detailWidth = 280.0;

  /// Desde este ancho el detalle va al costado.
  static const wideFrom = 560.0;

  @override
  State<LifeItemGrid> createState() => _LifeItemGridState();
}

class _LifeItemGridState extends State<LifeItemGrid> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final all = [for (final g in widget.groups) ...g.cells];
    final sel = all.where((c) => c.id == _sel).firstOrNull ?? all.firstOrNull;
    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.extra != null) ...[
          widget.extra!,
          SizedBox(height: DsSpace.xs)
        ],
        if (all.isEmpty)
          Padding(
            padding: EdgeInsets.all(DsSpace.sm),
            child: Text(widget.empty,
                key: widget.emptyKey, style: DsText.detail()),
          ),
        for (final g in widget.groups)
          if (g.cells.isNotEmpty) ...[
            if (g.title != null)
              DsSectionHeader(g.title!,
                  key: g.headerKey,
                  trailing: DsBadge(g.cells.length.toString(), neutral: true)),
            Wrap(
              spacing: DsSpace.xs,
              runSpacing: DsSpace.xs,
              children: [for (final c in g.cells) _cell(c, c.id == sel?.id)],
            ),
            SizedBox(height: DsSpace.sm),
          ],
      ],
    );
    final detail = sel == null ? null : _detail(sel);
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= LifeItemGrid.wideFrom;
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: SingleChildScrollView(child: grid)),
          if (detail != null) ...[
            SizedBox(width: DsSpace.sm),
            SizedBox(
                width: LifeItemGrid.detailWidth,
                child: SingleChildScrollView(child: detail)),
          ],
        ]);
      }
      return SingleChildScrollView(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (detail != null) ...[detail, SizedBox(height: DsSpace.sm)],
          grid,
        ]),
      );
    });
  }

  Widget _cell(LifeItemCellData c, bool selected) {
    const s = LifeItemGrid.cell;
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
    final tipped = c.detail.hoverTip ? DsTooltip(card: _tip(c), child: box) : box;
    return GestureDetector(
      key: ValueKey(c.id),
      onTap: () => setState(() => _sel = c.id),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: s + DsSpace.md,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            tipped,
            if (c.caption != null)
              Text(c.caption!,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: DsText.detail()),
          ]),
        ),
      ),
    );
  }

  List<Widget> _compare(LifeItemDetail d) {
    final cmp = d.compare;
    if (cmp == null || cmp.isEmpty) return const [];
    return [
      SizedBox(height: DsSpace.xs),
      Text(context.t('ui.town.trades.vs_equipped'), style: DsText.detail()),
      for (final (t, better) in cmp)
        Text(t,
            style: DsText.body(better ? DsColors.success : DsColors.danger)),
    ];
  }

  Widget _tip(LifeItemCellData c) {
    final d = c.detail;
    return DsTooltipCard(
      title: d.name,
      titleColor: d.nameColor,
      tags: [for (final (t, col) in d.tags) DsTag(t, color: col)],
      children: [
        for (final l in d.lines) Text(l, style: DsText.body()),
        ..._compare(d),
      ],
    );
  }

  Widget _detail(LifeItemCellData c) {
    final d = c.detail;
    return DsCard(
      key: const ValueKey('life-detail'),
      child: Column(
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
          ]),
          if (d.tags.isNotEmpty) ...[
            SizedBox(height: DsSpace.xs),
            Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              for (final (t, col) in d.tags) DsTag(t, color: col),
            ]),
          ],
          SizedBox(height: DsSpace.xs),
          for (final l in d.lines) Text(l, style: DsText.body()),
          ..._compare(d),
          if (d.description != null) ...[
            SizedBox(height: DsSpace.xs),
            Text(d.description!, style: DsText.detail()),
          ],
          if (d.actions.isNotEmpty) ...[
            SizedBox(height: DsSpace.sm),
            Wrap(
                spacing: DsSpace.xs,
                runSpacing: DsSpace.xs,
                children: d.actions),
          ],
        ],
      ),
    );
  }
}
