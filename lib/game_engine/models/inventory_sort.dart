/// Criterio de ORDENAR del inventario (`SortInventoryAction`,
/// docs/specs/loot.md § 17.2). El nombre viaja por la red (`invSort`).
enum InventorySortKey {
  /// Rareza de mayor a menor (después nivel de objeto, nombre).
  rarity('Rareza'),

  /// Nivel de objeto de mayor a menor (después rareza, nombre).
  itemLevel('Nivel de objeto'),

  /// Tipo de arma (alfabético; después rareza, nivel, nombre).
  weaponType('Tipo de arma'),

  /// Nombre (alfabético, sin mayúsculas ni tildes; después rareza).
  name('Nombre'),

  /// Lo más nuevo primero (armas y Ecos juntos).
  recent('Recientes');

  const InventorySortKey(this.label);

  final String label;

  static InventorySortKey? byName(String n) {
    for (final k in values) {
      if (k.name == n) return k;
    }
    return null;
  }
}
