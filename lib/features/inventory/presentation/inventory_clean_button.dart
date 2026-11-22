import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/models/item.dart';
import '../domain/item_text.dart' show rarityPlural;

/// Una opción de `LIMPIAR ▼`: elegir a mano, o desarmar / vender todas
/// las armas de una rareza (docs/specs/ui_minimal.md § 5).
class CleanChoice {
  const CleanChoice.pick()
      : op = null,
        rarity = null;
  const CleanChoice.batch(CraftOp this.op, Rarity this.rarity);

  /// `null` = ELEGIR A MANO.
  final CraftOp? op;
  final Rarity? rarity;

  bool get pick => op == null;
  bool get sell => op == CraftOp.sellAll;

  String get id => pick
      ? 'pick'
      : '${sell ? 'sell' : 'salvage'}-${rarity!.name}';

  /// Rarezas con lote (los Épicos y Legendarios, uno por uno).
  static const rarities = [Rarity.comun, Rarity.magico, Rarity.raro];

  static final all = [
    const CleanChoice.pick(),
    for (final r in rarities) CleanChoice.batch(CraftOp.salvageAll, r),
    for (final r in rarities) CleanChoice.batch(CraftOp.sellAll, r),
  ];

  @override
  bool operator ==(Object other) => other is CleanChoice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// `LIMPIAR ▼` del inventario: el ÚNICO lugar de las acciones en lote
/// (ui_minimal.md § 5). Un [DsMenuButton] con [CleanChoice.all]; las
/// opciones sin armas quedan grises con el motivo de tooltip.
class InventoryCleanButton extends StatelessWidget {
  const InventoryCleanButton({
    super.key,
    required this.count,
    required this.onChoose,
    this.current,
    this.initiallyOpen = false,
  });

  /// Cuántas armas de [r] entran en el lote.
  final int Function(Rarity r) count;
  final ValueChanged<CleanChoice> onChoose;
  final CleanChoice? current;
  final bool initiallyOpen;

  String _label(CleanChoice c) => c.pick
      ? 'Elegir a mano'
      : '${c.sell ? 'Vender' : 'Desarmar'} ${rarityPlural(c.rarity!)} '
          '(${count(c.rarity!)})';

  String? _reason(CleanChoice c) => c.pick || count(c.rarity!) > 0
      ? null
      : 'No tenés ${rarityPlural(c.rarity!).toLowerCase()}';

  @override
  Widget build(BuildContext context) => DsMenuButton<CleanChoice>(
        label: 'LIMPIAR',
        options: CleanChoice.all,
        optionLabel: _label,
        optionReason: _reason,
        onChanged: onChoose,
        current: current,
        initiallyOpen: initiallyOpen,
        buttonKey: const ValueKey('inv-clean'),
        menuKey: const ValueKey('inv-clean-menu'),
        optionKey: (c) => ValueKey('inv-clean-menu-${c.id}'),
      );
}
