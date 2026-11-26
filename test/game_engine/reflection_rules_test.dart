import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/reflection_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// docs/specs/water_reflections.md § 1–2.
void main() {
  final r = kTuning[TuningId.regions]!;

  test('water kinds: lava and land never reflect, roofs only lights', () {
    expect(ReflectionRules.kindOf(Tile.lava, 'grieta', roofed: false),
        WaterKind.none);
    expect(ReflectionRules.kindOf(Tile.grass, 'pradera', roofed: false),
        WaterKind.none);
    expect(ReflectionRules.kindOf(Tile.water, 'pradera', roofed: false),
        WaterKind.clear);
    expect(ReflectionRules.kindOf(Tile.fishing, 'bosque', roofed: false),
        WaterKind.murky);
    expect(ReflectionRules.kindOf(Tile.water, 'pradera', roofed: true),
        WaterKind.cave);
    expect(ReflectionRules.alphaOf(WaterKind.cave), greaterThan(0));
    expect(ReflectionRules.alphaOf(WaterKind.cave),
        lessThan(ReflectionRules.alphaOf(WaterKind.clear)));
    expect(ReflectionRules.alphaOf(WaterKind.murky),
        lessThan(ReflectionRules.alphaOf(WaterKind.clear)));
  });

  test('the wave moves whole pixels within the amplitude', () {
    final amp = r.d('reflWaveAmp').ceil();
    final seen = <int>{};
    for (var y = 0; y < 64; y++) {
      for (var t = 0.0; t < 6; t += 0.37) {
        final w = ReflectionRules.wave(y.toDouble(), t);
        expect(w.abs(), lessThanOrEqualTo(amp));
        seen.add(w);
      }
    }
    expect(seen.length, greaterThan(1), reason: 'it actually ripples');
    final wake = ReflectionRules.wake(0);
    expect(wake, r.d('reflWakeAmp'));
    expect(ReflectionRules.wake(r.d('reflWakeRadius')), 0);
    for (var t = 0.0; t < 3; t += 0.2) {
      expect(ReflectionRules.wave(5, t, extra: wake).abs(),
          lessThanOrEqualTo(amp + wake.ceil()));
    }
  });

  test('fade in three discrete steps', () {
    expect(ReflectionRules.fadeStep(0), 0);
    expect(ReflectionRules.fadeStep(r.d('reflFade1')), 1);
    expect(ReflectionRules.fadeStep(r.d('reflFade2')), 2);
    expect(ReflectionRules.fadeStep(200), 2);
    expect(ReflectionRules.fadeBlend, hasLength(3));
  });

  test('anchor: water line under the foot within reach, foot on water', () {
    // Column 2: land rows 0-2, water from row 3.
    WaterKind at(int x, int y) =>
        y >= 3 ? WaterKind.clear : WaterKind.none;
    expect(ReflectionRules.anchor(40, 40, at), 48); // row 2 -> line 48
    expect(ReflectionRules.anchor(40, 60, at), 60); // on water
    final reach = r.i('reflActorReach');
    expect(ReflectionRules.anchor(40, (3 - reach - 1) * 16 + 4, at), isNull);
  });

  test('actor fade: 1 at the edge, smooth and monotonic down to 0', () {
    final far = r.d('reflActorReach') + r.d('reflActorFadeTiles');
    expect(ReflectionRules.actorFade(0), 1);
    expect(ReflectionRules.actorFade(far), 0);
    expect(ReflectionRules.actorFade(far + 3), 0);
    var prev = 1.0;
    for (var g = 0.0; g <= far + 0.5; g += 1 / 16) {
      final a = ReflectionRules.actorFade(g);
      expect(a, lessThanOrEqualTo(prev));
      expect(prev - a, lessThan(0.15), reason: 'no pop at gap $g');
      prev = a;
    }
    // Continuous foot position: walking 1 px never jumps the opacity.
    WaterKind at(int x, int y) => y >= 3 ? WaterKind.clear : WaterKind.none;
    double fadeAt(double y) => ReflectionRules.actorLine(40, y, at)?.$2 ?? 0;
    for (var y = 0.0; y < 47; y += 1) {
      expect((fadeAt(y + 1) - fadeAt(y)).abs(), lessThan(0.15));
      expect(fadeAt(y + 1), greaterThanOrEqualTo(fadeAt(y)));
    }
    expect(fadeAt(48), 1);
  });

  test('actor cap keeps the nearest to the view center', () {
    final all = <ReflectionCandidate>[
      for (var i = 0; i < 30; i++) (x: i * 10.0, y: 0, moving: false),
    ];
    final p = ReflectionRules.pick(all, 0, 0, 5);
    expect(p, [0, 1, 2, 3, 4]);
    expect(ReflectionRules.pick(all.sublist(0, 3), 0, 0, 5), hasLength(3));
    expect(ReflectionRules.actorCap(high: false),
        lessThan(ReflectionRules.actorCap(high: true)));
  });

  test('sky: blue by day, warm at dusk, dark at night', () {
    final (dr, _, db) = ReflectionRules.sky(0);
    final (sr, _, sb) = ReflectionRules.sky(0.5);
    final (nr, ng, nb) = ReflectionRules.sky(1);
    expect(db, greaterThan(dr));
    expect(sr, greaterThan(sb));
    expect(nr + ng + nb, lessThan(150));
  });

  test('light glow: 2-4 short dashes, at most one tile, hard steps', () {
    final len = r.i('reflGlowLen');
    expect(len, lessThanOrEqualTo(16));
    for (var t = 0.0; t < 4; t += 0.13) {
      final d = ReflectionRules.glowDashes(7, t);
      expect(d.length, inInclusiveRange(2, 4));
      for (final (dy, w, step) in d) {
        expect(dy, lessThan(len));
        expect(w, inInclusiveRange(1, 8));
        expect(step, inInclusiveRange(0, 2));
      }
    }
    expect(ReflectionRules.floatDrop(), greaterThanOrEqualTo(0));
    expect(ReflectionRules.duskTint(0), 0);
    expect(ReflectionRules.duskTint(1), 0);
    expect(ReflectionRules.duskTint(0.5), greaterThan(0));
    expect(ReflectionRules.stars(0, 1, high: true), isEmpty);
    expect(ReflectionRules.stars(50, 1, high: false), isEmpty);
    for (final s in ReflectionRules.stars(50, 1, high: true)) {
      expect(s, inInclusiveRange(0, 49));
    }
  });
}
