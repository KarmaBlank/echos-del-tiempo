import 'dart:math' as math;

import '../data/vaults_catalog.dart';
import '../models/game_map.dart';
import '../models/zone_def.dart';
import 'map_generator.dart';
import 'mulberry32.dart';

/// Un piso recién generado, en coordenadas locales del piso.
class FloorGen {
  FloorGen({
    required this.rows,
    required this.side,
    required this.arena,
    required this.spawn,
    required this.rooms,
    required this.spots,
    required this.vaults,
    required this.chestMarks,
    required this.eliteMarks,
    this.stairsDown,
    this.stairsUp,
  });

  final List<String> rows;
  final String side;
  final TileRect arena;

  /// Tile de llegada (centro).
  final (int, int) spawn;
  final List<TileRect> rooms;
  final List<(int, int)> spots;
  final List<TileRect> vaults;
  final List<(int, int)> chestMarks;
  final List<(int, int)> eliteMarks;
  final (int, int)? stairsDown;
  final (int, int)? stairsUp;

  int get width => rows.first.length;
  int get height => rows.length;
}

/// Generadores de pisos de zona (docs/specs/worldgen.md § 6.6). Todo es
/// función pura de la semilla.
abstract final class ZoneGenerators {
  static const _arenaStrip = 16;
  static const _arenaW = 13;
  static const _arenaH = 13;

  /// Mínimo de tiles de un hueco para no rellenarlo.
  static const minComponent = 8;

  /// Tipo de vault de cada generador.
  static String vaultType(ZoneGen g) => switch (g) {
        ZoneGen.pradera || ZoneGen.bosque => 'bosque',
        ZoneGen.cavernas => 'cavernas',
        ZoneGen.fortaleza || ZoneGen.laberinto => 'fortaleza',
        ZoneGen.ruinas || ZoneGen.abismo => 'ruinas',
      };

  static bool passable(String c) =>
      c != Tile.wall &&
      c != Tile.water &&
      c != Tile.tree &&
      c != Tile.rock &&
      c != Tile.merchant;

  /// Genera el piso [floor] de [gen]. [last]: lleva el jefe; si no, la
  /// escalera de bajada. [hasUp]: escalera de subida junto al spawn.
  static FloorGen floor(ZoneGen gen, int seed,
      {required bool last, required bool hasUp}) {
    if (gen == ZoneGen.ruinas || gen == ZoneGen.abismo) {
      return _ruins(seed, last: last, hasUp: hasUp, vaultType: vaultType(gen));
    }
    return _organic(gen, seed, last: last, hasUp: hasUp);
  }

  // ------------------------------------------------------------------
  // Ruinas: el genMap intacto + vaults sobre muro macizo
  // ------------------------------------------------------------------

  static FloorGen _ruins(int seed,
      {required bool last, required bool hasUp, required String vaultType}) {
    final base = MapGenerator.ruins('ruinas', seed);
    final g = _Grid([for (final row in base.rows) row.split('')]);
    final r = mulberry32((seed ^ 0x5A17) | 0);
    int ri(int a, int b) => a + (r() * (b - a + 1)).floor();
    final ar = base.arena!;
    final spawn = ((base.spawn.x / 16).floor(), (base.spawn.y / 16).floor());

    final vaults = <TileRect>[];
    final chests = <(int, int)>[];
    final elites = <(int, int)>[];
    final defs = kVaults[vaultType]!;
    final n = 1 + (r() < 0.4 ? 1 : 0);
    for (var k = 0; k < n; k++) {
      final v = defs[ri(0, defs.length - 1)];
      for (var tries = 0; tries < 200; tries++) {
        final x = ri(2, g.w - 3 - v.width), y = ri(2, g.h - 3 - v.height);
        final rect = TileRect(x, y, v.width, v.height);
        var ok = true;
        for (var yy = y - 1; yy <= y + v.height && ok; yy++) {
          for (var xx = x - 1; xx <= x + v.width && ok; xx++) {
            if (g.at(xx, yy) != Tile.wall) ok = false;
          }
        }
        if (!ok || vaults.any((o) => _overlap(o, rect, 1))) continue;
        _stamp(g, v, x, y, chests, elites);
        vaults.add(rect);
        break;
      }
    }
    final forbid = _expand(ar, 1);
    _connectAll(g, spawn, forbid);
    _floodWall(g, spawn);
    final stairs = _placeStairs(g, ar, spawn, last: last, hasUp: hasUp);
    final spots = [
      for (final s in base.spots)
        if (g.at(s.$1, s.$2) == Tile.floor &&
            !vaults.any((v) => _inRect(v, s.$1, s.$2)))
          s,
    ];
    return FloorGen(
      rows: g.rows,
      side: base.side!,
      arena: ar,
      spawn: spawn,
      rooms: base.rooms,
      spots: spots,
      vaults: vaults,
      chestMarks: [for (final c in chests) if (g.at(c.$1, c.$2) == Tile.vaultFloor) c],
      eliteMarks: [for (final c in elites) if (g.at(c.$1, c.$2) == Tile.vaultFloor) c],
      stairsDown: stairs.$1,
      stairsUp: stairs.$2,
    );
  }

  // ------------------------------------------------------------------
  // Pradera / bosque, cavernas y fortaleza
  // ------------------------------------------------------------------

  static FloorGen _organic(ZoneGen gen, int seed,
      {required bool last, required bool hasUp}) {
    final r = mulberry32(seed);
    int ri(int a, int b) => a + (r() * (b - a + 1)).floor();

    final w = ri(58, 70), h = ri(42, 50);
    final g = _Grid([for (var y = 0; y < h; y++) List.filled(w, Tile.wall)]);

    // Franja de la arena, como el genMap.
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
    final region = TileRect(rx0, ry0, rx1 - rx0, ry1 - ry0);

    final rooms = <TileRect>[];
    switch (gen) {
      case ZoneGen.cavernas:
        _caves(g, region, r);
      case ZoneGen.fortaleza || ZoneGen.laberinto:
        _maze(g, region, r, rooms);
      default:
        _forest(g, region, r, gen == ZoneGen.pradera);
    }

    // Vaults.
    final vaults = <TileRect>[];
    final chests = <(int, int)>[];
    final elites = <(int, int)>[];
    final defs = kVaults[vaultType(gen)]!;
    final n = 1 + (r() < 0.4 ? 1 : 0);
    for (var k = 0; k < n; k++) {
      final v = defs[ri(0, defs.length - 1)];
      for (var tries = 0; tries < 60; tries++) {
        final x = ri(region.x + 1, region.x + region.w - 1 - v.width);
        final y = ri(region.y + 1, region.y + region.h - 1 - v.height);
        final rect = TileRect(x, y, v.width, v.height);
        if (vaults.any((o) => _overlap(o, rect, 2))) continue;
        _stamp(g, v, x, y, chests, elites);
        vaults.add(rect);
        break;
      }
    }

    _removeSmall(g, region, vaults);

    // Spawn: el tile abierto (8 vecinos abiertos, fuera de vaults) más
    // lejano a la arena.
    (int, int)? spawn;
    var best = -1;
    for (var y = region.y; y < region.y + region.h; y++) {
      for (var x = region.x; x < region.x + region.w; x++) {
        if (!_open3(g, x, y) || vaults.any((v) => _inRect(_expand(v, 1), x, y))) {
          continue;
        }
        final dx = x - ar.cx, dy = y - ar.cy;
        final d = dx * dx + dy * dy;
        if (d > best) {
          best = d;
          spawn = (x, y);
        }
      }
    }
    if (spawn == null) {
      // Sin lugar abierto (muy improbable): una sala de 3×3 en la esquina.
      final sx = region.x + 2, sy = region.y + 2;
      for (var y = sy - 1; y <= sy + 1; y++) {
        for (var x = sx - 1; x <= sx + 1; x++) {
          g.set(x, y, Tile.floor);
        }
      }
      spawn = (sx, sy);
    }

    final forbid = _expand(ar, 1);
    _connectAll(g, spawn, forbid);

    // Arena con su barrera y un tramo de pasillo afuera.
    for (var y = ar.y; y < ar.y + _arenaH; y++) {
      for (var x = ar.x; x < ar.x + _arenaW; x++) {
        g.set(x, y, Tile.floor);
      }
    }
    for (final (dx, dy) in const [
      (2, 2),
      (_arenaW - 3, 2),
      (2, _arenaH - 3),
      (_arenaW - 3, _arenaH - 3),
    ]) {
      g.set(ar.x + dx, ar.y + dy, Tile.wall);
    }
    final (int, int) front;
    switch (side) {
      case 'E':
        for (var y = ar.cy - 1; y <= ar.cy + 2; y++) {
          g.set(ar.x - 1, y, Tile.gate);
        }
        for (var y = ar.cy; y <= ar.cy + 1; y++) {
          g.set(ar.x - 2, y, Tile.path);
          g.set(ar.x - 3, y, Tile.path);
        }
        front = (ar.x - 3, ar.cy);
      case 'W':
        for (var y = ar.cy - 1; y <= ar.cy + 2; y++) {
          g.set(ar.x + _arenaW, y, Tile.gate);
        }
        for (var y = ar.cy; y <= ar.cy + 1; y++) {
          g.set(ar.x + _arenaW + 1, y, Tile.path);
          g.set(ar.x + _arenaW + 2, y, Tile.path);
        }
        front = (ar.x + _arenaW + 2, ar.cy);
      case 'N':
        for (var x = ar.cx - 1; x <= ar.cx + 2; x++) {
          g.set(x, ar.y + _arenaH, Tile.gate);
        }
        for (var x = ar.cx; x <= ar.cx + 1; x++) {
          g.set(x, ar.y + _arenaH + 1, Tile.path);
          g.set(x, ar.y + _arenaH + 2, Tile.path);
        }
        front = (ar.cx, ar.y + _arenaH + 2);
      default:
        for (var x = ar.cx - 1; x <= ar.cx + 2; x++) {
          g.set(x, ar.y - 1, Tile.gate);
        }
        for (var x = ar.cx; x <= ar.cx + 1; x++) {
          g.set(x, ar.y - 2, Tile.path);
          g.set(x, ar.y - 3, Tile.path);
        }
        front = (ar.cx, ar.y - 3);
    }
    _connectFrom(g, front, _bfs(g, spawn), forbid);
    _connectAll(g, spawn, forbid);
    _floodWall(g, spawn);

    final stairs = _placeStairs(g, ar, spawn, last: last, hasUp: hasUp);

    final spots = <(int, int)>[];
    final noSpot = _expand(ar, 2);
    for (var y = 0; y < g.h; y++) {
      for (var x = 0; x < g.w; x++) {
        final c = g.at(x, y);
        if (c != Tile.floor && c != Tile.path) continue;
        if (_inRect(noSpot, x, y) || vaults.any((v) => _inRect(v, x, y))) {
          continue;
        }
        final dx = x - spawn.$1, dy = y - spawn.$2;
        if (dx * dx + dy * dy <= 100) continue;
        spots.add((x, y));
      }
    }

    return FloorGen(
      rows: g.rows,
      side: side,
      arena: ar,
      spawn: spawn,
      rooms: rooms,
      spots: spots,
      vaults: vaults,
      chestMarks: [for (final c in chests) if (g.at(c.$1, c.$2) == Tile.vaultFloor) c],
      eliteMarks: [for (final c in elites) if (g.at(c.$1, c.$2) == Tile.vaultFloor) c],
      stairsDown: stairs.$1,
      stairsUp: stairs.$2,
    );
  }

  /// Ruido de valor con celdas de [cell] tiles (bilineal suavizado).
  static double Function(int, int) _noise(
      double Function() r, int w, int h, int cell) {
    final gw = w ~/ cell + 2, gh = h ~/ cell + 2;
    final lat = [for (var i = 0; i < gw * gh; i++) r()];
    double sm(double t) => t * t * (3 - 2 * t);
    return (x, y) {
      final gx = x ~/ cell, gy = y ~/ cell;
      final fx = sm((x % cell) / cell), fy = sm((y % cell) / cell);
      double v(int i, int j) => lat[j * gw + i];
      final a = v(gx, gy) + (v(gx + 1, gy) - v(gx, gy)) * fx;
      final b = v(gx, gy + 1) + (v(gx + 1, gy + 1) - v(gx, gy + 1)) * fx;
      return a + (b - a) * fy;
    };
  }

  static void _forest(_Grid g, TileRect reg, double Function() r, bool meadow) {
    final n1 = _noise(r, g.w, g.h, 7), n2 = _noise(r, g.w, g.h, 3);
    final lakes = _noise(r, g.w, g.h, 9);
    final thr = meadow ? 0.60 : 0.53;
    for (var y = reg.y; y < reg.y + reg.h; y++) {
      for (var x = reg.x; x < reg.x + reg.w; x++) {
        final v = 0.7 * n1(x, y) + 0.3 * n2(x, y);
        var c = v > thr ? Tile.wall : Tile.floor;
        if (meadow && c == Tile.floor && lakes(x, y) < 0.16) c = Tile.water;
        g.set(x, y, c);
      }
    }
    // Caminos entre 5 puntos de paso.
    int ri(int a, int b) => a + (r() * (b - a + 1)).floor();
    final pts = [
      for (var i = 0; i < 5; i++)
        (ri(reg.x + 1, reg.x + reg.w - 3), ri(reg.y + 1, reg.y + reg.h - 3)),
    ];
    for (var i = 0; i + 1 < pts.length; i++) {
      _lPath(g, pts[i], pts[i + 1], r() < 0.5, reg);
    }
  }

  static void _caves(_Grid g, TileRect reg, double Function() r) {
    bool inReg(int x, int y) =>
        x >= reg.x && y >= reg.y && x < reg.x + reg.w && y < reg.y + reg.h;
    for (var y = reg.y; y < reg.y + reg.h; y++) {
      for (var x = reg.x; x < reg.x + reg.w; x++) {
        g.set(x, y, r() < 0.46 ? Tile.wall : Tile.floor);
      }
    }
    for (var it = 0; it < 5; it++) {
      final next = <(int, int, String)>[];
      for (var y = reg.y; y < reg.y + reg.h; y++) {
        for (var x = reg.x; x < reg.x + reg.w; x++) {
          var n = 0;
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              if (!inReg(x + dx, y + dy) || g.at(x + dx, y + dy) == Tile.wall) {
                n++;
              }
            }
          }
          final c = n >= 5
              ? Tile.wall
              : n <= 3
                  ? Tile.floor
                  : g.at(x, y);
          next.add((x, y, c));
        }
      }
      for (final (x, y, c) in next) {
        g.set(x, y, c);
      }
    }
    // Charcos de agua helada en cuevas grandes.
    int ri(int a, int b) => a + (r() * (b - a + 1)).floor();
    for (var k = 0; k < 4; k++) {
      final x = ri(reg.x + 3, reg.x + reg.w - 5), y = ri(reg.y + 3, reg.y + reg.h - 4);
      var ok = true;
      for (var yy = y - 2; yy <= y + 3 && ok; yy++) {
        for (var xx = x - 2; xx <= x + 4 && ok; xx++) {
          if (g.at(xx, yy) != Tile.floor) ok = false;
        }
      }
      if (!ok) continue;
      for (var yy = y; yy <= y + 1; yy++) {
        for (var xx = x; xx <= x + 2; xx++) {
          g.set(xx, yy, Tile.water);
        }
      }
    }
  }

  static void _maze(
      _Grid g, TileRect reg, double Function() r, List<TileRect> rooms) {
    int ri(int a, int b) => a + (r() * (b - a + 1)).floor();
    final cols = (reg.w - 1) ~/ 3, rws = (reg.h - 1) ~/ 3;
    int cx(int i) => reg.x + 1 + 3 * i;
    int cy(int j) => reg.y + 1 + 3 * j;
    void open(int x, int y) => g.set(x, y, Tile.path);
    for (var j = 0; j < rws; j++) {
      for (var i = 0; i < cols; i++) {
        for (var dy = 0; dy < 2; dy++) {
          for (var dx = 0; dx < 2; dx++) {
            open(cx(i) + dx, cy(j) + dy);
          }
        }
      }
    }
    // Muro entre (i,j) y su vecino: derecha (horizontal) o abajo.
    void link(int i, int j, bool right) {
      for (var k = 0; k < 2; k++) {
        if (right) {
          open(cx(i) + 2, cy(j) + k);
        } else {
          open(cx(i) + k, cy(j) + 2);
        }
      }
    }

    final seen = List.filled(cols * rws, false);
    final linked = <int>{}; // i * 2 + (right ? 1 : 0) por celda
    final stack = <(int, int)>[(ri(0, cols - 1), ri(0, rws - 1))];
    seen[stack.first.$2 * cols + stack.first.$1] = true;
    while (stack.isNotEmpty) {
      final (i, j) = stack.last;
      final opts = <(int, int)>[
        for (final (di, dj) in const [(1, 0), (-1, 0), (0, 1), (0, -1)])
          if (i + di >= 0 &&
              j + dj >= 0 &&
              i + di < cols &&
              j + dj < rws &&
              !seen[(j + dj) * cols + i + di])
            (i + di, j + dj),
      ];
      if (opts.isEmpty) {
        stack.removeLast();
        continue;
      }
      final (ni, nj) = opts[ri(0, opts.length - 1)];
      seen[nj * cols + ni] = true;
      final ai = math.min(i, ni), aj = math.min(j, nj);
      final right = nj == j;
      link(ai, aj, right);
      linked.add((aj * cols + ai) * 2 + (right ? 1 : 0));
      stack.add((ni, nj));
    }
    // Bucles: un 10% de los muros restantes.
    for (var j = 0; j < rws; j++) {
      for (var i = 0; i < cols; i++) {
        for (final right in const [true, false]) {
          if (right ? i + 1 >= cols : j + 1 >= rws) continue;
          if (linked.contains((j * cols + i) * 2 + (right ? 1 : 0))) continue;
          if (r() < 0.10) link(i, j, right);
        }
      }
    }
    // Salas.
    final nRooms = ri(5, 7);
    for (var k = 0; k < nRooms; k++) {
      final rw = ri(5, 8), rh = ri(4, 7);
      final x = ri(reg.x + 1, reg.x + reg.w - 1 - rw);
      final y = ri(reg.y + 1, reg.y + reg.h - 1 - rh);
      for (var yy = y; yy < y + rh; yy++) {
        for (var xx = x; xx < x + rw; xx++) {
          g.set(xx, yy, Tile.floor);
        }
      }
      rooms.add(TileRect(x, y, rw, rh));
    }
  }

  // ------------------------------------------------------------------
  // Herramientas
  // ------------------------------------------------------------------

  static void _stamp(_Grid g, VaultDef v, int x0, int y0,
      List<(int, int)> chests, List<(int, int)> elites) {
    for (var y = 0; y < v.height; y++) {
      for (var x = 0; x < v.width; x++) {
        final ch = v.rows[y][x];
        final tx = x0 + x, ty = y0 + y;
        switch (ch) {
          case '+':
            g.set(tx, ty, Tile.path);
          case 'c':
            g.set(tx, ty, Tile.vaultFloor);
            chests.add((tx, ty));
          case 'e':
            g.set(tx, ty, Tile.vaultFloor);
            elites.add((tx, ty));
          default:
            g.set(tx, ty, ch);
        }
      }
    }
  }

  /// Camino `,` de 2 de ancho en L de [a] a [b], dentro de [reg].
  static void _lPath(
      _Grid g, (int, int) a, (int, int) b, bool horizontalFirst, TileRect reg) {
    void carve(int x, int y) {
      if (_inRect(reg, x, y)) g.set(x, y, Tile.path);
    }

    void hs(int y, int x1, int x2) {
      for (var x = math.min(x1, x2); x <= math.max(x1, x2); x++) {
        carve(x, y);
        carve(x, y + 1);
      }
    }

    void vs(int x, int y1, int y2) {
      for (var y = math.min(y1, y2); y <= math.max(y1, y2); y++) {
        carve(x, y);
        carve(x + 1, y);
      }
    }

    if (horizontalFirst) {
      hs(a.$2, a.$1, b.$1);
      vs(b.$1, a.$2, b.$2);
    } else {
      vs(a.$1, a.$2, b.$2);
      hs(b.$2, a.$1, b.$1);
    }
  }

  static bool _open3(_Grid g, int x, int y) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final c = g.at(x + dx, y + dy);
        if (c != Tile.floor && c != Tile.path) return false;
      }
    }
    return true;
  }

  /// Rellena los huecos de menos de [minComponent] tiles (fuera de vaults).
  static void _removeSmall(_Grid g, TileRect reg, List<TileRect> vaults) {
    final seen = <int>{};
    for (var y = reg.y; y < reg.y + reg.h; y++) {
      for (var x = reg.x; x < reg.x + reg.w; x++) {
        if (seen.contains(y * g.w + x) || !passable(g.at(x, y))) continue;
        final comp = <(int, int)>[];
        final stack = [(x, y)];
        seen.add(y * g.w + x);
        while (stack.isNotEmpty) {
          final (cx, cy) = stack.removeLast();
          comp.add((cx, cy));
          for (final (dx, dy) in _dirs) {
            final nx = cx + dx, ny = cy + dy;
            if (!g.contains(nx, ny) || !passable(g.at(nx, ny))) continue;
            if (seen.add(ny * g.w + nx)) stack.add((nx, ny));
          }
        }
        if (comp.length >= minComponent) continue;
        if (comp.any((p) => vaults.any((v) => _inRect(v, p.$1, p.$2)))) continue;
        for (final (cx, cy) in comp) {
          g.set(cx, cy, Tile.wall);
        }
      }
    }
  }

  static const _dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  /// Tiles alcanzables desde [from] (la barrera cuenta como abierta).
  static Set<int> _bfs(_Grid g, (int, int) from) {
    final seen = <int>{from.$2 * g.w + from.$1};
    final queue = [from];
    for (var i = 0; i < queue.length; i++) {
      final (x, y) = queue[i];
      for (final (dx, dy) in _dirs) {
        final nx = x + dx, ny = y + dy;
        if (!g.contains(nx, ny) || !passable(g.at(nx, ny))) continue;
        if (seen.add(ny * g.w + nx)) queue.add((nx, ny));
      }
    }
    return seen;
  }

  /// Túnel de 1 tile por el camino más corto desde [start] hasta algún
  /// tile de [reach], sin tocar [forbid] ni el borde.
  static void _connectFrom(
      _Grid g, (int, int) start, Set<int> reach, TileRect forbid) {
    final key0 = start.$2 * g.w + start.$1;
    if (reach.contains(key0)) return;
    final prev = <int, int>{key0: -1};
    final queue = [key0];
    int? hit;
    for (var i = 0; i < queue.length && hit == null; i++) {
      final k = queue[i];
      final x = k % g.w, y = k ~/ g.w;
      for (final (dx, dy) in _dirs) {
        final nx = x + dx, ny = y + dy;
        if (nx < 1 || ny < 1 || nx >= g.w - 1 || ny >= g.h - 1) continue;
        if (_inRect(forbid, nx, ny)) continue;
        final nk = ny * g.w + nx;
        if (prev.containsKey(nk)) continue;
        prev[nk] = k;
        if (reach.contains(nk)) {
          hit = nk;
          break;
        }
        queue.add(nk);
      }
    }
    if (hit == null) return;
    var k = prev[hit]!;
    while (k != -1) {
      final x = k % g.w, y = k ~/ g.w;
      if (!passable(g.at(x, y))) g.set(x, y, Tile.path);
      k = prev[k]!;
    }
  }

  /// Une cada componente suelto al del [spawn].
  static void _connectAll(_Grid g, (int, int) spawn, TileRect forbid) {
    for (var guard = 0; guard < 400; guard++) {
      final reach = _bfs(g, spawn);
      (int, int)? loose;
      for (var y = 1; y < g.h - 1 && loose == null; y++) {
        for (var x = 1; x < g.w - 1; x++) {
          if (_inRect(forbid, x, y)) continue;
          if (passable(g.at(x, y)) && !reach.contains(y * g.w + x)) {
            loose = (x, y);
            break;
          }
        }
      }
      if (loose == null) return;
      final before = g.at(loose.$1, loose.$2);
      _connectFrom(g, loose, reach, forbid);
      // Sin camino posible: se rellena para no quedar en bucle.
      if (!_bfs(g, spawn).contains(loose.$2 * g.w + loose.$1)) {
        g.set(loose.$1, loose.$2, before == Tile.water ? before : Tile.wall);
      }
    }
  }

  /// Flood fill desde el spawn: lo caminable inalcanzable se vuelve muro.
  static void _floodWall(_Grid g, (int, int) spawn) {
    final reach = _bfs(g, spawn);
    for (var y = 0; y < g.h; y++) {
      for (var x = 0; x < g.w; x++) {
        if (passable(g.at(x, y)) && !reach.contains(y * g.w + x)) {
          g.set(x, y, Tile.wall);
        }
      }
    }
  }

  /// `>` en el centro de la arena (si no es el último piso) y `<` a 2
  /// tiles del spawn (si [hasUp]).
  static ((int, int)?, (int, int)?) _placeStairs(
      _Grid g, TileRect ar, (int, int) spawn,
      {required bool last, required bool hasUp}) {
    (int, int)? down, up;
    if (!last) {
      down = (ar.cx, ar.cy);
      g.set(ar.cx, ar.cy, Tile.stairsDown);
    }
    if (hasUp) {
      for (final (dx, dy) in const [
        (0, -2), (0, 2), (-2, 0), (2, 0), (-2, -2), (2, 2), (2, -2), (-2, 2),
        (0, -1), (0, 1), (-1, 0), (1, 0),
      ]) {
        final x = spawn.$1 + dx, y = spawn.$2 + dy;
        final c = g.at(x, y);
        if (c == Tile.floor || c == Tile.path || c == Tile.vaultFloor) {
          up = (x, y);
          break;
        }
      }
      up ??= spawn;
      g.set(up.$1, up.$2, Tile.stairsUp);
    }
    return (down, up);
  }

  static bool _inRect(TileRect r, int x, int y) =>
      x >= r.x && y >= r.y && x < r.x + r.w && y < r.y + r.h;

  static TileRect _expand(TileRect r, int m) =>
      TileRect(r.x - m, r.y - m, r.w + 2 * m, r.h + 2 * m);

  static bool _overlap(TileRect a, TileRect b, int m) =>
      a.x - m < b.x + b.w &&
      b.x < a.x + a.w + m &&
      a.y - m < b.y + b.h &&
      b.y < a.y + a.h + m;
}

/// Grilla mutable de tiles.
class _Grid {
  _Grid(this.t)
      : h = t.length,
        w = t.first.length;
  final List<List<String>> t;
  final int w, h;

  bool contains(int x, int y) => x >= 0 && y >= 0 && x < w && y < h;
  String at(int x, int y) => contains(x, y) ? t[y][x] : Tile.wall;
  void set(int x, int y, String c) {
    if (contains(x, y)) t[y][x] = c;
  }

  List<String> get rows => [for (final row in t) row.join()];
}
