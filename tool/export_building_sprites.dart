// Town building sprites in procedural pixel art: the ARMERÍA (an
// equipment shop with a sword-and-shields emblem) and the FORJA (a
// hearth with a glowing anvil stall).
//
// Run with `dart run tool/export_building_sprites.dart`. It writes
// assets/sprites/items/vida_armeria.png, vida_forja.png, vida_tienda.png
// and the 4x
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
    final n =
        [(x1 - x0).abs(), (y1 - y0).abs(), 1].reduce((a, b) => a > b ? a : b);
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

const _plaster = 0xd8c8a0;
const _plasterDark = 0xb8a47c;
const _slate = 0x3a5a7a;
const _slateDark = 0x26405a;
const _woodLight = 0xb07a46;

/// A small barrel of 7 x 8 with two hoops.
void _barrel(_Pen p, int x, int y) {
  p.rect(x, y, 7, 8, _wood);
  p.rect(x + 1, y, 5, 1, _woodLight);
  p.rect(x, y + 2, 7, 1, _metalDark);
  p.rect(x, y + 5, 7, 1, _metalDark);
  p.rect(x + 5, y + 1, 1, 7, _woodDark);
}

/// TALLER DE OFICIOS: 48 x 48, same build as the ARMERIA (gable, eaves,
/// door, two windows) in timber-framed plaster under a slate roof. The
/// gable carries a crossed hammer and saw; barrels, a chimney and a
/// small anvil tell the crafts apart from the armory's weapons.
RgbaImage workshop() {
  final p = _Pen(48, 48);
  // Chimney (behind the roof).
  p.rect(34, 6, 6, 12, _stoneDark);
  p.rect(34, 6, 6, 1, _stone);
  // Timber-framed walls.
  p.rect(5, 24, 38, 23, _plaster);
  p.rect(5, 44, 38, 3, _plasterDark);
  p.rect(5, 24, 38, 2, _woodDark);
  p.rect(5, 37, 38, 1, _woodDark);
  for (final x in [5, 17, 30, 42]) {
    p.rect(x, 24, 1, 23, _woodDark);
  }
  p.line(6, 26, 16, 36, _woodDark);
  p.line(41, 26, 31, 36, _woodDark);
  // Roof eaves and front gable, slate rows.
  p.rect(2, 21, 44, 3, _slateDark);
  for (var r = 0; r < 17; r++) {
    final half = r + 3;
    p.rect(24 - half, 4 + r, half * 2, 1, r.isEven ? _slate : _slateDark);
  }
  // Sign plate with a crossed hammer and saw.
  p.rect(13, 8, 22, 13, _woodDark);
  p.rect(14, 9, 20, 11, 0x2e2a3a);
  // Saw: blade with teeth, handle bottom-right.
  p.line(18, 10, 30, 18, _metal);
  p.line(19, 10, 31, 18, _metalLight);
  for (var k = 0; k < 6; k++) {
    p.px(18 + k * 2, 12 + (k * 4) ~/ 3, _metalDark);
  }
  p.rect(30, 17, 3, 3, _wood);
  // Hammer: handle and head.
  p.line(17, 19, 28, 10, _woodLight);
  p.rect(26, 9, 5, 3, _metalDark);
  p.rect(26, 9, 5, 1, _metal);
  // Door.
  p.rect(19, 34, 10, 13, _woodDark);
  p.rect(20, 35, 8, 12, _wood);
  p.rect(23, 35, 1, 12, _woodDark);
  p.px(26, 41, 0xe0c060);
  // Windows: tools hanging inside.
  for (final wx in [8, 33]) {
    p.rect(wx, 28, 7, 7, _woodDark);
    p.rect(wx + 1, 29, 5, 5, 0x24324a);
    p.rect(wx + 1, 31, 5, 1, _woodDark);
    p.line(wx + 2, 29, wx + 2, 33, _woodLight);
    p.rect(wx + 1, 29, 3, 1, _metal);
    p.line(wx + 4, 30, wx + 4, 33, _metal);
  }
  // Barrels by the wall and an anvil on a stump at the corner.
  _barrel(p, 3, 39);
  _barrel(p, 10, 40);
  p.rect(36, 43, 6, 4, _woodDark);
  p.rect(34, 40, 10, 2, 0x6e7686);
  p.rect(34, 40, 10, 1, _metalLight);
  p.rect(37, 42, 4, 1, _metalDark);
  p.rect(32, 40, 2, 1, 0x6e7686);
  p.outline();
  // Smoke puffs over the chimney (after outline: soft).
  for (final (x, y, a) in [(36, 4, 0x90), (37, 2, 0x70), (35, 1, 0x50)]) {
    p.px(x, y, 0xc8ccd4, a);
    p.px(x + 1, y, 0xc8ccd4, a);
  }
  return p.img;
}

/// Fence piece for autotile [mask] (bit 1 N, 2 E, 4 S, 8 W): a post in
/// the middle and rails toward each connected side.
RgbaImage fence(int mask) {
  final p = _Pen(16, 16);
  if (mask & 2 != 0) _rails(p, 9, 7);
  if (mask & 8 != 0) _rails(p, 0, 7);
  if (mask & 1 != 0) _beam(p, 0, 4);
  if (mask & 4 != 0) _beam(p, 12, 4);
  _post(p, 6);
  p.outline();
  return p.img;
}

void _rails(_Pen p, int x, int w) {
  for (final y in [5, 10]) {
    p.rect(x, y, w, 1, _woodLight);
    p.rect(x, y + 1, w, 1, _woodDark);
  }
}

void _beam(_Pen p, int y, int h) {
  p.rect(7, y, 2, h, _wood);
  p.rect(7, y, 1, h, _woodLight);
}

void _post(_Pen p, int x) {
  p.rect(x, 3, 4, 11, _wood);
  p.rect(x, 3, 4, 1, _woodLight);
  p.rect(x + 3, 4, 1, 10, _woodDark);
}

/// Fence gate: [vertical] runs N-S between two posts, else E-W.
RgbaImage fenceGate({required bool vertical}) {
  final p = _Pen(16, 16);
  if (vertical) {
    p.rect(6, 0, 4, 3, _wood);
    p.rect(6, 0, 4, 1, _woodLight);
    p.rect(6, 13, 4, 3, _wood);
    p.rect(6, 13, 4, 1, _woodLight);
    p.rect(7, 3, 3, 10, _woodLight);
    p.rect(9, 3, 1, 10, _woodDark);
    p.rect(7, 5, 3, 1, _woodDark);
    p.rect(7, 10, 3, 1, _woodDark);
    p.px(6, 4, _metalDark);
    p.px(6, 11, _metalDark);
  } else {
    p.rect(0, 3, 3, 11, _wood);
    p.rect(0, 3, 3, 1, _woodLight);
    p.rect(13, 3, 3, 11, _wood);
    p.rect(13, 3, 3, 1, _woodLight);
    for (var x = 3; x < 13; x += 2) {
      p.rect(x, 5, 1, 8, _woodLight);
      p.rect(x + 1, 5, 1, 8, _wood);
    }
    p.rect(3, 6, 10, 1, _woodDark);
    p.rect(3, 11, 10, 1, _woodDark);
    p.line(3, 11, 12, 6, _woodDark);
    p.px(3, 7, _metalDark);
    p.px(3, 10, _metalDark);
  }
  p.outline();
  return p.img;
}

/// TIENDA (player_shop.md § 6): 48 x 48, same build as the ARMERÍA in
/// timber: plank walls, a green gable with a coin-pouch emblem, a
/// striped awning over the door and crates of goods in the windows.
RgbaImage playerShop() {
  final p = _Pen(48, 48);
  const roof = 0x3a7a4a, roofDark = 0x285a34, gold = 0xe0c060;
  // Plank walls.
  p.rect(5, 24, 38, 23, _wood);
  for (var x = 5; x < 43; x += 4) {
    p.rect(x, 24, 1, 23, _woodDark);
  }
  p.rect(5, 24, 2, 23, _woodDark);
  p.rect(41, 24, 2, 23, _woodDark);
  // Roof eaves and front gable.
  p.rect(2, 21, 44, 3, roofDark);
  for (var r = 0; r < 17; r++) {
    final half = r + 3;
    p.rect(24 - half, 4 + r, half * 2, 1, r.isEven ? roof : roofDark);
  }
  // Emblem plate: a coin pouch with two coins.
  p.rect(14, 8, 20, 12, _woodDark);
  p.rect(15, 9, 18, 10, 0x2e2a3a);
  p.rect(20, 12, 8, 6, 0xb07a44);
  p.rect(21, 11, 6, 1, 0xb07a44);
  p.rect(22, 10, 4, 1, _woodDark);
  p.px(24, 14, gold);
  p.rect(16, 15, 3, 3, gold);
  p.rect(29, 15, 3, 3, gold);
  p.px(17, 16, 0xffd166);
  p.px(30, 16, 0xffd166);
  // Striped awning over the door.
  for (var x = 15; x < 33; x++) {
    p.rect(x, 30, 1, 3, ((x - 15) ~/ 3).isEven ? 0xdfe6e9 : 0xa83a3a);
  }
  // Door.
  p.rect(19, 34, 10, 13, _woodDark);
  p.rect(20, 35, 8, 12, 0x6e4426);
  p.rect(23, 35, 1, 12, _woodDark);
  p.px(26, 41, gold);
  // Windows with crates of goods.
  for (final wx in [7, 34]) {
    p.rect(wx, 33, 7, 7, _woodDark);
    p.rect(wx + 1, 34, 5, 5, 0x24324a);
    p.rect(wx + 1, 37, 5, 2, 0xb07a44);
    p.px(wx + 2, 36, 0xa83a3a);
    p.px(wx + 4, 36, gold);
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
    (6, 11, 0x60),
    (19, 11, 0x60),
    (13, 11, 0x50),
    (31, 6, 0x50),
    (35, 6, 0x60),
    (38, 6, 0x50),
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
  File('assets/sprites/items/vida_tienda.png')
      .writeAsBytesSync(encodePng(playerShop()));
  File('docs/release_shots/building_icons_preview.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(encodePng(_preview(a, f)));
  File('assets/sprites/items/vida_taller_oficios.png')
      .writeAsBytesSync(encodePng(workshop()));
  for (var m = 0; m < 16; m++) {
    File('assets/sprites/items/vida_decor_fence_$m.png')
        .writeAsBytesSync(encodePng(fence(m)));
  }
  // Palette icons: a straight E-W run and the E-W gate.
  File('assets/sprites/items/vida_decor_fence.png')
      .writeAsBytesSync(encodePng(fence(2 | 8)));
  File('assets/sprites/items/vida_decor_fence_gate_h.png')
      .writeAsBytesSync(encodePng(fenceGate(vertical: false)));
  File('assets/sprites/items/vida_decor_fence_gate_v.png')
      .writeAsBytesSync(encodePng(fenceGate(vertical: true)));
  File('assets/sprites/items/vida_decor_fence_gate.png')
      .writeAsBytesSync(encodePng(fenceGate(vertical: false)));
  stdout.writeln('Wrote the building and fence sprites and the preview.');
}
