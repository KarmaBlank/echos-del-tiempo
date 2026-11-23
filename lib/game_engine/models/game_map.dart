import '../data/town_layout.dart' show TownLandmark;

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

  // ---- ascensión (docs/specs/ascension.md § 1) ----
  /// Estatua del Tiempo del pueblo (sólida): abre el panel ASCENSIÓN.
  static const statue = 'S';

  /// Torrecita del Loot perdido del pueblo (sólida, v0.20.22): abre el
  /// pozo compartido de la sala (missions.md § "Loot perdido").
  static const lostTower = 'L';

  // ---- pueblo v0.21.0 (docs/specs/town_loop.md § 2.1) ----
  /// Fuente rúnica del centro del pueblo (sólida).
  static const fountain = 'F';

  /// Punto de pesca marcado en la orilla del lago (sólido).
  static const fishing = 'f';

  /// Cartel del lago (sólido).
  static const sign = 'Y';

  /// Tierra de la huerta (caminable; farming.md § 2, v0.23.0). Las
  /// parcelas aradas y los cultivos se dibujan encima, desde el estado.
  static const soil = 'u';

  /// Recolectable de un exterior de bioma (overworld_biomes.md § 3):
  /// mata con frutos, hierbas u hongos (sólida). [forageUsed]: ya
  /// recolectada, esperando que vuelva a crecer.
  static const forage = 'q';
  static const forageUsed = 'Q';

  /// Púas de la Prueba del Tiempo (caminables: dañan).
  static const spikes = 'x';

  /// Pulso del Tiempo de la Prueba (caminable: activo, te devuelve).
  static const pulse = 'p';

  // ---- exploración v0.6 (docs/specs/worldgen.md § 11) ----
  /// Pared agrietada de una sala secreta (sólida hasta abrirla: `:`).
  static const cracked = 'K';

  /// Suelo de una sala secreta sin abrir: se ve y colisiona como muro
  /// (al abrirla pasa a `:`).
  static const secretFloor = 'k';

  /// Santuario sin usar / usado (sólidos).
  static const shrine = 'H';
  static const shrineUsed = 'h';

  /// Piedra de paso sin activar / activada (sólidas).
  static const waystone = 'W';
  static const waystoneOn = 'w';

  /// Santuario del Viento del Eco (sólido, reusable).
  static const wind = 'V';

  /// Atajo cerrado (muro con palanca del lado lejano; abierto: `,`).
  static const shortcut = 'J';

  /// Brasero apagado / encendido (sólidos).
  static const brazier = 'B';
  static const brazierLit = 'b';

  /// Tiles de los puntos de interés de v0.6 (todos sólidos).
  static const poiTiles = {
    cracked, secretFloor, shrine, shrineUsed, waystone, waystoneOn, wind,
    shortcut,
    brazier, brazierLit,
  };

  /// Tiles sólidos fijos (sin la barrera, que depende de si está abierta,
  /// ni las entradas de zona).
  static const solidTiles = {
    wall, water, counter, armory, merchant, tree, rock, lava, tombstone, gear,
    portal, statue, lostTower, fountain, fishing, sign, cracked, secretFloor, shrine, shrineUsed, waystone,
    waystoneOn, wind,
    shortcut, brazier, brazierLit, forage, forageUsed,
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

/// Tipo de punto de interés (worldgen.md § 11.3).
enum PoiKind {
  /// Sala secreta: [MapPoi.tx]/[MapPoi.ty] es la pared agrietada.
  secret,

  /// Santuario de bendición ([MapPoi.variant] = `BlessingKind.index`).
  shrine,

  /// Piedra de paso (viaje rápido dentro del piso).
  waystone,

  /// Santuario del Viento del Eco (velocidad, reusable).
  wind,

  /// Atajo: muro que se abre desde el lado lejano ([MapPoi.side]).
  shortcut,

  /// Brasero de una misión opcional ([MapPoi.quest]).
  brazier,

  /// Reliquia perdida de una misión opcional (se levanta al tocarla; no
  /// es un tile).
  relic,
}

/// Un punto de interés de un piso. Coordenadas del atlas (tiles).
class MapPoi {
  const MapPoi({
    required this.id,
    required this.kind,
    required this.tx,
    required this.ty,
    this.floor = 0,
    this.variant = 0,
    this.room,
    this.chest,
    this.side,
    this.quest,
  });

  /// Único en el atlas: `piso × 100 + k`.
  final int id;
  final PoiKind kind;
  final int tx, ty;
  final int floor;

  /// Bendición del santuario (índice de `BlessingKind`).
  final int variant;

  /// Interior de la sala secreta y su cofre.
  final TileRect? room;
  final (int, int)? chest;

  /// Atajo: el tile del lado lejano (desde donde se abre).
  final (int, int)? side;

  /// Misión opcional a la que pertenece (braseros, reliquia).
  final int? quest;

  WorldPoint get center => WorldPoint(tx * 16 + 8.0, ty * 16 + 8.0);

  /// Copia desplazada [ox] tiles en el atlas, en el piso [floorIndex].
  MapPoi shifted(int ox, int floorIndex, int newId, {int? newQuest}) {
    final r = room, c = chest, sd = side;
    return MapPoi(
      id: newId,
      kind: kind,
      tx: tx + ox,
      ty: ty,
      floor: floorIndex,
      variant: variant,
      room: r == null ? null : TileRect(r.x + ox, r.y, r.w, r.h),
      chest: c == null ? null : (c.$1 + ox, c.$2),
      side: sd == null ? null : (sd.$1 + ox, sd.$2),
      quest: newQuest ?? quest,
    );
  }
}

/// Tipo de misión opcional de piso (worldgen.md § 11.8).
enum QuestKind { braseros, guardian, reliquia, limpieza, secreto, cofres }

/// Premio principal de una misión opcional (loot.md § 23.3).
enum QuestReward { arma, eco, bendicion }

/// Una misión opcional de un piso: parte del mapa (sale de la semilla).
class FloorQuest {
  const FloorQuest({
    required this.id,
    required this.kind,
    required this.target,
    required this.reward,
    this.floor = 0,
  });

  /// Único en el atlas: `piso × 100 + 50 + k`.
  final int id;
  final QuestKind kind;

  /// Cuánto hay que juntar (braseros, grupos, cofres…).
  final int target;
  final QuestReward reward;
  final int floor;

  FloorQuest shifted(int floorIndex, int newId) => FloorQuest(
      id: newId, kind: kind, target: target, reward: reward, floor: floorIndex);
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
    List<MapPoi> pois = const [],
    List<FloorQuest> quests = const [],
    List<(int, int)> chestSpots = const [],
  })  : pois = List.unmodifiable(pois),
        quests = List.unmodifiable(quests),
        chestSpots = List.unmodifiable(chestSpots),
        spots = List.unmodifiable(spots),
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

  /// Puntos de interés del piso (worldgen.md § 11.3).
  final List<MapPoi> pois;

  /// Misiones opcionales del piso (worldgen.md § 11.8).
  final List<FloorQuest> quests;

  /// Lugares de cofre repartidos por densidad (worldgen.md § 11.2).
  final List<(int, int)> chestSpots;

  MapPoi? poi(int id) {
    for (final p in pois) {
      if (p.id == id) return p;
    }
    return null;
  }

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
    this.townOrigin = (0, 0),
    this.place,
    this.townMarks,
  })  : rows = List.unmodifiable(rows),
        floors = List.unmodifiable(floors),
        entrances = List.unmodifiable(entrances);

  final int width;
  final int height;

  /// Pueblo: dónde cae el tile (0, 0) del pueblo base (town_editor.md
  /// § 2; las ampliaciones al norte y al oeste lo corren).
  final (int, int) townOrigin;

  /// Exterior de bioma (overworld_biomes.md § 2): su id (`bosque`);
  /// `null` en el pueblo y en las mazmorras. Con `lobby = true` es zona
  /// segura, pero sin los lugares del pueblo.
  final String? place;
  /// Pueblo: los lugares en su posición de este mundo (coordenadas del
  /// pueblo base; town_editor.md § 3.3). `null` = los de siempre.
  final List<TownLandmark>? townMarks;

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
