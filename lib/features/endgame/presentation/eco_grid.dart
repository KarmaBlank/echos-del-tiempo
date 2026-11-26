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

/// The ECOS grid + detail: the shared [DsGridDetailLayout]
/// (design_system.md § "Grilla de ítems"); cells scale like INVENTARIO.
class EcoGridLayout extends StatelessWidget {
  const EcoGridLayout({
    super.key,
    required this.cells,
    required this.detail,
    this.empty,
    this.footer = const [],
  });

  final List<Widget> cells;
  final Widget detail;
  final Widget? empty;

  /// Extra widgets under the grid (dev shortcuts).
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) => DsGridDetailLayout(
        keyPrefix: 'eco',
        count: cells.length,
        cell: (context, i, size) => FittedBox(child: cells[i]),
        empty: empty,
        footer: footer,
        detail: detail,
      );
}
