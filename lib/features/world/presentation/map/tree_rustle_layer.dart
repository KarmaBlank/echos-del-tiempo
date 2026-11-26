import 'dart:math' as math;
import 'dart:ui';

import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/rules/cozy_rules.dart';

/// Searchable trees (docs/specs/cozy_life.md § 3): a gentle rustle of the
/// canopy and a couple of pixel leaves falling. Only the visible tiles
/// ([x0]..[x1], [y0]..[y1]) are visited; two fixed paints, a handful of
/// 1–2 px rects per tree, nothing allocated per frame. A tree already
/// searched today ([searched]) stays still.
class TreeRustleLayer {
  static const ts = 16.0;

  /// Leaves falling per tree at once.
  static const leavesPerTree = 2;

  final Paint _canopy = Paint()
    ..color = const Color(0xFF7FBF5A)
    ..isAntiAlias = false;
  final Paint _leaf = Paint()
    ..color = const Color(0xFFB7D96A)
    ..isAntiAlias = false;

  /// Trees drawn last frame (perf test / debug).
  int lastDrawn = 0;

  void draw(Canvas c, GameMap map, String biome, int day, int x0, int y0,
      int x1, int y1, double t,
      {bool motion = true, required bool Function(int x, int y) searched}) {
    lastDrawn = 0;
    if (!motion) return;
    final ya = math.max(0, y0), yb = math.min(map.height - 1, y1);
    final xa = math.max(0, x0), xb = math.min(map.width - 1, x1);
    for (var y = ya; y <= yb; y++) {
      for (var x = xa; x <= xb; x++) {
        if (map.tileAt(x, y) != Tile.tree) continue;
        if (!CozyRules.searchable(map, biome, day, x, y)) continue;
        if (searched(x, y)) continue;
        _tree(c, x, y, t);
        lastDrawn++;
      }
    }
  }

  void _tree(Canvas c, int x, int y, double t) {
    final px = x * ts, py = y * ts;
    final ph = ((x * 73 + y * 151) & 63) / 10.0;
    // Rustle: short bursts of a 1 px shake every few seconds.
    final burst = math.sin(t * 0.9 + ph);
    final dx = burst > 0.6 ? (math.sin(t * 18 + ph) > 0 ? 1.0 : -1.0) : 0.0;
    c.drawRect(Rect.fromLTWH(px + 4 + dx, py + 1, 2, 1), _canopy);
    c.drawRect(Rect.fromLTWH(px + 10 - dx, py + 3, 2, 1), _canopy);
    // Falling leaves: each loops over 2.4 s from the canopy to the base.
    for (var i = 0; i < leavesPerTree; i++) {
      final k = ((t / 2.4) + ph / 6.3 + i * 0.5) % 1.0;
      final lx = px + 3 + ((x * 5 + y * 3 + i * 7) % 10) +
          (math.sin(k * 9 + i) * 2).roundToDouble();
      final ly = py + 4 + (k * 14).floorToDouble();
      c.drawRect(Rect.fromLTWH(lx, ly, 1, 1), _leaf);
    }
  }
}
