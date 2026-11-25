// Rafts on the big lakes (docs/specs/fishing.md § 15). Pure and
// deterministic: the dock of each lake comes from the layout, the moves
// from the map. The client steers with them; the host validates with the
// same rules.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import 'biome_regions.dart';
import 'world_rules.dart';

/// The raft dock of a big lake: the land tile you press E on and the
/// water tile in front of it, where the raft starts.
typedef RaftDock = ({int lake, int x, int y, int wx, int wy});

abstract final class RaftRules {
  static const ts = WorldRules.tileSize;

  static TuningDef get t => tuning(TuningId.fishing);

  /// Raft speed (× the walking speed, `raftSpeed`).
  static double get speedMult => t.d('raftSpeed');

  /// Probes of the raft box (px from the center): a little smaller than
  /// a tile, so it slides along the shore.
  static const _probes = [(-6, -5), (6, -5), (-6, 5), (6, 5)];

  static const _dirs4 = [(0, 1), (1, 0), (-1, 0), (0, -1)];

  // ---------------- dock placement (generator) ----------------

  /// The water tiles of lake [l] (4-connected from its center).
  static Set<(int, int)> lakeTiles(BiomeLayout lay, BiomeLake l) {
    bool water(int x, int y) =>
        x >= 0 &&
        y >= 0 &&
        x < BiomeLayout.width &&
        y < BiomeLayout.height &&
        lay.baseTile(x, y) == Tile.water;
    final (cx, cy, rx, ry) = l.ellipse;
    (int, int)? seed;
    var best = double.infinity;
    final r = rx.ceil() + 1, rr = ry.ceil() + 1;
    for (var y = cy.round() - rr; y <= cy.round() + rr; y++) {
      for (var x = cx.round() - r; x <= cx.round() + r; x++) {
        if (!water(x, y)) continue;
        final d = (x - cx) * (x - cx) + (y - cy) * (y - cy);
        if (d < best) (best, seed) = (d, (x, y));
      }
    }
    final out = <(int, int)>{};
    if (seed == null) return out;
    final q = Queue<(int, int)>()..add(seed);
    out.add(seed);
    while (q.isNotEmpty) {
      final (x, y) = q.removeFirst();
      for (final (dx, dy) in _dirs4) {
        final n = (x + dx, y + dy);
        if (water(n.$1, n.$2) && out.add(n)) q.add(n);
      }
    }
    return out;
  }

  /// A lake gets a raft dock when it is giant or has at least
  /// `raftMinLakeTiles` water tiles.
  static bool isBig(BiomeLake l, int area) =>
      l.giant || area >= t.i('raftMinLakeTiles');

  /// One dock per big lake: the walkable shore tile nearest to the lake's
  /// path end (not on it, not by a fishing dock) whose water tile in
  /// front has open water behind it. Ties by row, then column.
  static List<RaftDock> placeDocks(BiomeLayout lay) {
    final out = <RaftDock>[];
    for (var i = 0; i < lay.lakes.length; i++) {
      final l = lay.lakes[i];
      final tiles = lakeTiles(lay, l);
      if (tiles.isEmpty || !isBig(l, tiles.length)) continue;
      RaftDock? best;
      var bd = 1 << 30;
      final (ax, ay) = l.approach;
      for (final (wx, wy) in tiles) {
        for (final (dx, dy) in _dirs4) {
          final x = wx - dx, y = wy - dy;
          if (x < 1 ||
              y < 1 ||
              x >= BiomeLayout.width - 1 ||
              y >= BiomeLayout.height - 1) {
            continue;
          }
          if (!Tile.isWalkable(lay.baseTile(x, y))) continue;
          // Open water ahead: two more tiles of this lake.
          if (!tiles.contains((wx + dx, wy + dy)) ||
              !tiles.contains((wx + 2 * dx, wy + 2 * dy))) {
            continue;
          }
          if (x == ax && y == ay) continue;
          if (l.docks.any((d) => (d.$1 - x).abs() + (d.$2 - y).abs() <= 1)) {
            continue;
          }
          final d = (x - ax) * (x - ax) + (y - ay) * (y - ay);
          final c = best;
          if (d < bd ||
              (d == bd &&
                  c != null &&
                  (y < c.y || (y == c.y && x < c.x)))) {
            bd = d;
            best = (lake: i, x: x, y: y, wx: wx, wy: wy);
          }
        }
      }
      if (best != null) out.add(best);
    }
    return out;
  }

  // ---------------- movement ----------------

  static bool _water(GameMap m, int tx, int ty) =>
      m.contains(tx, ty) && m.tileAt(tx, ty) == Tile.water;

  /// The raft box at (x, y) px touches something that is not water.
  static bool collides(GameMap m, double x, double y) {
    for (final (ox, oy) in _probes) {
      if (!_water(m, ((x + ox) / ts).floor(), ((y + oy) / ts).floor())) {
        return true;
      }
    }
    return false;
  }

  /// The raft center at (x, y) px is on water (what the host checks).
  static bool onWater(GameMap m, double x, double y) =>
      x.isFinite && y.isFinite && _water(m, (x / ts).floor(), (y / ts).floor());

  /// One step of the raft with the input ([ix], [iy] in -1..1): X then Y,
  /// sliding along the shore.
  static WorldPoint step(
      GameMap m, double x, double y, double ix, double iy, double dt) {
    final l = math.sqrt(ix * ix + iy * iy);
    if (l == 0) return WorldPoint(x, y);
    final v = WorldRules.playerSpeed * speedMult * dt;
    final nx = x + ix / l * v;
    if (!collides(m, nx, y)) x = nx;
    final ny = y + iy / l * v;
    if (!collides(m, x, ny)) y = ny;
    return WorldPoint(x, y);
  }

  // ---------------- board / get off ----------------

  /// The dock in reach of (x, y) px (`raftDockReach` tiles from the dock
  /// tile's center), or `null`.
  static RaftDock? nearDock(BiomeLayout? lay, double x, double y) {
    if (lay == null) return null;
    final reach = t.d('raftDockReach') * ts;
    RaftDock? best;
    var bd = reach;
    for (final d in lay.raftDocks) {
      final dx = (d.x + 0.5) * ts - x, dy = (d.y + 0.5) * ts - y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= bd) (bd, best) = (dist, d);
    }
    return best;
  }

  /// Where boarding at [d] puts the raft: the center of its water tile.
  static WorldPoint launch(RaftDock d) =>
      WorldPoint((d.wx + 0.5) * ts, (d.wy + 0.5) * ts);

  /// Where getting off the raft at (x, y) px puts the player: the
  /// nearest free land tile center within `raftShoreReach` tiles, or
  /// `null` (too far from any shore).
  static WorldPoint? landing(GameMap m, double x, double y) {
    final reach = t.d('raftShoreReach') * ts;
    final r = (reach / ts).ceil() + 1;
    final cx = (x / ts).floor(), cy = (y / ts).floor();
    WorldPoint? best;
    var bd = reach + 0.001;
    for (var ty = cy - r; ty <= cy + r; ty++) {
      for (var tx = cx - r; tx <= cx + r; tx++) {
        if (!m.contains(tx, ty) || !Tile.isWalkable(m.tileAt(tx, ty))) {
          continue;
        }
        final px = (tx + 0.5) * ts, py = (ty + 0.5) * ts;
        if (WorldRules.collides(m, px, py)) continue;
        // Distance from the raft center to the tile's nearest edge.
        final ex = math.max(math.max(tx * ts - x, 0.0), x - (tx + 1) * ts);
        final ey = math.max(math.max(ty * ts - y, 0.0), y - (ty + 1) * ts);
        final d = math.sqrt(ex * ex + ey * ey);
        if (d < bd) (bd, best) = (d, WorldPoint(px, py));
      }
    }
    return best;
  }

  // ---------------- depth (fishing) ----------------

  static final _depth = Expando<Uint8List>('raftDepth');

  /// Tiles from (tx, ty) to the nearest tile that is not water (8-way;
  /// 0 off the water). Cached per map.
  static int depth(GameMap m, int tx, int ty) {
    if (!_water(m, tx, ty)) return 0;
    final f = _depth[m] ??= _field(m);
    return f[ty * m.width + tx];
  }

  /// Depth under the point (x, y) px.
  static int depthAt(GameMap m, double x, double y) =>
      x.isFinite && y.isFinite ? depth(m, (x / ts).floor(), (y / ts).floor()) : 0;

  static Uint8List _field(GameMap m) {
    final w = m.width, h = m.height;
    final d = Uint8List(w * h)..fillRange(0, w * h, 255);
    final q = Queue<int>();
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (m.tileAt(x, y) != Tile.water) {
          d[y * w + x] = 0;
          q.add(y * w + x);
        }
      }
    }
    while (q.isNotEmpty) {
      final i = q.removeFirst();
      final x = i % w, y = i ~/ w, v = d[i] + 1;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final j = ny * w + nx;
          if (d[j] > v) {
            d[j] = math.min(v, 254);
            q.add(j);
          }
        }
      }
    }
    // Water at the map edge: the edge counts as shore.
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final e = math.min(math.min(x, y), math.min(w - 1 - x, h - 1 - y)) + 1;
        if (d[y * w + x] > e) d[y * w + x] = e;
      }
    }
    return d;
  }

  /// Rarity bonus of fishing at [depth] tiles (`deepRarePerTile`, capped
  /// by `deepRareMax`).
  static double depthRare(int depth) => math.min(
      t.d('deepRareMax'), math.max(0, depth - 1) * t.d('deepRarePerTile'));

  /// Size bonus (toward the top of the range) at [depth] tiles.
  static double depthSize(int depth) => math.min(
      t.d('deepSizeMax'), math.max(0, depth - 1) * t.d('deepSizePerTile'));
}
