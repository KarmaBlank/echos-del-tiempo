import '../data/smithing_catalog.dart' show kMineNpcs;
import '../models/game_map.dart';
import 'mulberry32.dart';

/// A generated mine (docs/specs/mining_smithing.md § 1.2): pure data,
/// same seed → same mine.
class MineLayout {
  const MineLayout({
    required this.biome,
    required this.index,
    required this.rows,
    required this.spawn,
    required this.exit,
    required this.nodes,
    this.npc,
  });

  final String biome;
  final int index;

  /// One row per `y`, one [Tile] per `x`, with every vein ready.
  final List<String> rows;

  /// Arrival tile (just above the exit) and the exit tile (`<`).
  final (int, int) spawn, exit;

  /// Vein tiles, in vein index order.
  final List<(int, int)> nodes;

  /// Ambient NPC (`kMineNpcs` id and tile), or `null`.
  final (String, int, int)? npc;

  int get width => rows.first.length;
  int get height => rows.length;

  /// The rows with the veins of [spent] (vein indexes) spent.
  List<String> rowsWith(Set<int> spent) {
    if (spent.isEmpty) return rows;
    final g = [for (final r in rows) r.split('')];
    for (final i in spent) {
      if (i < 0 || i >= nodes.length) continue;
      final (x, y) = nodes[i];
      g[y][x] = Tile.oreUsed;
    }
    return [for (final r in g) r.join()];
  }
}

/// Small calm caves for the mines: a random walk carved from the exit,
/// veins that never cut a path, a few lit lanterns and maybe an NPC.
/// Same PRNG as the dungeons (`mulberry32`).
abstract final class MineGenerator {
  static const width = 30, height = 20;

  /// Share of the area carved as floor.
  static const floorShare = 0.40;

  static const _dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  static MineLayout generate(String biome, int index, int seed,
      {int nodes = 7, double npcChance = 0.5}) {
    final r = mulberry32(seed);
    final g = [for (var y = 0; y < height; y++) List.filled(width, Tile.wall)];
    const exit = (width ~/ 2, height - 2);
    final spawn = (exit.$1, exit.$2 - 1);
    g[exit.$2][exit.$1] = Tile.stairsUp;
    var x = spawn.$1, y = spawn.$2;
    var carved = 0;
    final target = (width * height * floorShare).round();
    for (var step = 0; step < 20000 && carved < target; step++) {
      if (g[y][x] == Tile.wall) {
        g[y][x] = Tile.floor;
        carved++;
      }
      final (dx, dy) = _dirs[(r() * 4).floor().clamp(0, 3)];
      final nx = x + dx, ny = y + dy;
      // Keep a wall border and the exit row clear.
      if (nx < 2 || ny < 1 || nx > width - 3 || ny > height - 3) continue;
      x = nx;
      y = ny;
    }
    // Room around the arrival so the exit is never boxed in.
    for (var dy = -1; dy <= 0; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final (ax, ay) = (spawn.$1 + dx, spawn.$2 + dy);
        if (g[ay][ax] == Tile.wall) g[ay][ax] = Tile.floor;
      }
    }

    bool open8(int cx, int cy) {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final c = g[cy + dy][cx + dx];
          if (c != Tile.floor) return false;
        }
      }
      return true;
    }

    int dist((int, int) a, (int, int) b) =>
        (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs();

    // Candidates in scan order, shuffled with the seed (deterministic).
    final cands = <(int, int)>[
      for (var cy = 1; cy < height - 2; cy++)
        for (var cx = 1; cx < width - 1; cx++)
          if (g[cy][cx] == Tile.floor && dist((cx, cy), spawn) >= 4) (cx, cy),
    ];
    for (var i = cands.length - 1; i > 0; i--) {
      final j = (r() * (i + 1)).floor().clamp(0, i);
      final t = cands[i];
      cands[i] = cands[j];
      cands[j] = t;
    }
    // A solid tile whose 8 neighbours are floor never disconnects the
    // cave, and two of them never touch (spacing ≥ 2).
    final placed = <(int, int)>[];
    bool take((int, int) c, String tile) {
      if (!open8(c.$1, c.$2)) return false;
      if (placed.any((p) => dist(p, c) < 3)) return false;
      g[c.$2][c.$1] = tile;
      placed.add(c);
      return true;
    }

    final veins = <(int, int)>[];
    for (final c in cands) {
      if (veins.length >= nodes) break;
      if (take(c, Tile.ore)) veins.add(c);
    }
    var lamps = 0;
    for (final c in cands) {
      if (lamps >= 3) break;
      if (take(c, Tile.lanternLit)) lamps++;
    }
    (String, int, int)? npc;
    if (r() < npcChance) {
      final id = kMineNpcs[(r() * kMineNpcs.length).floor() % kMineNpcs.length];
      for (final c in cands) {
        if (g[c.$2][c.$1] == Tile.floor &&
            dist(c, spawn) >= 5 &&
            !placed.any((p) => dist(p, c) < 2)) {
          npc = (id, c.$1, c.$2);
          break;
        }
      }
    }
    return MineLayout(
      biome: biome,
      index: index,
      rows: [for (final row in g) row.join()],
      spawn: spawn,
      exit: exit,
      nodes: veins,
      npc: npc,
    );
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
