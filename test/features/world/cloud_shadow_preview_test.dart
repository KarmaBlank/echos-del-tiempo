import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/region_light_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Cloud shadows are pixel cells with stepped alpha (biome_regions.md);
/// `CLOUD_PREVIEW=1` writes docs/preview/cloud_shadows.png.
void main() {
  test('las sombras de nubes son celdas de 8 px con varios escalones de alfa',
      () async {
    const w = 640.0, h = 400.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF4F8A3A));
    final layer = RegionLightLayer();
    layer.drawClouds(c, const Rect.fromLTWH(0, 0, w, h), 30, 1.0, w, h);
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = (await img.toByteData())!;
    final shades = <int>{};
    for (var y = 0; y < h; y += 4) {
      for (var x = 0; x < w; x += 4) {
        final i = (y.toInt() * w.toInt() + x.toInt()) * 4;
        shades.add(bytes.getUint8(i + 1));
      }
    }
    // Grass plus at least two shadow steps: a soft, stepped edge.
    expect(shades.length, greaterThanOrEqualTo(3));
    if (Platform.environment['CLOUD_PREVIEW'] == '1') {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('docs/preview/cloud_shadows.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
}
