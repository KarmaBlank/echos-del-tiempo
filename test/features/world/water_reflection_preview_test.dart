import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/actor_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/water_reflection_layer.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'reflection_scene.dart';

/// Previews of the water reflections (docs/specs/water_reflections.md §
/// 7), written to docs/preview/reflections with
/// `REFLECT_PREVIEW=1 flutter test <this file>`.
final _on = Platform.environment['REFLECT_PREVIEW'] != null;

void main() {
  testWidgets('preview: reflejos en el agua', (tester) async {
    if (!_on) return;
    late GameSprites sprites;
    await tester.runAsync(() async => sprites = await loadSprites());
    final map = reflectionLake();
    final tiles = TilePainter()..vegetation = sprites.vegetation;
    final painter = ActorPainter(sprites);
    const w = 320.0, h = 200.0, scale = 3.0;
    final top = waterTop(map, map.width ~/ 2)!;
    final shore = Rect.fromLTWH(
        map.width * 8 - w / 2, top - 80, w, h);
    final lake = Rect.fromLTWH(
        map.width * 8 - w / 2, top + 10, w, h);

    final lamps = <ReflectedLight>[
      for (var y = 0; y < map.height; y++)
        for (var x = 0; x < map.width; x++)
          if (map.tileAt(x, y) == Tile.lanternLit)
            (x: x * 16 + 8.0, y: y * 16 + 4.0, color: const Color(0xFFFFD9A0)),
    ];

    Future<void> shot(String name, Rect view,
        {required double dark,
        double cover = 0.7,
        bool raft = false,
        double t = 2.0,
        Color? veil}) async {
      final layer = reflectionLayer(tiles);
      var actors = lakeActors(map, 10, painter: painter, t: t * 1000);
      if (raft) {
        final im = sprites.lifeIcon('balsa', '');
        final x = view.center.dx, y = view.center.dy + 10;
        actors = [
          ...actors,
          (
            x: x,
            y: y + 1,
            moving: true,
            onWater: true,
            draw: (Canvas c) {
              if (im != null) {
                c.drawImageRect(
                    im,
                    Rect.fromLTWH(0, 0, im.width.toDouble(),
                        im.height.toDouble()),
                    Rect.fromLTWH(x - 8, y + 3 - 8, 16, 16),
                    Paint()..filterQuality = FilterQuality.none);
              }
              painter.hero(c,
                  classId: 'maga',
                  weaponType: null,
                  x: x,
                  y: y,
                  t: t * 1000,
                  dir: 1,
                  moving: true,
                  dead: false,
                  blink: false);
            },
          ),
        ];
      }
      final img = record((w * scale).round(), (h * scale).round(), (c) {
        c
          ..scale(scale)
          ..translate(-view.left, -view.top);
        drawTiles(c, map, view, tiles);
        layer.draw(c, map, view,
            t: t,
            darkness: dark,
            cover: cover,
            field: Size(map.width * 16.0, map.height * 16.0),
            actors: actors,
            roofed: (_, __) => false);
        for (final a in [...actors]..sort((a, b) => a.y.compareTo(b.y))) {
          a.draw(c);
        }
        if (veil != null) {
          c.drawRect(view, Paint()
            ..color = veil
            ..blendMode = BlendMode.multiply);
        }
        layer.drawLights(c, view,
            lights: [
              ...lamps,
              if (dark > 0.5)
                for (final a in actors.take(3))
                  (x: a.x, y: a.y - 6, color: const Color(0xFFD2B8FF)),
            ],
            t: t,
            darkness: dark);
      });
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory('docs/preview/reflections').createSync(recursive: true);
        File('docs/preview/reflections/$name.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
      img.dispose();
      layer.dispose();
    }

    await shot('day_lake', shore, dark: 0);
    await shot('sunset', shore,
        dark: 0.5, veil: const Color(0xFFE8B090), cover: 0.4);
    await shot('night_lights', shore,
        dark: 1, veil: const Color(0xFF3A4478), cover: 0.2);
    await shot('raft_wake', lake, dark: 0, raft: true, t: 3.3);
  });
}
