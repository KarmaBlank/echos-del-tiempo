// Town path pieces (town_editor.md § 4.6) in 8-bit minimalist pixel
// art: Tierra (packed dirt), Piedra (flagstones) and Adoquín rúnico
// (slate cobbles set in magitech bronze, a rune glint here and there).
// One 16×16 piece per N / E / S / W neighbour mask (bit 1 N, 2 E, 4 S,
// 8 W, `Autotile.mask4`): the open sides get a rim, the joined ones run
// on into the next tile. Plus a palette icon per material.
//
// Run with `dart run tool/export_path_sprites.dart`. It writes
// assets/sprites/items/vida_path_<id>_<0..15>.png, vida_path_<id>_icon.png
// and the 4x preview at docs/preview/town_paths/path_pieces.png. The game
// never names a file: SpriteCatalog resolves `items.vida_path_<id>_<mask>`
// through sprite_manifest.yaml, so the art can be swapped there.
import 'dart:io';

import 'export_sprites.dart' show RgbaImage, encodePng;

const _n = 1, _e = 2, _s = 4, _w = 8;

class _Pen {
  _Pen(int w, int h) : img = RgbaImage(w, h);
  final RgbaImage img;

  void px(int x, int y, int rgb, [int a = 0xff]) {
    if (x < 0 || y < 0 || x >= img.width || y >= img.height) return;
    final o = (y * img.width + x) * 4;
    img.pixels
      ..[o] = (rgb >> 16) & 0xff
      ..[o + 1] = (rgb >> 8) & 0xff
      ..[o + 2] = rgb & 0xff
      ..[o + 3] = a;
  }

  void rect(int x, int y, int w, int h, int rgb, [int a = 0xff]) {
    for (var j = y; j < y + h; j++) {
      for (var i = x; i < x + w; i++) {
        px(i, j, rgb, a);
      }
    }
  }
}

int _hash(int x, int y, int k) {
  var h = x * 374761393 + y * 668265263 + k * 2246822519;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

/// A material: how to fill the whole tile, then the rim on open sides.
class _Mat {
  const _Mat(this.id, this.fill, this.rim, this.rimLight);
  final String id;
  final void Function(_Pen p, int mask) fill;
  final int rim, rimLight;
}

void _dirt(_Pen p, int mask) {
  p.rect(0, 0, 16, 16, 0x8a6a44);
  for (var k = 0; k < 9; k++) {
    final h = _hash(k, mask, 1);
    p.px(h % 16, (h >> 5) % 16, k.isEven ? 0x6e5234 : 0xa3845a);
  }
  // Two worn wheel ruts along the way it runs.
  final vertical = mask & (_n | _s) != 0 && mask & (_e | _w) == 0;
  for (var i = 0; i < 16; i += 3) {
    if (vertical) {
      p.px(5, i, 0x7a5c3a);
      p.px(10, i + 1, 0x7a5c3a);
    } else {
      p.px(i, 5, 0x7a5c3a);
      p.px(i + 1, 10, 0x7a5c3a);
    }
  }
}

void _stone(_Pen p, int mask) {
  p.rect(0, 0, 16, 16, 0x55524d);
  // Four flagstones, each nudged a pixel so the grid doesn't read.
  for (final (x, y, k) in [(0, 0, 0), (8, 0, 1), (0, 8, 2), (8, 8, 3)]) {
    final h = _hash(k, 7, 2);
    final dx = h % 2, dy = (h >> 3) % 2;
    final tone = (h >> 6) % 2 == 0 ? 0x8f8b84 : 0x7f7c78;
    p.rect(x + 1 + dx, y + 1 + dy, 6 - dx, 6 - dy, tone);
    p.rect(x + 1 + dx, y + 1 + dy, 6 - dx, 1, 0xa8a49c);
    p.px(x + 1 + dx, y + 2 + dy, 0xa8a49c);
    p.rect(x + 1 + dx, y + 6, 6 - dx, 1, 0x6b6863);
  }
}

void _rune(_Pen p, int mask) {
  p.rect(0, 0, 16, 16, 0x3b3846);
  // Running-bond cobbles, slate with a violet cast.
  for (var r = 0; r < 4; r++) {
    final shift = r.isOdd ? 2 : 0;
    for (var c = -1; c < 4; c++) {
      final x0 = c * 4 + shift, y0 = r * 4;
      final h = _hash(c, r, 3);
      final tone = h % 3 == 0 ? 0x77708a : 0x6a647c;
      for (var j = 0; j < 3; j++) {
        for (var i = 0; i < 3; i++) {
          p.px(x0 + i, y0 + j, j == 0 ? 0x8a83a0 : tone);
        }
      }
    }
  }
  // A rune glint on one cobble per piece (which one depends on the mask).
  final g = _hash(mask, 3, 4);
  final gx = 4 + (g % 2) * 6, gy = 4 + ((g >> 2) % 2) * 4;
  p.px(gx, gy, 0x48dbfb);
  p.px(gx + 1, gy, 0x9ff0ff);
  p.px(gx, gy + 1, 0x2a8fb0);
}

const _mats = [
  _Mat('dirt', _dirt, 0x5c4428, 0x7a5c3a),
  _Mat('stone', _stone, 0x3e3c38, 0x6b6863),
  // Bronze inlay along the open sides: the old magitech craft.
  _Mat('rune', _rune, 0x6e5428, 0xb08d57),
];

RgbaImage _piece(_Mat m, int mask) {
  final p = _Pen(16, 16);
  m.fill(p, mask);
  // Open sides: an outer dark rim and an inner light one.
  if (mask & _n == 0) {
    p.rect(0, 0, 16, 1, m.rim);
    p.rect(0, 1, 16, 1, m.rimLight);
  }
  if (mask & _s == 0) {
    p.rect(0, 15, 16, 1, m.rim);
    p.rect(0, 14, 16, 1, m.rimLight);
  }
  if (mask & _w == 0) {
    p.rect(0, 0, 1, 16, m.rim);
    p.rect(1, 1, 1, 14, m.rimLight);
  }
  if (mask & _e == 0) {
    p.rect(15, 0, 1, 16, m.rim);
    p.rect(14, 1, 1, 14, m.rimLight);
  }
  // Rounded outer corners: the corner pixel is see-through.
  for (final (cx, cy, a, b) in [
    (0, 0, _n, _w),
    (15, 0, _n, _e),
    (0, 15, _s, _w),
    (15, 15, _s, _e),
  ]) {
    if (mask & a == 0 && mask & b == 0) p.px(cx, cy, 0, 0);
  }
  return p.img;
}

void main() {
  const out = 'assets/sprites/items';
  final sheet = _Pen(16 * 17 * 4, 16 * _mats.length * 4);
  for (var row = 0; row < _mats.length; row++) {
    final m = _mats[row];
    for (var mask = 0; mask < 16; mask++) {
      final img = _piece(m, mask);
      File('$out/vida_path_${m.id}_$mask.png').writeAsBytesSync(encodePng(img));
      _blit(sheet, img, mask * 64, row * 64);
    }
    // Palette icon: a short straight run, joined E-W.
    final icon = _piece(m, _e | _w);
    File('$out/vida_path_${m.id}_icon.png').writeAsBytesSync(encodePng(icon));
    _blit(sheet, icon, 16 * 64, row * 64);
  }
  Directory('docs/preview/town_paths').createSync(recursive: true);
  File('docs/preview/town_paths/path_pieces.png')
      .writeAsBytesSync(encodePng(sheet.img));
  stdout.writeln('path pieces: ${_mats.length} materials × 17');
}

/// [img] scaled ×4 into [sheet] at ([x], [y]).
void _blit(_Pen sheet, RgbaImage img, int x, int y) {
  for (var j = 0; j < img.height; j++) {
    for (var i = 0; i < img.width; i++) {
      final o = (j * img.width + i) * 4;
      final rgb = img.pixels[o] << 16 | img.pixels[o + 1] << 8 | img.pixels[o + 2];
      sheet.rect(x + i * 4, y + j * 4, 4, 4, rgb, img.pixels[o + 3]);
    }
  }
}
