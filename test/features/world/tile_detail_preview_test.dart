import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Terrain tile detail (docs/specs/tile_detail.md): every outdoor theme
/// paints a patch of grass, dirt, path, water, mountain rock and tilled
/// soil next to the cave reference. Always checks that the patch has the
/// four-step ramp the cave tiles have; `TILE_PREVIEW=<name>` writes
/// docs/preview/<name>.png (3x scale).
const _patch = [
  'gggggg,,,,gggg~~~~^^^^^^',
  'gggg,,,,,,ggg~~~~~~^^^^^',
  'ggg,,..,,ggg~~~~~~~g^^^^',
  'ggg,....,gg~~~~~~ggg^^^^',
  'uuug,,..,,gg~~~~gggg....',
  'uuuug,,,,ggggggggg......',
  'uuuuuggg,,ggggg.........',
];
const _cave = [
  '^^^^^^^^',
  '^^....^^',
  '^......^',
  '^..~~..^',
  '^......^',
  '^^...^^^',
  '^^^^^^^^',
];
const _themes = [
  'pueblo',
  'bosque_ext',
  'ruinas_ext',
  'cavernas_ext',
  'grieta_ext',
  'abismo_ext',
];

ui.Picture _render() {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final p = TilePainter();
  const w = (24 + 1 + 8) * 16.0;
  c.drawRect(Rect.fromLTWH(0, 0, w, _themes.length * 8 * 16.0),
      Paint()..color = const Color(0xFF101014));
  for (var r = 0; r < _themes.length; r++) {
    final theme = _themes[r];
    final oy = r * 8;
    String? at(List<String> m, int ox, int x, int y) {
      final ly = y - oy, lx = x - ox;
      if (ly < 0 || ly >= m.length || lx < 0 || lx >= m[0].length) return null;
      return m[ly][lx];
    }

    void patch(List<String> m, int ox, {required bool cave}) {
      for (var y = 0; y < m.length; y++) {
        for (var x = 0; x < m[0].length; x++) {
          var ch = m[y][x];
          final tx = ox + x, ty = oy + y;
          if (ch == 'g' && !cave) ch = Tile.grass;
          c.save();
          c.clipRect(Rect.fromLTWH(tx * 16.0, ty * 16.0, 16, 16));
          p.draw(c, ch, tx * 16.0, ty * 16.0, theme, tx, ty,
              t: 1000,
              gateOpen: false,
              lobby: false,
              cave: cave,
              at: (a, b) => at(m, ox, a, b));
          c.restore();
        }
      }
    }

    patch(_patch, 0, cave: false);
    patch(_cave, 25, cave: true);
  }
  return rec.endRecording();
}

void main() {
  testWidgets('terrain patches render with a multi-step ramp', (tester) async {
    const w = 33 * 16, h = 6 * 8 * 16;
    final img = (await tester.runAsync(() => _render().toImage(w, h)))!;
    final data = (await tester
        .runAsync(() => img.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    // Grass cell block of the first theme: at least 4 distinct colours.
    final shades = <int>{};
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 64; x++) {
        shades.add(data.getUint32((y * w + x) * 4));
      }
    }
    final name = Platform.environment['TILE_PREVIEW'];
    if (name != null && name.isNotEmpty) {
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec)..scale(3);
        c.drawImage(
            img, Offset.zero, Paint()..filterQuality = FilterQuality.none);
        final big = await rec.endRecording().toImage(w * 3, h * 3);
        final png = await big.toByteData(format: ui.ImageByteFormat.png);
        File('docs/preview/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    expect(shades.length, greaterThanOrEqualTo(4));
  });
}
