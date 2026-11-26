import 'package:echos_del_tiempo/game_engine/rules/cozy_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fishing zoom is eased and frame-rate independent (cozy_life.md § 1).
void main() {
  double run(int fps, {required bool fishing, double p = 0}) {
    final dt = 1 / fps;
    for (var i = 0; i < fps * CozyRules.fishZoomSec * 0.5; i++) {
      p = CozyRules.fishZoomStep(p, fishing: fishing, dt: dt);
    }
    return p;
  }

  test('same progress at 30, 60 and 144 fps', () {
    final a = run(60, fishing: true), b = run(144, fishing: true);
    expect(a, closeTo(b, 0.02));
    expect(run(30, fishing: true), closeTo(a, 0.02));
  });

  test('zoom in and out are monotonic and settle exactly', () {
    var p = 0.0, last = CozyRules.fishZoomAt(0);
    expect(last, 1);
    for (var i = 0; i < 120; i++) {
      p = CozyRules.fishZoomStep(p, fishing: true, dt: 1 / 60);
      final z = CozyRules.fishZoomAt(p);
      expect(z, lessThanOrEqualTo(last));
      last = z;
    }
    expect(last, CozyRules.fishZoom);
    for (var i = 0; i < 120; i++) {
      p = CozyRules.fishZoomStep(p, fishing: false, dt: 1 / 60);
      final z = CozyRules.fishZoomAt(p);
      expect(z, greaterThanOrEqualTo(last));
      last = z;
    }
    expect(last, 1);
  });
}
