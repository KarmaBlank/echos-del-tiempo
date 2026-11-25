// Walking routes over a generated biome exterior (docs/specs/
// overworld_biomes.md § 10.1.1). Pure and deterministic: the same layout
// and start give the same route on every peer.

import '../models/game_map.dart';
import 'biome_regions.dart';

/// A* over the walkable tiles of a [BiomeLayout].
abstract final class BiomeRouteRules {
  /// Step cost on a path / trail tile.
  static const pathCost = 1;

  /// Step cost on any other walkable ground (grass, floor, bridge...).
  static const groundCost = 4;

  /// Never stepped on, even if a layout marks them walkable.
  static const _blocked = {Tile.water, Tile.fishing, Tile.lava, Tile.voidTile};

  /// Can a traveller stand on ([x], [y]) of [rows]?
  static bool walkable(List<String> rows, int x, int y) {
    if (y < 0 || y >= rows.length || x < 0 || x >= rows[y].length) {
      return false;
    }
    final c = rows[y][x];
    return !_blocked.contains(c) && Tile.isWalkable(c);
  }

  /// Cost of stepping onto ([x], [y]).
  static int cost(List<String> rows, int x, int y) =>
      rows[y][x] == Tile.path || rows[y][x] == Tile.bridge
          ? pathCost
          : groundCost;

  /// The cheapest 4-way route from [from] to [to] over [rows] (both ends
  /// included), or `null` when there is none. [from] may be off the
  /// walkable set (an NPC standing beside a stall): it is only left.
  /// Ties break by a fixed neighbour order, so it is deterministic.
  static List<(int, int)>? route(
      List<String> rows, (int, int) from, (int, int) to) {
    final h = rows.length;
    if (h == 0 || !walkable(rows, to.$1, to.$2)) return null;
    final w = rows.first.length;
    if (from.$1 < 0 || from.$2 < 0 || from.$1 >= w || from.$2 >= h) {
      return null;
    }
    int id(int x, int y) => y * w + x;
    int heur(int x, int y) => ((x - to.$1).abs() + (y - to.$2).abs()) * pathCost;
    final g = List<int>.filled(w * h, 1 << 30);
    final prev = List<int>.filled(w * h, -1);
    final closed = List<bool>.filled(w * h, false);
    // Small binary heap of (f, seq, node); seq keeps ties stable.
    final heap = <(int, int, int)>[];
    var seq = 0;
    void push((int, int, int) e) {
      heap.add(e);
      var i = heap.length - 1;
      while (i > 0) {
        final p = (i - 1) >> 1;
        if (_less(heap[i], heap[p])) {
          final t = heap[i];
          heap[i] = heap[p];
          heap[p] = t;
          i = p;
        } else {
          break;
        }
      }
    }

    (int, int, int) pop() {
      final top = heap.first;
      final last = heap.removeLast();
      if (heap.isNotEmpty) {
        heap[0] = last;
        var i = 0;
        while (true) {
          final l = 2 * i + 1, r = l + 1;
          var m = i;
          if (l < heap.length && _less(heap[l], heap[m])) m = l;
          if (r < heap.length && _less(heap[r], heap[m])) m = r;
          if (m == i) break;
          final t = heap[i];
          heap[i] = heap[m];
          heap[m] = t;
          i = m;
        }
      }
      return top;
    }

    final s = id(from.$1, from.$2), goal = id(to.$1, to.$2);
    g[s] = 0;
    push((heur(from.$1, from.$2), seq++, s));
    const dirs = [(0, 1), (1, 0), (-1, 0), (0, -1)];
    while (heap.isNotEmpty) {
      final (_, _, n) = pop();
      if (closed[n]) continue;
      closed[n] = true;
      if (n == goal) break;
      final x = n % w, y = n ~/ w;
      for (final (dx, dy) in dirs) {
        final nx = x + dx, ny = y + dy;
        if (!walkable(rows, nx, ny)) continue;
        final m = id(nx, ny);
        if (closed[m]) continue;
        final ng = g[n] + cost(rows, nx, ny);
        if (ng < g[m]) {
          g[m] = ng;
          prev[m] = n;
          push((ng + heur(nx, ny), seq++, m));
        }
      }
    }
    if (!closed[goal]) return null;
    final out = <(int, int)>[];
    for (var n = goal; n != -1; n = prev[n]) {
      out.add((n % w, n ~/ w));
      if (n == s) break;
    }
    return out.reversed.toList();
  }

  static bool _less((int, int, int) a, (int, int, int) b) =>
      a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 < b.$2);

  /// The tile in front of the "CAMINO AL PUEBLO" sign: the south end of
  /// the main path, where travellers leave for the town.
  static (int, int) townExit(BiomeLayout lay) => lay.mainPath.first;

  static final _cache = <(String, int, int, int), List<(int, int)>?>{};

  /// Route of someone leaving [lay] from [from] to [townExit] (cached
  /// per layout, seed and start).
  static List<(int, int)>? toTown(BiomeLayout lay, (int, int) from) =>
      _cache.putIfAbsent((lay.id, lay.seed, from.$1, from.$2),
          () => route(lay.rows(const {}), from, townExit(lay)));
}
