import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/settings/graphics.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/water_reflection_layer.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/world/reflection_scene.dart';

/// Cost of the water reflections (docs/specs/water_reflections.md § 5): a
/// view filled by a lake, 24 actors on its shore and on it (cap 16),
/// trees, rocks, lamps and a waystone on the shore, clouds and 12 night
/// lights. Prints the per-frame CPU cost of recording a frame with and
/// without the reflections (JIT: to compare, not absolute) and the cost
/// of building the window.
void main() {
  test('reflejos: lago lleno de actores, orilla, nubes y luces', () {
    final map = reflectionLake(w: 64, h: 40, rx: 24, ry: 13);
    final tiles = TilePainter();
    final actors = lakeActors(map, 24, raft: true);
    final lights = <ReflectedLight>[
      for (var y = 0; y < map.height; y++)
        for (var x = 0; x < map.width; x++)
          if (map.tileAt(x, y) == Tile.lanternLit)
            (x: x * 16 + 8.0, y: y * 16 + 4.0, color: const Color(0xFFFFD9A0)),
    ].take(12).toList();
    final top = waterTop(map, map.width ~/ 2)!;
    // 480 × 270 virtual canvas at zoom 1.5: 720 × 405 world px.
    Rect view(int f) =>
        Rect.fromLTWH(map.width * 8 - 360 + (f % 40) * 0.5, top - 60, 720, 405);
    const field = Size(64 * 16, 40 * 16);

    double run(WaterReflectionLayer? layer, int frames, {double dark = 1}) {
      final sw = Stopwatch()..start();
      for (var f = 0; f < frames; f++) {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        final v = view(f);
        layer?.draw(c, map, v,
            t: f / 60,
            darkness: dark,
            cover: 1,
            field: field,
            actors: actors,
            roofed: (_, __) => false);
        for (final a in actors) {
          a.draw(c);
        }
        layer?.drawLights(c, v, lights: lights, t: f / 60, darkness: dark);
        rec.endRecording().dispose();
      }
      return sw.elapsedMicroseconds / frames;
    }

    final warm = reflectionLayer(tiles);
    run(warm, 30);
    run(null, 30);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      final l = reflectionLayer(tiles);
      run(l, 1);
      l.dispose();
    }
    final build = sw.elapsedMicroseconds / 10;
    const frames = 300;
    final base = run(null, frames);
    final hi = reflectionLayer(tiles);
    final high = run(hi, frames);
    final lo = reflectionLayer(tiles)..level = ReflectionLevel.low;
    final low = run(lo, frames);
    final dl = reflectionLayer(tiles);
    final day = run(dl, frames, dark: 0);
    String ms(double us) => (us / 1000).toStringAsFixed(3);
    // UI thread = everything but turning the frame picture into an image
    // (software raster in tests, GPU raster thread in the app).
    double uiCost(WaterReflectionLayer l, double total) =>
        total - l.imageMicros / frames;
    // ignore: avoid_print
    print('reflejos (por cuadro): sin ${ms(base)} ms; '
        'ALTA ${ms(high)} ms = UI ${ms(uiCost(hi, high))} + imagen ${ms(hi.imageMicros / frames)} '
        '(${hi.lastActors} actores, ${hi.lastStrips} tiras); '
        'BAJA ${ms(low)} ms = UI ${ms(uiCost(lo, low))} + imagen ${ms(lo.imageMicros / frames)} '
        '(${lo.lastStrips} tiras); '
        'día ALTA ${ms(day)} ms = UI ${ms(uiCost(dl, day))}; '
        'ventana nueva ${ms(build)} ms; ventanas armadas ${hi.windowBuilds}');
    expect(hi.windowBuilds, 1, reason: 'the camera stays in one window');
    expect(hi.lastActors, lessThanOrEqualTo(16));
    // Same budget as light_perf (< 4 ms per frame on the UI thread).
    expect(uiCost(hi, high) - base, lessThan(4000));
    expect(uiCost(dl, day) - base, lessThan(4000));
    // The software raster of the test machine, as a sanity ceiling.
    expect(high - base, lessThan(12000));
    expect(build, lessThan(16000));
  });
}
