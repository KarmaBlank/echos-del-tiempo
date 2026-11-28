// The players' own house (player_house.md) in procedural 8-bit pixel art:
// the outside (a cosy cottage with a red roof, chimney, two lit windows
// and a door in the bottom middle) and, for the inside, one 16 x 16 tile
// per wall and floor material and one sprite per piece of furniture
// (player_house.md § 8). The room itself is drawn by HomeInteriorLayer
// from the layout.
//
// Run with `dart run tool/export_player_house_sprites.dart`. It writes
// assets/sprites/items/vida_home_exterior.png (4 x 3 tiles, 64 x 48),
// vida_home_<furniture id>.png and vida_home_<wall|floor id>.png. The
// game never names a file: SpriteCatalog resolves `items.vida_home_*`
// through sprite_manifest.yaml.
import 'dart:io';

import 'export_sprites.dart' show RgbaImage;
import 'pixel_pen.dart';

/// Same pieces and sizes as `kHomeFurniture` (kept in sync by
/// test/features/world/player_house_preview_test.dart).
const kHomeArtPieces = [
  ('bed_basic', 1, 2),
  ('bed_quilted', 1, 2),
  ('bed_canopy', 2, 2),
  ('picture_meadow', 1, 1),
  ('picture_portrait', 1, 1),
  ('picture_clock', 2, 1),
  ('window', 1, 1),
  ('window_wide', 2, 1),
  ('weapon_rack', 2, 1),
  ('stash_chest', 1, 1),
  ('kitchen', 2, 1),
  ('bookshelf', 2, 1),
  ('armor_stand', 1, 1),
  ('rug', 3, 2),
  ('plant', 1, 1),
  ('candelabra', 1, 1),
  ('table', 2, 1),
];

/// Same ids as `kHomeSurfaces`.
const kHomeArtSurfaces = [
  'wall_plaster',
  'wall_wood',
  'wall_stone',
  'wall_brick',
  'floor_planks',
  'floor_stone',
  'floor_tiles',
  'floor_carpet',
];

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
int _hash(int x, int y) {
  var h = x * 374761393 + y * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

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

/// A floor tile (16 x 16) of material [id].
RgbaImage floorTile(String id) {
  final p = Pen(_ts, _ts);
  switch (id) {
    case 'floor_stone':
      p.rect(0, 0, 16, 16, _s1);
      for (final (x, y, w, h) in [(0, 0, 9, 7), (9, 0, 7, 7), (0, 7, 5, 9), (5, 7, 11, 9)]) {
        p.rect(x + 1, y + 1, w - 2, h - 2, _s0);
        p.px(x + 2, y + 2, 0xc8c8d0);
      }
    case 'floor_tiles':
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 2; x++) {
          p.rect(x * 8, y * 8, 8, 8, (x + y).isEven ? 0xe8dcc0 : 0x8a4a3a);
        }
      }
      p.rect(0, 7, 16, 1, 0x00000000, 0x30);
      p.rect(7, 0, 1, 16, 0x00000000, 0x30);
    case 'floor_carpet':
      p.rect(0, 0, 16, 16, 0x7a3a4a);
      for (var i = 0; i < 16; i += 4) {
        p.px(i + 1, i % 8 + 1, 0x9a4a5a);
        p.px((i + 9) % 16, (i + 5) % 16, 0x5a2a3a);
      }
    default: // floor_planks
      for (var k = 0; k < 4; k++) {
        p.rect(0, k * 4, 16, 4, [_f0, _f1, _f1, _f0][k]);
        p.rect(0, k * 4 + 3, 16, 1, _f2);
        p.rect((k * 11) % 16, k * 4, 1, 3, _f2);
        final h = _hash(k, 3);
        p.rect(h % 10, k * 4 + 1, 2 + h % 3, 1, _f2, 0x60);
      }
  }
  return p.img;
}

/// A wall tile (16 x 16) of material [id]. Plaster is pale so the
/// paint (a multiply) shows well.
RgbaImage wallTile(String id) {
  final p = Pen(_ts, _ts);
  switch (id) {
    case 'wall_wood':
      p.rect(0, 0, 16, 16, _w1);
      for (final x in [0, 5, 10, 15]) {
        p.rect(x, 0, 1, 16, _w3);
      }
      p.rect(0, 0, 16, 2, _w3);
    case 'wall_stone':
      p.rect(0, 0, 16, 16, _s2);
      for (final (x, y, w) in [(0, 1, 7), (8, 1, 8), (3, 6, 9), (0, 11, 6), (7, 11, 9)]) {
        p.rect(x, y, w - 1, 4, _s0);
        p.px(x + 1, y, 0xc8c8d0);
      }
    case 'wall_brick':
      p.rect(0, 0, 16, 16, 0xc8b8a0);
      for (var r = 0; r < 4; r++) {
        for (var x = (r.isEven ? 0 : -4); x < 16; x += 8) {
          p.rect(x + 1 < 0 ? 0 : x + 1, r * 4 + 1, x < 0 ? 3 : 7, 3,
              r.isEven ? 0xa84a3a : 0x983e32);
        }
      }
    default: // wall_plaster
      p.rect(0, 0, 16, 16, _p0);
      p.rect(0, 10, 16, 6, _w1);
      p.rect(0, 10, 16, 1, _w0);
      p.rect(0, 15, 16, 1, _w3);
      p.rect(3, 3, 1, 1, _p1);
      p.rect(11, 6, 2, 1, _p1);
  }
  return p.img;
}

/// Furniture [id], [w] x [h] tiles; [extra] px taller (grows upward).
RgbaImage piece(String id, int w, int h, {int extra = 0}) {
  final p = Pen(w * _ts, h * _ts + extra);
  final W = w * _ts, H = h * _ts + extra;
  switch (id) {
    case 'bed_basic':
    case 'bed_quilted':
    case 'bed_canopy':
      final fancy = id != 'bed_basic';
      final sheet = switch (id) {
        'bed_quilted' => (0xc85a5a, 0xa03e3e),
        'bed_canopy' => (0x7a5ac8, 0x5a3ea0),
        _ => (0x5a7ac8, 0x3e5aa0),
      };
      final x = 1, y = extra, bw = W - 2, bh = h * _ts - 2;
      if (id == 'bed_canopy') {
        p.rect(0, 0, 2, H - 2, _w3);
        p.rect(W - 2, 0, 2, H - 2, _w3);
        p.rect(0, 0, W, 4, 0x5a3ea0);
        p.rect(2, 4, 3, extra + 8, 0x7a5ac8, 0xc0);
        p.rect(W - 5, 4, 3, extra + 8, 0x7a5ac8, 0xc0);
      }
      p.rect(x, y, bw, 6, _w3);
      p.rect(x + 1, y + 1, bw - 2, 4, fancy ? _w0 : _w1);
      p.rect(x, y + 6, bw, bh - 6, _w2);
      p.rect(x + 1, y + 6, bw - 2, bh - 8, 0xf0ead8);
      p.round(x + 2, y + 7, bw - 4, 5, 0xffffff);
      p.rect(x + 1, y + 14, bw - 2, bh - 16, sheet.$1);
      p.rect(x + 1, y + 14, bw - 2, 2, 0xf0ead8);
      p.rect(x + 1, y + bh - 4, bw - 2, 2, sheet.$2);
      for (var i = x + 3; i < x + bw - 2; i += 3) {
        p.px(i, y + 20, sheet.$2);
        if (fancy) p.px(i + 1, y + 24, sheet.$2);
      }
      p.rect(x, y + bh - 2, 2, 2, _w4);
      p.rect(x + bw - 2, y + bh - 2, 2, 2, _w4);
    case 'picture_meadow' || 'picture_portrait':
      p.rect(2, 1, W - 4, 10, _w3);
      p.rect(3, 2, W - 6, 8, 0xe0c060);
      p.rect(4, 3, W - 8, 6, id == 'picture_meadow' ? 0x9ac8f0 : 0x5a4a6a);
      if (id == 'picture_meadow') {
        p.rect(4, 7, W - 8, 2, _leaf1);
        p.px(9, 4, 0xfff0a0);
      } else {
        p.oval(6, 4, 4, 4, 0xe8c0a0);
        p.rect(6, 8, 4, 1, 0xa84a40);
      }
    case 'picture_clock':
      p.rect(10, 0, 12, 14, _w3);
      p.rect(11, 1, 10, 12, _w1);
      p.oval(12, 2, 8, 8, 0xf0ead8);
      p.px(16, 4, _w4);
      p.px(16, 5, _w4);
      p.px(17, 6, _w4);
      p.rect(15, 11, 2, 2, 0xe0c060);
    case 'window' || 'window_wide':
      p.rect(3, 1, W - 6, 10, _w3);
      p.rect(4, 2, W - 8, 8, _glass);
      p.rect(5, 3, 4, 3, 0x9ac8f0);
      for (var x = 16; x < W - 4; x += 16) {
        p.rect(x, 2, 1, 8, _w3);
      }
      p.rect(4, 6, W - 8, 1, _w3);
      p.rect(1, 1, 3, 11, 0xa84a40);
      p.rect(W - 4, 1, 3, 11, 0xa84a40);
    case 'weapon_rack':
      p.rect(1, 3, W - 2, 3, _w2);
      p.rect(1, 3, W - 2, 1, _w1);
      p.rect(1, H - 6, W - 2, 3, _w2);
      for (final x in [2, W - 4]) {
        p.rect(x, 0, 2, H - 1, _w3);
      }
    case 'stash_chest':
      p.rect(1, extra + 3, 14, 12, _w3);
      p.rect(2, extra + 4, 12, 10, _w1);
      p.rect(2, extra + 4, 12, 4, _w0);
      p.rect(1, extra + 8, 14, 1, _w4);
      p.rect(7, extra + 7, 2, 3, 0xe0c060);
    case 'kitchen':
      p.rect(0, extra, W, h * _ts, _s1);
      p.rect(0, extra, W, 3, _s0);
      p.rect(3, extra + 6, 10, 7, _s2);
      p.rect(5, extra + 8, 6, 4, 0xf08a3a);
      p.rect(6, extra + 9, 4, 2, 0xffd060);
      p.oval(18, extra - 1, 10, 6, 0x3a3a48);
      p.rect(20, extra - 3, 6, 2, 0x54546a);
    case 'bookshelf':
      p.rect(0, 0, W, H, _w3);
      p.rect(1, 1, W - 2, H - 2, _w2);
      for (var r = 0; r < 3; r++) {
        final y = 2 + r * 7;
        p.rect(1, y + 6, W - 2, 1, _w3);
        for (var x = 2; x < W - 3; x += 3) {
          final c = [0xa84a40, 0x3e5aa0, 0x5aa86a, 0xc8a050][_hash(x, r) % 4];
          p.rect(x, y + 1 + _hash(r, x) % 2, 2, 5 - _hash(r, x) % 2, c);
        }
      }
    case 'armor_stand':
      p.rect(4, H - 3, 8, 2, _w3);
      p.rect(7, 4, 2, H - 6, _w2);
      p.round(4, 0, 8, 7, _s0);
      p.rect(5, 3, 6, 1, _s2);
      p.round(2, 7, 12, 11, _s0);
      p.rect(3, 8, 10, 2, 0xd0d0d8);
      p.rect(7, 9, 2, 8, _s1);
    case 'rug':
      p.round(2, 2, W - 4, H - 4, 0x3e5a7a);
      p.round(4, 4, W - 8, H - 8, 0x5a7aa0);
      p.rect(7, 7, W - 14, H - 14, 0x3e5a7a);
      for (var i = 8; i < W - 8; i += 4) {
        p.px(i, 5, 0xe0c060);
        p.px(i, H - 6, 0xe0c060);
      }
    case 'plant':
      p.round(3, H - 8, 10, 7, _pot0);
      p.rect(4, H - 3, 8, 2, _pot1);
      p.oval(1, H - 20, 14, 13, _leaf1);
      p.oval(3, H - 19, 7, 6, _leaf0);
      p.px(8, H - 9, _leaf2);
    case 'candelabra':
      p.rect(5, H - 3, 6, 2, 0xa07a30);
      p.rect(7, 8, 2, H - 10, 0xc8a050);
      p.rect(2, 8, 12, 2, 0xc8a050);
      for (final x in [2, 7, 12]) {
        p.rect(x, 3, 2, 5, 0xf0ead8);
        p.px(x, 1, 0xffd060);
        p.px(x + 1, 2, 0xf08a3a);
      }
    case 'table':
      p.rect(0, extra + 2, W, 6, _w1);
      p.rect(0, extra + 2, W, 2, _w0);
      p.rect(2, extra + 8, 2, 7, _w3);
      p.rect(W - 4, extra + 8, 2, 7, _w3);
      p.oval(12, extra - 1, 5, 4, 0xf0ead8);
  }
  p.outline();
  return p.img;
}

/// Extra height (px) of the furniture art above its footprint.
const kHomeArtExtra = <String, int>{
  'bed_canopy': 4,
  'bookshelf': 4,
  'armor_stand': 4,
  'plant': 4,
  'candelabra': 4,
};

void main() {
  writePng('assets/sprites/items/vida_home_exterior.png', exterior());
  for (final f in kHomeArtPieces) {
    final img = piece(f.$1, f.$2, f.$3, extra: kHomeArtExtra[f.$1] ?? 0);
    writePng('assets/sprites/items/vida_home_${f.$1}.png', img);
  }
  for (final s in kHomeArtSurfaces) {
    writePng('assets/sprites/items/vida_home_$s.png',
        s.startsWith('wall') ? wallTile(s) : floorTile(s));
  }
  stdout.writeln('Wrote the player house sprites.');
}
