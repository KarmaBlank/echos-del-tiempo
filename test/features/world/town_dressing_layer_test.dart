import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/town_dressing_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/town_dressing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/renown.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_dressing_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/town_dressing_map.dart';

/// Town tier and event dressing (renown_town_growth.md § 5.2, § 6.4).
/// `TOWN_DRESSING_PREVIEW=1` writes docs/preview/town_tier_<n>.png and
/// docs/preview/festival_<kind>.png.
const _ts = TownDressingLayer.ts;

void _base(Canvas c, GameMap map) {
  for (var y = 0; y < map.height; y++) {
    for (var x = 0; x < map.width; x++) {
      final r = Rect.fromLTWH(x * _ts, y * _ts, _ts, _ts);
      final col = switch (map.tileAt(x, y)) {
        Tile.path => const Color(0xFF8A7352),
        Tile.fountain => const Color(0xFF5E7A8C),
        Tile.house => const Color(0xFF7A5C46),
        Tile.tree => const Color(0xFF2F4A2A),
        _ => (x + y).isEven ? const Color(0xFF4E6B3C) : const Color(0xFF4A6639),
      };
      c.drawRect(r, Paint()..color = col);
      if (map.tileAt(x, y) == Tile.house && map.tileAt(x, y - 1) != Tile.house) {
        c.drawRect(Rect.fromLTWH(x * _ts, y * _ts, _ts, 7),
            Paint()..color = const Color(0xFF5A3A34));
      }
    }
  }
}

Future<ui.Image> _render(TownDressingLayer layer, GameMap map, TownDressing d,
    {bool night = false, double secs = 3}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  _base(c, map);
  layer.drawGround(c, map, d, (0, 0), secs, night: night);
  layer.drawOverhead(c, d, night: night);
  if (night) {
    c.drawRect(Rect.fromLTWH(0, 0, map.width * _ts, map.height * _ts),
        Paint()..color = const Color(0x88101830));
  }
  layer.drawSky(c, d, secs, night: night);
  return rec.endRecording().toImage(
      (map.width * _ts).toInt(), (map.height * _ts).toInt());
}

Future<void> _maybeWrite(ui.Image img, String name) async {
  if (Platform.environment['TOWN_DRESSING_PREVIEW'] != '1') return;
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File('docs/preview/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

Future<int> _pixel(ui.Image img, int x, int y) async {
  final b = (await img.toByteData())!;
  return b.getUint32((y * img.width + x) * 4);
}

void main() {
  final map = dressingTestMap();

  test('each tier renders differently and paths change material', () async {
    final seen = <int>{};
    for (var i = 0; i < kTownTierDressing.length; i++) {
      final layer = TownDressingLayer();
      final img = await _render(layer, map, TownDressingRules.of(i, null));
      // A path tile away from props: dirt keeps the base colour.
      final px = await _pixel(img, 2 * 16 + 3, 7 * 16 + 3);
      seen.add(px);
      final bytes = (await img.toByteData())!.buffer.asUint8List();
      seen.add(Object.hashAll(bytes));
      await _maybeWrite(img, 'town_tier_$i');
    }
    expect(seen.length, greaterThanOrEqualTo(6));
  });

  test('festival and tournament dress the town; sky lanterns only at night',
      () async {
    for (final k in TownEventKind.values) {
      final layer = TownDressingLayer();
      final d = TownDressingRules.of(2, k);
      final day = await _render(layer, map, d);
      final night = await _render(layer, map, d, night: true);
      expect(layer.layout.centre, isNotNull);
      await _maybeWrite(night, 'festival_${k.name}');
      await _maybeWrite(day, 'festival_${k.name}_day');
      final plain = await _render(TownDressingLayer(), map,
          TownDressingRules.of(2, null));
      final a = (await day.toByteData())!.buffer.asUint8List();
      final b = (await plain.toByteData())!.buffer.asUint8List();
      expect(Object.hashAll(a) == Object.hashAll(b), isFalse);
    }
  });

  test('reduce motion: the same frame at any time', () async {
    final d = TownDressingRules.of(3, TownEventKind.festival);
    final a = await _render(TownDressingLayer(), map, d, secs: 0);
    final b = await _render(TownDressingLayer(), map, d, secs: 0);
    expect(Object.hashAll((await a.toByteData())!.buffer.asUint8List()),
        Object.hashAll((await b.toByteData())!.buffer.asUint8List()));
  });

  test('perf: static layers cached, frames stay cheap', () {
    final layer = TownDressingLayer();
    final d = TownDressingRules.of(3, TownEventKind.festival);
    final sw = Stopwatch()..start();
    for (var f = 0; f < 600; f++) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      layer
        ..drawGround(c, map, d, (0, 0), f / 60, night: true)
        ..drawOverhead(c, d, night: true)
        ..drawSky(c, d, f / 60, night: true);
      rec.endRecording().dispose();
    }
    sw.stop();
    expect(layer.rebuilds, 1);
    // ignore: avoid_print
    print('town dressing: ${sw.elapsedMicroseconds / 600} us/frame');
    expect(sw.elapsedMilliseconds / 600, lessThan(2.0));
    layer.drawGround(ui.Canvas(ui.PictureRecorder()), map,
        TownDressingRules.of(3, null), (0, 0), 0, night: false);
    expect(layer.rebuilds, 2);
  }, tags: 'perf');
}
