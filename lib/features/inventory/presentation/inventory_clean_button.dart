import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/models/item.dart';
import '../../../core/i18n/strings.dart';
import 'inventory_strings.dart';

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

  String _label(Strings s, CleanChoice c) => c.pick
      ? s.t('ui.inventory.clean.pick')
      : s.t(c.sell ? 'ui.inventory.clean.sell_batch' : 'ui.inventory.clean.salvage_batch',
          {'rarity': s.t(rarityPluralKey(c.rarity!)), 'n': count(c.rarity!)});

  String? _reason(Strings s, CleanChoice c) => c.pick || count(c.rarity!) > 0
      ? null
      : s.t('ui.inventory.clean.none_of',
          {'rarity': s.t(rarityPluralKey(c.rarity!)).toLowerCase()});

  @override
  Widget build(BuildContext context) {
    final s = invStrings(context);
    return DsMenuButton<CleanChoice>(
        label: s.t('ui.inventory.clean.button'),
        options: CleanChoice.all,
        optionLabel: (c) => _label(s, c),
        optionReason: (c) => _reason(s, c),
        onChanged: onChoose,
        current: current,
        initiallyOpen: initiallyOpen,
        buttonKey: const ValueKey('inv-clean'),
        menuKey: const ValueKey('inv-clean-menu'),
        optionKey: (c) => ValueKey('inv-clean-menu-${c.id}'),
      );
  }
}

/// String key of a rarity's plural for batches (`Comunes`, `Mágicos`...).
String rarityPluralKey(Rarity r) => switch (r) {
      Rarity.comun => 'ui.inventory.clean.rarity.common',
      Rarity.magico => 'ui.inventory.clean.rarity.magic',
      Rarity.raro => 'ui.inventory.clean.rarity.rare',
      Rarity.epico => 'ui.inventory.clean.rarity.epic',
      Rarity.legendario => 'ui.inventory.clean.rarity.legendary',
    };
