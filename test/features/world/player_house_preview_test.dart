import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/home_interior_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/home_interior_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../tool/export_player_house_sprites.dart' show kHomeRows, kHomeBeds;

/// Previews of the player house (docs/specs/player_house.md): the house
/// in town and its interior. Written with
/// `PREVIEW=1 flutter test <this file>` to docs/preview/player_house/.
final _on = Platform.environment['PREVIEW'] != null;
const _ts = 16.0;

Future<ui.Image> _png(String path) async {
  final codec = await ui
      .instantiateImageCodec(File('assets/sprites/$path').readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<void> _save(
    WidgetTester tester, ui.Picture pic, int w, int h, String name) async {
  await tester.runAsync(() async {
    final img = await pic.toImage(w, h);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview/player_house').createSync(recursive: true);
    File('docs/preview/player_house/$name')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  test('the art matches HomeInteriorRules', () {
    expect(kHomeRows, HomeInteriorRules.rows);
    expect(kHomeBeds, HomeInteriorRules.bedTiles);
  });

  testWidgets('preview: the player house in town', (tester) async {
    if (!_on) return;
    TownState? town;
    for (var y = 6; y < 24 && town == null; y++) {
      for (var x = 4; x < 34 && town == null; x++) {
        town = TownRules.place(const TownState(), kPlayerHouseId, x, y).town;
      }
    }
    final map = MapGenerator.townOf(town!);
    final b = HomeInteriorRules.housesOf(town).single.bounds;
    final (ox, oy) = town.origin;
    final im = (await tester.runAsync(
        () async => _png('items/vida_home_exterior.png')))!;
    final x0 = b.x + ox - 3, y0 = b.y + oy - 3;
    const w = 10, h = 9, scale = 3.0;
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
    final cx = (b.x + ox + b.w / 2) * _ts, bottom = (b.bottom + oy) * _ts;
    c.drawImage(im, Offset(cx - im.width / 2, bottom - im.height), Paint());
    await _save(tester, rec.endRecording(), (w * _ts * scale).round(),
        (h * _ts * scale).round(), 'house_exterior.png');
  });

  testWidgets('preview: the player house interior', (tester) async {
    if (!_on) return;
    final room =
        (await tester.runAsync(() async => _png('items/vida_home_room.png')))!;
    final layer = HomeInteriorLayer((id, _) => id == 'home_room' ? room : null);
    const scale = 3.0;
    const w = HomeInteriorRules.width * _ts, h = HomeInteriorRules.height * _ts;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(scale);
    layer.drawRoom(c);
    // A player standing by the door (plain marker).
    const a = HomeInteriorRules.arrival;
    c.drawRect(Rect.fromLTWH(a.x - 4, a.y - 12, 8, 12),
        Paint()..color = const Color(0xFF4CD137));
    await _save(tester, rec.endRecording(), (w * scale).round(),
        (h * scale).round(), 'house_interior.png');
  });
}
