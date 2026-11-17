import 'item.dart';

/// De dónde sale un drop (cambia la rareza, el nivel y los materiales).
enum LootSource { battle, elite, boss, chest, mission }

/// Lo que se apila en el inventario (1 casilla por tipo): pociones y
/// materiales de crafteo. `token` es la clave en la grilla y en la red.
enum StackKind {
  potion('pot', 'Poción de vida', 9),
  ether('eter', 'Poción de maná', 9),
  esquirla('mat:esquirla', 'Esquirla del Eco', CraftMaterial.maxStack),
  cristal('mat:cristal', 'Cristal de Era', CraftMaterial.maxStack),
  prisma('mat:prisma', 'Prisma Roto', CraftMaterial.maxStack);

  const StackKind(this.token, this.label, this.maxStack);

  final String token;
  final String label;
  final int maxStack;

  CraftMaterial? get material => switch (this) {
        StackKind.esquirla => CraftMaterial.esquirla,
        StackKind.cristal => CraftMaterial.cristal,
        StackKind.prisma => CraftMaterial.prisma,
        _ => null,
      };

  static StackKind of(CraftMaterial m) => switch (m) {
        CraftMaterial.esquirla => StackKind.esquirla,
        CraftMaterial.cristal => StackKind.cristal,
        CraftMaterial.prisma => StackKind.prisma,
      };

  static StackKind? byToken(String token) {
    for (final k in values) {
      if (k.token == token) return k;
    }
    return null;
  }
}

/// Un drop: un arma o una pila (pociones / materiales).
class LootDrop {
  const LootDrop.item(ItemInstance this.item)
      : stack = null,
        count = 1;
  const LootDrop.stack(StackKind this.stack, this.count) : item = null;

  final ItemInstance? item;
  final StackKind? stack;
  final int count;

  bool get isItem => item != null;

  Map<String, Object?> toJson() => item != null
      ? {'it': item!.toJson()}
      : {'st': stack!.token, 'n': count};

  /// `null` si no tiene la forma esperada.
  static LootDrop? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final it = ItemInstance.fromJson(raw['it']);
    if (it != null) return LootDrop.item(it);
    final st = raw['st'], n = raw['n'];
    final k = st is String ? StackKind.byToken(st) : null;
    if (k == null || n is! num || n <= 0) return null;
    return LootDrop.stack(k, n.toInt());
  }
}

/// Un drop en el piso del mapa. [ownerId] = jugador dueño (loot
/// instanciado: solo él lo ve y lo levanta); `null` = soltado por un
/// jugador, compartido (lo levanta cualquiera). Ver loot.md § 4.
class GroundLoot {
  const GroundLoot({
    required this.id,
    required this.drop,
    required this.x,
    required this.y,
    this.ownerId,
  });

  final int id;
  final LootDrop drop;
  final double x, y;
  final String? ownerId;

  bool visibleTo(String playerId) => ownerId == null || ownerId == playerId;
}
