import 'dart:math' as math;
import 'dart:ui';

import '../../../../core/settings/graphics.dart';
import '../../../../game_engine/models/battle_event.dart';
import 'battle_fx.dart';
import 'fx_style.dart';

/// Saltos visibles: rebote (`SkillDef.bounces`), atraviesa (`pierce`) y
/// ráfaga (`hits`). Ver docs/specs/battle_presentation.md § "Saltos".
///
/// El motor emite los golpes en orden (primario, ráfaga, atraviesa,
/// rebotes) y marca cada uno en el [DamageEvent] (`hitIndex`,
/// `pierced`, `chainFrom`). [ChainPlanner] los pone en fila: cada golpe
/// cae cuando le llega el proyectil, no todos a la vez.
abstract final class ChainTiming {
  /// Vuelo de un salto de rebote (de un enemigo al siguiente).
  static const hopMs = 140;

  /// Vuelo de la estela de atraviesa hasta el siguiente de la fila.
  static const pierceMs = 90;

  /// Separación entre golpes de una ráfaga sobre el mismo objetivo.
  static const multiHitMs = 90;

  /// Tope de todo lo encadenado después del golpe primario.
  static const maxMs = 600;

  /// La estela de atraviesa queda visible (se apaga) hasta acá.
  static const streakMs = 220;

  /// Cada número de una ráfaga sube esto más arriba que el anterior.
  static const multiHitDy = -7.0;

  /// Golpe [i] (1, 2, ...) de una ráfaga de [hits] golpes: los pasos se
  /// achican para no pasar de [maxMs].
  static int multiHitAt(int base, int i, int hits) {
    final step = hits <= 1
        ? multiHitMs
        : math.min(multiHitMs, maxMs ~/ math.max(1, hits - 1));
    return base + i * step;
  }
}

/// Dónde y cuándo cae un golpe encadenado, y lo que hay que dibujar.
class ChainPlacement {
  const ChainPlacement(this.delayMs, this.fx, {this.dy = 0});

  /// Hora del golpe (número, tajo y destello) en el paso.
  final int delayMs;

  /// Corrimiento vertical del número (ráfaga).
  final double dy;

  /// Proyectil / estela / contador `×N` del golpe.
  final List<BattleFx> fx;
}

/// Ordena los golpes encadenados de UNA acción. Puro (sin reloj).
class ChainPlanner {
  ChainPlanner({this.hits = 1});

  /// `SkillDef.hits` de la habilidad (para repartir la ráfaga).
  final int hits;

  String? _primary;
  var _base = 0;

  /// Hora del último golpe encadenado (de ahí sale el siguiente).
  var _cursor = 0;
  var _hops = 0;
  Offset? _pierceAt;

  /// Golpes encadenados planeados (para tests).
  int get links => _hops;

  /// El golpe primario a [id] cae en [dl]: de ahí arranca la cadena.
  void primaryHit(String id, int dl) {
    if (_primary != null) return;
    _primary = id;
    _base = dl;
    _cursor = dl;
  }

  /// `null` si [e] es un golpe común (lo maneja `hitDelay`).
  ChainPlacement? place(
    DamageEvent e,
    Offset Function(String id) position, {
    Color color = fxWhite,
    FxElement el = FxElement.phys,
    String? weapon,
  }) {
    final primary = _primary;
    if (primary == null) return null;
    final cap = _base + ChainTiming.maxMs;
    if (e.hitIndex > 0) {
      final dl = math.min(cap, ChainTiming.multiHitAt(_base, e.hitIndex, hits));
      _cursor = math.max(_cursor, dl);
      return ChainPlacement(dl, const [],
          dy: ChainTiming.multiHitDy * math.min(e.hitIndex, 4));
    }
    final from = e.pierced
        ? (_pierceAt ?? position(primary))
        : (e.chainFrom == null ? null : position(e.chainFrom!));
    if (from == null) return null;
    final to = position(e.targetId);
    final fly = e.pierced ? ChainTiming.pierceMs : ChainTiming.hopMs;
    final start = math.min(_cursor, cap - fly);
    final dl = start + fly;
    _cursor = dl;
    _hops++;
    if (e.pierced) _pierceAt = to;
    return ChainPlacement(dl, [
      BattleFx(e.pierced ? FxKind.streak : FxKind.hop,
          x: from.dx,
          y: from.dy - 10,
          tx: to.dx,
          ty: to.dy - 10,
          color: color,
          el: el,
          delayMs: start,
          weapon: weapon),
      // Contador: ×2 al segundo enemigo, ×3 al tercero...
      BattleFx(FxKind.txt,
          x: to.dx,
          y: to.dy - 40,
          text: '×${_hops + 1}',
          color: chainCounterColor,
          delayMs: dl),
    ]);
  }
}

/// Color del contador `×N`.
const chainCounterColor = Color(0xFFFFD166);

/// Cómo se ve el proyectil de un salto.
enum HopStyle { dagger, arrow, bolt }

/// Daga que gira (dagas), flecha (arco, ballesta, rifle) o rayo de
/// energía (magia / el resto).
HopStyle hopStyleFor(String? weapon, FxElement el) {
  if (weapon == 'dagas') return HopStyle.dagger;
  if (el == FxElement.phys &&
      (weapon == 'arco' || weapon == 'ballesta' || weapon == 'rifle')) {
    return HopStyle.arrow;
  }
  return el == FxElement.phys && weapon != null
      ? HopStyle.dagger
      : HopStyle.bolt;
}

/// Duración de los efectos de saltos (`BattleFx.durationMs`).
int chainFxMs(FxKind k) =>
    k == FxKind.streak ? ChainTiming.streakMs : ChainTiming.hopMs;

/// Dibuja un `hop` o un `streak` de edad [age] ms (px del mundo).
/// [still]: "Reducir movimiento" (sin giro ni estela ondulante).
abstract final class ChainFxPainter {
  static final _fill = Paint()..isAntiAlias = false;
  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square
    ..isAntiAlias = false;

  static void paint(Canvas c, BattleFx f, double age,
      {bool still = false, double density = 1}) {
    if (age < 0 || age >= chainFxMs(f.kind)) return;
    if (f.kind == FxKind.streak) {
      _streak(c, f, age);
    } else {
      _hop(c, f, age, still: still, density: density);
    }
  }

  /// Punto del vuelo en [s] (0..1): un arco que se nota aunque los
  /// enemigos estén cerca (alto 14–28 px según la distancia).
  static Offset _at(BattleFx f, double s) {
    final dist = Offset(f.tx - f.x, f.ty - f.y).distance;
    final lift = (dist * 0.5).clamp(14.0, 28.0);
    return Offset(f.x + (f.tx - f.x) * s,
        f.y + (f.ty - f.y) * s - math.sin(s * math.pi) * lift);
  }

  static void _hop(Canvas c, BattleFx f, double age,
      {required bool still, required double density}) {
    final s = (age / ChainTiming.hopMs).clamp(0.0, 1.0);
    final style = hopStyleFor(f.weapon, f.el);
    // Estela del color del elemento.
    final n = scaledCount(8, density);
    for (var i = n; i >= 1; i--) {
      final q = math.max(0.0, s - i * 0.06);
      final p = _at(f, q);
      final a = (1 - i / (n + 1)) * 0.75;
      _fill.color = f.color.withValues(alpha: a);
      final r = style == HopStyle.bolt ? 2.0 : 1.0;
      c.drawRect(
          Rect.fromCenter(
              center: Offset(p.dx.roundToDouble(), p.dy.roundToDouble()),
              width: r * 2,
              height: r * 2),
          _fill);
    }
    final p = _at(f, s);
    final d = _at(f, math.min(1, s + 0.05)) - _at(f, math.max(0, s - 0.05));
    final ang = math.atan2(d.dy, d.dx);
    c.save();
    c.translate(p.dx.roundToDouble(), p.dy.roundToDouble());
    switch (style) {
      case HopStyle.dagger:
        // Gira 2 vueltas por salto.
        c.rotate(still ? ang : age / ChainTiming.hopMs * math.pi * 4);
        _fill.color = const Color(0xFF2D3436);
        c.drawRect(const Rect.fromLTWH(-2, -9, 4, 15), _fill);
        _fill.color = const Color(0xFFF5F6FA);
        c.drawRect(const Rect.fromLTWH(-1, -8, 2, 9), _fill);
        _fill.color = const Color(0xFF6E4A2A);
        c.drawRect(const Rect.fromLTWH(-1, 3, 2, 3), _fill);
        _fill.color = f.color;
        c.drawRect(const Rect.fromLTWH(-4, 1, 8, 2), _fill);
      case HopStyle.arrow:
        c.rotate(ang);
        _line
          ..color = const Color(0xFFDFE6E9)
          ..strokeWidth = 1.5;
        c.drawLine(const Offset(-8, 0), Offset.zero, _line);
        _fill.color = f.color;
        c.drawRect(const Rect.fromLTWH(-1, -1, 3, 2), _fill);
        _line
          ..color = f.color
          ..strokeWidth = 1;
        c.drawLine(const Offset(-8, 0), const Offset(-10, -2), _line);
        c.drawLine(const Offset(-8, 0), const Offset(-10, 2), _line);
      case HopStyle.bolt:
        final k = still ? 1.0 : 0.8 + 0.2 * math.sin(age / 18);
        _fill.color = f.color.withValues(alpha: 0.45);
        c.drawRect(
            Rect.fromCenter(center: Offset.zero, width: 9 * k, height: 9 * k),
            _fill);
        _fill.color = fxWhite;
        c.drawRect(const Rect.fromLTWH(-2, -2, 4, 4), _fill);
    }
    c.restore();
  }

  static void _streak(Canvas c, BattleFx f, double age) {
    final grow = (age / ChainTiming.pierceMs).clamp(0.0, 1.0);
    final fade = age <= ChainTiming.pierceMs
        ? 1.0
        : 1 -
            (age - ChainTiming.pierceMs) /
                (ChainTiming.streakMs - ChainTiming.pierceMs);
    final a = Offset(f.x, f.y), b = Offset(f.tx, f.ty);
    final head = Offset.lerp(a, b, grow)!;
    _line
      ..color = f.color.withValues(alpha: 0.4 * fade)
      ..strokeWidth = 5;
    c.drawLine(a, head, _line);
    _line
      ..color = fxWhite.withValues(alpha: 0.9 * fade)
      ..strokeWidth = 1.5;
    c.drawLine(a, head, _line);
    if (grow < 1) {
      _fill.color = fxWhite;
      c.drawRect(Rect.fromCenter(center: head, width: 4, height: 4), _fill);
    }
  }
}
