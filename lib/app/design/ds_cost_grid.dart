import 'package:material_ui/material_ui.dart';

import '../theme/retro_theme.dart';
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

/// Organism: required items (a cost, an order, a quest objective) as
/// the INVENTARIO item cell ([DsItemCell]), top-left anchored, with no
/// text under the cells (design_system.md § "Grilla de ítems"). Each
/// cell carries `have/need` as a small corner count: greyed (icon and
/// count) while it is not enough, and a check mark on the top-right
/// once it is. Hovering a cell shows its fixed-size [DsCostEntry.card].
class DsCostGrid extends StatelessWidget {
  const DsCostGrid(this.entries, {super.key, this.size = cell});

  /// Cell side (same as INVENTARIO and the life item grids).
  static const cell = DsSizes.itemCell;

  final List<DsCostEntry> entries;

  /// Cell side (default [cell]).
  final double size;

  @override
  Widget build(BuildContext context) {
    final fixed = RetroType.fixedScaler(context);
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: DsSizes.itemGap,
        runSpacing: DsSizes.itemGap,
        children: [
          for (final e in entries)
            DsTooltip(
              card: e.card,
              child: SizedBox.square(
                key: ValueKey('cost-${e.id}'),
                dimension: size,
                child: Stack(children: [
                  DsItemCell(
                      icon: Opacity(
                          opacity: e.enough ? 1 : 0.45, child: e.icon),
                      border: e.enough ? DsColors.success : e.border,
                      dimension: size),
                  Positioned(
                    right: 2,
                    bottom: 0,
                    child: Text('${e.have}/${e.need}',
                        key: ValueKey('cost-${e.id}-count'),
                        textScaler: fixed,
                        style: DsText.meta(e.enough
                                ? DsColors.success
                                : DsColors.textDisabled)
                            .copyWith(
                                fontSize: RetroType.small,
                                height: 1,
                                shadows: const [Shadow(offset: Offset(1, 1))])),
                  ),
                  if (e.enough)
                    Positioned(
                      right: 1,
                      top: 1,
                      child: Icon(Icons.check,
                          key: ValueKey('cost-${e.id}-done'),
                          size: 12,
                          color: DsColors.success),
                    ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
