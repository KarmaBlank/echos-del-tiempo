import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import '../../../../core/fx/fx_catalog.dart';
import 'fx_style.dart';
import 'particles.dart';

/// Dónde se reproduce una animación FXA: anclas en px del mundo (pies),
/// imágenes para los ecos y el color/elemento de la acción.
class FxStage {
  const FxStage({
    required this.caster,
    required this.targets,
    this.party = const [],
    this.partner,
    this.casterImage,
    this.partnerImage,
    required this.color,
    required this.element,
    this.visible = Rect.largest,
  });

  final Offset caster;
  final List<Offset> targets;
  final List<Offset> party;
  final Offset? partner;
  final ui.Image? casterImage, partnerImage;

  /// Color de la acción (`color: element`) y elemento (`element: auto`).
  final Color color;
  final FxElement element;

  /// Rectángulo del mundo a la vista (destellos, tinte, columnas).
  final Rect visible;

  /// Hacia dónde están los objetivos desde el lanzador (1 o −1).
  double get dir {
    if (targets.isEmpty) return 1;
    return _center(targets, caster).dx >= caster.dx ? 1 : -1;
  }

  static Offset _center(List<Offset> l, Offset fallback) {
    if (l.isEmpty) return fallback;
    var x = 0.0, y = 0.0;
    for (final p in l) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / l.length, y / l.length);
  }

  /// Pies del ancla [name] (objetivo [i] para `target`/`sky`).
  Offset anchor(String? name, [int i = 0]) {
    Offset target() => targets.isEmpty
        ? caster.translate(dir * 60, 0)
        : targets[i.clamp(0, targets.length - 1)];
    final tc = _center(targets, caster.translate(dir * 60, 0));
    return switch (name) {
      'target' => target(),
      'targets_center' => tc,
      'allies_center' => _center(party, caster),
      'partner' => partner ?? caster,
      'sky' => target().translate(-dir * 22, -110),
      'sky_center' => tc.translate(-dir * 22, -110),
      'sky_caster' => caster.translate(-dir * 8, -80),
      'screen' => visible.isFinite ? visible.center : tc,
      _ => caster,
    };
  }
}

/// Reproduce un `FxTimeline` (docs/specs/game_editor.md § 2.2): [tick]
/// dispara lo puntual (partículas, sacudidas, hit-stop) una sola vez por
/// clave en [done]; [paint] dibuja las pistas visuales a la edad [a] ms.
/// Sin estado propio: sirve igual para la escena y para el Editor.
abstract final class FxPlayer {
  static const _maxStaggered = 4;

  /// Oscurecido del fondo (pista `dim`), 0..1.
  static double dim(FxTimeline t, double a) =>
      (t.track('dim')?.numAt('v', a) ?? 0).clamp(0.0, 1.0);

  /// Expande los disparos de [tr] (uno por objetivo con `each_target`).
  static Iterable<(FxKey, int, int)> _fires(FxTrack tr, int nTargets) sync* {
    for (final f in tr.fires) {
      if (tr.eachTarget && nTargets > 0) {
        for (var i = 0; i < nTargets; i++) {
          yield (f, i, f.t + tr.stagger * math.min(i, _maxStaggered - 1));
        }
      } else {
        yield (f, 0, f.t);
      }
    }
  }

  /// Lo puntual hasta la edad [a]. [skipped] = adelantada (sin sacudidas
  /// ni hit-stop pendientes).
  static void tick(FxTimeline t, double a, FxStage st, ParticleSystem p,
      Set<String> done,
      {required void Function(int ms) hitStop, bool skipped = false}) {
    final n = st.targets.length;
    for (var k = 0; k < t.tracks.length; k++) {
      final tr = t.tracks[k];
      if (!const {'particles', 'shake', 'hitstop'}.contains(tr.type)) continue;
      var j = 0;
      for (final (f, i, at) in _fires(tr, n)) {
        j++;
        if (a < at || !done.add('fx$k.$j')) continue;
        switch (tr.type) {
          case 'particles':
            final o = st.anchor(f.s('anchor') ?? tr.s('anchor') ?? 'target', i)
                .translate(f.d('dx', 0) * st.dir, f.d('dy', 0) - 10);
            _particles(p, f, o, st);
          case 'shake':
            if (!skipped) p.addShake(f.d('amp', 4));
          case 'hitstop':
            if (!skipped) hitStop(f.n('ms')?.toInt() ?? 80);
        }
      }
    }
  }

  // ---------------------------------------------------------- partículas

  static const _sparks = ElementFx([
    Color(0xFFFFFFFF),
    Color(0xFFFFE066),
    Color(0xFF9FF6FF),
  ], 6, 60, 0, 0.25, ParticleShape.ray);
  static const _dust = ElementFx([
    Color(0xFFB2A58F),
    Color(0xFF8D8270),
    Color(0xFFDFE6E9),
  ], 16, 90, -10, 0.7, ParticleShape.square);
  static const _debris = ElementFx([
    Color(0xFF6D4C2F),
    Color(0xFF8D6E4F),
    Color(0xFF636E72),
    Color(0xFFB2BEC3),
  ], 14, 120, 260, 0.8, ParticleShape.square);
  static const _frost = ElementFx([
    Color(0xFFF4FDFF),
    Color(0xFF9FE3F0),
    Color(0xFF74B9FF),
  ], 12, 70, 60, 0.6, ParticleShape.shard);
  static const _embers = ElementFx([
    Color(0xFFFFD166),
    Color(0xFFFF7B29),
    Color(0xFFFFE8A3),
  ], 10, 40, 120, 1.1, ParticleShape.square);

  static void _particles(ParticleSystem p, FxKey f, Offset o, FxStage st) {
    final mult = f.d('count', 1);
    final col = f.s('color') == null ? null : color(f.s('color'), st);
    switch (f.s('preset') ?? 'burst') {
      case 'sparks':
        p.burstWith(_sparks, o.dx, o.dy, mult);
      case 'dust':
        p.burstWith(_dust, o.dx, o.dy + 10, mult);
      case 'debris':
        p.burstWith(_debris, o.dx, o.dy + 8, mult);
      case 'frost':
        p.burstWith(_frost, o.dx, o.dy, mult);
      case 'embers':
        p.burstWith(_embers, o.dx, o.dy - 6, mult);
      case 'shards':
        p.burstWith(
            ElementFx([col ?? fxWhite, _light(st.color), st.color], 8, 110, 40,
                0.45, ParticleShape.shard),
            o.dx,
            o.dy,
            mult);
      case 'sparkles':
        final c = col ?? st.color;
        p.burstWith(
            ElementFx([c, _light(c), fxWhite], 10, 40, -70, 0.9,
                ParticleShape.plus),
            o.dx,
            o.dy,
            mult);
      default:
        final el = switch (f.s('element')) {
          null || 'auto' => st.element,
          final name => FxElement.values
                  .where((e) => e.name == name)
                  .firstOrNull ??
              st.element,
        };
        p.burst(o.dx, o.dy, el, mult);
    }
  }

  // ---------------------------------------------------------- colores

  static const _gold = Color(0xFFFFD36B);

  /// Firma de los ecos: el color de la acción llevado hacia el cian
  /// temporal (docs/lore.md: los ecos del tiempo).
  static Color echoColor(Color c) =>
      Color.lerp(c, const Color(0xFF7FF3FF), 0.7)!;

  static Color _light(Color c) => Color.lerp(c, fxWhite, 0.55)!;

  /// Color por rol (`element`, `light`, `dark`, `echo`, `white`, `gold`)
  /// o `'#rrggbb'` explícito.
  static Color color(String? role, FxStage st) {
    switch (role) {
      case null || 'element':
        return st.color;
      case 'light':
        return _light(st.color);
      case 'dark':
        return Color.lerp(st.color, const Color(0xFF000000), 0.5)!;
      case 'echo':
        return echoColor(st.color);
      case 'white':
        return fxWhite;
      case 'gold':
        return _gold;
    }
    final hex = role.startsWith('#') ? role.substring(1) : role;
    final v = int.tryParse(hex, radix: 16);
    if (v == null || hex.length != 6) return st.color;
    return Color(0xFF000000 | v);
  }

  // ---------------------------------------------------------- dibujo

  static final _fill = Paint()..isAntiAlias = false;
  static final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

  static Color _a(Color c, double k) =>
      c.withValues(alpha: (c.a * k).clamp(0.0, 1.0));

  static double _q(double a, num from, num len) =>
      len <= 0 ? 1 : ((a - from) / len).clamp(0.0, 1.0);

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

  static void _ring(
      Canvas c, Offset o, double rx, double ry, Color col, double w) {
    _stroke
      ..color = col
      ..strokeWidth = w;
    c.drawOval(
        Rect.fromCenter(center: o, width: rx * 2, height: ry * 2), _stroke);
  }

  /// Dibuja las pistas visuales a la edad [a]. [flash] = factor de
  /// destellos del jugador (accesibilidad; 0 = sin destellos).
  static void paint(Canvas c, FxTimeline t, double a, FxStage st,
      {double flash = 1}) {
    final n = st.targets.length;
    // Tinte de la escena.
    for (final tr in t.ofType('tint')) {
      final v = tr.numAt('v', a) ?? 0;
      if (v <= 0 || !st.visible.isFinite) continue;
      // Luz de color sumada (no tapa: aclara hacia el tono).
      _fill
        ..color = _a(color(tr.s('color') ?? tr.textAt('color', a), st),
            v.clamp(0.0, 0.5) * 0.6)
        ..blendMode = BlendMode.plus;
      c.drawRect(st.visible, _fill);
      _fill.blendMode = BlendMode.srcOver;
    }
    // Formas y estelas son luz: se suman (brillan sobre el oscurecido).
    _fill.blendMode = BlendMode.plus;
    _stroke.blendMode = BlendMode.plus;
    for (final tr in t.tracks) {
      if (tr.type == 'echo') {
        _fill.blendMode = BlendMode.srcOver;
        _echo(c, tr, a, st);
        _fill.blendMode = BlendMode.plus;
        continue;
      }
      switch (tr.type) {
        case 'shape':
          for (final (f, i, at) in _fires(tr, n)) {
            final ms = f.d('ms', 300);
            if (a < at || a > at + ms) continue;
            _shape(c, f, (a - at) / ms, a - at, st, i);
          }
        case 'trail':
          for (final (f, i, at) in _fires(tr, n)) {
            _trail(c, f, a - at, st, i);
          }
      }
    }
    _fill.blendMode = BlendMode.srcOver;
    _stroke.blendMode = BlendMode.srcOver;
    // Destellos al final (sobre todo), con tope 0.7 (§ 5.1).
    if (flash > 0 && st.visible.isFinite) {
      for (final tr in t.ofType('flash')) {
        for (final (f, _, at) in _fires(tr, n)) {
          final ms = f.d('ms', 150);
          if (a < at || a > at + ms) continue;
          final k = 1 - (a - at) / ms;
          final alpha = (f.d('alpha', 0.5).clamp(0.0, 0.7)) * k * flash;
          _fill.color = _a(color(f.s('color') ?? 'white', st), alpha);
          c.drawRect(st.visible, _fill);
        }
      }
    }
  }

  // ---------------------------------------------------------- ecos

  /// Ecos translúcidos (la firma de las ULT): [count] copias del actor
  /// que recorren el mismo camino que la primera, cada una [lag] ms más
  /// tarde, más tenues; `spacing` las abre en abanico y `orbit` las
  /// reparte alrededor del destino.
  static void _echo(Canvas c, FxTrack tr, double a, FxStage st) {
    final keys = tr.keys;
    if (keys.isEmpty) return;
    final count = (tr.n('count') ?? 3).toInt().clamp(1, 12);
    final lag = tr.d0('lag', 80);
    final fade = tr.d0('fade', 150);
    final base = tr.d0('alpha', 0.45).clamp(0.0, 0.8);
    final col = color(tr.s('color') ?? 'echo', st);
    final partner = tr.s('who') == 'partner';
    final img = partner ? st.partnerImage : st.casterImage;
    final sp = tr.props['spacing'];
    final spacing = sp is List && sp.length == 2
        ? Offset((sp[0] as num).toDouble() * st.dir, (sp[1] as num).toDouble())
        : Offset.zero;
    final orbit = tr.d0('orbit', 0);
    final first = keys.first.t.toDouble(), last = keys.last.t.toDouble();
    Offset at(FxKey k) => st
        .anchor(k.s('at') ?? (partner ? 'partner' : 'caster'))
        .translate(k.d('dx', 0) * st.dir, k.d('dy', 0));
    for (var i = count - 1; i >= 0; i--) {
      final ai = a - i * lag;
      if (ai < first || ai > last + fade) continue;
      // Posición sobre el camino de keyframes.
      var pos = at(keys.first);
      for (var k = 1; k < keys.length; k++) {
        final k0 = keys[k - 1], k1 = keys[k];
        if (ai <= k0.t) break;
        final q = k1.ease.apply(_q(ai, k0.t, k1.t - k0.t));
        pos = Offset.lerp(at(k0), at(k1), q)!;
      }
      pos += spacing * i.toDouble();
      if (orbit > 0 && keys.length > 1) {
        final w = _q(ai, keys[0].t, keys[1].t - keys[0].t);
        final ang = i * math.pi * 2 / count + 0.4;
        pos += Offset(math.cos(ang) * orbit, math.sin(ang) * orbit * 0.45) * w;
      }
      final fadeIn = _q(ai, first, 80);
      final fadeOut = ai > last ? 1 - (ai - last) / fade : 1.0;
      final alpha = base * (1 - i / (count + 1)) * fadeIn * fadeOut;
      _ghost(c, img, pos, alpha, col, st.dir);
    }
  }

  static void _ghost(Canvas c, ui.Image? img, Offset feet, double alpha,
      Color col, double dir) {
    if (alpha <= 0.01) return;
    final x = feet.dx.roundToDouble(), y = feet.dy.roundToDouble();
    c.save();
    c.translate(x, y);
    if (dir < 0) c.scale(-1, 1);
    if (img == null) {
      _fill.color = _a(col, alpha);
      c.drawRect(const Rect.fromLTWH(-6, -16, 12, 16), _fill);
    } else {
      final o = Offset(-img.width / 2, -img.height.toDouble());
      // Halo desfasado (±1 px), silueta luminosa del color del eco
      // (suma de luz: brilla sobre el fondo oscurecido) y la imagen
      // tenue encima, para que se reconozca quién es.
      final glow = Paint()
        ..filterQuality = FilterQuality.none
        ..blendMode = BlendMode.plus
        ..colorFilter = ColorFilter.mode(_a(col, alpha * 0.35), BlendMode.srcIn);
      c.drawImage(img, o.translate(-1, 0), glow);
      c.drawImage(img, o.translate(1, 0), glow);
      c.drawImage(
          img,
          o,
          Paint()
            ..filterQuality = FilterQuality.none
            ..blendMode = BlendMode.plus
            ..colorFilter =
                ColorFilter.mode(_a(col, alpha * 0.9), BlendMode.srcIn));
      c.drawImage(
          img,
          o,
          Paint()
            ..filterQuality = FilterQuality.none
            ..color = Color.fromRGBO(255, 255, 255, alpha * 0.4));
    }
    c.restore();
  }

  // ---------------------------------------------------------- estelas

  static void _trail(Canvas c, FxKey f, double age, FxStage st, int i) {
    final ms = f.d('ms', 250);
    final echoes = (f.n('echoes') ?? 0).toInt().clamp(0, 8);
    final lag = f.d('lag', 30);
    if (age < 0 || age > ms + echoes * lag + 60) return;
    final off = Offset(f.d('dx', 0) * st.dir, f.d('dy', 0));
    final from = st.anchor(f.s('from') ?? 'caster', i).translate(0, -10) + off;
    final to = st.anchor(f.s('to') ?? 'target', i).translate(0, -10) + off;
    final ease = FxEase.parse(f.data['ease'] ?? 'linear');
    final col = color(f.s('color'), st);
    final w = f.d('width', 1.5);
    final scale = f.d('scale', 1);
    final head = f.s('head') ?? 'dot';
    final dirV = to - from;
    final len = dirV.distance;
    final u = len == 0 ? const Offset(1, 0) : dirV / len;
    // La estela (línea que se apaga tras la cabeza).
    final q0 = ease.apply(_q(age, 0, ms));
    final tail = ease.apply(_q(age - 90, 0, ms));
    if (q0 > tail) {
      final fade = age > ms ? 1 - _q(age, ms, 60) : 1.0;
      _line(c, Offset.lerp(from, to, tail)!, Offset.lerp(from, to, q0)!,
          _a(col, 0.55 * fade), w);
    }
    for (var j = echoes; j >= 0; j--) {
      final aj = age - j * lag;
      if (aj < 0 || aj > ms + 40) continue;
      final q = ease.apply(_q(aj, 0, ms));
      final alpha = j == 0 ? 1.0 : 0.55 * (1 - j / (echoes + 1));
      final cc = j == 0 ? col : echoColor(col);
      _head(c, head, Offset.lerp(from, to, q)!, u, _a(cc, alpha), scale);
    }
  }

  static void _head(
      Canvas c, String kind, Offset p, Offset u, Color col, double s) {
    final nrm = Offset(-u.dy, u.dx);
    switch (kind) {
      case 'arrow':
        _line(c, p - u * 8 * s, p, col, 1);
        _line(c, p, p - u * 3 * s + nrm * 2 * s, col, 1);
        _line(c, p, p - u * 3 * s - nrm * 2 * s, col, 1);
      case 'spear':
        _line(c, p - u * 16 * s, p, col, 1.5);
        _fill.color = col;
        c.drawPath(
            Path()
              ..moveTo(p.dx + u.dx * 4 * s, p.dy + u.dy * 4 * s)
              ..lineTo(p.dx + nrm.dx * 2.5 * s, p.dy + nrm.dy * 2.5 * s)
              ..lineTo(p.dx - nrm.dx * 2.5 * s, p.dy - nrm.dy * 2.5 * s)
              ..close(),
            _fill);
      case 'hammer':
        _line(c, p - u * 10 * s, p, col, 1.5 * s);
        _fill.color = col;
        c.drawRect(
            Rect.fromCenter(center: p, width: 7 * s, height: 5 * s), _fill);
        _fill.color = _a(fxWhite, col.a);
        c.drawRect(
            Rect.fromCenter(
                center: p.translate(0, -1.5 * s), width: 7 * s, height: 1),
            _fill);
      case 'meteor':
        for (var k = 4; k >= 1; k--) {
          _fill.color = _a(col, 0.18 * k);
          c.drawCircle(p - u * (k * 3.0 * s), (5 - k * 0.6) * s, _fill);
        }
        _fill.color = col;
        c.drawCircle(p, 4.5 * s, _fill);
        _fill.color = _a(fxWhite, col.a * 0.9);
        c.drawCircle(p.translate(-1, -1), 2 * s, _fill);
      case 'bolt':
        _line(c, p - u * 12 * s, p, _a(col, col.a * 0.6), 3 * s);
        _line(c, p - u * 10 * s, p, _a(fxWhite, col.a), 1.2 * s);
      default:
        _fill.color = col;
        c.drawCircle(p, 2.5 * s, _fill);
    }
  }

  // ---------------------------------------------------------- formas

  static void _shape(
      Canvas c, FxKey f, double p, double age, FxStage st, int i) {
    final s = f.d('scale', 1);
    final col0 = color(f.s('color'), st);
    final env = (p < 0.12 ? p / 0.12 : 1.0) * f.d('alpha', 1);
    final feet = st
        .anchor(f.s('anchor') ?? 'target', i)
        .translate(f.d('dx', 0) * st.dir, f.d('dy', 0));
    final body = feet.translate(0, -10);
    Color col(double k) => _a(col0, env * k);
    switch (f.s('shape')) {
      case 'gather':
        final ms = f.d('ms', 800);
        for (var k = 0; k < 14; k++) {
          final fr = (age / 420 + _h(k, 3)) % 1.0;
          final ang = k * math.pi * 2 / 14 + _h(k, 9) * 0.4;
          final r1 = 70 * (1 - fr) + 8, r2 = r1 + 6 + 10 * (1 - fr);
          final d = Offset(math.cos(ang), math.sin(ang) * 0.6);
          _line(c, body + d * r1, body + d * r2,
              col((0.25 + 0.6 * fr) * (1 - p)), 1);
        }
        final r = 12 + 6 * (age / ms).clamp(0.0, 1.0) + math.sin(age / 55) * 2;
        _ring(c, body.translate(0, 2), r, r * 0.5 + 5, col(0.6), 2);
      case 'slash_arc':
        final ang = f.d('angle', 0) * math.pi / 180 * st.dir;
        final r = 16 * s;
        final sweep = math.min(1.0, p * 3) * math.pi * 0.9;
        c.save();
        c.translate(body.dx, body.dy);
        c.rotate(ang);
        _stroke
          ..color = col(1 - p)
          ..strokeWidth = 3 * (1 - p) + 1;
        c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r),
            -math.pi * 0.45, sweep, false, _stroke);
        _stroke
          ..color = _a(fxWhite, env * (1 - p))
          ..strokeWidth = 1;
        c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r - 1),
            -math.pi * 0.45, sweep, false, _stroke);
        c.restore();
      case 'slash_cross':
        final l = 13 * s * math.min(1.0, p * 4);
        for (final d in const [Offset(1, -1), Offset(1, 1)]) {
          final v = Offset(d.dx * st.dir, d.dy) * l;
          _line(c, body - v, body + v, col((1 - p) * 0.7), 4 * (1 - p) + 1);
          _line(c, body - v, body + v, _a(fxWhite, env * (1 - p)), 1.5);
        }
      case 'ring':
        final implode = f.b('implode');
        final k = Curves2.out(p);
        final r = implode ? 4 + 18 * s * (1 - k) : 5 + 18 * s * k;
        _ring(c, body, r, r * 0.6, col(1 - p), implode ? 1.5 : 2 * (1 - p) + 1);
      case 'rune_circle':
        final out = p > 0.8 ? (1 - p) / 0.2 : 1.0;
        final rx = 16 * s, ry = 6 * s;
        final g = feet.translate(0, 1);
        _ring(c, g, rx, ry, col(0.8 * out), 1);
        _ring(c, g, rx * 0.7, ry * 0.7, col(0.5 * out), 1);
        for (var k = 0; k < 8; k++) {
          final ang = age / 400 + k * math.pi / 4;
          final o = g + Offset(math.cos(ang) * rx, math.sin(ang) * ry);
          _fill.color = _a(fxWhite, env * out * 0.9);
          c.drawRect(Rect.fromCenter(center: o, width: 2, height: 2), _fill);
        }
        for (var k = 0; k < 5; k++) {
          final fr = (age / 600 + k / 5) % 1.0;
          final x = g.dx + (k - 2) * rx * 0.35;
          _line(c, Offset(x, g.dy - fr * 22), Offset(x, g.dy - fr * 22 - 4),
              col(out * (1 - fr)), 1);
        }
      case 'shockwave':
        final k = Curves2.out(p);
        final r = 8 + 30 * s * k;
        _ring(c, feet, r, r * 0.32, col(1 - p), 3 * (1 - p) + 1);
        _ring(c, feet, r * 0.7, r * 0.22, _a(fxWhite, env * (1 - p) * 0.6), 1);
      case 'quake':
        for (var k = 0; k < 7; k++) {
          final ang = k * math.pi * 2 / 7 + _h(k, 5);
          final len = (14 + 16 * _h(k, 7)) * s * math.min(1.0, p * 3);
          var a0 = feet;
          for (var seg = 1; seg <= 3; seg++) {
            final jit = (_h(k, seg) - 0.5) * 6;
            final b = feet +
                Offset(math.cos(ang) * len * seg / 3 + jit,
                    math.sin(ang) * len * seg / 3 * 0.35);
            _line(c, a0, b, col(1 - p), 1);
            a0 = b;
          }
        }
      case 'pillar':
        final top = st.visible.isFinite ? st.visible.top : feet.dy - 160;
        final w = 10 * s * (1 - p * 0.6);
        _fill.color = col(0.45 * (1 - p));
        c.drawRect(Rect.fromLTRB(feet.dx - w / 2, top, feet.dx + w / 2, feet.dy),
            _fill);
        _fill.color = _a(fxWhite, env * 0.8 * (1 - p));
        c.drawRect(
            Rect.fromLTRB(feet.dx - w / 6, top, feet.dx + w / 6, feet.dy), _fill);
      case 'beam':
        final from = st.caster.translate(0, -10);
        _line(c, from, body, col(0.5 * (1 - p)), 5 * s * (1 - p) + 1);
        _line(c, from, body, _a(fxWhite, env * (1 - p)), 1.5);
      case 'shield_dome':
        final out = p > 0.75 ? (1 - p) / 0.25 : 1.0;
        final grow = Curves2.out(math.min(1.0, p * 4));
        final rx = 34 * s * grow, ry = 28 * s * grow;
        final rect = Rect.fromCenter(
            center: feet.translate(0, 2), width: rx * 2, height: ry * 2);
        _fill.color = col(0.12 * out);
        c.drawArc(rect, math.pi, math.pi, true, _fill);
        _stroke
          ..color = col(0.8 * out)
          ..strokeWidth = 1.5;
        c.drawArc(rect, math.pi, math.pi, false, _stroke);
        for (var k = 1; k < 4; k++) {
          final fx = (k / 4 * 2 - 1) * rx;
          final h = ry * math.sqrt(math.max(0, 1 - (fx / rx) * (fx / rx)));
          _line(c, Offset(feet.dx + fx, feet.dy + 2),
              Offset(feet.dx + fx, feet.dy + 2 - h), col(0.3 * out), 1);
        }
      case 'sky_crack':
        final y = feet.dy - 100;
        final grow = math.min(1.0, p * 3);
        var prev = Offset(feet.dx - 50 * grow, y);
        for (var k = 1; k <= 10; k++) {
          final x = feet.dx - 50 * grow + 100 * grow * k / 10;
          final pt = Offset(x, y + (_h(k, 2) - 0.5) * 10);
          _line(c, prev, pt, col(0.5 * (1 - p)), 4);
          _line(c, prev, pt, _a(fxWhite, env * (1 - p)), 1);
          prev = pt;
        }
      case 'bolt':
        final top = feet.dy - 120;
        var prev = Offset(body.dx + (_h(i, 1) - 0.5) * 20, top);
        final flick = ((age / 30).floor().isEven) ? 1.0 : 0.6;
        for (var k = 1; k <= 7; k++) {
          final y = top + (body.dy - top) * k / 7;
          final x = k == 7 ? body.dx : body.dx + (_h(i * 7 + k, 4) - 0.5) * 16;
          final pt = Offset(x, y);
          _line(c, prev, pt, col(0.5 * flick * (1 - p)), 4);
          _line(c, prev, pt, _a(fxWhite, env * flick * (1 - p)), 1);
          prev = pt;
        }
      case 'clock':
        final out = p > 0.85 ? (1 - p) / 0.15 : 1.0;
        final o = body.translate(0, -26 * s);
        final r = 18 * s * Curves2.out(math.min(1.0, p * 5));
        _ring(c, o, r, r, col(0.8 * out), 1.5);
        for (var k = 0; k < 12; k++) {
          final ang = k * math.pi / 6;
          final d = Offset(math.cos(ang), math.sin(ang));
          _line(c, o + d * (r - 3), o + d * r, col(0.7 * out), 1);
        }
        // Las agujas giran hacia atrás, cada vez más rápido.
        final h = -age * age / 90000.0;
        _line(c, o, o + Offset(math.sin(h), -math.cos(h)) * r * 0.55,
            _a(fxWhite, env * out), 1.5);
        _line(c, o, o + Offset(math.sin(h * 12), -math.cos(h * 12)) * r * 0.85,
            _a(fxWhite, env * out * 0.8), 1);
      case 'cross':
        final l = 12 * s * Curves2.out(math.min(1.0, p * 3));
        _line(c, body.translate(0, -l * 1.3), body.translate(0, l),
            col(1 - p), 3);
        _line(c, body.translate(-l * 0.7, -l * 0.4),
            body.translate(l * 0.7, -l * 0.4), col(1 - p), 3);
      case 'rain':
        final w = 90 * s;
        final top = feet.dy - 110;
        for (var k = 0; k < 26; k++) {
          final fr = (age / 260 + _h(k, 11)) % 1.0;
          final x = feet.dx - w / 2 + w * _h(k, 13) - fr * 18 * st.dir;
          final y = top + (feet.dy - top) * fr;
          _line(c, Offset(x + 3 * st.dir, y - 9), Offset(x, y),
              col(0.75 * (1 - p * 0.5)), 1);
        }
      case 'shards':
        for (var k = 0; k < 8; k++) {
          final ang = k * math.pi / 4 + _h(k, 21) * 0.4;
          final d = Offset(math.cos(ang), math.sin(ang) * 0.7);
          final o = body + d * (4 + 26 * s * Curves2.out(p));
          final nrm = Offset(-d.dy, d.dx);
          _fill.color = col(1 - p);
          c.drawPath(
              Path()
                ..moveTo(o.dx + d.dx * 4, o.dy + d.dy * 4)
                ..lineTo(o.dx + nrm.dx * 1.5, o.dy + nrm.dy * 1.5)
                ..lineTo(o.dx - nrm.dx * 1.5, o.dy - nrm.dy * 1.5)
                ..close(),
              _fill);
        }
      case 'reticle':
        final r = (9 + 18 * (1 - Curves2.out(math.min(1.0, p * 1.6)))) * s;
        final rot = (1 - p) * 0.8;
        c.save();
        c.translate(body.dx, body.dy);
        c.rotate(rot);
        for (var k = 0; k < 4; k++) {
          c.save();
          c.rotate(k * math.pi / 2);
          _line(c, Offset(r, -r), Offset(r - 5, -r), col(0.9), 1);
          _line(c, Offset(r, -r), Offset(r, -r + 5), col(0.9), 1);
          c.restore();
        }
        c.restore();
        final blink = p > 0.85 && (age / 40).floor().isEven ? 1.0 : 0.5;
        _line(c, body.translate(-3, 0), body.translate(3, 0), col(blink), 1);
        _line(c, body.translate(0, -3), body.translate(0, 3), col(blink), 1);
    }
  }
}

/// Curvas mínimas (sin depender de Flutter).
abstract final class Curves2 {
  static double out(double x) {
    final t = x.clamp(0.0, 1.0);
    return 1 - (1 - t) * (1 - t);
  }
}

extension on FxTrack {
  double d0(String k, double fallback) => n(k)?.toDouble() ?? fallback;
}
