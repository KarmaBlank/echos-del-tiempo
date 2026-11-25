import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';import 'map_labels.dart';


import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../ascension/presentation/ascension_aura.dart';
import '../../../combat/presentation/game_sprites.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import '../../../../core/procedural/weapon_look.dart';
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

  /// Px the body drops when seated.
  static const seatDrop = 3.0;

  /// Seated pose (fishing on the raft), derived from the hero sprite so
  /// every class and ascension sits without extra art: head and torso
  /// (rows 0..11) drop [seatDrop] px, the legs become a bent strip (thighs
  /// forward, shins down) painted with the sprite's own pants, boot and
  /// outline pixels. Faces +x (the caller mirrors for dir < 0).
  void _seated(Canvas c, ui.Image img) {
    void fill(int sx, int sy, Rect dst) => c.drawImageRect(
        img, Rect.fromLTWH(sx.toDouble(), sy.toDouble(), 1, 1), dst, _sprite);
    const outline = (3, 12), pants = (4, 12), boot = (3, 15);
    // Two bent legs side by side (3/4 top-down): the far one first, the
    // near one 1 px lower and 3 px forward, so the outline column between
    // the shins reads as the gap. Each: thigh forward, shin down, boot.
    void leg(double x0, double y0) {
      fill(outline.$1, outline.$2, Rect.fromLTWH(x0 - 1, y0 - 1, 8, 4));
      fill(outline.$1, outline.$2, Rect.fromLTWH(x0 + 3, y0 + 1, 4, 6));
      fill(outline.$1, outline.$2, Rect.fromLTWH(x0 + 3, y0 + 4, 5, 3));
      fill(pants.$1, pants.$2, Rect.fromLTWH(x0, y0, 6, 2));
      fill(pants.$1, pants.$2, Rect.fromLTWH(x0 + 4, y0 + 2, 2, 3));
      fill(boot.$1, boot.$2, Rect.fromLTWH(x0 + 4, y0 + 5, 3, 1));
    }

    leg(-3, -4);
    leg(0, -3);
    final w = img.width.toDouble();
    c.drawImageRect(img, Rect.fromLTWH(0, 0, w, 12),
        Rect.fromLTWH(-7, -17 + seatDrop, w, 12), _sprite);
  }
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

  /// Si está, [text] no dibuja en el lienzo virtual: anota la etiqueta
  /// para dibujarla nítida en px de pantalla (`MapGame.render`,
  /// `paintMapLabels`).
  List<MapLabel>? labelSink;

  /// Texto centrado en x con la línea base en [y] y sombra negra +1/+1.
  void text(Canvas c, String s, double x, double y, Color color, double size) {
    final sink = labelSink;
    if (sink != null) {
      sink.add(MapTextLabel(c.getTransform(), s, x, y, color, size));
      return;
    }
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
    String? ascensionId,
    WeaponLook? look,
    bool showWeapon = true,
    bool seated = false,
  }) {
    final img = sprites.heroFor(classId, ascensionId);
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
    // Seated, the seat under them casts the contact shadow.
    if (!seated) _oval(c, _shadow, 0, 1, 6, 2);
    // Aura de la ascensión (docs/specs/ascension.md § 5).
    if (!dead) paintAscensionAura(c, ascensionId, sprites: sprites, t: t);
    c.translate(0, -bob.toDouble());
    if (img != null && seated && !dead) {
      _seated(c, img);
      c.translate(0, seatDrop);
    } else if (img != null) {
      c.drawImage(img, const Offset(-7, -17), _sprite);
    }
    // Con una herramienta de vida en la mano no se ve el arma.
    if (showWeapon) {
      WeaponOverlay.draw(c, classId, weaponType, look: look, time: t / 1000);
    }
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

  /// [locked]: cofre custodiado con su guardián vivo (worldgen.md § 11.5).
  void item(Canvas c, MissionItem it, double t, {bool locked = false}) {
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
        // Calidad (loot.md § 23): madera, reforzado (plata) y dorado.
        final (body, lid, band, edge) = switch (it.tier) {
          ChestTier.madera => (
              const Color(0xFF8A5A2B),
              const Color(0xFFB3781F),
              const Color(0xFFFFD166),
              const Color(0xFF5A3A1A),
            ),
          ChestTier.plata => (
              const Color(0xFF4A5A78),
              const Color(0xFF7D8DAE),
              const Color(0xFFDFE6E9),
              const Color(0xFF2A3348),
            ),
          ChestTier.oro => (
              const Color(0xFFB8860B),
              const Color(0xFFFFC93C),
              const Color(0xFFFFF3B0),
              const Color(0xFF7A5200),
            ),
        };
        final bob = locked ? 0.0 : math.sin(t / 300 + it.id) * 1.5;
        _oval(c, _shadow, x, y + 4, 8, 2.5);
        if (it.tier == ChestTier.oro && !locked) {
          final g = (0.18 + 0.12 * math.sin(t / 220)).clamp(0.0, 1.0);
          _oval(c, Color.fromRGBO(255, 209, 102, g), x, y - 2 + bob, 13, 10);
        }
        _rect(c, body, x - 8, y - 6 + bob, 16, 10);
        _rect(c, lid, x - 8, y - 9 + bob, 16, 5);
        _rect(c, band, x - 1, y - 5 + bob, 2, 5);
        if (it.tier != ChestTier.madera) {
          _rect(c, band, x - 8, y - 4 + bob, 16, 1);
        }
        _stroke.color = edge;
        c.drawRect(Rect.fromLTWH(x - 7.5, y - 8.5 + bob, 15, 14), _stroke);
        if (locked) {
          // Candado: el guardián vive.
          _rect(c, const Color(0xFF2A2D38), x - 3, y - 4, 6, 5);
          _stroke.color = const Color(0xFF2A2D38);
          c.drawRect(Rect.fromLTWH(x - 2, y - 8, 4, 4), _stroke);
          _rect(c, const Color(0xFFFF4757), x - 0.5, y - 3, 1, 2);
          return;
        }
        // Destello `✦`: rombo de 3 px (la fuente no tiene el glifo).
        final a = (0.5 + 0.3 * math.sin(t / 180)).clamp(0.0, 1.0);
        final spark = band.withValues(alpha: a);
        final sy = (y - 16 + bob).roundToDouble();
        _rect(c, spark, x - 1, sy, 3, 1);
        _rect(c, spark, x, sy - 1, 1, 3);
    }
  }

  /// Reliquia perdida de una misión opcional (worldgen.md § 11.8): un
  /// fragmento ámbar que flota y brilla.
  void relic(Canvas c, double x, double y, double t) {
    final b = math.sin(t / 230) * 2;
    _oval(c, const Color(0x55000000), x, y + 3, 5, 1.5);
    final k = (0.35 + 0.25 * math.sin(t / 160)).clamp(0.0, 1.0);
    _oval(c, Color.fromRGBO(255, 179, 71, k), x, y - 6 + b, 9, 9);
    _fill.color = const Color(0xFFFFB347);
    c.drawPath(
        Path()
          ..moveTo(x, y - 13 + b)
          ..lineTo(x + 5, y - 6 + b)
          ..lineTo(x, y + 1 + b)
          ..lineTo(x - 5, y - 6 + b)
          ..close(),
        _fill);
    _rect(c, const Color(0xFFFFF3B0), x - 1, y - 9 + b, 2, 4);
  }
}
