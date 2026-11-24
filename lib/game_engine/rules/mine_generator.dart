import 'dart:math' as math;

import '../data/mine_catalog.dart';
import '../data/smithing_catalog.dart' show kMineNpcs;
import '../models/game_map.dart';
import 'mulberry32.dart';

/// Knobs of one level generation (from `kTuning[TuningId.smithing]`;
/// the defaults match the shipped tuning so tests can call without it).
class MineGenParams {
  const MineGenParams({
    this.width = 72,
    this.height = 48,
    this.caveDensity = 0.36,
    this.formations = 6,
    this.streamChance = 0.4,
    this.grottoChance = 0.35,
    this.secretChance = 0.6,
    this.relicChance = 0.35,
    this.mushroomChance = 0.6,
    this.loreChance = 0.5,
    this.chestRate = 0.18,
    this.clusters = 12,
    this.sizeMin = 3,
    this.sizeMax = 7,
    this.weights = const {'r': 70, 'd': 10, 'e': 0, 'a': 2},
    this.npcChance = 0.5,
    this.last = false,
  });

  final int width, height;
  final double caveDensity;
  final int formations;
  final double streamChance, grottoChance, secretChance, relicChance;
  final double mushroomChance, loreChance, chestRate;
  final int clusters, sizeMin, sizeMax;

  /// Vein code → weight (`r` common, `d` rich, `e` deep, `a` gem).
  final Map<String, double> weights;
  final double npcChance;

  /// Deepest level: no shaft down.
  final bool last;
}

/// One generated mine level (mining_smithing.md § 1.2): solid natural
/// rock with pockets, veins inside the walls and hidden finds. Pure data:
/// same seed → same level. What players change lives in
/// `MineLevelState` and is laid on top by `MiningRules.rowsOf`.
class MineLevel {
  const MineLevel({
    required this.biome,
    required this.index,
    required this.level,
    required this.rows,
    required this.spawn,
    required this.exit,
    required this.station,
    this.shaft,
    this.npc,
  });

  final String biome;
  final int index, level;

  /// One row per `y`, one tile code per `x`.
  final List<String> rows;

  /// Arrival tile (below the way up), the way up (`<`) and the cart
  /// station spot (`Z`).
  final (int, int) spawn, exit, station;

  /// The natural shaft down (`>`); `null` on the deepest level.
  final (int, int)? shaft;

  /// Ambient NPC (`kMineNpcs` id and tile), or `null`.
  final (String, int, int)? npc;

  int get width => rows.first.length;
  int get height => rows.length;

  String at(int x, int y) => rows[y][x];
  int idx(int x, int y) => y * width + x;
  (int, int) xy(int i) => (i % width, i ~/ width);
}

/// Mine levels: cellular-automata pockets in solid rock, a stream or a
/// crystal grotto now and then, unbreakable formations, vein clusters
/// and sealed discoveries. Same PRNG as the dungeons (`mulberry32`).
abstract final class MineGenerator {
  static const _n8 = [
    (-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)
  ];
  static const _n4 = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  static MineLevel generate(String biome, int index, int level, int seed,
      [MineGenParams p = const MineGenParams()]) {
    final r = mulberry32(seed);
    final w = math.max(24, p.width), h = math.max(20, p.height);
    final g = [
      for (var y = 0; y < h; y++)
        List.filled(w, Tile.wall)
    ];
    bool inner(int x, int y) => x >= 2 && y >= 2 && x < w - 2 && y < h - 2;
    int rnd(int n) => n <= 0 ? 0 : (r() * n).floor().clamp(0, n - 1);
    int dist((int, int) a, (int, int) b) =>
        (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs();

    // 1. Natural pockets: cellular automata (5 smoothing passes).
    var cave = [
      for (var y = 0; y < h; y++)
        [for (var x = 0; x < w; x++) inner(x, y) && r() < p.caveDensity]
    ];
    for (var pass = 0; pass < 5; pass++) {
      cave = [
        for (var y = 0; y < h; y++)
          [
            for (var x = 0; x < w; x++)
              () {
                if (!inner(x, y)) return false;
                var n = 0;
                for (final (dx, dy) in _n8) {
                  if (cave[y + dy][x + dx]) n++;
                }
                return n >= 5 || (cave[y][x] && n >= 4);
              }()
          ]
      ];
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (cave[y][x]) g[y][x] = Tile.floor;
      }
    }

    // 2. The way in: a small chamber at the top middle.
    final cx = w ~/ 2;
    final exit = (cx, 2);
    final spawn = (cx, 4);
    for (var y = 3; y <= 6; y++) {
      for (var x = cx - 3; x <= cx + 3; x++) {
        g[y][x] = Tile.floor;
      }
    }
    final station = (cx + 2, 4);
    bool nearStart(int x, int y, int d) => dist((x, y), spawn) < d;

    // 3. Unbreakable formations.
    for (var k = 0; k < p.formations; k++) {
      final fx = 4 + rnd(w - 8), fy = 6 + rnd(h - 10);
      if (nearStart(fx, fy, 9)) continue;
      final rad = 1 + rnd(2);
      for (var y = fy - rad; y <= fy + rad; y++) {
        for (var x = fx - rad; x <= fx + rad; x++) {
          if (!inner(x, y)) continue;
          if ((x - fx).abs() + (y - fy).abs() > rad + 1) continue;
          g[y][x] = MineTile.bedrock;
        }
      }
    }

    // 4. An underground stream now and then (short: it never splits the
    // level in two).
    if (r() < p.streamChance) {
      var sx = 4 + rnd(w - 30), sy = h ~/ 3 + rnd(h ~/ 3);
      final len = 14 + rnd(10);
      for (var k = 0; k < len && sx < w - 3; k++) {
        if (!nearStart(sx, sy, 7) && inner(sx, sy)) {
          g[sy][sx] = Tile.water;
          for (final dy in const [-1, 1]) {
            final yy = sy + dy;
            if (inner(sx, yy) && g[yy][sx] == Tile.wall) {
              g[yy][sx] = Tile.floor;
            }
          }
        }
        final turn = r();
        if (turn < 0.2 && sy > 4) {
          sy--;
        } else if (turn > 0.8 && sy < h - 5) {
          sy++;
        } else {
          sx++;
        }
      }
    }

    // 5. A crystal grotto now and then.
    if (r() < p.grottoChance) {
      final gx = 6 + rnd(w - 12), gy = 10 + rnd(h - 16);
      if (!nearStart(gx, gy, 10)) {
        for (var y = gy - 4; y <= gy + 4; y++) {
          for (var x = gx - 4; x <= gx + 4; x++) {
            if (!inner(x, y) || g[y][x] == MineTile.bedrock) continue;
            final d = math.sqrt(math.pow(x - gx, 2) + math.pow(y - gy, 2));
            if (d <= 2.6) {
              g[y][x] = Tile.floor;
            } else if (d <= 3.8 && r() < 0.45) {
              g[y][x] = MineTile.crystal;
            }
          }
        }
      }
    }

    // Natural pockets (after the stream and the grotto).
    final pockets = _components(g, w, h);

    // 6. The shaft down: in a far pocket (found by exploring) or sealed
    // in the rock (dug to).
    (int, int)? shaft;
    if (!p.last) {
      final far = [
        for (final c in pockets)
          for (final t in c)
            if (dist(t, spawn) > (w + h) ~/ 3 &&
                _free4(g, t.$1, t.$2))
              t
      ];
      if (far.isNotEmpty && r() < 0.6) {
        shaft = far[rnd(far.length)];
      } else {
        for (var tries = 0; tries < 200 && shaft == null; tries++) {
          final sx = 4 + rnd(w - 8), sy = h ~/ 2 + rnd(h ~/ 2 - 4);
          if (dist((sx, sy), spawn) <= (w + h) ~/ 3) continue;
          if (g[sy][sx] == MineTile.bedrock) continue;
          shaft = (sx, sy);
          for (var y = sy - 1; y <= sy + 1; y++) {
            for (var x = sx - 1; x <= sx + 1; x++) {
              if (inner(x, y)) g[y][x] = Tile.floor;
            }
          }
        }
      }
      if (shaft != null) g[shaft.$2][shaft.$1] = Tile.stairsDown;
    }

    // 7. Vein clusters inside the rock, weighted by kind.
    final total = p.weights.values.fold(0.0, (a, b) => a + b);
    String pickVein() {
      if (total <= 0) return Tile.ore;
      var x = r() * total;
      for (final e in p.weights.entries) {
        x -= e.value;
        if (x < 0) return e.key;
      }
      return Tile.ore;
    }

    for (var k = 0; k < p.clusters; k++) {
      var vx = 3 + rnd(w - 6), vy = 4 + rnd(h - 7);
      if (nearStart(vx, vy, 5) || g[vy][vx] != Tile.wall) continue;
      final kind = pickVein();
      final size = p.sizeMin + rnd(math.max(1, p.sizeMax - p.sizeMin + 1));
      for (var s = 0; s < size * 3 && s < 40; s++) {
        if (inner(vx, vy) && g[vy][vx] == Tile.wall) g[vy][vx] = kind;
        final (dx, dy) = _n4[rnd(4)];
        if (inner(vx + dx, vy + dy)) {
          vx += dx;
          vy += dy;
        }
        if (_count(g, kind) > 0 && s >= size) break;
      }
    }

    // 8. Sealed discoveries: a hidden grotto with gems, a relic chest.
    (int, int)? sealedSpot(int rad) {
      for (var tries = 0; tries < 120; tries++) {
        final sx = 4 + rnd(w - 8), sy = 6 + rnd(h - 10);
        if (nearStart(sx, sy, 12)) continue;
        var ok = true;
        for (var y = sy - rad - 2; y <= sy + rad + 2 && ok; y++) {
          for (var x = sx - rad - 2; x <= sx + rad + 2 && ok; x++) {
            if (!inner(x, y) || g[y][x] != Tile.wall) ok = false;
          }
        }
        if (ok) return (sx, sy);
      }
      return null;
    }

    if (r() < p.secretChance) {
      if (sealedSpot(2) case (final sx, final sy)) {
        for (var y = sy - 1; y <= sy + 1; y++) {
          for (var x = sx - 1; x <= sx + 1; x++) {
            g[y][x] = Tile.floor;
          }
        }
        for (final (x, y) in [
          (sx - 2, sy), (sx + 2, sy), (sx, sy - 2), (sx, sy + 2)
        ]) {
          g[y][x] = MineTile.gem;
        }
        g[sy - 2][sx - 2] = MineTile.crystal;
        g[sy + 2][sx + 2] = MineTile.crystal;
      }
    }
    if (r() < p.relicChance) {
      if (sealedSpot(1) case (final sx, final sy)) {
        for (var y = sy - 1; y <= sy + 1; y++) {
          for (var x = sx - 1; x <= sx + 1; x++) {
            g[y][x] = Tile.floor;
          }
        }
        g[sy][sx] = MineTile.relic;
      }
    }

    // 9. Finds in the natural pockets: chests, mushrooms, a lore stone.
    final open = [
      for (final c in pockets)
        if (c.length >= 6 && !c.any((t) => nearStart(t.$1, t.$2, 6))) c
    ];
    (int, int)? spotIn(List<(int, int)> c) {
      for (var tries = 0; tries < 12; tries++) {
        final t = c[rnd(c.length)];
        if (g[t.$2][t.$1] == Tile.floor && t != shaft) return t;
      }
      return null;
    }

    for (final c in open) {
      if (r() < p.chestRate) {
        if (spotIn(c) case (final x, final y)) g[y][x] = MineTile.chest;
      }
    }
    if (open.isNotEmpty && r() < p.mushroomChance) {
      final c = open[rnd(open.length)];
      for (var k = 0; k < 3; k++) {
        if (spotIn(c) case (final x, final y)) g[y][x] = MineTile.mushroom;
      }
    }
    if (open.isNotEmpty && r() < p.loreChance) {
      final c = open[rnd(open.length)];
      if (spotIn(c) case (final x, final y)) g[y][x] = MineTile.lore;
    }

    // 10. Bedrock border (2 tiles), the way up and the station spot.
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!inner(x, y)) g[y][x] = MineTile.bedrock;
      }
    }
    g[exit.$2][exit.$1] = Tile.stairsUp;
    g[station.$2][station.$1] = MineTile.station;

    (String, int, int)? npc;
    if (level == 0 && r() < p.npcChance) {
      npc = (kMineNpcs[rnd(kMineNpcs.length)], cx - 2, 5);
    }
    return MineLevel(
      biome: biome,
      index: index,
      level: level,
      rows: [for (final row in g) row.join()],
      spawn: spawn,
      exit: exit,
      station: station,
      shaft: shaft,
      npc: npc,
    );
  }

  static int _count(List<List<String>> g, String c) {
    var n = 0;
    for (final row in g) {
      for (final x in row) {
        if (x == c) n++;
      }
    }
    return n;
  }

  static bool _free4(List<List<String>> g, int x, int y) {
    for (final (dx, dy) in _n4) {
      if (g[y + dy][x + dx] != Tile.floor) return false;
    }
    return true;
  }

  /// Floor components (4-connected), in scan order.
  static List<List<(int, int)>> _components(
      List<List<String>> g, int w, int h) {
    final seen = List.generate(h, (_) => List.filled(w, false));
    final out = <List<(int, int)>>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (seen[y][x] || g[y][x] != Tile.floor) continue;
        final comp = <(int, int)>[];
        final q = [(x, y)];
        seen[y][x] = true;
        while (q.isNotEmpty) {
          final (px, py) = q.removeLast();
          comp.add((px, py));
          for (final (dx, dy) in _n4) {
            final nx = px + dx, ny = py + dy;
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
            if (seen[ny][nx] || g[ny][nx] != Tile.floor) continue;
            seen[ny][nx] = true;
            q.add((nx, ny));
          }
        }
        out.add(comp);
      }
    }
    return out;
  }

  /// Rare ore veins of a dungeon floor (mining_smithing.md § 1.4): with
  /// [chance], one tile among [spots] whose 8 neighbours are walkable
  /// floor (so it never cuts a path). Deterministic by [seed]; uses its
  /// own PRNG so the floor generation stays the same.
  static List<(int, int)> dungeonVeins(
      List<String> rows, List<(int, int)> spots, int seed,
      {double chance = 0.5}) {
    if (spots.isEmpty) return const [];
    final r = mulberry32(seed ^ 0x5eed0e);
    if (r() >= chance) return const [];
    bool open8(int x, int y) {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final yy = y + dy, xx = x + dx;
          if (yy < 0 || yy >= rows.length || xx < 0 || xx >= rows[yy].length) {
            return false;
          }
          final c = rows[yy][xx];
          if (c != Tile.floor && c != Tile.path && c != Tile.grass) {
            return false;
          }
        }
      }
      return true;
    }

    final start = (r() * spots.length).floor() % spots.length;
    for (var k = 0; k < spots.length; k++) {
      final s = spots[(start + k) % spots.length];
      if (open8(s.$1, s.$2)) return [s];
    }
    return const [];
  }
}
