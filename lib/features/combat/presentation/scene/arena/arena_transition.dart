import 'package:material_ui/material_ui.dart';

/// Transición mapa ↔ arena (docs/specs/battle_presentation.md § "Arenas"
/// → "Transición"): un fundido de bloques de píxeles. La entrada la
/// dibuja la escena de batalla; la vuelta al mapa, [BattleExitWipe].
abstract final class ArenaWipe {
  /// Duración de cada transición.
  static const ms = 420.0;

  /// Destello blanco al entrar (× ajuste "Destellos").
  static const flashMs = 120.0;
  static const flashAlpha = 0.55;

  /// Color de los bloques.
  static const color = Color(0xFF05060C);

  /// Umbral (0..1) del bloque `(col, row)`: pseudoazar fijo con un leve
  /// barrido de izquierda a derecha (los bloques se van de a poco).
  static double threshold(int col, int row, int cols) {
    var h = (col * 73856093) ^ (row * 19349663);
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    final noise = (h & 0xFFFF) / 0x10000;
    final sweep = cols <= 1 ? 0.0 : col / (cols - 1);
    return (noise * 0.65 + sweep * 0.35).clamp(0.0, 0.999);
  }

  /// El bloque sigue tapando la escena con progreso [p] (0 = todo
  /// tapado, 1 = nada).
  static bool covered(double p, int col, int row, int cols) =>
      threshold(col, row, cols) >= p;

  /// Lado del bloque en px de pantalla para una escala [scale].
  static double blockPx(double scale) => (8 * scale).roundToDouble().clamp(6.0, 24.0);

  /// Tapa [area] con los bloques que siguen cubiertos con progreso [p].
  static void paint(Canvas canvas, Rect area, double p, double scale) {
    if (p >= 1) return;
    final b = blockPx(scale);
    final cols = (area.width / b).ceil(), rows = (area.height / b).ceil();
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    final path = Path();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (covered(p, c, r, cols)) {
          path.addRect(Rect.fromLTWH(area.left + c * b, area.top + r * b, b, b));
        }
      }
    }
    canvas.drawPath(path, paint);
  }

  /// Entrada a la arena a [age] ms del comienzo de la batalla: destello
  /// (× [flash]) y los bloques que se van.
  static void paintEnter(
      Canvas canvas, Rect area, double age, double scale, double flash) {
    if (age < 0 || age >= ms) return;
    if (age < flashMs && flash > 0) {
      canvas.drawRect(
          area,
          Paint()
            ..color = Color.fromRGBO(255, 255, 255,
                (flashAlpha * (1 - age / flashMs) * flash).clamp(0.0, 1.0)));
    }
    paint(canvas, area, Curves.easeOut.transform(age / ms), scale);
  }
}

/// Vuelta al mapa: cuando [inBattle] pasa de `true` a `false`, tapa la
/// pantalla con bloques que se van en [ArenaWipe.ms]. No toma clics.
class BattleExitWipe extends StatefulWidget {
  const BattleExitWipe({super.key, required this.inBattle});

  final bool inBattle;

  @override
  State<BattleExitWipe> createState() => _BattleExitWipeState();
}

class _BattleExitWipeState extends State<BattleExitWipe>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
      vsync: this, duration: Duration(milliseconds: ArenaWipe.ms.round()))
    ..value = 1;

  @override
  void didUpdateWidget(BattleExitWipe old) {
    super.didUpdateWidget(old);
    if (old.inBattle && !widget.inBattle) _anim.forward(from: 0);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => _anim.value >= 1
            ? const SizedBox.shrink()
            : CustomPaint(
                size: Size.infinite,
                painter: _WipePainter(Curves.easeOut.transform(_anim.value)),
              ),
      ),
    );
  }
}

class _WipePainter extends CustomPainter {
  _WipePainter(this.p);
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    final s = (size.width / 480).clamp(1.0, 4.0);
    ArenaWipe.paint(canvas, Offset.zero & size, p, s);
  }

  @override
  bool shouldRepaint(_WipePainter old) => old.p != p;
}
