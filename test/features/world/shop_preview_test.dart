import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/shop_interior_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/player_stall.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/shop_interior_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

/// Previews of the players' shop (docs/specs/player_shop.md § 6): the
/// house next to the ARMERÍA and the interior with 3 players' counters.
/// Written with `PREVIEW=1 flutter test <this file>`.
final _on = Platform.environment['PREVIEW'] != null;
const _ts = 16.0;

Future<ui.Image> _png(String path) async {
  final codec =
      await ui.instantiateImageCodec(File('assets/sprites/$path').readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<void> _save(WidgetTester tester, ui.Picture pic, int w, int h,
    String name) async {
  await tester.runAsync(() async {
    final img = await pic.toImage(w, h);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview').createSync(recursive: true);
    File('docs/preview/$name').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void _text(Canvas c, String s, double x, double y, Color col, double size) {
  final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(
              color: col, fontSize: size, fontFamily: RetroType.pixelFamily)),
      textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
}

void main() {
  testWidgets('preview: TIENDA next to the ARMERÍA', (tester) async {
    if (!_on) return;
    await loadRealFonts(tester);
    final map = MapGenerator.townOf(const TownState());
    final images = (await tester.runAsync(() async => {
          TownSpot.armory: await _png('items/vida_armeria.png'),
          TownSpot.shop: await _png('items/vida_tienda.png'),
        }))!;
    const x0 = 17, y0 = 4, w = 14, h = 14, scale = 3.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale)
      ..translate(-x0 * _ts, -y0 * _ts);
    final tiles = TilePainter();
    for (var y = y0; y < y0 + h; y++) {
      for (var x = x0; x < x0 + w; x++) {
        tiles.draw(c, map.tileAt(x, y), x * _ts, y * _ts, map.theme, x, y,
            t: 0, gateOpen: false, lobby: true);
      }
    }
    for (final e in images.entries) {
      final l = TownLayout.landmark(e.key);
      final im = e.value;
      final cx = (l.x + l.w / 2) * _ts, bottom = (l.y + l.h) * _ts;
      c.drawImage(im, Offset(cx - im.width / 2, bottom - im.height), Paint());
      _text(c, l.name, cx, bottom - im.height - 4, const Color(0xFFFFE9A8), 6);
    }
    await _save(tester, rec.endRecording(), (w * _ts * scale).round(),
        (h * _ts * scale).round(), 'shop_exterior.png');
  });

  testWidgets('preview: shop interior with 3 counters', (tester) async {
    if (!_on) return;
    await loadRealFonts(tester);
    final e = sessionEngine();
    var s = e.create();
    for (final (id, name) in [('p0', 'Ana'), ('p1', 'Beto'), ('p2', 'Caro')]) {
      final p = newProfile(name, 'guerrero');
      s = e.addPlayer(
          s,
          id,
          p.copyWith(
              life: p.life.copyWith(
                  stall: PlayerStall(listings: [
            if (id != 'p2') const StallListing('fish:carpa_musgo', 3, 10),
            const StallListing('ore:ingot_copper', 2, 40),
            if (id == 'p0') const StallListing('fish:trucha_musgo', 1, 25),
          ]))))!.state;
    }
    s = act(e, s, 'p0', const TravelAction(ShopInteriorRules.place));
    final icons = (await tester.runAsync(() async => {
          'carpa_musgo': await _png('items/vida_carpa_musgo.png'),
          'trucha_musgo': await _png('items/vida_trucha_musgo.png'),
          'mat_ingot_copper': await _png('items/vida_mine_ingot_copper.png'),
        }))!;
    final layer = ShopInteriorLayer((id, _) =>
        icons[id] ?? icons[id.replaceFirst('mat_', '')]);
    const scale = 3.0;
    const w = ShopInteriorRules.width * _ts, h = ShopInteriorRules.height * _ts;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(scale);
    layer.drawRoom(c);
    layer.drawCounters(c, s.players, 'LIBRE', (t, x, y, col, size) => _text(c, t, x, y, col, size));
    // Players walking around (plain markers).
    const cols = [Color(0xFF4CD137), Color(0xFF00A8FF), Color(0xFFE84393)];
    final at = [(6.0, 5.6), (9.6, 8.0), (13.5, 9.6)];
    for (var i = 0; i < 3; i++) {
      final (x, y) = at[i];
      c.drawRect(Rect.fromLTWH(x * _ts - 4, y * _ts - 12, 8, 12),
          Paint()..color = cols[i]);
    }
    await _save(tester, rec.endRecording(), (w * scale).round(),
        (h * scale).round(), 'shop_interior.png');
  });
}
