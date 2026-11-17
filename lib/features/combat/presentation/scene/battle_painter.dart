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
import 'battle_labels.dart';
import 'battle_layout.dart';
import 'battle_scene.dart';
import 'fx_style.dart';
import 'ult_cinematic.dart';
import 'ult_fx.dart';

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

  /// Ancho de [s] en [size] px.
  double width(String s, double size) => _layout(s, Colors.white, size).width;

  /// Texto con la línea base en [y]; centrado en [x] o desde [x]. Con
  /// [outline], contorno negro de `size/8` px (números de ULT).
  void text(Canvas c, String s, double x, double y, Color color, double size,
      {bool center = true, bool shadow = true, bool outline = false}) {
    final fg = _layout(s, color, size);
    final left = center ? x - fg.width / 2 : x;
    final top = y - fg.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final l = left.roundToDouble(), tp = top.roundToDouble();
    if (outline) {
      final bk = _layout(s, Colors.black, size);
      final o = (size / 8).roundToDouble().clamp(1.0, 4.0);
      for (final d in [
        Offset(-o, 0), Offset(o, 0), Offset(0, -o), Offset(0, o), //
        Offset(o, o), Offset(-o, o), Offset(o, -o), Offset(-o, -o),
      ]) {
        bk.paint(c, Offset(l, tp) + d);
      }
      bk.paint(c, Offset(l + o, tp + o * 2));
    } else if (shadow) {
      final o = size >= 16 ? (size / 8).roundToDouble() : 1.0;
      _layout(s, Colors.black, size).paint(c, Offset(l + o, tp + o));
    }
    fg.paint(c, Offset(l, tp));
  }
}

/// Copia una imagen escalándola con vecino más cercano.
void _blit(Canvas canvas, ui.Image image, Rect dst) {
  canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      SpriteCatalog.pixelPaint());
}

/// La franja de turnos (lienzo virtual), el mundo (px del mundo × zoom
/// entero) y el HUD de la escena (px de pantalla). Ver
/// docs/specs/battle_presentation.md § "Geometría" y § "Cámara y
/// encuadre".
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

    // 1. Franja de turnos en el lienzo virtual.
    final vw = g.virtualWidth;
    const sh = SceneGeometry.stripHeight;
    final rs = ui.PictureRecorder();
    final cs = Canvas(rs, Rect.fromLTWH(0, 0, vw.toDouble(), sh.toDouble()));
    _timeline(cs, f);
    final ps = rs.endRecording();
    final strip = ps.toImageSync(vw, sh);
    ps.dispose();
    _blit(canvas, strip,
        Rect.fromLTWH(0, 0, (vw * g.scale).roundToDouble(), g.stripPx));
    strip.dispose();

    // 2. El mundo en px del mundo, escalado ×zoom.
    final vp = SceneViewport(g.worldRect, scene.viewFor(f));
    final area = vp.area;
    final z = vp.zoom;
    final iw = (area.width / z).ceil() + 1, ih = (area.height / z).ceil() + 1;
    final tl = vp.topLeft;
    final rw = ui.PictureRecorder();
    final cw = Canvas(rw, Rect.fromLTWH(0, 0, iw.toDouble(), ih.toDouble()));
    cw.translate(-tl.dx, -tl.dy);
    _world(cw, f, Rect.fromLTWH(tl.dx, tl.dy, iw.toDouble(), ih.toDouble()));
    final pw = rw.endRecording();
    final world = pw.toImageSync(iw, ih);
    pw.dispose();
    final shake = scene.particles.shakeOffset() * g.scale;
    final shk = Offset(shake.dx.roundToDouble(), shake.dy.roundToDouble());
    canvas.save();
    canvas.clipRect(area);
    canvas.drawRect(area, Paint()..color = const Color(0xFF05060C));
    _blit(canvas, world,
        Rect.fromLTWH(area.left + shk.dx, area.top + shk.dy, iw * z, ih * z));
    world.dispose();

    // 3. Destellos de pantalla.
    final hf = scene.particles.hurtFlash;
    if (hf > 0) {
      final center = area.center;
      final r = area.width * 0.65;
      final paint = Paint()
        ..shader = ui.Gradient.radial(center, r, [
          const Color(0x00FF0000),
          Color.fromRGBO(255, 40, 60, (hf * 1.6).clamp(0.0, 1.0)),
        ], [
          (area.height * 0.3 / r).clamp(0.0, 1.0),
          1,
        ]);
      canvas.drawRect(area, paint);
    }
    final t = scene.t;
    for (final live in scene.fx) {
      if (live.fx.kind != FxKind.flash) continue;
      final a = live.age(t);
      if (a < 0 || a >= BattleFx.flashMs) continue;
      canvas.drawRect(
          area,
          Paint()
            ..color = live.fx.color
                .withValues(alpha: 0.35 * (1 - a / BattleFx.flashMs)));
    }

    // 4. HUD de la escena.
    _hud(canvas, f, vp, shk);
    canvas.restore();
  }

  @override
  bool shouldRepaint(BattleScenePainter old) => old.scene != scene;

  // ------------------------------------------------------------------
  // Mundo
  // ------------------------------------------------------------------

  void _world(Canvas c, SceneFrame f, Rect visible) {
    final t = scene.t;
    _pen.rect(c, const Color(0xFF05060C), visible.left, visible.top,
        visible.width, visible.height);
    f.arena?.paintWorld?.call(c, visible, t);
    final dim = scene.ultDim;
    if (dim > 0) {
      _pen.rect(c, Color.fromRGBO(4, 4, 12, dim), visible.left, visible.top,
          visible.width, visible.height);
    }

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
    final u = scene.ult;
    final stage = scene.ultStage(f);
    if (u != null && stage != null) {
      UltDirector.paintWorld(c, u, t - u.t0, stage, visible);
    }
    scene.particles.paint(c);
  }

  // ---------------- héroes (`drawHero` en batalla) ----------------

  void _hero(Canvas c, SceneFrame f, Combatant p, Offset pos) {
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
    final pt = scene.poseT;
    final type = e.enemyType ?? '';
    final img = f.sprites?.enemy(type);
    final sc = (f.sprites?.enemyScale(type) ?? 1) * (e.elite ? 1.45 : 1);
    final iw = (img?.width ?? 16).toDouble(), ih = (img?.height ?? 14).toDouble();
    final w = iw * sc, h = ih * sc;
    final x = pos.dx, y = pos.dy;
    final dir = f.layout.side;
    final floats = f.sprites?.enemyFloats(type) ?? false;
    final fl = floats ? math.sin(pt / 200 + x) * 2 - 4 : 0.0;

    if (alpha < 1) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    _pen.oval(c, const Color(0x66000000), x, y + 1, w * 0.35, 2.5 * sc);
    if (e.elite) {
      final a = (0.35 + 0.2 * math.sin(pt / 180)).clamp(0.0, 1.0);
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
    if (f.battle.currentId == e.id) {
      _pen.rect(c, const Color(0xFFFF4757), x - 10, y + 3, 20, 2);
    }
  }

  // ---------------- HUD de la escena (px de pantalla) ----------------

  /// Estados activos de [a], en el orden de las insignias.
  static List<StatusKind> _statuses(Combatant a) => [
        for (final k in StatusKind.values)
          if (a.stacks(k) > 0) k
      ];

  /// Insignias compactas desde [x], con la caja en `[y, y + 10u)`.
  void _badges(Canvas c, Combatant a, double x, double y, double u) {
    for (final k in _statuses(a)) {
      final s = '${statusLetter(k)}${a.stacks(k)}';
      final tw = _pen.width(s, 8 * u);
      final col = statusColor(k);
      _pen.rect(c, const Color(0xCC000000), x, y, tw + 6 * u, 10 * u);
      _pen.rect(c, col, x, y, 2 * u, 10 * u);
      _pen.text(c, s, x + 4 * u, y + 9 * u, col, 8 * u,
          center: false, shadow: false);
      x += tw + 7 * u;
    }
  }

  /// Etiquetas de todos los actores, ya ubicadas sin superposición
  /// (px de pantalla, sin la sacudida). Las usa también el test.
  static Map<String, Rect> labelRects(SceneFrame f, SceneViewport vp,
      {double Function(String text, double size)? measure}) {
    final u = f.geometry.hudUnit.toDouble();
    final m = measure ?? _pen.width;
    final reqs = <LabelRequest>[];
    double badges(Combatant a) {
      var w = 0.0;
      for (final k in StatusKind.values) {
        if (a.stacks(k) <= 0) continue;
        w += m('${statusLetter(k)}${a.stacks(k)}', 8 * u) + 7 * u;
      }
      return w == 0 ? 0 : w + 2 * u;
    }

    for (final p in f.battle.party) {
      final box = f.layout.boxOf(p.id);
      final anchor = vp.toScreen(Offset(box.center.dx, box.top)) -
          Offset(0, 2 * u);
      reqs.add(LabelRequest(p.id, anchor,
          Size(m(p.name, 8 * u) + badges(p), 10 * u)));
    }
    for (final e in f.battle.enemies) {
      if (!e.alive) continue;
      final box = f.layout.boxOf(e.id);
      final anchor = vp.toScreen(Offset(box.center.dx, box.top)) -
          Offset(0, 2 * u);
      final line = m('${e.hp}/${e.maxHp}', 8 * u) + badges(e);
      final bar = (e.boss || e.elite ? 48 : 28) * u;
      reqs.add(LabelRequest(e.id, anchor, Size(math.max(line, bar), 15 * u)));
    }
    return placeLabels(reqs, vp.area.deflate(2));
  }

  void _hud(Canvas c, SceneFrame f, SceneViewport vp, Offset shake) {
    final u = f.geometry.hudUnit.toDouble();
    final pt = scene.poseT;
    final u0 = scene.ult;
    final labelAlpha =
        u0 == null ? 1.0 : 1 - u0.script.darkness(scene.t - u0.t0);
    c.save();
    c.translate(shake.dx, shake.dy);
    if (labelAlpha > 0.02) {
      final rects = labelRects(f, vp);
      if (labelAlpha < 1) {
        c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, labelAlpha));
      }
      final cur = f.battle.currentId;
      for (final p in f.battle.party) {
        final r = rects[p.id];
        if (r == null) continue;
        final x = r.left.roundToDouble(), y = r.top.roundToDouble();
        _pen.text(c, p.name, x, y + 8 * u,
            p.id == f.localId ? const Color(0xFFFFD166) : const Color(0xFFFFFFFF),
            8 * u,
            center: false);
        final nw = _pen.width(p.name, 8 * u);
        _badges(c, p, x + nw + 3 * u, y - u, u);
        if (cur == p.id) _marker(c, r, math.sin(pt / 130) * 2 * u, u);
      }
      for (final e in f.battle.enemies) {
        final r = rects[e.id];
        if (r == null) continue;
        final x = r.left.roundToDouble(), y = r.top.roundToDouble();
        final hp = '${e.hp}/${e.maxHp}';
        _pen.text(c, hp, x, y + 8 * u, const Color(0xFFFFD8A8), 8 * u,
            center: false);
        _badges(c, e, x + _pen.width(hp, 8 * u) + 3 * u, y - u, u);
        final bw = (e.boss || e.elite ? 48 : 28) * u;
        final bx = (r.center.dx - bw / 2).roundToDouble();
        final by = y + 11 * u;
        _pen.rect(c, const Color(0xAA000000), bx, by, bw, 3 * u);
        _pen.rect(
            c,
            e.boss
                ? const Color(0xFFFF4757)
                : e.elite
                    ? const Color(0xFFFFD166)
                    : const Color(0xFFFF9F43),
            bx,
            by,
            (bw * (e.hp / e.maxHp).clamp(0.0, 1.0)).roundToDouble(),
            3 * u);
        if (e.alive && f.targetId == e.id) {
          _marker(c, r, math.sin(pt / 120) * 2 * u, u);
        }
      }
      if (labelAlpha < 1) c.restore();
    }
    _floating(c, vp, u);
    c.restore();
  }

  /// Triángulo dorado arriba de la etiqueta [r].
  void _marker(Canvas c, Rect r, double b, double u) {
    final x = r.center.dx.roundToDouble(), y = r.top - 3 * u + b;
    _pen.tri(c, const Color(0xFFFFD166), Offset(x - 4 * u, y - 6 * u),
        Offset(x + 4 * u, y - 6 * u), Offset(x, y));
  }

  /// Números y textos flotantes (`num`, `txt`).
  void _floating(Canvas c, SceneViewport vp, double u) {
    final t = scene.t;
    for (final live in scene.fx) {
      final f = live.fx;
      final age = live.age(t);
      if (age < 0) continue;
      switch (f.kind) {
        case FxKind.num when age < f.durationMs:
          final p = vp.toScreen(Offset(f.x, f.y));
          final size = f.heavy
              ? (f.big ? 32 : 24) * u
              : (f.big ? 24 : 16) * u;
          var y = p.dy - age / 40 * 1.5 * u;
          var k = 1.0;
          if (f.heavy) {
            final q = math.min(1.0, age / 140);
            k = 1 + 0.6 * (1 - q);
            y -= (math.sin(age / 80)).abs() * 6 * u * math.exp(-age / 260);
          }
          final alpha = age > f.durationMs - 200
              ? (f.durationMs - age) / 200
              : 1.0;
          if (alpha < 1) {
            c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)));
          }
          if (k != 1) {
            c.save();
            c.translate(p.dx, y);
            c.scale(k);
            _pen.text(c, f.text ?? '', 0, 0, f.color, size, outline: f.heavy);
            c.restore();
          } else {
            _pen.text(c, f.text ?? '', p.dx, y, f.color, size, outline: f.heavy);
          }
          if (alpha < 1) c.restore();
        case FxKind.txt when age < BattleFx.txtMs:
          final p = vp.toScreen(Offset(f.x, f.y));
          _pen.text(c, f.text ?? '', p.dx, p.dy - age / 60 * 1.5 * u, f.color, 8 * u);
        default:
          break;
      }
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

/// La parte de pantalla de la ULT, encima de toda la batalla (también de
/// la barra): oscurecido de la franja y la barra, barras de cine,
/// tarjeta con el nombre y destello blanco del impacto. Ver
/// docs/specs/battle_presentation.md § "Ultimates".
class BattleOverlayPainter extends CustomPainter {
  BattleOverlayPainter(this.scene) : super(repaint: scene);

  final BattleSceneController scene;
  static final _pen = _Pen();

  @override
  void paint(Canvas canvas, Size size) {
    final f = scene.frame;
    final u = scene.ult;
    if (f == null || u == null) return;
    final s = u.script;
    final a = scene.t - u.t0;
    if (a < 0 || a > s.totalMs) return;
    final g = f.geometry;
    final area = g.worldRect;
    final d = s.darkness(a);
    final fill = Paint();

    // Oscurecido de todo lo que no es el mundo.
    if (d > 0) {
      fill.color = Color.fromRGBO(4, 4, 12, 0.75 * d);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, area.top), fill);
      canvas.drawRect(
          Rect.fromLTRB(0, area.bottom, size.width, size.height), fill);
      // Barras de cine.
      final bh = (area.height * 0.09 * d).roundToDouble();
      fill.color = const Color(0xFF000000);
      canvas.drawRect(Rect.fromLTWH(0, area.top, size.width, bh), fill);
      canvas.drawRect(
          Rect.fromLTWH(0, area.bottom - bh, size.width, bh), fill);
    }

    // Tarjeta del nombre (capa pixelada, unidad 2u).
    if (a < s.buildMs + 60) _card(canvas, f, u, a, size, area);

    // Destello blanco en el impacto principal.
    final n = math.max(1, u.fx.ult?.targets.length ?? 1);
    final imp = s.lastImpact(n);
    if (!u.skipped && a > imp - 20 && a < imp + 140) {
      final k = (1 - (a - imp + 20) / 160).clamp(0.0, 1.0);
      fill.color = s.style == UltStyle.bulwark
          ? Color.fromRGBO(255, 234, 167, 0.35 * k)
          : Color.fromRGBO(255, 255, 255, 0.7 * k);
      canvas.drawRect(Offset.zero & size, fill);
    }
  }

  void _card(Canvas canvas, SceneFrame f, UltCinematic u, double a, Size size,
      Rect area) {
    final s = u.script;
    final pu = 2.0 * f.geometry.hudUnit;
    final w = (size.width / pu).ceil(), h = (size.height / pu).ceil();
    final inP = Curves.easeOutCubic.transform(((a - 80) / 180).clamp(0.0, 1.0));
    if (inP <= 0) return;
    final outP = ((a - (s.buildMs - 140)) / 200).clamp(0.0, 1.0);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    final wd = w.toDouble();
    // Arriba del área del mundo, debajo de la barra de cine: la cámara
    // tiene al lanzador en el centro.
    final by = ((area.top + area.height * 0.09) / pu + 26).roundToDouble();
    c.translate((wd * outP * 1.2).roundToDouble(), 0);
    if (outP > 0) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - outP));
    }
    final right = wd * inP;
    final col = u.fx.color;
    final band = Path()
      ..moveTo(0, by - 19)
      ..lineTo(right + 12, by - 19)
      ..lineTo(right - 6, by + 17)
      ..lineTo(0, by + 17)
      ..close();
    _pen.fill.color = const Color(0xE6000000);
    c.drawPath(band.shift(const Offset(0, 3)), _pen.fill);
    _pen.fill.color = Color.lerp(col, const Color(0xFF000000), 0.35)!
        .withValues(alpha: 0.92);
    c.drawPath(band, _pen.fill);
    // Franja clara arriba y líneas de velocidad.
    c.save();
    c.clipPath(band);
    _pen.rect(c, col.withValues(alpha: 0.9), 0, by - 19, wd, 3);
    _pen.rect(c, const Color(0xFF000000), 0, by + 14, wd, 3);
    for (var i = 0; i < 12; i++) {
      final ly = by - 14 + ((i * 7) % 26);
      final lx = ((i * 97 + a * 0.9) % (wd + 80)) - 80;
      _pen.rect(c, const Color(0x55FFFFFF), lx, ly, 40 + (i % 3) * 14, 1);
    }
    c.restore();
    // Borde blanco del corte.
    _pen.stroke
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2;
    c.drawLine(Offset(right + 12, by - 19), Offset(right - 6, by + 17), _pen.stroke);

    // Sprite grande del lanzador y textos (entran con la banda).
    final img = f.sprites?.hero(u.fx.ult?.casterClass ?? '');
    final x0 = math.min(right - 40, 18.0);
    if (img != null) {
      const k = 3.0;
      final dst = Rect.fromLTWH(x0, by + 17 - img.height * k + 8,
          img.width * k, img.height * k);
      final shadow = SpriteCatalog.pixelPaint()
        ..colorFilter = const ColorFilter.mode(Color(0xFF000000), BlendMode.srcIn);
      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      c.drawImageRect(img, src, dst.shift(const Offset(2, 2)), shadow);
      c.drawImageRect(img, src, dst, SpriteCatalog.pixelPaint());
    }
    final tx = x0 + 52;
    final ult = u.fx.ult;
    _pen.text(c, '★ ULTIMATE · ${ult?.casterName ?? ''}', tx, by - 8,
        const Color(0xFFFFFFFF), 8,
        center: false);
    _pen.text(c, (ult?.name ?? '').toUpperCase(), tx, by + 12,
        const Color(0xFFFFFFFF), 16,
        center: false, outline: true);
    if (outP > 0) c.restore();
    final pic = rec.endRecording();
    final img2 = pic.toImageSync(w, h);
    pic.dispose();
    _blit(canvas, img2, Rect.fromLTWH(0, 0, w * pu, h * pu));
    img2.dispose();
  }

  @override
  bool shouldRepaint(BattleOverlayPainter old) => old.scene != scene;
}
