import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel-snapped camera follow (exploration.md § Cámara): a constant-speed
/// walk moves the drawn camera and the hero's screen spot without
/// back-and-forth steps, at any frame rate.
void main() {
  for (final fps in [60, 75, 144]) {
    test('steady walk at $fps fps: monotonic camera, no hero wobble', () {
      final dt = 1 / fps;
      const speed = 70.0; // px/s
      var x = 100.0, cam = x - 160;
      var lastCam = cam.roundToDouble();
      final offsets = <double>[];
      for (var i = 0; i < fps * 4; i++) {
        x += speed * dt;
        final tx = x - 160;
        cam += (tx - cam) * MapGame.smoothing(0.25, dt);
        final d = cam.roundToDouble();
        expect(d, d.roundToDouble());
        expect(d, greaterThanOrEqualTo(lastCam), reason: 'frame $i');
        lastCam = d;
        final hero = MapGame.snapFocus(x, cam);
        expect((hero - x).abs(), lessThanOrEqualTo(1));
        offsets.add(hero - d);
      }
      // After settling the hero keeps one screen spot (the steady lag).
      for (var i = 1; i < offsets.length; i++) {
        expect(offsets[i], greaterThanOrEqualTo(offsets[i - 1]));
      }
      final tail = offsets.sublist(offsets.length ~/ 2);
      expect(tail.toSet().length, lessThanOrEqualTo(2));
    });
  }
}