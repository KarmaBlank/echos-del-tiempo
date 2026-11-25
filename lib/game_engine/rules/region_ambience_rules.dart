// Ambience of biome regions (docs/specs/biome_regions.md § 7.1–7.3):
// roofed cave zones, the light pools under their openings, wind sway of
// the vegetation and the quiet ambience while fishing. Pure: the drawing
// and the audio read these answers; the numbers live in
// `kTuning[TuningId.regions]` and `kTuning[TuningId.fishing]`.

import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';

/// Which side of a roofed tile opens to the sky (the cave mouth).
enum RoofSide { north, south, west, east }

abstract final class RegionAmbienceRules {
  static TuningDef get _r => kTuning[TuningId.regions]!;
  static TuningDef get _f => kTuning[TuningId.fishing]!;

  /// Tiles of the cave rock that read as cave wall: a rock tile with a
  /// roofed tile within [reach] tiles (Chebyshev). Everything else stays
  /// a mountain peak.
  static bool caveWall(BiomeLayout lay, String Function(int, int) tileAt,
      int x, int y,
      {int reach = 3}) {
    if (tileAt(x, y) != Tile.rock) return false;
    for (var dy = -reach; dy <= reach; dy++) {
      for (var dx = -reach; dx <= reach; dx++) {
        if (lay.isIndoor(x + dx, y + dy)) return true;
      }
    }
    return false;
  }

  /// The sides of roofed tile (x, y) that open to walkable ground outside
  /// the roof: the roof edge / overhang is drawn there.
  static List<RoofSide> roofEdges(
      BiomeLayout lay, String Function(int, int) tileAt, int x, int y) {
    if (!lay.isIndoor(x, y)) return const [];
    bool open(int xx, int yy) {
      if (xx < 0 || yy < 0 || xx >= BiomeLayout.width ||
          yy >= BiomeLayout.height) {
        return false;
      }
      if (lay.isIndoor(xx, yy)) return false;
      final t = tileAt(xx, yy);
      return t != Tile.rock && t != Tile.wall && t != Tile.tree;
    }

    return [
      if (open(x, y - 1)) RoofSide.north,
      if (open(x, y + 1)) RoofSide.south,
      if (open(x - 1, y)) RoofSide.west,
      if (open(x + 1, y)) RoofSide.east,
    ];
  }

  /// Light pool under an opening: alpha 0..1 at time [t] (s), a slow,
  /// faint breathing so the pool never reads as a spotlight.
  static double poolAlpha(int hash, double t, {bool motion = true}) {
    final a = _r.d('cavePoolAlpha').clamp(0.0, 1.0);
    if (!motion) return a;
    final ph = (hash % 628) / 100;
    return a * (0.85 + 0.15 * math.sin(t * 0.6 + ph));
  }

  /// Pool half-size (px) and its pixel step (the pool is drawn as
  /// stacked, quantized rects).
  static double get poolSize => _r.d('cavePoolSize').clamp(4.0, 40.0);
  static double get poolPixel => _r.d('cavePoolPixel').clamp(1.0, 8.0);

  /// Dust mote [k] of the pool with [hash] at [t]: offset (px) from the
  /// pool center and its alpha (0 = hidden). Slow drift, wrapping inside
  /// a column above the pool.
  static (double, double, double) mote(int hash, int k, double t) {
    final speed = _r.d('caveMoteSpeed');
    final size = poolSize;
    final ph = ((hash >> (k * 5)) % 100) / 100;
    final f = (t * speed + ph) % 1.0;
    final x = -size * 0.6 + ((hash >> (k * 3)) % 100) / 100 * size * 1.2 +
        math.sin(t * 0.7 + k * 2.1) * 2;
    final y = -size * 1.6 + f * size * 1.8;
    // Fade in and out at the ends of the drift.
    final a = math.sin(f * math.pi);
    return (x, y, a);
  }

  static int get moteCount => _r.i('caveMotes').clamp(0, 8);

  /// Roof lip depth (px) drawn on the open sides of a roofed tile.
  static double get roofLip => _r.d('caveRoofLip').clamp(0.0, 12.0);

  /// Wind sway of vegetation at (x, y): horizontal offset (px, whole
  /// pixels) at [t] seconds. Per-tile phase, so a field ripples instead
  /// of moving as one block. 0 with [motion] off (reduced motion).
  static double sway(int x, int y, double t, {bool motion = true}) {
    if (!motion) return 0;
    final amp = _r.d('swayAmp');
    if (amp <= 0) return 0;
    final speed = _r.d('swaySpeed');
    // A slow gust travelling along x plus a per-tile phase.
    final ph = ((x * 92821) ^ (y * 68917)) % 628 / 100;
    final v = math.sin(t * speed + x * 0.35 + ph) *
        (0.6 + 0.4 * math.sin(t * speed * 0.27 + y * 0.2));
    return (v * amp).roundToDouble();
  }

  /// `true` when vegetation tile (x, y) gets a swaying tuft this frame
  /// (a fixed subset of the tiles, by hash, so the cost stays bounded).
  static bool swaysAt(int x, int y) {
    final d = _r.d('swayDensity').clamp(0.0, 1.0);
    if (d <= 0) return false;
    final h = ((x * 73856093) ^ (y * 19349663)) & 0x3ff;
    return h < d * 1024;
  }

  /// The ambience of [place] (null = the town) while fishing; [indoor]:
  /// the local player stands under a roof.
  static FishingAmbience ambienceFor(String? place, {bool indoor = false}) {
    if (indoor) return FishingAmbience.drip;
    if (place == null || place == kPueblo) return FishingAmbience.breeze;
    final base = kBiomeBases[place];
    if (base == null) {
      // Mines and other underground places.
      return place.startsWith('mina_')
          ? FishingAmbience.drip
          : FishingAmbience.none;
    }
    return base.style.fishingAmbience;
  }

  /// Music level while fishing outside the town (0..1, near silence).
  static double get fishingMusicLevel =>
      _f.d('ambMusicLevel').clamp(0.0, 1.0);

  /// Seconds the music takes to duck / come back.
  static double get fishingDuckSec => _f.d('ambDuckSec').clamp(0.05, 10.0);

  /// Volume (0..1) of the ambience sounds.
  static double get ambienceVolume => _f.d('ambVolume').clamp(0.0, 1.0);

  /// Seconds until the next ambience sound ([rand] in 0..1).
  static double nextGapSec(double rand) {
    final lo = _f.d('ambGapMinSec').clamp(1.0, 600.0);
    final hi = math.max(lo, _f.d('ambGapMaxSec'));
    return lo + (hi - lo) * rand.clamp(0.0, 1.0);
  }

  // ---- Caverns (§ 3.1, § 7.2.1) ----

  static final _depth = Expando<List<int>>('cave depth');

  /// Steps (tiles, 4-neighbour) from roofed tile (x, y) to the nearest
  /// tile outside the roof: 1 = against the wall. 0 outside. Cached per
  /// layout. Drives the vignette toward the walls.
  static int caveDepth(BiomeLayout lay, int x, int y) {
    if (x < 0 || y < 0 || x >= BiomeLayout.width || y >= BiomeLayout.height) {
      return 0;
    }
    final d = _depth[lay] ??= _buildDepth(lay);
    return d[y * BiomeLayout.width + x];
  }

  static List<int> _buildDepth(BiomeLayout lay) {
    const w = BiomeLayout.width, h = BiomeLayout.height;
    final d = List.filled(w * h, 0);
    final q = <int>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!lay.isIndoor(x, y)) continue;
        final edge = !lay.isIndoor(x - 1, y) ||
            !lay.isIndoor(x + 1, y) ||
            !lay.isIndoor(x, y - 1) ||
            !lay.isIndoor(x, y + 1);
        if (edge) {
          d[y * w + x] = 1;
          q.add(y * w + x);
        }
      }
    }
    for (var i = 0; i < q.length; i++) {
      final p = q[i], x = p % w, y = p ~/ w;
      for (final (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]) {
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final n = ny * w + nx;
        if (d[n] != 0 || !lay.isIndoor(nx, ny)) continue;
        d[n] = d[p] + 1;
        q.add(n);
      }
    }
    return d;
  }

  /// Darkness (0..1) of roofed tile (x, y): the base plus the vignette,
  /// strongest against the walls and fading over `caveVignetteTiles`.
  static double caveDarkness(BiomeLayout lay, int x, int y) {
    final depth = caveDepth(lay, x, y);
    if (depth == 0) return 0;
    final base = _r.d('caveDark').clamp(0.0, 1.0);
    final vig = _r.d('caveVignette').clamp(0.0, 1.0);
    final span = math.max(1.0, _r.d('caveVignetteTiles'));
    final k = 1 - ((depth - 1) / span).clamp(0.0, 1.0);
    return (base + (1 - base) * vig * k).clamp(0.0, 1.0);
  }

  /// A bioluminescent speck / tiny mushroom on cave floor tile (x, y)?
  /// (by hash, `caveSpecks` = share of floor tiles).
  static bool speckAt(int x, int y) {
    final share = _r.d('caveSpecks').clamp(0.0, 1.0);
    final h = ((x * 83492791) ^ (y * 2971215073)) & 0x3ff;
    return h < share * 1024;
  }

  /// Mist band [k] over a lake ellipse (cx, cy, rx, ry, tiles) at [t]:
  /// center (px) and half-size (px). Slow drift along x, wrapping.
  static (double, double, double, double) mist(
      (double, double, double, double) lake, int k, double t) {
    final (cx, cy, rx, ry) = lake;
    final speed = _r.d('caveMistSpeed');
    final ph = (k * 0.37) % 1.0;
    final f = (t * speed / math.max(1.0, rx) + ph) % 1.0;
    final x = (cx - rx + f * 2 * rx) * 16;
    final y = (cy - ry * 0.5 + (k % 3) * ry * 0.5) * 16 +
        math.sin(t * 0.3 + k) * 2;
    return (x, y, rx * 16 * 0.45, 5 + (k % 2) * 2.0);
  }

  /// Alpha of the cold glow on cave water.
  static double get waterGlow => _r.d('caveWaterGlow').clamp(0.0, 1.0);

  static int get mistBands => _r.i('caveMistBands').clamp(0, 8);

  /// Drip ripple on a lake: every `caveDripSec` seconds a ring opens on
  /// a water tile (by hash of the period). Returns the tile and the age
  /// (0..1) of the current ring, or `null` between rings.
  static ((int, int), double)? ripple(
      List<(int, int)> water, int salt, double t) {
    if (water.isEmpty) return null;
    final every = math.max(0.5, _r.d('caveDripSec'));
    const life = 1.2;
    final n = (t / every).floor();
    final age = (t - n * every) / life;
    if (age > 1) return null;
    final h = ((n * 2654435761) ^ (salt * 40503)) & 0x7fffffff;
    return (water[h % water.length], age);
  }
}
