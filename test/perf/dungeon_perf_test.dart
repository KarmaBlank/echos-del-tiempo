import 'package:echos_del_tiempo/app/feature_flags.dart';
import 'package:echos_del_tiempo/core/perf/frame_stats.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:flutter/rendering.dart' show OffsetLayer;
import 'package:flutter_test/flutter_test.dart';

import '../real_fonts.dart';
import 'overworld_perf_test.dart' show pumpField;

/// Dungeon field profile (exploration.md § "Rendimiento"): the lava rift
/// zone (animated lava tiles, embers) with the darkness layer forced on,
/// and the dark caverns, with enemies around. Prints map render, whole
/// frame (`pump`) and CPU rasterize times (JIT: compare before / after).
void main() {
  setUpAll(() => FeatureFlags.instance = const FeatureFlags(soloParty: true));
  tearDownAll(() => FeatureFlags.instance = const FeatureFlags());
  setUpAll(loadRealFonts);

  for (final (zone, name, dark) in [
    (7, 'rift (lava)', false),
    (7, 'rift (lava), dark', true),
    (4, 'caverns (dark)', false),
  ]) {
    testWidgets('dungeon perf: $name', (tester) async {
      MapGame.debugForceDark = dark;
      addTearDown(() {
        MapGame.debugForceDark = false;
        MapGame.debugRenderTiming = null;
      });
      var dir = (0.0, 0.0);
      final c = await pumpField(tester,
          input: () => dir, keepEnemies: true, zone: zone);
      // Enemies nearby would start a battle: keep only the far ones.
      c.session!.mission!.enemies.removeWhere((e) {
        final dx = e.x - c.local.x, dy = e.y - c.local.y;
        return dx * dx + dy * dy < 300 * 300;
      });
      final render = <int>[], pump = <int>[];
      var on = false;
      MapGame.debugRenderTiming = (us) {
        if (on) render.add(us);
      };
      Future<void> run(int frames, (double, double) Function(int) f) async {
        for (var i = 0; i < frames; i++) {
          dir = f(i);
          if (i % 3 == 0) c.advance(0.05);
          final sw = Stopwatch()..start();
          await tester.pump(const Duration(microseconds: 16667));
          if (on) pump.add(sw.elapsedMicroseconds);
        }
      }

      await run(60, (_) => (0, 0));
      on = true;
      await run(180, (_) => (0, 0));
      await run(
          240,
          (i) => switch ((i ~/ 60) % 4) {
                0 => (1.0, 0.0),
                1 => (0.0, 1.0),
                2 => (-1.0, 0.0),
                _ => (0.0, -1.0),
              });
      on = false;
      final layer =
          tester.binding.renderViews.first.debugLayer! as OffsetLayer;
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final ras = <double>[];
      for (var i = 0; i < 25; i++) {
        if (i % 3 == 0) c.advance(0.05);
        await tester.pump(const Duration(microseconds: 16667));
        await tester.runAsync(() async {
          final sw = Stopwatch()..start();
          final img = await layer.toImage(Offset.zero & size);
          img.dispose();
          if (i >= 5) ras.add(sw.elapsedMicroseconds / 1000);
        });
      }
      ras.sort();
      final r = FrameStats(render), p = FrameStats(pump);
      // ignore: avoid_print
      print('\n=== Dungeon: $name (${c.view!.mode.name}) ===\n'
          '  render: ${r.summary} (mean ${r.mean.toStringAsFixed(2)})\n'
          '  pump:   ${p.summary} (mean ${p.mean.toStringAsFixed(2)})\n'
          '  raster: p50 ${ras[ras.length ~/ 2].toStringAsFixed(2)}'
          ' · p90 ${ras[(ras.length * .9).floor()].toStringAsFixed(2)} ms');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 30));
    });
  }
}
