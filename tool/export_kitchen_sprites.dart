// The town kitchen (COCINA, farming.md § 17) in procedural pixel art, in
// the style of the ARMERÍA and the TIENDA: a front gable with a warm
// tiled roof over brick and plaster walls, a tall stone chimney with
// smoke, a steaming pot on the gable plate, a hanging bread sign by the
// door, lit windows and a flour sack with firewood. 48 x 48 (3 x 3
// tiles, door at the bottom middle).
//
// Run with `dart run tool/export_kitchen_sprites.dart`. It writes
// assets/sprites/items/vida_cocina.png. The game never names a file:
// SpriteCatalog resolves `items.vida_cocina` through sprite_manifest.yaml.
import 'export_sprites.dart' show RgbaImage;
import 'pixel_pen.dart';

const _woodDark = 0x5c3a20;
const _wood = 0x8a5a32;
const _woodLight = 0xb07a46;
const _stone = 0x8a8f9a;
const _stoneDark = 0x5e6270;
const _stoneLight = 0xb4b8c2;
const _brick = 0xa8503a;
const _brickDark = 0x7a3428;
const _plaster = 0xe8dcb8;
const _plasterDark = 0xc8b48c;
const _roof = 0xc87a3a;
const _roofDark = 0x8e4e26;
const _roofLight = 0xe09a52;
const _glow = 0xf0c870;
const _glowHot = 0xffe0a0;
const _iron = 0x3a3e4a;
const _ironLight = 0x6e7686;
const _bread = 0xd8963e;
const _breadLight = 0xf0c070;
const _sack = 0xd8ccb0;

RgbaImage kitchen() {
  final p = Pen(48, 48);
  // Tall stone chimney behind the roof.
  p.rect(32, 3, 7, 16, _stoneDark);
  p.rect(33, 3, 5, 16, _stone);
  p.rect(31, 2, 9, 2, _stoneLight);
  for (var y = 6; y < 19; y += 3) {
    p.rect(33, y, 5, 1, _stoneDark);
  }
  // Walls: plaster above, brick below.
  p.rect(5, 23, 38, 24, _plaster);
  p.rect(5, 23, 38, 2, _plasterDark);
  p.rect(5, 38, 38, 9, _brick);
  for (var y = 38; y < 47; y += 3) {
    p.rect(5, y, 38, 1, _brickDark);
    for (var x = ((y - 38) ~/ 3).isOdd ? 7 : 9; x < 43; x += 5) {
      p.rect(x, y + 1, 1, 2, _brickDark);
    }
  }
  p.rect(5, 37, 38, 1, _woodDark);
  p.rect(5, 25, 1, 22, _woodDark);
  p.rect(42, 25, 1, 22, _woodDark);
  // Roof eaves and front gable, with tile rows.
  p.rect(2, 20, 44, 3, _roofDark);
  p.rect(2, 20, 44, 1, _roof);
  for (var r = 0; r < 17; r++) {
    final half = r + 3;
    p.rect(24 - half, 4 + r, half * 2, 1, r.isEven ? _roof : _roofDark);
    if (r.isEven) {
      for (var x = 24 - half + 2; x < 24 + half - 1; x += 4) {
        p.px(x, 4 + r, _roofLight);
      }
    }
  }
  // Gable plate: a steaming pot over a small fire.
  p.rect(14, 8, 20, 12, _woodDark);
  p.rect(15, 9, 18, 10, 0x2e2a3a);
  p.oval(18, 12, 12, 6, _iron);
  p.rect(17, 12, 14, 2, _ironLight);
  p.rect(18, 12, 12, 1, 0xdfe6e9);
  p.px(16, 13, _ironLight);
  p.px(31, 13, _ironLight);
  p.rect(21, 18, 6, 1, 0xff7b29);
  p.px(23, 17, 0xffd166);
  p.px(25, 18, 0xffd166);
  // Door with a warm transom.
  p.rect(19, 33, 10, 14, _woodDark);
  p.rect(20, 34, 8, 13, _wood);
  p.rect(20, 34, 8, 2, _glow);
  p.rect(20, 36, 8, 1, _woodDark);
  p.rect(23, 37, 1, 10, _woodDark);
  p.px(26, 41, 0xe0c060);
  // Hanging bread sign on a bracket, left of the door.
  p.rect(10, 31, 7, 1, _woodDark);
  p.px(11, 32, _woodDark);
  p.px(15, 32, _woodDark);
  p.rect(9, 33, 9, 6, _woodDark);
  p.rect(10, 34, 7, 4, 0x2e2a3a);
  p.oval(10, 34, 7, 4, _bread);
  p.rect(12, 34, 3, 1, _breadLight);
  p.px(12, 36, _woodDark);
  p.px(14, 35, _woodDark);
  // Lit windows with a herb bundle and a ladle inside.
  for (final wx in [8, 33]) {
    p.rect(wx, 26, 7, 7, _woodDark);
    p.rect(wx + 1, 27, 5, 5, _glow);
    p.rect(wx + 1, 27, 2, 2, _glowHot);
    p.rect(wx + 1, 29, 5, 1, _woodDark);
    p.rect(wx + 3, 27, 1, 5, _woodDark);
  }
  // Flour sack and firewood by the right corner.
  p.round(35, 40, 7, 7, _sack);
  p.rect(37, 39, 3, 1, _woodLight);
  p.px(38, 43, _woodDark);
  for (final (x, y) in [(3, 43), (6, 43), (4, 40)]) {
    p.oval(x, y, 4, 4, _wood);
    p.px(x + 1, y + 1, _woodLight);
    p.px(x + 2, y + 2, _woodDark);
  }
  p.outline();
  // Smoke over the chimney and steam over the pot (soft, after outline).
  for (final (x, y, a) in [(34, 0, 0x60), (35, 1, 0x90), (37, 0, 0x50)]) {
    p.px(x, y, 0xc8ccd4, a);
    p.px(x + 1, y, 0xc8ccd4, a);
  }
  for (final x in [20, 24, 28]) {
    for (final (dx, dy) in [(0, 11), (1, 10), (0, 9)]) {
      p.px(x + dx, dy, 0xdfe6e9, 0xb0 - (11 - dy) * 0x28);
    }
  }
  return p.img;
}

void main() {
  writePng('assets/sprites/items/vida_cocina.png', kitchen());
}
