import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/farm_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_themes.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Watered soil must read clearly apart from dry tilled soil
/// (farming.md § 2.3). `PREVIEW=1` writes docs/preview/wet_soil/.
void main() {
  const ts = MapFarmLayer.ts;
  const crop = 'nabo_claro';
  final grow = FarmingRules.growSec(crop);
  // Untilled, tilled dry, tilled watered, seeded dry, seeded watered,
  // grown watered.
  final cells = <FarmPlot?>[
    null,
    const FarmPlot(),
    const FarmPlot(wet: 100),
    const FarmPlot(seed: crop),
    const FarmPlot(seed: crop, wet: 100),
    FarmPlot(seed: crop, grow: grow * 0.7, wet: 100),
  ];

  Future<ui.Image> render({required bool night, int scale = 6}) async {
    const base = TownState();
    final farm = base.builds.firstWhere((b) => b.kind == BuildKind.huerta);
    final local = <String, FarmPlot>{
      for (var i = 0; i < cells.length; i++)
        if (cells[i] != null) plotKey(i * 2, 0): cells[i]!,
    };
    final town = base.copyWith(builds: [
      for (final b in base.builds)
        b.id == farm.id ? b.copyWith(plots: local) : b
    ]);
    final (ox, oy) = (farm.anchor.$1 + town.origin.$1,
        farm.anchor.$2 + town.origin.$2);
    final w = cells.length * 2 + 1, h = 3;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(scale.toDouble());
    c.drawRect(Rect.fromLTWH(0, 0, w * ts, h * ts),
        Paint()..color = kMapThemes['pradera']!.ground);
    c.save();
    c.translate((1 - ox) * ts, (1 - oy) * ts);
    MapFarmLayer().drawPlots(
        c, town, Rect.fromLTWH(ox * ts - ts, oy * ts - ts, w * ts, h * ts), 0);
    c.restore();
    if (night) {
      c.drawRect(Rect.fromLTWH(0, 0, w * ts, h * ts),
          Paint()..color = const Color(0x990A1030));
    }
    return rec
        .endRecording()
        .toImage((w * ts * scale).toInt(), (h * ts * scale).toInt());
  }

  int lum(ByteData b, int width, int x, int y) {
    final i = (y * width + x) * 4;
    return b.getUint8(i) + b.getUint8(i + 1) + b.getUint8(i + 2);
  }

  test('watered soil is clearly darker than dry tilled soil', () async {
    final img = await render(night: false, scale: 1);
    final b = (await img.toByteData())!;
    // Soil pixel between furrows of tilled dry (cell 1) vs watered (cell 2).
    final dry = lum(b, img.width, 3 * 16 + 7, 16 + 9);
    final wet = lum(b, img.width, 5 * 16 + 7, 16 + 9);
    expect(dry - wet, greaterThan(90));
    if (Platform.environment['PREVIEW'] == '1') {
      for (final night in [false, true]) {
        final big = await render(night: night);
        final png = await big.toByteData(format: ui.ImageByteFormat.png);
        File('docs/preview/wet_soil/wet_soil_${night ? 'night' : 'day'}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      }
    }
  });
}
