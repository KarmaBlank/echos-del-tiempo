import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/pixel_label.dart';
import '../../../../app/theme/ui_theme.dart';
import '../../../../core/settings/game_settings.dart' show MapLabelBackdrop;

import '../../../../game_engine/data/tuning_catalog.dart';

export '../../../../core/settings/game_settings.dart' show MapLabelBackdrop;

/// Opacity of a world label (NPC, place, sign or object name) whose anchor
/// is ([dx], [dy]) px from the local player, with [tile] px per tile: 1
/// within `labelRevealTiles` (Balance › Pueblo), fading to 0 over one more
/// tile (ui_style.md § "Etiquetas en el mundo"). Players' names do not use
/// it: they always show.
double worldLabelAlpha(double dx, double dy, double tile) {
  final d = math.sqrt(dx * dx + dy * dy) / tile;
  final range = tuning(TuningId.town).d('labelRevealTiles');
  return (1 - (d - range)).clamp(0.0, 1.0);
}

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
    return Offset(
        m[0] * p.dx + m[4] * p.dy + m[12], m[1] * p.dx + m[5] * p.dy + m[13]);
  }
}

/// Texto centrado con la línea base en ([x], [y]).
class MapTextLabel extends MapLabel {
  const MapTextLabel(
      super.transform, this.text, this.x, this.y, this.color, this.worldSize,
      {this.priority});

  final String text;
  final double x, y;
  final Color color;

  /// Tamaño pensado en px virtuales (decide chica / grande).
  final double worldSize;

  /// Con prioridad (lugares del pueblo, carteles): no se pisa con otras
  /// etiquetas con prioridad; si choca se corre hacia arriba o, si no
  /// entra, se oculta la de menor prioridad (número más alto). `null` =
  /// siempre se dibuja donde se pidió (nombres, avisos).
  final int? priority;
}

/// Ubica cajas de etiquetas sin que se pisen (ui_style.md § "Etiquetas
/// en el mundo", town_editor.md § 1.4). [boxes] en px de pantalla y
/// [priority] (más bajo = más importante) del mismo largo. Cada caja, en
/// orden de prioridad, prueba quedarse, subir uno o dos renglones o
/// bajar uno; si todas chocan con una ya ubicada, se oculta (`null`).
/// Devuelve el corrimiento vertical de cada una. Pura: sin dibujo.
List<double?> placeLabels(List<Rect> boxes, List<int> priority,
    {double gap = 2, Rect? bounds}) {
  final order = List.generate(boxes.length, (i) => i)
    ..sort((a, b) {
      final c = priority[a].compareTo(priority[b]);
      return c != 0 ? c : a.compareTo(b);
    });
  final out = List<double?>.filled(boxes.length, null);
  final placed = <Rect>[];
  for (final i in order) {
    final b = boxes[i];
    final step = b.height + gap;
    for (final dy in [0.0, -step, -2 * step, step]) {
      final r = b.shift(Offset(0, dy));
      // Fuera de [bounds] (arriba o abajo) se cortaría: otra posición.
      if (bounds != null &&
          (r.top < bounds.top - 0.5 || r.bottom > bounds.bottom + 0.5)) {
        continue;
      }
      if (placed.any((p) => p.overlaps(r))) continue;
      placed.add(r);
      out[i] = dy;
      break;
    }
  }
  return out;
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
Rect mapLabelBackdropRect(
    double cx, double baselineY, double width, double size, double u) {
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
    {MapLabelBackdrop backdrop = MapLabelBackdrop.none, double zoom = 1}) {
  if (labels.isEmpty) return;
  // Con zoom (edición del pueblo) las letras se achican con el mapa.
  final k = dst.width / virtualWidth / zoom;
  final kPos = dst.width / virtualWidth;
  final u = PixelLabelPen.unitFor(k).toDouble();
  Offset screen(Offset v) => Offset((dst.left + v.dx * kPos).roundToDouble(),
      (dst.top + v.dy * kPos).roundToDouble());
  final fill = Paint()..isAntiAlias = false;
  // Las que tienen prioridad no se pisan entre sí.
  final ranked = <int>[];
  final boxes = <Rect>[];
  final clampX = <int, Offset>{};
  for (var i = 0; i < labels.length; i++) {
    final l = labels[i];
    if (l is! MapTextLabel || l.priority == null) continue;
    final p = screen(l.toVirtual(Offset(l.x, l.y)));
    final size = PixelLabelPen.screenSize(l.worldSize, k);
    ranked.add(i);
    var b = mapLabelBackdropRect(p.dx, p.dy, pen.width(l.text, size), size, u);
    // Adentro de la pantalla: no se corta en los bordes.
    if (b.left < dst.left) b = b.shift(Offset(dst.left - b.left, 0));
    if (b.right > dst.right) b = b.shift(Offset(dst.right - b.right, 0));
    if (b.top < dst.top) b = b.shift(Offset(0, dst.top - b.top));
    if (b.bottom > dst.bottom) b = b.shift(Offset(0, dst.bottom - b.bottom));
    clampX[i] = Offset((b.center.dx - p.dx).roundToDouble(),
        (b.center.dy - mapLabelBackdropRect(p.dx, p.dy, 0, size, u).center.dy)
            .roundToDouble());
    // Un margen a los costados: dos nombres pegados se leen como uno.
    boxes.add(Rect.fromLTRB(b.left - 6 * u, b.top, b.right + 6 * u, b.bottom));
  }
  final shifts = <int, double?>{};
  if (ranked.isNotEmpty) {
    final dy = placeLabels(
        boxes, [for (final i in ranked) (labels[i] as MapTextLabel).priority!],
        bounds: dst);
    for (var j = 0; j < ranked.length; j++) {
      shifts[ranked[j]] = dy[j];
    }
  }
  for (var i = 0; i < labels.length; i++) {
    final l = labels[i];
    switch (l) {
      case MapTextLabel():
        var p = screen(l.toVirtual(Offset(l.x, l.y)));
        if (shifts.containsKey(i)) {
          final dy = shifts[i];
          if (dy == null) continue;
          final c = clampX[i] ?? Offset.zero;
          p = p.translate(c.dx, c.dy + dy);
        }
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
                  ..color =
                      UiTheme.of(UiSlot.panelBorder).withValues(alpha: a));
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
        final box =
            Rect.fromCenter(center: c, width: w + 6 * u, height: size + 4 * u);
        final r = Rect.fromLTWH(
            box.left.roundToDouble(),
            box.top.roundToDouble(),
            box.width.roundToDouble(),
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
        canvas.drawRect(
            Rect.fromLTWH(x, y, t, t), p..color = i.isEven ? _tileA : _tileB);
        if ((x ~/ t) % 3 == (y ~/ t) % 2) {
          canvas.drawRect(Rect.fromLTWH(x + 2, y + 2, 3, 2), p..color = _stone);
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
          MapTextLabel(
              m,
              'Herrera Ana',
              box.width / 2,
              box.height / 2 + size / 2,
              const Color(0xFFFFFFFF),
              size >= 16 ? 8 : 6),
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
