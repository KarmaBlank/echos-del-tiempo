// Farm animal art (docs/specs/animals.md): 8-bit minimalist pixel art,
// procedural. Run with `dart run tool/export_animal_sprites.dart`: writes
// the PNGs to assets/sprites/items/vida_*.png and the `items:` block of
// the manifest between `# animales:inicio` and `# animales:fin`. The game
// never names a file: SpriteCatalog resolves them by id
// (`items.vida_<id>`). To change the art, replace the PNG or the path.
import 'dart:io';

import 'export_sprites.dart' show RgbaImage, encodePng;

const _ink = 0x1a1420;
const _white = 0xf4f0e6;
const _cream = 0xe8dcc0;
const _shade = 0xb9ad94;
const _red = 0xd64a3a;
const _yellow = 0xf2c14e;
const _orange = 0xe58e26;
const _brown = 0x8a5a32;
const _brownDark = 0x5c3a20;
const _pink = 0xe8a0a0;
const _grey = 0x9aa0a8;
const _greyDark = 0x5e646c;
const _blue = 0x4aa3ff;
const _hay = 0xd9b54a;
const _hayDark = 0xa8862e;
const _roof = 0xa83c32;
const _roofDark = 0x6e2620;
const _wall = 0xd8c09a;
const _wallDark = 0xa88c66;
const _metal = 0xa8b0bc;

class _Pen {
  _Pen(int w, int h) : img = RgbaImage(w, h);
  final RgbaImage img;

  void px(int x, int y, int rgb) {
    if (x < 0 || y < 0 || x >= img.width || y >= img.height) return;
    final o = (y * img.width + x) * 4;
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

  /// Dark outline around everything painted.
  void outline() {
    final p = img.pixels;
    final w = img.width, h = img.height;
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
      px(x, y, _ink);
    }
  }
}

// ---------------- animals (world sprites) ----------------

/// Hen / duck, 16 × 16, facing right. [b]: second walk frame.
RgbaImage _bird({required bool duck, bool b = false}) {
  final p = _Pen(16, 16);
  final body = duck ? _white : _white;
  p.rect(4, 7, 8, 5, body);
  p.rect(5, 12, 6, 1, _shade);
  // Tail.
  p.rect(3, 6, 2, 3, duck ? _cream : _white);
  // Head.
  p.rect(10, 3, 4, 4, duck ? 0x3f8a4a : body);
  p.px(12, 4, _ink);
  if (duck) {
    p.rect(14, 5, 2, 1, _orange);
  } else {
    p.rect(14, 5, 1, 1, _yellow);
    p.rect(11, 2, 2, 1, _red);
    p.px(13, 7, _red);
  }
  // Wing.
  p.rect(6, 8, 4, 2, duck ? _cream : _shade);
  // Legs.
  final lx = b ? 1 : 0;
  p.rect(6 + lx, 13, 1, 2, _orange);
  p.rect(9 - lx, 13, 1, 2, _orange);
  p.outline();
  return p.img;
}

/// Cow / goat / sheep, 24 × 20, facing right. [b]: second walk frame.
RgbaImage _beast(String kind, {bool b = false}) {
  final p = _Pen(24, 20);
  final (body, spot, head) = switch (kind) {
    'vaca' => (_white, _ink, _white),
    'cabra' => (0xc8b48a, 0x8a6e48, 0xc8b48a),
    _ => (_cream, _cream, _greyDark),
  };
  final sheep = kind == 'oveja';
  // Body.
  p.rect(3, 7, 15, 8, body);
  if (sheep) {
    // Wool puffs.
    for (final (x, y) in [(3, 6), (7, 5), (11, 5), (15, 6), (2, 10), (17, 10)]) {
      p.rect(x, y, 3, 2, _white);
    }
  } else if (kind == 'vaca') {
    p.rect(6, 8, 3, 3, spot);
    p.rect(12, 10, 4, 3, spot);
  } else {
    p.rect(4, 13, 13, 2, spot);
  }
  // Head.
  p.rect(17, 4, 5, 6, head);
  p.px(20, 6, sheep ? _white : _ink);
  if (kind == 'vaca') {
    p.rect(20, 8, 2, 2, _pink);
    p.px(17, 3, _shade);
    p.px(21, 3, _shade);
  } else if (kind == 'cabra') {
    p.px(18, 3, _brownDark);
    p.px(19, 2, _brownDark);
    p.rect(20, 10, 1, 2, 0x8a6e48);
  } else {
    p.rect(16, 5, 1, 2, _greyDark);
  }
  // Tail.
  p.rect(1, 8, 2, 1, sheep ? _white : spot);
  // Legs.
  final legs = sheep ? _greyDark : (kind == 'cabra' ? 0x8a6e48 : _white);
  final s = b ? 1 : 0;
  for (final x in [4 + s, 7 - s, 13 + s, 16 - s]) {
    p.rect(x, 15, 2, 4, legs);
    p.px(x, 18, _ink);
  }
  p.outline();
  return p.img;
}

// ---------------- buildings ----------------

/// The coop house (2 × 2 tiles, 32 × 32): a small red-roofed hut with a
/// round hen door and a ramp.
RgbaImage _coop() {
  final p = _Pen(32, 32);
  p.rect(3, 14, 26, 16, _wall);
  for (var y = 16; y < 30; y += 3) {
    p.rect(3, y, 26, 1, _wallDark);
  }
  // Roof.
  for (var i = 0; i < 12; i++) {
    p.rect(1 + i, 13 - i, 30 - 2 * i, 1, i.isEven ? _roof : _roofDark);
  }
  // Hen door and ramp.
  p.rect(12, 21, 8, 9, _brownDark);
  p.rect(13, 20, 6, 1, _brownDark);
  p.rect(10, 29, 12, 2, _brown);
  // Window with straw.
  p.rect(22, 17, 4, 3, _hay);
  p.outline();
  return p.img;
}

/// The barn house (3 × 3 tiles, 48 × 48): a red barn with white trim,
/// a big X door and a hay loft.
RgbaImage _barn() {
  final p = _Pen(48, 48);
  const red = 0xb0402e, redDark = 0x7a2a1e;
  p.rect(3, 20, 42, 26, red);
  for (var x = 5; x < 45; x += 4) {
    p.rect(x, 20, 1, 26, redDark);
  }
  // Gambrel roof.
  for (var i = 0; i < 10; i++) {
    p.rect(1 + i, 19 - i, 46 - 2 * i, 1, i.isEven ? _greyDark : _grey);
  }
  for (var i = 0; i < 6; i++) {
    p.rect(11 + 2 * i, 9 - i, 26 - 4 * i, 1, i.isEven ? _greyDark : _grey);
  }
  // Loft with hay.
  p.rect(20, 12, 8, 6, _white);
  p.rect(21, 13, 6, 4, _hay);
  // Door with the X.
  p.rect(14, 30, 20, 16, _white);
  p.rect(15, 31, 18, 15, redDark);
  for (var i = 0; i < 15; i++) {
    p.px(15 + i * 18 ~/ 15, 31 + i, _white);
    p.px(32 - i * 18 ~/ 15, 31 + i, _white);
  }
  p.rect(23, 31, 2, 15, _white);
  p.outline();
  return p.img;
}

// ---------------- items (16 × 16 icons) ----------------

RgbaImage _egg({required bool duck}) {
  final p = _Pen(16, 16);
  final c = duck ? 0xcfe3d6 : _white;
  p.rect(5, 4, 6, 9, c);
  p.rect(4, 6, 8, 6, c);
  p.rect(6, 3, 4, 1, c);
  p.rect(6, 5, 1, 2, 0xffffff);
  if (duck) {
    p.px(9, 8, 0x9ab8a4);
    p.px(7, 10, 0x9ab8a4);
  }
  p.rect(5, 12, 6, 1, duck ? 0x9ab8a4 : _shade);
  p.outline();
  return p.img;
}

RgbaImage _milk({required bool goat}) {
  final p = _Pen(16, 16);
  // Bottle.
  p.rect(5, 5, 6, 9, _white);
  p.rect(6, 3, 4, 2, _white);
  p.rect(6, 2, 4, 1, goat ? 0x8a6e48 : _blue);
  p.rect(5, 9, 6, 3, goat ? 0xc8b48a : _blue);
  p.px(6, 6, 0xffffff);
  p.outline();
  return p.img;
}

RgbaImage _wool() {
  final p = _Pen(16, 16);
  p.rect(3, 6, 10, 6, _white);
  p.rect(4, 4, 4, 3, _white);
  p.rect(8, 5, 4, 2, _white);
  p.rect(4, 11, 8, 2, _cream);
  p.px(6, 7, _shade);
  p.px(10, 9, _shade);
  p.outline();
  return p.img;
}

RgbaImage _hayBale() {
  final p = _Pen(16, 16);
  p.rect(2, 5, 12, 8, _hay);
  for (var x = 3; x < 14; x += 2) {
    p.px(x, 6, _hayDark);
    p.px(x + 1, 9, _hayDark);
    p.px(x, 11, _hayDark);
  }
  p.rect(5, 5, 1, 8, _brown);
  p.rect(10, 5, 1, 8, _brown);
  p.outline();
  return p.img;
}

RgbaImage _bucket() {
  final p = _Pen(16, 16);
  p.rect(4, 6, 8, 8, _metal);
  p.rect(5, 13, 6, 1, _grey);
  p.rect(4, 6, 8, 1, _greyDark);
  p.rect(5, 7, 6, 2, _white);
  // Handle.
  p.px(4, 4, _greyDark);
  p.px(11, 4, _greyDark);
  p.rect(5, 3, 6, 1, _greyDark);
  p.outline();
  return p.img;
}

RgbaImage _shears() {
  final p = _Pen(16, 16);
  for (var i = 0; i < 7; i++) {
    p.px(3 + i, 2 + i, _metal);
    p.px(12 - i, 2 + i, _metal);
  }
  p.rect(3, 10, 3, 3, _red);
  p.rect(10, 10, 3, 3, _red);
  p.px(8, 8, _greyDark);
  p.outline();
  return p.img;
}

/// Little heart for the panel (8 × 8): full or empty.
RgbaImage _heart({required bool full}) {
  final p = _Pen(8, 8);
  final c = full ? 0xe84a5f : _greyDark;
  p.rect(1, 2, 2, 2, c);
  p.rect(5, 2, 2, 2, c);
  p.rect(1, 3, 6, 2, c);
  p.rect(2, 5, 4, 1, c);
  p.rect(3, 6, 2, 1, c);
  if (full) p.px(2, 2, 0xffb0b8);
  return p.img;
}

/// The hay trough by the house (16 × 16).
RgbaImage _trough() {
  final p = _Pen(16, 16);
  p.rect(2, 8, 12, 4, _brown);
  p.rect(3, 7, 10, 2, _hay);
  p.rect(2, 12, 2, 2, _brownDark);
  p.rect(12, 12, 2, 2, _brownDark);
  p.outline();
  return p.img;
}

void main() {
  final sprites = <String, RgbaImage>{
    'vida_animal_gallina': _bird(duck: false),
    'vida_animal_gallina_b': _bird(duck: false, b: true),
    'vida_animal_pato': _bird(duck: true),
    'vida_animal_pato_b': _bird(duck: true, b: true),
    for (final k in ['vaca', 'cabra', 'oveja']) ...{
      'vida_animal_$k': _beast(k),
      'vida_animal_${k}_b': _beast(k, b: true),
    },
    'vida_gallinero': _coop(),
    'vida_establo': _barn(),
    'vida_huevo': _egg(duck: false),
    'vida_huevo_pato': _egg(duck: true),
    'vida_leche': _milk(goat: false),
    'vida_leche_cabra': _milk(goat: true),
    'vida_lana': _wool(),
    'vida_heno': _hayBale(),
    'vida_cubeta': _bucket(),
    'vida_tijeras': _shears(),
    'vida_corazon': _heart(full: true),
    'vida_corazon_vacio': _heart(full: false),
    'vida_comedero': _trough(),
  };
  for (final e in sprites.entries) {
    File('assets/sprites/items/${e.key}.png')
        .writeAsBytesSync(encodePng(e.value));
  }
  final manifest = File('assets/sprites/sprite_manifest.yaml');
  final text = manifest.readAsStringSync();
  final block = StringBuffer()
    ..writeln(
        '  # animales:inicio — animales de granja (tool/export_animal_sprites.dart)');
  for (final e in sprites.entries) {
    block.writeln('  ${e.key}: { idle: items/${e.key}.png, '
        'size: [${e.value.width}, ${e.value.height}] }');
  }
  block.write('  # animales:fin');
  final start = text.indexOf('  # animales:inicio');
  final String next;
  if (start >= 0) {
    final end = text.indexOf('  # animales:fin') + '  # animales:fin'.length;
    next = text.replaceRange(start, end, block.toString());
  } else {
    const anchor = '  # vida:fin';
    next = text.replaceFirst(anchor, '$anchor\n$block');
  }
  manifest.writeAsStringSync(next);
  stdout.writeln('${sprites.length} sprites de animales');
}
