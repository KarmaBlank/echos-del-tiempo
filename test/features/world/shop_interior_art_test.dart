import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/farm_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/shop_interior_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_stall.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/town_build.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/shop_interior_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yaml/yaml.dart';

import '../../../tool/export_shop_interior_sprites.dart' show kShopRows;
import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

/// Art of the shop interior and the residents' houses
/// (player_shop.md § 6.1, town_editor.md § 3.4). Previews are written
/// with `PREVIEW=1 flutter test <this file>`.
final _on = Platform.environment['PREVIEW'] != null;
const _ts = 16.0;

final _items = (loadYaml(File('assets/sprites/sprite_manifest.yaml')
        .readAsStringSync()) as YamlMap)['items'] as YamlMap;

/// Every `vida_*` id this pass adds or redraws.
final _ids = [
  for (var lv = 1; lv <= 3; lv++) ...[
    'casa_$lv',
    'casa_${lv}_v1',
    'casa_${lv}_v2',
  ],
  'shop_room',
  'shop_tag',
  for (final pc in ['l', 'm', 'r', 's'])
    for (final c in ['0', '1', '2', '3', 'bare']) 'shop_table_${pc}_$c',
];

String _path(String id) =>
    'assets/sprites/${((_items['vida_$id'] as YamlMap)['idle'] as String)}';

Future<ui.Image> _decode(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  return (await codec.getNextFrame()).image;
}

Future<ui.Image> _png(String path) => _decode(File(path).readAsBytesSync());

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
      text: TextSpan(
          text: s,
          style: TextStyle(
              color: col, fontSize: size, fontFamily: RetroType.pixelFamily)),
      textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
}

void _blit(Canvas c, ui.Image im, double x, double y, [double k = 1]) =>
    c.drawImageRect(
        im,
        Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        Rect.fromLTWH(x, y, im.width * k, im.height * k),
        Paint()..filterQuality = FilterQuality.none);

/// The shop with 3 players' tables, drawn with [layer], and the players'
/// real idle sprites ([chars]) standing around.
void _paintShop(Canvas c, ShopInteriorLayer layer, Map<String, dynamic> players,
    List<ui.Image>? chars) {
  layer.drawRoom(c);
  layer.drawCounters(c, players.cast(), 'LIBRE',
      (t, x, y, col, size) => _text(c, t, x, y, col, size));
  final at = [(6.0, 5.6), (9.6, 8.0), (13.5, 9.6)];
  const cols = [Color(0xFF4CD137), Color(0xFF00A8FF), Color(0xFFE84393)];
  for (var i = 0; i < 3; i++) {
    final (x, y) = at[i];
    if (chars == null) {
      c.drawRect(Rect.fromLTWH(x * _ts - 4, y * _ts - 12, 8, 12),
          Paint()..color = cols[i]);
    } else {
      final im = chars[i];
      _blit(c, im, x * _ts - im.width / 2, y * _ts - im.height);
    }
  }
}

void main() {
  test('the tool room matches ShopInteriorRules.rows', () {
    expect(kShopRows, ShopInteriorRules.rows);
  });

  test('every new sprite is in the manifest and its file exists', () {
    for (final id in _ids) {
      expect(_items['vida_$id'], isNotNull, reason: id);
      expect(File(_path(id)).existsSync(), isTrue, reason: id);
    }
  });

  testWidgets('every new sprite has pixels and the manifest size',
      (tester) async {
    await tester.runAsync(() async {
      for (final id in _ids) {
        final im = await _png(_path(id));
        final size = ((_items['vida_$id'] as YamlMap)['size'] as YamlList)
            .cast<int>();
        expect([im.width, im.height], size, reason: id);
        final data = (await im.toByteData())!;
        var opaque = 0;
        for (var i = 3; i < data.lengthInBytes; i += 4) {
          if (data.getUint8(i) > 0) opaque++;
        }
        expect(opaque, greaterThan(im.width * im.height ~/ 4), reason: id);
      }
    });
  });

  test('table autotile: single, ends and middles', () {
    expect(ShopInteriorLayer.tablePieces(1), ['s']);
    expect(ShopInteriorLayer.tablePieces(2), ['l', 'r']);
    expect(ShopInteriorLayer.tablePieces(4), ['l', 'm', 'm', 'r']);
    expect(ShopInteriorLayer.clothOf(5, owned: true), '1');
    expect(ShopInteriorLayer.clothOf(0, owned: false), 'bare');
  });

  test('house variants: by position, falling back to the level sprite', () {
    final vs = {for (var x = 0; x < 6; x++) MapFarmLayer.houseVariant(x, 3)};
    expect(vs, {0, 1, 2});
    for (var x = 0; x < 3; x++) {
      final b = TownBuild('c$x', BuildKind.casa, [TownRect(x, 5, 3, 3)],
          level: 2);
      final v = MapFarmLayer.houseVariant(x, 5);
      expect(MapFarmLayer.houseSprite(b, (_) => false), 'casa_2');
      expect(MapFarmLayer.houseSprite(b, (_) => true),
          v == 0 ? 'casa_2' : 'casa_2_v$v');
    }
  });

  test('shop lamps are lit by the light system on floor tiles', () {
    final map = ShopInteriorRules.map();
    for (final (x, y) in ShopInteriorRules.lamps) {
      expect(map.rows[y.floor()][x.floor()], isNot('#'), reason: '($x, $y)');
    }
    final ls = LightRules.ambientEmitters(map, 0, 0, map.width, map.height);
    final lamp = kLightDefs[LightId.lamparaTienda];
    expect(ls.where((l) => identical(l.def, lamp)).length,
        ShopInteriorRules.lamps.length);
  });

  testWidgets('preview: shop interior v2 and before / after', (tester) async {
    if (!_on) return;
    await loadRealFonts(tester);
    final e = sessionEngine();
    var s = e.create();
    for (final (id, name, cls) in [
      ('p0', 'Ana', 'guerrero'),
      ('p1', 'Beto', 'maga'),
      ('p2', 'Caro', 'tirador'),
    ]) {
      final p = newProfile(name, cls);
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
    final art = (await tester.runAsync(() async => {
          'carpa_musgo': await _png('assets/sprites/items/vida_carpa_musgo.png'),
          'trucha_musgo':
              await _png('assets/sprites/items/vida_trucha_musgo.png'),
          'ingot_copper':
              await _png('assets/sprites/items/vida_mine_ingot_copper.png'),
          for (final id in _ids.where((i) => i.startsWith('shop_')))
            id: await _png(_path(id)),
          for (final cls in ['guerrero', 'maga', 'tirador'])
            'char_$cls':
                await _png('assets/sprites/characters/$cls/idle.png'),
        }))!;
    ui.Image? look(String id) =>
        art[id] ?? art[GameSprites.lifeIconKeys(id).last];
    final chars = [art['char_guerrero']!, art['char_maga']!, art['char_tirador']!];
    const scale = 3.0;
    const w = ShopInteriorRules.width * _ts, h = ShopInteriorRules.height * _ts;

    var rec = ui.PictureRecorder();
    var c = Canvas(rec)..scale(scale);
    _paintShop(c, ShopInteriorLayer((id, _) => look(id)), s.players, chars);
    await _save(tester, rec.endRecording(), (w * scale).round(),
        (h * scale).round(), 'shop_interior_v2.png');

    // Before (the flat drawing, no room sprites) | after.
    rec = ui.PictureRecorder();
    c = Canvas(rec)..scale(2.0);
    final flat = ShopInteriorLayer(
        (id, _) => id.startsWith('shop_') ? null : look(id));
    _paintShop(c, flat, s.players, null);
    _text(c, 'ANTES', w / 2, 6, const Color(0xFFFFFFFF), 8);
    c.translate(w + 8, 0);
    _paintShop(c, ShopInteriorLayer((id, _) => look(id)), s.players, chars);
    _text(c, 'AHORA', w / 2, 6, const Color(0xFFFFFFFF), 8);
    await _save(tester, rec.endRecording(), ((w * 2 + 8) * 2).round(),
        (h * 2).round(), 'shop_interior_before_after.png');
  });

  testWidgets('preview: town houses v2 and before / after', (tester) async {
    if (!_on) return;
    await loadRealFonts(tester);
    final now = (await tester.runAsync(() async => {
          for (final id in _ids.where((i) => i.startsWith('casa_')))
            id: await _png(_path(id)),
          'armeria': await _png('assets/sprites/items/vida_armeria.png'),
          'tienda': await _png('assets/sprites/items/vida_tienda.png'),
        }))!;
    // The old houses, straight from the commit before this pass.
    final before = (await tester.runAsync(() async {
      final out = <String, ui.Image>{};
      for (var lv = 1; lv <= 3; lv++) {
        final r = await Process.run(
            'git', ['show', '98f4d0c5:assets/sprites/items/vida_casa_$lv.png'],
            stdoutEncoding: null);
        if (r.exitCode == 0) {
          out['casa_$lv'] = await _decode(r.stdout as List<int>);
        }
      }
      return out;
    }))!;
    const grass = Color(0xFF3F6E3A);
    const cell = 64.0, scale = 3.0;

    // All variants (rows: variant; columns: level) next to the armory and
    // the shop.
    var rec = ui.PictureRecorder();
    var c = Canvas(rec)..scale(scale);
    const cols = 5, rows = 3;
    c.drawRect(const Rect.fromLTWH(0, 0, cols * cell, rows * cell + 10),
        Paint()..color = grass);
    for (var v = 0; v < 3; v++) {
      for (var lv = 1; lv <= 3; lv++) {
        final im = now[v == 0 ? 'casa_$lv' : 'casa_${lv}_v$v']!;
        _blit(c, im, (lv - 1) * cell + 8, v * cell + 12);
        _text(c, 'NV $lv · V$v', (lv - 1) * cell + cell / 2, v * cell + 6,
            const Color(0xFFFFE9A8), 5);
      }
    }
    for (final (k, id, name) in [(3, 'armeria', 'ARMERÍA'), (4, 'tienda', 'TIENDA')]) {
      _blit(c, now[id]!, k * cell + 8, cell + 12);
      _text(c, name, k * cell + cell / 2, cell + 6, const Color(0xFFFFE9A8), 5);
    }
    await _save(tester, rec.endRecording(), (cols * cell * scale).round(),
        ((rows * cell + 10) * scale).round(), 'town_houses_v2.png');

    // Before | after, per level.
    rec = ui.PictureRecorder();
    c = Canvas(rec)..scale(scale);
    c.drawRect(const Rect.fromLTWH(0, 0, 3 * cell, 2 * cell + 10),
        Paint()..color = grass);
    for (var lv = 1; lv <= 3; lv++) {
      final x = (lv - 1) * cell + 4;
      if (before['casa_$lv'] case final old?) _blit(c, old, x, 10);
      _blit(c, now['casa_$lv']!, x, cell + 10);
    }
    _text(c, 'ANTES', 1.5 * cell, 5, const Color(0xFFFFFFFF), 6);
    _text(c, 'AHORA', 1.5 * cell, cell + 5, const Color(0xFFFFFFFF), 6);
    await _save(tester, rec.endRecording(), (3 * cell * scale).round(),
        ((2 * cell + 10) * scale).round(), 'town_houses_before_after.png');
  });
}
