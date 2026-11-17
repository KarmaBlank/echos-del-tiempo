import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../combat/presentation/game_sprites.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import '../../../combat/presentation/weapon_overlay.dart';

/// `drawHero`, `drawEnemy`, los objetos del campo y `txt` del prototipo
/// (líneas 989-1018 y 1040-1052). Números en docs/specs/sprites.md y
/// docs/specs/exploration.md § "Objetos". Colores = arte del prototipo.
class ActorPainter {
  ActorPainter(this.sprites);

  final GameSprites sprites;

  final _fill = Paint()..isAntiAlias = false;
  final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..isAntiAlias = false;
  final _sprite = SpriteCatalog.pixelPaint();
  final _texts = <(String, int, double), TextPainter>{};

  static const _shadow = Color(0x66000000);

  void _rect(Canvas c, Color color, double x, double y, double w, double h) {
    _fill.color = color;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _fill);
  }

  void _oval(Canvas c, Color color, double cx, double cy, double rx, double ry) {
    _fill.color = color;
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
        _fill);
  }

  // ------------------------------------------------------------------
  // Texto (`txt`)
  // ------------------------------------------------------------------

  /// Texto centrado en x con la línea base en [y] y sombra negra +1/+1.
  void text(Canvas c, String s, double x, double y, Color color, double size) {
    final shadow = _layout(s, Colors.black, size);
    final fg = _layout(s, color, size);
    final left = x - fg.width / 2;
    final top = y - fg.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    shadow.paint(c, Offset((left + 1).roundToDouble(), (top + 1).roundToDouble()));
    fg.paint(c, Offset(left.roundToDouble(), top.roundToDouble()));
  }

  TextPainter _layout(String s, Color color, double size) {
    if (_texts.length > 256) _texts.clear();
    return _texts.putIfAbsent((s, color.toARGB32(), size), () {
      return TextPainter(
        text: TextSpan(
          text: retroText(s),
          style: TextStyle(
            fontFamily: RetroTheme.fontFamily,
            fontSize: size,
            color: color,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  // ------------------------------------------------------------------
  // Héroe (`drawHero`)
  // ------------------------------------------------------------------

  void hero(
    Canvas c, {
    required String classId,
    required String? weaponType,
    required double x,
    required double y,
    required double t,
    required int dir,
    required bool moving,
    required bool dead,
    required bool blink,
  }) {
    final img = sprites.hero(classId);
    c.save();
    c.translate(x.roundToDouble(), y.roundToDouble());
    final alpha = dead ? 0.55 : (blink ? 0.35 : 1.0);
    if (alpha < 1) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    if (dead) {
      c.rotate(math.pi / 2);
      c.translate(-6, -4);
    }
    if (dir < 0) c.scale(-1, 1);
    final bob = moving ? (t / 140).floor() % 2 : 0;
    _oval(c, _shadow, 0, 1, 6, 2);
    c.translate(0, -bob.toDouble());
    if (img != null) c.drawImage(img, const Offset(-7, -17), _sprite);
    WeaponOverlay.draw(c, classId, weaponType);
    if (alpha < 1) c.restore();
    c.restore();
  }

  // ------------------------------------------------------------------
  // Enemigo (`drawEnemy`)
  // ------------------------------------------------------------------

  /// Alto dibujado del enemigo (`hh`), para ubicar etiquetas.
  double enemyHeight(String type, {bool elite = false}) {
    final img = sprites.enemy(type);
    return img == null
        ? 16
        : img.height * sprites.enemyScale(type) * (elite ? 1.45 : 1);
  }

  void enemy(
    Canvas c, {
    required String type,
    required double x,
    required double y,
    required int dir,
    required double t,
    required bool elite,
  }) {
    final img = sprites.enemy(type);
    if (img == null) return;
    final sc = sprites.enemyScale(type) * (elite ? 1.45 : 1);
    final w = img.width * sc, h = img.height * sc;
    final fl = sprites.enemyFloats(type) ? math.sin(t / 200 + x) * 2 - 4 : 0.0;
    _oval(c, _shadow, x, y + 1, w * 0.35, 2.5 * sc);
    if (elite) {
      final a = (0.35 + 0.2 * math.sin(t / 180)).clamp(0.0, 1.0);
      _oval(c, const Color(0xFFFFD166).withValues(alpha: a), x, y - h / 2 + 2,
          w * 0.62, h * 0.6);
    }
    c.save();
    c.translate(x.roundToDouble(), (y + fl).roundToDouble());
    if (dir > 0) c.scale(-1, 1);
    c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(-w / 2, -h + 2, w, h),
        _sprite);
    c.restore();
  }

  // ------------------------------------------------------------------
  // Objetos del campo
  // ------------------------------------------------------------------

  void item(Canvas c, MissionItem it, double t) {
    final x = it.x, y = it.y;
    switch (it.kind) {
      case MissionItemKind.fragment:
        final b = math.sin(t / 250 + it.id) * 2;
        _oval(c, const Color(0x55000000), x, y + 2, 4, 1.5);
        _fill.color = const Color(0xFF48DBFB);
        c.drawPath(
            Path()
              ..moveTo(x, y - 12 + b)
              ..lineTo(x + 4, y - 6 + b)
              ..lineTo(x, y + b)
              ..lineTo(x - 4, y - 6 + b)
              ..close(),
            _fill);
        _rect(c, const Color(0xFFDFF9FB), x - 1, y - 9 + b, 2, 3);
        if ((t / 400 + it.id).floor() % 3 == 0) {
          _rect(c, const Color(0xFFFFFFFF), x + 3, y - 12 + b, 1, 1);
        }
      case MissionItemKind.seal:
        final on = it.done;
        _oval(c, _shadow, x, y + 2, 7, 2);
        _rect(c, on ? const Color(0xFF2D6A4F) : const Color(0xFF3D2C5A),
            x - 5, y - 16, 10, 18);
        final rune = on
            ? const Color(0xFF7BED9F)
            : const Color(0xFFA29BFE).withValues(
                alpha: (0.5 + 0.3 * math.sin(t / 200)).clamp(0.0, 1.0));
        _rect(c, rune, x - 2, y - 12, 4, 4);
        _rect(c, rune, x - 1, y - 7, 2, 5);
        if (on) {
          _fill.color = const Color(0x407BED9F);
          c.drawCircle(Offset(x, y - 8), 12, _fill);
        }
      case MissionItemKind.chest:
        final bob = math.sin(t / 300 + it.id) * 1.5;
        _oval(c, _shadow, x, y + 4, 8, 2.5);
        _rect(c, const Color(0xFF8A5A2B), x - 8, y - 6 + bob, 16, 10);
        _rect(c, const Color(0xFFB3781F), x - 8, y - 9 + bob, 16, 5);
        _rect(c, const Color(0xFFFFD166), x - 1, y - 5 + bob, 2, 5);
        _stroke.color = const Color(0xFF5A3A1A);
        c.drawRect(Rect.fromLTWH(x - 7.5, y - 8.5 + bob, 15, 14), _stroke);
        // Destello `✦`: rombo de 3 px (la fuente no tiene el glifo).
        final a = (0.5 + 0.3 * math.sin(t / 180)).clamp(0.0, 1.0);
        final spark = const Color(0xFFFFD166).withValues(alpha: a);
        final sy = (y - 16 + bob).roundToDouble();
        _rect(c, spark, x - 1, sy, 3, 1);
        _rect(c, spark, x, sy - 1, 1, 3);
    }
  }
}
