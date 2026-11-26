// Water reflections (docs/specs/water_reflections.md): which water
// reflects what, the integer wave of the strips, the discrete fade steps,
// the wake around moving actors and the actor cap. Pure: the drawing
// (`WaterReflectionLayer`) reads these answers; the numbers live in
// `kTuning[TuningId.regions]` (keys `refl*`).

import 'dart:math' as math;

import '../data/tuning_catalog.dart';
import '../models/game_map.dart';

/// How a water tile reflects (§ 2).
enum WaterKind {
  /// Not water (or lava): nothing.
  none,

  /// Open water: everything.
  clear,

  /// Murky water: everything, weaker and greener.
  murky,

  /// Water under a roof: light streaks and actors (no sky, no shore).
  cave,
}

/// One actor that may be reflected: its foot (px) and whether it moves.
typedef ReflectionCandidate = ({double x, double y, bool moving});

abstract final class ReflectionRules {
  static TuningDef get _r => kTuning[TuningId.regions]!;

  /// Themes whose water is murky (§ 2).
  static const murkyThemes = {'bosque', 'cementerio'};

  /// Strip height (px) per quality: high 1, low 2.
  static int stripHeight({required bool high}) => high ? 1 : 2;

  /// Kind of tile [ch] on a map of [theme]; [roofed] = under a cave roof,
  /// a mine or a dark dungeon.
  static WaterKind kindOf(String ch, String theme, {required bool roofed}) {
    if (ch != Tile.water && ch != Tile.fishing) return WaterKind.none;
    if (roofed) return WaterKind.cave;
    return murkyThemes.contains(theme) ? WaterKind.murky : WaterKind.clear;
  }

  /// Reflection opacity of a water [kind] (0 for none; cave is dimmer).
  static double alphaOf(WaterKind kind) => switch (kind) {
        WaterKind.clear => _r.d('reflAlpha'),
        WaterKind.murky => _r.d('reflMurkyAlpha'),
        WaterKind.cave => _r.d('reflCaveAlpha'),
        WaterKind.none => 0,
      };

  /// Sideways offset (integer px) of the strip at world row [y] (px) at
  /// time [t] (s): a slow sine of amplitude `reflWaveAmp`.
  static int wave(double y, double t, {double extra = 0}) {
    final amp = _r.d('reflWaveAmp') + extra;
    if (amp <= 0) return 0;
    final rows = math.max(1.0, _r.d('reflWaveRows'));
    final ph = y / rows * 2 * math.pi + t * _r.d('reflWaveSpeed');
    // Square-ish wave: integer steps, never sub-pixel.
    return (math.sin(ph) * (amp + 0.49)).round().clamp(-amp.ceil(), amp.ceil());
  }

  /// Extra amplitude (px) of the wake of an actor at distance [d] (px):
  /// full inside half the radius, one step less outside, none beyond.
  static double wake(double d) {
    final r = _r.d('reflWakeRadius');
    if (d >= r) return 0;
    final a = _r.d('reflWakeAmp');
    return d < r / 2 ? a : (a - 1).clamp(0.0, a);
  }

  /// Fade step (0 = full, 1, 2) of a reflected pixel [d] px below its
  /// water line.
  static int fadeStep(double d) {
    if (d < _r.d('reflFade1')) return 0;
    if (d < _r.d('reflFade2')) return 1;
    return 2;
  }

  /// Blend toward the water colour of each fade step.
  static const fadeBlend = [0.0, 0.28, 0.55];

  /// Water line (px) under the foot (x, y) px: the top of the first water
  /// tile at or below the foot within `reflActorReach` tiles; the foot
  /// itself when it stands on water. `null` = too far from water.
  static double? anchor(double x, double y, WaterKind Function(int, int) at) {
    const ts = 16.0;
    final tx = (x / ts).floor(), ty = (y / ts).floor();
    if (at(tx, ty) != WaterKind.none) return y;
    final reach = _r.i('reflActorReach');
    for (var d = 1; d <= reach; d++) {
      if (at(tx, ty + d) != WaterKind.none) return (ty + d) * ts;
    }
    return null;
  }

  /// Water line (px) and opacity factor (0..1) of an actor whose foot is
  /// at (x, y) px (§ 1.1). The factor is a smoothstep of the continuous
  /// foot-to-water gap: 1 on the edge, 0 at `reflActorReach` +
  /// `reflActorFadeTiles` tiles, so the reflection never pops. `null` =
  /// no water within that distance.
  static (double, double)? actorLine(
      double x, double y, WaterKind Function(int, int) at) {
    const ts = 16.0;
    final tx = (x / ts).floor(), ty = (y / ts).floor();
    if (at(tx, ty) != WaterKind.none) return (y, 1.0);
    final far = _r.d('reflActorReach') + _r.d('reflActorFadeTiles');
    final steps = far.ceil();
    for (var d = 1; d <= steps; d++) {
      if (at(tx, ty + d) != WaterKind.none) {
        final line = (ty + d) * ts;
        final a = actorFade((line - y) / ts);
        return a <= 0 ? null : (line, a);
      }
    }
    return null;
  }

  /// Opacity factor of an actor reflection whose foot is [gap] tiles
  /// above the water line: 1 at 0, smoothstep down to 0 at
  /// `reflActorReach` + `reflActorFadeTiles`.
  static double actorFade(double gap) {
    final far = _r.d('reflActorReach') + _r.d('reflActorFadeTiles');
    if (far <= 0) return gap <= 0 ? 1 : 0;
    final u = (gap / far).clamp(0.0, 1.0);
    return 1 - u * u * (3 - 2 * u);
  }

  /// Indices of the [all] candidates to reflect: at most [cap], the
  /// nearest to the view center (cx, cy).
  static List<int> pick(
      List<ReflectionCandidate> all, double cx, double cy, int cap) {
    final idx = List<int>.generate(all.length, (i) => i);
    if (idx.length <= cap) return idx;
    double d(int i) {
      final dx = all[i].x - cx, dy = all[i].y - cy;
      return dx * dx + dy * dy;
    }

    idx.sort((a, b) => d(a).compareTo(d(b)));
    return idx.sublist(0, math.max(0, cap));
  }

  /// Actor cap per quality.
  static int actorCap({required bool high}) =>
      _r.i(high ? 'reflActorsHigh' : 'reflActorsLow');

  /// Sky colour reflected at a [darkness] (0 day .. 1 night), as RGB
  /// 0..255: day blue, a warm orange around the change, night navy.
  static (int, int, int) sky(double darkness) {
    final dusk = (1 - (2 * darkness - 1).abs()).clamp(0.0, 1.0);
    final night = darkness.clamp(0.0, 1.0);
    int mix(int a, int b, int c) =>
        (a * (1 - night) * (1 - dusk) + b * dusk + c * night * (1 - dusk))
            .round()
            .clamp(0, 255);
    return (mix(150, 255, 18), mix(205, 150, 26), mix(240, 140, 60));
  }

  /// The compact glow a light leaves on the water (§ 1.4): 2-4 short
  /// horizontal dashes under its mirrored point, as (row offset px,
  /// width px, fade step 0 bright .. 2 faint). At most `reflGlowLen` px
  /// long; dashes blink with [t] (s), stable per light [seed].
  static List<(int, int, int)> glowDashes(int seed, double t) {
    final len = math.max(2, _r.i('reflGlowLen'));
    final out = <(int, int, int)>[];
    final tick = (t * 5).floor();
    for (var i = 0; i < 4; i++) {
      final dy = 1 + i * 3 + (_hash(i, seed) % 2);
      if (dy >= len) break;
      final n = _hash(i * 7 + tick, seed);
      if (i > 1 && n % 3 == 0) continue; // broken by the ripple
      final w = math.max(1, 6 - i * 2 + (n % 2) * 2 - (n >> 3) % 2);
      out.add((dy, w, i == 0 ? 0 : (i < 3 ? 1 : 2)));
    }
    return out;
  }

  /// Water line drop (px) under an actor afloat: its reflection reads
  /// below the raft, not hidden under it.
  static double floatDrop() => _r.d('reflFloatDrop');

  /// Warm pink/orange added on the water surface at sunset / sunrise
  /// (0 outside): alpha for a [darkness].
  static double duskTint(double darkness) =>
      _r.d('reflDuskTint') * (1 - (2 * darkness - 1).abs()).clamp(0.0, 1.0);

  /// Star glints visible on [visibleTiles] water tiles at time [t]:
  /// stable positions (indices into the tiles) that twinkle.
  static List<int> stars(int visibleTiles, double t, {required bool high}) {
    if (!high || visibleTiles == 0) return const [];
    final n = _r.i('reflStars');
    final out = <int>[];
    for (var i = 0; i < n; i++) {
      final h = _hash(i, 977);
      if (((t * 1.5).floor() + i) % 4 == 0) continue; // blink
      out.add(h % visibleTiles);
    }
    return out;
  }

  static int _hash(int a, int b) {
    var h = (a * 374761393 + b * 668265263) & 0x7fffffff;
    h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
    return h ^ (h >> 16);
  }
}
