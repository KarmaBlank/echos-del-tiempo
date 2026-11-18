/// Tipos de la exploración v0.6 (docs/specs/worldgen.md § 11 y loot.md
/// § 23).
library;

/// Calidad de un cofre del campo.
enum ChestTier {
  /// Cofre común (de madera).
  madera,

  /// Cofre reforzado (de plata).
  plata,

  /// Cofre dorado: arma Rara o mejor segura.
  oro,
}

/// Bendición de santuario: una activa por misión, para todo el grupo.
enum BlessingKind { fuerza, vigor, fortuna, reloj }
