import '../data/tuning_catalog.dart';
import 'battle_command.dart';

/// Un consumible de la tienda (`ITEMS` del prototipo).
class ItemDef {
  final BattleItem item;

  /// Clave del prototipo (`pot` / `eter`), también usada en el JSON del perfil.
  final String key;
  final String name;
  final String description;

  const ItemDef({
    required this.item,
    required this.key,
    required this.name,
    required this.description,
  });

  /// Precio vigente (tunable): el Éter vale `aetherMult` × Poción de vida.
  int get price {
    final t = tuning(TuningId.consumables);
    return switch (item) {
      BattleItem.potion => t.i('potionPrice'),
      BattleItem.ether => t.i('etherPrice'),
      BattleItem.aether => (t.i('potionPrice') * t.d('aetherMult')).round(),
    };
  }
}
