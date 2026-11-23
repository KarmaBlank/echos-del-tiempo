// Exporta los sprites de los habitantes (overworld_biomes.md § 9 y
// sprites.md § "Habitantes"): el MISMO cuerpo que los personajes
// jugables (`heroRows` + `makeSprite` de export_sprites.dart) con la
// paleta de una clase base recoloreada y accesorios de su rol. Así no se
// confunden con los ayudantes del pueblo (granjero / pescador).
//
// Uso (desde la raíz del proyecto):
//
//   dart run tool/export_npc_sprites.dart
//
// Escribe `assets/sprites/items/vida_npc_<id>.png` (14 × 18, el cuerpo
// entero) y `vida_npc_<id>_retrato.png` (14 × 12, cabeza y hombros, para
// el cuadro de diálogo).
import 'dart:io';

import 'export_sprites.dart'
    show RgbaImage, encodePng, heroPalettes, heroRows, makeSprite;

/// Un habitante: clase base, colores que cambian y accesorios
/// (x, y, letra) sobre la grilla de 12 × 16 del héroe.
typedef NpcLook = ({
  String base,
  Map<String, String> pal,
  List<(int, int, String)> marks,
});

List<(int, int, String)> _col(int x, int y0, int y1, String ch) =>
    [for (var y = y0; y <= y1; y++) (x, y, ch)];

List<(int, int, String)> _rect(int x0, int y0, int x1, int y1, String ch) => [
      for (var y = y0; y <= y1; y++)
        for (var x = x0; x <= x1; x++) (x, y, ch)
    ];

/// Looks por id de habitante (biomes_catalog.dart).
final Map<String, NpcLook> npcLooks = {
  // Herbolaria: base tiradora; túnica verde musgo, morral A con hojas G
  // en el pelo y asomando del morral.
  'ilda': (
    base: 'tirador',
    pal: {
      'H': '#7a4b2a', 'B': '#4f7a3a', 'L': '#5a4632', 'D': '#3e2c1c',
      'A': '#9a6b3c', 'G': '#7bd35a',
    },
    marks: [
      (4, 0, 'G'), (7, 0, 'G'), (8, 1, 'G'),
      ..._rect(9, 9, 11, 10, 'A'), (10, 8, 'G'), (11, 8, 'G'),
    ],
  ),
  // Archivista: base maga; túnica ocre, libro K (tapa) con hojas P en la
  // mano izquierda y un rollo P en la espalda.
  'velda': (
    base: 'maga',
    pal: {
      'H': '#c9c3b5', 'B': '#8a6a3a', 'L': '#5c4a2e', 'D': '#3a2e1e',
      'K': '#6b2a2a', 'P': '#efe6cf',
    },
    marks: [
      ..._rect(0, 8, 1, 10, 'K'), (1, 9, 'P'),
      (10, 5, 'P'), (11, 6, 'P'),
    ],
  ),
  // Instructor: base guerrero; jubón gris acero y un bastón de práctica T
  // de punta a punta, con empuñadura W.
  'kael': (
    base: 'guerrero',
    pal: {
      'H': '#2d2d2d', 'B': '#5d6d7e', 'L': '#2c3e50', 'D': '#1c2833',
      'T': '#a0703c', 'W': '#e8d8b0',
    },
    marks: [..._col(11, 1, 14, 'T'), (11, 7, 'W'), (11, 8, 'W')],
  ),
  // Forjador: base paladín; camisa roja tostada, delantal de cuero A y
  // martillo M (cabeza) con mango T.
  'brann': (
    base: 'paladin',
    pal: {
      'H': '#4a2a14', 'S': '#d9a07a', 'B': '#a04030', 'L': '#3a2a20',
      'D': '#2a1a10', 'A': '#6b4a2a', 'M': '#8a8f98', 'T': '#7a5030',
    },
    marks: [
      ..._rect(4, 7, 7, 10, 'A'),
      ..._rect(0, 6, 1, 7, 'M'), ..._col(0, 8, 10, 'T'),
    ],
  ),
  // Vidente: base maga; capucha C que tapa el pelo, túnica violeta noche
  // y un orbe Q con brillo W en la mano izquierda.
  'oren': (
    base: 'maga',
    pal: {
      'H': '#3b2a5a', 'B': '#4b3a78', 'L': '#2a1f45', 'D': '#1a1230',
      'C': '#2e2350', 'Q': '#8fd8ff', 'W': '#ffffff',
    },
    marks: [
      ..._rect(3, 0, 8, 0, 'C'), ..._rect(2, 1, 9, 1, 'C'),
      (2, 2, 'C'), (9, 2, 'C'), (2, 3, 'C'), (9, 3, 'C'),
      (2, 4, 'C'), (9, 4, 'C'),
      ..._rect(0, 9, 1, 10, 'Q'), (0, 9, 'W'),
    ],
  ),
};

/// Grilla del héroe con los accesorios de [look] encima.
List<String> npcRows(NpcLook look) {
  final g = [for (final r in heroRows) r.split('')];
  for (final (x, y, ch) in look.marks) {
    g[y][x] = ch;
  }
  return [for (final r in g) r.join()];
}

/// Sprite de cuerpo entero (14 × 18).
RgbaImage npcSprite(String id) {
  final look = npcLooks[id]!;
  return makeSprite(
      npcRows(look), {...heroPalettes[look.base]!, ...look.pal});
}

/// Retrato: las primeras 12 filas del sprite (cabeza y hombros).
RgbaImage npcPortrait(String id) {
  final full = npcSprite(id);
  const h = 12;
  final out = RgbaImage(full.width, h);
  out.pixels.setRange(0, full.width * h * 4, full.pixels);
  return out;
}

Map<String, RgbaImage> buildNpcSprites() => {
      for (final id in npcLooks.keys) ...{
        'items/vida_npc_$id.png': npcSprite(id),
        'items/vida_npc_${id}_retrato.png': npcPortrait(id),
      },
    };

void main() {
  final root = Directory('assets/sprites');
  if (!root.existsSync()) {
    stderr.writeln('Correlo desde la raíz del proyecto.');
    exitCode = 1;
    return;
  }
  for (final e in buildNpcSprites().entries) {
    final f = File('${root.path}/${e.key}')..parent.createSync(recursive: true);
    f.writeAsBytesSync(encodePng(e.value));
    stdout.writeln('${f.path} (${e.value.width}x${e.value.height})');
  }
}
