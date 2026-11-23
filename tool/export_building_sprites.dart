// Town building sprites in procedural pixel art: the ARMERÍA (an
// equipment shop with a sword-and-shields emblem) and the FORJA (a
// hearth with a glowing anvil stall).
//
// Run with `dart run tool/export_building_sprites.dart`. It writes
// assets/sprites/items/vida_armeria.png, vida_forja.png and the 4x
// preview at docs/release_shots/building_icons_preview.png. The game never
// names a file: SpriteCatalog resolves `items.vida_armeria` /
// `items.vida_forja` through sprite_manifest.yaml, so the art can be
// swapped there without touching Dart.
import 'dart:io';

import 'export_sprites.dart' show RgbaImage, encodePng;

const _outline = 0x1a1420;
const _wood = 0x8a5a32;
const _woodDark = 0x5c3a20;
const _metal = 0xa8b0bc;
const _metalLight = 0xdfe6e9;
const _metalDark = 0x4a4e5a;
const _stone = 0x8a8f9a;
const _stoneDark = 0x5e6270;
const _roof = 0x8a3a3a;
const _roofDark = 0x5e2626;
const _ember = 0xff7b29;
const _emberHot = 0xffd166;

class _Pen {
  _Pen(int w, int h) : img = RgbaImage(w, h);
  final RgbaImage img;
  int get w => img.width;
  int get h => img.height;

  void px(int x, int y, int rgb, [int a = 0xff]) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final o = (y * w + x) * 4;
    img.pixels
      ..[o] = (rgb >> 16) & 0xff
      ..[o + 1] = (rgb >> 8) & 0xff
      ..[o + 2] = rgb & 0xff
      ..[o + 3] = a;
  }

  void rect(int x, int y, int rw, int rh, int rgb, [int a = 0xff]) {
    for (var j = y; j < y + rh; j++) {
      for (var i = x; i < x + rw; i++) {
        px(i, j, rgb, a);
      }
    }
  }

  void line(int x0, int y0, int x1, int y1, int rgb) {
    final n = [(x1 - x0).abs(), (y1 - y0).abs(), 1]
        .reduce((a, b) => a > b ? a : b);
    for (var k = 0; k <= n; k++) {
      px((x0 + (x1 - x0) * k / n).round(), (y0 + (y1 - y0) * k / n).round(),
          rgb);
    }
  }

  /// Dark outline around everything painted so far.
  void outline() {
    final p = img.pixels;
    bool on(int x, int y) =>
        x >= 0 && y >= 0 && x < w && y < h && p[(y * w + x) * 4 + 3] != 0;
    final add = <(int, int)>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (on(x, y)) continue;
        if (on(x - 1, y) || on(x + 1, y) || on(x, y - 1) || on(x, y + 1)) {
          add.add((x, y));
        }
      }
    }
    for (final (x, y) in add) {
      px(x, y, _outline);
    }
  }
}

/// Kite shield of 7 x 8 with a rim and a central boss.
void _shield(_Pen p, int x, int y, int face) {
  p.rect(x, y, 7, 5, _metal);
  p.rect(x + 1, y + 5, 5, 2, _metal);
  p.px(x + 3, y + 7, _metal);
  p.rect(x + 1, y + 1, 5, 4, face);
  p.rect(x + 2, y + 5, 3, 1, face);
  p.px(x + 3, y + 2, _metalLight);
}

/// ARMERÍA: 48 x 48, stone shop with a front gable that carries a sword
/// over two shields, plus weapon racks behind the windows.
RgbaImage armory() {
  final p = _Pen(48, 48);
  // Walls.
  p.rect(5, 24, 38, 23, _stone);
  for (var y = 27; y < 47; y += 4) {
    p.rect(5, y, 38, 1, _stoneDark);
    for (var x = ((y - 27) ~/ 4).isOdd ? 9 : 5; x < 43; x += 8) {
      p.rect(x, y - 3, 1, 3, _stoneDark);
    }
  }
  // Roof eaves and front gable.
  p.rect(2, 21, 44, 3, _roofDark);
  for (var r = 0; r < 17; r++) {
    final half = r + 3;
    p.rect(24 - half, 4 + r, half * 2, 1, r.isEven ? _roof : _roofDark);
  }
  // Emblem plate on the gable.
  p.rect(12, 7, 24, 14, _woodDark);
  p.rect(13, 8, 22, 12, 0x2e2a3a);
  _shield(p, 14, 10, 0x3a6a9a);
  _shield(p, 27, 10, 0xa83a3a);
  // Sword over the shields, diagonal.
  p.line(17, 19, 31, 7, _metalLight);
  p.line(18, 19, 31, 8, _metal);
  p.line(19, 13, 23, 17, 0xe0c060); // crossguard
  p.rect(16, 19, 2, 2, _woodDark); // grip
  p.px(15, 21, 0xe0c060); // pommel
  // Door.
  p.rect(19, 34, 10, 13, _woodDark);
  p.rect(20, 35, 8, 12, _wood);
  p.rect(23, 35, 1, 12, _woodDark);
  p.px(26, 41, 0xe0c060);
  // Windows with a sword rack inside.
  for (final wx in [8, 33]) {
    p.rect(wx, 29, 7, 7, _woodDark);
    p.rect(wx + 1, 30, 5, 5, 0x24324a);
    p.line(wx + 2, 30, wx + 2, 34, _metalLight);
    p.line(wx + 4, 30, wx + 4, 34, _metal);
    p.rect(wx + 1, 32, 5, 1, _wood);
  }
  p.outline();
  return p.img;
}

/// FORJA: 80 x 32 (five tiles wide, one tile tall plus one above). Stone
/// platform, brick hearth with embers, a big anvil with a hammer and a
/// quenching barrel.
RgbaImage forge() {
  final p = _Pen(80, 32);
  // Platform (the walkable-edge row of the landmark).
  p.rect(0, 20, 80, 12, 0x3d3d4a);
  p.rect(0, 19, 80, 3, 0x8395a7);
  // Hearth and chimney.
  p.rect(9, 1, 8, 8, _stoneDark);
  p.rect(9, 1, 8, 1, _stone);
  p.rect(3, 8, 20, 12, 0x7a3e2c);
  for (var y = 10; y < 20; y += 3) {
    p.rect(3, y, 20, 1, 0x5a2c20);
  }
  p.rect(7, 12, 12, 7, 0x2a1410);
  p.rect(8, 16, 10, 3, _ember);
  for (final (x, y) in [(9, 15), (12, 14), (15, 15), (11, 17), (14, 17)]) {
    p.px(x, y, _emberHot);
  }
  // Anvil: feet, waist, face, horn and heel.
  p.rect(33, 17, 14, 2, _metalDark);
  p.rect(36, 14, 8, 3, _metalDark);
  p.rect(38, 12, 4, 2, _metalDark);
  p.rect(30, 8, 20, 4, 0x6e7686);
  p.rect(30, 8, 20, 1, _metalLight);
  p.rect(25, 8, 5, 2, 0x6e7686);
  p.rect(22, 8, 3, 1, 0x6e7686);
  p.px(25, 8, _metalLight);
  p.rect(50, 8, 3, 2, 0x6e7686);
  // Hammer resting on the face.
  p.line(44, 7, 52, 3, _wood);
  p.rect(41, 5, 4, 3, _metalDark);
  // Hot bar on the anvil.
  p.rect(32, 7, 7, 1, _ember);
  p.px(33, 7, _emberHot);
  // Quenching barrel and a tongs rack.
  p.rect(60, 10, 11, 10, _wood);
  p.rect(60, 12, 11, 1, _metalDark);
  p.rect(60, 17, 11, 1, _metalDark);
  p.rect(61, 10, 9, 1, 0x3a6a9a);
  p.line(74, 4, 74, 18, _woodDark);
  p.line(72, 6, 77, 6, _woodDark);
  p.line(73, 7, 73, 12, _metal);
  p.line(76, 7, 76, 12, _metal);
  p.outline();
  // Soft glow around the hearth mouth and the hot bar (after outline).
  for (final (x, y, a) in [
    (6, 11, 0x60), (19, 11, 0x60), (13, 11, 0x50),
    (31, 6, 0x50), (35, 6, 0x60), (38, 6, 0x50),
  ]) {
    p.px(x, y, _ember, a);
  }
  return p.img;
}

/// Nearest-neighbour upscale of [src] by [k].
RgbaImage _scale(RgbaImage src, int k) {
  final out = RgbaImage(src.width * k, src.height * k);
  for (var y = 0; y < out.height; y++) {
    for (var x = 0; x < out.width; x++) {
      final s = ((y ~/ k) * src.width + x ~/ k) * 4;
      final d = (y * out.width + x) * 4;
      for (var c = 0; c < 4; c++) {
        out.pixels[d + c] = src.pixels[s + c];
      }
    }
  }
  return out;
}

/// Both sprites side by side over a grass-like backdrop, scaled 4x.
RgbaImage _preview(RgbaImage a, RgbaImage f) {
  const pad = 8;
  final w = pad * 3 + a.width + f.width;
  final h = pad * 2 + a.height;
  final out = RgbaImage(w, h);
  for (var i = 0; i < w * h; i++) {
    out.pixels
      ..[i * 4] = 0x3f
      ..[i * 4 + 1] = 0x6e
      ..[i * 4 + 2] = 0x3a
      ..[i * 4 + 3] = 0xff;
  }
  void blit(RgbaImage s, int ox, int oy) {
    for (var y = 0; y < s.height; y++) {
      for (var x = 0; x < s.width; x++) {
        final so = (y * s.width + x) * 4;
        final al = s.pixels[so + 3] / 255;
        if (al == 0) continue;
        final d = ((oy + y) * w + ox + x) * 4;
        for (var c = 0; c < 3; c++) {
          out.pixels[d + c] =
              (s.pixels[so + c] * al + out.pixels[d + c] * (1 - al)).round();
        }
      }
    }
  }

  blit(a, pad, pad);
  blit(f, pad * 2 + a.width, pad + a.height - f.height);
  return _scale(out, 4);
}

void main() {
  final a = armory();
  final f = forge();
  File('assets/sprites/items/vida_armeria.png').writeAsBytesSync(encodePng(a));
  File('assets/sprites/items/vida_forja.png').writeAsBytesSync(encodePng(f));
  File('docs/release_shots/building_icons_preview.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(encodePng(_preview(a, f)));
  stdout.writeln('Wrote vida_armeria.png, vida_forja.png and the preview.');
}
