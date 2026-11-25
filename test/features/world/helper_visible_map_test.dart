import 'dart:ui' as ui;

import 'package:echos_del_tiempo/game_engine/models/town_build.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fishing_map_harness.dart';

/// "No se ven los ayudantes": a hired farm helper must paint pixels on
/// the real town map (MapGame.render), not only on the farm layer.
void main() {
  testWidgets('hired farm helper is visible on the town map', (tester) async {
    final h = await FishingMapHarness.pump(tester);
    final c = h.c;
    final farm = c.town.builds.firstWhere((b) => b.kind == BuildKind.huerta);
    final pos = TownRules.helperPos(c.town, farm, 0, c.session!.time);
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(pos.x + 40, pos.y);
    await h.frames(10);

    Future<ui.Image> shot() async {
      final rec = ui.PictureRecorder();
      h.game.render(ui.Canvas(rec));
      final sz = h.game.size;
      return tester
          .runAsync(
              () => rec.endRecording().toImage(sz.x.toInt(), sz.y.toInt()))
          .then((i) => i!);
    }

    Future<List<int>> bytes(ui.Image im) async =>
        (await tester.runAsync(() => im.toByteData()))!.buffer.asUint8List();

    void hire(int n) {
      // ignore: invalid_use_of_visible_for_testing_member
      c.debugTown((t) => t.copyWith(builds: [
            for (final b in t.builds)
              b.id == farm.id
                  ? b.copyWith(helper: n, plots: {
                      for (var x = 0; x < 4; x++)
                        for (var y = 0; y < 3; y++) '$x,$y': FarmingRules.till()
                    })
                  : b
          ]));
    }

    int count(List<int> a, List<int> b) {
      var d = 0;
      for (var i = 0; i < a.length; i += 4) {
        if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) d++;
      }
      return d;
    }

    hire(0);
    await h.frames(2);
    final a = await bytes(await shot());
    hire(1);
    final im = await shot();
    final b = await bytes(im);
    final diff = count(a, b);
    expect(diff, greaterThan(40), reason: 'helper painted no pixels');
  });
}
