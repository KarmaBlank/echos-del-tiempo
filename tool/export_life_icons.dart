// Íconos de oficio (pesca y cultivo) en pixel art procedural, 16 × 16.
// Correr con `dart run tool/export_life_icons.dart`: escribe los PNG en
// assets/sprites/items/vida_*.png y el bloque de `items:` del manifest
// entre las marcas `# vida:inicio` y `# vida:fin`. El juego nunca nombra
// un archivo: los resuelve SpriteCatalog por id (`items.vida_<id>`).
// Para cambiar el arte, reemplazá el PNG o la ruta en el manifest.
import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';

import 'export_sprites.dart' show RgbaImage, encodePng;

const _outline = 0x1a1420;
const _wood = 0x8a5a32;
const _woodDark = 0x5c3a20;
const _metal = 0xa8b0bc;
const _soil = 0x6b4a2e;
const _leaf = 0x5fae4a;

int _rarity(FishRarity r) => switch (r) {
      FishRarity.comun => 0xd8d8d8,
      FishRarity.raro => 0x4aa3ff,
      FishRarity.epico => 0xb46bff,
      FishRarity.legendario => 0xffb347,
    };

int _hash(String s) => s.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff);

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
    final n = [(x1 - x0).abs(), (y1 - y0).abs(), 1].reduce((a, b) => a > b ? a : b);
    for (var k = 0; k <= n; k++) {
      px((x0 + (x1 - x0) * k / n).round(), (y0 + (y1 - y0) * k / n).round(), rgb);
    }
  }

  /// Contorno oscuro alrededor de todo lo pintado.
  void outline() {
    final p = img.pixels;
    bool on(int x, int y) =>
        x >= 0 && y >= 0 && x < 16 && y < 16 && p[(y * 16 + x) * 4 + 3] != 0;
    final add = <(int, int)>[];
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
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

RgbaImage _rod(int accent) {
  final p = _Pen();
  p.line(2, 14, 12, 2, _wood);
  p.line(3, 14, 13, 2, _woodDark);
  p.rect(3, 11, 2, 2, accent);
  p.line(13, 2, 13, 10, 0xe0e0e0);
  p.rect(12, 10, 3, 2, accent);
  p.outline();
  return p.img;
}

RgbaImage _hoe(int accent) {
  final p = _Pen();
  p.line(3, 14, 11, 4, _wood);
  p.rect(9, 2, 5, 2, _metal);
  p.rect(12, 4, 2, 3, _metal);
  p.rect(9, 2, 2, 1, accent);
  p.outline();
  return p.img;
}

RgbaImage _can(int accent) {
  final p = _Pen();
  p.rect(3, 6, 8, 7, _metal);
  p.rect(3, 6, 8, 2, accent);
  p.line(11, 9, 14, 5, _metal);
  p.rect(5, 3, 4, 1, _metal);
  p.px(4, 4, _metal);
  p.px(9, 4, _metal);
  p.outline();
  return p.img;
}

RgbaImage _fert(int accent) {
  final p = _Pen();
  p.rect(4, 5, 8, 9, 0xc8a46a);
  p.rect(5, 3, 6, 2, 0xb08a52);
  p.rect(6, 8, 4, 3, accent);
  p.outline();
  return p.img;
}

RgbaImage _fish(String id, int accent) {
  final p = _Pen();
  final h = _hash(id);
  final body = _mix(accent, [0x6fa8c8, 0x8fbf7a, 0xc89a6a, 0xa08ac8][h % 4], 0.5);
  final tall = 3 + h % 2;
  p.rect(3, 8 - tall ~/ 2 - 1, 8, tall + 2, body);
  p.rect(4, 8 - tall ~/ 2 - 2, 6, 1, body);
  p.line(11, 8, 14, 5, accent);
  p.line(11, 8, 14, 11, accent);
  p.px(13, 7, accent);
  p.px(13, 9, accent);
  p.px(5, 7, _outline);
  p.rect(6, 9, 4, 1, _mix(body, 0xffffff, 0.4));
  p.outline();
  return p.img;
}

RgbaImage _junk(String id) {
  final p = _Pen();
  if (id.contains('bota')) {
    p.rect(5, 3, 4, 8, 0x6b4a2e);
    p.rect(5, 10, 8, 3, 0x6b4a2e);
    p.rect(5, 12, 8, 1, 0x3a2818);
  } else if (id.contains('rama')) {
    p.line(2, 12, 13, 4, _woodDark);
    p.line(7, 9, 9, 12, _woodDark);
    p.px(12, 3, _leaf);
  } else {
    p.rect(4, 5, 8, 8, 0x7a6a50);
    p.line(4, 5, 11, 12, 0x5a4a36);
    p.rect(7, 3, 2, 2, 0x5a4a36);
  }
  p.outline();
  return p.img;
}

RgbaImage _seed(int accent) {
  final p = _Pen();
  p.rect(4, 5, 8, 9, 0xd8c08a);
  p.rect(5, 3, 6, 2, 0xc0a670);
  p.rect(6, 8, 2, 2, accent);
  p.rect(9, 10, 2, 2, accent);
  p.px(7, 11, accent);
  p.outline();
  return p.img;
}

RgbaImage _crop(String id, int accent) {
  final p = _Pen();
  final h = _hash(id);
  final fruit = _mix(accent, [0xe8d070, 0xe07a4a, 0xc85a8a, 0x8ac85a][h % 4], 0.55);
  p.rect(4, 6, 8, 8, fruit);
  p.rect(5, 5, 6, 1, fruit);
  p.rect(5, 14, 6, 1, fruit);
  p.rect(6, 7, 2, 2, _mix(fruit, 0xffffff, 0.5));
  p.line(8, 5, 8, 2, _leaf);
  p.line(8, 3, 11, 2, _leaf);
  p.outline();
  return p.img;
}

/// Ayudante del pueblo (farming.md § 8): cuerpo, cara, sombrero y la
/// herramienta. [work]: el cuadro de trabajo (regando o con la línea).
RgbaImage _npc({required bool farmer, required bool work}) {
  final p = _Pen();
  const skin = 0xe8b890;
  final shirt = farmer ? 0x6a8a3a : 0x3a6a9a;
  final pants = farmer ? 0x4a5a8a : 0x5a4a3a;
  final hat = farmer ? 0xe0c060 : 0x2a4a7a;
  p.rect(6, 13, 2, 3, pants);
  p.rect(9, 13, 2, 3, pants);
  p.rect(5, 8, 7, 5, shirt);
  p.rect(6, 4, 5, 4, skin);
  p.px(7, 6, _outline);
  p.px(9, 6, _outline);
  if (farmer) {
    p.rect(4, 3, 9, 1, hat);
    p.rect(6, 2, 5, 1, hat);
    p.rect(6, 10, 5, 3, pants); // pechera
    if (work) {
      p.rect(12, 9, 3, 3, _metal);
      p.px(15, 9, _metal);
      p.px(15, 12, 0x6fb6ff);
      p.px(14, 14, 0x6fb6ff);
    } else {
      p.line(12, 6, 12, 14, _wood);
      p.rect(11, 5, 3, 1, _metal);
    }
  } else {
    p.rect(5, 3, 7, 2, hat);
    p.rect(11, 4, 2, 1, hat);
    if (work) {
      p.line(11, 10, 15, 3, _wood);
      p.line(15, 3, 15, 9, 0xe0e0e0);
    } else {
      p.line(12, 14, 13, 4, _wood);
    }
    p.rect(3, 11, 2, 3, 0x8a6a3a); // canasto
  }
  p.outline();
  return p.img;
}

RgbaImage _chest() {
  final p = _Pen();
  p.rect(2, 7, 12, 7, _wood);
  p.rect(2, 5, 12, 3, _woodDark);
  p.rect(2, 9, 12, 1, _woodDark);
  p.rect(7, 8, 2, 3, 0xe0c060);
  p.outline();
  return p.img;
}

RgbaImage _category(String cat) => switch (cat) {
      'herramienta' => _hoe(_metal),
      'pescado' => _fish('generico', 0xd8d8d8),
      'semilla' => _seed(_soil),
      'cosecha' => _crop('generico', 0xd8d8d8),
      _ => _junk('bulto'),
    };

void main() {
  final icons = <String, RgbaImage>{
    for (final r in kRods.values) 'vida_${r.id}': _rod(_rarity(r.rarity)),
    for (final t in kFarmTools.values)
      'vida_${t.id}': t.kind == FarmToolKind.azada
          ? _hoe(_rarity(t.rarity))
          : _can(_rarity(t.rarity)),
    for (final f in kFertilizers.values) 'vida_${f.id}': _fert(_rarity(f.rarity)),
    for (final f in kFish.values)
      'vida_${f.id}': f.biome == kWaterJunkBiome
          ? _junk(f.id)
          : _fish(f.id, _rarity(f.rarity)),
    for (final c in kCrops.values) ...{
      'vida_semilla_${c.id}': _seed(_rarity(c.rarity)),
      'vida_cosecha_${c.id}': _crop(c.id, _rarity(c.rarity)),
    },
    for (final cat in ['herramienta', 'pescado', 'semilla', 'cosecha', 'basura'])
      'vida_cat_$cat': _category(cat),
    'vida_npc_granjero': _npc(farmer: true, work: false),
    'vida_npc_granjero_trabajo': _npc(farmer: true, work: true),
    'vida_npc_pescador': _npc(farmer: false, work: false),
    'vida_npc_pescador_trabajo': _npc(farmer: false, work: true),
    'vida_cofre_oficio': _chest(),
  };
  for (final e in icons.entries) {
    File('assets/sprites/items/${e.key}.png').writeAsBytesSync(encodePng(e.value));
  }
  final manifest = File('assets/sprites/sprite_manifest.yaml');
  final text = manifest.readAsStringSync();
  final block = StringBuffer()
    ..writeln('  # vida:inicio — íconos de oficio (tool/export_life_icons.dart)');
  for (final k in icons.keys) {
    block.writeln('  $k: { idle: items/$k.png, size: [16, 16] }');
  }
  block.write('  # vida:fin');
  final start = text.indexOf('  # vida:inicio');
  final String next;
  if (start >= 0) {
    final end = text.indexOf('  # vida:fin') + '  # vida:fin'.length;
    next = text.replaceRange(start, end, block.toString());
  } else {
    const anchor = '  cofre: { procedural: true, size: [16, 16] }';
    next = text.replaceFirst(anchor, '$anchor\n$block');
  }
  manifest.writeAsStringSync(next);
  stdout.writeln('${icons.length} íconos');
}
