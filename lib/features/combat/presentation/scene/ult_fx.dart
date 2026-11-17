import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'battle_fx.dart';
import 'fx_style.dart';
import 'particles.dart';
import 'ult_cinematic.dart';

/// Cinemática de ULT en curso (`ultCine`).
class UltCinematic {
  UltCinematic(this.fx, this.t0, [this.batch = 0]);

  final BattleFx fx;

  /// Hora de inicio en el reloj de la escena (se corre al adelantarla).
  double t0;

  /// Paso del que viene (sus números se adelantan con ella).
  final int batch;

  /// Disparos "una vez" ya hechos.
  final done = <String>{};

  /// Se adelantó (sin hit-stop ni sacudidas pendientes).
  bool skipped = false;

  UltScript get script => fx.ult?.script ?? kDefaultUltScript;
  UltStyle get style => script.style;
}

/// Dónde ocurre la cinemática (px del mundo, pies).
class UltStage {
  const UltStage({
    required this.caster,
    required this.targets,
    this.targetBoxes = const [],
    this.party = const [],
  });

  final Offset caster;
  final List<Offset> targets;
  final List<Rect> targetBoxes;
  final List<Offset> party;

  /// Hacia dónde están los objetivos desde el lanzador (1 o −1).
  double get dir {
    if (targets.isEmpty) return -1;
    final dx = centroid.dx - caster.dx;
    return dx >= 0 ? 1 : -1;
  }

  Offset get centroid {
    if (targets.isEmpty) return caster;
    var x = 0.0, y = 0.0;
    for (final t in targets) {
      x += t.dx;
      y += t.dy;
    }
    return Offset(x / targets.length, y / targets.length);
  }
}

// Recetas de partículas propias de las ULT.
const _debris = ElementFx([
  Color(0xFF6D4C2F),
  Color(0xFF8D6E4F),
  Color(0xFF636E72),
  Color(0xFFB2BEC3),
], 14, 120, 260, 0.8, ParticleShape.square);
const _sparks = ElementFx([
  Color(0xFFFFFFFF),
  Color(0xFFFFE066),
  Color(0xFF74B9FF),
], 6, 60, 0, 0.25, ParticleShape.ray);
const _dust = ElementFx([
  Color(0xFFB2A58F),
  Color(0xFF8D8270),
  Color(0xFFDFE6E9),
], 16, 90, -10, 0.7, ParticleShape.square);

/// Disparos (partículas, sacudidas, hit-stop) y dibujo en el mundo de
/// cada ULT. Diseño en docs/specs/battle_presentation.md § "Ultimates".
abstract final class UltDirector {
  /// Elemento de las partículas de cada estilo.
  static FxElement element(UltStyle s) => switch (s) {
        UltStyle.finalSlash => FxElement.phys,
        UltStyle.cataclysm => FxElement.phys,
        UltStyle.meteor => FxElement.burn,
        UltStyle.paradox => FxElement.freeze,
        UltStyle.arrowStorm => FxElement.poison,
        UltStyle.deadShot => FxElement.phys,
        UltStyle.bulwark => FxElement.holy,
        UltStyle.judgment => FxElement.holy,
        UltStyle.skyHammer => FxElement.holy,
      };

  /// Oscurecido del fondo del mundo (0.85 en la preparación, 0.62 en la
  /// descarga, baja en el regreso).
  static double worldDim(UltCinematic u, double a) {
    final s = u.script;
    final d = s.darkness(a);
    final k = a < s.buildMs
        ? 0.85
        : 0.85 - 0.23 * ((a - s.buildMs) / 200).clamp(0.0, 1.0);
    return d * k;
  }

  /// La parte "una vez" de la cinemática a la edad [a].
  static void tick(UltCinematic u, double a, UltStage st, ParticleSystem p,
      void Function(int ms) hitStop) {
    final s = u.script;
    final el = element(s.style);
    bool once(String k) => u.done.add(k);
    final c = st.caster;

    // Carga en el lanzador (cada 120 ms de la preparación).
    if (a < s.buildMs) {
      final slot = (a / 120).floor();
      if (once('aura$slot')) {
        // A los costados del lanzador (que se siga viendo con el zoom).
        final side = slot.isEven ? -13.0 : 13.0;
        if (el == FxElement.phys) {
          p.burstWith(_sparks, c.dx + side, c.dy - 10, 0.6);
        } else {
          p.burst(c.dx + side, c.dy - 4, el, 0.15);
        }
        if (s.style == UltStyle.skyHammer) {
          p.burstWith(_sparks, c.dx - side, c.dy - 18, 0.8);
        }
        if (s.style == UltStyle.cataclysm) {
          p.burstWith(_dust, c.dx, c.dy, 0.3);
          if (!u.skipped) p.addShake(1.5);
        }
      }
    }

    final n = st.targets.length;
    // Golpes previos (Tajo Final).
    for (var k = 0; k < s.preHitsMs.length; k++) {
      if (a >= s.preHitsMs[k] && n > 0 && once('pre$k')) {
        final g = st.targets.first;
        p.burst(g.dx, g.dy - 10, FxElement.phys, 2);
        if (!u.skipped) p.addShake(5);
      }
    }
    // Momentos propios de cada estilo.
    switch (s.style) {
      case UltStyle.cataclysm:
        if (a >= 950 && once('slam')) {
          p.burstWith(_dust, c.dx, c.dy, 1.2);
          if (!u.skipped) p.addShake(6);
        }
      case UltStyle.deadShot:
        if (a >= s.buildMs + 50 && once('muzzle')) {
          p.burst(c.dx + st.dir * 8, c.dy - 9, FxElement.phys, 2);
          p.burstWith(_sparks, c.dx + st.dir * 8, c.dy - 9, 1.5);
          if (!u.skipped) p.addShake(6);
        }
      case UltStyle.arrowStorm:
        if (a >= s.buildMs + 100 && a < s.returnAt - 150 && n > 0) {
          final slot = (a / 80).floor();
          if (once('rain$slot')) {
            final g = st.targets[slot % n];
            p.burst(g.dx + (slot * 7 % 20) - 10, g.dy - 4, FxElement.phys, 0.4);
            if (!u.skipped) p.addShake(2);
          }
        }
      case UltStyle.bulwark:
        if (a >= s.buildMs + 300 && once('dome')) {
          for (final q in st.party) {
            p.burst(q.dx, q.dy - 10, FxElement.holy, 1.2);
          }
          if (!u.skipped) p.addShake(3);
        }
      default:
        break;
    }

    // Impactos.
    for (var i = 0; i < n; i++) {
      if (a < s.impactFor(i) || !once('imp$i')) continue;
      final g = st.targets[i];
      switch (s.style) {
        case UltStyle.finalSlash:
          p.burst(g.dx, g.dy - 10, FxElement.phys, 4);
          p.burst(g.dx, g.dy - 10, FxElement.level, 1);
        case UltStyle.cataclysm:
          p.burstWith(_debris, g.dx, g.dy - 2, 1.6);
          p.burst(g.dx, g.dy - 6, FxElement.burn, 1.5);
        case UltStyle.meteor:
          p.burst(g.dx, g.dy - 8, FxElement.burn, 4);
          p.burst(g.dx, g.dy - 8, FxElement.phys, 2);
          p.burstWith(_debris, g.dx, g.dy - 2, 0.6);
        case UltStyle.paradox:
          p.burst(g.dx, g.dy - 10, FxElement.freeze, 4);
          p.burst(g.dx, g.dy - 10, FxElement.arcane, 2);
        case UltStyle.arrowStorm:
          p.burst(g.dx, g.dy - 8, FxElement.poison, 2.5);
          p.burst(g.dx, g.dy - 8, FxElement.phys, 1.5);
        case UltStyle.deadShot:
          p.burst(g.dx, g.dy - 10, FxElement.phys, 4);
          p.burstWith(_sparks, g.dx, g.dy - 10, 2);
          p.burst(g.dx, g.dy - 10, FxElement.level, 0.6);
        case UltStyle.bulwark:
          p.burst(g.dx, g.dy - 8, FxElement.heal, 1.5);
        case UltStyle.judgment:
          p.burst(g.dx, g.dy - 8, FxElement.holy, 4);
          p.burst(g.dx, g.dy - 8, FxElement.level, 1);
        case UltStyle.skyHammer:
          p.burst(g.dx, g.dy - 6, FxElement.phys, 5);
          p.burstWith(_dust, g.dx, g.dy, 2);
          p.burst(g.dx, g.dy - 10, FxElement.holy, 2);
      }
      if (!u.skipped) {
        p.addShake(i == n - 1 ? s.shake : s.shake * 0.6);
        if (i == n - 1 && s.hitStopMs > 0) hitStop(s.hitStopMs);
      }
    }
  }

  // ------------------------------------------------------------ dibujo

  static final _fill = Paint()..isAntiAlias = false;
  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

  static double _ease(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static double _q(double a, num from, num len) =>
      ((a - from) / len).clamp(0.0, 1.0);

  /// Azar determinista en [0, 1).
  static double _h(int a, int b) {
    var x = (a * 73856093) ^ (b * 19349663);
    x = (x ^ (x >> 13)) * 1274126177;
    return ((x ^ (x >> 16)) & 0xffff) / 65536;
  }

  static void _line(Canvas c, Offset a, Offset b, Color col, double w) {
    _stroke
      ..color = col
      ..strokeWidth = w;
    c.drawLine(a, b, _stroke);
  }

  static void _disc(Canvas c, Offset o, double r, Color col) {
    _fill.color = col;
    c.drawCircle(o, r, _fill);
  }

  static void _ring(Canvas c, Offset o, double rx, double ry, Color col, double w) {
    _stroke
      ..color = col
      ..strokeWidth = w;
    c.drawOval(Rect.fromCenter(center: o, width: rx * 2, height: ry * 2), _stroke);
  }

  static void _oval(Canvas c, Offset o, double rx, double ry, Color col) {
    _fill.color = col;
    c.drawOval(Rect.fromCenter(center: o, width: rx * 2, height: ry * 2), _fill);
  }

  static Color _a(Color c, double alpha) =>
      c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

  /// Estrella de 4 puntas.
  static void _star(Canvas c, Offset o, double r, Color col) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..lineTo(o.dx + r * 0.18, o.dy - r * 0.18)
      ..lineTo(o.dx + r, o.dy)
      ..lineTo(o.dx + r * 0.18, o.dy + r * 0.18)
      ..lineTo(o.dx, o.dy + r)
      ..lineTo(o.dx - r * 0.18, o.dy + r * 0.18)
      ..lineTo(o.dx - r, o.dy)
      ..lineTo(o.dx - r * 0.18, o.dy - r * 0.18)
      ..close();
    _fill.color = col;
    c.drawPath(path, _fill);
  }

  /// Líneas que convergen hacia el lanzador y un anillo de carga.
  static void _gather(Canvas c, Offset o, double a, int build, Color col) {
    if (a >= build) return;
    final grow = _q(a, 0, build);
    for (var k = 0; k < 14; k++) {
      final f = (a / 420 + _h(k, 3)) % 1.0;
      final ang = k * math.pi * 2 / 14 + _h(k, 9) * 0.4;
      final r1 = 90 * (1 - f) + 8, r2 = r1 + 8 + 10 * (1 - f);
      final dir = Offset(math.cos(ang), math.sin(ang) * 0.6);
      _line(c, o.translate(0, -10) + dir * r1, o.translate(0, -10) + dir * r2,
          _a(col, 0.25 + 0.6 * f), 1);
    }
    final r = 12 + grow * 6 + math.sin(a / 55) * 2;
    _ring(c, o.translate(0, -8), r, r * 0.5 + 5, _a(col, 0.6), 2);
    _ring(c, o.translate(0, -8), r * 0.6, r * 0.3 + 3, _a(const Color(0xFFFFFFFF), 0.4), 1);
  }

  /// Dibuja la parte del mundo de la cinemática. [visible] = rectángulo
  /// del mundo a la vista.
  static void paintWorld(
      Canvas c, UltCinematic u, double a, UltStage st, Rect visible) {
    final s = u.script;
    final col = u.fx.color;
    final out = s.phaseAt(a) == UltPhase.recover
        ? 1 - _q(a, s.returnAt, s.returnMs)
        : 1.0;
    switch (s.style) {
      case UltStyle.finalSlash:
        _finalSlash(c, u, a, st, visible, col);
      case UltStyle.cataclysm:
        _cataclysm(c, u, a, st, out);
      case UltStyle.meteor:
        _meteor(c, u, a, st, visible, out);
      case UltStyle.paradox:
        _paradox(c, u, a, st, visible, out);
      case UltStyle.arrowStorm:
        _arrows(c, u, a, st, visible, out);
      case UltStyle.deadShot:
        _deadShot(c, u, a, st);
      case UltStyle.bulwark:
        _bulwark(c, u, a, st, out);
      case UltStyle.judgment:
        _judgment(c, u, a, st, visible, out);
      case UltStyle.skyHammer:
        _hammer(c, u, a, st, visible, out);
    }
  }

  // ---------------- Tajo Final ----------------

  static void _finalSlash(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, Color col) {
    final s = u.script;
    final o = st.caster;
    const edge = Color(0xFF9FD8FF);
    _gather(c, o, a, s.buildMs, col);
    if (a > 560 && a < s.buildMs + 40) {
      final q = _q(a, 560, 280);
      final tip = o.translate(st.dir * 6, -18);
      _star(c, tip, 3 + 9 * math.sin(q * math.pi), const Color(0xFFFFFFFF));
      _star(c, tip, 2 + 4 * math.sin(q * math.pi), edge);
    }
    if (st.targets.isEmpty) return;
    final g = st.targets.first.translate(0, -10);
    // Estela de imágenes fantasma del lanzador al objetivo.
    if (a >= s.buildMs && a < s.buildMs + 260) {
      final q = _q(a, s.buildMs, 150);
      for (var k = 0; k < 5; k++) {
        final p = Offset.lerp(o.translate(0, -8), g, (q - k * 0.12).clamp(0.0, 1.0))!;
        _oval(c, p, 6, 9, _a(edge, 0.5 * (1 - k / 5) * (1 - _q(a, s.buildMs + 150, 110))));
      }
      _line(c, o.translate(0, -8), Offset.lerp(o.translate(0, -8), g, q)!,
          _a(const Color(0xFFFFFFFF), 0.7), 2);
    }
    // Tajos que cruzan la vista.
    const angles = [-0.45, 0.35, -1.05];
    final span = vis.width;
    for (var k = 0; k < s.preHitsMs.length; k++) {
      final h = s.preHitsMs[k];
      if (a < h || a > h + 200) continue;
      final q = _q(a, h, 200);
      final ang = angles[k % angles.length];
      final d = Offset(math.cos(ang), math.sin(ang));
      final len = span * math.min(1.0, q * 4);
      final w = 5 * (1 - q) + 1;
      _line(c, g - d * len / 2, g + d * len / 2, _a(edge, 0.8 * (1 - q)), w + 3);
      _line(c, g - d * len / 2, g + d * len / 2, _a(const Color(0xFFFFFFFF), 1 - q * 0.7), w);
    }
    // La X final.
    final imp = s.impactMs;
    if (a >= imp - 60 && a < imp + 300) {
      final q = _q(a, imp - 60, 360);
      final r = 18 + 50 * _ease(q * 2);
      final w = 8 * (1 - q) + 1;
      for (final sgn in [1.0, -1.0]) {
        final d = Offset(1, sgn);
        _line(c, g - d * r, g + d * r, _a(edge, 0.9 * (1 - q)), w + 4);
        _line(c, g - d * r, g + d * r, _a(const Color(0xFFFFFFFF), 1 - q * 0.6), w);
      }
      _ring(c, g, 70 * q, 30 * q, _a(const Color(0xFFFFFFFF), 1 - q), 3);
    }
  }

  // ---------------- Cataclismo ----------------

  static List<Offset> _fissure(Offset from, Offset to, int seed) {
    final pts = <Offset>[];
    const k = 9;
    for (var i = 0; i <= k; i++) {
      final f = i / k;
      final p = Offset.lerp(from, to, f)!;
      final off = (i == 0 || i == k) ? 0.0 : (_h(seed, i) - 0.5) * 9;
      pts.add(p.translate(0, off));
    }
    return pts;
  }

  static void _cataclysm(
      Canvas c, UltCinematic u, double a, UltStage st, double out) {
    final s = u.script;
    final o = st.caster;
    const glow = Color(0xFFFF9F43);
    const dark = Color(0xFF2D1B0E);
    _gather(c, o, a, s.buildMs, u.fx.color);
    // Grietas que brillan bajo el lanzador.
    if (a < s.returnAt) {
      final g = 0.5 + 0.5 * math.sin(a / 70);
      final grow = _q(a, 100, s.buildMs - 100);
      for (var k = 0; k < 6; k++) {
        final ang = k * math.pi / 3 + 0.3;
        final pts = _fissure(o, o + Offset(math.cos(ang) * 18, math.sin(ang) * 6) * grow, k + 50);
        for (var i = 1; i < pts.length; i++) {
          _line(c, pts[i - 1], pts[i], _a(dark, out), 2);
          _line(c, pts[i - 1], pts[i], _a(glow, g * out), 1);
        }
      }
    }
    if (a < 950) return;
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      final reveal = _q(a, 950, imp - 950);
      final pts = _fissure(o, g, i + 7);
      final upto = (reveal * (pts.length - 1));
      for (var k = 1; k < pts.length; k++) {
        if (k - 1 > upto) break;
        final b = k <= upto ? pts[k] : Offset.lerp(pts[k - 1], pts[k], upto - (k - 1))!;
        _line(c, pts[k - 1], b, _a(dark, out), 4);
        _line(c, pts[k - 1], b, _a(glow, out * (0.6 + 0.4 * math.sin(a / 50 + k))), 1.5);
      }
      if (a >= imp) {
        final t = (a - imp) / 1000;
        // Resplandor de lava y rocas que saltan.
        _oval(c, g, 22 * (1 - _q(a, imp, 700)) + 6, 7, _a(const Color(0xFFFF7B29), 0.6 * (1 - _q(a, imp, 700))));
        for (var k = 0; k < 7; k++) {
          if (t > 0.9) break;
          final vx = (k - 3) * 22.0 + (_h(i, k) - 0.5) * 10;
          final vy = -150.0 - 30 * _h(k, i);
          final p = g + Offset(vx * t, vy * t + 0.5 * 420 * t * t);
          final sz = 3 + (k % 3).toDouble();
          _fill.color = k.isEven ? const Color(0xFF6D4C2F) : const Color(0xFF636E72);
          c.drawRect(Rect.fromCenter(center: p, width: sz, height: sz), _fill);
        }
      }
    }
  }

  // ---------------- Meteoro ----------------

  static void _meteor(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const orange = Color(0xFFFF7B29);
    const hot = Color(0xFFFFF3B0);
    // Círculo mágico.
    if (a < s.returnAt) {
      final grow = _ease(_q(a, 0, 300));
      final fade = 1 - _q(a, s.buildMs, 300);
      final ctr = o.translate(0, 1);
      _ring(c, ctr, 24 * grow, 8 * grow, _a(orange, 0.9 * fade), 2);
      _ring(c, ctr, 16 * grow, 5.5 * grow, _a(hot, 0.7 * fade), 1);
      for (var k = 0; k < 8; k++) {
        final ang = a / 260 + k * math.pi / 4;
        final p = ctr + Offset(math.cos(ang) * 20 * grow, math.sin(ang) * 6.5 * grow);
        _fill.color = _a(k.isEven ? hot : orange, fade);
        c.drawRect(Rect.fromCenter(center: p, width: 3, height: 3), _fill);
      }
    }
    // Cielo rojo.
    final tint = s.darkness(a) * 0.14 * (a < s.buildMs ? _q(a, 200, 500) : 1);
    if (tint > 0) {
      _fill.color = Color.fromRGBO(255, 60, 20, tint);
      c.drawRect(vis, _fill);
    }
    // Meteoritos decorativos.
    final cen = st.centroid;
    for (var k = 0; k < 3; k++) {
      final land = s.buildMs + 160 + k * 140;
      final q = _q(a, land - 300, 300);
      if (q <= 0 || q >= 1) continue;
      final end = cen + Offset((k - 1) * 46.0 + 20, -4 + k * 6.0);
      final start = end + const Offset(90, -200);
      final p = Offset.lerp(start, end, q * q)!;
      for (var j = 0; j < 4; j++) {
        _disc(c, p + Offset(j * 3.5, -j * 8.0), 3.5 - j * 0.7, _a(j < 1 ? hot : orange, 1 - j / 4));
      }
    }
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      final q = _q(a, imp - 420, 420);
      final end = g.translate(0, -8);
      final start = end + const Offset(110, -230);
      if (q > 0 && q < 1) {
        final p = Offset.lerp(start, end, q * q)!;
        final dirv = (end - start) / (end - start).distance;
        for (var k = 7; k >= 0; k--) {
          _disc(c, p - dirv * (k * 6.0), 9 - k * 0.9,
              _a(k < 2 ? hot : (k < 5 ? orange : const Color(0xFFD63031)), 1 - k / 8));
        }
        _disc(c, p, 4, const Color(0xFFFFFFFF));
      }
      if (a >= imp) {
        // Cráter y explosión.
        _oval(c, g.translate(0, 1), 17, 5, _a(const Color(0xFF1A0D05), 0.85 * out));
        _ring(c, g.translate(0, 1), 17, 5, _a(orange, 0.8 * out), 1);
        final e = _q(a, imp, 450);
        if (e < 1) {
          _disc(c, g.translate(0, -10), 22 * (1 - e) * _ease(e * 4), _a(hot, 0.9 * (1 - e)));
          _ring(c, g.translate(0, -2), 55 * e, 20 * e, _a(orange, 1 - e), 3);
        }
      }
    }
  }

  // ---------------- Paradoja ----------------

  static void _clock(Canvas c, Offset o, double r, double hand, double minute,
      Color col, double alpha) {
    _ring(c, o, r, r, _a(col, alpha), 2);
    _ring(c, o, r - 3, r - 3, _a(const Color(0xFFFFFFFF), alpha * 0.4), 1);
    for (var k = 0; k < 12; k++) {
      final ang = k * math.pi / 6;
      final d = Offset(math.cos(ang), math.sin(ang));
      _line(c, o + d * (r - 5), o + d * (r - 1), _a(const Color(0xFFFFFFFF), alpha), k % 3 == 0 ? 2 : 1);
    }
    _line(c, o, o + Offset(math.cos(hand), math.sin(hand)) * (r * 0.8),
        _a(const Color(0xFFFFFFFF), alpha), 2);
    _line(c, o, o + Offset(math.cos(minute), math.sin(minute)) * (r * 0.5),
        _a(col, alpha), 2);
  }

  static void _paradox(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const violet = Color(0xFFA29BFE);
    const ice = Color(0xFFDFF9FB);
    if (a < s.buildMs + 200) {
      final grow = _ease(_q(a, 0, 350));
      final fade = 1 - _q(a, s.buildMs, 200);
      _clock(c, o.translate(0, -24), 20 * grow, -a / 70, -a / 420, violet, fade);
    }
    // Rebobinado: franjas horizontales que se corren.
    final d = s.darkness(a);
    if (d > 0 && a < s.returnAt) {
      for (var k = 0; k < 7; k++) {
        final y = vis.top + ((k * 41 + a * 0.35) % vis.height);
        final off = math.sin(a / 40 + k) * 10;
        _fill.color = _a(violet, 0.12 * d);
        c.drawRect(Rect.fromLTWH(vis.left + off, y, vis.width, 2 + (k % 3)), _fill);
      }
    }
    if (a < s.buildMs) return;
    final cen = st.centroid.translate(0, -26);
    final r = 52 * _ease(_q(a, s.buildMs, 260));
    final sweep = (a - s.buildMs) / s.releaseMs * math.pi * 2;
    _clock(c, cen, r, -math.pi / 2 + sweep * 2, -math.pi / 2 - sweep, violet, 0.8 * out);
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      if (a < imp) {
        // Ecos en el tiempo y cristales que crecen.
        for (var k = 1; k <= 2; k++) {
          final e = ((a / 300) + k * 0.5) % 1.0;
          _ring(c, g.translate(0, -8), 18 * (1 - e) + 6, 10 * (1 - e) + 4, _a(violet, 0.5 * e), 1);
        }
        final grow = _q(a, s.buildMs + 100, imp - s.buildMs - 100);
        for (var k = -3; k <= 3; k++) {
          final h = (30 - k.abs() * 5) * _ease(grow);
          final x = g.dx + k * 5;
          final path = Path()
            ..moveTo(x - 3, g.dy + 2)
            ..lineTo(x + (k * 0.6), g.dy + 2 - h)
            ..lineTo(x + 3, g.dy + 2)
            ..close();
          _fill.color = _a(k.isEven ? ice : const Color(0xFF81ECEC), 0.85);
          c.drawPath(path, _fill);
        }
      } else {
        final e = _q(a, imp, 400);
        _ring(c, g.translate(0, -10), 40 * e, 22 * e, _a(ice, 1 - e), 2);
      }
    }
  }

  // ---------------- Tormenta de Flechas ----------------

  static void _arrow(Canvas c, Offset head, Offset dirv, double len, double alpha) {
    _line(c, head - dirv * len, head, _a(const Color(0xFFDFE6E9), alpha), 1);
    _fill.color = _a(const Color(0xFFFDCB6E), alpha);
    c.drawRect(Rect.fromCenter(center: head, width: 2, height: 2), _fill);
  }

  static void _arrows(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    _gather(c, o, a, s.buildMs, u.fx.color);
    // Andanada al cielo.
    if (a > 300 && a < s.buildMs + 250) {
      for (var k = 0; k < 10; k++) {
        final t0 = 320 + k * 35.0;
        final e = (a - t0) / 1000;
        if (e < 0) continue;
        final p = o + Offset(st.dir * (4 + k * 1.5), -16 - e * 520);
        if (p.dy < vis.top - 20) continue;
        _arrow(c, p, const Offset(0, -1), 9, 1);
      }
    }
    if (a < s.buildMs) return;
    final cen = st.centroid;
    final spread = math.max(70.0, st.targets.fold<double>(0, (m, t) => math.max(m, (t.dx - cen.dx).abs())) * 2 + 50);
    const fall = 240.0;
    final dirv = Offset(-st.dir * 0.35, 1) / Offset(-st.dir * 0.35, 1).distance;
    for (var k = 0; k < 44; k++) {
      final land = s.buildMs + 120 + (k * 23) % (s.releaseMs - 300);
      final tx = cen.dx + (_h(k, 1) - 0.5) * spread;
      final ty = cen.dy + (_h(k, 2) - 0.5) * 34;
      final ground = Offset(tx, ty);
      final q = (a - (land - fall)) / fall;
      if (q < 0) continue;
      if (q < 1) {
        final p = ground - dirv * (1 - q) * 260;
        _arrow(c, p, dirv, 12, 1);
      } else {
        // Clavada.
        _arrow(c, ground, dirv, 6, 0.9 * out);
      }
    }
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      final e = _q(a, imp, 700);
      if (a >= imp && e < 1) {
        for (var k = 0; k < 4; k++) {
          _ring(c, g.translate((k - 1.5) * 7, -6 - k * 2.0), 6 + 14 * e, 4 + 8 * e,
              _a(const Color(0xFF7BED9F), 0.7 * (1 - e)), 1);
        }
      }
    }
  }

  // ---------------- Disparo Letal ----------------

  static void _deadShot(Canvas c, UltCinematic u, double a, UltStage st) {
    final s = u.script;
    final o = st.caster;
    const red = Color(0xFFFF4757);
    final muzzle = o.translate(st.dir * 9, -9);
    if (st.targets.isEmpty) return;
    final g = st.targets.first.translate(0, -10);
    if (a > 300 && a < s.buildMs + 60) {
      final q = _q(a, 300, s.buildMs - 300);
      _line(c, muzzle, g, _a(red, 0.25 + 0.6 * q), 3 - 2 * q);
      _disc(c, g, 2 + math.sin(a / 40).abs() * 2, _a(red, 0.9));
      _ring(c, g, 14 - 9 * q, 14 - 9 * q, _a(red, 0.8), 1);
      _disc(c, muzzle, 1.5 + 3 * q + math.sin(a / 30), _a(const Color(0xFFFFE066), 0.9));
    }
    final fire = s.buildMs + 50;
    if (a >= fire && a < fire + 160) {
      final q = _q(a, fire, 160);
      _star(c, muzzle, 26 * (1 - q) + 4, _a(const Color(0xFFFFFFFF), 1 - q * 0.5));
      _star(c, muzzle, 12 * (1 - q) + 2, _a(const Color(0xFFFFE066), 1 - q));
      _ring(c, muzzle, 20 * q + 4, 20 * q + 4, _a(const Color(0xFFFFFFFF), 1 - q), 2);
    }
    final imp = s.impactMs;
    if (a >= fire && a < imp) {
      final q = _q(a, fire, imp - fire);
      final p = Offset.lerp(muzzle, g, q)!;
      _line(c, muzzle, p, _a(const Color(0xFFFFFFFF), 0.35), 1);
      // Ondas a lo largo del recorrido (cámara lenta).
      for (var k = 0; k < 6; k++) {
        final kp = k / 6;
        if (kp > q) break;
        final e = ((q - kp) * 4).clamp(0.0, 1.0);
        final at = Offset.lerp(muzzle, g, kp)!;
        _ring(c, at, 3 + 9 * e, 5 + 12 * e, _a(const Color(0xFFFFFFFF), 0.6 * (1 - e)), 1);
      }
      _fill.color = const Color(0xFFFFFFFF);
      c.drawRect(Rect.fromCenter(center: p, width: 5, height: 2), _fill);
      _disc(c, p, 2, _a(const Color(0xFFFFE066), 0.8));
    }
    if (a >= imp && a < imp + 500) {
      final q = _q(a, imp, 500);
      _ring(c, g, 46 * _ease(q), 46 * _ease(q), _a(red, 1 - q), 4 * (1 - q) + 1);
      _ring(c, g, 30 * _ease(q), 30 * _ease(q), _a(const Color(0xFFFFFFFF), 1 - q), 2);
      _star(c, g, 18 * (1 - q), _a(const Color(0xFFFFFFFF), 1 - q));
    }
  }

  // ---------------- Baluarte ----------------

  static void _bulwark(
      Canvas c, UltCinematic u, double a, UltStage st, double out) {
    final s = u.script;
    final o = st.caster;
    const gold = Color(0xFFFFD166);
    const blue = Color(0xFF74B9FF);
    _gather(c, o, a, s.buildMs, gold);
    if (a < s.buildMs) {
      _disc(c, o.translate(-st.dir * 7, -10), 4 + math.sin(a / 50).abs() * 3,
          _a(gold, 0.6 * _q(a, 0, 300)));
      return;
    }
    // Cúpula (burbuja de escudo) sobre el grupo.
    final party = st.party.isEmpty ? [o] : st.party;
    var l = party.first.dx, r = l, top = party.first.dy, bottom = top;
    for (final p in party) {
      l = math.min(l, p.dx);
      r = math.max(r, p.dx);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
    }
    final ctr = Offset((l + r) / 2, (top + bottom) / 2 - 8);
    final ry = (bottom - top) / 2 + 30;
    final rx = math.max((r - l) / 2 + 34, ry * 0.9);
    final g = _ease(_q(a, s.buildMs, 300));
    final base = Offset.lerp(o.translate(0, -8), ctr, g)!;
    final w = rx * g, h = ry * g;
    final dome = Rect.fromCenter(center: base, width: w * 2, height: h * 2);
    final shimmer = 0.5 + 0.5 * math.sin(a / 60);
    _fill.color = _a(blue, 0.16 * out);
    c.drawOval(dome, _fill);
    // Nervaduras hexagonales: paralelos y meridianos de la burbuja.
    for (final k in [0.72, 0.42]) {
      _ring(c, base, w, h * k, _a(const Color(0xFFDFF9FB), 0.3 * out), 1);
    }
    for (final k in [0.75, 0.4]) {
      _ring(c, base, w * k, h, _a(const Color(0xFFDFF9FB), 0.25 * out), 1);
    }
    _ring(c, base, w, h, _a(blue, 0.95 * out), 2);
    // Brillo que recorre el borde.
    final sa = ((a - s.buildMs) / 500 % 1.0) * math.pi * 2;
    _stroke
      ..color = _a(const Color(0xFFFFFFFF), 0.85 * out * shimmer)
      ..strokeWidth = 2;
    c.drawArc(dome, sa, 0.5, false, _stroke);
    _ring(c, Offset(base.dx, base.dy + h * 0.78), w * 0.8, 5 * g,
        _a(gold, 0.7 * out), 1);
  }

  // ---------------- Juicio Divino ----------------

  static void _judgment(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const gold = Color(0xFFFFEAA7);
    _gather(c, o, a, s.buildMs, gold);
    if (a < s.returnAt) {
      final fade = 1 - _q(a, s.buildMs, 200);
      _ring(c, o.translate(0, -24), 9, 3, _a(const Color(0xFFFFF3B0), fade), 2);
      // Haces que barren el cielo.
      for (var k = 0; k < 3; k++) {
        final x = vis.left + ((a * 0.25 + k * vis.width / 3) % (vis.width + 60)) - 30;
        final path = Path()
          ..moveTo(x, vis.top)
          ..lineTo(x + 14, vis.top)
          ..lineTo(x + 44, vis.bottom)
          ..lineTo(x + 24, vis.bottom)
          ..close();
        _fill.color = _a(const Color(0xFFFFF3B0), 0.08 * s.darkness(a) * fade);
        c.drawPath(path, _fill);
      }
    }
    if (a < s.buildMs) return;
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      if (a < imp) {
        final q = _q(a, s.buildMs + 50, imp - s.buildMs - 50);
        _line(c, Offset(g.dx, vis.top), Offset(g.dx, vis.top + (g.dy - vis.top) * q),
            _a(const Color(0xFFFFF3B0), 0.4 + 0.4 * math.sin(a / 30).abs()), 1);
        _ring(c, g, 12 * q, 4 * q, _a(gold, 0.6), 1);
      } else {
        final e = _q(a, imp, 650);
        final w = (14 + 12 * _ease(_q(a, imp, 120))) * (1 - e * 0.6);
        final al = (1 - e) * out;
        final rect = Rect.fromLTRB(g.dx - w / 2, vis.top, g.dx + w / 2, g.dy + 2);
        final paint = Paint()
          ..isAntiAlias = false
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
            Color.fromRGBO(255, 243, 176, 0.15 * al),
            Color.fromRGBO(255, 234, 167, 0.9 * al),
          ]);
        c.drawRect(rect, paint);
        _fill.color = _a(const Color(0xFFFFFFFF), al);
        c.drawRect(Rect.fromLTRB(g.dx - w / 6, vis.top, g.dx + w / 6, g.dy + 2), _fill);
        _ring(c, g.translate(0, 1), w + 30 * e, 5 + 8 * e, _a(gold, al), 2);
      }
    }
  }

  // ---------------- Martillo Celestial ----------------

  static void _hammerShape(Canvas c, Offset bottom, double alpha) {
    const head = Size(44, 26);
    final hr = Rect.fromLTWH(bottom.dx - head.width / 2, bottom.dy - head.height,
        head.width, head.height);
    // Mango.
    _fill.color = _a(const Color(0xFF8A5A2B), alpha);
    c.drawRect(Rect.fromLTWH(bottom.dx - 3, hr.top - 34, 6, 34), _fill);
    _fill.color = _a(const Color(0xFF5C3A1B), alpha);
    c.drawRect(Rect.fromLTWH(bottom.dx + 1, hr.top - 34, 2, 34), _fill);
    // Cabeza.
    _fill.color = _a(const Color(0xFF8A6D1F), alpha);
    c.drawRect(hr.inflate(2), _fill);
    _fill.color = _a(const Color(0xFFFFD166), alpha);
    c.drawRect(hr, _fill);
    _fill.color = _a(const Color(0xFFFFF3B0), alpha);
    c.drawRect(Rect.fromLTWH(hr.left + 3, hr.top + 3, hr.width - 6, 4), _fill);
    _fill.color = _a(const Color(0xFFD4AF37), alpha);
    c.drawRect(Rect.fromLTWH(hr.left, hr.bottom - 6, hr.width, 6), _fill);
    _fill.color = _a(const Color(0xFFFFFFFF), alpha);
    c.drawRect(Rect.fromLTWH(hr.center.dx - 4, hr.center.dy - 4, 8, 8), _fill);
  }

  static void _hammer(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    _gather(c, o, a, s.buildMs, const Color(0xFFFFD166));
    // Chispas eléctricas alrededor del lanzador.
    if (a < s.buildMs + 100) {
      final slot = (a / 60).floor();
      for (var k = 0; k < 3; k++) {
        var p = o + Offset((_h(slot, k) - 0.5) * 30, -6 - _h(k, slot) * 26);
        for (var j = 0; j < 3; j++) {
          final q = p + Offset((_h(slot + j, k) - 0.5) * 10, (_h(k + j, slot) - 0.5) * 10);
          _line(c, p, q, const Color(0xFFDFF9FB), 1);
          p = q;
        }
      }
    }
    if (st.targets.isEmpty) return;
    final g = st.targets.first;
    final imp = s.impactMs;
    // Sombra que crece.
    if (a < imp) {
      final q = _q(a, 200, imp - 200);
      _oval(c, g.translate(0, 1), 8 + 18 * q, 3 + 4 * q, _a(const Color(0xFF000000), 0.5 * q));
    }
    final drop = s.buildMs + 100;
    if (a >= drop) {
      final q = _q(a, drop, imp - drop);
      final y0 = vis.top - 40;
      final y = y0 + (g.dy + 2 - y0) * q * q;
      final alpha = a < s.returnAt ? 1.0 : out;
      if (q < 1) {
        // Estela de la caída.
        for (var k = 1; k <= 3; k++) {
          _fill.color = _a(const Color(0xFFFFD166), 0.18 / k);
          c.drawRect(Rect.fromLTWH(g.dx - 22, y - 26 - k * 14.0, 44, 14), _fill);
        }
      }
      _hammerShape(c, Offset(g.dx, y), alpha);
    }
    if (a >= imp) {
      for (var k = 0; k < 3; k++) {
        final e = _q(a, imp + k * 80, 450);
        if (e <= 0 || e >= 1) continue;
        final rx = 20 + 80 * _ease(e);
        _ring(c, g.translate(0, 1), rx, rx * 0.3,
            _a(k == 0 ? const Color(0xFFFFFFFF) : const Color(0xFFFFD166), 1 - e), 3 * (1 - e) + 1);
      }
    }
  }
}
