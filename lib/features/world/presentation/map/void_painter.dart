import 'dart:math' as math;
import 'dart:ui';

import '../../../../core/settings/graphics.dart';
import 'map_themes.dart';
import 'tile_painter.dart';

/// Fondo del vacío de las zonas de abismo, en coordenadas de pantalla
/// virtual (debajo de los tiles): degradado en bandas, dos capas de
/// estrellas con paralaje y motas de tiempo que derivan. Ver
/// docs/specs/exploration.md § "Fondo del vacío".
class VoidPainter {
  final _paint = Paint()..isAntiAlias = false;

  /// Bandas del degradado (pixelado, sin suavizar).
  static const bands = 12;

  /// Lado de la celda de la grilla de estrellas (px).
  static const cell = 24.0;

  /// Paralaje de las capas de estrellas respecto de la cámara.
  static const parallax = (0.35, 0.15);

  void _rect(Canvas c, Color color, double x, double y, double w, double h) {
    _paint.color = color;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _paint);
  }

  /// Color de las estrellas por tema.
  static Color starTint(String themeId) => switch (themeId) {
        'cementerio' => const Color(0xFFC8A8FF),
        'corazon' => const Color(0xFFFFE6A0),
        _ => const Color(0xFF9FC4FF),
      };

  /// Pinta el fondo en el rectángulo virtual [w] × [h] con la cámara en
  /// ([camX], [camY]).
  void draw(Canvas c, String themeId, double w, double h,
      {required double camX,
      required double camY,
      required double t,
      double density = 1}) {
    final (top, bottom) = voidGradient(themeId);
    final bh = (h / bands).ceilToDouble();
    for (var i = 0; i < bands; i++) {
      _rect(c, Color.lerp(top, bottom, i / (bands - 1))!, 0, i * bh, w, bh);
    }
    final tint = starTint(themeId);
    _stars(c, w, h, camX * parallax.$2, camY * parallax.$2, t, 11, tint,
        dim: true);
    _stars(c, w, h, camX * parallax.$1, camY * parallax.$1, t, 0, tint);
    // Motas de tiempo que derivan.
    final n = scaledCount(14, density);
    for (var i = 0; i < n; i++) {
      final speed = 1 + i % 3;
      final x = ((i * 53 + t / 60 * speed) % (w + 20)) - 10;
      final y = ((i * 37 + math.sin(t / 900 + i) * 8 + t / 400 * (i % 2)) % h)
          .floorToDouble();
      final a = 0.25 + 0.25 * math.sin(t / 300 + i);
      _rect(c, tint.withValues(alpha: a.clamp(0.0, 1.0)), x.floorToDouble(), y,
          i % 4 == 0 ? 2 : 1, 1);
    }
  }

  void _stars(Canvas c, double w, double h, double ox, double oy, double t,
      int salt, Color tint,
      {bool dim = false}) {
    final gx0 = (ox / cell).floor(), gy0 = (oy / cell).floor();
    final cols = (w / cell).ceil() + 1, rows = (h / cell).ceil() + 1;
    for (var gy = gy0; gy <= gy0 + rows; gy++) {
      for (var gx = gx0; gx <= gx0 + cols; gx++) {
        final hsh = TilePainter.tileHash(gx + salt * 31, gy + salt * 17);
        if (hsh % 3 != 0) continue;
        final sx = (gx * cell + (hsh >> 4) % cell - ox).floorToDouble();
        final sy = (gy * cell + (hsh >> 9) % cell - oy).floorToDouble();
        if (sx < -2 || sy < -2 || sx > w || sy > h) continue;
        var a = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t / 400 + hsh % 17));
        if (dim) a *= 0.45;
        final col = (hsh % 4 == 0 ? const Color(0xFFFFFFFF) : tint)
            .withValues(alpha: a.clamp(0.0, 1.0));
        _rect(c, col, sx, sy, 1, 1);
        if (!dim && hsh % 7 == 0) {
          // Estrella grande en cruz.
          final arm = col.withValues(alpha: a * 0.5);
          _rect(c, arm, sx - 1, sy, 1, 1);
          _rect(c, arm, sx + 1, sy, 1, 1);
          _rect(c, arm, sx, sy - 1, 1, 1);
          _rect(c, arm, sx, sy + 1, 1, 1);
        }
      }
    }
  }
}
