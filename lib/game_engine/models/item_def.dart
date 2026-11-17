import 'battle_command.dart';

/// Un consumible de la tienda (`ITEMS` del prototipo).
class ItemDef {
  final BattleItem item;

  /// Clave del prototipo (`pot` / `eter`), también usada en el JSON del perfil.
  final String key;
  final String name;
  final String description;
  final int price;

  const ItemDef({
    required this.item,
    required this.key,
    required this.name,
    required this.description,
    required this.price,
  });
}
