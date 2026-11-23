// Cultivos, semillas y herramientas de la huerta (docs/specs/farming.md
// § 2 y § 4). Datos puros: los lee `FarmingRules`; la UI solo los muestra.

import 'fishing_catalog.dart' show FishRarity;

export 'fishing_catalog.dart' show FishRarity;

/// Calidad de una cosecha (farming.md § 3): normal, rara, épica o
/// legendaria. El precio y la XP suben con la calidad
/// (`qualityMult<Key>` en Editor → Balance → Cultivo).
enum CropQuality {
  normal('normal'),
  raro('rara'),
  epico('épica'),
  legendario('legendaria');

  const CropQuality(this.label);
  final String label;

  /// Sufijo de las claves de tunables (`qualityMultRaro`, `wQEpico`, …).
  String get key => '${name[0].toUpperCase()}${name.substring(1)}';
}

/// Un abono (farming.md § 3.2): sesga la tirada de calidad hacia arriba
/// y acelera un poco el crecimiento. El sesgo y la velocidad están en el
/// Balance (`fert<Key>Bias`, `fert<Key>Speed`).
class FertDef {
  const FertDef(this.id, this.name, this.key, this.rarity, {required this.price});
  final String id;
  final String name;

  /// Sufijo de los tunables (`fertComunBias`, …).
  final String key;
  final FishRarity rarity;
  final int price;
}

const kFertilizers = <String, FertDef>{
  'abono': FertDef('abono', 'Abono', 'Comun', FishRarity.comun, price: 20),
  'abono_runico': FertDef('abono_runico', 'Abono rúnico', 'Runico',
      FishRarity.epico, price: 120),
  'abono_eco':
      FertDef('abono_eco', 'Abono del Eco', 'Eco', FishRarity.legendario, price: 600),
};

/// Un cultivo (y su semilla, con el mismo id).
class CropDef {
  const CropDef(this.id, this.name, this.rarity,
      {required this.biome,
      required this.growSec,
      required this.price,
      required this.xp,
      this.seedPrice = 0,
      this.lore = ''});

  final String id;
  final String name;
  final FishRarity rarity;

  /// Bioma de origen (`zona1` … `zona10`).
  final String biome;

  /// Segundos de crecimiento regado (farming.md § 2.2).
  final double growSec;

  /// Precio base en oro (calidad normal).
  final int price;

  /// XP de Cultivo base (antes de rareza y calidad).
  final int xp;

  /// Precio de la semilla en el comerciante (0 = no se vende: cae de
  /// cosechas o de las mazmorras).
  final int seedPrice;
  final String lore;

  String get seedName => 'Semilla de ${name[0].toLowerCase()}${name.substring(1)}';
}

/// Tipo de herramienta de la huerta.
enum FarmToolKind {
  azada('Azada'),
  regadera('Regadera');

  const FarmToolKind(this.label);
  final String label;
}

/// Una azada o una regadera (espacio de herramienta, como las cañas).
class FarmToolDef {
  const FarmToolDef(this.id, this.name, this.kind, this.rarity,
      {required this.reqLevel,
      this.quality = 0,
      this.area = 0,
      this.extra = 0,
      this.price = 0});

  final String id;
  final String name;
  final FarmToolKind kind;
  final FishRarity rarity;

  /// Nivel de Cultivo para rendir al 100 % (town_loop.md § 11c).
  final int reqLevel;

  /// Bonus de calidad base (antes de la efectividad).
  final double quality;

  /// Área base: 0 = un tile, 1 = cruz de 5, 2 = cuadrado de 3 × 3.
  final int area;

  /// Azada: chance de cosecha doble. Regadera: × de duración del riego.
  final double extra;

  /// Precio en el comerciante (0 = no se vende).
  final int price;
}

/// Bioma de las semillas iniciales del pueblo.
const kFarmStartBiome = 'zona1';

/// Herramientas con que arranca todo personaje (migración v0.23.0).
const kStarterHoe = 'azada_rama';
const kStarterCan = 'regadera_lata';

const kFarmTools = <String, FarmToolDef>{
  'azada_rama': FarmToolDef(
      'azada_rama', 'Azada de rama', FarmToolKind.azada, FishRarity.comun,
      reqLevel: 1),
  'azada_hierro': FarmToolDef('azada_hierro', 'Azada de hierro',
      FarmToolKind.azada, FishRarity.raro,
      reqLevel: 5, quality: 0.15, area: 1, extra: 0.1, price: 350),
  'azada_runica': FarmToolDef('azada_runica', 'Azada de bronce rúnico',
      FarmToolKind.azada, FishRarity.epico,
      reqLevel: 12, quality: 0.3, area: 2, extra: 0.2, price: 1400),
  'azada_eco': FarmToolDef(
      'azada_eco', 'Azada del Eco', FarmToolKind.azada, FishRarity.legendario,
      reqLevel: 22, quality: 0.5, area: 2, extra: 0.35, price: 4800),
  'regadera_lata': FarmToolDef('regadera_lata', 'Regadera de lata',
      FarmToolKind.regadera, FishRarity.comun,
      reqLevel: 1),
  'regadera_cobre': FarmToolDef('regadera_cobre', 'Regadera de cobre',
      FarmToolKind.regadera, FishRarity.raro,
      reqLevel: 5, quality: 0.1, area: 1, extra: 0.25, price: 300),
  'regadera_runica': FarmToolDef('regadera_runica',
      'Regadera de bronce rúnico', FarmToolKind.regadera, FishRarity.epico,
      reqLevel: 12, quality: 0.2, area: 2, extra: 0.5, price: 1300),
  'regadera_eco': FarmToolDef('regadera_eco', 'Regadera del Eco',
      FarmToolKind.regadera, FishRarity.legendario,
      reqLevel: 22, quality: 0.35, area: 2, extra: 1, price: 4500),
};

const kCrops = <String, CropDef>{
  'nabo_claro': CropDef('nabo_claro', 'Nabo del claro', FishRarity.comun,
      biome: 'zona1', growSec: 150, price: 10, xp: 6, seedPrice: 4),
  'trigo_dorado': CropDef('trigo_dorado', 'Trigo dorado', FishRarity.comun,
      biome: 'zona1', growSec: 200, price: 13, xp: 7, seedPrice: 5),
  'papa_piedra': CropDef('papa_piedra', 'Papa de piedra', FishRarity.comun,
      biome: 'zona1', growSec: 240, price: 16, xp: 8, seedPrice: 6),
  'calabaza_sendero': CropDef('calabaza_sendero', 'Calabaza del sendero',
      FishRarity.comun,
      biome: 'zona1', growSec: 300, price: 20, xp: 9, seedPrice: 8),
  'frutilla_rocio': CropDef('frutilla_rocio', 'Frutilla de rocío',
      FishRarity.raro,
      biome: 'zona1', growSec: 420, price: 42, xp: 16, seedPrice: 25),
  'cebolla_cobre': CropDef('cebolla_cobre', 'Cebolla de cobre',
      FishRarity.raro,
      biome: 'zona1', growSec: 480, price: 50, xp: 18, seedPrice: 30,
      lore: 'Las capas brillan como el metal de las ruinas.'),
  'flor_runica': CropDef('flor_runica', 'Flor rúnica', FishRarity.epico,
      biome: 'zona1', growSec: 840, price: 130, xp: 40,
      lore: 'Los pétalos llevan las mismas runas que la fuente.'),
  'melon_engranaje': CropDef('melon_engranaje', 'Melón engranaje',
      FishRarity.epico,
      biome: 'zona1', growSec: 900, price: 150, xp: 44,
      lore: 'Sus semillas encastran como piezas de un mecanismo antiguo.'),
  'trigo_manana': CropDef('trigo_manana', 'Trigo del Mañana',
      FishRarity.legendario,
      biome: 'zona1', growSec: 1500, price: 850, xp: 150,
      lore: 'Un eco del futuro: ya lo cosechaste, solo que todavía no.'),
  'rosa_reloj': CropDef('rosa_reloj', 'Rosa del Reloj Quieto',
      FishRarity.legendario,
      biome: 'zona1', growSec: 1650, price: 950, xp: 160,
      lore: 'Florece a una hora que no avanza.'),
  'raiz_era': CropDef('raiz_era', 'Raíz de la Era Antigua',
      FishRarity.legendario,
      biome: 'zona1', growSec: 1800, price: 1100, xp: 175,
      lore: 'Creció cuando el pasado era más avanzado que el presente.'),
  // Semillas exclusivas del Bosque (overworld_biomes.md § 3.3): salen de
  // recolectar y se plantan en la huerta del pueblo; no se venden.
  'helecho_dulce': CropDef('helecho_dulce', 'Helecho dulce', FishRarity.comun,
      biome: 'bosque', growSec: 260, price: 24, xp: 9),
  'arandano_sombra': CropDef('arandano_sombra', 'Arándano de sombra',
      FishRarity.raro,
      biome: 'bosque', growSec: 520, price: 60, xp: 19),
  'seta_reloj': CropDef('seta_reloj', 'Seta del reloj', FishRarity.epico,
      biome: 'bosque', growSec: 960, price: 175, xp: 45,
      lore: 'Crece en anillos, como si contara horas que ya pasaron.'),
  // Productos silvestres del Bosque (se recolectan; nunca dan semilla).
  'moras_bosque': CropDef('moras_bosque', 'Moras del bosque',
      FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 9, xp: 5),
  'hierba_rocio': CropDef('hierba_rocio', 'Hierba de rocío', FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 12, xp: 6),
  'hongo_ambar': CropDef('hongo_ambar', 'Hongo ámbar', FishRarity.raro,
      biome: 'silvestre', growSec: 1e9, price: 32, xp: 12,
      lore: 'Brilla de noche con la misma luz que las runas viejas.'),
};

/// Clave de la bolsa de cosechas: `<cultivo>@<calidad>`.
String cropKey(String crop, CropQuality q) => '$crop@${q.index}';

/// (cultivo, calidad) de una clave de la bolsa; `null` si no es válida.
(CropDef, CropQuality)? parseCropKey(String key) {
  final i = key.lastIndexOf('@');
  if (i <= 0) return null;
  final c = kCrops[key.substring(0, i)];
  final q = int.tryParse(key.substring(i + 1));
  if (c == null || q == null || q < 0 || q >= CropQuality.values.length) {
    return null;
  }
  return (c, CropQuality.values[q]);
}
