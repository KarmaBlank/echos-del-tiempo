import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/models/inventory_sort.dart';

/// `ORDENAR ▼` del inventario (v0.5.1, loot.md § 17.2, panels.md §
/// "Inventario"): un [DsMenuButton] con las claves de [InventorySortKey]
/// (`inv-sort-<clave>`); elegir una llama a [onSort].
class InventorySortButton extends StatelessWidget {
  const InventorySortButton({
    super.key,
    required this.onSort,
    this.reason,
    this.current,
    this.initiallyOpen = false,
  });

  final ValueChanged<InventorySortKey> onSort;
  final String? reason;

  /// Última clave usada (borde dorado en el menú).
  final InventorySortKey? current;

  /// Abre el menú al aparecer (capturas y tests).
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) => DsMenuButton<InventorySortKey>(
        label: 'ORDENAR',
        options: InventorySortKey.values,
        optionLabel: (k) => k.label,
        onChanged: onSort,
        current: current,
        reason: reason,
        initiallyOpen: initiallyOpen,
        buttonKey: const ValueKey('inv-sort'),
        menuKey: const ValueKey('inv-sort-menu'),
        optionKey: (k) => ValueKey('inv-sort-${k.name}'),
      );
}
