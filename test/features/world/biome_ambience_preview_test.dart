import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/region_light_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/vegetation_sway_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/region_ambience_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Previews of the roofed cave lake and the wind sway
/// (docs/specs/biome_regions.md § 7.2.1–7.2.2), written to
/// docs/preview/biomes with `BIOME_PREVIEW=1 flutter test <this file>`.
final _on = Platform.environment['BIOME_PREVIEW'] != null;

void main() {
  tearDown(() => BiomeRegions.bind(0));

  testWidgets('preview: gruta techada y viento', (tester) async {
    late BiomeLayout lay;
    for (var seed = 0; seed < 400; seed++) {
      BiomeRegions.bind(seed);
      lay = biomeLayout(kBosque)!;
      if (lay.skylights.isNotEmpty) break;
    }
    final map = MapGenerator.biome(lay);
    final cave = lay.lakes.firstWhere((l) => l.cave != null).ellipse;
    const w = 320.0, h = 200.0, scale = 3.0;
    final view = Rect.fromCenter(
        center: Offset(cave.$1 * 16, cave.$2 * 16), width: w, height: h);

    ui.Picture shot(double t) {
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
          final ch = map.tileAt(x, y);
          final cv = ch == Tile.floor
              ? lay.isIndoor(x, y)
              : RegionAmbienceRules.caveWall(lay, map.tileAt, x, y);
          tiles.draw(c, ch, x * 16.0, y * 16.0, map.theme, x, y,
              t: t * 1000, gateOpen: false, lobby: true, cave: cv);
        }
      }
      VegetationSwayLayer().draw(c, map, x0, y0, x1, y1, t);
      final light = RegionLightLayer();
      light.drawCaveShade(c, lay, 0.6);
      light.drawRoofEdges(c, lay, map.tileAt);
      light.drawPools(c, map, view, t);
      return rec.endRecording();
    }

    for (final (name, t) in [('cave_lake_a', 1.0), ('cave_lake_b', 4.0)]) {
      final pic = shot(t);
      if (!_on) {
        pic.dispose();
        continue;
      }
      await tester.runAsync(() async {
        final img = await pic.toImage((w * scale).round(), (h * scale).round());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('docs/preview/biomes/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });
}
