// The players' own house (player_house.md) in procedural 8-bit pixel art:
// the outside (a cosy cottage with a red roof, chimney, two lit windows
// and a door in the bottom middle) and the inside (plank floor, plaster
// walls with wainscot, a window on the back wall, four beds, a rug, a
// plant and the door gap at the bottom).
//
// Run with `dart run tool/export_player_house_sprites.dart`. It writes
// assets/sprites/items/vida_home_exterior.png (4 x 3 tiles, 64 x 48) and
// vida_home_room.png (the whole 12 x 8 room, 192 x 128). The game never
// names a file: SpriteCatalog resolves `items.vida_home_*` through
// sprite_manifest.yaml.
import 'dart:io';

import 'export_sprites.dart' show RgbaImage;
import 'pixel_pen.dart';

/// Same map as `HomeInteriorRules.rows` (kept in sync by
/// test/features/world/player_house_art_test.dart).
const kHomeRows = [
  '############',
  '#C.C..C.C..#',
  '#C.C..C.C..#',
  '#..........#',
  '#..........#',
  '#..........#',
  '#..........#',
  '#####..#####',
];

/// Bed head tiles, as `HomeInteriorRules.bedTiles`.
const kHomeBeds = [(1, 1), (3, 1), (6, 1), (8, 1)];

const _ts = 16;

// Wood ramp.
const _w0 = 0xd9a066, _w1 = 0xb07a46, _w2 = 0x8a5a32, _w3 = 0x5c3a20;
const _w4 = 0x3a2414;
// Floor planks.
const _f0 = 0xc8925a, _f1 = 0xaa7442, _f2 = 0x8a5a34;
// Plaster.
const _p0 = 0xf0e0b8, _p1 = 0xdcc898, _p2 = 0xb8a070;
// Roof.
const _r0 = 0xd05a48, _r1 = 0xa83e36, _r2 = 0x7a2a2a;
// Stone.
const _s0 = 0xa8a8b0, _s1 = 0x7a7a88, _s2 = 0x54546a;
const _glass = 0x34466a, _glassLit = 0xf0c870, _light = 0xfff0c0;
const _leaf0 = 0x8acc6a, _leaf1 = 0x5a9a4a, _leaf2 = 0x3a6a34;
const _pot0 = 0xd07a4a, _pot1 = 0xa8563a;
// Bed sheets, one colour per bed.
const _sheets = [
  (0x5a7ac8, 0x3e5aa0),
  (0xc85a5a, 0xa03e3e),
  (0x5aa86a, 0x3e844a),
  (0xc8a050, 0xa07a34),
];

int _hash(int x, int y) {
  var h = x * 374761393 + y * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

bool _wall(int tx, int ty) =>
    ty < 0 ||
    ty >= kHomeRows.length ||
    tx < 0 ||
    tx >= 12 ||
    kHomeRows[ty][tx] == '#';

// ---------------------------------------------------------------- outside

RgbaImage exterior() {
  final p = Pen(64, 48);
  // Ground shadow.
  p.rect(2, 45, 60, 3, 0x1a1420, 0x50);
  // Stone foundation.
  p.rect(4, 40, 56, 6, _s1);
  for (var x = 4; x < 60; x += 6) {
    p.rect(x, 40, 5, 2, _s0);
    p.rect(x + 3, 43, 5, 2, _s0);
    p.px(x + 5, 41, _s2);
  }
  // Plaster walls with timber frame.
  p.rect(6, 22, 52, 18, _p0);
  p.rect(6, 22, 52, 2, _p1);
  p.rect(6, 37, 52, 3, _p2);
  for (final x in [6, 31, 56]) {
    p.rect(x, 22, 2, 18, _w2);
  }
  p.rect(6, 22, 52, 1, _w3);
  p.rect(6, 30, 52, 1, _w2, 0x80);
  // Windows (warm light inside), one on each side of the door.
  for (final x in [12, 42]) {
    p.rect(x - 1, 25, 12, 10, _w3);
    p.rect(x, 26, 10, 8, _glass);
    p.rect(x + 1, 27, 8, 6, _glassLit);
    p.rect(x + 1, 27, 3, 2, _light);
    p.rect(x + 4, 26, 1, 8, _w3);
    p.rect(x, 29, 10, 1, _w3);
    // Flower box.
    p.rect(x - 1, 35, 12, 2, _w2);
    for (var i = 0; i < 5; i++) {
      p.px(x + i * 2, 34, i.isEven ? 0xe05a7a : 0xf0d060);
      p.px(x + i * 2 + 1, 34, _leaf1);
    }
  }
  // Door in the bottom middle (the tile E uses).
  p.rect(26, 26, 12, 14, _w4);
  p.rect(27, 27, 10, 13, _w2);
  p.round(27, 26, 10, 4, _w2);
  for (final x in [29, 32, 35]) {
    p.rect(x, 28, 1, 12, _w3);
  }
  p.px(35, 34, 0xe0c060);
  p.px(35, 35, 0xa07a30);
  // Step.
  p.rect(25, 40, 14, 2, _s0);
  // Roof: stepped gable with shingles.
  for (var row = 0; row < 12; row++) {
    final y = 10 + row;
    final x0 = 4 + (11 - row) * 2, x1 = 60 - (11 - row) * 2;
    p.rect(x0, y, x1 - x0, 1, row.isEven ? _r0 : _r1);
    for (var x = x0 + (row % 2) * 2; x < x1; x += 4) {
      p.px(x, y, _r2);
    }
    p.px(x0, y, _r2);
    p.px(x1 - 1, y, _r2);
  }
  p.rect(2, 22, 60, 2, _r2);
  p.rect(2, 21, 60, 1, _r1);
  // Ridge.
  p.rect(26, 9, 12, 1, _r2);
  // Chimney with a puff of smoke.
  p.rect(46, 6, 6, 10, _s1);
  p.rect(45, 5, 8, 2, _s2);
  p.rect(47, 8, 2, 2, _s0);
  p.oval(48, 0, 4, 3, 0xd8d8e0, 0xa0);
  p.oval(51, 1, 3, 2, 0xd8d8e0, 0x70);
  p.outline();
  return p.img;
}

// ----------------------------------------------------------------- inside

RgbaImage room() {
  final p = Pen(12 * _ts, kHomeRows.length * _ts);
  _floor(p);
  _rug(p);
  _walls(p);
  _window(p);
  for (var i = 0; i < kHomeBeds.length; i++) {
    _bed(p, kHomeBeds[i], _sheets[i % _sheets.length]);
  }
  _props(p);
  return p.img;
}

void _floor(Pen p) {
  for (var ty = 0; ty < kHomeRows.length; ty++) {
    for (var tx = 0; tx < 12; tx++) {
      if (_wall(tx, ty)) continue;
      final x0 = tx * _ts, y0 = ty * _ts;
      for (var k = 0; k < 4; k++) {
        final gy = ty * 4 + k;
        final tone = [_f0, _f1, _f1, _f0][(gy * 5) % 4];
        p.rect(x0, y0 + k * 4, _ts, 4, tone);
        p.rect(x0, y0 + k * 4 + 3, _ts, 1, _f2);
        final seam = (gy * 11) % 32;
        final sx = seam - (tx * _ts) % 32;
        if (sx >= 0 && sx < _ts) p.rect(x0 + sx, y0 + k * 4, 1, 3, _f2);
        final h = _hash(tx * 4 + k, ty);
        p.rect(x0 + h % 10, y0 + k * 4 + 1, 2 + h % 3, 1, _f2, 0x60);
      }
    }
  }
}

void _rug(Pen p) {
  const x = 3 * _ts + 4, y = 4 * _ts + 2, w = 6 * _ts - 8, h = 2 * _ts + 4;
  p.rect(x + 1, y + h, w, 2, 0x2a1810, 0x50);
  p.round(x, y, w, h, 0x3e5a7a);
  p.round(x + 2, y + 2, w - 4, h - 4, 0x5a7aa0);
  p.rect(x + 5, y + 5, w - 10, h - 10, 0x3e5a7a);
  for (var i = x + 6; i < x + w - 6; i += 4) {
    p.px(i, y + 3, 0xe0c060);
    p.px(i, y + h - 4, 0xe0c060);
  }
}

void _walls(Pen p) {
  for (var ty = 0; ty < kHomeRows.length; ty++) {
    for (var tx = 0; tx < 12; tx++) {
      if (kHomeRows[ty][tx] != '#') continue;
      final x0 = tx * _ts, y0 = ty * _ts;
      if (ty == 0) {
        // Back wall: plaster above a wooden wainscot.
        p.rect(x0, y0, _ts, _ts, _p0);
        p.rect(x0, y0, _ts, 2, _w3);
        p.rect(x0, y0 + 10, _ts, 6, _w1);
        p.rect(x0, y0 + 10, _ts, 1, _w0);
        p.rect(x0, y0 + 15, _ts, 1, _w3);
        if (tx % 3 == 0) p.rect(x0, y0 + 2, 1, 8, _p2);
      } else {
        // Side and front walls: dark timber.
        p.rect(x0, y0, _ts, _ts, _w3);
        p.rect(x0 + 1, y0 + 1, _ts - 2, _ts - 2, _w2);
        p.rect(x0 + 1, y0 + 7, _ts - 2, 1, _w3);
      }
    }
  }
  // Shadow at the foot of the back wall.
  p.rect(_ts, _ts, 10 * _ts, 3, 0x2a1810, 0x60);
  // Door gap: a mat and the threshold.
  const dx = 5 * _ts, dy = 7 * _ts;
  p.rect(dx, dy, 2 * _ts, _ts, _w4);
  p.rect(dx + 2, dy, 2 * _ts - 4, 3, _f2);
  p.rect(dx + 4, dy - 6, 2 * _ts - 8, 5, 0x8a6a3a);
  p.rect(dx + 5, dy - 5, 2 * _ts - 10, 3, 0xa8844a);
}

void _window(Pen p) {
  // Back wall window between the second and third bed (x 4-5).
  const x = 4 * _ts + 4, y = 1;
  p.rect(x - 1, y, 2 * _ts - 6, 10, _w3);
  p.rect(x, y + 1, 2 * _ts - 8, 8, _glass);
  p.rect(x + 1, y + 2, 4, 3, 0x9ac8f0);
  p.rect(x + (2 * _ts - 8) ~/ 2, y + 1, 1, 8, _w3);
  // Curtains.
  p.rect(x - 3, y, 3, 11, 0xa84a40);
  p.rect(x + 2 * _ts - 8, y, 3, 11, 0xa84a40);
}

void _bed(Pen p, (int, int) at, (int, int) sheet) {
  final x = at.$1 * _ts + 1, y = at.$2 * _ts - 4;
  const w = _ts - 2, h = 2 * _ts + 2;
  // Headboard and frame.
  p.rect(x, y, w, 6, _w3);
  p.rect(x + 1, y + 1, w - 2, 4, _w1);
  p.rect(x, y + 6, w, h - 6, _w2);
  // Mattress, pillow, blanket.
  p.rect(x + 1, y + 6, w - 2, h - 8, 0xf0ead8);
  p.round(x + 2, y + 7, w - 4, 5, 0xffffff);
  p.rect(x + 3, y + 11, w - 6, 1, 0xd8d0c0);
  p.rect(x + 1, y + 14, w - 2, h - 16, sheet.$1);
  p.rect(x + 1, y + 14, w - 2, 2, 0xf0ead8);
  p.rect(x + 1, y + h - 4, w - 2, 2, sheet.$2);
  for (var i = x + 3; i < x + w - 2; i += 3) {
    p.px(i, y + 20, sheet.$2);
  }
  // Foot posts and shadow.
  p.rect(x, y + h - 2, 2, 2, _w4);
  p.rect(x + w - 2, y + h - 2, 2, 2, _w4);
  p.rect(x + 1, y + h, w, 2, 0x2a1810, 0x50);
}

void _props(Pen p) {
  // Potted plant in the right corner.
  const px0 = 10 * _ts + 3, py0 = 1 * _ts + 2;
  p.round(px0 + 1, py0 + 8, 9, 6, _pot0);
  p.rect(px0 + 2, py0 + 12, 7, 2, _pot1);
  p.oval(px0, py0, 11, 9, _leaf1);
  p.oval(px0 + 2, py0 + 1, 6, 5, _leaf0);
  p.px(px0 + 5, py0 + 7, _leaf2);
  // Little lamp table by the left wall.
  const tx = 1 * _ts + 2, ty = 4 * _ts;
  p.rect(tx, ty + 6, 12, 8, _w2);
  p.rect(tx, ty + 6, 12, 2, _w1);
  p.rect(tx + 4, ty, 4, 6, 0xe0c060);
  p.rect(tx + 5, ty + 1, 2, 2, _light);
}

void main() {
  writePng('assets/sprites/items/vida_home_exterior.png', exterior());
  writePng('assets/sprites/items/vida_home_room.png', room());
  stdout.writeln('Wrote the player house sprites.');
}
