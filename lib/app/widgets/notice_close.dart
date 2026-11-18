import 'package:material_ui/material_ui.dart';

import '../theme/min_hit_target.dart';
import '../theme/proto_colors.dart';
import '../theme/retro_type.dart';

/// La `×` chica de un aviso del HUD con DURACIÓN DE LOS AVISOS = HASTA
/// CERRAR (docs/specs/accessibility.md § 9.5). Dibujada (dos diagonales
/// de 2 px, crece con el texto), con área de clic de al menos 24 px. No
/// toma el foco: el teclado cierra todos con `Retroceso`.
class NoticeClose extends StatelessWidget {
  const NoticeClose({super.key, required this.onPressed, this.color});

  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final side = RetroType.width(context, 10).roundToDouble();
    return Semantics(
      button: true,
      label: 'Cerrar aviso',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: MinHitTarget(
            child: CustomPaint(
              size: Size.square(side),
              painter: _CrossPainter(color ?? ProtoColors.dim),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..isAntiAlias = false;
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), p)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), p);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color;
}
