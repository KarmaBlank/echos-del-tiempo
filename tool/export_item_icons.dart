// Íconos de armas e ítems (las formas del generador `item_icon`) en el
// mismo estilo que los de oficio: 16 × 16, contorno oscuro, luz arriba a
// la izquierda y sombra abajo a la derecha, por material.
// Correr con `dart run tool/export_item_icons.dart`: escribe dos PNG por
// forma en assets/sprites/items/ y el bloque de `items:` del manifest
// entre las marcas `# items:inicio` y `# items:fin`:
//   <clave>.png         todo lo que no es acento (metal, mango, cuerda…).
//   <clave>_acento.png  solo el acento (gema, rareza, material) en grises;
//                       el juego lo tiñe con el color que corresponda
//                       (rareza, tema, modo daltónico).
// Después de generarlos, los PNG mandan: el dueño puede reemplazarlos o
// editarlos sin tocar código. Volver a correr esto los PISA.
import 'dart:io';

import 'package:echos_del_tiempo/core/procedural/item_icon_rows.dart';

import 'export_sprites.dart' show RgbaImage, encodePng;

const _outline = 0x1a1420;
// Mismos valores por defecto que las perillas `item_icon`.
const _palette = {
  'm': 0xc8d2ff,
  'h': 0xa0703c,
  's': 0xe8ecff,
  'p': 0xe8dcc0,
  'c': 0x8e3b46,
  'w': 0xdde6ff,
  'g': 0xc8c8c8, // acento: gris medio, se tiñe en el juego
};

int _mix(int a, int b, double t) {
  int ch(int s) =>
      (((a >> s) & 0xff) * (1 - t) + ((b >> s) & 0xff) * t).round() & 0xff;
  return (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// Clave del manifest de una forma (`báculo` → `baculo`).
String fileKey(String shape) => shape.replaceAll('á', 'a');

/// La forma [rows] a 14 × 14 (margen de 1 para el contorno), sombreada.
/// Devuelve (base, acento).
(RgbaImage, RgbaImage) render(List<String> rows) {
  const n = 14;
  String at(int x, int y) {
    if (x < 0 || y < 0 || x >= n || y >= n) return '.';
    final r = rows[(y * 8) ~/ n];
    final c = r[(x * 8) ~/ n];
    return _palette.containsKey(c) ? c : '.';
  }

  final base = RgbaImage(16, 16), acc = RgbaImage(16, 16);
  void put(RgbaImage img, int x, int y, int rgb) {
    final o = (y * 16 + x) * 4;
    img.pixels
      ..[o] = (rgb >> 16) & 0xff
      ..[o + 1] = (rgb >> 8) & 0xff
      ..[o + 2] = rgb & 0xff
      ..[o + 3] = 0xff;
  }

  for (var y = -1; y <= n; y++) {
    for (var x = -1; x <= n; x++) {
      final k = at(x, y);
      final px = x + 1, py = y + 1;
      if (k == '.') {
        final near = at(x - 1, y) != '.' || at(x + 1, y) != '.' ||
            at(x, y - 1) != '.' || at(x, y + 1) != '.';
        if (near) put(base, px, py, _outline);
        continue;
      }
      var c = _palette[k]!;
      final lit = at(x, y - 1) != k || at(x - 1, y) != k;
      final dark = at(x, y + 1) != k || at(x + 1, y) != k;
      if (lit && !dark) {
        c = _mix(c, 0xffffff, 0.4);
      } else if (dark && !lit) {
        c = _mix(c, 0x000000, 0.35);
      } else if (k == 'm' && (x + y) % 5 == 0) {
        c = _mix(c, 0xffffff, 0.55); // brillo del metal
      }
      put(k == 'g' ? acc : base, px, py, c);
    }
  }
  return (base, acc);
}

void main() {
  final keys = <String>[];
  for (final e in kItemIconRows.entries) {
    final k = fileKey(e.key);
    final (b, a) = render(e.value);
    File('assets/sprites/items/$k.png').writeAsBytesSync(encodePng(b));
    File('assets/sprites/items/${k}_acento.png').writeAsBytesSync(encodePng(a));
    keys.add(k);
  }
  final manifest = File('assets/sprites/sprite_manifest.yaml');
  var lines = manifest.readAsLinesSync();
  final s = lines.indexWhere((l) => l.startsWith('  # items:inicio'));
  if (s >= 0) {
    final e = lines.indexWhere((l) => l.startsWith('  # items:fin'));
    lines.removeRange(s, e + 1);
  }
  final firstProc = lines.indexWhere((l) => keys.any(
      (k) => l.startsWith('  $k: { procedural: true')));
  var at = firstProc >= 0
      ? firstProc
      : lines.indexWhere((l) => l.startsWith('  # vida:inicio'));
  if (s >= 0) at = s;
  lines = [
    for (var i = 0; i < lines.length; i++)
      if (!keys.any((k) => lines[i].startsWith('  $k: { procedural: true')))
        lines[i]
      else
        '\u0000',
  ];
  // Mantener el índice de inserción tras quitar las líneas viejas.
  final before = lines.sublist(0, at).where((l) => l != '\u0000').toList();
  final after = lines.sublist(at).where((l) => l != '\u0000').toList();
  final block = [
    '  # items:inicio — íconos de armas e ítems (tool/export_item_icons.dart)',
    for (final k in keys) ...[
      '  $k: { idle: items/$k.png, size: [16, 16] }',
      '  ${k}_acento: { idle: items/${k}_acento.png, size: [16, 16] }',
    ],
    '  # items:fin',
  ];
  manifest.writeAsStringSync('${[...before, ...block, ...after].join('\n')}\n');
  stdout.writeln('${keys.length} formas');
}
