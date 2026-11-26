// Town art: the TALLER DE OFICIOS sprite and the fence autotile
// (docs/specs/town_editor.md § 5.1). With PREVIEW_SHOTS=1 writes
// docs/preview/town_workshop.png (workshop next to the armory) and
// docs/preview/fences_autotile.png (a garden enclosure):
//   $env:PREVIEW_SHOTS = "1"; flutter test test/features/world/town_art_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/cozy_layer.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final _shots = Platform.environment['PREVIEW_SHOTS'] != null;

Future<void> _save(
    WidgetTester tester, ui.Picture pic, int w, int h, String name) async {
  if (!_shots) {
    pic.dispose();
    return;
  }
  await tester.runAsync(() async {
    final img = await pic.toImage(w, h);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('docs/preview/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void _grass(Canvas c, double w, double h) {
  c.drawRect(
      Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF3F6E3A));
  final dot = Paint()..color = const Color(0xFF4C7F45);
  for (var y = 0.0; y < h; y += 16) {
    for (var x = 0.0; x < w; x += 16) {
      c.drawRect(Rect.fromLTWH(x + (y % 32 == 0 ? 3 : 9), y + 5, 2, 2), dot);
    }
  }
}

void main() {
  testWidgets('workshop sprite resolves through SpriteCatalog', (tester) async {
    final (cat, sprites) = (await tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      return (cat, await GameSprites.load(cat));
    }))!;
    final e = cat.entry('items.vida_taller_oficios.idle');
    expect(e, isNotNull);
    expect(e!.path, 'items/vida_taller_oficios.png');
    final workshop = sprites.lifeIcon('taller_oficios', '');
    final armory = sprites.lifeIcon('armeria', '');
    expect(workshop, isNotNull);
    expect(armory, isNotNull);
    expect((workshop!.width, workshop.height), (armory!.width, armory.height));

    const scale = 6.0, pad = 8.0;
    const w = pad * 3 + 96, h = pad * 2 + 48;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(scale);
    _grass(c, w, h);
    final p = SpriteCatalog.pixelPaint();
    c.drawImage(armory, const Offset(pad, pad), p);
    c.drawImage(workshop, const Offset(pad * 2 + 48, pad), p);
    await _save(tester, rec.endRecording(), (w * scale).round(),
        (h * scale).round(), 'town_workshop');
  });

  testWidgets('fence autotile: garden enclosure with corners, T and gate',
      (tester) async {
    final sprites = (await tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      return GameSprites.load(cat);
    }))!;
    // 7 x 5 garden, a gate in the bottom side, an inner divider (T on
    // top and bottom) and a short stub (end post) inside.
    final town = TownState(decor: [
      for (var x = 0; x <= 6; x++) ('fence', x, 0),
      for (var x = 0; x <= 6; x++) (x == 5 ? 'fence_gate' : 'fence', x, 4),
      for (var y = 1; y <= 3; y++) ('fence', 0, y),
      for (var y = 1; y <= 3; y++) ('fence', 6, y),
      for (var y = 1; y <= 3; y++) ('fence', 3, y),
      ('fence', 1, 2),
      ('fence', 8, 2),
    ]);
    const scale = 5.0, ox = 1, oy = 1;
    const w = 11 * 16.0, h = 7 * 16.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(scale);
    _grass(c, w, h);
    var missing = 0;
    CozyLayer((id) {
      final im = sprites.lifeIcon(id, '');
      if (im == null) missing++;
      return im;
    }).drawDecor(c, town, ox, oy);
    expect(missing, 0);
    await _save(tester, rec.endRecording(), (w * scale).round(),
        (h * scale).round(), 'fences_autotile');
  });
}
