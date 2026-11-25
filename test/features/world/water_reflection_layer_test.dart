import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/settings/graphics.dart';
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
}
