import 'package:flutter/rendering.dart';

import '../../game_engine/models/item.dart' show Rarity;
import 'procedural_art.dart';
import 'weapon_look.dart';

/// Pintor del ícono de [entryId] (`items.espada`, o `items` = familia)
/// con las perillas vigentes de [ProceduralArt.instance].
class ItemIconPainter extends CustomPainter {
  ItemIconPainter(this.rows, this.accent, this.entryId, {this.look})
      : revision = ProceduralArt.instance.revision;
  final List<String> rows;
  final Color accent;
  final String entryId;
  final int revision;

  /// Identidad del arma concreta (aura sutil, acento, ULT, variante).
  final WeaponLook? look;

  @override
  void paint(Canvas canvas, Size size) => paintItemIcon(canvas,
      Offset.zero & size, rows, accent, ProceduralArt.instance.resolve(entryId),
      look: look);

  @override
  bool shouldRepaint(ItemIconPainter old) =>
      old.rows != rows ||
      old.accent != accent ||
      old.entryId != entryId ||
      old.look != look ||
      old.revision != revision;
}

/// Dibuja la entrada [entryId] del manifest (`items.espada`) si tiene
/// generador; `false` si no (el Editor la marca rayada).
bool paintProceduralEntry(Canvas canvas, Rect r, String entryId,
    {Color accent = kItemDefaultAccent}) {
  final parts = entryId.split('.');
  if (parts.length < 2 || parts[0] != 'items') return false;
  final shape = kItemEntryShapes[parts[1]];
  if (shape == null) return false;
  final side = r.shortestSide;
  paintItemIcon(canvas, Rect.fromCenter(center: r.center, width: side, height: side),
      kItemIconRows[shape]!, accent,
      ProceduralArt.instance.resolve('items.${parts[1]}'));
  return true;
}

/// Generador `item_icon` (docs/specs/game_editor.md § 7.5): íconos pixel
/// 8 × 8 de armas e ítems. Catálogo único de formas; el pintor lee sus
/// perillas de [ProceduralArt] (valores por defecto = aspecto de siempre).
///
/// Bitmaps 8 × 8: `.` vacío; `m` metal; `h` mango; `g` acento (gema,
/// color de la rareza o del material); `s` cuerda; `p` papel; `c` tapa;
/// `w` vidrio.
const kItemIconRows = <String, List<String>>{
  'espada': [
    '.......m',
    '......mm',
    '.....mm.',
    '.h..mm..',
    '..hmm...',
    '...h....',
    '..h.h...',
    '.h......',
  ],
  'hacha': [
    '..mmm...',
    '.mmmmh..',
    '.mmmh...',
    '..mh....',
    '...h....',
    '....h...',
    '.....h..',
    '......h.',
  ],
  'lanza': [
    '......mm',
    '......mm',
    '.....h..',
    '....h...',
    '...h....',
    '..h.....',
    '.h......',
    'h.......',
  ],
  'báculo': [
    '.....gg.',
    '....gggg',
    '.....gg.',
    '....h...',
    '...h....',
    '..h.....',
    '.h......',
    'h.......',
  ],
  'tomo': [
    '........',
    '.cccccc.',
    '.cppppc.',
    '.cpggpc.',
    '.cppppc.',
    '.cppppc.',
    '.cccccc.',
    '........',
  ],
  'varita': [
    '......g.',
    '.....g.g',
    '......g.',
    '.....h..',
    '....h...',
    '...h....',
    '..h.....',
    '........',
  ],
  'arco': [
    '..hh....',
    '.h..s...',
    'h....s..',
    'h.....s.',
    'h.....s.',
    'h....s..',
    '.h..s...',
    '..hh....',
  ],
  'rifle': [
    '........',
    '........',
    'mmmmmmm.',
    'hhhmm...',
    'hh.h....',
    'h.......',
    '........',
    '........',
  ],
  'ballesta': [
    '...m....',
    '..mmm...',
    '.h.m.h..',
    'h..m..h.',
    '...m....',
    '...h....',
    '...h....',
    '........',
  ],
  'dagas': [
    'm......m',
    '.m....m.',
    '..m..m..',
    '...hh...',
    '...hh...',
    '..h..h..',
    '.h....h.',
    '........',
  ],
  'escudo': [
    '.mmmmmm.',
    '.mggggm.',
    '.mgmmgm.',
    '.mggggm.',
    '.mggggm.',
    '..mggm..',
    '...mm...',
    '........',
  ],
  // Armas en mano de las familias con escudo (sprites.md § "Armas en
  // mano"): el ícono de inventario sigue siendo el escudo.
  'maza': [
    '..g.g...',
    '.gmmmg..',
    '..mmm...',
    '.gmmmg..',
    '...h....',
    '...h....',
    '...h....',
    '...h....',
  ],
  'martillo': [
    'mmmmmmm.',
    'mmmmmmm.',
    'mmmhmmm.',
    '...h....',
    '...h....',
    '...h....',
    '...h....',
    '...h....',
  ],
  'pocion': [
    '...hh...',
    '...ww...',
    '..gggg..',
    '.gggggg.',
    '.gggggg.',
    '.gggggg.',
    '..gggg..',
    '........',
  ],
  // Cofre (forma nueva del Editor, § 7.5).
  'cofre': [
    '........',
    '.hhhhhh.',
    'hmmmmmmh',
    'hhhggghh',
    'hhhgghhh',
    'hhhhhhhh',
    'hmmmmmmh',
    '........',
  ],
  'esquirla': [
    '....g...',
    '...gg...',
    '...ggg..',
    '..gggg..',
    '..ggg...',
    '.ggg....',
    '.gg.....',
    '........',
  ],
  'cristal': [
    '...gg...',
    '..gggg..',
    '.gggggg.',
    'gggwgggg',
    '.gggggg.',
    '..gggg..',
    '...gg...',
    '........',
  ],
  'prisma': [
    '...g....',
    '...gg...',
    '..gggm..',
    '..ggmm..',
    '.ggmmmh.',
    '.gmmmhh.',
    'gggmmhhh',
    '........',
  ],
  // Eco: un portal con un reloj adentro (ecos_atlas.md § 2).
  'eco': [
    '..gggg..',
    '.gwwwwg.',
    'gww.mwwg',
    'gww.mwwg',
    'gwwmmwwg',
    'gwwwwwwg',
    '.gwwwwg.',
    '..gggg..',
  ],
  // Ancla Temporal.
  'ancla': [
    '...gg...',
    '...gg...',
    '.mmggmm.',
    '...gg...',
    '...gg...',
    'g..gg..g',
    '.g.gg.g.',
    '..gggg..',
  ],
  // Fragmento del Abismo (v0.8): rombo partido con núcleo.
  'fragmento': [
    '...m....',
    '..mgm...',
    '.mgwgm..',
    'mggwggm.',
    '.mggm...',
    '..mgm...',
    '...m....',
    '........',
  ],
  // Esencia del Abismo (v0.8): gota.
  'esencia': [
    '...g....',
    '...g....',
    '..ggg...',
    '.ggwgg..',
    '.gwggg..',
    '.ggggg..',
    '..ggg...',
    '........',
  ],
};

/// Entrada `items.<clave>` del sprite_manifest.yaml → forma.
const kItemEntryShapes = <String, String>{
  'espada': 'espada',
  'hacha': 'hacha',
  'lanza': 'lanza',
  'dagas': 'dagas',
  'espada_escudo': 'escudo',
  'maza_escudo': 'escudo',
  'martillo_escudo': 'escudo',
  'arco': 'arco',
  'ballesta': 'ballesta',
  'rifle': 'rifle',
  'baculo': 'báculo',
  'varita': 'varita',
  'tomo': 'tomo',
  'pocion': 'pocion',
  'cofre': 'cofre',
};

/// Acento por defecto de las entradas del Editor (sin rareza): celeste.
const kItemDefaultAccent = Color(0xFF9FB4FF);

/// Clave de entrada del manifest de un tipo de arma (`espada+escudo` →
/// `espada_escudo`, `báculo` → `baculo`), o `null` si no tiene.
String? procKeyForType(String type) {
  final k = type.replaceAll('+', '_').replaceAll('á', 'a');
  return kItemEntryShapes.containsKey(k) ? k : null;
}

Color _hex(String s) => Color(0xFF000000 | int.parse(s.substring(1), radix: 16));

Color _tone(Color c, double shine) => shine == 0
    ? c
    : Color.lerp(c, shine > 0 ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        shine.abs())!;

/// Dibuja la forma [rows] en [r] con las perillas [p]. [accent] = el
/// acento que decide el juego (rareza, material) si la perilla `accent`
/// está vacía.
///
/// Con [look] (un arma concreta, weapon_identity.md § 3) suma la
/// identidad: acento de la rareza, variante suave por uid (tono del
/// metal y gema, sin tocar la silueta), aura tenue del elemento con
/// partículas, destello del legendario y el píxel de la ULT en el pomo.
/// [time] (segundos) anima el aura y el destello; con 0 queda quieto.
void paintItemIcon(Canvas canvas, Rect r, List<String> rows, Color accent,
    ProcParams p, {WeaponLook? look, double time = 0}) {
  final vary = look != null && p.flag('variation') ? look.variant : 0;
  final shine = (p.number('shine') +
          switch (vary) { 1 => 0.12, 2 => -0.12, _ => 0.0 })
      .clamp(-0.6, 0.6);
  Color col(String k) => _tone(_hex(p.color(k)), shine);
  final acc = p.color('accent').isEmpty ? _tone(accent, shine) : col('accent');
  final palette = {
    'm': col('metal'),
    'h': col('handle'),
    'g': acc,
    's': col('string'),
    'p': col('paper'),
    'c': col('cover'),
    'w': col('glass'),
  };
  final scale = p.number('scale');
  final px = r.width * scale / 8;
  final ox = r.left + (r.width - px * 8) / 2;
  final oy = r.top + (r.height - px * 8) / 2;
  final mirror = p.flag('mirror');
  final paint = Paint()..isAntiAlias = false;
  void cell(int x, int y, Color c) {
    paint.color = c;
    final cx = mirror ? 7 - x : x;
    canvas.drawRect(Rect.fromLTWH(ox + cx * px, oy + y * px, px, px), paint);
  }

  bool filled(int x, int y) =>
      y >= 0 && y < rows.length && x >= 0 && x < rows[y].length &&
      palette.containsKey(rows[y][x]);

  if (p.flag('outline')) {
    final oc = _hex(p.color('outline_color'));
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        if (filled(x, y)) continue;
        if (filled(x - 1, y) || filled(x + 1, y) || filled(x, y - 1) || filled(x, y + 1)) {
          cell(x, y, oc);
        }
      }
    }
  }
  // Aura del elemento: halo de 1 celda alrededor de la silueta.
  final aura = look?.auraColor;
  final auraK = p.number('aura');
  if (aura != null && auraK > 0) {
    final ac = aura.withValues(alpha: (auraK * 0.7).clamp(0.0, 1.0));
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        if (filled(x, y)) continue;
        if (filled(x - 1, y) || filled(x + 1, y) || filled(x, y - 1) ||
            filled(x, y + 1)) {
          cell(x, y, ac);
        }
      }
    }
  }
  final highlight = p.flag('highlight') || look?.rarity == Rarity.epico;
  var gem = p.flag('gem') || vary == 2;
  for (var y = 0; y < rows.length; y++) {
    var lit = false;
    for (var x = 0; x < rows[y].length; x++) {
      final k = rows[y][x];
      var c = palette[k];
      if (c == null) continue;
      if (gem && k == 'h') {
        c = acc;
        gem = false;
      } else if (highlight && !lit && k == 'm') {
        c = Color.lerp(c, const Color(0xFFFFFFFF), 0.5)!;
        lit = true;
      }
      cell(x, y, c);
    }
  }
  if (look == null) return;
  // Partículas lentas del aura (2), solo en celdas vacías.
  if (aura != null && auraK > 0 && p.flag('aura_particles')) {
    final pc = aura.withValues(alpha: (auraK * 0.9).clamp(0.0, 1.0));
    for (var k = 0; k < 2; k++) {
      final ph = time * 1.2 + k * 4 + look.variant;
      final y = 7 - (ph % 8).floor();
      final x = (k * 5 + 1 + (ph / 8).floor() * 3) % 8;
      if (!filled(x, y)) cell(x, y, pc);
    }
  }
  // Destello del legendario: un píxel blanco recorre el metal cada ~2 s.
  if (look.legendary && p.flag('sparkle')) {
    final metal = <(int, int)>[
      for (var y = 0; y < rows.length; y++)
        for (var x = 0; x < rows[y].length; x++)
          if (rows[y][x] == 'm' || rows[y][x] == 'g') (x, y),
    ];
    if (metal.isNotEmpty) {
      final i = (time * 6).floor() % (metal.length + 6);
      final (x, y) = metal[i < metal.length ? i : 0];
      cell(x, y, i < metal.length ? const Color(0xFFFFFFFF) : const Color(0xFFFFE08A));
    }
  }
  // Marca de ULT: un píxel rosa en el pomo (la última celda del mango).
  if (look.hasUlt && p.flag('ult_mark')) {
    (int, int)? pommel;
    for (var y = rows.length - 1; y >= 0 && pommel == null; y--) {
      for (var x = 0; x < rows[y].length; x++) {
        if (rows[y][x] == 'h') {
          pommel = (x, y);
          break;
        }
      }
    }
    if (pommel == null) {
      for (var y = rows.length - 1; y >= 0 && pommel == null; y--) {
        for (var x = 0; x < rows[y].length; x++) {
          if (filled(x, y)) {
            pommel = (x, y);
            break;
          }
        }
      }
    }
    if (pommel != null) cell(pommel.$1, pommel.$2, kUltMarkColor);
  }
}
