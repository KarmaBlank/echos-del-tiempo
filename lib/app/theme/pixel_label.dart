import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'retro_text.dart';
import 'retro_theme.dart';

/// Etiquetas de texto pixel dibujadas en px de PANTALLA (nombres sobre
/// los personajes, carteles del pueblo, avisos, loot del piso): Press
/// Start 2P a un múltiplo de 8 px, peso normal, sombra negra de 1 px (o
/// contorno), posición redondeada al pixel. Es el estilo de los nombres
/// de la batalla ("Karmona"): fino y limpio. Nunca se dibujan en el
/// lienzo virtual que después se agranda (eso las hace gordas y
/// borrosas). Ver docs/specs/ui_style.md § "Etiquetas en el mundo".
class PixelLabelPen {
  final _texts = <(String, int, double), TextPainter>{};

  /// La grilla de Press Start 2P: tamaños nítidos.
  static const grid = 8.0;

  /// Unidad de las etiquetas para una escala del mundo [k] (px de
  /// pantalla por px virtual): 1 hasta ×2, 2 desde ahí (como
  /// `SceneGeometry.hudUnit` de la batalla).
  static int unitFor(double k) => k < 2 ? 1 : 2;

  /// Tamaño en pantalla de una etiqueta pensada a [worldSize] px
  /// virtuales: 8·u las chicas (nombres, carteles), 16·u las grandes
  /// (avisos de 8 px o más).
  static double screenSize(double worldSize, double k) =>
      (worldSize >= 8 ? 2 : 1) * grid * unitFor(k);

  TextPainter layout(String s, Color color, double size) {
    if (_texts.length > 300) _texts.clear();
    return _texts.putIfAbsent((s, color.toARGB32(), size), () {
      return TextPainter(
        text: TextSpan(
          text: retroText(s),
          style: TextStyle(
              fontFamily: RetroTheme.fontFamily,
              fontSize: size,
              fontWeight: FontWeight.normal,
              color: color,
              height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Ancho de [s] en [size] px.
  double width(String s, double size) => layout(s, Colors.white, size).width;

  /// Texto con la línea base en [y]; centrado en [x] o desde [x]. Sombra
  /// negra (1 px; `size/8` desde 16 px) o, con [outline], contorno.
  void text(Canvas c, String s, double x, double y, Color color, double size,
      {bool center = true, bool shadow = true, bool outline = false}) {
    final fg = layout(s, color, size);
    final left = center ? x - fg.width / 2 : x;
    final top = y - fg.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final l = left.roundToDouble(), tp = top.roundToDouble();
    final a = color.a;
    Color black() => Colors.black.withValues(alpha: a);
    if (outline) {
      final bk = layout(s, black(), size);
      final o = (size / 8).roundToDouble().clamp(1.0, 4.0);
      for (final d in [
        Offset(-o, 0), Offset(o, 0), Offset(0, -o), Offset(0, o), //
        Offset(o, o), Offset(-o, o), Offset(o, -o), Offset(-o, -o),
      ]) {
        bk.paint(c, Offset(l, tp) + d);
      }
    } else if (shadow) {
      final o = size >= 16 ? math.max(1.0, (size / 8).roundToDouble()) : 1.0;
      layout(s, black(), size).paint(c, Offset(l + o, tp + o));
    }
    fg.paint(c, Offset(l, tp));
  }
}
