import 'package:material_ui/material_ui.dart';

import 'ds_components.dart';
import 'ds_tokens.dart';
import 'ds_transfer_template.dart' show DsItemCell;

/// One required item of a [DsCostGrid].
class DsCostEntry {
  const DsCostEntry({
    required this.id,
    required this.icon,
    required this.need,
    required this.have,
    required this.card,
    this.border = DsColors.border,
  });

  /// Stable key: the cell is `ValueKey('cost-<id>')`.
  final String id;
  final Widget icon;
  final Color border;
  final int need;
  final int have;

  /// Tooltip shown on hover (a [DsTooltipCard]).
  final Widget card;

  bool get enough => have >= need;
}

/// Molecule: what something costs, as item cells (the same [DsItemCell]
/// as INVENTARIO) with `have/need` under each one, green when it is
/// enough and red when it is not. Hovering a cell shows its [card].
class DsCostGrid extends StatelessWidget {
  const DsCostGrid(this.entries, {super.key});

  /// Cell side (same as the life item grids).
  static const cell = 44.0;

  final List<DsCostEntry> entries;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: DsSpace.sm,
        runSpacing: DsSpace.sm,
        children: [
          for (final e in entries)
            DsTooltip(
              card: e.card,
              child: Column(
                key: ValueKey('cost-${e.id}'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsItemCell(
                      icon: e.icon,
                      border: e.enough ? e.border : DsColors.danger,
                      dimension: cell),
                  Text('${e.have}/${e.need}',
                      key: ValueKey('cost-${e.id}-count'),
                      style: DsText.detail(
                          e.enough ? DsColors.success : DsColors.danger)),
                ],
              ),
            ),
        ],
      );
}
