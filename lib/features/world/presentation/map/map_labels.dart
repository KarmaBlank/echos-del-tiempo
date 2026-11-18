import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/pixel_label.dart';
import '../../../../app/theme/ui_theme.dart';
import '../../../../core/settings/game_settings.dart' show MapLabelBackdrop;

export '../../../../core/settings/game_settings.dart' show MapLabelBackdrop;

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

/// Alfa de la franja de SOMBREADO detrás del texto.
const kShadedLabelAlpha = 0.6;

/// La caja de fondo de un texto de [width] × [size] px con la línea base
/// en [baselineY], centrado en [cx] (FONDO DEL TEXTO EN EL MAPA).
Rect mapLabelBackdropRect(double cx, double baselineY, double width,
    double size, double u) {
  final r = Rect.fromLTWH(cx - width / 2 - 3 * u, baselineY - size - 2 * u,
      width + 6 * u, size + 4 * u);
  return Rect.fromLTRB(r.left.roundToDouble(), r.top.roundToDouble(),
      r.right.roundToDouble(), r.bottom.roundToDouble());
}

/// Dibuja [labels] en pantalla: el lienzo virtual ocupa [dst] (escala
/// `dst.width / virtualWidth`). [backdrop] (accesibilidad, § 9.6):
/// NINGUNO = solo la sombra; SOMBREADO = franja del fondo del tema al
/// 60 %; CAJA OPACA = caja del fondo del tema con borde (y la caja del
/// loot sin transparencia).
void paintMapLabels(Canvas canvas, List<MapLabel> labels, Rect dst,
    double virtualWidth, PixelLabelPen pen,
    {MapLabelBackdrop backdrop = MapLabelBackdrop.none}) {
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
        final size = PixelLabelPen.screenSize(l.worldSize, k);
        if (backdrop != MapLabelBackdrop.none) {
          final r = mapLabelBackdropRect(
              p.dx, p.dy, pen.width(l.text, size), size, u);
          final a = l.color.a;
          canvas.drawRect(
              r,
              fill
                ..color = UiTheme.of(UiSlot.bg).withValues(
                    alpha: (backdrop == MapLabelBackdrop.box
                            ? 1.0
                            : kShadedLabelAlpha) *
                        a));
          if (backdrop == MapLabelBackdrop.box) {
            canvas.drawRect(
                r.deflate(u / 2),
                Paint()
                  ..isAntiAlias = false
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = u
                  ..color = UiTheme.of(UiSlot.panelBorder)
                      .withValues(alpha: a));
          }
        }
        pen.text(canvas, l.text, p.dx, p.dy, l.color, size,
            shadow: backdrop != MapLabelBackdrop.box);
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
        canvas.drawRect(
            r,
            fill
              ..color = backdrop == MapLabelBackdrop.box
                  ? l.background.withValues(alpha: 1)
                  : l.background);
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

/// Muestra de FONDO DEL TEXTO EN EL MAPA para la vista previa de
/// ACCESIBILIDAD: un nombre sobre tiles cargados (pasto y piedras, con los
/// colores del arte del mapa) dibujado igual que en el juego.
class MapLabelSamplePainter extends CustomPainter {
  MapLabelSamplePainter({required this.backdrop, this.size = 8});

  final MapLabelBackdrop backdrop;

  /// Tamaño de la etiqueta en pantalla (8 o 16 px).
  final double size;

  final _pen = PixelLabelPen();

  // Arte del mapa (como TilePainter): no sigue el tema.
  static const _tileA = Color(0xFF4E7A3A);
  static const _tileB = Color(0xFF6E9A4A);
  static const _stone = Color(0xFFB8B8A0);

  @override
  void paint(Canvas canvas, Size box) {
    const t = 8.0;
    final p = Paint()..isAntiAlias = false;
    for (var y = 0.0; y < box.height; y += t) {
      for (var x = 0.0; x < box.width; x += t) {
        final i = (x ~/ t) + (y ~/ t);
        canvas.drawRect(Rect.fromLTWH(x, y, t, t),
            p..color = i.isEven ? _tileA : _tileB);
        if ((x ~/ t) % 3 == (y ~/ t) % 2) {
          canvas.drawRect(
              Rect.fromLTWH(x + 2, y + 2, 3, 2), p..color = _stone);
        }
      }
    }
    final m = Float64List(16)
      ..[0] = 1
      ..[5] = 1
      ..[10] = 1
      ..[15] = 1;
    paintMapLabels(
        canvas,
        [
          MapTextLabel(m, 'Herrera Ana', box.width / 2, box.height / 2 + size / 2,
              const Color(0xFFFFFFFF), size >= 16 ? 8 : 6),
        ],
        Offset.zero & box,
        box.width,
        _pen,
        backdrop: backdrop);
  }

  @override
  bool shouldRepaint(MapLabelSamplePainter old) =>
      old.backdrop != backdrop || old.size != size;
}
