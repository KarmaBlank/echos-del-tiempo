import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/settings/graphics.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/region_light_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/reflection_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'reflection_scene.dart';

/// docs/specs/water_reflections.md § 3 and § 6.
void main() {
  void frame(void Function(Canvas c) draw) {
    final rec = ui.PictureRecorder();
    draw(Canvas(rec));
    rec.endRecording().dispose();
  }

  test('the window is built once while the camera moves inside it', () {
    final map = reflectionLake();
    final layer = reflectionLayer(TilePainter());
    final actors = lakeActors(map, 8);
    for (var i = 0; i < 20; i++) {
      final view = Rect.fromLTWH(200.0 + i, 120, 320, 180);
      frame((c) => layer.draw(c, map, view,
          t: i / 10,
          darkness: 0,
          cover: 0.6,
          field: const Size(768, 480),
          actors: actors,
          roofed: (_, __) => false));
    }
    expect(layer.windowBuilds, 1);
    expect(layer.lastStrips, greaterThan(0));
    expect(layer.lastActors, greaterThan(0));
    expect(layer.frames, 20);
    // Far away: a new window.
    frame((c) => layer.draw(c, map, const Rect.fromLTWH(0, 0, 320, 180),
        t: 0,
        darkness: 0,
        cover: 0,
        field: const Size(768, 480),
        actors: actors,
        roofed: (_, __) => false));
    expect(layer.windowBuilds, 2);
    layer.dispose();
  });

  test('no water: nothing recorded; OFF: nothing at all', () {
    final dry = GameMap(
        width: 40,
        height: 30,
        rows: List.filled(30, Tile.grass * 40),
        theme: 'bosque_ext',
        spawn: const WorldPoint(0, 0),
        lobby: true);
    final layer = reflectionLayer(TilePainter());
    frame((c) => layer.draw(c, dry, const Rect.fromLTWH(0, 0, 320, 180),
        t: 0,
        darkness: 0,
        cover: 1,
        field: const Size(640, 480),
        actors: lakeActors(dry, 4),
        roofed: (_, __) => false));
    expect(layer.frames, 0);
    expect(layer.lastStrips, 0);

    final map = reflectionLake();
    final off = reflectionLayer(TilePainter())..level = ReflectionLevel.off;
    frame((c) => off.draw(c, map, const Rect.fromLTWH(200, 120, 320, 180),
        t: 0,
        darkness: 0,
        cover: 1,
        field: const Size(768, 480),
        actors: lakeActors(map, 4),
        roofed: (_, __) => false));
    expect(off.windowBuilds, 0);
    expect(off.frames, 0);
  });

  test('low quality: fewer actors and half the strips', () {
    final map = reflectionLake();
    final actors = lakeActors(map, 30);
    const view = Rect.fromLTWH(100, 100, 560, 320);
    int strips(ReflectionLevel l, List<int> out) {
      final layer = reflectionLayer(TilePainter())..level = l;
      frame((c) => layer.draw(c, map, view,
          t: 0,
          darkness: 0,
          cover: 0,
          field: const Size(768, 480),
          actors: actors,
          roofed: (_, __) => false));
      out.add(layer.lastActors);
      return layer.lastStrips;
    }

    final hi = <int>[], lo = <int>[];
    final sh = strips(ReflectionLevel.high, hi);
    final sl = strips(ReflectionLevel.low, lo);
    expect(sl, lessThan(sh));
    expect(hi.single, lessThanOrEqualTo(ReflectionRules.actorCap(high: true)));
    expect(lo.single, ReflectionRules.actorCap(high: false));
  });

  test('cave water reflects only lights; automatic low when slow', () {
    final map = reflectionLake();
    final layer = reflectionLayer(TilePainter());
    frame((c) {
      layer.draw(c, map, const Rect.fromLTWH(200, 120, 320, 180),
          t: 0,
          darkness: 1,
          cover: 0,
          field: const Size(768, 480),
          actors: lakeActors(map, 6),
          roofed: (_, __) => true,
          sky: false);
      layer.drawLights(c, const Rect.fromLTWH(200, 120, 320, 180),
          lights: [(x: 300, y: 150, color: const Color(0xFFFFD9A0))],
          t: 0,
          darkness: 1);
    });
    expect(layer.lastStrips, 0);
    expect(layer.lastActors, 0);
    for (var i = 0; i < 200; i++) {
      layer.frameTime(60);
    }
    expect(layer.autoLow, isTrue);
    expect(layer.high, isFalse);
    for (var i = 0; i < 400; i++) {
      layer.frameTime(8);
    }
    expect(layer.autoLow, isFalse);
  });
  test('one cloud field: shadow on land, reflection on water, same cells',
      () {
    final map = reflectionLake();
    final layer = reflectionLayer(TilePainter());
    final shadows = RegionLightLayer();
    const field = Size(768, 480);
    final top = waterTop(map, map.width ~/ 2)!;
    final view = Rect.fromLTWH(200, top - 120, 360, 240);
    // A moment when a cloud straddles the shore in the view.
    var found = false;
    for (var t = 0.0; t < 600 && !found; t += 7) {
      final all = <(double, double, int)>{};
      RegionLightLayer.cloudCells(view, t, 1, field.width, field.height,
          (x, y, s) => all.add((x, y, s)));
      frame((c) {
        layer.draw(c, map, view,
            t: t,
            darkness: 0,
            cover: 1,
            field: field,
            actors: const [],
            roofed: (_, __) => false);
        shadows.drawClouds(c, view, t, 1, field.width, field.height,
            onWater: layer.reflectsSky);
      });
      Set<(double, double, int)> cells(List<List<double>> b) => {
            for (var s = 0; s < b.length; s++)
              for (var i = 0; i < b[s].length; i += 2)
                (b[s][i], b[s][i + 1], s + 1),
          };
      final land = cells(shadows.debugShadowCells);
      final water = cells(layer.debugCloudCells);
      if (land.isEmpty || water.isEmpty) continue;
      found = true;
      expect(land.intersection(water), isEmpty);
      // Together they are exactly the cloud: nothing lost at the shore.
      expect(land.union(water), all);
      for (final (x, y, _) in water) {
        expect(layer.reflectsSky(x, y), isTrue);
      }
      for (final (x, y, _) in land) {
        expect(layer.reflectsSky(x, y), isFalse);
      }
    }
    expect(found, isTrue, reason: 'a cloud crossed the shore');
  });

  testWidgets('no tint seam while panning across a window border',
      (tester) async {
    final map = reflectionLake(w: 64, h: 40, rx: 26, ry: 14);
    final layer = reflectionLayer(TilePainter());
    const w = 160, h = 64;
    // Deep water, far from the shore; window borders every 8 tiles.
    final cy = (map.height / 2 + 4) * 16.0;
    final rows = <List<int>>[];
    for (final x0 in [380.0, 384.0, 388.0, 512.0]) {
      final view = Rect.fromLTWH(x0, cy, w.toDouble(), h.toDouble());
      final img = record(w, h, (c) {
        c.translate(-view.left, -view.top);
        layer.draw(c, map, view,
            t: 0,
            darkness: 0,
            cover: 0,
            field: const Size(1024, 640),
            actors: const [],
            roofed: (_, __) => false);
      });
      final data = await tester.runAsync(
          () => img.toByteData(format: ui.ImageByteFormat.rawRgba));
      final px = data!.buffer.asUint32List();
      rows.add([for (var x = 0; x < w; x++) px[(h ~/ 2) * w + x]]);
      img.dispose();
    }
    expect(layer.windowBuilds, greaterThan(1), reason: 'crossed a border');
    // Without clouds or actors, open water is one flat colour everywhere.
    final all = {for (final r in rows) ...r};
    expect(all, hasLength(1));
  });
}
