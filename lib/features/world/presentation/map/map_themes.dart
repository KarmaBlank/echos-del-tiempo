import 'dart:ui';

/// Colores de tiles de un tema de mapa (`THEMES` del prototipo, líneas
/// 298-303, más los temas del mundo y de las zonas de worldgen.md § 7.6).
/// Son arte, no chrome de UI: no pasan por `RetroPalette`
/// (docs/specs/exploration.md § "Decisión de color").
class MapTheme {
  const MapTheme({
    required this.ground,
    required this.ground2,
    required this.wall,
    required this.wall2,
    required this.path,
    required this.path2,
    required this.water,
    this.grass = const Color(0xFF4FA046),
    this.grass2 = const Color(0xFF67B85A),
    this.tree = const Color(0xFF1F5F2A),
    this.tree2 = const Color(0xFF2F7D37),
    this.trunk = const Color(0xFF4A2F1A),
    this.rock = const Color(0xFF6B6F7A),
    this.rock2 = const Color(0xFF8C909C),
  });

  /// `g`, `g2`: suelo y su detalle.
  final Color ground, ground2;

  /// `w`, `w2`: muro y su detalle.
  final Color wall, wall2;

  /// `path`, `p2`: camino y su detalle.
  final Color path, path2;

  /// `wat`: agua.
  final Color water;

  /// Pasto (`g`), árbol (`T`) y roca (`^`) del mapa del mundo.
  final Color grass, grass2, tree, tree2, trunk, rock, rock2;
}

/// Temas por id (`GameMap.theme`).
const Map<String, MapTheme> kMapThemes = {
  'pradera': MapTheme(
    ground: Color(0xFF3F8F3A),
    ground2: Color(0xFF57A84A),
    wall: Color(0xFF1F5F2A),
    wall2: Color(0xFF2F7D37),
    path: Color(0xFFB89A5A),
    path2: Color(0xFFA3874C),
    water: Color(0xFF2E86DE),
  ),
  'ruinas': MapTheme(
    ground: Color(0xFF5F5F68),
    ground2: Color(0xFF6C6C76),
    wall: Color(0xFF34343C),
    wall2: Color(0xFF82828E),
    path: Color(0xFF8A7F6A),
    path2: Color(0xFF776D5A),
    water: Color(0xFF1E6091),
  ),
  // Zona 9 (v0.3): islas de roca flotante sobre vacío azul profundo.
  'abismo': MapTheme(
    ground: Color(0xFF4A5372),
    ground2: Color(0xFF5A6488),
    wall: Color(0xFF262B40),
    wall2: Color(0xFF8A96C0),
    path: Color(0xFF5E6890),
    path2: Color(0xFF50597C),
    water: Color(0xFF2A4AA0),
    rock: Color(0xFF323954),
    rock2: Color(0xFF6A76A0),
  ),
  'lobby': MapTheme(
    ground: Color(0xFF2D3A55),
    ground2: Color(0xFF34446A),
    wall: Color(0xFF161D33),
    wall2: Color(0xFF3D4D80),
    path: Color(0xFF5A3A6A),
    path2: Color(0xFF4A2F5A),
    water: Color(0xFF48DBFB),
  ),
  // El pueblo v0.21.0 (town_loop.md § 2.1): claro de bosque al aire
  // libre, caminos de tierra y el lago.
  'pueblo': MapTheme(
    ground: Color(0xFF4A9A44),
    ground2: Color(0xFF5FB153),
    wall: Color(0xFF1F5F2A),
    wall2: Color(0xFF2F7D37),
    path: Color(0xFFB08A55),
    path2: Color(0xFF977445),
    water: Color(0xFF2F7FC8),
    grass: Color(0xFF4A9A44),
    grass2: Color(0xFF5FB153),
    tree: Color(0xFF1C5A2A),
    tree2: Color(0xFF2E7A38),
  ),
  // Exterior del Bosque (overworld_biomes.md § 3, v0.26.0): pasto más
  // oscuro que el pueblo, árboles densos y agua verdosa.
  'bosque_ext': MapTheme(
    ground: Color(0xFF3A7A3C),
    ground2: Color(0xFF4A8E46),
    wall: Color(0xFF154520),
    wall2: Color(0xFF235F2C),
    path: Color(0xFF8C6E45),
    path2: Color(0xFF76603C),
    water: Color(0xFF256B7A),
    grass: Color(0xFF3A7A3C),
    grass2: Color(0xFF4A8E46),
    tree: Color(0xFF14421E),
    tree2: Color(0xFF22602C),
    trunk: Color(0xFF3A2414),
  ),
  // Ruinas: piedra gris y musgo de cobre, agua turquesa. (overworld_biomes.md § 3, v0.29.0).
  'ruinas_ext': MapTheme(
    ground: Color(0xFF3E4A3A),
    ground2: Color(0xFF4C5A46),
    wall: Color(0xFF2A2E30),
    wall2: Color(0xFF3C4246),
    path: Color(0xFF8A8270),
    path2: Color(0xFF6E6858),
    water: Color(0xFF2A8A8A),
    grass: Color(0xFF4A5A44),
    grass2: Color(0xFF5A6A50),
    tree: Color(0xFF3A3E44),
    tree2: Color(0xFF52585E),
    trunk: Color(0xFF2A2420),
  ),
  // Cavernas: piso de hielo, roca azul, agua helada (sin cielo). (overworld_biomes.md § 3, v0.29.0).
  'cavernas_ext': MapTheme(
    ground: Color(0xFF5A6A7E),
    ground2: Color(0xFF6A7C92),
    wall: Color(0xFF1E2A3A),
    wall2: Color(0xFF2E3E52),
    path: Color(0xFF8A9AAE),
    path2: Color(0xFF76869A),
    water: Color(0xFF6AB8E0),
    grass: Color(0xFF5A6A7E),
    grass2: Color(0xFF7A8EA6),
    tree: Color(0xFF2A3A4E),
    tree2: Color(0xFF40546E),
    trunk: Color(0xFF1A2230),
  ),
  // Grieta: tierra quemada, roca negra y lago de brasas. (overworld_biomes.md § 3, v0.29.0).
  'grieta_ext': MapTheme(
    ground: Color(0xFF4A3028),
    ground2: Color(0xFF5A3A2E),
    wall: Color(0xFF1E1414),
    wall2: Color(0xFF30201C),
    path: Color(0xFF7A5A40),
    path2: Color(0xFF644832),
    water: Color(0xFFD8541E),
    grass: Color(0xFF4A3028),
    grass2: Color(0xFF62402E),
    tree: Color(0xFF261A18),
    tree2: Color(0xFF3E2A24),
    trunk: Color(0xFF140C0A),
  ),
  // Abismo: piso violeta, cristales del futuro y mar de ecos. (overworld_biomes.md § 3, v0.29.0).
  'abismo_ext': MapTheme(
    ground: Color(0xFF2E2A4A),
    ground2: Color(0xFF3A3458),
    wall: Color(0xFF14102A),
    wall2: Color(0xFF24203E),
    path: Color(0xFF6A6290),
    path2: Color(0xFF585078),
    water: Color(0xFF4A6AD8),
    grass: Color(0xFF2E2A4A),
    grass2: Color(0xFF463E6A),
    tree: Color(0xFF1E1A36),
    tree2: Color(0xFF3A3060),
    trunk: Color(0xFF100C20),
  ),
  // Mapa del mundo fuera del pueblo (el pueblo usa `lobby`).
  'mundo': MapTheme(
    ground: Color(0xFF4FA046),
    ground2: Color(0xFF67B85A),
    wall: Color(0xFF1F5F2A),
    wall2: Color(0xFF2F7D37),
    path: Color(0xFFC2A266),
    path2: Color(0xFFA88B52),
    water: Color(0xFF2E86DE),
  ),
  // Zona 2: verde oscuro, árboles densos.
  'bosque': MapTheme(
    ground: Color(0xFF30683A),
    ground2: Color(0xFF3E7D44),
    wall: Color(0xFF113A1C),
    wall2: Color(0xFF1D5A2A),
    path: Color(0xFF6E5A3A),
    path2: Color(0xFF5C4A2E),
    water: Color(0xFF1E5F74),
    tree: Color(0xFF113A1C),
    tree2: Color(0xFF1D5A2A),
    trunk: Color(0xFF3A2414),
  ),
  // Mina de bosque (mining_smithing.md § 1.2): cueva oscura.
  'mina_bosque': MapTheme(
    ground: Color(0xFF3A3328),
    ground2: Color(0xFF473E31),
    wall: Color(0xFF1E1A14),
    wall2: Color(0xFF5C4A30),
    path: Color(0xFF473E31),
    path2: Color(0xFF3A3328),
    water: Color(0xFF2A4A6A),
  ),
  // Mina de ruinas (mining_smithing.md § 1.2): cueva oscura.
  'mina_ruinas': MapTheme(
    ground: Color(0xFF3B3A40),
    ground2: Color(0xFF48464F),
    wall: Color(0xFF1F1E24),
    wall2: Color(0xFFB08A3A),
    path: Color(0xFF48464F),
    path2: Color(0xFF3B3A40),
    water: Color(0xFF2A4A6A),
  ),
  // Mina de cavernas (mining_smithing.md § 1.2): cueva oscura.
  'mina_cavernas': MapTheme(
    ground: Color(0xFF3A4658),
    ground2: Color(0xFF46546A),
    wall: Color(0xFF1C2433),
    wall2: Color(0xFF9FDCF5),
    path: Color(0xFF46546A),
    path2: Color(0xFF3A4658),
    water: Color(0xFF2A4A6A),
  ),
  // Mina de grieta (mining_smithing.md § 1.2): cueva oscura.
  'mina_grieta': MapTheme(
    ground: Color(0xFF332A28),
    ground2: Color(0xFF40342F),
    wall: Color(0xFF1A1414),
    wall2: Color(0xFFFF7B29),
    path: Color(0xFF40342F),
    path2: Color(0xFF332A28),
    water: Color(0xFF2A4A6A),
  ),
  // Mina de abismo (mining_smithing.md § 1.2): cueva oscura.
  'mina_abismo': MapTheme(
    ground: Color(0xFF2E2A40),
    ground2: Color(0xFF3A3550),
    wall: Color(0xFF16131F),
    wall2: Color(0xFFC08AFF),
    path: Color(0xFF3A3550),
    path2: Color(0xFF2E2A40),
    water: Color(0xFF2A4A6A),
  ),
  // Zona 4: hielo — suelo azul grisáceo, roca helada, agua cian.
  'cavernas': MapTheme(
    ground: Color(0xFF4A5A70),
    ground2: Color(0xFF5B6E86),
    wall: Color(0xFF26304A),
    wall2: Color(0xFF9FDCF5),
    path: Color(0xFF6E8299),
    path2: Color(0xFF5E7188),
    water: Color(0xFF3FC4E6),
    rock: Color(0xFF3A4660),
    rock2: Color(0xFF5A6A88),
  ),
  // Zona 5: piedra oscura, caminos de losa.
  'fortaleza': MapTheme(
    ground: Color(0xFF3A3642),
    ground2: Color(0xFF47424F),
    wall: Color(0xFF221E2A),
    wall2: Color(0xFF55505F),
    path: Color(0xFF4C4856),
    path2: Color(0xFF403C4A),
    water: Color(0xFF2A4A6A),
  ),
  // Zona 6: piedra azul pizarra, bronce, pasillos de losa.
  'laberinto': MapTheme(
    ground: Color(0xFF3B4A63),
    ground2: Color(0xFF46577A),
    wall: Color(0xFF222C3F),
    wall2: Color(0xFFB08A3A),
    path: Color(0xFF56647E),
    path2: Color(0xFF4A5770),
    water: Color(0xFF2A4A6A),
  ),
  // Zona 7: basalto oscuro, suelo de ceniza, lava.
  'grieta': MapTheme(
    ground: Color(0xFF2F2A2C),
    ground2: Color(0xFF3D3537),
    wall: Color(0xFF1A1618),
    wall2: Color(0xFFFF7B29),
    path: Color(0xFF4A3E3A),
    path2: Color(0xFF3E3431),
    water: Color(0xFFC0391B),
    rock: Color(0xFF241F21),
    rock2: Color(0xFF3A3335),
  ),
  // Zona 8: islas de tierra gris con pasto seco sobre vacío violeta.
  'cementerio': MapTheme(
    ground: Color(0xFF5A5D5A),
    ground2: Color(0xFF6C706A),
    wall: Color(0xFF2E2C35),
    wall2: Color(0xFF7E8A5A),
    path: Color(0xFF6E6A5E),
    path2: Color(0xFF5E5A50),
    water: Color(0xFF3A2A5A),
    rock: Color(0xFF3A3842),
    rock2: Color(0xFF5E5C68),
  ),
  // Zona 10: cristal dorado / blanco sobre vacío, arena rúnica.
  'corazon': MapTheme(
    ground: Color(0xFFD9C58A),
    ground2: Color(0xFFEFE2B0),
    wall: Color(0xFF6B5A2A),
    wall2: Color(0xFFFFF3C4),
    path: Color(0xFFC9B06A),
    path2: Color(0xFFB89C56),
    water: Color(0xFF6C4AD9),
    rock: Color(0xFF8A7440),
    rock2: Color(0xFFB8A060),
  ),
};

/// Temas con islas sobre vacío (el `#` es roca flotante; worldgen.md § 9.1).
const kAbyssThemes = {'abismo', 'cementerio', 'corazon'};

/// Fondo del vacío por tema: arriba y abajo del degradado
/// (exploration.md § "Fondo del vacío").
(Color, Color) voidGradient(String themeId) => switch (themeId) {
      'cementerio' => (const Color(0xFF0A0614), const Color(0xFF22123A)),
      'corazon' => (const Color(0xFF0A0818), const Color(0xFF2A1C3A)),
      _ => (const Color(0xFF04061A), const Color(0xFF0C1838)),
    };

/// Tema de un mapa (pradera si el id no existe).
MapTheme mapTheme(String id) => kMapThemes[id] ?? kMapThemes['pradera']!;

/// Fondo fuera del mapa (`#05060c`).
const kMapBackground = Color(0xFF05060C);

/// Color de cada zona (1..10): portal de la entrada y marca del minimapa.
const kZoneColors = <int, Color>{
  1: Color(0xFF7BED9F),
  2: Color(0xFF2ED573),
  3: Color(0xFFFFD166),
  4: Color(0xFF48DBFB),
  5: Color(0xFFFF6B81),
  6: Color(0xFFA29BFE),
  7: Color(0xFFFF7B29),
  8: Color(0xFFDFE6E9),
  9: Color(0xFF9B59FF),
  10: Color(0xFFE84393),
};

/// Color de la zona [zone] (blanco si no existe).
Color zoneColor(int zone) => kZoneColors[zone] ?? const Color(0xFFFFFFFF);

/// Gris de una entrada bloqueada.
const kLockedZoneColor = Color(0xFF6C6F7A);

/// El pueblo dentro del mapa del mundo: tiles `0..25 × 0..13`
/// (worldgen.md § 6.5). Ahí se dibuja con el estilo del lobby.
bool inTown(int tx, int ty) => tx < 26 && ty < 14;

/// Colores de la torrecita del Loot perdido del pueblo (v0.20.22).
abstract final class LostTowerPalette {
  static const base = Color(0xFF34404F);
  static const rim = Color(0xFF8395A7);
  static const stone = Color(0xFF6B7A8F);
  static const cap = Color(0xFF4B5869);
  static const glow = Color(0xFFFFD166);
}

/// Colores de los lugares nuevos del pueblo v0.21.0 (fuente rúnica,
/// puntos de pesca y cartel del lago; town_loop.md § 2.1).
abstract final class TownPalette {
  static const stone = Color(0xFF8C93A3);
  static const stoneDark = Color(0xFF5B6170);
  static const basin = Color(0xFF3F8FD6);
  static const rune = Color(0xFF5AE6D2);
  static const plank = Color(0xFF9A6B3C);
  static const plankDark = Color(0xFF6B4423);
  static const bobber = Color(0xFFE74C3C);
  static const foam = Color(0x66FFFFFF);
  static const signBoard = Color(0xFFC08A4A);
  static const label = Color(0xFFFFF3C4);

  /// "!" de un habitante con pedido u orden (overworld_biomes.md § 10.4).
  static const request = Color(0xFFFFC83D);
}

/// Colores de la edición del pueblo (town_editor.md § 1.3).
abstract final class TownEditPalette {
  /// Franja fantasma de una ampliación.
  static const side = Color(0x3366C2FF);
  static const sideBorder = Color(0xFF66C2FF);
  static const sideText = Color(0xFFDDF2FF);
  static const sideLocked = Color(0xFF9AA0AC);

  /// Franja de un lado al tope (gris, no se elige).
  static const sideFull = Color(0x339AA0AC);

  /// Contorno de cada construcción y el de la elegida.
  static const outline = Color(0x99FFF3C4);
  static const selected = Color(0xFFFFD166);

  /// Fantasma de lo que se mueve o se pone.
  static const valid = Color(0x6655E07A);
  static const validBorder = Color(0xFF55E07A);
  static const invalid = Color(0x66FF5C5C);
  static const invalidBorder = Color(0xFFFF5C5C);
  static const lakeGhost = Color(0x663F8FD6);
}

/// Colores de la huerta (farming.md § 2.3, v0.23.0).
abstract final class FarmPalette {
  static const soil = Color(0xFF7A5534);
  static const soilDark = Color(0xFF5C3D24);
  static const tilled = Color(0xFF5A3A22);
  static const furrow = Color(0xFF3E2716);
  static const wet = Color(0xFF3A2414);
  static const fert = Color(0xFFB8A27A);
  static const sprout = Color(0xFF7BD36B);
  static const leaf = Color(0xFF3E9B45);
  static const leafDark = Color(0xFF2D6E32);
  static const stem = Color(0xFF4F8A3A);
  static const ripeGlow = Color(0x66FFE680);
  static const droplet = Color(0xFF7FC8FF);
  static const pop = Color(0xFFFFF3C4);
  static const helper = Color(0xFFD9A066);
  static const helperHat = Color(0xFF8C6A3C);
  static const hoeHandle = Color(0xFF8C6A3C);
  static const hoeBlade = Color(0xFFB8C2CC);
  static const targetOk = Color(0xFF7BE07B);
  static const targetBad = Color(0xFFFF9F43);
  static const seedBag = Color(0xFFC9A46A);
  static const seedBagTie = Color(0xFF6E4F2A);
  static const can = Color(0xFF7E95A8);
  static const canDark = Color(0xFF55697A);

  /// Cofre de oficio (farming.md § 8.3): vacío se ve apagado, con cosas
  /// brilla un poco y lleno lleva un marco. [chestEmpty] multiplica el
  /// sprite (opaco: oscurece sin dejar ver el pasto a través).
  static const chestEmpty = Color(0xFF9A9A9A);
  static const chestGlow = Color(0x55FFE680);
  static const chestFull = Color(0xFFFF9F43);

  /// Color del fruto por rareza del cultivo (índice de `FishRarity`).
  static const fruit = [
    Color(0xFFE8C170),
    Color(0xFFE85C5C),
    Color(0xFFB57CFF),
    Color(0xFFFFD166),
  ];
}

/// Colores de la escena de pesca (fishing.md § 4; pesca en el mapa desde v0.22.2).
abstract final class FishingPalette {
  static const water = Color(0xFF1F5F8B);
  static const waterDeep = Color(0xFF15425F);
  static const ripple = Color(0x55FFFFFF);
  static const shadow = Color(0x66061A2A);
  static const dock = TownPalette.plank;
  static const dockDark = TownPalette.plankDark;
  static const line = Color(0xCCEFEFEF);
  static const bobber = TownPalette.bobber;
  static const foam = Color(0xCCFFFFFF);
  // Agua brillante de los biomas (fishing.md § 11).
  static const shimmer = Color(0xCCBFEFFF);
  static const shimmerGlow = Color(0x5580D8FF);
  static const reed = Color(0xFF3E7B3A);
  // Pesca en el mapa (v0.22.2).
  static const rod = TownPalette.plankDark;
  static const bang = Color(0xFFFFD166);
  static const meter = Color(0xFFFFD166);
  static const meterBack = Color(0xCC10141C);
  static const barFrame = Color(0xFF0B0E14);
  static const barBack = Color(0xFF26303F);
  static const zoneIn = Color(0xAA4CD07D);
  static const zoneOut = Color(0xAAE0A040);
}

/// Cozy life art (cozy_life.md § 1): fireflies and the raft paints
/// (index of `RaftDecoDef.paint`).
abstract final class CozyPalette {
  static const firefly = Color(0xFFE8F58A);
  static const fireflyGlow = Color(0x44E8F58A);
  /// Tint of the unpainted raft deck and awning (sprites are neutral).
  static const wood = Color(0xFFC08A55);
  static const cloth = Color(0xFFF2E6C2);
  static const seatShadow = Color(0x55000000);
  static const paints = [
    Color(0xFFE0857A),
    Color(0xFF8AB4E8),
    Color(0xFF9AD48A),
    Color(0xFFF2E6C2),
  ];
}

/// Progress bar under a work target (`drawTileTarget`).
abstract final class TargetPalette {
  static const barBack = Color(0xCC0E0C12);
}

/// Colores de los recolectables de los exteriores (overworld_biomes.md
/// § 3.2): la mata y el fruto de cada tipo (índice de `kForageKinds`).
/// Mine art (mining_smithing.md § 1): entrance, vein rock and the ore
/// colour of each biome's mines.
abstract final class MinePalette {
  static const rock = Color(0xFF55505A);
  static const rockLight = Color(0xFF6E6875);
  static const mouth = Color(0xFF0C0A10);
  static const timber = Color(0xFF7A5230);
  // Mining v2 (mining_smithing.md § 1.9).
  static const rockDark = Color(0xFF2E2A33);
  static const rockTop = Color(0xFF8A8392);
  static const bedrock = Color(0xFF16141B);
  static const bedrockLight = Color(0xFF26232D);
  static const caveFloor = Color(0xFF3A3540);
  static const caveFloor2 = Color(0xFF332F39);
  static const crack = Color(0xFF0E0C12);
  static const spark = Color(0xFFFFE08A);
  static const bomb = Color(0xFF22202A);
  static const rail = Color(0xFF9A9AA8);
  static const cart = Color(0xFF6A4A2C);
  static const cartDark = Color(0xFF3A2816);
  static const label = Color(0xFFE8E0C8);
  static const crystal = Color(0xFF9FE8FF);
  static const flame = Color(0xFFFFB347);
  static const mushroom = Color(0xFFB06AE0);
  static const chestWood = Color(0xFF8A5A2B);
  static const chestBand = Color(0xFFE0B860);
  static const relic = Color(0xFF7AE0D0);
  static const lore = Color(0xFF7A8FA8);
  // Pick swing (mining_smithing.md § 1.9).
  static const pickHead = Color(0xFFB8C2CC);
  static const pickEdge = Color(0xFFE8EEF4);
  static const pickHeadDark = Color(0xFF6E7780);
  static const timberDark = Color(0xFF4E3420);
  static const dust = Color(0xFFA89F96);
  static const _veins = {
    'mina_bosque': Color(0xFFD9824A),
    'mina_ruinas': Color(0xFFE0B860),
    'mina_cavernas': Color(0xFFBFE8FF),
    'mina_grieta': Color(0xFFFF6A2A),
    'mina_abismo': Color(0xFFC08AFF),
  };

  /// Ore colour of a theme (dungeon veins: rare gold).
  static Color vein(String theme) => _veins[theme] ?? const Color(0xFFFFD166);
}

abstract final class ForagePalette {
  static const bush = Color(0xFF2E6B30);
  static const bushLight = Color(0xFF3F8A3E);
  static const picked = Color(0xFF4F5E3A);
  static const fruit = [
    Color(0xFF8E3FD1), Color(0xFF9BE36A), Color(0xFFE0A040), // Bosque
    Color(0xFFB87333), Color(0xFF8FA8FF), Color(0xFFD8C05A), // Ruinas
    Color(0xFFBFE8FF), Color(0xFF5AA8D8), Color(0xFFE0F0FF), // Cavernas
    Color(0xFFFF5A2A), Color(0xFFB0A8A0), Color(0xFFFF9A3A), // Grieta
    Color(0xFFC08AFF), Color(0xFFFFE08A), Color(0xFF8AFFE0), // Abismo
    // Regions: seed bush, seasonal sprouts, echo bloom.
    Color(0xFFE8D8A0), Color(0xFF7AE07A), Color(0xFFB89CFF),
  ];
}

/// Colors of the generated biome regions (biome_regions.md § 6–7).
/// Colours of a biome's cavern (biome_regions.md § 7.2.1): rock (deep,
/// base, mid, lit), cracks, floor (two tones), wet shore, the cold water
/// glow and the bioluminescent specks.
class CavePalette {
  const CavePalette({
    required this.rockDeep,
    required this.rock,
    required this.rockMid,
    required this.rockLit,
    required this.crack,
    required this.floor,
    required this.floor2,
    required this.wet,
    required this.wetGlint,
    required this.waterGlow,
    required this.speck,
    required this.mist,
  });

  final Color rockDeep, rock, rockMid, rockLit, crack;
  final Color floor, floor2, wet, wetGlint;
  final Color waterGlow, speck, mist;

  /// The palette of a region theme (`bosque_ext`, ...); grey stone for
  /// any other.
  static CavePalette of(String theme) => _byTheme[theme] ?? _stone;

  static const _stone = CavePalette(
    rockDeep: Color(0xFF15161B),
    rock: Color(0xFF2A2C33),
    rockMid: Color(0xFF3A3D45),
    rockLit: Color(0xFF555963),
    crack: Color(0xFF0C0D10),
    floor: Color(0xFF24252A),
    floor2: Color(0xFF1C1D21),
    wet: Color(0xFF16191F),
    wetGlint: Color(0xFF5C6E80),
    waterGlow: Color(0xFF7FC8FF),
    speck: Color(0xFF8CFFE0),
    mist: Color(0xFFB8C8D8),
  );

  static const _byTheme = {
    // Forest: mossy dark stone, teal specks.
    'bosque_ext': CavePalette(
      rockDeep: Color(0xFF121712),
      rock: Color(0xFF262D26),
      rockMid: Color(0xFF354033),
      rockLit: Color(0xFF4E5C48),
      crack: Color(0xFF0A0D0A),
      floor: Color(0xFF20251F),
      floor2: Color(0xFF191D18),
      wet: Color(0xFF131815),
      wetGlint: Color(0xFF5E7A6A),
      waterGlow: Color(0xFF7FE0D0),
      speck: Color(0xFF9CFFB0),
      mist: Color(0xFFB8D0C0),
    ),
    // Ruins: dusty sandstone gone grey in the dark, amber specks.
    'ruinas_ext': CavePalette(
      rockDeep: Color(0xFF1A1612),
      rock: Color(0xFF332C24),
      rockMid: Color(0xFF453B30),
      rockLit: Color(0xFF63574A),
      crack: Color(0xFF0E0B08),
      floor: Color(0xFF2A241E),
      floor2: Color(0xFF221D18),
      wet: Color(0xFF181614),
      wetGlint: Color(0xFF7A6E5E),
      waterGlow: Color(0xFF9CC8E8),
      speck: Color(0xFFFFD58A),
      mist: Color(0xFFD0C8B8),
    ),
    // Caverns: frozen blue-grey, pale cyan specks.
    'cavernas_ext': CavePalette(
      rockDeep: Color(0xFF10141C),
      rock: Color(0xFF242C3A),
      rockMid: Color(0xFF34405A),
      rockLit: Color(0xFF5A6C88),
      crack: Color(0xFF080A10),
      floor: Color(0xFF1E2430),
      floor2: Color(0xFF181D27),
      wet: Color(0xFF121722),
      wetGlint: Color(0xFF8AA8D0),
      waterGlow: Color(0xFFA8E0FF),
      speck: Color(0xFFC8F0FF),
      mist: Color(0xFFD0E0F0),
    ),
    // Rift (volcano): basalt, ember cracks, orange specks.
    'grieta_ext': CavePalette(
      rockDeep: Color(0xFF120C0C),
      rock: Color(0xFF261A18),
      rockMid: Color(0xFF382622),
      rockLit: Color(0xFF543830),
      crack: Color(0xFF7A2A10),
      floor: Color(0xFF1E1614),
      floor2: Color(0xFF171110),
      wet: Color(0xFF140E0D),
      wetGlint: Color(0xFF8A5040),
      waterGlow: Color(0xFFFF9A5A),
      speck: Color(0xFFFFB060),
      mist: Color(0xFF8A7068),
    ),
    // Abyss: violet-black, violet specks.
    'abismo_ext': CavePalette(
      rockDeep: Color(0xFF110D18),
      rock: Color(0xFF221A30),
      rockMid: Color(0xFF322642),
      rockLit: Color(0xFF4E3E66),
      crack: Color(0xFF07050C),
      floor: Color(0xFF1C1626),
      floor2: Color(0xFF16111F),
      wet: Color(0xFF110D18),
      wetGlint: Color(0xFF7A62A0),
      waterGlow: Color(0xFFB48CFF),
      speck: Color(0xFFD8A8FF),
      mist: Color(0xFFB8A8D0),
    ),
  };
}

abstract final class RegionPalette {
  /// Glowing shore plants: stem, leaf, bulb and its glow.
  static const glowStem = Color(0xFF2A5A4A);
  static const glowLeaf = Color(0xFF3A8A6A);
  static const glowBulb = Color(0xFF9AFFE0);
  static const glowHalo = Color(0x559AFFE0);

  /// Soft cloud shadow over the ground (alpha in the layer).
  static const cloudShadow = Color(0xFF101828);

  /// Light shaft: the beam and the bright patch on the floor.
  static const shaftBeam = Color(0xFFFFF4D8);
  static const shaftPatch = Color(0xFFFFF8E8);

  /// Roofed caves of a region (biome_regions.md § 7.2.1): wall blocks
  /// (base, shadow, lit edge, crack), floor stone and the roof lip.
  static const caveWall = Color(0xFF4A4A52);
  static const caveWallDark = Color(0xFF2C2C34);
  static const caveWallLight = Color(0xFF6A6A74);
  static const caveCrack = Color(0xFF1C1C22);
  static const caveFloor = Color(0xFF3A3834);
  static const caveFloor2 = Color(0xFF302E2B);
  static const roofLip = Color(0xFF26262C);
  static const roofLipEdge = Color(0xFF45454E);

  /// Wind sway: a grass tuft and a canopy highlight.
  static const swayTuft = Color(0xFF7FCB5A);
  static const swayLeaf = Color(0x3398E070);

  /// Darkness under a cave roof in a daylit region.
  static const caveShade = Color(0xFF05070C);

  /// Dappled light: leaf shadows.
  static const dapple = Color(0xFF0A1408);

  /// Ambient critters by kind (butterfly, spark, frost, ember, echo).
  static const critters = [
    Color(0xFFFFE08A),
    Color(0xFFFFC870),
    Color(0xFFD8F0FF),
    Color(0xFFFF8A3A),
    Color(0xFFD2B8FF),
  ];

  /// Activated waystone rune.
  static const waystoneOn = Color(0xFF8AE8FF);
}
/// Forma del fruto maduro de un cultivo (farming.md § 2.3, v0.25.3).
enum CropShape { root, grain, tuber, pumpkin, berries, bulb, flower, melon, rose, crystal }

/// Aspecto de un cultivo en el mapa: semilla, planta y fruto.
class CropLook {
  const CropLook(this.shape,
      {required this.seed,
      required this.plant,
      required this.fruit,
      required this.accent,
      this.glow = false});
  final CropShape shape;
  final Color seed, plant, fruit, accent;

  /// Destella al madurar (legendarios).
  final bool glow;
}

/// Aspecto de cada cultivo (id de `kCrops`) en la huerta del mapa.
abstract final class CropPalette {
  static const fallback = CropLook(CropShape.berries,
      seed: FarmPalette.fert,
      plant: FarmPalette.leaf,
      fruit: Color(0xFFE8C170),
      accent: Color(0xFFFFF3C4));

  static const looks = <String, CropLook>{
    // Winter crops (weather_seasons.md § 5).
    'rabano_nieve': CropLook(CropShape.root,
        seed: Color(0xFFCFD8E0),
        plant: Color(0xFF6FA89A),
        fruit: Color(0xFFE85A7A),
        accent: Color(0xFFF4F8FC)),
    'col_invierno': CropLook(CropShape.pumpkin,
        seed: Color(0xFF9DB0A0),
        plant: Color(0xFF4E8C6A),
        fruit: Color(0xFF8FC7A0),
        accent: Color(0xFFE6F2EC)),
    'puerro_helado': CropLook(CropShape.bulb,
        seed: Color(0xFFB8C8D4),
        plant: Color(0xFF5A9A7C),
        fruit: Color(0xFFE8F0F4),
        accent: Color(0xFF9CC8E8)),
    'nabo_claro': CropLook(CropShape.root,
        seed: Color(0xFFD8D0C0),
        plant: Color(0xFF5DBB4E),
        fruit: Color(0xFFF2EEE6),
        accent: Color(0xFFB36FC2)),
    'trigo_dorado': CropLook(CropShape.grain,
        seed: Color(0xFFD9B45A),
        plant: Color(0xFFA8B84A),
        fruit: Color(0xFFE8B83A),
        accent: Color(0xFFFFE9A0)),
    'papa_piedra': CropLook(CropShape.tuber,
        seed: Color(0xFF8E8478),
        plant: Color(0xFF4F9A48),
        fruit: Color(0xFFA89478),
        accent: Color(0xFF6C6258)),
    'calabaza_sendero': CropLook(CropShape.pumpkin,
        seed: Color(0xFFEFDCA8),
        plant: Color(0xFF3E9B45),
        fruit: Color(0xFFF08A24),
        accent: Color(0xFFB85A10)),
    'frutilla_rocio': CropLook(CropShape.berries,
        seed: Color(0xFFE88A8A),
        plant: Color(0xFF46A24A),
        fruit: Color(0xFFE8364A),
        accent: Color(0xFFFFE680)),
    'cebolla_cobre': CropLook(CropShape.bulb,
        seed: Color(0xFFC87A44),
        plant: Color(0xFF7BC66B),
        fruit: Color(0xFFC8743A),
        accent: Color(0xFFFFC08A)),
    'flor_runica': CropLook(CropShape.flower,
        seed: Color(0xFF8FA8FF),
        plant: Color(0xFF3E9B6A),
        fruit: Color(0xFF6FA0FF),
        accent: Color(0xFFE0C8FF)),
    'melon_engranaje': CropLook(CropShape.melon,
        seed: Color(0xFFE6E0B0),
        plant: Color(0xFF3E9B45),
        fruit: Color(0xFF9CD86A),
        accent: Color(0xFF4E7A2E)),
    'trigo_manana': CropLook(CropShape.grain,
        seed: Color(0xFFFFF3C4),
        plant: Color(0xFFC8D8A0),
        fruit: Color(0xFFFFF6D8),
        accent: Color(0xFF9FE8FF),
        glow: true),
    'rosa_reloj': CropLook(CropShape.rose,
        seed: Color(0xFFB03050),
        plant: Color(0xFF2D6E32),
        fruit: Color(0xFFD8203C),
        accent: Color(0xFFFFD166),
        glow: true),
    'raiz_era': CropLook(CropShape.crystal,
        seed: Color(0xFF3FD8C8),
        plant: Color(0xFF3A8C7A),
        fruit: Color(0xFF3FE0D0),
        accent: Color(0xFFE0FFFA),
        glow: true),
    // Bosque (overworld_biomes.md § 3.3) y silvestres (§ 3.2).
    'helecho_dulce': CropLook(CropShape.flower,
        seed: Color(0xFF6E8A4A),
        plant: Color(0xFF2F7A3A),
        fruit: Color(0xFF8BD86A),
        accent: Color(0xFFDFF5C0)),
    'arandano_sombra': CropLook(CropShape.berries,
        seed: Color(0xFF4A3A6A),
        plant: Color(0xFF2D5E3A),
        fruit: Color(0xFF4A5AC8),
        accent: Color(0xFFB8C0FF)),
    'seta_reloj': CropLook(CropShape.bulb,
        seed: Color(0xFFB89A70),
        plant: Color(0xFF6A8A5A),
        fruit: Color(0xFFC8402E),
        accent: Color(0xFFFFE8C8)),
    // Region forage (biome_regions.md § 5).
    'brote_primavera': CropLook(CropShape.grain,
        seed: Color(0xFF7A9A5A),
        plant: Color(0xFF4FA03E),
        fruit: Color(0xFFB8F07A),
        accent: Color(0xFFF0FFD8)),
    'fresa_estival': CropLook(CropShape.berries,
        seed: Color(0xFF8A5A40),
        plant: Color(0xFF3F8A3E),
        fruit: Color(0xFFE0404A),
        accent: Color(0xFFFFD0D0)),
    'castana_otono': CropLook(CropShape.tuber,
        seed: Color(0xFF6A4A30),
        plant: Color(0xFF8A6A3A),
        fruit: Color(0xFF9A5A2A),
        accent: Color(0xFFE8C090)),
    'baya_invierno': CropLook(CropShape.berries,
        seed: Color(0xFF5A6A8A),
        plant: Color(0xFF4A6A7A),
        fruit: Color(0xFF8AC8FF),
        accent: Color(0xFFE8F8FF)),
    'flor_eco': CropLook(CropShape.bulb,
        seed: Color(0xFF5A4A8A),
        plant: Color(0xFF4A5A9A),
        fruit: Color(0xFFB89CFF),
        accent: Color(0xFFF0E8FF)),
    'moras_bosque': CropLook(CropShape.berries,
        seed: Color(0xFF5A3A5A),
        plant: Color(0xFF2E6B30),
        fruit: Color(0xFF8E3FD1),
        accent: Color(0xFFD8B0FF)),
    'hierba_rocio': CropLook(CropShape.grain,
        seed: Color(0xFF7A9A6A),
        plant: Color(0xFF3F8A3E),
        fruit: Color(0xFF9BE36A),
        accent: Color(0xFFE8FFD0)),
    'hongo_ambar': CropLook(CropShape.tuber,
        seed: Color(0xFF8A6A40),
        plant: Color(0xFF5A7A4A),
        fruit: Color(0xFFE0A040),
        accent: Color(0xFFFFE0A0)),
    // Biomas v0.29.0 (overworld_biomes.md § 3.3) y sus silvestres.
    'lirio_mecanico': CropLook(CropShape.flower,
        seed: Color(0xFF6E451E),
        plant: Color(0xFF6A7A5A),
        fruit: Color(0xFF8A5620),
        accent: Color(0xFFEF9542)),
    'calabaza_runica': CropLook(CropShape.pumpkin,
        seed: Color(0xFF6E451E),
        plant: Color(0xFF6A7A5A),
        fruit: Color(0xFF985F21),
        accent: Color(0xFFEF9542)),
    'olivo_eras': CropLook(CropShape.crystal,
        seed: Color(0xFF6E451E),
        plant: Color(0xFF6A7A5A),
        fruit: Color(0xFFA76822),
        accent: Color(0xFFEF9542), glow: true),
    'nabo_escarcha': CropLook(CropShape.root,
        seed: Color(0xFF5F8199),
        plant: Color(0xFF4A7A8A),
        fruit: Color(0xFF9DD5E3),
        accent: Color(0xFFCEFFFF)),
    'flor_cristal': CropLook(CropShape.crystal,
        seed: Color(0xFF5F8199),
        plant: Color(0xFF4A7A8A),
        fruit: Color(0xFFAAE7E4),
        accent: Color(0xFFCEFFFF)),
    'lirio_eco': CropLook(CropShape.rose,
        seed: Color(0xFF5F8199),
        plant: Color(0xFF4A7A8A),
        fruit: Color(0xFFB6F8E5),
        accent: Color(0xFFCEFFFF), glow: true),
    'chile_volcan': CropLook(CropShape.bulb,
        seed: Color(0xFF993F19),
        plant: Color(0xFF6A4A2A),
        fruit: Color(0xFFBF4F06),
        accent: Color(0xFFFF8936)),
    'flor_brasa': CropLook(CropShape.flower,
        seed: Color(0xFF993F19),
        plant: Color(0xFF6A4A2A),
        fruit: Color(0xFFD35727),
        accent: Color(0xFFFF8936)),
    'fruta_forja': CropLook(CropShape.melon,
        seed: Color(0xFF993F19),
        plant: Color(0xFF6A4A2A),
        fruit: Color(0xFFE86028),
        accent: Color(0xFFFF8936), glow: true),
    'trigo_eco': CropLook(CropShape.grain,
        seed: Color(0xFF735299),
        plant: Color(0xFF3A4A7A),
        fruit: Color(0xFFBE88E9),
        accent: Color(0xFFF9B3FF)),
    'rosa_futuro': CropLook(CropShape.rose,
        seed: Color(0xFF735299),
        plant: Color(0xFF3A4A7A),
        fruit: Color(0xFFCD93EA),
        accent: Color(0xFFF9B3FF)),
    'arbol_paradoja': CropLook(CropShape.tuber,
        seed: Color(0xFF735299),
        plant: Color(0xFF3A4A7A),
        fruit: Color(0xFFDC9EEB),
        accent: Color(0xFFF9B3FF), glow: true),
    'musgo_cobre': CropLook(CropShape.grain,
        seed: Color(0xFF6E451E),
        plant: Color(0xFF6A7A5A),
        fruit: Color(0xFF8A562C),
        accent: Color(0xFFEF9542)),
    'liquen_runa': CropLook(CropShape.flower,
        seed: Color(0xFF6E451E),
        plant: Color(0xFF6A7A5A),
        fruit: Color(0xFF985F2D),
        accent: Color(0xFFEF9542)),
    'baya_engranaje': CropLook(CropShape.berries,
        seed: Color(0xFF6E451E),
        plant: Color(0xFF6A7A5A),
        fruit: Color(0xFFA7682E),
        accent: Color(0xFFEF9542)),
    'cristal_escarcha': CropLook(CropShape.crystal,
        seed: Color(0xFF5F8199),
        plant: Color(0xFF4A7A8A),
        fruit: Color(0xFF9DD5EF),
        accent: Color(0xFFCEFFFF)),
    'liquen_azul': CropLook(CropShape.grain,
        seed: Color(0xFF5F8199),
        plant: Color(0xFF4A7A8A),
        fruit: Color(0xFFAAE7F0),
        accent: Color(0xFFCEFFFF)),
    'hongo_frio': CropLook(CropShape.tuber,
        seed: Color(0xFF5F8199),
        plant: Color(0xFF4A7A8A),
        fruit: Color(0xFFB6F8F1),
        accent: Color(0xFFCEFFFF)),
    'pimiento_brasa': CropLook(CropShape.bulb,
        seed: Color(0xFF993F19),
        plant: Color(0xFF6A4A2A),
        fruit: Color(0xFFBF4F12),
        accent: Color(0xFFFF8936)),
    'flor_ceniza': CropLook(CropShape.flower,
        seed: Color(0xFF993F19),
        plant: Color(0xFF6A4A2A),
        fruit: Color(0xFFD35733),
        accent: Color(0xFFFF8936)),
    'raiz_ignea': CropLook(CropShape.root,
        seed: Color(0xFF993F19),
        plant: Color(0xFF6A4A2A),
        fruit: Color(0xFFE86034),
        accent: Color(0xFFFF8936)),
    'polvo_eco': CropLook(CropShape.crystal,
        seed: Color(0xFF735299),
        plant: Color(0xFF3A4A7A),
        fruit: Color(0xFFBE88F5),
        accent: Color(0xFFF9B3FF)),
    'flor_manana': CropLook(CropShape.rose,
        seed: Color(0xFF735299),
        plant: Color(0xFF3A4A7A),
        fruit: Color(0xFFCD93F6),
        accent: Color(0xFFF9B3FF)),
    'fruto_paradoja': CropLook(CropShape.melon,
        seed: Color(0xFF735299),
        plant: Color(0xFF3A4A7A),
        fruit: Color(0xFFDC9EF7),
        accent: Color(0xFFF9B3FF)),
  };

  static CropLook of(String? id) => looks[id] ?? fallback;
}

/// Cartel de subida de nivel de oficio sobre el personaje (v0.25.3).
abstract final class LifeLevelPalette {
  static const frame = Color(0xFF2A1E12);
  static const back = Color(0xE01A140E);
  static const title = Color(0xFFFFD166);
  static const fish = Color(0xFF7FC8FF);
  static const farm = Color(0xFF7BE07B);
}

/// Ground marks of the seasons and the weather (weather_seasons.md
/// § 6.3).
abstract final class GroundPalette {
  static const snowTint = Color(0x1FE8F0FF);
  static const frost = Color(0xD9F4F8FF);
  static const wetTint = Color(0x14284878);
  static const puddle = Color(0x996A8CB8);
  static const leaf = Color(0xFFC8702A);
  static const leafDark = Color(0xFF8A4A1E);
  static const petal = Color(0xFFF2A0C8);
  static const petalAlt = Color(0xFFF4E07A);
}

/// Colores del cielo (day_night_weather.md § 4): la noche, la luz de los
/// faros y luciérnagas, la lluvia y el rayo.
abstract final class SkyPalette {
  /// Tinte de la noche cerrada (el alfa lo pone la oscuridad).
  static const night = Color(0xFF0A1030);

  /// Cielo encapotado de día (lluvia y tormenta).
  static const overcast = Color(0xFF1C2333);

  /// Luz cálida de un faro o brasero.
  static const warm = Color(0xFFFFC46B);
  static const warmEdge = Color(0x00FFC46B);

  /// Luciérnaga: el punto y su halo.
  static const firefly = Color(0xFFE8FF8A);
  static const fireflyGlow = Color(0x66C8FF5A);

  static const rain = Color(0x99A8C8FF);

  /// Snowflakes and the fog veil (weather_seasons.md § 6).
  static const snow = Color(0xE6F4F8FF);
  static const fog = Color(0xFFC8D0DA);
  static const bolt = Color(0xFFF4F7FF);
  static const boltGlow = Color(0x88B5C8FF);
  // Pararrayos que desvía un rayo (cozy_life.md § 2.1).
  static const rodGlow = Color(0xFF6FD3FF);
  static const rodSpark = Color(0xFFE4F8FF);
  static const flash = Color(0xFFFFFFFF);

  /// Máscara de las luces (lo que "come" la noche).
  static const cut = Color(0xFF000000);
  static const cutClear = Color(0x00000000);

  /// Cartel del pronóstico.
  static const forecast = Color(0xFFDDE6FF);
  static const forecastBack = Color(0xB30A1030);

  /// Faro del pueblo: poste y cabeza.
  static const faroPost = Color(0xFF4A4F5C);
  static const faroHead = Color(0xFF6B7080);
}

/// Colores de la iluminación (docs/specs/lighting.md § 6). Las claves de
/// [tints] son las `tint` de `kLightDefs`. Tonos elegidos para que se
/// distingan por brillo, no solo por matiz (seguros para daltonismo).
abstract final class LightPalette {
  /// Llama errante (lighting.md § 3.1.1): núcleo y halo.
  static const wispCore = Color(0xFFFFF1D6);
  static const wispHalo = Color(0xFFD2B8FF);

  static const tints = <String, Color>{
    'calida': Color(0xFFFFD9A0),
    'brasa': Color(0xFFFFB070),
    'runa': Color(0xFFA8E6FF),
    'eco': Color(0xFFD2B8FF),
    'luciernaga': Color(0xFFE8FF9A),
    'flora': Color(0xFFB8FFD8),
    'agua': Color(0xFFA8D0FF),
    'botin': Color(0xFFFFE8A8),
    'hongo': Color(0xFFC8B8FF),
    'shaft': Color(0xFFFFF4D8),
  };
  static const fallback = Color(0xFFFFFFFF);

  /// Ambiente del atardecer / amanecer y de la noche cerrada.
  static const dusk = Color(0xFFD8A890);
  static const night = Color(0xFF2A3466);

  /// Ambiente de una mazmorra oscura (casi negro).
  static const darkDungeon = Color(0xFF0A0A12);

  /// Mines: dark, but rock shapes stay readable (mining_smithing.md § 1.6).
  static const darkMine = Color(0xFF2A2630);

  /// Silueta de un enemigo en la penumbra.
  static const silhouette = Color(0xFF000000);
}
