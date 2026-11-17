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
  'abismo': MapTheme(
    ground: Color(0xFF2C1F45),
    ground2: Color(0xFF3A2A5A),
    wall: Color(0xFF120A22),
    wall2: Color(0xFF9B59FF),
    path: Color(0xFF4E3478),
    path2: Color(0xFF432C68),
    water: Color(0xFF6C2BD9),
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
