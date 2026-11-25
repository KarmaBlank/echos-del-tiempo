import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_target.dart';
import 'package:echos_del_tiempo/game_engine/data/profession_gear_catalog.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Profession gear art (profession_gear.md § 3.2 and life_trees_v2.md
// § 2.1): the living weapon growth stages with the gear icons, and the
// area pickaxe indicator. With `PROFESSION_GEAR_PREVIEW=1` it writes
// docs/preview/living_weapon_stages.png and mine_area_pickaxe.png.

final _preview = Platform.environment['PROFESSION_GEAR_PREVIEW'] != null;
final _shot = GlobalKey();

Future<ui.Image> _png(String id) async {
  final bytes = File('assets/sprites/items/vida_$id.png').readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

Future<void> _save(WidgetTester tester, String name) async {
  if (!_preview) return;
  await tester.runAsync(() async {
    final b =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview').createSync(recursive: true);
    File('docs/preview/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

class _Strip extends CustomPainter {
  _Strip(this.rows);
  final List<List<ui.Image>> rows;

  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = DsColors.background);
    const cell = 64.0;
    for (var r = 0; r < rows.length; r++) {
      for (var i = 0; i < rows[r].length; i++) {
        final img = rows[r][i];
        c.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromLTWH(16 + i * (cell + 16), 16 + r * (cell + 16), cell, cell),
            Paint()..filterQuality = FilterQuality.none);
      }
    }
  }

  @override
  bool shouldRepaint(_Strip old) => false;
}

/// A mine wall with veins: the one in front (target) and the ones the
/// area pickaxe also breaks.
class _Mine extends CustomPainter {
  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xff2a2230));
    c.scale(4);
    final vein = Paint()..color = const Color(0xffc08a4a);
    const veins = [(2, 1), (3, 1), (2, 2), (3, 2), (4, 2), (3, 3)];
    for (final (x, y) in veins) {
      c.drawRect(Rect.fromLTWH(x * 16.0 + 4, y * 16.0 + 4, 8, 8), vein);
    }
    drawTileTarget(c, const [(3, 2)], true);
    final area = [
      for (final t in squareTiles(3, 2, 1))
        if (veins.contains(t) && t != (3, 2)) t,
    ].take(3);
    drawTileTarget(c, area, true);
  }

  @override
  bool shouldRepaint(_Mine old) => false;
}

void main() {
  testWidgets('living weapon stages and profession gear icons',
      (tester) async {
    late List<List<ui.Image>> rows;
    await tester.runAsync(() async {
      rows = [
        [for (var s = 0; s < 4; s++) await _png('vivo_$s')],
        [for (final w in kWeaponSeeds.keys.take(4)) await _png('semilla_$w')],
        [for (final g in kProfessionGear.values) await _png(g.sprite)],
      ];
    });
    await tester.binding.setSurfaceSize(const Size(1000, 260));
    await tester.pumpWidget(RepaintBoundary(
        key: _shot,
        child: CustomPaint(painter: _Strip(rows), size: const Size(1000, 260))));
    expect(rows.last, hasLength(kProfessionGear.length));
    await _save(tester, 'living_weapon_stages');
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('area pickaxe indicator', (tester) async {
    await tester.binding.setSurfaceSize(const Size(448, 384));
    await tester.pumpWidget(RepaintBoundary(
        key: _shot,
        child: CustomPaint(painter: _Mine(), size: const Size(448, 384))));
    expect(tester.takeException(), isNull);
    await _save(tester, 'mine_area_pickaxe');
    await tester.binding.setSurfaceSize(null);
  });
}
