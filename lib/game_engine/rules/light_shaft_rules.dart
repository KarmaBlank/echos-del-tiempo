import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/light_catalog.dart';
import '../models/game_map.dart';

/// Light shafts and cloud shadows (docs/specs/biome_regions.md § 7).
/// Pure: which tiles get a shaft, which places have openings, and where
/// the cloud shadows drift. The drawing lives in `RegionLightLayer`.
abstract final class LightShaftRules {
  /// Openings of [map]: a biome region's cave skylights, or the theme's
  /// openings (`kLightShaftThemes`); themes without an entry stay dark.
  static bool hasOpenings(GameMap map) {
    // A biome region: only its cave skylights. The theme's hashed
    // openings are for roofed maps; on an open exterior they put bright
    // shaft lights on open grass (v0.49.9 bug).
    if (map.lobby && biomeLayout(map.place) != null) {
      return biomeLayout(map.place)!.skylights.isNotEmpty;
    }
    return kLightShaftThemes.containsKey(map.theme);
  }

  static final _cache = Expando<List<(int, int)>>('shafts');

  /// Shaft tiles of [map] (cached per map). Region skylights plus, for a
  /// flagged theme, open floor tiles picked by hash (with open floor all
  /// around, so a shaft never sits against a wall).
  static List<(int, int)> shafts(GameMap map) =>
      _cache[map.rows] ??= _build(map);

  static List<(int, int)> _build(GameMap map) {
    final out = <(int, int)>[];
    if (map.lobby) {
      if (biomeLayout(map.place) case final lay?) {
        // Only skylights under the roof (biome_regions.md § 7.2.1).
        out.addAll([
          for (final (x, y) in lay.skylights)
            if (lay.isIndoor(x, y)) (x, y),
        ]);
        return List.unmodifiable(out);
      }
    }
    final def = kLightShaftThemes[map.theme];
    if (def == null) return List.unmodifiable(out);
    final every = math.max(2, def.every);
    for (var y = 1; y < map.height - 1; y++) {
      for (var x = 1; x < map.width - 1; x++) {
        if (hash(x, y) % every != 0) continue;
        if (!_open(map, x, y)) continue;
        out.add((x, y));
      }
    }
    return List.unmodifiable(out);
  }

  static bool _open(GameMap map, int x, int y) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (!Tile.isWalkable(map.tileAt(x + dx, y + dy))) return false;
        if (map.tileAt(x + dx, y + dy) == Tile.voidTile) return false;
      }
    }
    return true;
  }

  /// Shafts inside the tile window [x0, x1) × [y0, y1), into [out]
  /// (cleared first; no allocation when it has room).
  static void visible(GameMap map, int x0, int y0, int x1, int y1,
      List<(int, int)> out) {
    out.clear();
    for (final s in shafts(map)) {
      if (s.$1 >= x0 && s.$1 < x1 && s.$2 >= y0 && s.$2 < y1) out.add(s);
    }
  }

  static int hash(int x, int y) {
    var h = (x * 73856093) ^ (y * 19349663);
    h = (h ^ (h >> 13)) & 0x7fffffff;
    h = (h * 0x5bd1e995) & 0x7fffffff;
    return h ^ (h >> 15);
  }

  // ---------------- cloud shadows (§ 7.1) ----------------

  /// Cloud shadow strength (0..1 alpha scale) for the weather: thicker
  /// with rain and storm; none at night ([dark] ≥ 0.6).
  static double cloudCover(String weatherKey, double dark) {
    if (dark >= 0.6) return 0;
    final base = switch (weatherKey) {
      'tormenta' => 1.0,
      'lluvia' => 0.75,
      'fog' => 0.5,
      'snow' => 0.55,
      _ => 0.5,
    };
    return base * (1 - dark / 0.6);
  }

  /// Number of cloud shadows that exist at a [cover].
  static int cloudCount(double cover) => cover <= 0 ? 0 : (4 + cover * 6).round();

  /// Cloud [i] at time [t] (s): center (px) and radii. They drift slowly
  /// east-south-east over a wrapping field of [fieldW] × [fieldH] px.
  static (double, double, double, double) cloud(
      int i, double t, double fieldW, double fieldH) {
    final h = hash(i * 31 + 7, i * 17 + 3);
    final rx = 90.0 + (h % 120);
    final ry = rx * (0.45 + ((h >> 8) % 20) / 100);
    final speed = 6.0 + (h >> 12) % 6;
    final x0 = ((h >> 4) % 1000) / 1000 * fieldW;
    final y0 = ((h >> 14) % 1000) / 1000 * fieldH;
    final x = (x0 + t * speed) % (fieldW + rx * 2) - rx;
    final y = (y0 + t * speed * 0.3) % (fieldH + ry * 2) - ry;
    return (x, y, rx, ry);
  }
}
