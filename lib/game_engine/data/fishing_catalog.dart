// Peces y cañas (docs/specs/fishing.md § 2 y § 4). Datos puros: los lee
// `FishingRules`; la UI solo los muestra.

import '../models/sky.dart';

export '../models/sky.dart' show Season, Weather, kAllSeasons, kWarmSeasons;

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
      this.lore = '',
      this.seasons = kAllSeasons,
      this.weather,
      this.visitor = false,
      this.minDepth = 0});

  /// Open-water species (fishing.md § 15): only bites with the bobber at
  /// least this many tiles from the shore (a raft on a big lake). Not in
  /// any stored lake list; joins its [biome]'s table out there.
  final int minDepth;

  /// Seasons when it bites (weather_seasons.md § 4): out of season it
  /// never bites, not even off-hours.
  final Set<Season> seasons;

  /// Weather it needs (`null` = any, or the time rule of fishing.md
  /// § 13). Set here, it is strict: only in that weather.
  final Weather? weather;

  /// Seasonal / weather visitor (§ 4.2): not part of any stored lake
  /// list; it joins the lakes of its [biome] while its season and
  /// weather hold.
  final bool visitor;

  final String id;
  final String name;
  final FishRarity rarity;

  /// Bioma donde vive (fishing.md § 2.1): `zona1` … `zona10`. El lago del
  /// pueblo arranca con las especies de `zona1` (`TownState.lake`).
  final String biome;
  final int minCm, maxCm;

  /// Precio base en oro (el agropecuario; fishing.md § 5).
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

  /// Precio en el agropecuario (0 = no se vende).
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
      biome: 'zona1', minCm: 20, maxCm: 45, price: 18, xp: 8,
      seasons: kWarmSeasons),
  'trucha_cobre': FishDef('trucha_cobre', 'Trucha de cobre', FishRarity.raro,
      biome: 'zona1', minCm: 25, maxCm: 50, price: 45, xp: 16,
      seasons: {Season.autumn, Season.winter, Season.spring}),
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
          'desovar en el pasado, y siempre llega.',
      seasons: {Season.autumn, Season.winter}),
  // Lago de RUINAS (overworld_biomes.md § 3, v0.29.0).
  'carpa_cobre': FishDef('carpa_cobre', 'Carpa de cobre', FishRarity.comun,
      biome: 'ruinas', minCm: 12, maxCm: 30, price: 30, xp: 10),
  'anguila_runa': FishDef('anguila_runa', 'Anguila de runa', FishRarity.comun,
      biome: 'ruinas', minCm: 30, maxCm: 70, price: 36, xp: 11),
  'pez_pinon': FishDef('pez_pinon', 'Pez piñón', FishRarity.raro,
      biome: 'ruinas', minCm: 20, maxCm: 45, price: 85, xp: 24,
      lore: 'Las aletas giran como piezas de un mecanismo antiguo.'),
  'barbo_reloj': FishDef('barbo_reloj', 'Barbo de relojería', FishRarity.epico,
      biome: 'ruinas', minCm: 50, maxCm: 110, price: 240, xp: 60,
      lore: 'Lo armó alguien del pasado, y sigue nadando.'),
  'esturion_eras': FishDef('esturion_eras', 'Esturión de las Eras', FishRarity.legendario,
      biome: 'ruinas', minCm: 90, maxCm: 180, price: 1600, xp: 220,
      lore: 'Nadaba en estas aguas cuando el mundo era más avanzado.'),
  // Lago de CAVERNAS (overworld_biomes.md § 3, v0.29.0).
  'pez_escarcha': FishDef('pez_escarcha', 'Pez de escarcha', FishRarity.comun,
      biome: 'cavernas', minCm: 10, maxCm: 24, price: 44, xp: 13),
  'lenguado_cristal': FishDef('lenguado_cristal', 'Lenguado de cristal', FishRarity.comun,
      biome: 'cavernas', minCm: 18, maxCm: 40, price: 52, xp: 14),
  'trucha_hielo': FishDef('trucha_hielo', 'Trucha de hielo', FishRarity.raro,
      biome: 'cavernas', minCm: 25, maxCm: 60, price: 120, xp: 30),
  'lucio_frio': FishDef('lucio_frio', 'Lucio del eco frío', FishRarity.epico,
      biome: 'cavernas', minCm: 60, maxCm: 130, price: 330, xp: 75,
      lore: 'Su eco llega al anzuelo antes que él.'),
  'pez_invierno': FishDef('pez_invierno', 'Pez del Invierno que Vendrá', FishRarity.legendario,
      biome: 'cavernas', minCm: 80, maxCm: 160, price: 2100, xp: 270,
      lore: 'Un eco del futuro: el frío que todavía no llegó.',
      seasons: {Season.autumn, Season.winter}),
  // Lago de GRIETA (overworld_biomes.md § 3, v0.29.0).
  'pez_ceniza': FishDef('pez_ceniza', 'Pez ceniza', FishRarity.comun,
      biome: 'grieta', minCm: 10, maxCm: 26, price: 62, xp: 16),
  'bagre_brasa': FishDef('bagre_brasa', 'Bagre de brasa', FishRarity.comun,
      biome: 'grieta', minCm: 25, maxCm: 60, price: 72, xp: 17),
  'salamandra_lago': FishDef('salamandra_lago', 'Salamandra del lago', FishRarity.raro,
      biome: 'grieta', minCm: 20, maxCm: 50, price: 170, xp: 38),
  'dorado_igneo': FishDef('dorado_igneo', 'Dorado ígneo', FishRarity.epico,
      biome: 'grieta', minCm: 55, maxCm: 120, price: 450, xp: 90,
      lore: 'Brilla como el mecanismo que calienta la grieta.',
      seasons: kWarmSeasons),
  'pez_ultimo_fuego': FishDef('pez_ultimo_fuego', 'Pez del Último Fuego', FishRarity.legendario,
      biome: 'grieta', minCm: 80, maxCm: 170, price: 2800, xp: 330,
      lore: 'Viene del día en que se apagó el pasado.'),
  // Lago de ABISMO (overworld_biomes.md § 3, v0.29.0).
  'pez_eco': FishDef('pez_eco', 'Pez eco', FishRarity.comun,
      biome: 'abismo', minCm: 12, maxCm: 30, price: 85, xp: 20),
  'medusa_manana': FishDef('medusa_manana', 'Medusa del mañana', FishRarity.comun,
      biome: 'abismo', minCm: 20, maxCm: 50, price: 98, xp: 21,
      seasons: {Season.spring, Season.summer}),
  'raya_reloj': FishDef('raya_reloj', 'Raya del reloj', FishRarity.raro,
      biome: 'abismo', minCm: 40, maxCm: 90, price: 230, xp: 46),
  'pez_paradoja': FishDef('pez_paradoja', 'Pez paradoja', FishRarity.epico,
      biome: 'abismo', minCm: 50, maxCm: 120, price: 620, xp: 110,
      lore: 'Lo pescaste mañana; hoy solo lo sacás.'),
  'leviatan_quieto': FishDef('leviatan_quieto', 'Leviatán del Futuro Quieto', FishRarity.legendario,
      biome: 'abismo', minCm: 150, maxCm: 300, price: 3800, xp: 400,
      lore: 'El futuro no se cambia: él ya estaba en tu red.'),
  // Aguas abiertas de los lagos grandes (fishing.md § 15): solo lejos de
  // la orilla, desde una balsa.
  'lucio_hondo': FishDef('lucio_hondo', 'Lucio de la hondura', FishRarity.epico,
      biome: 'bosque', minCm: 70, maxCm: 150, price: 260, xp: 70,
      minDepth: 4,
      lore: 'Nada donde la luz del bosque ya no llega, esperando a alguien que se fue.'),
  'carpa_olvido': FishDef('carpa_olvido', 'Carpa del Olvido', FishRarity.legendario,
      biome: 'bosque', minCm: 110, maxCm: 200, price: 1500, xp: 230,
      minDepth: 5,
      lore: 'Guarda en las escamas los nombres que el bosque ya no recuerda.'),
  'barbo_campana': FishDef('barbo_campana', 'Barbo de la campana hundida', FishRarity.epico,
      biome: 'ruinas', minCm: 60, maxCm: 130, price: 380, xp: 85,
      minDepth: 4,
      lore: 'Suena como una campana que llamaba a una ciudad que ya no existe.'),
  'pez_archivo': FishDef('pez_archivo', 'Pez del Archivo Ahogado', FishRarity.legendario,
      biome: 'ruinas', minCm: 100, maxCm: 210, price: 2100, xp: 290,
      minDepth: 5,
      lore: 'Lleva grabada la última página de una biblioteca que el agua cerró.'),
  'lucio_silencio': FishDef('lucio_silencio', 'Lucio del silencio', FishRarity.epico,
      biome: 'cavernas', minCm: 70, maxCm: 150, price: 500, xp: 110,
      minDepth: 4,
      lore: 'En lo hondo del lago helado no se oye ni el eco de su propia aleta.'),
  'esturion_escarcha': FishDef('esturion_escarcha', 'Esturión de la Escarcha Eterna', FishRarity.legendario,
      biome: 'cavernas', minCm: 140, maxCm: 260, price: 2800, xp: 350,
      minDepth: 5,
      lore: 'Lo congeló un invierno que todavía no llegó, y aun así sigue nadando.'),
  'dorado_rescoldo': FishDef('dorado_rescoldo', 'Dorado del rescoldo', FishRarity.epico,
      biome: 'grieta', minCm: 65, maxCm: 140, price: 650, xp: 130,
      minDepth: 4,
      lore: 'Brilla como la última brasa de un hogar que nadie volvió a encender.'),
  'pez_forja_muda': FishDef('pez_forja_muda', 'Pez de la Forja Muda', FishRarity.legendario,
      biome: 'grieta', minCm: 120, maxCm: 230, price: 3600, xp: 420,
      minDepth: 5,
      lore: 'Nació del calor de una forja que se apagó cuando el pasado era más grande.'),
  'raya_adios': FishDef('raya_adios', 'Raya del adiós', FishRarity.epico,
      biome: 'abismo', minCm: 80, maxCm: 170, price: 850, xp: 150,
      minDepth: 4,
      lore: 'Pasa una sola vez junto a cada balsa, como una despedida que ya ocurrió.'),
  'ballena_eco': FishDef('ballena_eco', 'Ballena del Último Eco', FishRarity.legendario,
      biome: 'abismo', minCm: 200, maxCm: 400, price: 4800, xp: 500,
      minDepth: 5,
      lore: 'Canta lo que el futuro ya decidió; nadie la escucha dos veces.'),
  // Seasonal and weather visitors (weather_seasons.md § 4.2, v0.44.0):
  // they join the lakes of their biome only in their season / weather.
  'mojarra_primavera': FishDef('mojarra_primavera', 'Mojarra de primavera',
      FishRarity.comun,
      biome: 'zona1', minCm: 8, maxCm: 18, price: 16, xp: 8,
      seasons: {Season.spring}, visitor: true),
  'carpa_nevada': FishDef('carpa_nevada', 'Carpa nevada', FishRarity.raro,
      biome: 'zona1', minCm: 25, maxCm: 55, price: 60, xp: 20,
      seasons: {Season.winter}, visitor: true,
      lore: 'Sube a la orilla cuando el lago se enfría.'),
  'pez_copo': FishDef('pez_copo', 'Pez copo', FishRarity.raro,
      biome: 'zona1', minCm: 10, maxCm: 22, price: 70, xp: 22,
      seasons: {Season.winter}, weather: Weather.snow, visitor: true,
      lore: 'Solo nada mientras nieva; después nadie lo encuentra.'),
  'pez_bruma': FishDef('pez_bruma', 'Pez de bruma', FishRarity.epico,
      biome: 'zona1', minCm: 30, maxCm: 70, price: 180, xp: 48,
      weather: Weather.fog, visitor: true,
      lore: 'Se ve mejor cuando no se ve nada.'),
  'perca_hojas': FishDef('perca_hojas', 'Perca de hojas', FishRarity.comun,
      biome: 'bosque', minCm: 12, maxCm: 28, price: 20, xp: 9,
      seasons: {Season.autumn}, visitor: true),
  'trucha_tormenta': FishDef('trucha_tormenta', 'Trucha de tormenta',
      FishRarity.epico,
      biome: 'bosque', minCm: 40, maxCm: 90, price: 190, xp: 50,
      weather: Weather.tormenta, visitor: true,
      lore: 'Salta cuando cae el rayo, como si lo esperara.'),
  'anguila_niebla': FishDef('anguila_niebla', 'Anguila de niebla',
      FishRarity.raro,
      biome: 'ruinas', minCm: 40, maxCm: 90, price: 110, xp: 28,
      weather: Weather.fog, visitor: true,
      lore: 'Se enrosca en los engranajes hundidos cuando baja la niebla.'),
  'dorado_estival': FishDef('dorado_estival', 'Dorado estival',
      FishRarity.raro,
      biome: 'grieta', minCm: 30, maxCm: 70, price: 200, xp: 42,
      seasons: {Season.summer}, visitor: true),
  'raya_relampago': FishDef('raya_relampago', 'Raya del relámpago',
      FishRarity.epico,
      biome: 'abismo', minCm: 60, maxCm: 140, price: 700, xp: 120,
      weather: Weather.tormenta, visitor: true,
      lore: 'Lleva en el lomo la luz de un rayo que todavía no cayó.'),
  // Basura de los lagos de bioma (fishing.md § 8).
  'engranaje_oxidado': FishDef('engranaje_oxidado', 'Engranaje oxidado', FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 5, maxCm: 12, price: 1, xp: 1),
  'placa_rota': FishDef('placa_rota', 'Placa rúnica rota', FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 10, maxCm: 30, price: 1, xp: 1),
  'estalactita_rota': FishDef('estalactita_rota', 'Estalactita rota', FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 15, maxCm: 40, price: 1, xp: 1),
  'guante_helado': FishDef('guante_helado', 'Guante helado', FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 15, maxCm: 22, price: 1, xp: 1),
  'escoria': FishDef('escoria', 'Escoria', FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 5, maxCm: 20, price: 1, xp: 1),
  'hueso_chamuscado': FishDef('hueso_chamuscado', 'Hueso chamuscado', FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 10, maxCm: 35, price: 1, xp: 1),
  'arena_reloj': FishDef('arena_reloj', 'Arena de reloj', FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 3, maxCm: 8, price: 1, xp: 1),
  'manecilla_perdida': FishDef('manecilla_perdida', 'Manecilla perdida', FishRarity.comun,
      biome: kWaterJunkBiome, minCm: 5, maxCm: 15, price: 1, xp: 1),
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
        if (f.biome == kTownStartBiome && !f.visitor) f.id
    ];

/// Open-water species of [biome] that bite at [depth] tiles from the
/// shore (fishing.md § 15).
List<String> deepFishOf(String? biome, int depth) => [
      for (final f in kFish.values)
        if (f.minDepth > 0 && f.biome == biome && depth >= f.minDepth) f.id
    ];
