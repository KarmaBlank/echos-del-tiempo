import '../models/game_map.dart';
import '../models/world_save.dart' show TownState;
import '../models/mission_def.dart';
import '../models/zone_def.dart';
import '../data/biomes_catalog.dart';
import '../data/town_layout.dart';
import 'mulberry32.dart';
import 'zone_generators.dart';
import 'town_plan.dart';
import 'zone_rules.dart';

/// Puerto de `lobbyMap` y `genMap` del prototipo. Ver
/// docs/specs/world.md: el orden de las llamadas al azar es parte del
/// contrato (misma semilla → mismo mapa que en el navegador).
abstract final class MapGenerator {
  static const tileSize = 16;

  /// Ancho de la franja reservada para la arena y tamaño de la arena.
  static const _arenaStrip = 16;
  static const _arenaW = 13;
  static const _arenaH = 13;

  /// `lobbyMap()`.
  static GameMap lobby() {
    const w = 26, h = 14;
    final t = [
      for (var y = 0; y < h; y++)
        [
          for (var x = 0; x < w; x++)
            x == 0 || y == 0 || x == w - 1 || y == h - 1 ? Tile.wall : Tile.floor,
        ],
    ];
    for (var x = 9; x <= 16; x++) {
      t[2][x] = Tile.counter;
    }
    for (var x = 19; x <= 23; x++) {
      t[2][x] = Tile.armory;
    }
    // Portal del Eco (ecos_atlas.md § 1), a la izquierda del mostrador.
    for (var x = 3; x <= 5; x++) {
      t[2][x] = Tile.portal;
    }
    for (var y = 7; y <= 8; y++) {
      for (var x = 20; x <= 22; x++) {
        t[y][x] = Tile.water;
      }
      for (var x = 3; x <= 5; x++) {
        t[y][x] = Tile.water;
      }
    }
    // Estatua del Tiempo (ascension.md § 1), debajo de la fuente derecha.
    for (var x = 20; x <= 22; x++) {
      t[10][x] = Tile.statue;
    }
    // Loot perdido (v0.20.22), debajo de la fuente izquierda.
    for (var x = 3; x <= 5; x++) {
      t[10][x] = Tile.lostTower;
    }
    for (var y = 3; y < h - 1; y++) {
      for (var x = 12; x <= 13; x++) {
        t[y][x] = Tile.path;
      }
    }
    for (var x = 1; x < w - 1; x++) {
      t[1][x] = Tile.path;
    }
    return GameMap(
      width: w,
      height: h,
      rows: [for (final row in t) row.join()],
      theme: 'lobby',
      spawn: const WorldPoint(13.0 * tileSize, 9.0 * tileSize),
      lobby: true,
    );
  }

  /// `genMap(mission, seed)`.
  static GameMap generate(MissionDef mission, int seed) =>
      ruins(mission.theme, seed);

  /// El `genMap` del prototipo con el tema [theme] (generador "ruinas").
  static GameMap ruins(String theme, int seed) {
    final r = mulberry32(seed);
    int ri(int a, int b) => a + (r() * (b - a + 1)).floor();

    final w = ri(60, 76), h = ri(44, 54);
    final t = [for (var y = 0; y < h; y++) List.filled(w, Tile.wall)];

    final side = const ['E', 'W', 'N', 'S'][ri(0, 3)];
    var rx0 = 2, ry0 = 2, rx1 = w - 3, ry1 = h - 3;
    final int arX, arY;
    switch (side) {
      case 'E':
        rx1 = w - 3 - _arenaStrip;
        arX = w - 2 - _arenaW;
        arY = ri(3, h - 3 - _arenaH);
      case 'W':
        rx0 = 2 + _arenaStrip;
        arX = 2;
        arY = ri(3, h - 3 - _arenaH);
      case 'N':
        ry0 = 2 + _arenaStrip;
        arX = ri(3, w - 3 - _arenaW);
        arY = 2;
      default:
        ry1 = h - 3 - _arenaStrip;
        arX = ri(3, w - 3 - _arenaW);
        arY = h - 2 - _arenaH;
    }
    final ar = TileRect(arX, arY, _arenaW, _arenaH);

    // ---- salas ----
    final rooms = <TileRect>[];
    for (var i = 0; i < 600 && rooms.length < 13; i++) {
      final rw = ri(6, 12), rh = ri(5, 9);
      final x = ri(rx0, rx1 - rw), y = ri(ry0, ry1 - rh);
      if (x < rx0 || y < ry0 || x + rw > rx1 || y + rh > ry1) continue;
      final overlaps = rooms.any((o) =>
          x < o.x + o.w + 2 &&
          x + rw + 2 > o.x &&
          y < o.y + o.h + 2 &&
          y + rh + 2 > o.y);
      if (overlaps) continue;
      rooms.add(TileRect(x, y, rw, rh));
    }
    if (rooms.isEmpty) rooms.add(TileRect(rx0, ry0, 5, 4));
    for (final o in rooms) {
      for (var y = o.y; y < o.y + o.h; y++) {
        for (var x = o.x; x < o.x + o.w; x++) {
          t[y][x] = Tile.floor;
        }
      }
    }

    // ---- pasillos ----
    void carve(int x, int y) {
      if (x > 0 && y > 0 && x < w - 1 && y < h - 1 && t[y][x] == Tile.wall) {
        t[y][x] = Tile.path;
      }
    }

    void hs(int y, int a, int b) {
      for (var x = a < b ? a : b; x <= (a > b ? a : b); x++) {
        carve(x, y);
        carve(x, y + 1);
      }
    }

    void vs(int x, int a, int b) {
      for (var y = a < b ? a : b; y <= (a > b ? a : b); y++) {
        carve(x, y);
        carve(x + 1, y);
      }
    }

    void corr(int x1, int y1, int x2, int y2, bool horizontalFirst) {
      if (horizontalFirst) {
        hs(y1, x1, x2);
        vs(x2, y1, y2);
      } else {
        vs(x1, y1, y2);
        hs(y2, x1, x2);
      }
    }

    int dist(TileRect a, TileRect b) =>
        (a.cx - b.cx).abs() + (a.cy - b.cy).abs();

    // Árbol mínimo (Prim) + un par de bucles.
    final inTree = <int>[0];
    while (inTree.length < rooms.length) {
      int? bi, bj, bd;
      for (final i in inTree) {
        for (var j = 0; j < rooms.length; j++) {
          if (inTree.contains(j)) continue;
          final d = dist(rooms[i], rooms[j]);
          if (bd == null || d < bd) {
            bi = i;
            bj = j;
            bd = d;
          }
        }
      }
      inTree.add(bj!);
      corr(rooms[bi!].cx, rooms[bi].cy, rooms[bj].cx, rooms[bj].cy, r() < 0.5);
    }
    for (var k = 0; k < 2 && rooms.length > 3; k++) {
      final i = ri(0, rooms.length - 1), j = ri(0, rooms.length - 1);
      if (i != j) {
        corr(rooms[i].cx, rooms[i].cy, rooms[j].cx, rooms[j].cy, r() < 0.5);
      }
    }

    // ---- arena del jefe con una sola entrada (barrera) ----
    for (var y = ar.y; y < ar.y + _arenaH; y++) {
      for (var x = ar.x; x < ar.x + _arenaW; x++) {
        t[y][x] = Tile.floor;
      }
    }
    for (final (dx, dy) in const [
      (2, 2),
      (_arenaW - 3, 2),
      (2, _arenaH - 3),
      (_arenaW - 3, _arenaH - 3),
    ]) {
      t[ar.y + dy][ar.x + dx] = Tile.wall;
    }
    // Primera sala con la menor distancia (sort estable del prototipo).
    var near = rooms.first;
    for (final o in rooms) {
      if (dist(o, ar) < dist(near, ar)) near = o;
    }
    switch (side) {
      case 'E':
        corr(near.cx, near.cy, ar.x - 2, ar.cy, false);
        for (var y = ar.cy - 1; y <= ar.cy + 2; y++) {
          t[y][ar.x - 1] = Tile.gate;
        }
      case 'W':
        corr(near.cx, near.cy, ar.x + _arenaW + 1, ar.cy, false);
        for (var y = ar.cy - 1; y <= ar.cy + 2; y++) {
          t[y][ar.x + _arenaW] = Tile.gate;
        }
      case 'N':
        corr(near.cx, near.cy, ar.cx, ar.y + _arenaH + 1, true);
        for (var x = ar.cx - 1; x <= ar.cx + 2; x++) {
          t[ar.y + _arenaH][x] = Tile.gate;
        }
      default:
        corr(near.cx, near.cy, ar.cx, ar.y - 2, true);
        for (var x = ar.cx - 1; x <= ar.cx + 2; x++) {
          t[ar.y - 1][x] = Tile.gate;
        }
    }

    // ---- sala inicial: la más lejana al jefe (primera en empate) ----
    var spIndex = 0;
    for (var i = 1; i < rooms.length; i++) {
      if (dist(rooms[i], ar) > dist(rooms[spIndex], ar)) spIndex = i;
    }
    final sp = rooms[spIndex];

    // ---- decoración (no bloquea la cruz central de cada sala) ----
    for (var i = 0; i < rooms.length; i++) {
      if (i == spIndex) continue;
      final o = rooms[i];
      final k = ri(0, 3);
      for (var n = 0; n < k; n++) {
        final x = ri(o.x + 1, o.x + o.w - 2), y = ri(o.y + 1, o.y + o.h - 2);
        if ((x - o.cx).abs() <= 1 ||
            x == o.cx + 2 ||
            (y - o.cy).abs() <= 1 ||
            y == o.cy + 2) {
          continue;
        }
        t[y][x] = r() < 0.3 ? Tile.water : Tile.wall;
      }
    }

    // ---- relleno: lo inalcanzable se vuelve muro ----
    final seen = <int>{sp.cy * w + sp.cx};
    final stack = <(int, int)>[(sp.cx, sp.cy)];
    while (stack.isNotEmpty) {
      final (x, y) = stack.removeLast();
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final key = ny * w + nx;
        if (seen.contains(key)) continue;
        final c = t[ny][nx];
        if (c == Tile.wall || c == Tile.water || c == Tile.merchant) continue;
        seen.add(key);
        stack.add((nx, ny));
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final c = t[y][x];
        if ((c == Tile.floor || c == Tile.path) && !seen.contains(y * w + x)) {
          t[y][x] = Tile.wall;
        }
      }
    }

    final spots = <(int, int)>[];
    for (var i = 0; i < rooms.length; i++) {
      if (i == spIndex) continue;
      final o = rooms[i];
      for (var y = o.y; y < o.y + o.h; y++) {
        for (var x = o.x; x < o.x + o.w; x++) {
          if (t[y][x] == Tile.floor && seen.contains(y * w + x)) {
            spots.add((x, y));
          }
        }
      }
    }

    return GameMap(
      width: w,
      height: h,
      rows: [for (final row in t) row.join()],
      theme: theme,
      side: side,
      arena: ar,
      rooms: List.unmodifiable(rooms),
      spawn: WorldPoint(sp.cx * tileSize + 8.0, sp.cy * tileSize + 8.0),
      boss: WorldPoint(ar.cx * tileSize + 8.0, ar.cy * tileSize + 8.0),
      spots: List.unmodifiable(spots),
    );
  }
  // ------------------------------------------------------------------
  // Mundo y zonas (docs/specs/worldgen.md § 6.5 y § 6.6)
  // ------------------------------------------------------------------

  /// Columnas de muro entre pisos del atlas de una zona.
  static const floorGap = 18;

  /// El pueblo (town_loop.md § 2.1, town_editor.md § 4): claro de bosque
  /// con la fuente rúnica al centro, caminos de tierra, los lugares fijos
  /// y las construcciones del mundo (lagos, huertas) con sus caminos
  /// procedurales. Reemplaza al overworld caminable: las zonas se eligen
  /// desde el tablero. Sin argumento, el pueblo base.
  static GameMap town([TownState t = const TownState()]) {
    final key = TownPlan.keyOf(t);
    final hit = _towns[key];
    if (hit != null) return hit;
    if (_towns.length > 8) _towns.clear();
    return _towns[key] = _buildTown(t);
  }

  static final _towns = <String, GameMap>{};

  /// El pueblo de un mundo (town_editor.md): con sus ampliaciones.
  static GameMap townOf(TownState t) => town(t);

  /// El exterior del Bosque (overworld_biomes.md § 3).
  static GameMap bosque([Set<int> picked = const {}]) =>
      biome(bosqueLayout, picked);

  /// El exterior de un bioma (overworld_biomes.md § 3) con las matas de
  /// [picked] (índices de `lay.forage`) ya recolectadas.
  static GameMap biome(BiomeLayout lay, [Set<int> picked = const {}]) {
    final key = '${lay.id}|${(picked.toList()..sort()).join(',')}';
    final hit = _bosques[key];
    if (hit != null) return hit;
    if (_bosques.length > 32) _bosques.clear();
    return _bosques[key] = GameMap(
      width: BiomeLayout.width,
      height: BiomeLayout.height,
      rows: lay.rows(picked),
      theme: lay.theme,
      spawn: lay.spawn,
      lobby: true,
      place: lay.id,
      entrances: [
        for (final (z, x, y) in lay.entrances) ZoneEntrance(z, x, y),
      ],
    );
  }

  static final _bosques = <String, GameMap>{};

  static GameMap _buildTown(TownState s) {
    final p = TownPlan.of(s);
    final marks = TownPlan.landmarksOf(s);
    // Aparición: al sur de la fuente, donde esté (town_editor.md § 3.3).
    final f = marks.firstWhere((l) => l.spot == TownSpot.fountain);
    final sp = TownLayout.spawnFor(f.x, f.y);
    return GameMap(
      width: p.width,
      height: p.height,
      rows: [for (final row in p.tiles) row.join()],
      theme: TownLayout.theme,
      spawn: WorldPoint(sp.x + p.ox * tileSize, sp.y + p.oy * tileSize),
      lobby: true,
      townOrigin: (p.ox, p.oy),
      townMarks: marks,
    );
  }

  /// El atlas de pisos de la zona [z] para la misión con [seed]: todos
  /// los pisos uno al lado del otro (worldgen.md § 6.6).
  static GameMap zone(ZoneDef z, int seed) {
    // v0.20.22: tope de pisos por misión (worldgen.md § 6.8).
    final n = ZoneRules.missionFloors(z);
    final gens = [
      for (var f = 0; f < n; f++)
        ZoneGenerators.floor(
            z.gen, (seed + 7919 * f + 104729 * z.index).toSigned(32),
            last: f == n - 1, hasUp: f > 0),
    ];
    final height = gens.map((g) => g.height).reduce((a, b) => a > b ? a : b);
    final width =
        gens.fold(0, (a, g) => a + g.width) + floorGap * (gens.length - 1);
    final gap = Tile.wall * floorGap;
    final rows = <String>[
      for (var y = 0; y < height; y++)
        [
          for (final g in gens) y < g.height ? g.rows[y] : Tile.wall * g.width,
        ].join(gap),
    ];

    WorldPoint px((int, int) p, int ox) =>
        WorldPoint((p.$1 + ox) * tileSize + 8.0, p.$2 * tileSize + 8.0);
    TileRect sh(TileRect r, int ox) => TileRect(r.x + ox, r.y, r.w, r.h);

    final floors = <MapFloor>[];
    final rooms = <TileRect>[];
    final spots = <(int, int)>[];
    var ox = 0;
    for (var f = 0; f < gens.length; f++) {
      final g = gens[f];
      final last = f == gens.length - 1;
      final ar = sh(g.arena, ox);
      final fspots = [for (final s in g.spots) (s.$1 + ox, s.$2)];
      final down = g.stairsDown;
      floors.add(MapFloor(
        index: f,
        bounds: TileRect(ox, 0, g.width, g.height),
        level: ZoneRules.floorLevel(z, f),
        spawn: px(g.spawn, ox),
        last: last,
        stairsDown: down == null ? null : px(down, ox),
        stairsUp: g.stairsUp == null ? null : px(g.stairsUp!, ox),
        returnPoint: down == null ? null : px((down.$1, down.$2 + 2), ox),
        arena: ar,
        side: g.side,
        boss: last
            ? WorldPoint(ar.cx * tileSize + 8.0, ar.cy * tileSize + 8.0)
            : null,
        spots: fspots,
        vaults: [for (final v in g.vaults) sh(v, ox)],
        chestMarks: [for (final c in g.chestMarks) (c.$1 + ox, c.$2)],
        eliteMarks: [for (final c in g.eliteMarks) (c.$1 + ox, c.$2)],
        // v0.6 (worldgen.md § 11): ids únicos en el atlas.
        pois: [
          for (final p in g.pois)
            p.shifted(ox, f, f * 100 + p.id,
                newQuest: p.quest == null ? null : f * 100 + p.quest!),
        ],
        quests: [for (final q in g.quests) q.shifted(f, f * 100 + q.id)],
        chestSpots: [for (final c in g.chestSpots) (c.$1 + ox, c.$2)],
      ));
      rooms.addAll([for (final r in g.rooms) sh(r, ox)]);
      spots.addAll(fspots);
      ox += g.width + floorGap;
    }
    final lastF = floors.last;
    return GameMap(
      width: width,
      height: height,
      rows: rows,
      theme: z.theme,
      spawn: floors.first.spawn,
      side: lastF.side,
      arena: lastF.arena,
      rooms: rooms,
      boss: lastF.boss,
      spots: spots,
      floors: floors,
      zone: z.index,
    );
  }
}
