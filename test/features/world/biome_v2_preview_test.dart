import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/region_light_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/mine_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/region_ambience_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Biome exploration v2 (docs/specs/biome_exploration.md): the player's
/// light cuts the cave darkness (always checked) and previews of whole
/// biomes and a lit cavern, written to docs/preview/biomes_v2 with
/// `BIOME_PREVIEW=1 flutter test <this file>`.
final _on = Platform.environment['BIOME_PREVIEW'] != null;

void main() {
  tearDown(() => BiomeRegions.bind(0));

  void tiles(Canvas c, BiomeLayout lay, GameMap map, Rect view) {
    final painter = TilePainter();
    final x0 = (view.left / 16).floor(), y0 = (view.top / 16).floor();
    final x1 = (view.right / 16).ceil(), y1 = (view.bottom / 16).ceil();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (!map.contains(x, y)) continue;
        final ch = map.tileAt(x, y);
        final cv = ch == Tile.floor || ch == MineTile.chest
            ? lay.isIndoor(x, y)
            : RegionAmbienceRules.caveWall(lay, map.tileAt, x, y);
        painter.draw(c, ch, x * 16.0, y * 16.0, map.theme, x, y,
            t: 1000, gateOpen: false, lobby: true, cave: cv);
      }
    }
  }

  Future<ui.Image> render(WidgetTester tester, ui.Picture pic, int w, int h) async =>
      (await tester.runAsync(() => pic.toImage(w, h)))!;

  Future<void> save(WidgetTester tester, ui.Image img, String name) async {
    await tester.runAsync(() async {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/preview/biomes_v2').createSync(recursive: true);
      File('docs/preview/biomes_v2/$name.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  /// A world whose forest has a cavern in the wilds.
  BiomeLayout cavernForest() {
    for (var seed = 0; seed < 200; seed++) {
      BiomeRegions.bind(seed);
      final lay = biomeLayout(kBosque)!;
      if (lay.caverns.isNotEmpty) return lay;
    }
    fail('no cavern in 200 seeds');
  }

  testWidgets('a carried light cuts the cave darkness', (tester) async {
    final lay = cavernForest();
    final (cx, cy, _, _) = lay.caverns.first;
    final px = cx * 16, py = cy * 16;
    const w = 200.0, h = 120.0;
    final view =
        Rect.fromCenter(center: Offset(px, py), width: w, height: h);

    /// (alpha, red) at the light's center.
    Future<(int, int)> alphaAtCenter(bool lit) async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..translate(-view.left, -view.top);
      final light = RegionLightLayer();
      light.drawCaveShade(c, lay, 1,
          view: view, lights: lit ? [(px, py, 80.0)] : const []);
      final img = await render(tester, rec.endRecording(), w.toInt(), h.toInt());
      final data = (await tester.runAsync(
          () => img.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      final i = ((h ~/ 2) * w.toInt() + w ~/ 2) * 4;
      light.dispose();
      return (data.getUint8(i + 3), data.getUint8(i));
    }

    final dark = await alphaAtCenter(false);
    final lit = await alphaAtCenter(true);
    expect(dark.$1, greaterThan(40), reason: 'the cave is dark');
    expect(lit.$1, lessThan(dark.$1), reason: 'the light cuts through');
    expect(lit.$2, greaterThan(dark.$2 + 40), reason: 'and glows warm');
  });

  testWidgets('preview: whole biomes and a lit cavern', (tester) async {
    if (!_on) return;
    BiomeRegions.bind(7);
    for (final id in [kBosque, kCavernas, kAbismo]) {
      final lay = biomeLayout(id)!;
      final map = MapGenerator.biome(lay);
      const scale = 0.5;
      const view = Rect.fromLTWH(
          0, 0, BiomeLayout.width * 16.0, BiomeLayout.height * 16.0);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(scale);
      tiles(c, lay, map, view);
      final light = RegionLightLayer()
        ..drawCaveShade(c, lay, 0.6)
        ..drawCaveLife(c, lay, 1, motion: false);
      light.drawRoofEdges(c, lay, map.tileAt);
      // Mark the waystones so they read at this scale.
      final mark = Paint()..color = const Color(0xFF48DBFB);
      for (final w in lay.waystones) {
        c.drawCircle(Offset((w.x + 0.5) * 16, (w.y + 0.5) * 16), 10, mark);
      }
      final img = await render(tester, rec.endRecording(),
          (view.width * scale).round(), (view.height * scale).round());
      await save(tester, img, 'biome_$id');
      light.dispose();
    }

    final lay = cavernForest();
    final map = MapGenerator.biome(lay);
    final (cx, cy, _, _) = lay.caverns.first;
    const w = 320.0, h = 200.0, scale = 3.0;
    final view = Rect.fromCenter(
        center: Offset(cx * 16, cy * 16), width: w, height: h);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale)
      ..translate(-view.left, -view.top);
    tiles(c, lay, map, view);
    final px = cx * 16, py = cy * 16 + 8;
    // The player (a simple marker) and the wisp's light.
    c.drawRect(Rect.fromCenter(center: Offset(px, py), width: 8, height: 12),
        Paint()..color = const Color(0xFFFFD166));
    final light = RegionLightLayer()
      ..drawCaveShade(c, lay, 0.6, view: view, lights: [(px, py, 88.0)])
      ..drawCaveLife(c, lay, 1, motion: false, view: view);
    light.drawPools(c, map, view, 1);
    if (lay.beams.isNotEmpty) {
      light.drawShafts(c, map, view, 1, only: lay.beams);
    }
    final img = await render(
        tester, rec.endRecording(), (w * scale).round(), (h * scale).round());
    await save(tester, img, 'cavern_light');
    light.dispose();
  });
}
