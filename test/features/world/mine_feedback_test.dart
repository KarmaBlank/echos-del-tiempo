import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/map_themes.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/mine_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Dig feedback in the mines (docs/specs/mining_smithing.md § 1.9): the
/// pick swing, cracks and the dig indicator. The preview strip goes to
/// docs/preview/mining_feedback.png with
/// `MINING_PREVIEW=1 flutter test <this file>`.
final _preview = Platform.environment['MINING_PREVIEW'] != null;

Future<ByteData> _pixels(ui.Picture pic, int w, int h, WidgetTester t) async =>
    (await t.runAsync(() async {
      final img = await pic.toImage(w, h);
      return img.toByteData(format: ui.ImageByteFormat.rawRgba);
    }))!;

Color _at(ByteData d, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return Color.fromARGB(
      d.getUint8(i + 3), d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2));
}

void main() {
  group('digProgress', () {
    test('fills with hits dealt', () {
      expect(
          MineLayer.digProgress(
              dealt: 0, hits: 4, sinceHitMs: 0, holding: true),
          0);
      expect(
          MineLayer.digProgress(
              dealt: 2, hits: 4, sinceHitMs: 10, holding: true),
          0.5);
      expect(
          MineLayer.digProgress(
              dealt: 9, hits: 4, sinceHitMs: 10, holding: false),
          1);
    });

    test('hides once the player lets go', () {
      expect(
          MineLayer.digProgress(
              dealt: 2,
              hits: 4,
              sinceHitMs: MineLayer.indicatorLingerMs - 1,
              holding: false),
          0.5);
      expect(
          MineLayer.digProgress(
              dealt: 2,
              hits: 4,
              sinceHitMs: MineLayer.indicatorLingerMs + 1,
              holding: false),
          isNull);
      // Held: stays up however long between hits.
      expect(
          MineLayer.digProgress(
              dealt: 2, hits: 4, sinceHitMs: 5000, holding: true),
          0.5);
    });
  });

  test('swing: lands on the hit, recoils, winds up and stays raised', () {
    const period = 300.0;
    expect(MineLayer.swingOffset(MineLayer.strikeMs, period), closeTo(0, 1e-9));
    final recoil =
        MineLayer.swingOffset(MineLayer.strikeMs + MineLayer.recoilMs, period);
    expect(recoil, lessThan(0));
    expect(MineLayer.swingOffset(period, period), lessThan(recoil));
    expect(MineLayer.swingOffset(period * 5, period),
        MineLayer.swingOffset(period, period));
  });

  test('cracks grow with damage', () {
    expect(MineLayer.crackSegments(0), 0);
    var last = 0;
    for (final k in [0.1, 0.3, 0.6, 0.9, 1.0]) {
      final n = MineLayer.crackSegments(k);
      expect(n, greaterThanOrEqualTo(last));
      last = n;
    }
    expect(last, greaterThan(MineLayer.crackSegments(0.1)));
  });

  testWidgets('indicator bar renders its fill in the target colour',
      (tester) async {
    Future<ByteData> render(double? progress, bool ok) {
      final rec = ui.PictureRecorder();
      drawTileTarget(Canvas(rec), [(0, 0)], ok, progress: progress);
      return _pixels(rec.endRecording(), 16, 16, tester);
    }

    // Half full: left of the bar filled, right of it the dark back.
    final half = await render(0.5, true);
    expect(_at(half, 16, 3, 12), FarmPalette.targetOk);
    expect(_at(half, 16, 12, 12), isNot(FarmPalette.targetOk));
    expect(_at(half, 16, 12, 12).a, greaterThan(0));
    // The box (same marker as the farm's) is there too.
    expect(_at(half, 16, 0, 5), FarmPalette.targetOk);
    // Pick too weak: orange, nothing filled.
    final bad = await render(0, false);
    expect(_at(bad, 16, 0, 5), FarmPalette.targetBad);
    expect(_at(bad, 16, 3, 12), isNot(FarmPalette.targetBad));
    // Without progress (the farm), no bar.
    final farm = await render(null, true);
    expect(_at(farm, 16, 3, 12).a, 0);
  });

  testWidgets('preview: pick swing frames and dig indicator', (tester) async {
    const ts = 16.0, scale = 4.0;
    const frames = [0.0, 20.0, 45.0, 90.0, 160.0, 300.0];
    const cell = 48.0, h = 40.0;
    final w = cell * frames.length;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(scale);
    c.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = MinePalette.caveFloor);
    for (var i = 0; i < frames.length; i++) {
      final layer = MineLayer();
      final ms = frames[i];
      c.save();
      c.translate(i * cell, 0);
      // Rock to the right of the player.
      const tx = 1, ty = 1;
      c.drawRect(const Rect.fromLTWH(tx * ts, ty * ts, ts, ts),
          Paint()..color = MinePalette.rock);
      c.drawRect(const Rect.fromLTWH(tx * ts, ty * ts, ts, 3),
          Paint()..color = MinePalette.rockTop);
      const px = 0.5 * ts, py = 2 * ts - 1;
      // Player stand-in.
      c.drawRect(const Rect.fromLTWH(px - 3, py - 12, 6, 12),
          Paint()..color = MinePalette.label);
      final progress = (i + 1) / frames.length;
      const t0 = 1000.0;
      layer.onSwing(tx, ty, t0, fromX: px, fromY: py);
      layer.drawEffects(c, t0);
      layer.drawCrack(c, tx, ty, progress, t0 + ms);
      layer.drawImpactFlash(c, t0 + ms);
      layer.drawSwing(c, tx, ty, px, py, MineLayer.swingOffset(ms, 300));
      layer.drawEffects(c, t0 + ms);
      drawTileTarget(c, [(tx, ty)], true, progress: progress);
      c.restore();
    }
    final pic = rec.endRecording();
    if (!_preview) {
      pic.dispose();
      return;
    }
    await tester.runAsync(() async {
      final img = await pic.toImage((w * scale).round(), (h * scale).round());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('docs/preview/mining_feedback.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
