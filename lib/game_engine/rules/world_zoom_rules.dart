import 'dart:math' as math;

import '../data/tuning_catalog.dart';

/// Pixel-perfect world zoom (exploration.md § Cámara, "Zoom del mundo").
///
/// A zoom LEVEL is an integer offset from the base pixel scale: the world
/// is always drawn with a whole number of screen pixels per world pixel
/// (`basePixelScale + level`), never a fraction. Pure: no Flutter.
abstract final class WorldZoomRules {
  static TuningDef get t => tuning(TuningId.regions);

  /// Lowest level the player can pick (negative = farther away).
  static int get minLevel => t.i('worldZoomMin').clamp(-3, 0);

  /// Highest level the player can pick (closer).
  static int get maxLevel => t.i('worldZoomMax').clamp(0, 4);

  /// Levels the fishing calm moves closer (cozy_life.md § 1).
  static int get fishSteps => t.i('worldZoomFishSteps').clamp(0, 4);

  /// [level] inside the tunable range.
  static int clampLevel(int level) => level.clamp(minLevel, maxLevel);

  /// One Ctrl + wheel notch: [dir] > 0 closer, < 0 farther, clamped.
  static int step(int level, int dir) => clampLevel(level + dir.sign);

  /// The level actually drawn: the player's [chosen] one, or
  /// [fishSteps] closer while [fishing] when that is still allowed
  /// (if not, the fishing zoom is skipped). Leaving the water returns
  /// to [chosen].
  static int effective(int chosen, {required bool fishing}) {
    final c = clampLevel(chosen);
    if (!fishing || fishSteps == 0) return c;
    final f = c + fishSteps;
    return f <= maxLevel ? f : c;
  }

  /// Whole base scale for a fit scale [fit] (screen px per virtual px).
  static int basePixelScale(double fit) =>
      fit.isFinite ? math.max(1, fit.round()) : 1;

  /// Screen px per world px at [level] (always an integer ≥ 1).
  static int pixelScale(double fit, int level) =>
      math.max(1, basePixelScale(fit) + level);
}
