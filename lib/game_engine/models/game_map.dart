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

  /// Portal del Eco del pueblo (sólido; docs/specs/ecos_atlas.md § 1).
  static const portal = 'P';

  // ---- mundo y zonas (worldgen.md § 7.6) ----
  /// Pasto del mapa del mundo (caminable).
  static const grass = 'g';

  /// Árbol del mapa del mundo (sólido).
  static const tree = 'T';

  /// Roca / montaña del mapa del mundo (sólida).
  static const rock = '^';

  /// Escalera que baja al piso siguiente (caminable).
  static const stairsDown = '>';

  /// Escalera que sube al piso anterior (caminable).
  static const stairsUp = '<';

  /// Suelo de vault (caminable, decorativo).
  static const vaultFloor = ':';

  // ---- zonas 6–10 (worldgen.md § 9.1) ----
  /// Vacío de las zonas de abismo: el jugador puede pisarlo y se cae
  /// (vuelve al spawn del piso); para los enemigos es sólido.
  static const voidTile = '_';

  /// Puente sobre el vacío o la lava (caminable).
  static const bridge = '=';

  /// Lava de la Grieta Ígnea (sólida).
  static const lava = '%';

  /// Lápida del Cementerio de Eras (sólida).
  static const tombstone = 't';

  /// Engranaje / reloj de los vaults del laberinto (sólido).
  static const gear = 'o';

  /// Tiles sólidos fijos (sin la barrera, que depende de si está abierta,
  /// ni las entradas de zona).
  static const solidTiles = {
    wall, water, counter, armory, merchant, tree, rock, lava, tombstone, gear,
    portal,
  };

  /// Se puede pisar (el vacío cuenta: se pisa y se cae).
  static bool isWalkable(String c) =>
      !solidTiles.contains(c) && entranceZone(c) == null && c != gate;

  /// Entrada de la zona [zone] (1..10) en el mapa del mundo: `'1'..'9'`
  /// y `'0'` para la 10. Sólida.
  static String entrance(int zone) => '${zone % 10}';

  /// Zona de una entrada (`null` si [ch] no es una entrada).
  static int? entranceZone(String ch) {
    final c = ch.codeUnitAt(0);
    if (c < 48 || c > 57) return null;
    return c == 48 ? 10 : c - 48;
  }
}

/// Tipo de escalera cerca del jugador.
enum StairsKind { down, up }

/// Entrada de zona del mapa del mundo: el tile de la entrada (sólido) y
/// el de abajo ("frente"), donde se para el jugador.
class ZoneEntrance {
  final int zone;
  final int tx, ty;
  const ZoneEntrance(this.zone, this.tx, this.ty);

  WorldPoint get center => WorldPoint(tx * 16 + 8.0, ty * 16 + 8.0);
  WorldPoint get front => WorldPoint(tx * 16 + 8.0, ty * 16 + 24.0);
}

/// Un piso dentro del atlas de una zona (worldgen.md § 6.6). Todas las
/// coordenadas son del atlas (ya desplazadas).
class MapFloor {
  MapFloor({
    required this.index,
    required this.bounds,
    required this.level,
    required this.spawn,
    required this.last,
    this.stairsDown,
    this.stairsUp,
    this.returnPoint,
    this.arena,
    this.side,
    this.boss,
    List<(int, int)> spots = const [],
    List<TileRect> vaults = const [],
    List<(int, int)> chestMarks = const [],
    List<(int, int)> eliteMarks = const [],
  })  : spots = List.unmodifiable(spots),
        vaults = List.unmodifiable(vaults),
        chestMarks = List.unmodifiable(chestMarks),
        eliteMarks = List.unmodifiable(eliteMarks);

  final int index;

  /// Rectángulo del piso dentro del atlas (en tiles).
  final TileRect bounds;

  /// Nivel de los enemigos del piso.
  final int level;

  /// Llegada bajando (y el inicio de la misión en el piso 0).
  final WorldPoint spawn;
  final bool last;

  /// Centro en px de la `>` (todos menos el último piso).
  final WorldPoint? stairsDown;

  /// Centro en px de la `<` (desde el segundo piso).
  final WorldPoint? stairsUp;

  /// Llegada subiendo desde el piso de abajo (2 tiles debajo de `>`).
  final WorldPoint? returnPoint;
  final TileRect? arena;
  final String? side;

  /// Jefe (solo el último piso).
  final WorldPoint? boss;

  /// Tiles donde aparecen enemigos y objetos.
  final List<(int, int)> spots;
  final List<TileRect> vaults;

  /// Marcas `c` / `e` de los vaults (tiles).
  final List<(int, int)> chestMarks;
  final List<(int, int)> eliteMarks;

  bool containsTile(int tx, int ty) =>
      tx >= bounds.x &&
      ty >= bounds.y &&
      tx < bounds.x + bounds.w &&
      ty < bounds.y + bounds.h;
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
    List<MapFloor> floors = const [],
    List<ZoneEntrance> entrances = const [],
    this.zone = 0,
  })  : rows = List.unmodifiable(rows),
        floors = List.unmodifiable(floors),
        entrances = List.unmodifiable(entrances);

  final int width;
  final int height;

  /// Una fila por `y`, un carácter por `x` (ver [Tile]).
  final List<String> rows;

  /// Tema visual (`pradera`, `ruinas`, `abismo`, `lobby`, `mundo`,
  /// `bosque`, `cavernas`, `fortaleza`): lo resuelve la UI.
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

  /// Pisos del atlas de una zona (vacío en el mundo y en misiones viejas).
  final List<MapFloor> floors;

  /// Entradas de zona (solo el mapa del mundo).
  final List<ZoneEntrance> entrances;

  /// Índice de zona del atlas (0 = mundo o misión sin zona).
  final int zone;

  MapFloor? floor(int i) => i >= 0 && i < floors.length ? floors[i] : null;

  /// El piso que contiene el punto (px), o `null`.
  MapFloor? floorAt(double x, double y) {
    final tx = (x / 16).floor(), ty = (y / 16).floor();
    for (final f in floors) {
      if (f.containsTile(tx, ty)) return f;
    }
    return null;
  }

  String tileAt(int tx, int ty) => rows[ty][tx];

  bool contains(int tx, int ty) =>
      tx >= 0 && ty >= 0 && tx < width && ty < height;
}
