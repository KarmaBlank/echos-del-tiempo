import 'dart:math' as math;
import 'dart:ui';

import '../../../game_engine/data/ascension_catalog.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/sprite_catalog.dart';

/// Aura permanente de un héroe ascendido (docs/specs/ascension.md § 5),
/// en batalla y en el mapa. Se dibuja DETRÁS del héroe con el lienzo ya
/// trasladado a sus pies (y espejado si mira a la izquierda): el sprite
/// `aura_<ascensión>` (24 × 26 en (−12, −25), alfa `0.65 + 0.25 ·
/// sin(t / 220)`) o, si no está, un anillo pintado con motas que suben.
void paintAscensionAura(Canvas c, String? ascensionId,
    {GameSprites? sprites, required double t}) {
  final a = kAscensions[ascensionId];
  if (a == null) return;
  final alpha = 0.65 + 0.25 * math.sin(t / 220);
  final img = sprites?.aura(a.id);
  if (img != null) {
    c.drawImage(
        img,
        const Offset(-12, -25),
        SpriteCatalog.pixelPaint()
          ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0)));
    return;
  }
  final col = Color(a.color);
  final pen = Paint()..isAntiAlias = false;
  pen
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = col.withValues(alpha: 0.35 + 0.3 * alpha);
  c.drawOval(
      Rect.fromCenter(center: const Offset(0, 1), width: 18, height: 6), pen);
  pen
    ..style = PaintingStyle.fill
    ..color = col.withValues(alpha: 0.12 + 0.1 * alpha);
  c.drawOval(
      Rect.fromCenter(center: const Offset(0, -8), width: 20, height: 24), pen);
  for (var i = 0; i < 4; i++) {
    final q = ((t / 900) + i / 4) % 1;
    pen.color = col.withValues(alpha: (1 - q) * 0.9);
    c.drawRect(
        Rect.fromLTWH(((i * 5) % 14 - 7).toDouble(), -2 - q * 20, 1, 1), pen);
  }
}
