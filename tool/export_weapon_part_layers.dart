// Recolour layers of the item icons (docs/specs/profession_gear_v2.md
// § 6). Run `dart run tool/export_weapon_part_layers.dart`: reads the
// CURRENT assets/sprites/items/<shape>.png (so the owner's edits stay) and
// writes <shape>_head.png and <shape>_grip.png (greys = tone index), the
// manifest block between `# capas:inicio` / `# capas:fin`, and the
// colour grids of docs/preview/weapon_parts/.
import 'dart:io';

import 'package:echos_del_tiempo/core/procedural/item_icon_rows.dart';
import 'package:echos_del_tiempo/core/procedural/weapon_parts.dart';

import 'export_item_icons.dart' show fileKey;
import 'export_sprites.dart' show RgbaImage, encodePng;
import 'png_decode.dart';

/// Head materials of the preview grid (rows) and grip materials (columns).
const kPreviewHeads = [
  '',
  'ingot_copper',
  'ingot_bronze',
  'ingot_frost',
  'ingot_ember',
  'ingot_echo',
  'fp_pez_paradoja_scale',
  'living_fuego',
];
const kPreviewGrips = ['', 'ingot_copper', 'fp_pez_paradoja_bone', 'living'];

/// Weapon shapes shown in the preview.
const kPreviewShapes = [
  'espada', 'hacha', 'lanza', 'dagas', 'arco', 'ballesta', 'rifle',
  'báculo', 'varita', 'tomo', 'espada_escudo', 'maza_escudo',
  'martillo_escudo',
];

RgbaImage _img(int w, int h, List<int> px) {
  final i = RgbaImage(w, h);
  i.pixels.setAll(0, px);
  return i;
}

void main() {
  final keys = <String>[];
  for (final shape in kItemIconRows.keys) {
    final k = fileKey(shape);
    final f = File('assets/sprites/items/$k.png');
    if (!f.existsSync()) continue;
    final (w, h, px) = decodePng(f.readAsBytesSync());
    final (head, grip) = splitLayers(px);
    File('assets/sprites/items/${k}_head.png')
        .writeAsBytesSync(encodePng(_img(w, h, head)));
    File('assets/sprites/items/${k}_grip.png')
        .writeAsBytesSync(encodePng(_img(w, h, grip)));
    keys.add(k);
  }
  // Manifest block.
  final manifest = File('assets/sprites/sprite_manifest.yaml');
  final lines = manifest.readAsLinesSync();
  final s = lines.indexWhere((l) => l.startsWith('  # capas:inicio'));
  if (s >= 0) {
    final e = lines.indexWhere((l) => l.startsWith('  # capas:fin'));
    lines.removeRange(s, e + 1);
  }
  final at = lines.indexWhere((l) => l.startsWith('  # items:fin')) + 1;
  lines.insertAll(at, [
    '  # capas:inicio — capas de recoloreo (tool/export_weapon_part_layers.dart)',
    for (final k in keys) ...[
      '  ${k}_head: { idle: items/${k}_head.png, size: [16, 16] }',
      '  ${k}_grip: { idle: items/${k}_grip.png, size: [16, 16] }',
    ],
    '  # capas:fin',
  ]);
  manifest.writeAsStringSync('${lines.join('\n')}\n');
  // Preview: per shape, head material (rows) × grip material (columns).
  Directory('docs/preview/weapon_parts').createSync(recursive: true);
  const scale = 4, cell = 16 * scale + 4;
  for (final shape in kPreviewShapes) {
    final k = fileKey(shape);
    final f = File('assets/sprites/items/$k.png');
    if (!f.existsSync()) continue;
    final (w, h, px) = decodePng(f.readAsBytesSync());
    final (head, grip) = splitLayers(px);
    final out = RgbaImage(cell * kPreviewGrips.length, cell * kPreviewHeads.length);
    for (var i = 0; i < out.pixels.length; i += 4) {
      out.pixels
        ..[i] = 0x1e
        ..[i + 1] = 0x1b
        ..[i + 2] = 0x2a
        ..[i + 3] = 0xff;
    }
    for (var r = 0; r < kPreviewHeads.length; r++) {
      for (var c = 0; c < kPreviewGrips.length; c++) {
        final copy = [...px];
        final hc = materialColor(kPreviewHeads[r]);
        final gc = materialColor(kPreviewGrips[c]);
        recolor(copy, head, grip, hc == null ? null : rampOf(hc),
            gc == null ? null : rampOf(gc));
        for (var y = 0; y < h * scale; y++) {
          for (var x = 0; x < w * scale; x++) {
            final so = ((y ~/ scale) * w + x ~/ scale) * 4;
            if (copy[so + 3] == 0) continue;
            final dx = c * cell + 2 + x, dy = r * cell + 2 + y;
            final o = (dy * out.width + dx) * 4;
            for (var j = 0; j < 4; j++) {
              out.pixels[o + j] = copy[so + j];
            }
          }
        }
      }
    }
    File('docs/preview/weapon_parts/$k.png').writeAsBytesSync(encodePng(out));
  }
  stdout.writeln('${keys.length} formas con capas');
}
