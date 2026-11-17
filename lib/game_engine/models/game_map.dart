/// Un punto del mundo en px (no en tiles).
class WorldPoint {
  final double x;
  final double y;
  const WorldPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is WorldPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'WorldPoint($x, $y)';
}

/// Un rectángulo en tiles con su centro (`{x, y, w, h, cx, cy}` del
/// prototipo; el centro usa `w >> 1`).
class TileRect {
  final int x, y, w, h;
  const TileRect(this.x, this.y, this.w, this.h);

  int get cx => x + (w >> 1);
  int get cy => y + (h >> 1);
}

/// Códigos de tile del prototipo (un carácter por tile). Ver
/// docs/specs/world.md § "Tiles".
abstract final class Tile {
  static const wall = '#';
  static const floor = '.';
  static const path = ',';
  static const water = '~';
  static const counter = 'C';
  static const armory = 'A';
  static const merchant = 'M';
  static const gate = 'G';
}

/// Un mapa ya generado (lobby o misión). Inmutable. Lo único que viaja
/// por red es la semilla: cada peer lo regenera con
/// `MapGenerator.generate`.
class GameMap {
  GameMap({
    required this.width,
    required this.height,
    required List<String> rows,
    required this.theme,
    required this.spawn,
    this.lobby = false,
    this.side,
    this.arena,
    this.rooms = const [],
    this.boss,
    this.spots = const [],
    this.merchant,
  }) : rows = List.unmodifiable(rows);

  final int width;
  final int height;

  /// Una fila por `y`, un carácter por `x` (ver [Tile]).
  final List<String> rows;

  /// Tema visual (`pradera`, `ruinas`, `abismo`, `lobby`): lo resuelve la UI.
  final String theme;
  final WorldPoint spawn;
  final bool lobby;

  /// Lado de la arena del jefe: `E`, `W`, `N` o `S` (solo misiones).
  final String? side;
  final TileRect? arena;
  final List<TileRect> rooms;
  final WorldPoint? boss;

  /// Tiles de suelo alcanzables donde aparecen enemigos y objetos.
  final List<(int, int)> spots;

  /// Mercader ambulante: desactivado en el prototipo, siempre `null`.
  final WorldPoint? merchant;

  String tileAt(int tx, int ty) => rows[ty][tx];

  bool contains(int tx, int ty) =>
      tx >= 0 && ty >= 0 && tx < width && ty < height;
}
