import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/battle_state.dart';
import '../../../../game_engine/models/status.dart';
import '../../domain/turn_order.dart';
import '../sprite_catalog.dart';
import 'battle_fx.dart';
import 'battle_layout.dart';
import 'battle_scene.dart';
import 'fx_style.dart';

/// Primitivas de dibujo en el lienzo virtual (sin antialias, texto con
/// sombra como `txt` del prototipo).
class _Pen {
  final fill = Paint()..isAntiAlias = false;
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;
  final _texts = <(String, int, double), TextPainter>{};

  void rect(Canvas c, Color color, double x, double y, double w, double h) {
    fill.color = color;
    c.drawRect(Rect.fromLTWH(x, y, w, h), fill);
  }

  void oval(Canvas c, Color color, double cx, double cy, double rx, double ry) {
    fill.color = color;
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
        fill);
  }

  void tri(Canvas c, Color color, Offset a, Offset b, Offset d) {
    fill.color = color;
    c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(d.dx, d.dy)
          ..close(),
        fill);
  }

  TextPainter _layout(String s, Color color, double size) {
    if (_texts.length > 300) _texts.clear();
    return _texts.putIfAbsent((s, color.toARGB32(), size), () {
      return TextPainter(
        text: TextSpan(
          text: retroText(s),
          style: TextStyle(
              fontFamily: RetroTheme.fontFamily,
              fontSize: size,
              color: color,
              height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Texto con la línea base en [y]; centrado en [x] o desde [x].
  void text(Canvas c, String s, double x, double y, Color color, double size,
      {bool center = true, bool shadow = true}) {
    final fg = _layout(s, color, size);
    final left = center ? x - fg.width / 2 : x;
    final top = y - fg.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    if (shadow) {
      _layout(s, Colors.black, size).paint(
          c, Offset((left + 1).roundToDouble(), (top + 1).roundToDouble()));
    }
    fg.paint(c, Offset(left.roundToDouble(), top.roundToDouble()));
  }
}

/// La franja de turnos + la escena de batalla, dibujadas en el lienzo
/// virtual y escaladas con vecino más cercano. Ver
/// docs/specs/battle_presentation.md.
class BattleScenePainter extends CustomPainter {
  BattleScenePainter(this.scene) : super(repaint: scene);

  final BattleSceneController scene;
  static final _pen = _Pen();
  static final _sprite = SpriteCatalog.pixelPaint();

  @override
  void paint(Canvas canvas, Size size) {
    final f = scene.frame;
    if (f == null) return;
    final g = f.geometry;
    final vw = g.virtualWidth, vh = g.virtualHeight;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder, Rect.fromLTWH(0, 0, vw.toDouble(), vh.toDouble()));
    _pen.rect(c, const Color(0xFF05060C), 0, 0, vw.toDouble(), vh.toDouble());

    _timeline(c, f);

    c.save();
    c.translate(0, SceneGeometry.stripHeight.toDouble());
    c.clipRect(Rect.fromLTWH(0, 0, vw.toDouble(), g.sceneHeight.toDouble()));
    _scene(c, f);
    c.restore();

    final picture = recorder.endRecording();
    final image = picture.toImageSync(vw, vh);
    picture.dispose();
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, vw.toDouble(), vh.toDouble()),
        Rect.fromLTWH(0, 0, (vw * g.scale).roundToDouble(),
            (vh * g.scale).roundToDouble()),
        _sprite);
    image.dispose();
  }

  @override
  bool shouldRepaint(BattleScenePainter old) => old.scene != scene;

  // ------------------------------------------------------------------
  // Escena
  // ------------------------------------------------------------------

  void _scene(Canvas c, SceneFrame f) {
    final g = f.geometry;
    final t = scene.t;
    final cam = scene.camera ?? f.layout.cameraTarget(g, f.arena);
    final sh = scene.particles.shakeOffset();
    final vw = g.virtualWidth.toDouble(), vh = g.sceneHeight.toDouble();

    c.save();
    c.translate(-cam.dx.roundToDouble() + sh.dx, -cam.dy.roundToDouble() + sh.dy);
    f.arena?.paintWorld?.call(c, Rect.fromLTWH(cam.dx, cam.dy, vw, vh), t);

    // Actores ordenados por y.
    final b = f.battle;
    final ents = <(double, int, void Function())>[];
    for (final p in b.party) {
      final pos = f.layout.of(p.id);
      ents.add((pos.dy, ents.length, () => _hero(c, f, p, pos)));
    }
    for (final e in b.enemies) {
      final alpha = e.alive ? 1.0 : scene.deathAlpha(e.id);
      if (alpha == null) continue;
      final pos = f.layout.of(e.id);
      ents.add((pos.dy, ents.length, () => _enemy(c, f, e, pos, alpha)));
    }
    ents.sort((a, b) {
      final r = a.$1.compareTo(b.$1);
      return r != 0 ? r : a.$2.compareTo(b.$2);
    });
    for (final e in ents) {
      e.$3();
    }

    _worldFx(c);
    _ultWorld(c, f);
    scene.particles.paint(c);
    c.restore();

    // Sin sacudida: destello rojo y `flash`.
    final hf = scene.particles.hurtFlash;
    final visibleH = math.max(1.0, vh - f.coverBottom);
    if (hf > 0) {
      final center = Offset(vw / 2, visibleH / 2);
      final r = vw * 0.65;
      final paint = Paint()
        ..shader = ui.Gradient.radial(center, r, [
          const Color(0x00FF0000),
          Color.fromRGBO(255, 40, 60, (hf * 1.6).clamp(0.0, 1.0)),
        ], [
          (visibleH * 0.3 / r).clamp(0.0, 1.0),
          1,
        ]);
      c.drawRect(Rect.fromLTWH(0, 0, vw, vh), paint);
    }
    for (final live in scene.fx) {
      if (live.fx.kind != FxKind.flash) continue;
      final a = live.age(t);
      if (a < 0 || a >= BattleFx.flashMs) continue;
      _pen.rect(c, live.fx.color.withValues(alpha: 0.35 * (1 - a / BattleFx.flashMs)),
          0, 0, vw, vh);
    }
  }

  // ---------------- héroes (`drawHero` en batalla) ----------------

  void _hero(Canvas c, SceneFrame f, Combatant p, Offset pos) {
    final t = scene.t;
    final x = pos.dx.roundToDouble(), y = pos.dy.roundToDouble();
    final dir = -f.layout.side;
    final dead = !p.alive;
    final img = f.sprites?.hero(p.classId ?? '');

    c.save();
    c.translate(x, y);
    if (dead) {
      c.saveLayer(null, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.55));
      c.rotate(math.pi / 2);
      c.translate(-6, -4);
    }
    if (dir < 0) c.scale(-1, 1);
    _pen.oval(c, const Color(0x66000000), 0, 1, 6, 2);
    c.translate(!dead && scene.lunging(p.id) ? 6 : 0, 0);
    if (img != null) {
      c.drawImage(img, const Offset(-7, -17), _sprite);
    } else {
      _pen.rect(c, const Color(0xFF8B93AF), -6, -16, 12, 16);
    }
    _weapon(c, p.classId ?? '', p.weaponType);
    if (p.defending && !dead) {
      _pen.stroke
        ..color = const Color(0xAA74B9FF)
        ..strokeWidth = 1;
      c.drawCircle(const Offset(0, -8), 11, _pen.stroke);
    }
    if (dead) c.restore();
    c.restore();

    _pen.text(c, p.name, x, y - 22,
        p.id == f.localId ? const Color(0xFFFFD166) : const Color(0xFFFFFFFF), 6);
    _badges(c, p, x, y - 50);
    if (f.battle.currentId == p.id) {
      final bb = math.sin(t / 130) * 2;
      _pen.tri(c, const Color(0xFFFFD166), Offset(x - 4, y - 36 + bb),
          Offset(x + 4, y - 36 + bb), Offset(x, y - 30 + bb));
    }
  }

  void _sword(Canvas c) {
    _pen.rect(c, const Color(0xFFDFE6E9), 5, -17, 2, 9);
    _pen.rect(c, const Color(0xFFFFD166), 3, -9, 6, 1);
  }

  /// Armas del héroe (docs/specs/sprites.md § "Héroe").
  void _weapon(Canvas c, String classId, String? weaponType) {
    switch (classId) {
      case 'guerrero':
        _sword(c);
      case 'maga':
        _pen.rect(c, const Color(0xFF8A5A2B), 6, -15, 1, 15);
        _pen.fill.color = const Color(0xFF74B9FF);
        c.drawCircle(const Offset(6.5, -16), 2.2, _pen.fill);
      case 'paladin':
        if (weaponType == 'martillo+escudo') {
          _pen.rect(c, const Color(0xFF8A5A2B), 6, -14, 1, 11);
          _pen.rect(c, const Color(0xFF95A5A6), 3, -18, 7, 5);
          _pen.rect(c, const Color(0xFF636E72), 3, -14, 7, 1);
        } else if (weaponType == 'maza+escudo') {
          _pen.rect(c, const Color(0xFF8A5A2B), 6, -13, 1, 9);
          _pen.fill.color = const Color(0xFFB2BEC3);
          c.drawCircle(const Offset(6.5, -15), 2.6, _pen.fill);
          for (final (px, py) in const [(4.0, -16.0), (8.0, -16.0), (6.0, -18.0)]) {
            _pen.rect(c, const Color(0xFFDFE6E9), px, py, 1, 1);
          }
        } else {
          _sword(c);
        }
        _pen.rect(c, const Color(0xFF2C3E50), -10, -13, 6, 9);
        _pen.rect(c, const Color(0xFFECF0F1), -9, -12, 4, 7);
        _pen.rect(c, const Color(0xFFD4AF37), -8, -11, 2, 5);
        _pen.rect(c, const Color(0xFFD4AF37), -9, -9, 4, 1);
      default:
        _pen.rect(c, const Color(0xFF636E72), 5, -8, 6, 2);
        _pen.rect(c, const Color(0xFF636E72), 5, -7, 2, 3);
    }
  }

  // ---------------- enemigos (`drawEnemy` en batalla) ----------------

  static const _brightness3 = ColorFilter.matrix([
    3, 0, 0, 0, 0, //
    0, 3, 0, 0, 0, //
    0, 0, 3, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  void _enemy(Canvas c, SceneFrame f, Combatant e, Offset pos, double alpha) {
    final t = scene.t;
    final type = e.enemyType ?? '';
    final img = f.sprites?.enemy(type);
    final sc = (f.sprites?.enemyScale(type) ?? 1) * (e.elite ? 1.45 : 1);
    final iw = (img?.width ?? 16).toDouble(), ih = (img?.height ?? 14).toDouble();
    final w = iw * sc, h = ih * sc;
    final x = pos.dx, y = pos.dy;
    final dir = f.layout.side;
    final floats = f.sprites?.enemyFloats(type) ?? false;
    final fl = floats ? math.sin(t / 200 + x) * 2 - 4 : 0.0;

    if (alpha < 1) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    _pen.oval(c, const Color(0x66000000), x, y + 1, w * 0.35, 2.5 * sc);
    if (e.elite) {
      final a = (0.35 + 0.2 * math.sin(t / 180)).clamp(0.0, 1.0);
      _pen.oval(c, const Color(0xFFFFD166).withValues(alpha: a), x,
          y - h / 2 + 2, w * 0.62, h * 0.6);
    }
    c.save();
    c.translate((x + (e.alive && scene.lunging(e.id) ? 6 * dir : 0)).roundToDouble(),
        (y + fl).roundToDouble());
    if (dir > 0) c.scale(-1, 1);
    final dst = Rect.fromLTWH(-w / 2, -h + 2, w, h);
    if (img != null) {
      final paint = SpriteCatalog.pixelPaint();
      if (scene.flashing(e.id)) paint.colorFilter = _brightness3;
      c.drawImageRect(img, Rect.fromLTWH(0, 0, iw, ih), dst, paint);
    } else {
      _pen.rect(c, const Color(0xFFE43B44), dst.left, dst.top, dst.width, dst.height);
    }
    c.restore();
    if (alpha < 1) c.restore();

    // Barra, vida, insignias, marcas (con alfa 1, como el prototipo).
    final bw = e.boss || e.elite ? 40.0 : 20.0;
    _pen.rect(c, const Color(0xAA000000), x - bw / 2, y - h - 3, bw, 3);
    _pen.rect(
        c,
        e.boss
            ? const Color(0xFFFF4757)
            : e.elite
                ? const Color(0xFFFFD166)
                : const Color(0xFFFF9F43),
        x - bw / 2,
        y - h - 3,
        bw * (e.hp / e.maxHp).clamp(0.0, 1.0),
        3);
    if (f.battle.currentId == e.id) {
      _pen.rect(c, const Color(0xFFFF4757), x - 10, y + 3, 20, 2);
    }
    _pen.text(c, '${e.hp}/${e.maxHp}', x, y - h - 6, const Color(0xFFFFD8A8), 6);
    _badges(c, e, x, y - h - 32);
    if (e.alive && f.targetId == e.id) {
      final b = math.sin(t / 120) * 2;
      _pen.tri(c, const Color(0xFFFFD166), Offset(x - 4, y - h - 19 + b),
          Offset(x + 4, y - h - 19 + b), Offset(x, y - h - 13 + b));
    }
  }

  /// `drawBadges` (tamaño normal).
  void _badges(Canvas c, Combatant a, double x, double y) {
    final ks = [
      for (final k in StatusKind.values)
        if (a.stacks(k) > 0) k
    ];
    if (ks.isEmpty) return;
    const w = 13.0;
    var bx = (x - ks.length * w / 2).roundToDouble();
    for (final k in ks) {
      final col = statusColor(k);
      _pen.rect(c, const Color(0xCC000000), bx, y, w - 1, 9);
      _pen.rect(c, col, bx, y, 2, 9);
      _pen.text(c, '${statusLetter(k)}${a.stacks(k)}', bx + 3, y + 8, col, 6,
          center: false, shadow: false);
      bx += w;
    }
  }

  // ---------------- efectos del mundo ----------------

  void _worldFx(Canvas c) {
    final t = scene.t;
    for (final live in scene.fx) {
      final f = live.fx;
      final age = live.age(t);
      if (age < 0) continue;
      switch (f.kind) {
        case FxKind.proj when age < BattleFx.projMs:
          final a = age / BattleFx.projMs;
          Offset at(double b) => Offset(f.x + (f.tx - f.x) * b,
              f.y + (f.ty - f.y) * b - math.sin(b * math.pi) * 10);
          final p = at(a);
          if (f.el == FxElement.phys) {
            final ang = math.atan2(f.ty - f.y, f.tx - f.x);
            _pen.stroke
              ..color = fxWhite
              ..strokeWidth = 1.5;
            c.drawLine(
                Offset(p.dx - math.cos(ang) * 7, p.dy - math.sin(ang) * 7),
                p,
                _pen.stroke);
          } else {
            for (var i = 4; i >= 0; i--) {
              final q = at(math.max(0, a - i * 0.05));
              _pen.fill.color = f.color.withValues(alpha: (1 - i / 5) * 0.8);
              c.drawCircle(q, 3.5 - i * 0.5, _pen.fill);
            }
            _pen.fill.color = fxWhite;
            c.drawCircle(p, 1.5, _pen.fill);
          }
        case FxKind.ring when age < BattleFx.ringMs:
          final a = age / BattleFx.ringMs;
          _pen.stroke
            ..color = f.color.withValues(alpha: 1 - a)
            ..strokeWidth = f.big ? 3 : 2;
          final rx = (f.big ? 60 : 34) * a, ry = (f.big ? 30 : 17) * a;
          c.drawOval(
              Rect.fromCenter(
                  center: Offset(f.x, f.y), width: rx * 2, height: ry * 2),
              _pen.stroke);
        case FxKind.num when age < BattleFx.numMs:
          _pen.text(c, f.text ?? '', f.x, f.y - age / 40, f.color, f.big ? 12 : 8);
        case FxKind.txt when age < BattleFx.txtMs:
          _pen.text(c, f.text ?? '', f.x, f.y - age / 60, f.color, 7);
        case FxKind.slash when age < BattleFx.slashMs:
          final a = age / BattleFx.slashMs;
          _pen.stroke
            ..color = f.color
            ..strokeWidth = 2;
          c.drawLine(Offset(f.x - 10 + a * 4, f.y - 10),
              Offset(f.x + 10 - a * 4, f.y + 10), _pen.stroke);
          c.drawLine(Offset(f.x + 10, f.y - 10 + a * 4),
              Offset(f.x - 10, f.y + 10 - a * 4), _pen.stroke);
        case FxKind.poof when age < BattleFx.poofMs:
          final col = Color.fromRGBO(255, 255, 255, 1 - age / BattleFx.poofMs);
          for (var i = 0; i < 8; i++) {
            final a = i / 8 * 6.28, r = age / 25;
            _pen.rect(c, col, f.x + math.cos(a) * r - 1, f.y + math.sin(a) * r - 1, 3, 3);
          }
        default:
          break;
      }
    }
  }

  /// La parte dibujada de `ultWorld`.
  void _ultWorld(Canvas c, SceneFrame f) {
    final u = scene.ult;
    if (u == null) return;
    final a = scene.t - u.t0;
    final col = u.fx.color;
    if (a < 1100) {
      final r = 14 + math.sin(a / 60) * 3;
      _pen.stroke
        ..color = col.withValues(alpha: 0.5)
        ..strokeWidth = 2;
      c.drawOval(
          Rect.fromCenter(
              center: Offset(u.fx.x, u.fx.y - 8),
              width: r * 2,
              height: (r * 0.5 + 6) * 2),
          _pen.stroke);
    }
    final ph = (a - 300) / 800;
    if (ph <= 0 || ph >= 1.15) return;
    final tg = scene.ultTargets(f);
    for (var i = 0; i < tg.length; i++) {
      final g = tg[i];
      final lp = (ph * 1.25 - i * 0.1).clamp(0.0, 1.0);
      switch (u.fx.el) {
        case FxElement.burn:
          if (lp < 1) {
            final sx = g.dx + 70, sy = g.dy - 160;
            final mx = sx + (g.dx - sx) * lp, my = sy + (g.dy - 10 - sy) * lp;
            for (var k = 0; k < 6; k++) {
              _pen.fill.color = (k < 2 ? const Color(0xFFFFF3B0) : const Color(0xFFFF7B29))
                  .withValues(alpha: 1 - k / 6);
              c.drawCircle(Offset(mx + k * 5, my - k * 11), 6 - k * 0.7, _pen.fill);
            }
          }
        case FxElement.freeze:
          final h = math.min(1.0, lp * 1.6) * 34;
          for (var k = -2; k <= 2; k++) {
            _pen.tri(
                c,
                k.isOdd ? const Color(0xFF81ECEC) : const Color(0xFFDFF9FB),
                Offset(g.dx + k * 7 - 4, g.dy + 2),
                Offset(g.dx + k * 7, g.dy + 2 - h * (1 - k.abs() * 0.22)),
                Offset(g.dx + k * 7 + 4, g.dy + 2));
          }
        case FxElement.poison:
          _pen.stroke
            ..color = const Color(0xFFBADC58).withValues(alpha: 0.9)
            ..strokeWidth = 1.5;
          for (var k = 0; k < 7; k++) {
            final ox = ((k * 37 + i * 13) % 40) - 20.0;
            final fy = (a * 0.45 + k * 31) % 90;
            c.drawLine(Offset(g.dx + ox + 6, g.dy - 90 + fy),
                Offset(g.dx + ox, g.dy - 78 + fy), _pen.stroke);
          }
        case FxElement.holy:
          final w = 10 + lp * 8;
          final al = 0.85 * math.min(1.0, lp * 2);
          final paint = Paint()
            ..shader = ui.Gradient.linear(Offset(0, g.dy - 200), Offset(0, g.dy), [
              const Color(0x00FFF3B0),
              Color.fromRGBO(255, 243, 176, al),
            ]);
          c.drawRect(Rect.fromLTWH(g.dx - w / 2, g.dy - 200, w, 200), paint);
          _pen.rect(c, Color.fromRGBO(255, 255, 255, math.min(1.0, lp * 2) * 0.9),
              g.dx - w / 6, g.dy - 200, w / 3, 200);
        case FxElement.arcane:
          final rr = 40 * (1 - lp) + 4;
          for (var k = 0; k < 10; k++) {
            final an = a / 90 + k * 0.63;
            _pen.rect(c, k.isOdd ? const Color(0xFFA29BFE) : const Color(0xFFE84393),
                g.dx + math.cos(an) * rr - 2, g.dy - 10 + math.sin(an) * rr * 0.6 - 2, 4, 4);
          }
        default:
          if (lp > 0 && lp < 1) {
            _pen.stroke
              ..color = Color.fromRGBO(255, 255, 255, 1 - lp * 0.5)
              ..strokeWidth = 3;
            c.drawLine(Offset(g.dx - 40 + lp * 10, g.dy - 50),
                Offset(g.dx - 40 + lp * 80, g.dy - 50 + lp * 60), _pen.stroke);
            c.drawLine(Offset(g.dx + 40 - lp * 10, g.dy - 50),
                Offset(g.dx + 40 - lp * 80, g.dy - 50 + lp * 60), _pen.stroke);
          }
      }
    }
  }

  // ---------------- franja de turnos (`drawTimeline`) ----------------

  void _timeline(Canvas c, SceneFrame f) {
    final t = scene.t;
    final b = f.battle;
    final vw = f.geometry.virtualWidth.toDouble();
    _pen.rect(c, const Color(0xFF0B0E1A), 0, 0, vw, 54);
    _pen.rect(c, const Color(0xCC0B0E1A), 0, 0, vw, 32);
    _pen.rect(c, const Color(0xFF5B74C9), 0, 32, vw, 1);
    final cur = b.current;
    final left = f.turnTimeLeft;
    if (cur != null && cur.isPlayer && left != null) {
      final l = left.clamp(0.0, 30.0);
      _pen.rect(c, const Color(0xAA000000), 0, 33, vw, 4);
      _pen.rect(
          c,
          l <= 10
              ? ((t / 250).floor().isOdd
                  ? const Color(0xFFFF4757)
                  : const Color(0xFFFF6B81))
              : const Color(0xFFFFD166),
          0,
          33,
          vw * l / 30,
          4);
    }
    _pen.text(c, 'TURNOS', 26, 19, const Color(0xFF9FB4FF), 6);

    final order = predictTurns(b, 10);
    var x = 52.0;
    for (var i = 0; i < order.length; i++) {
      final a = b.byId(order[i]);
      if (a == null) continue;
      final big = i == 0;
      final sz = big ? 28.0 : 22.0;
      final y = big ? 2.0 : 6.0;
      _pen.rect(c, a.isPlayer ? const Color(0xFF1D2A5A) : const Color(0xFF4A1820),
          x, y, sz, sz);
      _pen.stroke
        ..strokeWidth = big ? 2 : 1
        ..color = big
            ? const Color(0xFFFFD166)
            : a.isPlayer
                ? (a.id == f.localId
                    ? const Color(0xAAFFD166)
                    : const Color(0xFF5B74C9))
                : const Color(0xFFFF4757);
      final inset = big ? 1.0 : 0.5;
      c.drawRect(Rect.fromLTWH(x + inset, y + inset, sz - inset * 2, sz - inset * 2),
          _pen.stroke);
      final img = a.isPlayer
          ? f.sprites?.hero(a.classId ?? '')
          : f.sprites?.enemy(a.enemyType ?? '');
      if (img != null) {
        final k = math.min((sz - 4) / img.width, (sz - 4) / img.height);
        final w = img.width * k, h = img.height * k;
        c.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromLTWH((x + sz / 2 - w / 2).roundToDouble(),
                (y + sz / 2 - h / 2).roundToDouble(), w, h),
            _sprite);
      }
      var dx = 0.0;
      for (final k in StatusKind.values) {
        if (a.stacks(k) <= 0) continue;
        _pen.rect(c, statusColor(k), x + 2 + dx, y + sz - 4, 3, 3);
        dx += 4;
      }
      if (big) {
        final bb = math.sin(t / 150) * 1.5;
        _pen.tri(c, const Color(0xFFFFD166), Offset(x + sz / 2 - 4, y + sz + 3 + bb),
            Offset(x + sz / 2 + 4, y + sz + 3 + bb), Offset(x + sz / 2, y + sz - 1 + bb));
      }
      x += sz + (big ? 8 : 4);
      if (big && i < order.length - 1) {
        _pen.rect(c, const Color(0xFF5B74C9), x - 6, y + sz / 2 - 1, 3, 2);
      }
    }
    // Banda del log (el texto es un widget encima).
    _pen.rect(c, const Color(0xFF000000), 0, 38, vw, 16);
  }
}

/// `ultScreen`: oscurecido, banda con el nombre y destello blanco de la
/// ultimate, encima de TODO (también de los paneles Flutter).
class BattleOverlayPainter extends CustomPainter {
  BattleOverlayPainter(this.scene) : super(repaint: scene);

  final BattleSceneController scene;
  static final _pen = _Pen();

  @override
  void paint(Canvas canvas, Size size) {
    final f = scene.frame;
    final u = scene.ult;
    if (f == null || u == null) return;
    final g = f.geometry;
    final vw = g.virtualWidth, vh = g.virtualHeight;
    final a = scene.t - u.t0;
    if (a < 0) return;

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder, Rect.fromLTWH(0, 0, vw.toDouble(), vh.toDouble()));
    final w = vw.toDouble(), h = vh.toDouble();
    final dark = a < 250
        ? a / 250
        : a < 1050
            ? 1.0
            : a < 1500
                ? 1 - (a - 1050) / 450
                : 0.0;
    if (dark > 0) _pen.rect(c, Color.fromRGBO(5, 5, 15, 0.55 * dark), 0, 0, w, h);
    if (a < 1300) {
      final inP = math.min(1.0, a / 220);
      final outP = a > 1000 ? (a - 1000) / 300 : 0.0;
      final bx = -w * (1 - inP) + w * outP * 1.2;
      final alpha = (1 - outP).clamp(0.0, 1.0);
      c.save();
      c.translate(bx.roundToDouble(), 0);
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      final by = h - 58;
      _pen.fill.color = u.fx.color.withValues(alpha: 0.85);
      c.drawPath(
          Path()
            ..moveTo(0, by - 18)
            ..lineTo(w, by - 28)
            ..lineTo(w, by + 12)
            ..lineTo(0, by + 22)
            ..close(),
          _pen.fill);
      _pen.rect(c, const Color(0xFF000000), 0, by + 20, w, 2);
      for (var i = 0; i < 14; i++) {
        final ly = by - 22 + ((i * 17 + a * 0.6) % 44);
        _pen.rect(c, const Color(0x59FFFFFF), ((i * 53 + a * 1.5) % (w + 80)) - 80,
            ly, 60, 1);
      }
      final ult = u.fx.ult;
      _pen.text(c, '★ ULTIMATE · ${ult?.casterName ?? ''} ★', w / 2, by - 10,
          const Color(0xFFFFFFFF), 7);
      _pen.text(c, (ult?.name ?? '').toUpperCase(), w / 2, by + 10,
          const Color(0xFFFFFFFF), 15);
      c.restore();
      c.restore();
    }
    const dl = BattleFx.ultDelayMs;
    if (a > dl - 40 && a < dl + 160) {
      _pen.rect(c, Color.fromRGBO(255, 255, 255, ((1 - (a - dl + 40) / 200) * 0.7).clamp(0.0, 1.0)),
          0, 0, w, h);
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(vw, vh);
    picture.dispose();
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, w, h),
        Rect.fromLTWH(0, 0, (w * g.scale).roundToDouble(), (h * g.scale).roundToDouble()),
        SpriteCatalog.pixelPaint());
    image.dispose();
  }

  @override
  bool shouldRepaint(BattleOverlayPainter old) => old.scene != scene;
}
