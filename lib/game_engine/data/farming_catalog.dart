// Cultivos, semillas y herramientas de la huerta (docs/specs/farming.md
// § 2 y § 4). Datos puros: los lee `FarmingRules`; la UI solo los muestra.

import 'fishing_catalog.dart'
    show FishRarity, Season, kAllSeasons, kWarmSeasons;

export 'fishing_catalog.dart'
    show FishRarity, Season, kAllSeasons, kWarmSeasons;

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
      this.lore = '',
      this.seasons = kWarmSeasons});

  /// Seasons when it grows (farming.md § 15): out of season a planted
  /// crop stalls (it does not die) until its season comes back. Most
  /// crops skip winter; winter crops only grow and ripen in winter.
  final Set<Season> seasons;

  /// Only grows in winter (and only then can it be harvested).
  bool get winterOnly => seasons.length == 1 && seasons.contains(Season.winter);

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

  /// Precio de la semilla en el agropecuario (0 = no se vende: cae de
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

  /// Precio en el agropecuario (0 = no se vende).
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
      biome: 'zona1', growSec: 150, price: 10, xp: 9, seedPrice: 4),
  'trigo_dorado': CropDef('trigo_dorado', 'Trigo dorado', FishRarity.comun,
      biome: 'zona1', growSec: 200, price: 13, xp: 10, seedPrice: 5),
  'papa_piedra': CropDef('papa_piedra', 'Papa de piedra', FishRarity.comun,
      biome: 'zona1', growSec: 240, price: 16, xp: 12, seedPrice: 6),
  'calabaza_sendero': CropDef('calabaza_sendero', 'Calabaza del sendero',
      FishRarity.comun,
      biome: 'zona1', growSec: 300, price: 20, xp: 14, seedPrice: 8),
  'frutilla_rocio': CropDef('frutilla_rocio', 'Frutilla de rocío',
      FishRarity.raro,
      biome: 'zona1', growSec: 420, price: 42, xp: 24, seedPrice: 25),
  'cebolla_cobre': CropDef('cebolla_cobre', 'Cebolla de cobre',
      FishRarity.raro,
      biome: 'zona1', growSec: 480, price: 50, xp: 27, seedPrice: 30,
      lore: 'Las capas brillan como el metal de las ruinas.'),
  'flor_runica': CropDef('flor_runica', 'Flor rúnica', FishRarity.epico,
      biome: 'zona1', growSec: 840, price: 130, xp: 60,
      lore: 'Los pétalos llevan las mismas runas que la fuente.'),
  'melon_engranaje': CropDef('melon_engranaje', 'Melón engranaje',
      FishRarity.epico,
      biome: 'zona1', growSec: 900, price: 150, xp: 66,
      lore: 'Sus semillas encastran como piezas de un mecanismo antiguo.'),
  'trigo_manana': CropDef('trigo_manana', 'Trigo del Mañana',
      FishRarity.legendario,
      biome: 'zona1', growSec: 1500, price: 850, xp: 225,
      lore: 'Un eco del futuro: ya lo cosechaste, solo que todavía no.'),
  'rosa_reloj': CropDef('rosa_reloj', 'Rosa del Reloj Quieto',
      FishRarity.legendario,
      biome: 'zona1', growSec: 1650, price: 950, xp: 240,
      lore: 'Florece a una hora que no avanza.'),
  'raiz_era': CropDef('raiz_era', 'Raíz de la Era Antigua',
      FishRarity.legendario,
      biome: 'zona1', growSec: 1800, price: 1100, xp: 262,
      lore: 'Creció cuando el pasado era más avanzado que el presente.'),
  // Winter crops (weather_seasons.md § 5, v0.44.0): they only grow in
  // winter, and only then can they be harvested.
  'rabano_nieve': CropDef('rabano_nieve', 'Rábano de nieve', FishRarity.comun,
      biome: 'zona1', growSec: 180, price: 18, xp: 12, seedPrice: 7,
      seasons: {Season.winter}),
  'col_invierno': CropDef('col_invierno', 'Col de invierno', FishRarity.comun,
      biome: 'zona1', growSec: 280, price: 26, xp: 15, seedPrice: 10,
      seasons: {Season.winter}),
  'puerro_helado': CropDef('puerro_helado', 'Puerro helado', FishRarity.raro,
      biome: 'zona1', growSec: 500, price: 70, xp: 30, seedPrice: 40,
      seasons: {Season.winter},
      lore: 'Lo dulce le sale con la primera helada.'),
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
  // Semillas exclusivas de RUINAS (overworld_biomes.md § 3.3).
  'lirio_mecanico': CropDef('lirio_mecanico', 'Lirio mecánico', FishRarity.comun,
      biome: 'ruinas', growSec: 380, price: 34, xp: 12),
  'calabaza_runica': CropDef('calabaza_runica', 'Calabaza rúnica', FishRarity.raro,
      biome: 'ruinas', growSec: 700, price: 85, xp: 25),
  'olivo_eras': CropDef('olivo_eras', 'Olivo de las Eras', FishRarity.epico,
      biome: 'ruinas', growSec: 1300, price: 250, xp: 60,
      lore: 'Da frutos que maduran en una época que ya pasó.'),
  // Semillas exclusivas de CAVERNAS (overworld_biomes.md § 3.3).
  'nabo_escarcha': CropDef('nabo_escarcha', 'Nabo de escarcha', FishRarity.comun,
      biome: 'cavernas', growSec: 420, price: 46, xp: 14,
      seasons: kAllSeasons),
  'flor_cristal': CropDef('flor_cristal', 'Flor de cristal', FishRarity.raro,
      biome: 'cavernas', growSec: 780, price: 115, xp: 30,
      seasons: kAllSeasons),
  'lirio_eco': CropDef('lirio_eco', 'Lirio del eco', FishRarity.epico,
      biome: 'cavernas', growSec: 1400, price: 320, xp: 70,
      lore: 'Repite su perfume un rato después de cortarlo.',
      seasons: kAllSeasons),
  // Semillas exclusivas de GRIETA (overworld_biomes.md § 3.3).
  'chile_volcan': CropDef('chile_volcan', 'Chile de volcán', FishRarity.comun,
      biome: 'grieta', growSec: 460, price: 60, xp: 16),
  'flor_brasa': CropDef('flor_brasa', 'Flor de brasa', FishRarity.raro,
      biome: 'grieta', growSec: 840, price: 150, xp: 34),
  'fruta_forja': CropDef('fruta_forja', 'Fruta de la forja', FishRarity.epico,
      biome: 'grieta', growSec: 1500, price: 400, xp: 80,
      lore: 'Late caliente, como un mecanismo que sigue andando.'),
  // Semillas exclusivas de ABISMO (overworld_biomes.md § 3.3).
  'trigo_eco': CropDef('trigo_eco', 'Trigo del eco', FishRarity.comun,
      biome: 'abismo', growSec: 500, price: 80, xp: 18),
  'rosa_futuro': CropDef('rosa_futuro', 'Rosa del futuro', FishRarity.raro,
      biome: 'abismo', growSec: 900, price: 190, xp: 40),
  'arbol_paradoja': CropDef('arbol_paradoja', 'Árbol paradoja', FishRarity.epico,
      biome: 'abismo', growSec: 1600, price: 520, xp: 95,
      lore: 'Ya lo cosechaste. Plantarlo es solo cumplirlo.'),
  // Productos silvestres de los biomas (se recolectan; nunca dan semilla).
  'musgo_cobre': CropDef('musgo_cobre', 'Musgo de cobre', FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 18, xp: 7),
  'liquen_runa': CropDef('liquen_runa', 'Liquen rúnico', FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 22, xp: 8),
  'baya_engranaje': CropDef('baya_engranaje', 'Bayas de engranaje', FishRarity.raro,
      biome: 'silvestre', growSec: 1e9, price: 48, xp: 15),
  'cristal_escarcha': CropDef('cristal_escarcha', 'Cristales de escarcha', FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 26, xp: 9),
  'liquen_azul': CropDef('liquen_azul', 'Liquen azul', FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 28, xp: 9),
  'hongo_frio': CropDef('hongo_frio', 'Hongos fríos', FishRarity.raro,
      biome: 'silvestre', growSec: 1e9, price: 60, xp: 17),
  'pimiento_brasa': CropDef('pimiento_brasa', 'Pimientos de brasa', FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 34, xp: 10),
  'flor_ceniza': CropDef('flor_ceniza', 'Flores de ceniza', FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 36, xp: 10),
  'raiz_ignea': CropDef('raiz_ignea', 'Raíces ígneas', FishRarity.raro,
      biome: 'silvestre', growSec: 1e9, price: 75, xp: 19),
  'polvo_eco': CropDef('polvo_eco', 'Polvo de eco', FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 42, xp: 11),
  'flor_manana': CropDef('flor_manana', 'Flores del mañana', FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 46, xp: 12),
  'fruto_paradoja': CropDef('fruto_paradoja', 'Frutos paradoja', FishRarity.raro,
      biome: 'silvestre', growSec: 1e9, price: 90, xp: 22),
  // Region forage (biome_regions.md § 5): seasonal sprouts of every biome
  // (one per season) and the rare echo bloom of the optional nooks.
  'brote_primavera': CropDef('brote_primavera', 'Brote de primavera',
      FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 16, xp: 7),
  'fresa_estival': CropDef('fresa_estival', 'Fresa estival', FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 18, xp: 7),
  'castana_otono': CropDef('castana_otono', 'Castaña de otoño',
      FishRarity.comun,
      biome: 'silvestre', growSec: 1e9, price: 18, xp: 7),
  'baya_invierno': CropDef('baya_invierno', 'Baya de invierno',
      FishRarity.raro,
      biome: 'silvestre', growSec: 1e9, price: 30, xp: 10),
  'flor_eco': CropDef('flor_eco', 'Flor del eco', FishRarity.epico,
      biome: 'silvestre', growSec: 1e9, price: 160, xp: 40,
      lore: 'Florece donde el tiempo se repite: dura lo que dura un eco.'),
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
