// The magitec lightning rod (PARARRAYOS, cozy_life.md § 2.1): a brass
// mast on a stone base with a glowing echo crystal in a ring at the top.
// 16x16 procedural pixel art.
//
// Run with `dart run tool/export_lightning_rod_sprite.dart`. It writes
// assets/sprites/items/vida_decor_lightning_rod.png. The game never names
// the file: SpriteCatalog resolves `items.vida_decor_lightning_rod`
// through sprite_manifest.yaml.
import 'dart:io';

import 'export_sprites.dart' show RgbaImage, encodePng;

const _outline = 0x1a1420;
const _stone = 0x8a8f9a;
const _stoneDark = 0x5e6270;
const _stoneLight = 0xb4b9c2;
const _brass = 0xc9a24a;
const _brassDark = 0x7a5a26;
const _brassLight = 0xf0d68a;
const _crystal = 0x6fd3ff;
const _crystalLight = 0xe4f8ff;
const _crystalDark = 0x2f7fb8;

RgbaImage lightningRod() {
  final img = RgbaImage(16, 16);
  void px(int x, int y, int rgb) {
    final o = (y * 16 + x) * 4;
    img.pixels
      ..[o] = (rgb >> 16) & 0xff
      ..[o + 1] = (rgb >> 8) & 0xff
      ..[o + 2] = rgb & 0xff
      ..[o + 3] = 0xff;
  }

  // Stone base (rows 12-15).
  for (var x = 4; x <= 11; x++) {
    px(x, 15, _outline);
    px(x, 12, _outline);
  }
  for (var y = 12; y <= 15; y++) {
    px(3, y, _outline);
    px(12, y, _outline);
  }
  for (var y = 13; y <= 14; y++) {
    for (var x = 4; x <= 11; x++) {
      px(x, y, y == 13 ? _stoneLight : (x.isEven ? _stone : _stoneDark));
    }
  }
  // Mast (rows 4-11), 2 px wide with outline.
  for (var y = 4; y <= 11; y++) {
    px(6, y, _outline);
    px(7, y, _brassLight);
    px(8, y, _brassDark);
    px(9, y, _outline);
  }
  // Brass collars.
  for (final y in [7, 10]) {
    px(6, y, _brass);
    px(9, y, _brass);
    px(5, y, _outline);
    px(10, y, _outline);
  }
  // Ring around the echo crystal (rows 1-4).
  for (final (x, y) in [(5, 1), (10, 1), (4, 2), (11, 2), (4, 3), (11, 3), (5, 4), (10, 4)]) {
    px(x, y, _brass);
  }
  // Crystal.
  px(7, 0, _outline);
  px(8, 0, _outline);
  px(7, 1, _crystalLight);
  px(8, 1, _crystal);
  px(6, 2, _crystal);
  px(7, 2, _crystalLight);
  px(8, 2, _crystal);
  px(9, 2, _crystalDark);
  px(6, 3, _crystalDark);
  px(7, 3, _crystal);
  px(8, 3, _crystal);
  px(9, 3, _crystalDark);
  return img;
}

void main() {
  File('assets/sprites/items/vida_decor_lightning_rod.png')
      .writeAsBytesSync(encodePng(lightningRod()));
  stdout.writeln('Wrote vida_decor_lightning_rod.png.');
}
