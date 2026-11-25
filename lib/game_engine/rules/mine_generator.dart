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
    this.caveDensity = 0,
    this.formations = 6,
    this.streamChance = 0.5,
    this.lakeChance = 0.3,
    this.chambers = 6,
    this.chamberMin = 1,
    this.chamberMax = 2,
    this.grottoChance = 0.35,
    this.secretChance = 0.6,
    this.relicChance = 0.35,
    this.mushroomChance = 0.6,
    this.loreChance = 0.5,
    this.chestRate = 0.3,
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
  final double streamChance, lakeChance, grottoChance, secretChance, relicChance;

  /// Small sealed discovery chambers and their radius range (tiles).
  final int chambers, chamberMin, chamberMax;
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

/// Mine levels, dig-first: solid rock except the entry chamber, the
/// shaft spot and small sealed discovery chambers (optional open pockets
/// only with `caveDensity` > 0), unbreakable formations and ore veins in
/// the walls. Same PRNG as the dungeons (`mulberry32`).
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


    // 6. The shaft down: in a far pocket (found by exploring) or sealed
    // in the rock (dug to).
    (int, int)? shaft;
    if (!p.last) {
      // Dig-first (mining_smithing.md § 1.2): always sealed in the rock.
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
      if (shaft != null) g[shaft.$2][shaft.$1] = Tile.stairsDown;
    }

    // 7. Small sealed discovery chambers, reached only by digging: a
    // chest room, a mushroom or lake pocket, a lore stone or a crystal
    // grotto (mining_smithing.md § 1.2).
    (int, int)? sealedAt(int rad) {
      for (var tries = 0; tries < 120; tries++) {
        final sx = 4 + rnd(w - 8), sy = 6 + rnd(h - 10);
        if (nearStart(sx, sy, 10)) continue;
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

    final lo = math.max(1, p.chamberMin);
    final hi = math.max(lo, p.chamberMax);
    for (var k = 0; k < p.chambers; k++) {
      final rad = lo + rnd(hi - lo + 1);
      final at = sealedAt(rad);
      if (at == null) continue;
      final (sx, sy) = at;
      final cells = <(int, int)>[];
      for (var y = sy - rad; y <= sy + rad; y++) {
        for (var x = sx - rad; x <= sx + rad; x++) {
          if ((x - sx) * (x - sx) + (y - sy) * (y - sy) > rad * rad + rad) {
            continue;
          }
          g[y][x] = Tile.floor;
          cells.add((x, y));
        }
      }
      (int, int) any() => cells[rnd(cells.length)];
      if (r() < p.chestRate) {
        g[sy][sx] = MineTile.chest;
      } else if (r() < p.mushroomChance) {
        for (var n = 0; n < 3; n++) {
          final (x, y) = any();
          g[y][x] = MineTile.mushroom;
        }
      } else if (r() < p.loreChance) {
        g[sy][sx] = MineTile.lore;
      } else if (r() < p.lakeChance) {
        g[sy][sx] = Tile.water;
        if (rad > 1) g[sy][sx + 1] = Tile.water;
      } else if (r() < p.grottoChance) {
        for (var y = sy - rad - 1; y <= sy + rad + 1; y++) {
          for (var x = sx - rad - 1; x <= sx + rad + 1; x++) {
            if (inner(x, y) && g[y][x] == Tile.wall && r() < 0.5) {
              g[y][x] = MineTile.crystal;
            }
          }
        }
      }
    }

    // Small underground streams (scenery): a short run of water sealed in
    // the rock, no open banks, so it never becomes a path.
    for (var k = 0; k < 2; k++) {
      if (r() >= p.streamChance) continue;
      var sx = 4 + rnd(w - 16), sy = 8 + rnd(h - 14);
      final len = 5 + rnd(6);
      for (var n = 0; n < len; n++) {
        if (inner(sx, sy) && !nearStart(sx, sy, 8) && g[sy][sx] == Tile.wall) {
          g[sy][sx] = Tile.water;
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

    // 8. Vein clusters inside the rock, weighted by kind.
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
