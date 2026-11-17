import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'sprite_catalog.dart';

/// Un sprite pixel art escalado con vecino más cercano
/// (docs/specs/sprites.md § "Dibujo: filtrado"). El tamaño es
/// `imagen × scale`, redondeado a píxel entero.
class PixelSprite extends StatelessWidget {
  const PixelSprite(this.image,
      {super.key, required this.scale, this.flipX = false, this.opacity = 1});

  final ui.Image image;
  final double scale;

  /// Espejar horizontalmente (el arte del héroe mira a la derecha; el
  /// de los enemigos, a la izquierda).
  final bool flipX;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (image.width * scale).roundToDouble(),
      height: (image.height * scale).roundToDouble(),
      child: CustomPaint(painter: _PixelPainter(image, flipX, opacity)),
    );
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.image, this.flipX, this.opacity);

  final ui.Image image;
  final bool flipX;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = SpriteCatalog.pixelPaint()
      ..color = Color.fromRGBO(0, 0, 0, opacity);
    canvas.save();
    if (flipX) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PixelPainter old) =>
      old.image != image || old.flipX != flipX || old.opacity != opacity;
}
