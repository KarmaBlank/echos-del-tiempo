import 'package:echos_del_tiempo/app/feature_flags.dart';
import 'package:echos_del_tiempo/core/perf/frame_stats.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:flutter/rendering.dart' show OffsetLayer;
import 'package:flutter_test/flutter_test.dart';

import '../features/world/world_test_helpers.dart';
import '../real_fonts.dart';
import 'overworld_perf_test.dart' show pumpField;

/// Battle performance harness: the real `WorldScreen` in a fight. The
/// map (`MapGame`) stays mounted under the battle, fully covered by it;
/// it must not draw the world (tiles, lighting, actors) every frame
/// behind an opaque scene. Prints map render, whole-frame pump and
/// rasterization times (JIT: for before / after comparison only).
///
/// `flutter test test/perf/battle_perf_test.dart` prints the table.
void main() {
  setUpAll(() => FeatureFlags.instance = const FeatureFlags(soloParty: true));
  tearDownAll(() => FeatureFlags.instance = const FeatureFlags());
  setUpAll(loadRealFonts);

  testWidgets('battle: frame profile', (tester) async {
    final c = await pumpField(tester, keepEnemies: true);
    startBattleWithFirstGroup(c);
    await tester.pump();
    expect(c.view!.mode, SessionMode.battle);

    final render = <int>[];
    MapGame.debugRenderTiming = render.add;
    addTearDown(() => MapGame.debugRenderTiming = null);
    final pump = <int>[];
    for (var i = 0; i < 300; i++) {
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(microseconds: 16667));
      if (i >= 60) pump.add(sw.elapsedMicroseconds);
    }
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final raster = <int>[];
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(microseconds: 16667));
      await tester.runAsync(() async {
        final sw = Stopwatch()..start();
        final img = await layer.toImage(Offset.zero & size);
        raster.add(sw.elapsedMicroseconds);
        img.dispose();
      });
    }
    final r = FrameStats(render), p = FrameStats(pump), x = FrameStats(raster);
    // ignore: avoid_print
    print('\n=== Battle ===\n'
        '  map render calls: ${render.length}'
        '${render.isEmpty ? '' : ' · ${r.summary}'}\n'
        '  frame (pump): ${p.summary} (mean ${p.mean.toStringAsFixed(2)})\n'
        '  raster: ${x.summary} (mean ${x.mean.toStringAsFixed(2)})');
    // The map under the battle draws only a cheap clear, never the world.
    if (render.isNotEmpty) {
      expect(FrameStats(render).mean, lessThan(0.5));
    }
    expect(c.view!.mode, SessionMode.battle);
    expect(tester.takeException(), isNull);
  });
}
