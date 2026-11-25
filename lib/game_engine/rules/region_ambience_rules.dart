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
      {int reach = 2}) {
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
}
