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
}

/// Colores de la edición del pueblo (town_editor.md § 1.3).
abstract final class TownEditPalette {
  /// Franja fantasma de una ampliación.
  static const side = Color(0x3366C2FF);
  static const sideBorder = Color(0xFF66C2FF);
  static const sideText = Color(0xFFDDF2FF);
  static const sideLocked = Color(0xFF9AA0AC);

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
