import 'dart:ui';

/// Colores de tiles de un tema de mapa (`THEMES` del prototipo, líneas
/// 298-303). Son arte, no chrome de UI: no pasan por `RetroPalette`
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
  });

  /// `g`, `g2`: suelo y su detalle.
  final Color ground, ground2;

  /// `w`, `w2`: muro y su detalle.
  final Color wall, wall2;

  /// `path`, `p2`: camino y su detalle.
  final Color path, path2;

  /// `wat`: agua.
  final Color water;
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
};

/// Tema de un mapa (pradera si el id no existe).
MapTheme mapTheme(String id) => kMapThemes[id] ?? kMapThemes['pradera']!;

/// Fondo fuera del mapa (`#05060c`).
const kMapBackground = Color(0xFF05060C);
