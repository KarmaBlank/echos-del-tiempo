import 'dart:ui';

/// Lo que pide una etiqueta del HUD de la escena: su ancla (centro de
/// abajo, px de pantalla) y su tamaño.
class LabelRequest {
  const LabelRequest(this.id, this.anchor, this.size);

  final String id;

  /// Centro del borde de abajo, donde la etiqueta querría ir.
  final Offset anchor;
  final Size size;

  Rect get preferred => Rect.fromLTWH(anchor.dx - size.width / 2,
      anchor.dy - size.height, size.width, size.height);
}

/// Ubica las etiquetas sin que se superpongan (docs/specs/
/// battle_presentation.md § "Etiquetas"): de arriba hacia abajo, cada
/// una en la primera posición libre entre la preferida, corrida 1, 2 o 3
/// líneas hacia arriba, y corrida media etiqueta a un lado o al otro;
/// siempre dentro de [bounds]. Puro.
Map<String, Rect> placeLabels(List<LabelRequest> requests, Rect bounds,
    {double gap = 2}) {
  final order = [...requests]
    ..sort((a, b) => a.anchor.dy.compareTo(b.anchor.dy));
  final placed = <String, Rect>{};

  Rect inside(Rect r) {
    var dx = 0.0, dy = 0.0;
    if (r.left < bounds.left) dx = bounds.left - r.left;
    if (r.right + dx > bounds.right) dx = bounds.right - r.right;
    if (r.top < bounds.top) dy = bounds.top - r.top;
    if (r.bottom + dy > bounds.bottom) dy = bounds.bottom - r.bottom;
    return r.shift(Offset(dx, dy));
  }

  bool free(Rect r) {
    final grown = r.inflate(gap / 2);
    for (final p in placed.values) {
      if (grown.overlaps(p.inflate(gap / 2))) return false;
    }
    return true;
  }

  for (final q in order) {
    final base = q.preferred;
    final h = q.size.height + gap, w = q.size.width / 2 + gap;
    final candidates = <Offset>[
      Offset.zero,
      for (var k = 1; k <= 3; k++) Offset(0, -h * k),
      Offset(-w, 0),
      Offset(w, 0),
      for (var k = 1; k <= 2; k++) ...[Offset(-w, -h * k), Offset(w, -h * k)],
      for (var k = 1; k <= 3; k++) Offset(0, h * k),
    ];
    Rect? best;
    for (final c in candidates) {
      final r = inside(base.shift(c));
      if (free(r)) {
        best = r;
        break;
      }
    }
    if (best == null) {
      // Sin lugar libre: debajo de la más baja que choca.
      var r = inside(base);
      for (var i = 0; i < 20 && !free(r); i++) {
        r = r.shift(Offset(0, h));
      }
      best = r;
    }
    placed[q.id] = best;
  }
  return placed;
}
