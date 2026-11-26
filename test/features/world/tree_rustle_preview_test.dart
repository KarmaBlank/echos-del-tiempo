import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tree_rustle_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/cozy_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Preview of the searchable trees (docs/specs/cozy_life.md § 3), written
/// to docs/preview/tree_rustle.png with
/// `TREE_PREVIEW=1 flutter test <this file>`.
final _on = Platform.environment['TREE_PREVIEW'] != null;

void main() {
  testWidgets('preview: árboles buscables', (tester) async {
    final lay = biomeLayout(kBosque)!;
    final map = MapGenerator.biome(lay);
    // A view centred on the first searchable tree of day 1.
    var at = (map.width ~/ 2, map.height ~/ 2);
    outer:
    for (var y = 6; y < map.height - 6; y++) {
      for (var x = 10; x < map.width - 10; x++) {
        if (CozyRules.searchable(map, lay.id, 1, x, y)) {
          at = (x, y);
          break outer;
        }
      }
    }
    const w = 320.0, h = 200.0, scale = 3.0;
    final view = Rect.fromCenter(
        center: Offset(at.$1 * 16.0, at.$2 * 16.0), width: w, height: h);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale)
      ..translate(-view.left, -view.top);
    final tiles = TilePainter();
    final x0 = (view.left / 16).floor(), y0 = (view.top / 16).floor();
    final x1 = (view.right / 16).ceil(), y1 = (view.bottom / 16).ceil();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!map.contains(x, y)) continue;
        tiles.draw(c, map.tileAt(x, y), x * 16.0, y * 16.0, map.theme, x, y,
            t: 1000, gateOpen: false, lobby: true);
      }
    }
    final layer = TreeRustleLayer();
    layer.draw(c, map, lay.id, 1, x0, y0, x1, y1, 1.3,
        searched: (_, __) => false);
    expect(layer.lastDrawn, greaterThan(0));
    final pic = rec.endRecording();
    if (!_on) {
      pic.dispose();
      return;
    }
    await tester.runAsync(() async {
      final img = await pic.toImage((w * scale).round(), (h * scale).round());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('docs/preview/tree_rustle.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
