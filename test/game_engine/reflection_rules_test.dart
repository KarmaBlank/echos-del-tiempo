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
    expect(ReflectionRules.alphaOf(WaterKind.cave), 0);
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

  test('light streak: dashes, wider near the light, ends at its length', () {
    final len = r.i('reflStreakLen');
    var gaps = 0;
    for (var i = 0; i < len; i++) {
      final w = ReflectionRules.streakWidth(i, 7, 1.3);
      expect(w, inInclusiveRange(0, 3));
      if (w == 0) gaps++;
    }
    expect(gaps, greaterThan(0));
    expect(ReflectionRules.streakWidth(len, 7, 1.3), 0);
    expect(ReflectionRules.stars(0, 1, high: true), isEmpty);
    expect(ReflectionRules.stars(50, 1, high: false), isEmpty);
    for (final s in ReflectionRules.stars(50, 1, high: true)) {
      expect(s, inInclusiveRange(0, 49));
    }
  });
}
