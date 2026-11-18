import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/pixel_label.dart';

/// Una etiqueta del mapa (nombre, cartel, aviso o loot del piso) anotada
/// mientras se dibuja el mundo en el lienzo virtual y dibujada después en
/// px de PANTALLA con [PixelLabelPen]: nítida, fina y del mismo estilo
/// que los nombres de la batalla (docs/specs/ui_style.md § "Etiquetas en
/// el mundo"). Guarda la transformación del lienzo de cuando se pidió
/// (cámara, zoom de una animación) para ubicarla igual.
sealed class MapLabel {
  const MapLabel(this.transform);

  /// `Canvas.getTransform()` al pedirla (4×4, por columnas).
  final Float64List transform;

  /// [p] (coordenadas de quien la pidió) → px del lienzo virtual.
  Offset toVirtual(Offset p) {
    final m = transform;
    return Offset(m[0] * p.dx + m[4] * p.dy + m[12],
        m[1] * p.dx + m[5] * p.dy + m[13]);
  }
}

/// Texto centrado con la línea base en ([x], [y]).
class MapTextLabel extends MapLabel {
  const MapTextLabel(super.transform, this.text, this.x, this.y, this.color,
      this.worldSize);

  final String text;
  final double x, y;
  final Color color;

  /// Tamaño pensado en px virtuales (decide chica / grande).
  final double worldSize;
}

/// Etiqueta de loot: caja ([rect], px del mundo) con fondo, borde y texto.
class MapBoxLabel extends MapLabel {
  const MapBoxLabel(super.transform, this.rect, this.text,
      {required this.textColor,
      required this.background,
      this.border,
      required this.worldSize});

  final Rect rect;
  final String text;
  final Color textColor, background;
  final Color? border;
  final double worldSize;
}

/// Dibuja [labels] en pantalla: el lienzo virtual ocupa [dst] (escala
/// `dst.width / virtualWidth`).
void paintMapLabels(Canvas canvas, List<MapLabel> labels, Rect dst,
    double virtualWidth, PixelLabelPen pen) {
  if (labels.isEmpty) return;
  final k = dst.width / virtualWidth;
  final u = PixelLabelPen.unitFor(k).toDouble();
  Offset screen(Offset v) =>
      Offset((dst.left + v.dx * k).roundToDouble(),
          (dst.top + v.dy * k).roundToDouble());
  final fill = Paint()..isAntiAlias = false;
  for (final l in labels) {
    switch (l) {
      case MapTextLabel():
        final p = screen(l.toVirtual(Offset(l.x, l.y)));
        pen.text(canvas, l.text, p.dx, p.dy, l.color,
            PixelLabelPen.screenSize(l.worldSize, k));
      case MapBoxLabel():
        // La caja se arma alrededor del texto nítido, centrada donde la
        // ubicó el mundo (sin superponerse con las otras).
        final size = PixelLabelPen.screenSize(l.worldSize, k);
        final w = pen.width(l.text, size);
        final c = screen(l.toVirtual(l.rect.center));
        final box = Rect.fromCenter(
            center: c, width: w + 6 * u, height: size + 4 * u);
        final r = Rect.fromLTWH(box.left.roundToDouble(),
            box.top.roundToDouble(), box.width.roundToDouble(),
            box.height.roundToDouble());
        canvas.drawRect(r, fill..color = l.background);
        if (l.border case final b?) {
          canvas.drawRect(
              r,
              Paint()
                ..isAntiAlias = false
                ..style = PaintingStyle.stroke
                ..strokeWidth = u
                ..color = b);
        }
        pen.text(canvas, l.text, r.left + 3 * u, r.top + 2 * u + size,
            l.textColor, size,
            center: false, shadow: false);
    }
  }
}
