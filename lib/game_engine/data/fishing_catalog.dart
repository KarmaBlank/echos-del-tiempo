// Peces y cañas (docs/specs/fishing.md § 2 y § 4). Datos puros: los lee
// `FishingRules`; la UI solo los muestra.

/// Rareza de un pez o de una caña (fishing.md § 2).
enum FishRarity {
  comun('común'),
  raro('raro'),
  epico('épico'),
  legendario('legendario');

  const FishRarity(this.label);
  final String label;

  /// Sufijo de las claves de tunables (`weightComun`, `xpRaro`, …).
  String get key => '${name[0].toUpperCase()}${name.substring(1)}';

  static FishRarity fromName(Object? n) =>
      values.firstWhere((v) => v.name == n, orElse: () => comun);
}

/// Una especie de pez.
class FishDef {
  const FishDef(this.id, this.name, this.rarity,
      {required this.biome,
      required this.minCm,
      required this.maxCm,
      required this.price,
      required this.xp,
      this.lore = ''});

  final String id;
  final String name;
  final FishRarity rarity;

  /// Bioma donde vive (fishing.md § 2.1): `zona1` … `zona10`. El lago del
  /// pueblo arranca con las especies de `zona1` (`TownState.lake`).
  final String biome;
  final int minCm, maxCm;

  /// Precio base en oro (el comerciante; fishing.md § 5).
  final int price;

  /// XP de Pesca base (antes de rareza y tamaño).
  final int xp;
  final String lore;

  double get avgCm => (minCm + maxCm) / 2;
}

/// Una caña: herramienta en su propio espacio (no es un arma).
class RodDef {
  const RodDef(this.id, this.name, this.rarity,
      {required this.reqLevel,
      this.biteSpeed = 0,
      this.zoneBonus = 0,
      this.rareBonus = 0,
      this.price = 0});

  final String id;
  final String name;
  final FishRarity rarity;

  /// Nivel de Pesca para rendir al 100 % (town_loop.md § 11c).
  final int reqLevel;

  /// Bonus base (antes de la efectividad): picada más rápida (fracción
  /// menos de espera), zona de captura más ancha y chance de rareza.
  final double biteSpeed, zoneBonus, rareBonus;

  /// Precio en el comerciante (0 = no se vende).
  final int price;
}

/// La caña que tiene todo personaje (migración v0.22.0).
const kStarterRod = 'cana_rama';

const kRods = <String, RodDef>{
  'cana_rama': RodDef('cana_rama', 'Caña de rama', FishRarity.comun,
      reqLevel: 1),
  'cana_roble': RodDef('cana_roble', 'Caña de roble', FishRarity.raro,
      reqLevel: 5, biteSpeed: 0.15, zoneBonus: 0.15, rareBonus: 0.2,
      price: 400),
  'cana_runica': RodDef('cana_runica', 'Caña de bronce rúnico',
      FishRarity.epico,
      reqLevel: 12, biteSpeed: 0.3, zoneBonus: 0.3, rareBonus: 0.45,
      price: 1500),
  'cana_eco': RodDef('cana_eco', 'Caña del Eco', FishRarity.legendario,
      reqLevel: 22, biteSpeed: 0.45, zoneBonus: 0.5, rareBonus: 0.8,
      price: 5000),
};

/// Bioma de las especies con que arranca el lago del pueblo.
const kTownStartBiome = 'zona1';

const kFish = <String, FishDef>{
  'mojarra_claro': FishDef('mojarra_claro', 'Mojarra del claro',
      FishRarity.comun,
      biome: 'zona1', minCm: 8, maxCm: 16, price: 12, xp: 6),
  'perca_rayada': FishDef('perca_rayada', 'Perca rayada', FishRarity.comun,
      biome: 'zona1', minCm: 15, maxCm: 30, price: 15, xp: 7),
  'carpa_musgo': FishDef('carpa_musgo', 'Carpa de musgo', FishRarity.comun,
      biome: 'zona1', minCm: 20, maxCm: 45, price: 18, xp: 8),
  'trucha_cobre': FishDef('trucha_cobre', 'Trucha de cobre', FishRarity.raro,
      biome: 'zona1', minCm: 25, maxCm: 50, price: 45, xp: 16),
  'bagre_ruinas': FishDef('bagre_ruinas', 'Bagre de las ruinas',
      FishRarity.raro,
      biome: 'zona1', minCm: 30, maxCm: 70, price: 55, xp: 18,
      lore: 'Vive entre piedras talladas que se hundieron hace eras.'),
  'anguila_runica': FishDef('anguila_runica', 'Anguila rúnica',
      FishRarity.epico,
      biome: 'zona1', minCm: 50, maxCm: 110, price: 140, xp: 40,
      lore: 'Las runas del lomo brillan como las de la fuente.'),
  'pez_engranaje': FishDef('pez_engranaje', 'Pez engranaje', FishRarity.epico,
      biome: 'zona1', minCm: 20, maxCm: 40, price: 160, xp: 45,
      lore: 'Mitad escama, mitad mecanismo antiguo movido por magia.'),
  'carpa_manana': FishDef('carpa_manana', 'Carpa del Mañana',
      FishRarity.legendario,
      biome: 'zona1', minCm: 80, maxCm: 140, price: 900, xp: 150,
      lore: 'Un eco del futuro: ya la pescaste, solo que todavía no.'),
  'esturion_era': FishDef('esturion_era', 'Esturión de la Era Antigua',
      FishRarity.legendario,
      biome: 'zona1', minCm: 120, maxCm: 220, price: 1200, xp: 180,
      lore: 'Nadaba cuando el pasado era más avanzado que el presente.'),
  'pez_reloj': FishDef('pez_reloj', 'Pez del Reloj Quieto',
      FishRarity.legendario,
      biome: 'zona1', minCm: 40, maxCm: 70, price: 1000, xp: 160,
      lore: 'Las escamas marcan una hora que no avanza.'),
  // Lago del Bosque (overworld_biomes.md § 3.1, v0.26.0).
  'mojarra_sombra': FishDef('mojarra_sombra', 'Mojarra de sombra',
      FishRarity.comun,
      biome: 'bosque', minCm: 9, maxCm: 18, price: 14, xp: 7),
  'bagre_raiz': FishDef('bagre_raiz', 'Bagre de raíz', FishRarity.comun,
      biome: 'bosque', minCm: 20, maxCm: 48, price: 19, xp: 8),
  'trucha_musgo': FishDef('trucha_musgo', 'Trucha musgosa', FishRarity.raro,
      biome: 'bosque', minCm: 25, maxCm: 55, price: 50, xp: 17),
  'lucio_runico': FishDef('lucio_runico', 'Lucio rúnico', FishRarity.epico,
      biome: 'bosque', minCm: 55, maxCm: 120, price: 150, xp: 42,
      lore: 'Muerde los anzuelos como si fueran engranajes sueltos.'),
  'salmon_eco': FishDef('salmon_eco', 'Salmón del Eco Quieto',
      FishRarity.legendario,
      biome: 'bosque', minCm: 70, maxCm: 130, price: 1100, xp: 170,
      lore: 'Remonta un río que todavía no existe: viene del futuro a '
          'desovar en el pasado, y siempre llega.'),
  // Botín del agua (fishing.md § 8, v0.22.2): la basura va a la bolsa y
  // se vende por poco; el bulto es lo que se ve en la línea antes de saber
  // qué es (nunca entra a la bolsa).
  'botas_viejas': FishDef('botas_viejas', 'Botas viejas', FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 25, maxCm: 30, price: 2, xp: 2),
  'rama_empapada': FishDef('rama_empapada', 'Rama empapada',
      FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 30, maxCm: 80, price: 1, xp: 1),
  'hojarasca_mojada': FishDef('hojarasca_mojada', 'Hojarasca mojada',
      FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 10, maxCm: 30, price: 1, xp: 1),
  kWaterBundle: FishDef(kWaterBundle, 'Algo pesado', FishRarity.raro,
      biome: kWaterJunkBiome, minCm: 0, maxCm: 0, price: 0, xp: 0),
};

/// Bioma de la basura del agua (no es de ningún lago).
const kWaterJunkBiome = 'basura';

/// Lo que se clava cuando es un hallazgo (materiales, cofre o arma).
const kWaterBundle = 'bulto_hundido';

/// La basura del agua (fishing.md § 8).
const kWaterJunk = ['botas_viejas', 'rama_empapada'];

/// Armas legendarias que solo salen del agua (fishing.md § 8.3).
const kFishingLegendaries = ['filoHundido', 'relojAhogado', 'cuerdaOrilla'];

/// Especies iniciales del lago del pueblo (las del bioma de la zona 1).
List<String> get kTownLakeDefault => [
      for (final f in kFish.values)
        if (f.biome == kTownStartBiome) f.id
    ];
