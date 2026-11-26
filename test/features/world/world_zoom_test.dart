import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/world_frame.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_zoom_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _virtual = Size(480, 288);

/// Pixel-perfect world zoom (exploration.md § Cámara, "Zoom del mundo").
/// `ZOOM_PREVIEW=1` writes docs/preview/zoom_levels.png.
void main() {
  final screens = [
    const Size(1920, 1080),
    const Size(1366, 768),
    const Size(1280, 720),
    const Size(2560, 1440),
  ];

  test('levels are integers in the tunable range; Ctrl + wheel clamps', () {
    expect(WorldZoomRules.minLevel, lessThanOrEqualTo(0));
    expect(WorldZoomRules.maxLevel, greaterThan(0));
    var l = 0;
    for (var i = 0; i < 10; i++) {
      l = WorldZoomRules.step(l, 1);
    }
    expect(l, WorldZoomRules.maxLevel);
    for (var i = 0; i < 10; i++) {
      l = WorldZoomRules.step(l, -1);
    }
    expect(l, WorldZoomRules.minLevel);
    expect(WorldZoomRules.step(0, 1), 1);
    expect(WorldZoomRules.clampLevel(99), WorldZoomRules.maxLevel);
  });

  test('the pixel scale is always a whole number >= 1', () {
    for (final s in screens) {
      for (final mode in ScaleMode.values) {
        final view = mapViewRect(s, _virtual, mode);
        for (var l = WorldZoomRules.minLevel; l <= WorldZoomRules.maxLevel; l++) {
          final p = WorldZoomRules.pixelScale(view.width / _virtual.width, l);
          expect(p, greaterThanOrEqualTo(1));
          expect(p, isA<int>());
        }
      }
    }
  });

  test('world -> screen is integer-aligned at every non-zero level', () {
    for (final s in screens) {
      for (final mode in ScaleMode.values) {
        final view = mapViewRect(s, _virtual, mode);
        for (var l = WorldZoomRules.minLevel; l <= WorldZoomRules.maxLevel; l++) {
          if (l == 0) continue;
          final f = WorldFrame.of(view, _virtual, l);
          final p = f.pixelScale!;
          // One world px = one image px (no resampling of the world)...
          expect(f.imageScale / f.zoom, 1);
          // ...and the image goes on screen at a whole factor.
          expect(f.dst.width, f.imageW * p);
          expect(f.dst.height, f.imageH * p);
          expect(f.dst.left, f.dst.left.roundToDouble());
          expect(f.dst.top, f.dst.top.roundToDouble());
          // The image covers the whole map area.
          expect(f.dst.contains(f.clip.topLeft), isTrue);
          expect(f.dst.right, greaterThanOrEqualTo(f.clip.right));
          expect(f.dst.bottom, greaterThanOrEqualTo(f.clip.bottom));
          // Whole camera -> whole screen px, P apart per world px.
          for (final cam in [0.0, 37.0, 1203.0]) {
            final a = f.toScreen(Offset(cam + 5, cam + 9), cam, cam);
            final b = f.toScreen(Offset(cam + 6, cam + 9), cam, cam);
            expect(a.dx, closeTo(a.dx.roundToDouble(), 1e-6));
            expect(a.dy, closeTo(a.dy.roundToDouble(), 1e-6));
            expect(b.dx - a.dx, closeTo(p.toDouble(), 1e-6));
          }
        }
        // Closer levels show less world.
        final z1 = WorldFrame.of(view, _virtual, 1).zoom;
        final z2 = WorldFrame.of(view, _virtual, 2).zoom;
        expect(z2, lessThan(z1));
        expect(WorldFrame.of(view, _virtual, 0).zoom, 1);
      }
    }
  });

  test('fishing goes one step closer and returns to the chosen level', () {
    final max = WorldZoomRules.maxLevel;
    expect(WorldZoomRules.effective(0, fishing: true),
        0 + WorldZoomRules.fishSteps);
    expect(WorldZoomRules.effective(0, fishing: false), 0);
    // Already at the closest level: no fishing zoom, stays put.
    expect(WorldZoomRules.effective(max, fishing: true), max);
    expect(WorldZoomRules.effective(-1, fishing: true),
        -1 + WorldZoomRules.fishSteps);
    expect(WorldZoomRules.effective(-1, fishing: false), -1);
  });

  test('the chosen level persists in the settings', () {
    final s = const GameSettings().copyWith(worldZoom: 2);
    final back = GameSettings.fromJson(s.toJson());
    expect(back.worldZoom, 2);
    expect(back, s);
    expect(const GameSettings().worldZoom, 0);
    expect(GameSettings.fromJson({...s.toJson(), 'worldZoom': 99}).worldZoom,
        0);
    expect(const GameSettings().copyWith(worldZoom: 99).worldZoom,
        GameSettings.worldZoomMax);
  });

  test('every world px is a uniform block at each level (raster check)',
      () async {
    const screen = Size(1280, 720);
    final view = mapViewRect(screen, _virtual, ScaleMode.fit);
    final shots = <ui.Image>[];
    for (var l = WorldZoomRules.minLevel; l <= WorldZoomRules.maxLevel; l++) {
      final img = await _render(view, l, screen);
      shots.add(img);
      if (l == 0) continue;
      final f = WorldFrame.of(view, _virtual, l);
      final p = f.pixelScale!;
      final bytes = (await img.toByteData())!;
      int px(int x, int y) =>
          bytes.getUint32((y * screen.width.toInt() + x) * 4);
      // Sample world px blocks in the middle: every screen px of a block
      // has the block's colour.
      final ox = f.dst.left.toInt(), oy = f.dst.top.toInt();
      for (var by = 40; by < 48; by++) {
        for (var bx = 40; bx < 56; bx++) {
          final x0 = ox + bx * p, y0 = oy + by * p;
          final c = px(x0, y0);
          for (var dy = 0; dy < p; dy++) {
            for (var dx = 0; dx < p; dx++) {
              expect(px(x0 + dx, y0 + dy), c);
            }
          }
        }
      }
    }
    if (Platform.environment['ZOOM_PREVIEW'] == '1') {
      final w = screen.width / 2, h = screen.height / 2;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < shots.length; i++) {
        c.drawImageRect(
            shots[i],
            Offset.zero & screen,
            Rect.fromLTWH((i % 2) * w, (i ~/ 2) * h, w, h),
            Paint()..filterQuality = FilterQuality.none);
      }
      final out = await rec
          .endRecording()
          .toImage(screen.width.toInt(), (h * ((shots.length + 1) ~/ 2)).toInt());
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      File('docs/preview/zoom_levels.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
}

/// The map pipeline of MapGame.render with a test world: the same spot
/// (camera centered on world (400, 300)) at [level].
Future<ui.Image> _render(Rect view, int level, Size screen) async {
  final f = WorldFrame.of(view, _virtual, level);
  final z = f.zoom;
  final camX = (400 - _virtual.width * z / 2).roundToDouble();
  final camY = (300 - _virtual.height * z / 2).roundToDouble();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Offset.zero & _virtual)
    ..save()
    ..scale(1 / z)
    ..translate(-camX, -camY);
  // 16 px tiles with 1 px details, like the pixel art.
  for (var ty = 0; ty < 40; ty++) {
    for (var tx = 0; tx < 60; tx++) {
      final dark = (tx + ty).isEven;
      c.drawRect(Rect.fromLTWH(tx * 16.0, ty * 16.0, 16, 16),
          Paint()..color = dark ? const Color(0xFF3B6B2E) : const Color(0xFF4F8A3A));
      c.drawRect(Rect.fromLTWH(tx * 16.0 + 3, ty * 16.0 + 5, 1, 1),
          Paint()..color = const Color(0xFFE8D26A));
      c.drawRect(Rect.fromLTWH(tx * 16.0 + 9, ty * 16.0 + 11, 2, 1),
          Paint()..color = const Color(0xFF1E3A18));
    }
  }
  c.restore();
  var pic = rec.endRecording();
  if (f.imageScale != 1) {
    final r2 = ui.PictureRecorder();
    Canvas(r2)
      ..scale(f.imageScale)
      ..drawPicture(pic);
    pic = r2.endRecording();
  }
  final img = await pic.toImage(f.imageW, f.imageH);
  final rec3 = ui.PictureRecorder();
  Canvas(rec3)
    ..drawRect(Offset.zero & screen, Paint()..color = const Color(0xFF000000))
    ..clipRect(f.clip)
    ..drawImageRect(
        img,
        Rect.fromLTWH(0, 0, f.imageW.toDouble(), f.imageH.toDouble()),
        f.dst,
        Paint()..filterQuality = FilterQuality.none);
  return rec3
      .endRecording()
      .toImage(screen.width.toInt(), screen.height.toInt());
}
