import 'package:material_ui/material_ui.dart';

import '../../../game_engine/models/status.dart';
import 'scene/fx_style.dart';

/// Íconos pixel art de los estados elementales de v0.7
/// (docs/specs/elemental_reactions.md § 3 y § 8): gota = Mojado
/// (`status_wet`), rayo = Cargado (`status_charged`). Son arte de
/// interfaz chico como las letras de estado (`statusLetter`), dibujado
/// con rectángulos a 1 px por celda: la forma distingue el estado aunque
/// no se vea el color (accessibility.md § 3), y el chip suma su letra.
///
/// Grillas de 8×8: `X` contorno, `C` color del estado, `L` brillo, `.`
/// transparente.
const Map<String, List<String>> kStatusIconRows = {
  'status_wet': [
    '...XX...',
    '..XCCX..',
    '..XCCX..',
    '.XCCCCX.',
    'XCLCCCCX',
    'XCLCCCCX',
    '.XCCCCX.',
    '..XXXX..',
  ],
  'status_charged': [
    '....XXXX',
    '...XLCCX',
    '..XCCCX.',
    '.XCCCCXX',
    '.XXXCCCX',
    '...XCCX.',
    '..XCCX..',
    '..XXX...',
  ],
};

/// Lado de la grilla (celdas).
const kStatusIconCells = 8;

/// Id de ícono de [k] (`StatusKind.iconId`) si tiene ícono dibujado
/// (Mojado, Cargado); los demás van solo con letra.
String? statusIconOf(StatusKind k) =>
    kStatusIconRows.containsKey(k.iconId) ? k.iconId : null;

/// Estado del ícono [id].
StatusKind _kindOf(String id) =>
    StatusKind.values.firstWhere((k) => k.iconId == id);

const _outline = Color(0xFF0B0E1A);
const _shine = Color(0xFFFFFFFF);

/// Dibuja el ícono [id] con su esquina en `(x, y)`, [px] por celda (en
/// la escena: el `u` de las etiquetas). Sin suavizado; color del estado
/// (`statusColor`).
void paintStatusIcon(Canvas c, String id, double x, double y, double px) {
  final rows = kStatusIconRows[id];
  if (rows == null) return;
  final fill = Paint()..isAntiAlias = false;
  final col = statusColor(_kindOf(id));
  for (var j = 0; j < rows.length; j++) {
    final r = rows[j];
    for (var i = 0; i < r.length; i++) {
      final Color? k = switch (r[i]) {
        'X' => _outline,
        'C' => col,
        'L' => _shine,
        _ => null,
      };
      if (k == null) continue;
      fill.color = k;
      c.drawRect(Rect.fromLTWH(x + i * px, y + j * px, px, px), fill);
    }
  }
}

/// El ícono [id] como widget, [px] píxeles lógicos por celda.
class StatusIcon extends StatelessWidget {
  const StatusIcon(this.id, {super.key, this.px = 1});

  final String id;
  final double px;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: kStatusIconCells * px,
        child: CustomPaint(painter: _IconPainter(id, px)),
      );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.id, this.px);

  final String id;
  final double px;

  @override
  void paint(Canvas canvas, Size size) =>
      paintStatusIcon(canvas, id, 0, 0, px);

  @override
  bool shouldRepaint(_IconPainter old) => old.id != id || old.px != px;
}
