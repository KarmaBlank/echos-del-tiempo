import 'package:material_ui/material_ui.dart';

import '../theme/proto_colors.dart';

/// Íconos pixel de 8 × 8 dibujados con un `CustomPainter` (sin assets):
/// cada `#` es un píxel. Se escalan a múltiplos enteros para quedar
/// nítidos. Ver docs/specs/ui_style.md § "Menús: tarjetas".
enum PixelIconKind {
  dice([
    '########',
    '#......#',
    '#.#..#.#',
    '#......#',
    '#......#',
    '#.#..#.#',
    '#......#',
    '########',
  ]),
  plus([
    '...##...',
    '...##...',
    '...##...',
    '########',
    '########',
    '...##...',
    '...##...',
    '...##...',
  ]),
  gem([
    '..####..',
    '.#.##.#.',
    '########',
    '.#....#.',
    '..#..#..',
    '...##...',
    '........',
    '........',
  ]),
  arrowIn([
    '....#...',
    '....##..',
    '#######.',
    '########',
    '#######.',
    '....##..',
    '....#...',
    '........',
  ]),
  star([
    '...##...',
    '...##...',
    '########',
    '.######.',
    '..####..',
    '.##..##.',
    '.#....#.',
    '........',
  ]),
  trash([
    '.######.',
    '########',
    '.#.##.#.',
    '.#.##.#.',
    '.#.##.#.',
    '.#.##.#.',
    '.######.',
    '........',
  ]),
  anvil([
    '########',
    '.#######',
    '..####..',
    '...##...',
    '..####..',
    '.######.',
    '........',
    '........',
  ]),
  lock([
    '..####..',
    '.#....#.',
    '.#....#.',
    '########',
    '###..###',
    '###..###',
    '########',
    '........',
  ]),
  coin([
    '..####..',
    '.##..##.',
    '##.##.##',
    '##.##.##',
    '##.##.##',
    '.##..##.',
    '..####..',
    '........',
  ]),
  sword([
    '.......#',
    '......#.',
    '.....#..',
    '#...#...',
    '.#.#....',
    '..#.....',
    '.#.#....',
    '#.......',
  ]),
  shard([
    '...#....',
    '..##....',
    '..###...',
    '.####...',
    '.#####..',
    '..####..',
    '...##...',
    '........',
  ]),
  prism([
    '...##...',
    '...##...',
    '..####..',
    '..####..',
    '.######.',
    '.######.',
    '########',
    '........',
  ]),
  anchor([
    '...##...',
    '..#..#..',
    '...##...',
    '...##...',
    '#..##..#',
    '##.##.##',
    '.######.',
    '..####..',
  ]),
  check([
    '........',
    '.......#',
    '......##',
    '#....##.',
    '##..##..',
    '.####...',
    '..##....',
    '........',
  ]);

  const PixelIconKind(this.rows);
  final List<String> rows;
}

/// Un [PixelIconKind] de [size] px (se redondea a un múltiplo de 8 para
/// que cada píxel sea entero) en [color].
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.kind,
      {super.key, this.size = 16, this.color = ProtoColors.ink});

  final PixelIconKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final px = (size / 8).floorToDouble().clamp(1.0, 64.0);
    return SizedBox(
      width: px * 8,
      height: px * 8,
      child: CustomPaint(painter: _PixelPainter(kind.rows, px, color)),
    );
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.rows, this.px, this.color);

  final List<String> rows;
  final double px;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      final r = rows[y];
      for (var x = 0; x < r.length; x++) {
        if (r[x] == '#') {
          canvas.drawRect(Rect.fromLTWH(x * px, y * px, px, px), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) =>
      old.rows != rows || old.px != px || old.color != color;
}
