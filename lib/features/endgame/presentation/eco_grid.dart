import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../inventory/presentation/item_widgets.dart';

/// Shared pieces of the ECOS subtabs (MEJORAR and FUSIONAR,
/// docs/specs/ecos_atlas.md § 4.1 / § 4.2): the same INVENTARIO-style Eco
/// cell (icon, tier bottom-right, rarity frame) and the same grid + detail
/// layout. Purely visual.

/// Atom: one Eco cell of the grid.
class EcoGridCell extends StatelessWidget {
  const EcoGridCell({
    super.key,
    required this.rules,
    required this.eco,
    required this.selected,
    required this.onTap,
  });

  final ProgressionRules rules;
  final EcoItem eco;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ItemCell(
              rules: rules,
              content: CellContent.eco(eco),
              selected: selected,
              size: DsItemCell.size),
        ),
      );
}

/// Template: a wrapping grid of cells on the left and [detail] on the
/// right ([detailWidth] wide, full height); on narrow widths the detail
/// goes on top. [empty] replaces the grid when there are no cells.
class EcoGridLayout extends StatelessWidget {
  const EcoGridLayout({
    super.key,
    required this.cells,
    required this.detail,
    this.empty,
    this.footer = const [],
    this.detailWidth = 300,
  });

  final List<Widget> cells;
  final Widget detail;
  final Widget? empty;

  /// Extra widgets under the grid (dev shortcuts).
  final List<Widget> footer;
  final double detailWidth;

  @override
  Widget build(BuildContext context) {
    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cells.isEmpty && empty != null)
          empty!
        else
          Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: cells),
        for (final f in footer) ...[SizedBox(height: DsSpace.sm), f],
      ],
    );
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 560 && box.hasBoundedHeight) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SingleChildScrollView(child: grid)),
            SizedBox(width: DsSpace.sm),
            SizedBox(width: detailWidth, height: box.maxHeight, child: detail),
          ],
        );
      }
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [detail, SizedBox(height: DsSpace.sm), grid],
        ),
      );
    });
  }
}
