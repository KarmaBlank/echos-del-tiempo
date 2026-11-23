// Captura de los cultivos en la huerta (v0.24.6). NO es parte de la suite.
// Correr con
//   flutter test tool/shots/v0246_cultivos_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/farm_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_themes.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('huerta con los 11 cultivos', () async {
    const scale = 6.0, cols = 5;
    final ids = kCrops.keys.toList();
    const stages = [0.05, 0.3, 0.7, 1.0, 1.0];
    const w = (cols + 1) * MapFarmLayer.ts * scale;
    final h = (ids.length + 1) * MapFarmLayer.ts * scale;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = FarmPalette.soil);
    c.scale(scale);
    final layer = MapFarmLayer();
    for (var row = 0; row < ids.length; row++) {
      final id = ids[row];
      for (var col = 0; col < cols; col++) {
        final p = FarmPlot(
            seed: id,
            grow: FarmingRules.growSec(id) * stages[col],
            planter: 'p$col');
        layer.drawPlot(c, p, col, row + 1, col == 4 ? 300 : 0);
      }
    }
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('docs/release_shots/v0.24.6/huerta_cultivos.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}
