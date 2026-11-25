import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/actor_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_cache.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/water_reflection_layer.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:material_ui/material_ui.dart';

/// A lake scene for the reflection tests, perf and previews
/// (docs/specs/water_reflections.md § 5): a lake of [rx] × [ry] tiles with
/// trees, rocks, lamps and a waystone on its shore.
GameMap reflectionLake(
    {int w = 48, int h = 30, double rx = 16, double ry = 9, String theme = 'bosque_ext'}) {
  final cx = w / 2, cy = h / 2 + 2;
  bool water(int x, int y) {
    final dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry;
    return dx * dx + dy * dy <= 1;
  }

  final rows = <String>[];
  for (var y = 0; y < h; y++) {
    final b = StringBuffer();
    for (var x = 0; x < w; x++) {
      if (water(x, y)) {
        b.write(Tile.water);
      } else if (water(x, y + 1) || water(x, y + 2)) {
        // Shore band: a prop every few tiles.
        final k = (x * 7 + y * 3) % 9;
        b.write(switch (k) {
          0 || 4 => Tile.tree,
          2 => Tile.lanternLit,
          6 => Tile.rock,
          7 when x % 5 == 0 => Tile.waystone,
          _ => Tile.grass,
        });
      } else {
        b.write((x * 3 + y * 5) % 13 == 0 ? Tile.tree : Tile.grass);
      }
    }
    rows.add(b.toString());
  }
  return GameMap(
      width: w,
      height: h,
      rows: rows,
      theme: theme,
      spawn: const WorldPoint(0, 0),
      lobby: true);
}

/// First water row of column [x] (px), or null.
double? waterTop(GameMap map, int x) {
  for (var y = 0; y < map.height; y++) {
    if (map.tileAt(x, y) == Tile.water) return y * 16.0;
  }
  return null;
}

/// Draws all tiles of [view] (no cache: tests and previews).
void drawTiles(Canvas c, GameMap map, Rect view, TilePainter tiles) {
  final x0 = math.max(0, (view.left / 16).floor() - 1);
  final y0 = math.max(0, (view.top / 16).floor() - 1);
  final x1 = math.min(map.width - 1, (view.right / 16).ceil() + 1);
  final y1 = math.min(map.height - 1, (view.bottom / 16).ceil() + 2);
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      tiles.draw(c, map.tileAt(x, y), x * 16.0, y * 16.0, map.theme, x, y,
          t: 0,
          gateOpen: false,
          lobby: true,
          at: (a, b) => map.contains(a, b) ? map.tileAt(a, b) : null);
    }
  }
}

/// Actors along the north shore and on the lake: heroes and enemies from
/// the real sprites when [sprites] is given, blocks otherwise.
List<ReflectedActor> lakeActors(GameMap map, int n,
    {ActorPainter? painter, double t = 0, bool raft = false}) {
  final out = <ReflectedActor>[];
  const classes = ['guerrero', 'maga', 'paladin', 'tirador'];
  const enemies = ['slime', 'bat'];
  final block = Paint()..color = const Color(0xFFE0B050);
  for (var i = 0; i < n; i++) {
    final col = 6 + (i * 5) % (map.width - 12);
    final top = waterTop(map, col);
    if (top == null) continue;
    final onLake = raft && i == 0;
    final x = col * 16.0 + 8;
    final y = onLake ? top + 64 : top - 4 - (i % 2) * 8;
    final hero = i % 3 != 2;
    void draw(Canvas c) {
      final p = painter;
      if (p == null) {
        c.drawRect(Rect.fromLTWH(x - 5, y - 16, 10, 16), block);
      } else if (hero) {
        p.hero(c,
            classId: classes[i % classes.length],
            weaponType: null,
            x: x,
            y: y,
            t: t,
            dir: i.isEven ? 1 : -1,
            moving: false,
            dead: false,
            blink: false);
      } else {
        p.enemy(c,
            type: enemies[i % enemies.length],
            x: x,
            y: y,
            dir: 1,
            t: t,
            elite: false);
      }
    }

    out.add((
      x: x,
      y: y + 1,
      moving: onLake || i % 4 == 0,
      onWater: onLake,
      draw: draw,
    ));
  }
  return out;
}

/// Loads the real sprites (call inside `tester.runAsync`).
Future<GameSprites> loadSprites() async =>
    GameSprites.load(await SpriteCatalog.load());

/// The reflection layer for [map]'s tile painter.
WaterReflectionLayer reflectionLayer(TilePainter tiles) =>
    WaterReflectionLayer(TileLayerCache(tiles));

/// Records [draw] and returns the picture's image (for previews).
ui.Image record(int w, int h, void Function(Canvas c) draw) {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  final pic = rec.endRecording();
  final img = pic.toImageSync(w, h);
  pic.dispose();
  return img;
}

/// A lake (rows 12+) with a 1-tile inlet going up at column 10 (rows
/// 6..11); trees: right above the inlet top (adjacent), and two tiles
/// above the lake at column 20 with grass between.
GameMap inletLake() {
  final rows = <String>[];
  for (var y = 0; y < 24; y++) {
    final b = StringBuffer();
    for (var x = 0; x < 32; x++) {
      if (y >= 12 || (x == 10 && y >= 6)) {
        b.write(Tile.water);
      } else if ((x == 10 && y == 5) || (x == 20 && y == 10)) {
        b.write(Tile.tree);
      } else {
        b.write(Tile.grass);
      }
    }
    rows.add(b.toString());
  }
  return GameMap(
      width: 32,
      height: 24,
      rows: rows,
      theme: 'bosque_ext',
      spawn: const WorldPoint(0, 0),
      lobby: true);
}
