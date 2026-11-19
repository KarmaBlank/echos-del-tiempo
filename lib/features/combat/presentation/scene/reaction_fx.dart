import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_type.dart';
import '../../../../core/settings/graphics.dart';
import '../../../../game_engine/models/elements.dart';
import '../../../../game_engine/models/status.dart';
import '../../domain/element_text.dart';
import 'fx_style.dart';

/// Reacciones elementales en la escena (docs/specs/elemental_reactions.md
/// § 3; números en docs/specs/battle_presentation.md § "Reacciones
/// elementales"): un cartel corto sobre el objetivo (`¡ELECTROCUCIÓN!`),
/// del color del elemento que detona, más el anillo de salpicadura de la
/// Explosión tóxica y el rayo de la Electrocución / Cortocircuito.
///
abstract final class ReactionTiming {
  /// El cartel sale esto después del golpe que detona.
  static const afterHitMs = 30;

  /// Vida del cartel (tope del pedido: ≤ 600 ms).
  static const bannerMs = 600;

  /// El cartel entra (escala 1.5 → 1) en este tiempo.
  static const popMs = 90;

  /// Y se apaga en los últimos [fadeMs].
  static const fadeMs = 160;

  /// Anillo de salpicadura (Explosión tóxica) / anillo chico del resto.
  static const ringMs = 420;

  /// Rayo de Electrocución / Cortocircuito.
  static const zapMs = 260;

  /// Los demás enemigos reciben la salpicadura esto después del centro.
  static const splashLagMs = 90;

  /// Separación entre las salpicaduras de cada enemigo.
  static const splashStaggerMs = 40;

  /// Cortocircuito: el rayo llega al segundo enemigo en este tiempo.
  static const hopMs = 140;

  /// El número / el golpe del salto de Cortocircuito.
  static int shortCircuitHitAt(int at) => at + hopMs;

  /// La salpicadura al enemigo [i] de la Explosión tóxica.
  static int splashAt(int at, int i) =>
      at + splashLagMs + i * splashStaggerMs;
}

/// Cómo se ve una reacción.
class ReactionLook {
  const ReactionLook(this.kind, this.color, this.accent, this.el,
      {this.ring = false, this.zap = false, this.bigRing = false});

  final ReactionKind kind;

  /// Texto del cartel y del rayo.
  final Color color;

  /// Franjas del cartel (el estado consumido).
  final Color accent;

  /// Partículas del impacto (`kElementFx`).
  final FxElement el;

  /// Anillo en el objetivo.
  final bool ring;

  /// Anillo grande + uno chico en cada salpicado (Explosión tóxica).
  final bool bigRing;

  /// Rayo quebrado (Electrocución sobre el objetivo; Cortocircuito al
  /// segundo enemigo).
  final bool zap;

  String get banner => reactionBanner(kind);
}

Color _c(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

/// Look de la reacción [kind]: el color de la reacción y, en las
/// franjas, el del estado que consume.
ReactionLook reactionLook(ReactionKind kind) {
  final color = _c(reactionHex(kind));
  final accent = kind == ReactionKind.explosionToxica
      ? statusColor(StatusKind.burn)
      : kind == ReactionKind.combustion
          ? statusColor(StatusKind.poison)
      : statusColor(kind.primer);
  return switch (kind) {
    ReactionKind.electrocucion ||
    ReactionKind.cortocircuito =>
      ReactionLook(kind, color, accent, FxElement.mana, zap: true),
    ReactionKind.explosionToxica => ReactionLook(
        kind, color, accent, FxElement.poison,
        ring: true, bigRing: true),
    ReactionKind.congelacionSubita =>
      ReactionLook(kind, color, accent, FxElement.freeze, ring: true),
    ReactionKind.derretir =>
      ReactionLook(kind, color, accent, FxElement.burn, ring: true),
    ReactionKind.combustion => ReactionLook(
        kind, color, accent, FxElement.burn,
        ring: true, bigRing: true),
  };
}

/// Qué pieza de una reacción.
enum ReactionPart { banner, ring, zap }

/// Una pieza ubicada (px del mundo; el cartel se dibuja en px de
/// pantalla sobre `(x, y)`). Inmutable, sin reloj.
class ReactionFx {
  const ReactionFx(
    this.part,
    this.look, {
    this.x = 0,
    this.y = 0,
    this.tx = 0,
    this.ty = 0,
    this.delayMs = 0,
    this.big = false,
    this.seed = 0,
  });

  final ReactionPart part;
  final ReactionLook look;
  final double x, y;

  /// Destino del rayo.
  final double tx, ty;
  final int delayMs;

  /// Anillo grande (centro de la Explosión tóxica).
  final bool big;

  /// Semilla del quiebre del rayo.
  final int seed;

  int get durationMs => switch (part) {
        ReactionPart.banner => ReactionTiming.bannerMs,
        ReactionPart.ring => ReactionTiming.ringMs,
        ReactionPart.zap => ReactionTiming.zapMs,
      };
}

/// Altura del cartel sobre los pies del objetivo (px del mundo): entre
/// la etiqueta del enemigo y los textos de estado (`y − 46`).
const bannerDy = -34.0;

/// Tamaño del texto del cartel (× la unidad de las etiquetas `u`).
const bannerTextU = 12.0;

/// Piezas de la reacción [kind] sobre [target] (pies del objetivo, px
/// del mundo) a la hora [at] del paso. [splash]: los demás enemigos
/// (Explosión tóxica); [jumpTo]: el enemigo al que salta el
/// Cortocircuito.
List<ReactionFx> planReactionFx(
  ReactionKind kind, {
  required Offset target,
  int at = 0,
  List<Offset> splash = const [],
  Offset? jumpTo,
}) {
  final look = reactionLook(kind);
  final head = Offset(target.dx, target.dy - 10);
  final out = <ReactionFx>[
    ReactionFx(ReactionPart.banner, look,
        x: target.dx, y: target.dy + bannerDy, delayMs: at),
  ];
  if (look.ring) {
    out.add(ReactionFx(ReactionPart.ring, look,
        x: head.dx, y: head.dy, delayMs: at, big: look.bigRing));
  }
  if (look.bigRing) {
    for (var i = 0; i < splash.length; i++) {
      out.add(ReactionFx(ReactionPart.ring, look,
          x: splash[i].dx,
          y: splash[i].dy - 10,
          delayMs: ReactionTiming.splashAt(at, i)));
    }
  }
  if (look.zap) {
    if (kind == ReactionKind.cortocircuito) {
      if (jumpTo == null) return out;
      out.add(ReactionFx(ReactionPart.zap, look,
          x: head.dx,
          y: head.dy,
          tx: jumpTo.dx,
          ty: jumpTo.dy - 10,
          delayMs: at,
          seed: 7));
    } else {
      // Electrocución: dos rayos cortos que cruzan al objetivo.
      out.add(ReactionFx(ReactionPart.zap, look,
          x: head.dx - 12,
          y: head.dy - 14,
          tx: head.dx + 6,
          ty: head.dy + 8,
          delayMs: at,
          seed: 3));
      out.add(ReactionFx(ReactionPart.zap, look,
          x: head.dx + 12,
          y: head.dy - 12,
          tx: head.dx - 4,
          ty: head.dy + 10,
          delayMs: at + 40,
          seed: 5));
    }
  }
  return out;
}

/// Ajustes efectivos que respeta el dibujo (los de `SceneOptions`).
class ReactionFxOptions {
  const ReactionFxOptions(
      {this.still = false, this.flash = 1, this.density = 1});

  /// REDUCIR MOVIMIENTO: sin rebote de entrada, sin subir, sin titilar.
  final bool still;

  /// `flashFactor` (0..1): el golpe blanco del cartel.
  final double flash;

  /// PARTÍCULAS (0.3 / 0.6 / 1): chispas del rayo y del anillo.
  final double density;
}

/// Dibuja las piezas. Puro sobre un [Canvas]; sin estado.
abstract final class ReactionFxPainter {
  static final _fill = Paint()..isAntiAlias = false;
  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square
    ..isAntiAlias = false;

  /// Anillo o rayo de edad [age] ms (px del mundo).
  static void paintWorld(Canvas c, ReactionFx f, double age,
      {ReactionFxOptions o = const ReactionFxOptions()}) {
    if (age < 0 || age >= f.durationMs) return;
    switch (f.part) {
      case ReactionPart.ring:
        _ring(c, f, age, o);
      case ReactionPart.zap:
        _zap(c, f, age, o);
      case ReactionPart.banner:
        break;
    }
  }

  /// Alfa del cartel a la edad [age].
  static double bannerAlpha(double age) {
    if (age < 0 || age >= ReactionTiming.bannerMs) return 0;
    final left = ReactionTiming.bannerMs - age;
    return left < ReactionTiming.fadeMs ? left / ReactionTiming.fadeMs : 1;
  }

  /// Escala del cartel (entra grande y se asienta; quieta con [still]).
  static double bannerScale(double age, {bool still = false}) {
    if (still) return 1;
    final q = (age / ReactionTiming.popMs).clamp(0.0, 1.0);
    return 1 + 0.5 * (1 - q) * (1 - q);
  }

  /// Cartel centrado en [at] (px de pantalla, la línea base del texto),
  /// [u] = unidad de las etiquetas. Banda negra con franjas del estado
  /// consumido y el texto del color de la reacción con contorno.
  static void paintBanner(
      Canvas c, ReactionFx f, Offset at, double age, double u,
      {ReactionFxOptions o = const ReactionFxOptions()}) {
    final alpha = bannerAlpha(age);
    if (alpha <= 0) return;
    final look = f.look;
    final size = bannerTextU * u;
    final tp = _text(look.banner, look.color, size);
    final ink = _text(look.banner, const Color(0xFF000000), size);
    final w = tp.width + 8 * u, h = size + 6 * u;
    final rise = o.still ? 0.0 : -(age / ReactionTiming.bannerMs) * 6 * u;
    final k = bannerScale(age, still: o.still);
    if (alpha < 1) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    c.save();
    c.translate(at.dx.roundToDouble(), (at.dy + rise).roundToDouble());
    if (k != 1) c.scale(k);
    final top = -size - 3 * u;
    _fill.color = const Color(0xD9000000);
    c.drawRect(Rect.fromLTWH(-w / 2, top, w, h), _fill);
    _fill.color = look.accent;
    c.drawRect(Rect.fromLTWH(-w / 2, top, w, u), _fill);
    c.drawRect(Rect.fromLTWH(-w / 2, top + h - u, w, u), _fill);
    // Golpe blanco al entrar (DESTELLOS: apagado / suave / normal).
    final hit = (1 - age / 80).clamp(0.0, 1.0) * o.flash;
    if (hit > 0) {
      _fill.color = fxWhite.withValues(alpha: 0.55 * hit);
      c.drawRect(Rect.fromLTWH(-w / 2, top, w, h), _fill);
    }
    final x = (-tp.width / 2).roundToDouble();
    final y = (-tp.computeDistanceToActualBaseline(TextBaseline.alphabetic))
        .roundToDouble();
    final d = (size / 8).roundToDouble().clamp(1.0, 4.0);
    for (final off in [Offset(-d, 0), Offset(d, 0), Offset(0, -d), Offset(0, d)]) {
      ink.paint(c, Offset(x, y) + off);
    }
    tp.paint(c, Offset(x, y));
    c.restore();
    if (alpha < 1) c.restore();
  }

  static final _texts = <(String, int, double), TextPainter>{};

  static TextPainter _text(String s, Color color, double size) {
    if (_texts.length > 64) _texts.clear();
    return _texts.putIfAbsent((s, color.toARGB32(), size), () {
      return TextPainter(
        text: TextSpan(
          text: retroText(s),
          style: TextStyle(
              fontFamily: RetroType.pixelFamily,
              fontSize: size,
              color: color,
              height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Ancho del texto del cartel de [kind] en [u] (para el test / la
  /// ubicación sin pisar etiquetas).
  static double bannerWidth(ReactionKind kind, double u) =>
      _text(reactionBanner(kind), fxWhite, bannerTextU * u).width + 8 * u;

  static void _ring(Canvas c, ReactionFx f, double age, ReactionFxOptions o) {
    final p = (age / ReactionTiming.ringMs).clamp(0.0, 1.0);
    final max = f.big ? 26.0 : 14.0;
    // Quieto: aparece ya abierto y se apaga.
    final r = o.still ? max : 4 + (max - 4) * (1 - (1 - p) * (1 - p));
    final a = (1 - p) * 0.9;
    _line
      ..color = f.look.color.withValues(alpha: a)
      ..strokeWidth = f.big ? 3 : 2;
    c.drawCircle(Offset(f.x, f.y), r.roundToDouble(), _line);
    _line
      ..color = f.look.accent.withValues(alpha: a * 0.7)
      ..strokeWidth = 1;
    c.drawCircle(Offset(f.x, f.y), (r * 0.6).roundToDouble(), _line);
    // Gotas de la salpicadura (PARTÍCULAS).
    final n = scaledCount(f.big ? 12 : 6, o.density);
    for (var i = 0; i < n; i++) {
      final ang = i / n * math.pi * 2 + f.seed;
      final q = Offset(f.x + math.cos(ang) * r, f.y + math.sin(ang) * r * 0.8);
      _fill.color = (i.isEven ? f.look.color : f.look.accent)
          .withValues(alpha: a);
      c.drawRect(
          Rect.fromCenter(
              center: Offset(q.dx.roundToDouble(), q.dy.roundToDouble()),
              width: 2,
              height: 2),
          _fill);
    }
  }

  /// Puntos del rayo quebrado de 6 tramos; cambia cada 40 ms (fijo con
  /// [still]).
  static List<Offset> zapPoints(ReactionFx f, double age, {bool still = false}) {
    final frame = still ? 0 : (age / 40).floor();
    final rnd = math.Random(f.seed * 31 + frame);
    final a = Offset(f.x, f.y), b = Offset(f.tx, f.ty);
    final d = b - a;
    final len = d.distance;
    final n = len == 0 ? Offset.zero : Offset(-d.dy / len, d.dx / len);
    final amp = math.min(6.0, math.max(2.0, len * 0.12));
    return [
      for (var i = 0; i <= 6; i++)
        if (i == 0 || i == 6)
          Offset.lerp(a, b, i / 6)!
        else
          Offset.lerp(a, b, i / 6)! + n * ((rnd.nextDouble() * 2 - 1) * amp),
    ];
  }

  static void _zap(Canvas c, ReactionFx f, double age, ReactionFxOptions o) {
    final p = age / ReactionTiming.zapMs;
    // Llega al destino en el primer 40% y se apaga desde el 60%.
    final grow = (p / 0.4).clamp(0.0, 1.0);
    final a = p < 0.6 ? 1.0 : (1 - (p - 0.6) / 0.4).clamp(0.0, 1.0);
    final pts = zapPoints(f, age, still: o.still);
    final upto = (grow * (pts.length - 1)).ceil();
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i <= upto && i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    _line
      ..color = f.look.color.withValues(alpha: a)
      ..strokeWidth = 2.5;
    c.drawPath(path, _line);
    _line
      ..color = fxWhite.withValues(alpha: a)
      ..strokeWidth = 1;
    c.drawPath(path, _line);
    // Chispas en la punta (PARTÍCULAS).
    final tip = pts[math.min(upto, pts.length - 1)];
    final n = scaledCount(4, o.density);
    for (var i = 0; i < n; i++) {
      final ang = i / n * math.pi * 2 + (o.still ? 0 : age / 60);
      _fill.color = (i.isEven ? fxWhite : f.look.color).withValues(alpha: a);
      c.drawRect(
          Rect.fromCenter(
              center: Offset((tip.dx + math.cos(ang) * 4).roundToDouble(),
                  (tip.dy + math.sin(ang) * 4).roundToDouble()),
              width: 2,
              height: 2),
          _fill);
    }
  }
}
