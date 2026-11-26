// Interior of the players' TIENDA (player_shop.md § 6) in procedural pixel
// art: a cosy little shop with a plank floor, wainscoted back wall with
// shelves of jars and crates, side windows that drop light on the floor,
// a cash counter with a bell, wall lamps, plants, a rug and a door mat;
// plus the display tables (one per player counter, autotiled from end
// and middle pieces) and the small gold price tag.
//
// Run with `dart run tool/export_shop_interior_sprites.dart`. It writes
// assets/sprites/items/vida_shop_room.png (the whole 16 x 11 room, 256 x
// 176), vida_shop_table_<piece>_<cloth>.png (piece l / m / r / s, cloth
// 0-3 or `bare` for a free counter, 16 x 22 each) and vida_shop_tag.png.
// The game never names a file: SpriteCatalog resolves `items.vida_shop_*`
// through sprite_manifest.yaml.
import 'dart:io';

import 'export_sprites.dart' show RgbaImage;
import 'pixel_pen.dart';

/// Same map as `ShopInteriorRules.rows` (kept in sync by
/// test/features/world/shop_interior_art_test.dart).
const kShopRows = [
  '################',
  '#####......#####',
  '#..............#',
  '#..CC......CC..#',
  '#..............#',
  '#..............#',
  '#..CC......CC..#',
  '#..............#',
  '#..............#',
  '#..............#',
  '#######..#######',
];

const _ts = 16;

// Wood ramp.
const _w0 = 0xd9a066, _w1 = 0xb07a46, _w2 = 0x8a5a32, _w3 = 0x5c3a20;
const _w4 = 0x3a2414;
// Floor planks.
const _f0 = 0xc8925a, _f1 = 0xaa7442, _f2 = 0x8a5a34;
// Plaster.
const _p0 = 0xf0e0b8, _p1 = 0xdcc898, _p2 = 0xb8a070;
const _gold = 0xe0c060, _goldLight = 0xffe9a8, _goldDark = 0xa07a30;
const _glass = 0x34466a, _glassLit = 0xf0c870, _light = 0xfff0c0;
const _leaf0 = 0x8acc6a, _leaf1 = 0x5a9a4a, _leaf2 = 0x3a6a34;
const _pot0 = 0xd07a4a, _pot1 = 0xa8563a;

int _hash(int x, int y) {
  var h = x * 374761393 + y * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

bool _wall(int tx, int ty) =>
    ty < 0 ||
    ty >= kShopRows.length ||
    tx < 0 ||
    tx >= 16 ||
    kShopRows[ty][tx] == '#';

RgbaImage room() {
  final p = Pen(16 * _ts, kShopRows.length * _ts);
  _floor(p);
  _rug(p);
  _sideWalls(p);
  _backWall(p);
  _shelves(p, 1);
  _shelves(p, 11);
  _cashCounter(p);
  _frontWall(p);
  _windowLight(p);
  _props(p);
  return p.img;
}

void _floor(Pen p) {
  for (var ty = 0; ty < kShopRows.length; ty++) {
    for (var tx = 0; tx < 16; tx++) {
      if (_wall(tx, ty)) continue;
      final x0 = tx * _ts, y0 = ty * _ts;
      // Four horizontal planks per tile; each plank row has its own
      // tone and its end seams are staggered by row.
      for (var k = 0; k < 4; k++) {
        final gy = ty * 4 + k;
        final tone = [_f0, _f1, _f1, _f0][(gy * 5) % 4];
        p.rect(x0, y0 + k * 4, _ts, 4, tone);
        p.rect(x0, y0 + k * 4 + 3, _ts, 1, _f2);
        p.rect(x0, y0 + k * 4, _ts, 1, 0xffffff, 0x18);
        final seam = (gy * 11) % 32;
        final sx = seam - (tx * _ts) % 32;
        if (sx >= 0 && sx < _ts) p.rect(x0 + sx, y0 + k * 4, 1, 3, _f2);
        if (sx + 32 >= 0 && sx + 32 < _ts) {
          p.rect(x0 + sx + 32, y0 + k * 4, 1, 3, _f2);
        }
        // Grain and the odd knot.
        final h = _hash(tx * 4 + k, ty);
        p.rect(x0 + h % 10, y0 + k * 4 + 1, 3 + h % 4, 1, _f2, 0x60);
        if (h % 7 == 0) p.px(x0 + 3 + h % 9, y0 + k * 4 + 2, _w3);
      }
    }
  }
  // Soft shadow at the foot of every wall.
  for (var ty = 0; ty < kShopRows.length; ty++) {
    for (var tx = 0; tx < 16; tx++) {
      if (_wall(tx, ty)) continue;
      final x0 = tx * _ts, y0 = ty * _ts;
      if (_wall(tx, ty - 1)) {
        p.rect(x0, y0, _ts, 3, 0x2a1810, 0x70);
        p.rect(x0, y0 + 3, _ts, 2, 0x2a1810, 0x30);
      }
      if (_wall(tx - 1, ty)) p.rect(x0, y0, 3, _ts, 0x2a1810, 0x50);
      if (_wall(tx + 1, ty)) p.rect(x0 + _ts - 2, y0, 2, _ts, 0x2a1810, 0x40);
    }
  }
}

void _rug(Pen p) {
  // Central rug, cols 6-9, rows 3-8: rounded, bordered, with a medallion.
  const x = 6 * _ts + 2, y = 3 * _ts + 4, w = 4 * _ts - 4, h = 6 * _ts - 8;
  p.rect(x + 1, y + h, w, 2, 0x2a1810, 0x50); // shadow
  p.round(x, y, w, h, 0x6e2a2a);
  p.round(x + 1, y + 1, w - 2, h - 2, 0xa84a40);
  p.rect(x + 3, y + 3, w - 6, h - 6, _goldDark);
  p.rect(x + 4, y + 4, w - 8, h - 8, 0x8a3a3a);
  // Border motif: little gold dots.
  for (var i = x + 4; i < x + w - 4; i += 3) {
    p.px(i, y + 2, _gold);
    p.px(i, y + h - 3, _gold);
  }
  for (var j = y + 4; j < y + h - 4; j += 3) {
    p.px(x + 2, j, _gold);
    p.px(x + w - 3, j, _gold);
  }
  // Medallion: a diamond with a lighter core.
  const cx = x + w ~/ 2, cy = y + h ~/ 2;
  for (var r = 0; r < 14; r++) {
    final half = 14 - r;
    p.rect(cx - half, cy - r, half * 2, 1, r.isEven ? 0xc05a48 : 0xb05040);
    p.rect(cx - half, cy + r, half * 2, 1, r.isEven ? 0xc05a48 : 0xb05040);
  }
  for (var r = 0; r < 6; r++) {
    p.rect(cx - (6 - r), cy - r, (6 - r) * 2, 1, _gold);
    p.rect(cx - (6 - r), cy + r, (6 - r) * 2, 1, _gold);
  }
  p.rect(cx - 2, cy - 1, 4, 2, 0xa84a40);
  // Corner leaves.
  for (final (ox, oy) in [(x + 7, y + 7), (x + w - 9, y + 7), (x + 7, y + h - 9), (x + w - 9, y + h - 9)]) {
    p.rect(ox, oy, 2, 2, _gold);
  }
  // Fringe at both ends.
  for (var i = x + 2; i < x + w - 2; i += 2) {
    p.px(i, y - 1, _p1);
    p.px(i, y + h, _p1);
  }
}

void _sideWalls(Pen p) {
  // Left and right walls seen from above: thick timber with a lighter
  // inner lip, a window in rows 3 and 7 and a lamp in row 5.
  for (final tx in [0, 15]) {
    final x0 = tx * _ts;
    p.rect(x0, 0, _ts, kShopRows.length * _ts, _w4);
    final lip = tx == 0 ? x0 + _ts - 4 : x0;
    p.rect(lip, 0, 4, kShopRows.length * _ts, _w2);
    p.rect(tx == 0 ? lip + 3 : lip, 0, 1, kShopRows.length * _ts, _w1);
    for (var y = 6; y < kShopRows.length * _ts; y += 12) {
      p.rect(x0 + 2, y, _ts - 6, 1, _w3);
    }
    for (final ty in [3, 7]) {
      final y = ty * _ts + 2;
      final gx = tx == 0 ? x0 + 6 : x0 + 4;
      p.rect(gx - 1, y - 1, 8, 14, _w3);
      p.rect(gx, y, 6, 12, _glass);
      p.rect(gx, y, 6, 4, 0x6a86a8);
      p.rect(gx + 2, y, 1, 12, _w3);
      p.rect(gx, y + 6, 6, 1, _w3);
      p.px(gx + 1, y + 1, _light);
    }
  }
}

void _lamp(Pen p, int cx, int y) {
  // A small iron lantern with warm glass and a halo.
  p.oval(cx - 9, y - 4, 18, 18, _light, 0x22);
  p.oval(cx - 6, y - 1, 12, 12, _light, 0x30);
  p.rect(cx, y - 3, 1, 3, 0x2e2a3a);
  p.rect(cx - 3, y, 7, 2, 0x2e2a3a);
  p.rect(cx - 2, y + 2, 5, 5, _glassLit);
  p.rect(cx - 2, y + 2, 1, 5, _light);
  p.rect(cx, y + 2, 1, 5, 0xd09040);
  p.rect(cx - 3, y + 7, 7, 1, 0x2e2a3a);
  p.px(cx, y + 8, 0x2e2a3a);
}

void _backWall(Pen p) {
  // Face of the back wall: row 0 everywhere, row 1 beside the alcove.
  // Ceiling beam on top, plaster, chair rail and wainscot panels.
  for (var tx = 1; tx < 15; tx++) {
    final x0 = tx * _ts;
    final bottom = _wall(tx, 1) ? 2 * _ts : _ts;
    p.rect(x0, 0, _ts, bottom, _p1);
    // Plaster mottling.
    for (var k = 0; k < 4; k++) {
      final h = _hash(tx, k);
      p.px(x0 + h % 16, 5 + (h >> 4) % (bottom - 12), k.isEven ? _p0 : _p2);
    }
    // Wainscot: the lower 7 px.
    final wy = bottom - 7;
    p.rect(x0, wy, _ts, 7, _w2);
    p.rect(x0, wy, _ts, 1, _w0);
    p.rect(x0, wy + 1, _ts, 1, _w3);
    p.rect(x0 + 2, wy + 2, 12, 4, _w1);
    p.rect(x0 + 2, wy + 5, 12, 1, _w3);
    p.rect(x0 + 2, wy + 2, 1, 4, _w0);
    // Ceiling beam.
    p.rect(x0, 0, _ts, 4, _w3);
    p.rect(x0, 3, _ts, 1, _w4);
    p.rect(x0, 0, _ts, 1, _w2);
  }
  // Beam ends where the alcove steps back.
  for (final x in [5 * _ts, 11 * _ts - 2]) {
    p.rect(x, _ts, 2, _ts, _w3);
  }
  // Alcove wall: a painted sign board between two lamps.
  p.round(7 * _ts - 2, 5, 2 * _ts + 4, 9, _w3);
  p.round(7 * _ts - 1, 6, 2 * _ts + 2, 7, _w1);
  // Coin emblem on the sign.
  for (final (cx, c) in [(7 * _ts + 9, _gold), (8 * _ts + 7, _gold)]) {
    p.oval(cx - 3, 7, 6, 5, c);
    p.px(cx - 1, 8, _goldLight);
  }
  p.rect(8 * _ts - 3, 8, 6, 3, 0x6e4426);
  p.rect(8 * _ts - 2, 7, 4, 1, 0x6e4426);
  _lamp(p, 5 * _ts + 10, 3);
  _lamp(p, 11 * _ts - 10, 3);
}

void _jar(Pen p, int x, int y, int col, int lid) {
  p.round(x, y + 1, 5, 6, col);
  p.rect(x + 1, y, 3, 1, lid);
  p.px(x + 1, y + 2, 0xffffff, 0xa0);
  p.rect(x + 1, y + 5, 3, 1, 0x000000, 0x40);
}

void _bottle(Pen p, int x, int y, int col) {
  p.rect(x + 1, y, 1, 2, 0x6e4426);
  p.round(x, y + 2, 3, 5, col);
  p.px(x, y + 3, 0xffffff, 0x90);
}

void _crate(Pen p, int x, int y) {
  p.rect(x, y, 7, 6, _w1);
  p.rect(x, y, 7, 1, _w0);
  p.rect(x, y + 5, 7, 1, _w3);
  p.line(x, y + 1, x + 6, y + 4, _w2);
  p.rect(x, y, 1, 6, _w3);
  p.rect(x + 6, y, 1, 6, _w3);
}

void _sack(Pen p, int x, int y) {
  p.round(x, y + 1, 6, 6, 0xc4a878);
  p.rect(x + 2, y, 2, 1, 0x8a7048);
  p.rect(x + 1, y + 2, 4, 1, 0xa88a5a);
  p.px(x + 1, y + 3, 0xe0cca0);
}

void _shelves(Pen p, int tx) {
  // A shelving unit of 4 tiles over rows 0-1 with three boards.
  final x0 = tx * _ts + 1, w = 4 * _ts - 2;
  p.rect(x0, 4, w, 28, _w4);
  p.rect(x0 + 2, 5, w - 4, 26, 0x4a2e1a);
  p.rect(x0, 4, 2, 28, _w2);
  p.rect(x0 + w - 2, 4, 2, 28, _w2);
  p.rect(x0, 4, w, 1, _w1);
  const goods = [
    (0x3a6a9a, 0xdfe6e9),
    (0xa83a3a, _w0),
    (0xe0c060, _w2),
    (0x4e8a4a, _w0),
    (0x8a5ab0, 0xdfe6e9),
    (0xe07a3a, _w2),
  ];
  for (final (k, by) in [(0, 12), (1, 21), (2, 30)]) {
    p.rect(x0 + 1, by, w - 2, 2, _w1);
    p.rect(x0 + 1, by, w - 2, 1, _w0);
    var x = x0 + 3;
    var i = 0;
    while (x < x0 + w - 8) {
      final h = _hash(tx * 13 + i, k);
      final (col, lid) = goods[h % goods.length];
      switch ((h >> 3) % 5) {
        case 0 || 1:
          _jar(p, x, by - 7, col, lid);
          x += 6;
        case 2:
          _bottle(p, x, by - 7, col);
          x += 4;
        case 3:
          if (k == 2) {
            _sack(p, x, by - 7);
          } else {
            _crate(p, x, by - 6);
          }
          x += 8;
        default:
          // Stacked bolts of cloth / folded goods.
          p.rect(x, by - 3, 6, 3, col);
          p.rect(x, by - 5, 6, 2, lid);
          p.rect(x, by - 3, 6, 1, 0x000000, 0x30);
          x += 7;
      }
      x += 1;
      i++;
    }
  }
}

void _cashCounter(Pen p) {
  // Cash counter in the alcove (row 1, cols 6-9): wooden, with a bell,
  // a ledger and a stack of coins on top.
  const x = 6 * _ts + 2, y = _ts + 1, w = 4 * _ts - 4;
  p.rect(x + 1, y + 15, w, 2, 0x2a1810, 0x60); // shadow
  p.round(x, y, w, 6, _w0);
  p.rect(x + 1, y + 1, w - 2, 1, 0xf0c890);
  p.rect(x, y + 5, w, 1, _w3);
  p.rect(x, y + 6, w, 9, _w2);
  for (var i = x + 4; i < x + w - 4; i += 10) {
    p.rect(i, y + 7, 7, 6, _w1);
    p.rect(i, y + 12, 7, 1, _w3);
    p.px(i + 3, y + 9, _gold);
  }
  p.rect(x, y + 14, w, 1, _w4);
  // Bell.
  p.rect(x + 8, y + 4, 7, 1, _w3);
  p.oval(x + 9, y, 5, 5, _gold);
  p.px(x + 10, y + 1, _goldLight);
  p.px(x + 11, y - 1, _goldDark);
  // Ledger (open book).
  p.rect(x + 22, y + 1, 9, 4, _p0);
  p.rect(x + 26, y + 1, 1, 4, _p2);
  p.rect(x + 23, y + 2, 2, 1, _p2);
  p.rect(x + 28, y + 2, 2, 1, _p2);
  // Coin stacks.
  for (final (cx, n) in [(x + 38, 3), (x + 43, 2)]) {
    for (var k = 0; k < n; k++) {
      p.rect(cx, y + 3 - k * 2, 4, 2, k.isEven ? _gold : _goldDark);
      p.px(cx + 1, y + 3 - k * 2, _goldLight);
    }
  }
  // Little scale.
  p.rect(x + 51, y - 2, 1, 6, 0x4a4e5a);
  p.rect(x + 48, y - 2, 7, 1, 0x4a4e5a);
  p.rect(x + 47, y, 3, 1, 0xa8b0bc);
  p.rect(x + 53, y, 3, 1, 0xa8b0bc);
}

void _frontWall(Pen p) {
  // Bottom wall seen from above, with the open doorway at cols 7-8.
  final y0 = (kShopRows.length - 1) * _ts;
  for (var tx = 0; tx < 16; tx++) {
    if (!_wall(tx, kShopRows.length - 1)) continue;
    final x0 = tx * _ts;
    p.rect(x0, y0, _ts, _ts, _w4);
    p.rect(x0, y0, _ts, 4, _w2);
    p.rect(x0, y0, _ts, 1, _w1);
    p.rect(x0, y0 + 9, _ts, 1, _w3);
  }
  // Doorway: frame posts, threshold and daylight from outside.
  const dx = 7 * _ts;
  p.rect(dx, y0 + 4, 2 * _ts, _ts - 4, _light, 0x40);
  p.rect(dx, y0 + 10, 2 * _ts, 6, _light, 0x50);
  p.rect(dx - 3, y0 - 2, 3, _ts + 2, _w2);
  p.rect(dx - 3, y0 - 2, 1, _ts + 2, _w1);
  p.rect(dx + 2 * _ts, y0 - 2, 3, _ts + 2, _w2);
  p.rect(dx + 2 * _ts + 2, y0 - 2, 1, _ts + 2, _w3);
  p.rect(dx, y0 + 2, 2 * _ts, 2, 0x8a8f9a);
  p.rect(dx, y0 + 2, 2 * _ts, 1, 0xb4b8c2);
  // Door mat just inside.
  const mx = dx + 3, mw = 2 * _ts - 6;
  final my = y0 - 12;
  p.round(mx, my, mw, 10, 0x7a5a2a);
  p.round(mx + 1, my + 1, mw - 2, 8, 0xa8844a);
  for (var i = mx + 2; i < mx + mw - 2; i += 2) {
    p.rect(i, my + 2, 1, 6, 0x8a6a36);
  }
  p.rect(mx + 3, my + 4, mw - 6, 2, 0x6e2a2a);
}

void _windowLight(Pen p) {
  // Day light from the side windows falls on the floor as soft skewed
  // patches (the lamps' night light is the light system's job).
  for (final ty in [3, 7]) {
    for (var k = 0; k < 14; k++) {
      final y = ty * _ts + 4 + k;
      final len = 18 - k ~/ 3;
      final a = k < 2 || k > 11 ? 0x1c : 0x2c;
      p.rect(_ts + 1 + k, y, len, 1, _light, a);
      p.rect(15 * _ts - 1 - k - len, y, len, 1, _light, a);
    }
  }
}

void _plant(Pen p, int x, int y, {bool tall = false}) {
  // Terracotta pot with a leafy plant; [tall] is a small potted tree.
  p.oval(x - 1, y + 12, 14, 4, 0x2a1810, 0x60);
  p.round(x + 2, y + 8, 8, 6, _pot1);
  p.round(x + 1, y + 7, 10, 3, _pot0);
  p.rect(x + 3, y + 10, 2, 3, 0xe09a6a);
  if (tall) {
    p.rect(x + 5, y - 2, 2, 10, _w3);
    p.oval(x - 2, y - 14, 16, 14, _leaf2);
    p.oval(x - 1, y - 14, 13, 11, _leaf1);
    p.oval(x + 1, y - 13, 7, 6, _leaf0);
    for (final (lx, ly) in [(x + 9, y - 6), (x, y - 9), (x + 5, y - 11)]) {
      p.px(lx, ly, _leaf0);
    }
    return;
  }
  for (final (lx, ly, lw, lh, c) in [
    (x - 1, y + 1, 6, 6, _leaf2),
    (x + 7, y + 1, 6, 6, _leaf2),
    (x + 2, y - 3, 8, 9, _leaf1),
    (x + 4, y - 2, 4, 4, _leaf0),
    (x, y + 2, 3, 3, _leaf1),
    (x + 9, y + 2, 3, 3, _leaf1),
  ]) {
    p.oval(lx, ly, lw, lh, c);
  }
  p.px(x + 3, y - 1, 0xff7b7b);
  p.px(x + 8, y + 1, 0xffd166);
}

void _barrel(Pen p, int x, int y) {
  p.oval(x - 1, y + 11, 12, 4, 0x2a1810, 0x60);
  p.round(x, y, 10, 13, _w2);
  p.rect(x + 1, y, 3, 13, _w1);
  p.rect(x, y + 3, 10, 1, 0x4a4e5a);
  p.rect(x, y + 9, 10, 1, 0x4a4e5a);
  p.oval(x + 1, y - 1, 8, 3, _w0);
  // Apples on top.
  p.px(x + 3, y - 1, 0xa83a3a);
  p.px(x + 5, y - 2, 0xc84a4a);
  p.px(x + 6, y - 1, 0xa83a3a);
}

void _props(Pen p) {
  // Plants by the shelves, a potted tree and crates by the door.
  _plant(p, _ts + 2, 2 * _ts + 1);
  _plant(p, 14 * _ts + 2, 2 * _ts + 1);
  _plant(p, _ts + 2, 9 * _ts + 1, tall: true);
  _barrel(p, 14 * _ts + 3, 9 * _ts + 1);
  _crate(p, 13 * _ts + 6, 9 * _ts + 8);
  _sack(p, 13 * _ts + 8, 9 * _ts + 2);
  // Wall lamps on the side walls (row 5).
  _lamp(p, 8, 5 * _ts + 2);
  _lamp(p, 15 * _ts + 8, 5 * _ts + 2);
}

/// Cloth colours of the display tables (light, mid, dark), by slot.
const kCloths = [
  [0xe07a6a, 0xb84a44, 0x7e2a2e], // red
  [0x7aa6d8, 0x4a74b0, 0x2e4a7a], // blue
  [0x8acc7a, 0x4e9a4a, 0x2e6a34], // green
  [0xc8a0e0, 0x8a62b0, 0x5a3a7e], // plum
];

/// One display-table piece, 16 x 22: [piece] `l`, `m`, `r` or `s`
/// (single); [cloth] 0-3 or null for a bare wooden table. Its tabletop
/// starts at y 4; the bottom row lines up 3 px below the counter tile.
RgbaImage table(String piece, int? cloth) {
  final p = Pen(16, 22);
  final left = piece == 'l' || piece == 's';
  final right = piece == 'r' || piece == 's';
  final x0 = left ? 1 : 0, x1 = right ? 15 : 16;
  // Legs at the ends.
  if (left) p.rect(x0 + 1, 13, 2, 7, _w3);
  if (right) p.rect(x1 - 3, 13, 2, 7, _w3);
  if (cloth == null) {
    // Bare table: plank top with grain, an apron, legs.
    p.rect(x0, 4, x1 - x0, 7, _w1);
    p.rect(x0, 4, x1 - x0, 1, _w0);
    p.rect(x0, 7, x1 - x0, 1, _w2);
    p.rect(x0 + 3, 5, 4, 1, _w2, 0x80);
    p.rect(x0, 10, x1 - x0, 4, _w2);
    p.rect(x0, 13, x1 - x0, 1, _w3);
  } else {
    final [c0, c1, c2] = kCloths[cloth];
    // Cloth over the top and a skirt with folds and a scalloped hem.
    p.rect(x0, 4, x1 - x0, 6, c0);
    p.rect(x0, 4, x1 - x0, 1, 0xffffff, 0x60);
    p.rect(x0, 9, x1 - x0, 1, c1);
    p.rect(x0, 10, x1 - x0, 7, c1);
    p.rect(x0, 10, x1 - x0, 1, _gold);
    for (var x = x0 + 2; x < x1; x += 4) {
      p.rect(x, 11, 1, 6, c2);
    }
    for (var x = x0; x < x1; x++) {
      if (x.isEven) p.px(x, 17, c1);
    }
  }
  // Round the outer corners.
  void cut(int x, int y) => p.img.pixels[(y * 16 + x) * 4 + 3] = 0;
  if (left) {
    cut(x0, 4);
  }
  if (right) {
    cut(x1 - 1, 4);
  }
  // Outline only on the outer sides: the join side stays open.
  final outlined = Pen(16, 22)..blit(p.img, 0, 0);
  outlined.outline();
  if (!left) _clearCol(outlined, 0, p);
  if (!right) _clearCol(outlined, 15, p);
  // Floor shadow under the table (after the outline: soft).
  for (var y = 20; y < 22; y++) {
    for (var x = x0; x < x1; x++) {
      if (!outlined.on(x, y)) outlined.px(x, y, 0x2a1810, 0x60);
    }
  }
  return outlined.img;
}

void _clearCol(Pen o, int x, Pen src) {
  // Undo the outline the join column got, keeping the piece's own pixels.
  for (var y = 0; y < 22; y++) {
    final i = (y * 16 + x) * 4;
    for (var c = 0; c < 4; c++) {
      o.img.pixels[i + c] = src.img.pixels[i + c];
    }
  }
}

/// Small gold price tag on a string, 5 x 6.
RgbaImage tag() {
  final p = Pen(5, 6);
  p.px(2, 0, 0x6e4426);
  p.round(0, 1, 5, 5, _gold);
  p.rect(1, 2, 3, 1, _goldLight);
  p.rect(1, 4, 3, 1, _goldDark);
  p.px(2, 2, 0x6e4426);
  return p.img;
}

void main() {
  writePng('assets/sprites/items/vida_shop_room.png', room());
  for (final piece in ['l', 'm', 'r', 's']) {
    for (var k = 0; k < kCloths.length; k++) {
      writePng('assets/sprites/items/vida_shop_table_${piece}_$k.png',
          table(piece, k));
    }
    writePng('assets/sprites/items/vida_shop_table_${piece}_bare.png',
        table(piece, null));
  }
  writePng('assets/sprites/items/vida_shop_tag.png', tag());
  stdout.writeln('Wrote the shop interior sprites.');
}
