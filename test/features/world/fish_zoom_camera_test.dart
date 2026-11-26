import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/game_engine/rules/cozy_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fishing zoom (cozy_life.md § 1, exploration.md § Cámara): the
/// player stays still on screen while the world zooms, at any frame rate.
void main() {
  /// Runs the zoom in for [sec] at [fps]; returns the player's screen x
  /// (virtual px) of every frame and the final zoom.
  (List<double>, double) run(double fps, double sec) {
    const v = MapGame.vw * 1.0;
    const focus = 1000.3; // a fractional player position
    var cam = focus - v / 2; // centered before fishing
    var p = 0.0, z = 1.0;
    final xs = <double>[];
    final dt = 1 / fps;
    for (var i = 0; i < (sec * fps).round(); i++) {
      p = CozyRules.fishZoomStep(p, fishing: true, dt: dt);
      final z1 = CozyRules.fishZoomAt(p);
      cam = MapGame.zoomRecenter(cam, v, z, z1);
      z = z1;
      final zooming = p > 0 && p < 1;
      final camDraw = zooming ? cam : cam.roundToDouble();
      final hero = MapGame.heroDraw(focus, cam, zooming: zooming);
      if (zooming) xs.add((hero - camDraw) / z);
    }
    return (xs, z);
  }

  test('the player keeps its screen spot through the zoom', () {
    for (final fps in [30.0, 60.0, 144.0]) {
      final (xs, _) = run(fps, CozyRules.fishZoomSec);
      for (final x in xs) {
        expect((x - MapGame.vw / 2).abs(), lessThanOrEqualTo(0.5 + 1e-9),
            reason: '$fps fps');
      }
    }
  });

  test('the zoom does not depend on the frame rate', () {
    final a = run(30, CozyRules.fishZoomSec / 2).$2;
    final b = run(144, CozyRules.fishZoomSec / 2).$2;
    expect((a - b).abs(), lessThan(0.01));
    expect(run(60, CozyRules.fishZoomSec + 0.1).$2,
        closeTo(CozyRules.fishZoom, 1e-9));
  });

  test('the hero snaps only once the zoom settles', () {
    expect(MapGame.heroDraw(10.3, 2.6, zooming: true), 10.3);
    expect(MapGame.heroDraw(10.3, 2.6, zooming: false),
        MapGame.snapFocus(10.3, 2.6));
  });
}
