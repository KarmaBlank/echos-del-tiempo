// Mining icons (docs/specs/mining_smithing.md § 1.6, § 2) in procedural
// pixel art, 16 × 16: ores, ingots, rare materials, tools and supplies.
// Run `dart run tool/export_mine_icons.dart`: writes
// assets/sprites/items/vida_mine_<id>.png. The manifest maps each
// `vida_<id>` to its file; the game never names a file. Replace a PNG or
// its manifest path to change the art.
import 'dart:io';

import 'export_sprites.dart' show RgbaImage, encodePng;

const _outline = 0x1a1420;
const _wood = 0x8a5a32;
const _woodDark = 0x5c3a20;
const _rock = 0x6e6875;
const _rockDark = 0x45404c;

/// Ore colour per tier (copper, bronze, frost, ember, echo).
const _tier = {
  1: 0xd9824a,
  2: 0xe0b860,
  3: 0xbfe8ff,
  4: 0xff6a2a,
  5: 0xc08aff,
};

int _mix(int a, int b, double t) {
  int ch(int s) =>
      (((a >> s) & 0xff) * (1 - t) + ((b >> s) & 0xff) * t).round() & 0xff;
  return (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

class _Pen {
  _Pen() : img = RgbaImage(16, 16);
  final RgbaImage img;
  void px(int x, int y, int rgb) {
    if (x < 0 || y < 0 || x > 15 || y > 15) return;
    final o = (y * 16 + x) * 4;
    img.pixels
      ..[o] = (rgb >> 16) & 0xff
      ..[o + 1] = (rgb >> 8) & 0xff
      ..[o + 2] = rgb & 0xff
      ..[o + 3] = 0xff;
  }

  void rect(int x, int y, int w, int h, int rgb) {
    for (var j = y; j < y + h; j++) {
      for (var i = x; i < x + w; i++) {
        px(i, j, rgb);
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
}

/// A rock lump with ore chunks of [c].
RgbaImage ore(int c) {
  final p = _Pen();
  p.rect(3, 5, 10, 8, _outline);
  p.rect(4, 4, 8, 1, _outline);
  p.rect(4, 5, 8, 7, _rock);
  p.rect(5, 4, 6, 1, _rock);
  p.rect(4, 10, 8, 2, _rockDark);
  for (final (x, y) in const [(5, 6), (8, 5), (9, 8), (6, 9)]) {
    p.rect(x, y, 2, 2, c);
    p.px(x, y, _mix(c, 0xffffff, 0.5));
  }
  return p.img;
}

/// A bar seen from the side, lit on top.
RgbaImage ingot(int c) {
  final p = _Pen();
  p.rect(2, 7, 12, 6, _outline);
  p.rect(4, 5, 8, 2, _outline);
  p.rect(3, 8, 10, 4, _mix(c, 0x000000, 0.25));
  p.rect(5, 6, 6, 2, _mix(c, 0xffffff, 0.35));
  p.rect(4, 8, 8, 1, c);
  p.px(5, 6, 0xffffff);
  return p.img;
}

/// A cut gem.
RgbaImage gem(int c) {
  final p = _Pen();
  p.line(8, 2, 13, 7, _outline);
  p.line(13, 7, 8, 13, _outline);
  p.line(8, 13, 3, 7, _outline);
  p.line(3, 7, 8, 2, _outline);
  for (var y = 3; y < 13; y++) {
    final w = y < 7 ? y - 3 : 12 - y;
    p.rect(8 - w, y, w * 2 + 1, 1, y < 7 ? _mix(c, 0xffffff, 0.3) : c);
  }
  p.px(7, 4, 0xffffff);
  return p.img;
}

RgbaImage scroll() {
  final p = _Pen();
  p.rect(3, 3, 10, 10, _outline);
  p.rect(4, 4, 8, 8, 0xe8dcb0);
  p.line(5, 6, 10, 6, 0x4a6aa8);
  p.line(5, 8, 9, 8, 0x4a6aa8);
  p.line(5, 10, 10, 10, 0x4a6aa8);
  return p.img;
}

RgbaImage core() {
  final p = _Pen();
  p.rect(4, 4, 8, 8, _outline);
  p.rect(5, 5, 6, 6, 0x7ae0d0);
  p.rect(7, 7, 2, 2, 0xffffff);
  p.px(4, 4, 0);
  return p.img;
}

/// A pick (or a drill) with a head of [c].
RgbaImage pick(int c, {bool drill = false}) {
  final p = _Pen();
  if (drill) {
    p.rect(2, 9, 6, 4, _outline);
    p.rect(3, 10, 4, 2, _woodDark);
    for (var k = 0; k < 7; k++) {
      p.rect(7 + k, 9 + (k ~/ 3), 1, 4 - (k ~/ 2).clamp(0, 3), c);
    }
    p.px(13, 11, 0xffffff);
    return p.img;
  }
  // Handle: diagonal from bottom-left up into the head, 2 px wide.
  p.line(1, 14, 10, 5, _outline);
  p.line(2, 14, 11, 5, _outline);
  p.line(1, 13, 10, 4, _outline);
  p.line(2, 13, 10, 5, _wood);
  // Head: a thick arc bulging to the top-right corner, a point at each
  // end (reads as a pick, not a hoe or a sickle).
  const outer = [
    (2, 2), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 2),
    (10, 2), (11, 3), (12, 4), (13, 5), (13, 6), (14, 7), (14, 8),
    (14, 9), (14, 10), (14, 11), (14, 12),
  ];
  const inner = [
    (3, 2), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2), (9, 3), (10, 3),
    (11, 4), (12, 5), (12, 6), (13, 7), (13, 8), (13, 9), (13, 10),
  ];
  for (final (x, y) in [...outer, ...inner]) {
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      p.px(x + dx, y + dy, _outline);
    }
  }
  for (final (x, y) in outer) {
    p.px(x, y, _mix(c, 0xffffff, 0.3));
  }
  for (final (x, y) in inner) {
    p.px(x, y, c);
  }
  p.px(2, 2, c);
  p.px(14, 12, c);
  return p.img;
}

RgbaImage torch() {
  final p = _Pen();
  p.rect(7, 7, 2, 8, _woodDark);
  p.rect(6, 3, 4, 4, 0xffb347);
  p.rect(7, 2, 2, 2, 0xffe08a);
  p.px(7, 5, 0xffffff);
  return p.img;
}

RgbaImage bomb() {
  final p = _Pen();
  p.rect(4, 6, 8, 8, _outline);
  p.rect(5, 5, 6, 10, _outline);
  p.rect(5, 7, 6, 6, 0x34303c);
  p.px(6, 8, 0x8a8392);
  p.line(9, 5, 11, 2, _wood);
  p.px(12, 1, 0xffe08a);
  return p.img;
}

RgbaImage oil() {
  final p = _Pen();
  p.rect(6, 2, 4, 2, _woodDark);
  p.rect(5, 4, 6, 10, _outline);
  p.rect(6, 5, 4, 8, 0x4aa3a0);
  p.rect(6, 9, 4, 4, 0xe0b860);
  p.px(7, 6, 0xffffff);
  return p.img;
}

void main() {
  const tiers = {
    'copper': 1,
    'bronze': 2,
    'frost': 3,
    'ember': 4,
    'echo': 5,
  };
  const rares = {
    'rare_amber': 0xffb347,
    'rare_cog': 0xe0b860,
    'rare_rime': 0xbfe8ff,
    'rare_magma': 0xff4a2a,
    'rare_sand': 0xe8d8a0,
  };
  final out = <String, RgbaImage>{
    for (final e in tiers.entries) 'ore_${e.key}': ore(_tier[e.value]!),
    for (final e in tiers.entries) 'ingot_${e.key}': ingot(_tier[e.value]!),
    for (final e in rares.entries) e.key: gem(e.value),
    'schematic': scroll(),
    'guardian_core': core(),
    'pico': pick(0x9a9aa8),
    'pick_copper': pick(_tier[1]!),
    'pick_frost': pick(_tier[3]!),
    'pick_ember': pick(_tier[4]!),
    'drill_echo': pick(_tier[5]!, drill: true),
    'mine_torch': torch(),
    'mine_bomb': bomb(),
    'vein_oil': oil(),
  };
  for (final e in out.entries) {
    File('assets/sprites/items/vida_mine_${e.key}.png')
        .writeAsBytesSync(encodePng(e.value));
  }
  stdout.writeln('${out.length} mining icons written.');
}
