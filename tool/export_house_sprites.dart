// Residents' houses (town_editor.md § 3.4) in procedural pixel art, in the
// style of the ARMERÍA and the TIENDA: a front gable with a tiled roof,
// timber, plank or stone walls, a framed door, shuttered windows with
// flower boxes, a chimney and small props. One sprite per level (1-3)
// and colour variant (0-2), all 48 x 48 (3 x 3 tiles, door at the
// bottom middle).
//
// Run with `dart run tool/export_house_sprites.dart`. It writes
// assets/sprites/items/vida_casa_<level>.png (variant 0) and
// vida_casa_<level>_v<variant>.png (variants 1 and 2). The game never
// names a file: SpriteCatalog resolves `items.vida_casa_*` through
// sprite_manifest.yaml.
import 'dart:io';

import 'export_sprites.dart' show RgbaImage;
import 'pixel_pen.dart';

const _woodDark = 0x5c3a20;
const _wood = 0x8a5a32;
const _woodLight = 0xb07a46;
const _glass = 0x24324a;
const _glassLit = 0xf0c870;
const _gold = 0xe0c060;
const _stone = 0x8a8f9a;
const _stoneDark = 0x5e6270;
const _stoneLight = 0xb4b8c2;

/// Colours of one house variant.
class HouseStyle {
  const HouseStyle(this.roof, this.wall, this.shutter, this.walls);

  /// Roof ramp: light, mid, dark.
  final List<int> roof;

  /// Wall ramp: light, mid, dark.
  final List<int> wall;

  /// Shutter colour.
  final int shutter;

  /// `plaster` (timber framed), `planks` or `stone`.
  final String walls;
}

const kHouseStyles = [
  // Terracotta tiles over timber-framed plaster, green shutters.
  HouseStyle([0xd0704a, 0xa84e36, 0x6e2a22], [0xe8dcb8, 0xd8c8a0, 0xb8a47c],
      0x3a7a4a, 'plaster'),
  // Slate tiles over warm planks, red shutters.
  HouseStyle([0x6a8aaa, 0x46668a, 0x2a4462], [0xb07a46, 0x8a5a32, 0x6a4226],
      0xa83a3a, 'planks'),
  // Moss tiles over a stone cottage, blue shutters.
  HouseStyle([0x8aa45a, 0x5e7e3e, 0x3a5228], [0xc4b8a0, 0xa89a80, 0x7e7262],
      0x3a6a9a, 'stone'),
];

/// Apex row and the eave row of the front gable.
const _apex = 3, _eave = 22;

int _half(int y) => y - _apex + 2;

RgbaImage house(int level, HouseStyle s) {
  final p = Pen(48, 48);
  // Chimney behind the roof (levels 2 and 3).
  if (level >= 2) {
    p.rect(33, 4, 6, 14, _stoneDark);
    p.rect(34, 4, 4, 14, _stone);
    p.rect(32, 3, 8, 2, _stoneLight);
    p.rect(32, 4, 8, 1, _stoneDark);
    for (var y = 7; y < 18; y += 3) {
      p.rect(34, y, 4, 1, _stoneDark);
    }
  }
  _walls(p, s, level);
  _roof(p, s, level);
  _door(p, s, level);
  // Windows: level 1 has one, then two.
  _window(p, s, 8, 29, box: level >= 2);
  if (level >= 2) _window(p, s, 33, 29, box: true);
  if (level == 1) {
    // A wall lantern by the door and a small woodpile on the right.
    p.rect(31, 31, 3, 4, _woodDark);
    p.rect(32, 32, 1, 2, _glassLit);
    for (final (x, y) in [(34, 43), (37, 43), (35, 40)]) {
      p.oval(x, y, 4, 4, _wood);
      p.px(x + 1, y + 1, _woodLight);
      p.px(x + 2, y + 2, _woodDark);
    }
  }
  if (level == 3) {
    // Barrel and a planter at the corners.
    p.rect(2, 39, 6, 8, _wood);
    p.rect(3, 39, 4, 1, _woodLight);
    p.rect(2, 41, 6, 1, 0x4a4e5a);
    p.rect(2, 45, 6, 1, 0x4a4e5a);
    p.rect(6, 40, 1, 7, _woodDark);
    p.rect(40, 42, 7, 5, _woodDark);
    p.rect(41, 42, 5, 1, _woodLight);
    for (final (x, y, c) in [
      (41, 40, 0x4e8a4a),
      (43, 39, 0x6aaa5a),
      (45, 40, 0x4e8a4a),
      (42, 39, 0xe84393),
      (44, 38, 0xffd166),
    ]) {
      p.rect(x, y, 1, 3, c);
    }
  }
  p.outline();
  // Smoke from the chimney (after the outline: soft).
  if (level >= 2) {
    for (final (x, y, a) in [(35, 1, 0x80), (36, 0, 0x60), (34, 0, 0x40)]) {
      p.px(x, y, 0xc8ccd4, a);
      p.px(x + 1, y, 0xc8ccd4, a);
    }
  }
  return p.img;
}


void _walls(Pen p, HouseStyle s, int level) {
  final [light, mid, dark] = s.wall;
  const x0 = 5, x1 = 43, y0 = 23, y1 = 47;
  p.rect(x0, y0, x1 - x0, y1 - y0, mid);
  switch (s.walls) {
    case 'plaster':
      // Light plaster with a soft top shade and timber frame.
      p.rect(x0, y0, x1 - x0, 2, dark);
      for (var y = y0 + 3; y < y1; y += 5) {
        p.px(x0 + 3 + (y * 7) % 30, y, light);
        p.px(x0 + 9 + (y * 13) % 26, y + 2, dark);
      }
      p.rect(x0, y0 + 2, x1 - x0, 1, _woodDark);
      p.rect(x0, 38, x1 - x0, 1, _woodDark);
      for (final x in [x0, 17, 30, x1 - 1]) {
        p.rect(x, y0 + 2, 1, y1 - y0 - 2, _woodDark);
      }
      p.line(6, 37, 16, 27, _woodDark);
      p.line(42, 37, 31, 27, _woodDark);
    case 'planks':
      for (var x = x0; x < x1; x += 4) {
        p.rect(x, y0, 1, y1 - y0, dark);
        p.rect(x + 1, y0, 1, y1 - y0, light);
        // Knots and plank ends.
        p.px(x + 2, y0 + 4 + (x * 5) % 14, dark);
        p.rect(x + 1, y0 + 9 + (x * 3) % 10, (x1 - x - 1).clamp(0, 3), 1, dark);
      }
      p.rect(x0, y0, x1 - x0, 2, dark);
      p.rect(x0, y0, 2, y1 - y0, _woodDark);
      p.rect(x1 - 2, y0, 2, y1 - y0, _woodDark);
    default:
      // Rough stone courses.
      for (var y = y0; y < y1; y += 4) {
        p.rect(x0, y, x1 - x0, 1, dark);
        final off = ((y - y0) ~/ 4).isOdd ? 3 : 0;
        for (var x = x0 + off; x < x1; x += 6) {
          p.rect(x, y + 1, 1, 3, dark);
          p.rect(x + 1, y + 1, (x1 - x - 1).clamp(0, 4), 1, light);
        }
      }
      // Quoins at the corners.
      for (var y = y0; y < y1; y += 4) {
        final k = ((y - y0) ~/ 4).isEven ? 4 : 2;
        p.rect(x0, y, k, 3, _stoneLight);
        p.rect(x1 - k, y, k, 3, _stoneLight);
      }
  }
  // Stone plinth (except the stone cottage) and the eave shadow.
  if (s.walls != 'stone') {
    p.rect(x0, 44, x1 - x0, 3, _stoneDark);
    for (var x = x0 + 2; x < x1 - 2; x += 5) {
      p.rect(x, 44, 3, 1, _stone);
    }
  }
  p.rect(x0, y0, x1 - x0, 1, 0x2a1e1a, 0xa0);
}

void _roof(Pen p, HouseStyle s, int level) {
  final [light, mid, dark] = s.roof;
  final [wLight, wMid, wDark] = s.wall;
  for (var y = _apex; y <= _eave; y++) {
    final half = _half(y);
    final inner = half - 7;
    final course = (y - _apex) % 3;
    for (var x = 24 - half; x < 24 + half; x++) {
      final d = (x + 0.5 - 24).abs();
      if (inner > 0 && d < inner && y < _eave - 1) {
        // Gable wall inside the roof.
        p.px(x, y, s.walls == 'stone' ? wMid : (s.walls == 'planks' ? wDark : wLight));
        continue;
      }
      // Tile courses: light top row, mid, dark lip; staggered seams.
      var c = course == 0 ? light : (course == 1 ? mid : dark);
      final stagger = ((y - _apex) ~/ 3).isOdd ? 2 : 0;
      if ((x + stagger) % 4 == 0 && course != 0) c = dark;
      p.px(x, y, c);
    }
  }
  // Bargeboards along both slopes and the eave line.
  for (var y = _apex; y <= _eave; y++) {
    final half = _half(y);
    p.px(24 - half, y, _woodLight);
    p.px(24 + half - 1, y, _woodLight);
    final inner = half - 7;
    if (inner > 0 && y < _eave - 1) {
      p.px(24 - inner - 1, y, _woodDark);
      p.px(24 + inner, y, _woodDark);
    }
  }
  p.rect(1, _eave, 46, 1, dark);
  p.rect(2, _eave - 1, 44, 1, _woodDark);
  // Ridge cap and finial.
  p.rect(22, _apex - 1, 4, 2, dark);
  p.px(23, _apex - 2, _woodLight);
  p.px(24, _apex - 2, _woodLight);
  // Gable details: timber on plaster, plank seams, and the attic window.
  if (s.walls == 'plaster') {
    p.rect(24, 12, 1, 9, _woodDark);
    p.rect(17, 19, 15, 1, _woodDark);
  } else if (s.walls == 'planks') {
    for (var x = 20; x < 30; x += 3) {
      p.rect(x, 12, 1, 8, wMid);
    }
  } else {
    p.rect(19, 16, 11, 1, wDark);
  }
  if (level >= 2) {
    // Round attic window, lit warm at level 3.
    p.oval(21, 12, 7, 7, _woodDark);
    p.oval(22, 13, 5, 5, level == 3 ? _glassLit : _glass);
    p.rect(24, 13, 1, 5, _woodDark);
    p.rect(22, 15, 5, 1, _woodDark);
    if (level < 3) p.px(23, 14, 0x6a86a8);
  } else {
    // A small vent slot.
    p.rect(22, 15, 5, 3, _woodDark);
    p.rect(23, 16, 3, 1, 0x2e2a3a);
  }
}

void _door(Pen p, HouseStyle s, int level) {
  // Stone frame with an arched top, plank door, iron straps, a step.
  p.round(18, 32, 12, 15, _stoneLight);
  p.rect(19, 33, 10, 14, _stoneDark);
  p.round(20, 34, 8, 13, _wood);
  p.rect(20, 35, 1, 12, _woodLight);
  p.rect(23, 35, 1, 12, _woodDark);
  p.rect(25, 35, 1, 12, _woodDark);
  p.rect(20, 37, 8, 1, 0x4a4e5a);
  p.rect(20, 43, 8, 1, 0x4a4e5a);
  p.px(26, 40, _gold);
  p.rect(17, 46, 14, 1, _stone);
  if (level == 3) {
    // Little canopy over the door, roof-coloured, with two brackets.
    p.rect(16, 29, 16, 2, s.roof[1]);
    p.rect(16, 29, 16, 1, s.roof[0]);
    p.rect(16, 31, 16, 1, s.roof[2]);
    p.px(17, 32, _woodDark);
    p.px(30, 32, _woodDark);
  }
  // Door mat.
  p.rect(20, 47, 8, 1, 0xa83a3a);
}

void _window(Pen p, HouseStyle s, int x, int y, {required bool box}) {
  // Frame, panes with a cross and a glint, shutters, sill.
  p.rect(x, y, 7, 8, _woodDark);
  p.rect(x + 1, y + 1, 5, 6, _glass);
  p.rect(x + 1, y + 1, 5, 2, 0x34466a);
  p.rect(x + 3, y + 1, 1, 6, _woodDark);
  p.rect(x + 1, y + 4, 5, 1, _woodDark);
  p.px(x + 1, y + 1, 0x8aa6c8);
  p.px(x + 4, y + 5, _glassLit);
  for (final sx in [x - 3, x + 7]) {
    p.rect(sx, y, 3, 8, s.shutter);
    p.rect(sx, y, 3, 1, 0xffffff, 0x50);
    p.rect(sx + 1, y + 2, 1, 1, _woodDark);
    p.rect(sx + 1, y + 5, 1, 1, _woodDark);
  }
  p.rect(x - 1, y + 8, 9, 1, _woodLight);
  if (!box) return;
  // Flower box with leaves and blooms.
  p.rect(x - 1, y + 9, 9, 3, _wood);
  p.rect(x - 1, y + 11, 9, 1, _woodDark);
  for (var k = 0; k < 9; k++) {
    p.px(x - 1 + k, y + 8, k.isEven ? 0x4e8a4a : 0x6aaa5a);
  }
  for (final (k, c) in [(0, 0xe84393), (3, 0xffd166), (6, 0xff7b7b)]) {
    p.px(x + k, y + 7, c);
  }
}

void main() {
  for (var lv = 1; lv <= 3; lv++) {
    for (var v = 0; v < kHouseStyles.length; v++) {
      final name = v == 0 ? 'vida_casa_$lv' : 'vida_casa_${lv}_v$v';
      writePng('assets/sprites/items/$name.png', house(lv, kHouseStyles[v]));
    }
  }
  stdout.writeln('Wrote 9 house sprites.');
}
