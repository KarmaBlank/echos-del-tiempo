import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/loot_filter.dart';
import '../../../game_engine/rules/loot_filter_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';

/// Piezas visuales de objetos (loot v2): colores de rareza, ícono pixel,
/// casilla de inventario y etiqueta de loot con el estilo del filtro.
/// Ver docs/specs/panels.md § "Ficha de objeto" e § "Inventario".

/// Colores de rareza: los mismos del filtro en el mapa
/// (`LootFilterRules.rarityColor`).
abstract final class RarityColors {
  static Color of(Rarity r) => filterColor(LootFilterRules.rarityColor(r));

  /// [FilterColor] → [Color].
  static Color filterColor(FilterColor c) => Color.fromARGB(c.a, c.r, c.g, c.b);

  /// Color de una pila (materiales: celeste, como el filtro por defecto).
  static const stack = Color(0xFF78E6DC);
}

// ---------------------------------------------------------------------
// Íconos pixel (8 × 8)
// ---------------------------------------------------------------------

const _metal = Color(0xFFC8D2FF);
const _handle = Color(0xFFA0703C);
const _string = Color(0xFFE8ECFF);
const _paper = Color(0xFFE8DCC0);
const _cover = Color(0xFF8E3B46);
const _glass = Color(0xFFDDE6FF);

/// Bitmaps 8 × 8: `.` vacío; `m` metal; `h` mango; `g` acento (gema,
/// color de la rareza o del material); `s` cuerda; `p` papel; `c` tapa;
/// `w` vidrio.
const _icons = <String, List<String>>{
  'espada': [
    '.......m', '......mm', '.....mm.', '.h..mm..',
    '..hmm...', '...h....', '..h.h...', '.h......',
  ],
  'hacha': [
    '..mmm...', '.mmmmh..', '.mmmh...', '..mh....',
    '...h....', '....h...', '.....h..', '......h.',
  ],
  'lanza': [
    '......mm', '......mm', '.....h..', '....h...',
    '...h....', '..h.....', '.h......', 'h.......',
  ],
  'báculo': [
    '.....gg.', '....gggg', '.....gg.', '....h...',
    '...h....', '..h.....', '.h......', 'h.......',
  ],
  'tomo': [
    '........', '.cccccc.', '.cppppc.', '.cpggpc.',
    '.cppppc.', '.cppppc.', '.cccccc.', '........',
  ],
  'varita': [
    '......g.', '.....g.g', '......g.', '.....h..',
    '....h...', '...h....', '..h.....', '........',
  ],
  'arco': [
    '..hh....', '.h..s...', 'h....s..', 'h.....s.',
    'h.....s.', 'h....s..', '.h..s...', '..hh....',
  ],
  'rifle': [
    '........', '........', 'mmmmmmm.', 'hhhmm...',
    'hh.h....', 'h.......', '........', '........',
  ],
  'ballesta': [
    '...m....', '..mmm...', '.h.m.h..', 'h..m..h.',
    '...m....', '...h....', '...h....', '........',
  ],
  'dagas': [
    'm......m', '.m....m.', '..m..m..', '...hh...',
    '...hh...', '..h..h..', '.h....h.', '........',
  ],
  'escudo': [
    '.mmmmmm.', '.mggggm.', '.mgmmgm.', '.mggggm.',
    '.mggggm.', '..mggm..', '...mm...', '........',
  ],
  'pocion': [
    '...hh...', '...ww...', '..gggg..', '.gggggg.',
    '.gggggg.', '.gggggg.', '..gggg..', '........',
  ],
  'esquirla': [
    '....g...', '...gg...', '...ggg..', '..gggg..',
    '..ggg...', '.ggg....', '.gg.....', '........',
  ],
  'cristal': [
    '...gg...', '..gggg..', '.gggggg.', 'gggwgggg',
    '.gggggg.', '..gggg..', '...gg...', '........',
  ],
  'prisma': [
    '...g....', '...gg...', '..gggm..', '..ggmm..',
    '.ggmmmh.', '.gmmmhh.', 'gggmmhhh', '........',
  ],
};

/// Clave del ícono de un tipo de arma (`espada+escudo` → `escudo`).
String iconKeyForType(String type) =>
    type.contains('escudo') ? 'escudo' : (_icons.containsKey(type) ? type : 'espada');

/// Clave y color de acento del ícono de una pila.
(String, Color) iconForStack(StackKind k) => switch (k) {
      StackKind.potion => ('pocion', ProtoColors.red),
      StackKind.ether => ('pocion', ProtoColors.ice),
      StackKind.esquirla => ('esquirla', RarityColors.stack),
      StackKind.cristal => ('cristal', ProtoColors.violet),
      StackKind.prisma => ('prisma', ProtoColors.gold),
    };

/// Ícono pixel (8 × 8 escalado) sin difuminado.
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.iconKey, {super.key, this.accent = ProtoColors.ice, this.size = 32});

  final String iconKey;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _PixelPainter(_icons[iconKey] ?? _icons['espada']!, accent),
      );
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.rows, this.accent);
  final List<String> rows;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 8;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final color = switch (rows[y][x]) {
          'm' => _metal,
          'h' => _handle,
          'g' => accent,
          's' => _string,
          'p' => _paper,
          'c' => _cover,
          'w' => _glass,
          _ => null,
        };
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(Rect.fromLTWH(x * px, y * px, px, px), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) => old.rows != rows || old.accent != accent;
}

// ---------------------------------------------------------------------
// Casilla
// ---------------------------------------------------------------------

/// Lo que hay en una casilla, resuelto para dibujar.
class CellContent {
  const CellContent.item(ItemInstance this.item)
      : stack = null,
        count = 1;
  const CellContent.stack(StackKind this.stack, this.count) : item = null;

  final ItemInstance? item;
  final StackKind? stack;
  final int count;
}

/// Casilla de inventario de [size] px: fondo `input`, borde del color de
/// la rareza (2 px; dorado y 3 px si está elegida), el ícono y, en las
/// pilas, la cantidad abajo a la derecha.
class ItemCell extends StatelessWidget {
  const ItemCell({
    super.key,
    required this.rules,
    this.content,
    this.selected = false,
    this.highlight = false,
    this.size = 44,
  });

  final ProgressionRules rules;
  final CellContent? content;
  final bool selected;

  /// Destino posible de un arrastre o de MOVER.
  final bool highlight;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = content;
    final Color border;
    Widget? icon;
    if (c?.item case final it?) {
      border = RarityColors.of(it.rarity);
      final type = rules.catalog.weapons[it.baseId]?.type ?? 'espada';
      icon = PixelIcon(iconKeyForType(type),
          accent: RarityColors.of(it.rarity), size: size - 12);
    } else if (c?.stack case final st?) {
      border = ProtoColors.panelBorder;
      final (key, accent) = iconForStack(st);
      icon = PixelIcon(key, accent: accent, size: size - 12);
    } else {
      border = ProtoColors.panelBorder;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: highlight ? ProtoColors.buttonHover : ProtoColors.input,
        border: Border.all(
          color: selected ? ProtoColors.gold : border,
          width: selected ? 3 : RetroTheme.thinBorderWidth,
        ),
      ),
      child: Stack(
        children: [
          if (icon != null) Center(child: icon),
          if (c?.stack != null)
            Positioned(
              right: 2,
              bottom: 0,
              child: Text('${c!.count}',
                  style: const TextStyle(
                      fontSize: 8,
                      color: ProtoColors.ink,
                      shadows: [Shadow(offset: Offset(1, 1))])),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Etiqueta de loot (estilo del filtro)
// ---------------------------------------------------------------------

/// Etiqueta de un drop como se vería en el mapa con el estilo del filtro
/// ([verdict]): color de texto, borde y fondo; tamaño 8 px (≥ 36 en el
/// filtro: 16 px). Oculto: texto `dim` y `(oculto)`.
class LootLabel extends StatelessWidget {
  const LootLabel({
    super.key,
    required this.text,
    required this.verdict,
    this.hiddenNote = '(oculto)',
    this.tooltip,
  });

  final String text;
  final FilterVerdict verdict;
  final String hiddenNote;

  /// Ficha al pasar el mouse (markup).
  final String? tooltip;

  /// Tamaño de letra para un tamaño de filtro (18–45).
  static double fontSizeFor(int? size) =>
      (size ?? FilterStyle.defaultSize) >= 36 ? 16 : 8;

  @override
  Widget build(BuildContext context) {
    final st = verdict.style;
    Widget label;
    if (!verdict.visible) {
      label = Text(retroText('$text $hiddenNote'),
          style: const TextStyle(
              color: ProtoColors.dim, decoration: TextDecoration.lineThrough));
    } else {
      final bg = st.backgroundColor;
      final bd = st.borderColor;
      label = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bg == null
              ? const Color(0xCC000000)
              : RarityColors.filterColor(bg),
          border: bd == null
              ? null
              : Border.all(color: RarityColors.filterColor(bd), width: 2),
        ),
        child: Text(retroText(text),
            style: TextStyle(
                fontSize: fontSizeFor(st.size),
                height: 1.4,
                color: st.textColor == null
                    ? ProtoColors.ink
                    : RarityColors.filterColor(st.textColor!))),
      );
    }
    if (tooltip != null) label = RetroTooltip(message: tooltip!, child: label);
    return label;
  }
}

/// Texto de una etiqueta de drop: nombre del arma o `N Material`.
String dropLabelText(ProgressionRules rules, LootDrop d) {
  final it = d.item;
  if (it != null) return rules.items.displayName(it);
  return d.count > 1 ? '${d.count} ${d.stack!.label}' : d.stack!.label;
}
