import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import '../../../../core/settings/graphics.dart';
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
// ULT enemigas.
const _acid = ElementFx([
  Color(0xFF7BED9F),
  Color(0xFF20BF6B),
  Color(0xFFBADC58),
], 14, 70, 220, 0.6, ParticleShape.square);
const _webBits = ElementFx([
  Color(0xFFEDEFF5),
  Color(0xFFDCDDE1),
  Color(0xFF9B59B6),
], 10, 60, 120, 0.7, ParticleShape.square);
const _frostBits = ElementFx([
  Color(0xFFF4FDFF),
  Color(0xFF9FE3F0),
  Color(0xFF74B9FF),
], 12, 70, 60, 0.6, ParticleShape.shard);
const _voidFx = ElementFx([
  Color(0xFF6C5CE7),
  Color(0xFFD63031),
  Color(0xFF2D1B4E),
  Color(0xFFFF7B29),
], 14, 60, 0, 0.6, ParticleShape.square);

// v0.3.
const _echoBits = ElementFx([
  Color(0xFF7FF3FF),
  Color(0xFFE8FFFF),
  Color(0xFFB48CFF),
], 10, 70, -20, 0.7, ParticleShape.square);
const _magma = ElementFx([
  Color(0xFFFF7B29),
  Color(0xFFFFD166),
  Color(0xFFFF4500),
  Color(0xFF3B3B3B),
], 14, 110, 260, 0.7, ParticleShape.square);
const _wisps = ElementFx([
  Color(0xFFB8C6FF),
  Color(0xFFE8F6FF),
  Color(0xFF6C7BA8),
], 10, 50, -40, 0.9, ParticleShape.square);
/// Diluvio Ácido: la nube revienta sobre el grupo.
const _acidCloudAt = 1150;
Offset _acidCloud(UltStage st) =>
    Offset(st.centroid.dx, _topOf(st.targets, st.centroid.dy) - 42);

/// El `y` más alto (menor) de [l].
double _topOf(List<Offset> l, double fallback) =>
    l.isEmpty ? fallback : l.map((p) => p.dy).reduce(math.min);

/// Fin de las Eras: el vórtice arriba del lanzador, que en la descarga
/// viaja sobre el grupo.
Offset _vortexAt(UltCinematic u, double a, UltStage st) {
  final s = u.script;
  // Se forma delante del lanzador y viaja sobre el grupo.
  final home = st.caster.translate(st.dir * 30, -24);
  final over = Offset(st.centroid.dx, _topOf(st.targets, st.centroid.dy) - 30);
  final q = ((a - s.buildMs) / 300).clamp(0.0, 1.0);
  return Offset.lerp(home, over, q * q * (3 - 2 * q))!;
}

/// Lluvia de Lanzas: cuándo salen las lanzas al cielo.
const _spearHurlAt = 520;

/// Dónde se clava la lanza decorativa [slot] (alrededor de los objetivos).
Offset _spearLand(UltStage st, int slot) {
  final g = st.targets[slot % st.targets.length];
  final dx = ((slot * 37) % 41) - 20.0;
  final dy = ((slot * 23) % 17) - 8.0;
  return g.translate(dx, dy);
}

/// Tormenta Arcana: dónde cae el rayo [slot].
Offset _stormStrike(UltStage st, int slot) {
  final g = st.targets[slot % st.targets.length];
  final dx = ((slot * 29) % 33) - 16.0;
  final dy = ((slot * 13) % 11) - 5.0;
  return g.translate(dx, dy);
}

/// Andanada: virotes chicos antes del grande y cuándo pega el [k].
const _volleySmall = 4;
int _volleyHit(UltScript s, int k) => s.buildMs + 230 + k * 60;

/// Disparos (partículas, sacudidas, hit-stop) y dibujo en el mundo de
/// cada ULT. Diseño en docs/specs/battle_presentation.md § "Ultimates".
abstract final class UltDirector {
  /// Multiplicador de las motas "de lluvia" que dibuja la cinemática
  /// (ajuste PARTÍCULAS; lo pone el pintor de la escena en cada frame).
  static double density = 1;

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
        UltStyle.acidFlood => FxElement.poison,
        UltStyle.endGear => FxElement.freeze,
        UltStyle.endOfEras => FxElement.burn,
        UltStyle.eliteFury => FxElement.burn,
        UltStyle.venomNest => FxElement.poison,
        UltStyle.glacialBreath => FxElement.freeze,
        UltStyle.hollowJudgment => FxElement.arcane,
        UltStyle.echoChorus => FxElement.arcane,
        UltStyle.totalEruption => FxElement.burn,
        UltStyle.eternalLament => FxElement.freeze,
        UltStyle.voidCollapse => FxElement.arcane,
        UltStyle.spearRain => FxElement.phys,
        UltStyle.arcaneStorm => FxElement.arcane,
        UltStyle.volley => FxElement.phys,
        UltStyle.thousandCuts => FxElement.phys,
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
        final cuts = s.style == UltStyle.thousandCuts;
        p.burst(g.dx, g.dy - 10, FxElement.phys, cuts ? 1 : 2);
        if (cuts) p.burstWith(_sparks, g.dx, g.dy - 10, 0.8);
        if (!u.skipped) p.addShake(cuts ? 3 : 5);
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
      case UltStyle.acidFlood:
        // El limo se hincha y escupe la bola de ácido al cielo.
        if (a >= s.buildMs + 40 && once('spit')) {
          p.burst(c.dx, c.dy - 20, FxElement.poison, 2.5);
          if (!u.skipped) p.addShake(4);
        }
        // La nube revienta sobre el grupo.
        if (a >= _acidCloudAt && once('cloud') && n > 0) {
          final cl = _acidCloud(st);
          p.burst(cl.dx, cl.dy, FxElement.poison, 3);
        }
      case UltStyle.endGear:
        if (a < s.buildMs) {
          final slot = (a / 100).floor();
          if (once('tick$slot') && !u.skipped) p.addShake(0.8);
        }
        // Onda de tiempo que retrasa a todo el grupo.
        if (a >= s.impactMs + 160 && once('ripple')) {
          for (final q in st.party) {
            p.burst(q.dx, q.dy - 10, FxElement.freeze, 0.9);
          }
        }
      case UltStyle.endOfEras:
        if (a < s.buildMs) {
          final slot = (a / 140).floor();
          if (once('suck$slot')) {
            final v = _vortexAt(u, a, st);
            p.burstWith(_voidFx, v.dx, v.dy, 0.5);
            if (!u.skipped) p.addShake(1 + a / s.buildMs * 1.5);
          }
        }
      case UltStyle.eliteFury:
        if (a >= s.buildMs && once('dash')) {
          p.burst(c.dx, c.dy - 8, FxElement.burn, 1.5);
          if (!u.skipped) p.addShake(3);
        }
      case UltStyle.venomNest:
        // Escupe la red al cielo.
        if (a >= s.buildMs + 40 && once('net')) {
          p.burst(c.dx, c.dy - 18, FxElement.poison, 2);
          p.burstWith(_webBits, c.dx, c.dy - 18, 1.2);
          if (!u.skipped) p.addShake(4);
        }
      case UltStyle.glacialBreath:
        if (a < s.buildMs) {
          final slot = (a / 110).floor();
          if (once('chill$slot')) {
            p.burstWith(_frostBits, c.dx + st.dir * 14, c.dy - 22, 0.4);
            if (!u.skipped) p.addShake(0.6 + a / s.buildMs);
          }
        }
        // Chorro de aliento: escarcha a lo largo del cono.
        if (a >= s.buildMs && a < s.impactMs + 200) {
          final slot = (a / 70).floor();
          if (once('breath$slot') && n > 0) {
            final g = st.targets[slot % n];
            final q = ((a - s.buildMs) / 420).clamp(0.0, 1.0);
            final o = Offset.lerp(c.translate(st.dir * 14, -22), g.translate(0, -10), q)!;
            p.burstWith(_frostBits, o.dx, o.dy, 0.5);
          }
        }
      case UltStyle.echoChorus:
        // Cada eco canta: ondas que salen del lanzador.
        if (a < s.buildMs) {
          final slot = (a / 200).floor();
          if (once('note$slot')) {
            p.burstWith(_echoBits, c.dx + st.dir * 10, c.dy - 22, 0.5);
            if (!u.skipped) p.addShake(0.8);
          }
        }
      case UltStyle.totalEruption:
        if (a < s.buildMs) {
          final slot = (a / 120).floor();
          if (once('rumble$slot')) {
            p.burstWith(_magma, c.dx + (slot.isEven ? -16 : 16), c.dy, 0.4);
            if (!u.skipped) p.addShake(1 + a / s.buildMs * 2);
          }
        }
      case UltStyle.eternalLament:
        if (a < s.buildMs) {
          final slot = (a / 140).floor();
          if (once('wail$slot')) {
            p.burstWith(_wisps, c.dx, c.dy - 24, 0.5);
            if (!u.skipped) p.addShake(0.6);
          }
        }
      case UltStyle.voidCollapse:
        if (a < s.buildMs) {
          final slot = (a / 130).floor();
          if (once('pull$slot')) {
            final v = _voidHole(u, a, st);
            p.burstWith(_voidFx, v.dx, v.dy, 0.5);
            if (!u.skipped) p.addShake(1 + a / s.buildMs * 2);
          }
        }
        if (a >= s.impactMs - 40 && once('collapse') && !u.skipped) {
          p.addShake(6);
        }
      case UltStyle.hollowJudgment:
        // La espada fantasma aparece sobre el objetivo.
        if (a >= s.buildMs + 120 && once('summon') && n > 0) {
          final g = st.targets.first;
          p.burst(g.dx, g.dy - 60, FxElement.arcane, 1.5);
          if (!u.skipped) p.addShake(3);
        }
      case UltStyle.spearRain:
        // Lanza las lanzas al cielo y empiezan a clavarse alrededor.
        if (a >= _spearHurlAt && once('hurl')) {
          p.burstWith(_sparks, c.dx, c.dy - 20, 1.2);
          if (!u.skipped) p.addShake(3);
        }
        if (a >= s.buildMs + 150 && a < s.returnAt - 150 && n > 0) {
          final slot = (a / 90).floor();
          if (once('stake$slot')) {
            final g = _spearLand(st, slot);
            p.burstWith(_dust, g.dx, g.dy, 0.35);
            if (!u.skipped) p.addShake(1.5);
          }
        }
      case UltStyle.arcaneStorm:
        // Rayos arcanos que caen sin parar alrededor de los objetivos.
        if (a >= s.buildMs + 120 && a < s.returnAt - 120 && n > 0) {
          final slot = (a / 90).floor();
          if (once('zap$slot')) {
            final g = _stormStrike(st, slot);
            p.burst(g.dx, g.dy - 4, FxElement.arcane, 0.5);
            if (!u.skipped) p.addShake(1.5);
          }
        }
      case UltStyle.volley:
        if (a >= s.buildMs + 50 && once('fire')) {
          p.burst(c.dx + st.dir * 12, c.dy - 9, FxElement.phys, 2);
          p.burstWith(_sparks, c.dx + st.dir * 12, c.dy - 9, 1.5);
          if (!u.skipped) p.addShake(6);
        }
        // Virotes de la andanada que llegan antes del grande.
        for (var k = 0; k < _volleySmall; k++) {
          if (n > 0 && a >= _volleyHit(s, k) && once('bolt$k')) {
            final g = st.targets.first;
            p.burstWith(_sparks, g.dx, g.dy - 10, 1);
            if (!u.skipped) p.addShake(3);
          }
        }
      case UltStyle.thousandCuts:
        if (a >= s.buildMs && once('dash')) {
          p.burstWith(_sparks, c.dx, c.dy - 8, 1.2);
          if (!u.skipped) p.addShake(2);
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
        case UltStyle.acidFlood:
          p.burst(g.dx, g.dy - 6, FxElement.poison, 3.5);
          p.burstWith(_acid, g.dx, g.dy - 2, 1.4);
        case UltStyle.endGear:
          p.burst(g.dx, g.dy - 10, FxElement.freeze, 4);
          p.burstWith(_debris, g.dx, g.dy - 4, 0.8);
          p.burstWith(_sparks, g.dx, g.dy - 10, 1.5);
        case UltStyle.endOfEras:
          p.burst(g.dx, g.dy - 8, FxElement.burn, 4);
          p.burstWith(_voidFx, g.dx, g.dy - 14, 1.2);
          p.burst(g.dx, g.dy - 10, FxElement.arcane, 1.5);
        case UltStyle.eliteFury:
          p.burst(g.dx, g.dy - 10, FxElement.phys, 4);
          p.burst(g.dx, g.dy - 10, FxElement.burn, 2);
          p.burstWith(_sparks, g.dx, g.dy - 10, 1.5);
        case UltStyle.venomNest:
          p.burst(g.dx, g.dy - 6, FxElement.poison, 3.5);
          p.burstWith(_acid, g.dx, g.dy - 2, 1.2);
          p.burstWith(_webBits, g.dx, g.dy - 10, 1);
        case UltStyle.glacialBreath:
          p.burst(g.dx, g.dy - 10, FxElement.freeze, 4);
          p.burstWith(_frostBits, g.dx, g.dy - 8, 1.6);
          p.burstWith(_sparks, g.dx, g.dy - 10, 0.8);
        case UltStyle.echoChorus:
          p.burst(g.dx, g.dy - 10, FxElement.arcane, 3.5);
          p.burstWith(_echoBits, g.dx, g.dy - 12, 1.6);
        case UltStyle.totalEruption:
          p.burst(g.dx, g.dy - 6, FxElement.burn, 4);
          p.burstWith(_magma, g.dx, g.dy - 4, 2);
          p.burstWith(_debris, g.dx, g.dy - 2, 0.8);
        case UltStyle.eternalLament:
          p.burst(g.dx, g.dy - 10, FxElement.freeze, 3.5);
          p.burstWith(_wisps, g.dx, g.dy - 8, 1.6);
        case UltStyle.voidCollapse:
          p.burstWith(_voidFx, g.dx, g.dy - 12, 2);
          p.burst(g.dx, g.dy - 10, FxElement.arcane, 3);
          p.burstWith(_sparks, g.dx, g.dy - 10, 1.2);
        case UltStyle.hollowJudgment:
          p.burst(g.dx, g.dy - 10, FxElement.arcane, 4);
          p.burst(g.dx, g.dy - 6, FxElement.phys, 3);
          p.burstWith(_dust, g.dx, g.dy, 2);
          p.burstWith(_sparks, g.dx, g.dy - 12, 2);
        case UltStyle.spearRain:
          p.burst(g.dx, g.dy - 8, FxElement.phys, 3);
          p.burstWith(_debris, g.dx, g.dy - 2, 0.8);
          p.burstWith(_dust, g.dx, g.dy, 0.8);
        case UltStyle.arcaneStorm:
          p.burst(g.dx, g.dy - 10, FxElement.arcane, 4);
          p.burstWith(_sparks, g.dx, g.dy - 10, 1.5);
          p.burst(g.dx, g.dy - 10, FxElement.level, 0.5);
        case UltStyle.volley:
          p.burst(g.dx, g.dy - 10, FxElement.phys, 4);
          p.burst(g.dx, g.dy - 8, FxElement.burn, 2);
          p.burstWith(_debris, g.dx, g.dy - 4, 1);
          p.burstWith(_sparks, g.dx, g.dy - 10, 2);
        case UltStyle.thousandCuts:
          p.burst(g.dx, g.dy - 10, FxElement.phys, 4);
          p.burstWith(_sparks, g.dx, g.dy - 10, 2.5);
          p.burst(g.dx, g.dy - 10, FxElement.level, 0.8);
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
      case UltStyle.acidFlood:
        _acidFlood(c, u, a, st, visible, out);
      case UltStyle.endGear:
        _endGear(c, u, a, st, out);
      case UltStyle.endOfEras:
        _endOfEras(c, u, a, st, visible, out);
      case UltStyle.eliteFury:
        _eliteFury(c, u, a, st, visible);
      case UltStyle.venomNest:
        _venomNest(c, u, a, st, visible, out);
      case UltStyle.glacialBreath:
        _glacialBreath(c, u, a, st, visible, out);
      case UltStyle.hollowJudgment:
        _hollowJudgment(c, u, a, st, visible, out);
      case UltStyle.echoChorus:
        _echoChorus(c, u, a, st, visible, out);
      case UltStyle.totalEruption:
        _totalEruption(c, u, a, st, visible, out);
      case UltStyle.eternalLament:
        _eternalLament(c, u, a, st, visible, out);
      case UltStyle.voidCollapse:
        _voidCollapse(c, u, a, st, visible, out);
      case UltStyle.spearRain:
        _spearRain(c, u, a, st, visible, out);
      case UltStyle.arcaneStorm:
        _arcaneStorm(c, u, a, st, visible, out);
      case UltStyle.volley:
        _volley(c, u, a, st, out);
      case UltStyle.thousandCuts:
        _thousandCuts(c, u, a, st, visible);
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

  // ---------------- ULT enemigas ----------------

  /// Diluvio Ácido (Rey Limo): se hincha, escupe una bola de ácido que
  /// revienta en una nube sobre el grupo y llueve ácido; charcos.
  static void _acidFlood(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const green = Color(0xFF7BED9F);
    const dark = Color(0xFF20BF6B);
    const sick = Color(0xFFBADC58);
    _gather(c, o, a, s.buildMs, green);
    // Cielo verdoso.
    final tint = s.darkness(a) * 0.12 * (a < s.buildMs ? _q(a, 150, 500) : 1);
    if (tint > 0) {
      _fill.color = Color.fromRGBO(60, 220, 120, tint);
      c.drawRect(vis, _fill);
    }
    // El limo se hincha (membrana que tiembla) y burbujas que suben.
    if (a < s.buildMs + 80) {
      final g = _ease(_q(a, 0, s.buildMs));
      final wob = math.sin(a / 45) * 2;
      _oval(c, o.translate(0, -16), 18 + 12 * g + wob, 14 + 9 * g - wob,
          _a(green, 0.18 + 0.12 * g));
      _ring(c, o.translate(0, -16), 18 + 12 * g + wob, 14 + 9 * g - wob,
          _a(dark, 0.8), 1);
      for (var k = 0; k < 9; k++) {
        final e = ((a / 600) + _h(k, 4)) % 1.0;
        final x = o.dx + (_h(k, 8) - 0.5) * 40;
        final y = o.dy - 4 - e * 50;
        _ring(c, Offset(x, y), 1.5 + 2 * _h(k, 1), 1.5 + 2 * _h(k, 1),
            _a(sick, 1 - e), 1);
      }
    }
    if (st.targets.isEmpty) return;
    final cloud = _acidCloud(st);
    // Bola de ácido al cielo (de la boca del limo a la nube).
    if (a >= s.buildMs && a < _acidCloudAt) {
      final q = _q(a, s.buildMs, _acidCloudAt - s.buildMs);
      final from = o.translate(0, -24);
      final p = Offset.lerp(from, cloud, q)!.translate(0, -math.sin(q * math.pi) * 40);
      for (var k = 4; k >= 0; k--) {
        _disc(c, p.translate(0, k * 4.0), 7 - k * 1.1, _a(k == 0 ? sick : dark, 1 - k / 5));
      }
      _disc(c, p.translate(-2, -2), 2, _a(const Color(0xFFFFFFFF), 0.8));
    }
    if (a < _acidCloudAt) return;
    // Nube que cubre al grupo.
    final spread = math.max(60.0, st.targets.fold<double>(0, (m, t) => math.max(m, (t.dx - cloud.dx).abs())) * 2 + 40);
    final grow = _ease(_q(a, _acidCloudAt, 200));
    for (var k = 0; k < 7; k++) {
      final x = cloud.dx + (k - 3) / 3 * spread / 2;
      final y = cloud.dy + math.sin(k * 1.7 + a / 300) * 3;
      _oval(c, Offset(x, y), (14 + 6 * _h(k, 2)) * grow, (7 + 3 * _h(k, 5)) * grow,
          _a(k.isEven ? const Color(0xFF145A32) : dark, 0.85 * out));
    }
    // Lluvia de ácido.
    for (var k = 0; k < scaledCount(36, density); k++) {
      final t0 = _acidCloudAt + 40 + (k * 29) % 520;
      final q = (a - t0) / 260;
      if (q < 0 || q > 1) continue;
      final x = cloud.dx + (_h(k, 7) - 0.5) * spread;
      final gy = st.centroid.dy + (_h(k, 3) - 0.5) * 30;
      final y = cloud.dy + 6 + (gy - cloud.dy - 6) * q;
      _line(c, Offset(x, y - 6), Offset(x, y), _a(sick, 0.9), 1.5);
      _fill.color = _a(green, 1);
      c.drawRect(Rect.fromCenter(center: Offset(x, y), width: 2, height: 2), _fill);
    }
    // Charcos y salpicaduras en cada objetivo.
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      if (a < imp) continue;
      final e = _q(a, imp, 400);
      _oval(c, g.translate(0, 1), 10 + 6 * _ease(e), 3 + 2 * _ease(e), _a(dark, 0.7 * out));
      _ring(c, g.translate(0, 1), 10 + 6 * _ease(e), 3 + 2 * _ease(e), _a(sick, 0.9 * out), 1);
      if (e < 1) {
        _ring(c, g.translate(0, -6), 26 * e, 12 * e, _a(green, 1 - e), 2);
      }
    }
  }

  /// Engranaje dentado de radio [r] girado [ang].
  static void _gear(Canvas c, Offset o, double r, double ang, double alpha) {
    const bronze = Color(0xFFE1B12C);
    const dark = Color(0xFF6D4C1F);
    const teeth = 12;
    final path = Path();
    for (var k = 0; k < teeth * 2; k++) {
      final a0 = ang + k * math.pi / teeth;
      final rr = k.isEven ? r : r * 0.8;
      final a1 = a0 + math.pi / teeth;
      final p0 = o + Offset(math.cos(a0), math.sin(a0)) * rr;
      final p1 = o + Offset(math.cos(a1), math.sin(a1)) * rr;
      if (k == 0) {
        path.moveTo(p0.dx, p0.dy);
      } else {
        path.lineTo(p0.dx, p0.dy);
      }
      path.lineTo(p1.dx, p1.dy);
    }
    path.close();
    _fill.color = _a(dark, alpha);
    c.drawPath(path.shift(const Offset(1, 1)), _fill);
    _fill.color = _a(bronze, alpha);
    c.drawPath(path, _fill);
    _disc(c, o, r * 0.55, _a(const Color(0xFF8A6D1F), alpha));
    _ring(c, o, r * 0.55, r * 0.55, _a(const Color(0xFFFFF3B0), alpha * 0.7), 1);
    for (var k = 0; k < 4; k++) {
      final aa = ang * 1.5 + k * math.pi / 2;
      _line(c, o, o + Offset(math.cos(aa), math.sin(aa)) * r * 0.5,
          _a(dark, alpha), 2);
    }
    _disc(c, o, 2.5, _a(const Color(0xFFFFF3B0), alpha));
  }

  /// Engranaje del Fin (Gólem Reloj): un engranaje gigante gira detrás
  /// del gólem, sale rodando y aplasta al objetivo con hielo; una onda de
  /// tiempo retrasa a todo el grupo.
  static void _endGear(
      Canvas c, UltCinematic u, double a, UltStage st, double out) {
    final s = u.script;
    final o = st.caster;
    const ice = Color(0xFF74B9FF);
    const pale = Color(0xFFDFF9FB);
    _gather(c, o, a, s.buildMs, const Color(0xFFE1B12C));
    final home = o.translate(-st.dir * 4, -24);
    if (a < s.buildMs) {
      final g = _ease(_q(a, 0, 300));
      // Gira a los saltos, como un reloj.
      final tick = (a / 100).floor() * math.pi / 24;
      _gear(c, home, 26 * g, tick, 0.95 * g);
      _ring(c, home, 32 * g, 32 * g, _a(pale, 0.35 * g), 1);
      return;
    }
    if (st.targets.isEmpty) return;
    final g = st.targets.first.translate(0, -14);
    final imp = s.impactMs;
    if (a < imp) {
      final q = _q(a, s.buildMs, imp - s.buildMs);
      final p = Offset.lerp(home, g, q * q)!.translate(0, -math.sin(q * math.pi) * 30);
      // Estela de hielo.
      for (var k = 1; k <= 4; k++) {
        final pq = Offset.lerp(home, g, math.max(0, q - k * 0.06) * math.max(0, q - k * 0.06))!
            .translate(0, -math.sin(math.max(0, q - k * 0.06) * math.pi) * 30);
        _disc(c, pq, 18 - k * 3.0, _a(ice, 0.25 / k));
      }
      _gear(c, p, 22, a / 40, 1);
    } else if (a < imp + 300) {
      final e = _q(a, imp, 300);
      _gear(c, g.translate(0, 4 * e), 22 * (1 - e * 0.3), imp / 40, 1 - e);
    }
    if (a >= imp) {
      final e = _q(a, imp, 520);
      // Cristales de hielo que encierran al objetivo.
      for (var k = -3; k <= 3; k++) {
        final h = (26 - k.abs() * 4) * _ease(_q(a, imp, 120)) * out;
        final x = g.dx + k * 5;
        final base = g.dy + 15;
        final path = Path()
          ..moveTo(x - 3, base)
          ..lineTo(x + k * 0.6, base - h)
          ..lineTo(x + 3, base)
          ..close();
        _fill.color = _a(k.isEven ? pale : ice, 0.85 * out);
        c.drawPath(path, _fill);
      }
      if (e < 1) {
        _ring(c, g, 46 * _ease(e), 24 * _ease(e), _a(pale, 1 - e), 2);
      }
      // Onda de tiempo sobre todo el grupo.
      final r = _q(a, imp + 120, 600);
      if (r > 0 && r < 1) {
        for (final q in st.party) {
          for (var k = 0; k < 2; k++) {
            final rr = (r + k * 0.3).clamp(0.0, 1.0);
            _ring(c, q.translate(0, -8), 6 + 18 * rr, 3 + 9 * rr, _a(ice, 0.8 * (1 - rr)), 1);
          }
        }
      }
    }
  }

  /// Fin de las Eras (Devorador): un vórtice traga la luz sobre el
  /// lanzador, viaja sobre el grupo, colapsa y estallan columnas de fuego;
  /// los buffs del grupo se rompen como cristal.
  static void _endOfEras(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    const crimson = Color(0xFFD63031);
    const violet = Color(0xFF6C5CE7);
    const ember = Color(0xFFFF7B29);
    // Cielo rojo que se oscurece.
    final tint = s.darkness(a) * (a < s.buildMs ? 0.2 * _q(a, 100, 700) : 0.2);
    if (tint > 0) {
      _fill.color = Color.fromRGBO(120, 0, 20, tint);
      c.drawRect(vis, _fill);
    }
    final imp = s.impactMs;
    final v = _vortexAt(u, a, st);
    if (a < imp) {
      final grow = _ease(_q(a, 0, s.buildMs));
      final swell = a < s.buildMs ? 1.0 : 1 + 0.9 * _ease(_q(a, s.buildMs, 300));
      final collapse = 1 - _ease(_q(a, imp - 120, 120));
      final r = (10 + 16 * grow) * swell * collapse;
      // Polvo y luz que caen en espiral hacia el vórtice.
      for (var k = 0; k < 16; k++) {
        final f = ((a / 500) + _h(k, 6)) % 1.0;
        final ang = k * 0.9 + a / 220;
        final rr = r + 50 * (1 - f);
        final p = v + Offset(math.cos(ang), math.sin(ang) * 0.5) * rr;
        _fill.color = _a(k.isEven ? ember : violet, f);
        c.drawRect(Rect.fromCenter(center: p, width: 2, height: 2), _fill);
      }
      _disc(c, v, r * 1.25, _a(violet, 0.3));
      for (var k = 0; k < 3; k++) {
        final aa = a / (90 + k * 40) + k;
        _stroke
          ..color = _a(k == 1 ? violet : crimson, 0.9)
          ..strokeWidth = 2;
        c.drawArc(Rect.fromCenter(center: v, width: r * 2.2 + k * 6, height: (r * 2.2 + k * 6) * 0.6),
            aa, 2.2, false, _stroke);
      }
      _disc(c, v, r, const Color(0xFF0B0010));
      _ring(c, v, r, r, _a(crimson, 0.9), 1);
    }
    if (a >= imp - 120 && a < imp + 120) {
      // Destello del colapso.
      final e = _q(a, imp - 120, 240);
      _disc(c, v, 30 * math.sin(e * math.pi), _a(const Color(0xFFFFFFFF), 0.8 * (1 - e)));
    }
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final ti = s.impactFor(i);
      if (a < ti) {
        if (a > s.buildMs + 200) {
          // Grieta incandescente bajo cada objetivo.
          final q = _q(a, s.buildMs + 200, ti - s.buildMs - 200);
          _oval(c, g.translate(0, 1), 4 + 8 * q, 1.5 + 2 * q, _a(ember, 0.5 + 0.4 * math.sin(a / 40).abs()));
        }
        continue;
      }
      final e = _q(a, ti, 700);
      final h = 100 * _ease(_q(a, ti, 120)) * (1 - e * 0.4);
      final w = 16 * (1 - e * 0.5);
      final al = (1 - e) * out;
      final rect = Rect.fromLTRB(g.dx - w / 2, g.dy - h, g.dx + w / 2, g.dy + 2);
      final paint = Paint()
        ..isAntiAlias = false
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
          Color.fromRGBO(214, 48, 49, 0.1 * al),
          Color.fromRGBO(255, 123, 41, 0.95 * al),
        ]);
      c.drawRect(rect, paint);
      _fill.color = _a(const Color(0xFFFFF3B0), al);
      c.drawRect(Rect.fromLTRB(g.dx - w / 6, g.dy - h * 0.7, g.dx + w / 6, g.dy + 2), _fill);
      _ring(c, g.translate(0, 1), w + 26 * e, 4 + 6 * e, _a(crimson, al), 2);
      // Buffs que se rompen: astillas violetas que salen volando.
      for (var k = 0; k < 6; k++) {
        final t = e * 0.9;
        final ang = k * math.pi / 3 + 0.4;
        final p = g.translate(0, -18) + Offset(math.cos(ang), math.sin(ang)) * (6 + 40 * t) + Offset(0, 60 * t * t);
        _fill.color = _a(violet, 1 - e);
        c.drawRect(Rect.fromCenter(center: p, width: 3, height: 2), _fill);
      }
    }
  }

  /// Furia Élite: el élite arde en rojo, se lanza dejando imágenes y
  /// desgarra al objetivo con tres zarpazos (el último, crítico).
  static void _eliteFury(
      Canvas c, UltCinematic u, double a, UltStage st, Rect vis) {
    final s = u.script;
    final o = st.caster;
    const red = Color(0xFFFF4757);
    const ember = Color(0xFFFF9F43);
    _gather(c, o, a, s.buildMs, red);
    if (a < s.buildMs + 100) {
      // Llamas rojas alrededor del cuerpo.
      for (var k = 0; k < 10; k++) {
        final ph = (a / 160 + _h(k, 2)) % 1.0;
        final x = o.dx + (k - 4.5) * 4.5;
        final hgt = 8 + 14 * math.sin(ph * math.pi) * _q(a, 0, 300);
        final path = Path()
          ..moveTo(x - 3, o.dy)
          ..lineTo(x, o.dy - hgt - 10)
          ..lineTo(x + 3, o.dy)
          ..close();
        _fill.color = _a(k.isEven ? red : ember, 0.55);
        c.drawPath(path, _fill);
      }
      // Brillo en los ojos.
      if (a > 480) {
        final q = _q(a, 480, 220);
        _star(c, o.translate(st.dir * 4, -18), 2 + 8 * math.sin(q * math.pi), _a(const Color(0xFFFFFFFF), 1));
        _star(c, o.translate(st.dir * 4, -18), 1 + 4 * math.sin(q * math.pi), red);
      }
    }
    if (st.targets.isEmpty) return;
    final g = st.targets.first.translate(0, -10);
    // Embestida con imágenes.
    if (a >= s.buildMs && a < s.buildMs + 300) {
      final q = _q(a, s.buildMs, 220);
      for (var k = 0; k < 5; k++) {
        final p = Offset.lerp(o.translate(0, -10), g, (q - k * 0.12).clamp(0.0, 1.0))!;
        _oval(c, p, 9, 11, _a(red, 0.45 * (1 - k / 5) * (1 - _q(a, s.buildMs + 200, 100))));
      }
    }
    // Zarpazos: dos previos y el final, enorme.
    final hits = [...s.preHitsMs, s.impactMs];
    for (var k = 0; k < hits.length; k++) {
      final h = hits[k];
      final last = k == hits.length - 1;
      final dur = last ? 360.0 : 200.0;
      if (a < h || a > h + dur) continue;
      final q = _q(a, h, dur);
      final len = (last ? 70.0 : 40.0) * math.min(1.0, q * 5);
      final ang = last ? -0.9 : (k.isEven ? -0.7 : -1.2);
      final d = Offset(math.cos(ang), math.sin(ang));
      final n = Offset(-d.dy, d.dx);
      for (var j = -1; j <= 1; j++) {
        final off = n * (j * (last ? 9.0 : 6.0));
        final w = (last ? 6.0 : 3.0) * (1 - q) + 1;
        _line(c, g + off - d * len / 2, g + off + d * len / 2, _a(red, 0.9 * (1 - q)), w + 2);
        _line(c, g + off - d * len / 2, g + off + d * len / 2, _a(const Color(0xFFFFFFFF), 1 - q * 0.8), w * 0.5);
      }
      if (last) {
        _ring(c, g, 60 * q, 30 * q, _a(red, 1 - q), 3);
      }
    }
  }

  // ---------------- ULT de los jefes v0.2 ----------------

  /// Telaraña radial de radio [r] centrada en [o] (anillos + rayos).
  static void _webDisc(Canvas c, Offset o, double r, double rot, Color col,
      double alpha, {double squash = 1}) {
    if (r <= 1 || alpha <= 0) return;
    const spokes = 8;
    Offset pt(double ang, double rr) =>
        o + Offset(math.cos(ang) * rr, math.sin(ang) * rr * squash);
    for (var k = 0; k < spokes; k++) {
      final ang = rot + k * math.pi * 2 / spokes;
      _line(c, o, pt(ang, r), _a(col, alpha), 1);
    }
    for (final f in [0.3, 0.55, 0.8, 1.0]) {
      final path = Path();
      for (var k = 0; k <= spokes; k++) {
        final ang = rot + k * math.pi * 2 / spokes;
        // Los hilos se comban hacia adentro entre rayos.
        final q = pt(ang, r * f);
        if (k == 0) {
          path.moveTo(q.dx, q.dy);
        } else {
          final mid = pt(ang - math.pi / spokes, r * f * 0.86);
          path.quadraticBezierTo(mid.dx, mid.dy, q.dx, q.dy);
        }
      }
      _stroke
        ..color = _a(col, alpha * 0.85)
        ..strokeWidth = 1;
      c.drawPath(path, _stroke);
    }
  }

  /// Nido Venenoso (Matriarca Araña): hilos que salen de ella y sacos de
  /// huevos que laten; escupe una red enorme que cae sobre todo el grupo
  /// y revienta en veneno.
  static void _venomNest(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const silk = Color(0xFFEDEFF5);
    const purple = Color(0xFF9B59B6);
    const green = Color(0xFF7BED3F);
    _gather(c, o, a, s.buildMs, purple);
    // Bosque que se oscurece en violeta.
    final tint = s.darkness(a) * 0.14 * (a < s.buildMs ? _q(a, 100, 500) : 1);
    if (tint > 0) {
      _fill.color = Color.fromRGBO(70, 20, 90, tint);
      c.drawRect(vis, _fill);
    }
    if (a < s.buildMs + 120) {
      // Hilos tendidos desde la Matriarca hacia arriba y los costados.
      final g = _ease(_q(a, 0, 400));
      for (var k = 0; k < 7; k++) {
        final ang = -math.pi / 2 + (k - 3) * 0.42;
        final end = o.translate(0, -16) +
            Offset(math.cos(ang), math.sin(ang)) * (30 + 50 * g);
        _line(c, o.translate(0, -16), end, _a(silk, 0.55 * g), 1);
      }
      // Sacos de huevos que laten alrededor.
      for (var k = 0; k < 4; k++) {
        final q = o.translate((k - 1.5) * 16, -4 - (k % 2) * 10);
        final r = (3 + 1.5 * math.sin(a / 90 + k)) * g;
        _disc(c, q, r + 1, _a(const Color(0xFF2E1834), 0.9));
        _disc(c, q, r, _a(green, 0.75));
        _disc(c, q.translate(-1, -1), r * 0.35, _a(const Color(0xFFFFFFFF), 0.7));
      }
    }
    if (st.targets.isEmpty) return;
    // Centro de la red sobre el grupo.
    final top = _topOf(st.targets, st.centroid.dy);
    final over = Offset(st.centroid.dx, top - 34);
    final spread = math.max(
        44.0,
        st.targets.fold<double>(0, (m, t) => math.max(m, (t.dy - st.centroid.dy).abs())) +
            30);
    final land = s.impactMs - 40;
    if (a >= s.buildMs && a < land) {
      // La red vuela en arco, girando y abriéndose.
      final q = _q(a, s.buildMs, land - s.buildMs);
      final from = o.translate(0, -20);
      final p = Offset.lerp(from, over, q)!.translate(0, -math.sin(q * math.pi) * 40);
      _webDisc(c, p, 6 + (spread - 6) * _ease(q) * 0.7, a / 160, silk, 0.95,
          squash: 0.8);
    }
    if (a >= land) {
      // Cae y envuelve al grupo; gotea veneno.
      final q = _ease(_q(a, land, 160));
      final ctr = Offset.lerp(over, st.centroid.translate(0, -12), q)!;
      _webDisc(c, ctr, spread * (0.7 + 0.3 * q), 0.4, silk, 0.9 * out,
          squash: 1.2);
      for (var k = 0; k < scaledCount(18, density); k++) {
        final t0 = land + 60 + (k * 37) % 420;
        final dq = (a - t0) / 300;
        if (dq < 0 || dq > 1) continue;
        final x = ctr.dx + (_h(k, 3) - 0.5) * spread * 1.6;
        final y = ctr.dy - spread * 0.4 + dq * spread;
        _fill.color = _a(green, 0.9 * (1 - dq));
        c.drawRect(Rect.fromCenter(center: Offset(x, y), width: 2, height: 3), _fill);
      }
    }
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      if (a < imp) continue;
      final e = _q(a, imp, 420);
      _oval(c, g.translate(0, 1), 9 + 6 * _ease(e), 3 + 2 * _ease(e),
          _a(const Color(0xFF2E7D32), 0.6 * out));
      if (e < 1) {
        _ring(c, g.translate(0, -8), 24 * e, 12 * e, _a(green, 1 - e), 2);
        _ring(c, g.translate(0, -8), 14 * e, 7 * e, _a(purple, 1 - e), 1);
      }
    }
  }

  /// Aliento Glacial (Sierpe de Escarcha): la escarcha se junta en sus
  /// fauces, sopla un cono de hielo sobre todo el grupo y los encierra en
  /// cristales.
  static void _glacialBreath(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const ice = Color(0xFF9FE3F0);
    const pale = Color(0xFFF4FDFF);
    const deep = Color(0xFF2E6FB5);
    final mouth = o.translate(st.dir * 16, -24);
    _gather(c, mouth.translate(0, 10), a, s.buildMs, ice);
    // Niebla fría que cubre la vista.
    final tint = s.darkness(a) * (a < s.buildMs ? 0.18 * _q(a, 100, 700) : 0.18);
    if (tint > 0) {
      _fill.color = Color.fromRGBO(160, 230, 255, tint);
      c.drawRect(vis, _fill);
    }
    if (a < s.buildMs + 60) {
      // Copos que entran en espiral a las fauces y un núcleo que crece.
      final g = _ease(_q(a, 0, s.buildMs));
      for (var k = 0; k < scaledCount(18, density); k++) {
        final f = ((a / 520) + _h(k, 5)) % 1.0;
        final ang = k * 0.7 + a / 260;
        final rr = 8 + 60 * (1 - f);
        final p = mouth + Offset(math.cos(ang), math.sin(ang) * 0.6) * rr;
        _fill.color = _a(k.isEven ? pale : ice, f);
        c.drawRect(Rect.fromCenter(center: p, width: 2, height: 2), _fill);
      }
      _disc(c, mouth, 3 + 6 * g + math.sin(a / 40), _a(ice, 0.5));
      _disc(c, mouth, 2 + 3 * g, _a(pale, 0.95));
    }
    if (st.targets.isEmpty) return;
    // Cono de aliento: de las fauces al grupo.
    if (a >= s.buildMs && a < s.returnAt) {
      final grow = _ease(_q(a, s.buildMs, 260));
      final fade = 1 - _q(a, s.impactMs + 300, 300);
      final far = st.centroid.translate(st.dir * 10, -10);
      final reach = Offset.lerp(mouth, far, grow)!;
      final half = (st.targets.fold<double>(0, (m, t) => math.max(m, (t.dy - st.centroid.dy).abs())) + 18) * grow;
      final cone = Path()
        ..moveTo(mouth.dx, mouth.dy - 3)
        ..lineTo(reach.dx, reach.dy - half)
        ..lineTo(reach.dx + st.dir * 10, reach.dy)
        ..lineTo(reach.dx, reach.dy + half)
        ..lineTo(mouth.dx, mouth.dy + 3)
        ..close();
      _fill.color = _a(ice, 0.35 * fade * out);
      c.drawPath(cone, _fill);
      // Vetas blancas que corren por el cono.
      for (var k = 0; k < 10; k++) {
        final f = ((a / 200) + _h(k, 2)) % 1.0;
        final side = (_h(k, 7) - 0.5) * 2;
        final p0 = Offset.lerp(mouth, reach.translate(0, side * half), f)!;
        final p1 = Offset.lerp(mouth, reach.translate(0, side * half), math.min(1, f + 0.12))!;
        _line(c, p0, p1, _a(pale, 0.9 * fade * out), 1);
      }
    }
    // Cristales que encierran a cada objetivo.
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      if (a < imp) continue;
      final up = _ease(_q(a, imp, 140)) * out;
      for (var k = -2; k <= 2; k++) {
        final hgt = (22 - k.abs() * 5) * up;
        final x = g.dx + k * 4.5;
        final path = Path()
          ..moveTo(x - 2.5, g.dy + 2)
          ..lineTo(x + k * 0.8, g.dy + 2 - hgt)
          ..lineTo(x + 2.5, g.dy + 2)
          ..close();
        _fill.color = _a(k.isEven ? ice : deep, 0.85 * out);
        c.drawPath(path, _fill);
        _line(c, Offset(x, g.dy + 1), Offset(x + k * 0.6, g.dy + 3 - hgt),
            _a(pale, 0.8 * out), 1);
      }
      final e = _q(a, imp, 500);
      if (e < 1) _ring(c, g.translate(0, -6), 30 * _ease(e), 14 * _ease(e), _a(pale, 1 - e), 2);
    }
  }

  /// Juicio Hueco (Caballero Hueco): sus ojos arden en cian, runas giran a
  /// su alrededor; una espada espectral gigante cae sobre el objetivo y
  /// estalla en una cruz de luz.
  static void _hollowJudgment(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const cyan = Color(0xFF6FF7FF);
    const ghost = Color(0xFFD9FBFF);
    const dark = Color(0xFF1B2A3A);
    _gather(c, o, a, s.buildMs, cyan);
    final tint = s.darkness(a) * 0.16;
    if (tint > 0) {
      _fill.color = Color.fromRGBO(10, 30, 50, tint);
      c.drawRect(vis, _fill);
    }
    if (a < s.buildMs + 100) {
      // Runas que giran (cuadrados con cruz) y ojos que arden.
      final g = _ease(_q(a, 0, 300));
      for (var k = 0; k < 6; k++) {
        final ang = a / 300 + k * math.pi / 3;
        final p = o.translate(0, -16) + Offset(math.cos(ang) * 26, math.sin(ang) * 10) * g;
        _fill.color = _a(cyan, 0.8 * g);
        c.drawRect(Rect.fromCenter(center: p, width: 4, height: 4), _fill);
        _fill.color = _a(dark, 0.9 * g);
        c.drawRect(Rect.fromCenter(center: p, width: 2, height: 2), _fill);
      }
      if (a > 450) {
        final q = _q(a, 450, 300);
        _star(c, o.translate(st.dir * 3, -26), 2 + 7 * math.sin(q * math.pi), _a(ghost, 1));
        _star(c, o.translate(st.dir * 3, -26), 1 + 3 * math.sin(q * math.pi), cyan);
      }
    }
    if (st.targets.isEmpty) return;
    final g = st.targets.first;
    final imp = s.impactMs;
    // La espada espectral se forma arriba y cae.
    if (a >= s.buildMs && a < imp + 260) {
      final form = _ease(_q(a, s.buildMs, 260));
      final fall = _q(a, imp - 220, 220);
      final tipY = g.dy - 26 + 24 * fall * fall;
      final alpha = (a < imp ? form : 1 - _q(a, imp, 260)) * out;
      const len = 24.0;
      // Hoja.
      final blade = Path()
        ..moveTo(g.dx, tipY)
        ..lineTo(g.dx - 5, tipY - 8)
        ..lineTo(g.dx - 5, tipY - len)
        ..lineTo(g.dx + 5, tipY - len)
        ..lineTo(g.dx + 5, tipY - 8)
        ..close();
      _fill.color = _a(cyan, 0.45 * alpha);
      c.drawPath(blade, _fill);
      _stroke
        ..color = _a(ghost, 0.95 * alpha)
        ..strokeWidth = 1;
      c.drawPath(blade, _stroke);
      _line(c, Offset(g.dx, tipY - 4), Offset(g.dx, tipY - len + 2), _a(ghost, alpha), 1);
      // Guarda y empuñadura.
      _fill.color = _a(const Color(0xFFB8963E), alpha);
      c.drawRect(Rect.fromLTWH(g.dx - 12, tipY - len - 3, 24, 3), _fill);
      _fill.color = _a(dark, alpha);
      c.drawRect(Rect.fromLTWH(g.dx - 2, tipY - len - 14, 4, 11), _fill);
      _disc(c, Offset(g.dx, tipY - len - 15), 3, _a(cyan, alpha));
      // Estela de la caída.
      if (fall > 0 && a < imp) {
        for (var k = 1; k <= 3; k++) {
          _fill.color = _a(cyan, 0.2 / k * alpha);
          c.drawRect(Rect.fromLTWH(g.dx - 5, tipY - len - k * 10, 10, len), _fill);
        }
      }
    }
    if (a >= imp) {
      // Cruz de luz y onda en el suelo.
      final e = _q(a, imp, 520);
      final w = 90 * _ease(e);
      final al = (1 - e) * out;
      _fill.color = _a(ghost, 0.9 * al);
      c.drawRect(Rect.fromCenter(center: g.translate(0, -10), width: w, height: 3), _fill);
      c.drawRect(Rect.fromCenter(center: g.translate(0, -10), width: 3, height: w * 0.8), _fill);
      _ring(c, g.translate(0, 1), 10 + 50 * e, 4 + 14 * e, _a(cyan, al), 2);
      // Grietas en el piso.
      for (var k = 0; k < 6; k++) {
        final ang = k * math.pi / 3 + 0.3;
        final r = 6 + 22 * _ease(_q(a, imp, 160));
        _line(c, g.translate(0, 1),
            g.translate(math.cos(ang) * r, 1 + math.sin(ang) * r * 0.35),
            _a(dark, out), 2);
      }
    }
  }

  // ---------------- Lluvia de Lanzas ----------------

  /// Una lanza con la punta en [tip] apuntando en [dirv].
  static void _spear(Canvas c, Offset tip, Offset dirv, double len, double alpha) {
    final n = Offset(-dirv.dy, dirv.dx);
    _line(c, tip - dirv * len, tip - dirv * 4, _a(const Color(0xFF8A5A2B), alpha), 2);
    _fill.color = _a(const Color(0xFFDFE6E9), alpha);
    c.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((tip - dirv * 5 + n * 2).dx, (tip - dirv * 5 + n * 2).dy)
          ..lineTo((tip - dirv * 5 - n * 2).dx, (tip - dirv * 5 - n * 2).dy)
          ..close(),
        _fill);
    _line(c, tip - dirv * 6 + n * 1.5, tip - dirv * 6 - n * 1.5,
        _a(const Color(0xFFD63031), alpha), 1);
  }

  static void _spearRain(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const rose = Color(0xFFFF6B81);
    _gather(c, o, a, s.buildMs, rose);
    // La lanza gira sobre la cabeza, cada vez más rápido.
    if (a < _spearHurlAt) {
      final ang = a * a / 40000 * math.pi * 2;
      final d = Offset(math.cos(ang), math.sin(ang) * 0.45);
      final ctr = o.translate(0, -26);
      _spear(c, ctr + d * 11, d, 22, 1);
      _ring(c, ctr, 13, 6, _a(rose, 0.4 * _q(a, 100, 300)), 1);
    }
    // Las lanzas suben al cielo (andanada en abanico).
    if (a >= _spearHurlAt && a < s.buildMs + 200) {
      for (var k = 0; k < 7; k++) {
        final e = (a - _spearHurlAt - k * 30) / 1000;
        if (e < 0) continue;
        final dirv = Offset(st.dir * (k - 3) * 0.06, -1);
        final p = o.translate(st.dir * (k - 3) * 2.0, -20) + dirv * (e * 560);
        if (p.dy < vis.top - 30) continue;
        _spear(c, p, dirv / dirv.distance, 18, 1);
      }
    }
    if (a < s.buildMs || st.targets.isEmpty) return;
    final dirv = Offset(st.dir * 0.22, 1) / Offset(st.dir * 0.22, 1).distance;
    const fall = 200.0;
    // Lanzas decorativas que se clavan alrededor (las del tick).
    final first = ((s.buildMs + 150) / 90).ceil();
    final last = ((s.returnAt - 150) / 90).floor();
    for (var slot = first; slot <= last; slot++) {
      final land = slot * 90.0;
      final q = (a - (land - fall)) / fall;
      if (q < 0) continue;
      final g = _spearLand(st, slot);
      if (q < 1) {
        _spear(c, g - dirv * (1 - q) * 240, dirv, 20, 1);
      } else {
        _spear(c, g.translate(0, 3), dirv, 12, 0.9 * out);
      }
    }
    // Tres lanzas grandes por objetivo que llegan en su impacto.
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      for (var k = 0; k < 3; k++) {
        final land = imp - (2 - k) * 40.0;
        final q = (a - (land - 240)) / 240;
        if (q < 0) continue;
        final at = g.translate((k - 1) * 7.0, -2);
        if (q < 1) {
          final p = at - dirv * (1 - q) * 280;
          _line(c, p - dirv * 40, p - dirv * 20, _a(rose, 0.5), 2);
          _spear(c, p, dirv, 28, 1);
        } else {
          _spear(c, at, dirv, 18, out);
        }
      }
      final e = _q(a, imp, 500);
      if (a >= imp && e < 1) {
        _ring(c, g.translate(0, 1), 30 * e + 6, 10 * e + 2, _a(rose, 1 - e), 2);
        _disc(c, g.translate(0, -10), 14 * (1 - e), _a(const Color(0xFFFFFFFF), 0.8 * (1 - e)));
      }
    }
  }

  // ---------------- Tormenta Arcana ----------------

  /// Rayo quebrado de [from] a [to].
  static void _bolt(Canvas c, Offset from, Offset to, int seed, Color col,
      double alpha, double w) {
    var prev = from;
    const k = 6;
    for (var i = 1; i <= k; i++) {
      final f = i / k;
      final p = Offset.lerp(from, to, f)!
          .translate(i == k ? 0 : (_h(seed, i) - 0.5) * 14, 0);
      _line(c, prev, p, _a(col, alpha), w + 2);
      _line(c, prev, p, _a(const Color(0xFFFFFFFF), alpha), w);
      prev = p;
    }
  }

  static void _arcaneStorm(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const magenta = Color(0xFFE84393);
    const violet = Color(0xFFA29BFE);
    // Sello arcano que gira bajo el lanzador y runas que suben.
    if (a < s.returnAt) {
      final grow = _ease(_q(a, 0, 300));
      final fade = 1 - _q(a, s.buildMs, 300);
      final ctr = o.translate(0, 1);
      _ring(c, ctr, 22 * grow, 7 * grow, _a(magenta, 0.9 * fade), 2);
      _ring(c, ctr, 14 * grow, 4.5 * grow, _a(violet, 0.8 * fade), 1);
      for (var k = 0; k < 6; k++) {
        final ang = -a / 200 + k * math.pi / 3;
        final p = ctr + Offset(math.cos(ang) * 18 * grow, math.sin(ang) * 6 * grow);
        _fill.color = _a(k.isEven ? violet : magenta, fade);
        c.drawRect(Rect.fromCenter(center: p, width: 3, height: 3), _fill);
        final rise = ((a / 700 + k / 6) % 1.0);
        final r = o.translate((k - 2.5) * 6, -4 - rise * 30);
        _fill.color = _a(violet, (1 - rise) * 0.8 * fade);
        c.drawRect(Rect.fromCenter(center: r, width: 2, height: 3), _fill);
      }
      // La punta de la varita junta energía.
      if (a < s.buildMs + 60) {
        final q = _q(a, 300, s.buildMs - 300);
        final tip = o.translate(st.dir * 7, -15);
        _star(c, tip, 2 + 7 * q, _a(const Color(0xFFFFFFFF), 0.9));
        _star(c, tip, 1 + 4 * q, magenta);
      }
    }
    if (st.targets.isEmpty) return;
    final cen = st.centroid;
    final top = _topOf(st.targets, cen.dy) - 46;
    // Nube arcana que se forma sobre los objetivos al final de la carga.
    final form = _ease(_q(a, s.buildMs - 250, 400));
    if (form > 0) {
      final cloud = Offset(cen.dx, top);
      final spread = math.max(60.0, st.targets.fold<double>(0, (m, t) => math.max(m, (t.dx - cen.dx).abs())) + 40);
      _oval(c, cloud, spread * form, 12 * form, _a(const Color(0xFF2D1B4E), 0.85 * out));
      for (var k = 0; k < 3; k++) {
        final r = (spread - k * 14) * form;
        final rot = a / (300 + k * 120) * (k.isEven ? 1 : -1);
        _stroke
          ..color = _a(k == 1 ? magenta : violet, 0.7 * out)
          ..strokeWidth = 1;
        c.drawArc(Rect.fromCenter(center: cloud, width: r * 2, height: (10 - k * 2) * 2 * form),
            rot, 2.2, false, _stroke);
      }
    }
    if (a < s.buildMs) return;
    // Rayos de fondo (los del tick) y los de cada impacto.
    final slot = (a / 90).floor();
    for (var k = slot - 1; k <= slot; k++) {
      if (k * 90 < s.buildMs + 120 || k * 90 >= s.returnAt - 120) continue;
      final age = a - k * 90;
      if (age < 0 || age > 120) continue;
      final g = _stormStrike(st, k);
      _bolt(c, Offset(g.dx + (_h(k, 4) - 0.5) * 20, top + 6), g, k,
          violet, 1 - age / 120, 1);
    }
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      final e = _q(a, imp, 260);
      if (a >= imp - 40 && e < 1) {
        _bolt(c, Offset(g.dx, top + 6), g.translate(0, -4), i + 77, magenta,
            1 - e, 2);
        _ring(c, g.translate(0, -6), 26 * e + 4, 12 * e + 2, _a(magenta, 1 - e), 2);
      }
    }
  }

  // ---------------- Andanada ----------------

  /// Un virote de [tip] en dirección [dirv].
  static void _crossbowBolt(Canvas c, Offset tip, Offset dirv, double len,
      double alpha, {double w = 2}) {
    final n = Offset(-dirv.dy, dirv.dx);
    _line(c, tip - dirv * len, tip, _a(const Color(0xFFDFE6E9), alpha), w);
    _disc(c, tip, w * 0.9, _a(const Color(0xFFFF9F43), alpha));
    _line(c, tip - dirv * len, tip - dirv * (len + 3) + n * 3,
        _a(const Color(0xFFD63031), alpha), 1);
    _line(c, tip - dirv * len, tip - dirv * (len + 3) - n * 3,
        _a(const Color(0xFFD63031), alpha), 1);
  }

  static void _volley(Canvas c, UltCinematic u, double a, UltStage st,
      double out) {
    final s = u.script;
    final o = st.caster;
    const orange = Color(0xFFFF9F43);
    _gather(c, o, a, s.buildMs, orange);
    final muzzle = o.translate(st.dir * 12, -9);
    if (st.targets.isEmpty) return;
    final g = st.targets.first.translate(0, -10);
    // Mira: cuatro esquinas que se cierran sobre el objetivo.
    if (a > 250 && a < s.buildMs + 80) {
      final q = _ease(_q(a, 250, s.buildMs - 300));
      final r = 26 - 14 * q;
      final col = _a(orange, 0.5 + 0.5 * q);
      for (final (sx, sy) in const [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]) {
        final corner = g + Offset(sx * r, sy * r);
        _line(c, corner, corner - Offset(sx * 6, 0), col, 2);
        _line(c, corner, corner - Offset(0, sy * 6), col, 2);
      }
      _disc(c, g, 1.5 + q, _a(orange, 0.9));
      // Brillo en la punta del virote que se tensa.
      _disc(c, muzzle, 1 + 3 * q + math.sin(a / 35), _a(const Color(0xFFFFE066), 0.9));
    }
    final dirv = (g - muzzle) / math.max(1, (g - muzzle).distance);
    final n = Offset(-dirv.dy, dirv.dx);
    // Andanada: virotes chicos que salen en abanico y convergen.
    for (var k = 0; k < _volleySmall; k++) {
      final hit = _volleyHit(s, k);
      final launch = s.buildMs + 50 + k * 45;
      final q = _q(a, launch, hit - launch);
      if (a < launch || a > hit + 40) continue;
      final arc = math.sin(q * math.pi) * (k.isEven ? 1 : -1) * (10 + k * 3);
      final p = Offset.lerp(muzzle, g, q)! + n * arc;
      _crossbowBolt(c, p, dirv, 10, 1, w: 1.5);
    }
    // El virote grande, del fogonazo al impacto, con estela y ondas.
    final launch = s.buildMs + 50;
    if (a >= launch && a < s.impactMs) {
      final q = _q(a, launch, s.impactMs - launch);
      final p = Offset.lerp(muzzle, g, q * q)!;
      _line(c, muzzle, p, _a(orange, 0.35), 3);
      for (var k = 1; k <= 3; k++) {
        final w = Offset.lerp(muzzle, p, k / 4)!;
        _ring(c, w, 3 + 2.0 * k, 6 + 2.0 * k, _a(const Color(0xFFFFFFFF), 0.35), 1);
      }
      _crossbowBolt(c, p, dirv, 18, 1, w: 3);
    }
    if (a >= s.impactMs) {
      final e = _q(a, s.impactMs, 420);
      if (e < 1) {
        _disc(c, g, 20 * (1 - e) * _ease(e * 5), _a(const Color(0xFFFFF3B0), 0.9 * (1 - e)));
        _ring(c, g, 50 * e, 24 * e, _a(orange, 1 - e), 3);
      }
      // Clavado y mareado: estrellitas que giran.
      _crossbowBolt(c, g - dirv * 2, dirv, 14, out, w: 2.5);
      for (var k = 0; k < 3; k++) {
        final ang = a / 160 + k * math.pi * 2 / 3;
        _star(c, g + Offset(math.cos(ang) * 9, -12 + math.sin(ang) * 3), 2.5,
            _a(const Color(0xFFFFEAA7), out));
      }
    }
  }

  // ---------------- Danza de Mil Cortes ----------------

  static void _thousandCuts(
      Canvas c, UltCinematic u, double a, UltStage st, Rect vis) {
    final s = u.script;
    final o = st.caster;
    const mint = Color(0xFF55EFC4);
    // Viento que se arremolina alrededor del lanzador.
    if (a < s.buildMs + 80) {
      final grow = _q(a, 0, 300);
      for (var k = 0; k < 8; k++) {
        final ang = a / 90 + k * math.pi / 4;
        final p = o.translate(math.cos(ang) * 14, -10 + math.sin(ang) * 6);
        final p2 = o.translate(math.cos(ang + 0.5) * 14, -10 + math.sin(ang + 0.5) * 6);
        _line(c, p, p2, _a(mint, 0.6 * grow), 1);
      }
      // Destello de las hojas al desenvainar.
      if (a > 420) {
        final q = _q(a, 420, 240);
        _star(c, o.translate(st.dir * 7, -12), 2 + 8 * math.sin(q * math.pi), _a(const Color(0xFFFFFFFF), 1));
        _star(c, o.translate(-st.dir * 8, -11), 1 + 5 * math.sin(q * math.pi), mint);
      }
    }
    if (st.targets.isEmpty) return;
    final g = st.targets.first.translate(0, -10);
    // Embestida: imágenes que van del lanzador al objetivo.
    if (a >= s.buildMs && a < s.buildMs + 260) {
      final q = _q(a, s.buildMs, 180);
      for (var k = 0; k < 6; k++) {
        final p = Offset.lerp(o.translate(0, -8), g, (q - k * 0.1).clamp(0.0, 1.0))!;
        _oval(c, p, 5, 9, _a(mint, 0.45 * (1 - k / 6) * (1 - _q(a, s.buildMs + 160, 100))));
      }
    }
    // Cortes en todas direcciones (uno por golpe previo, más finos).
    final hits = s.preHitsMs;
    for (var k = 0; k < hits.length; k++) {
      final h = hits[k];
      if (a < h || a > h + 160) continue;
      final q = _q(a, h, 160);
      final ang = _h(k, 11) * math.pi;
      final d = Offset(math.cos(ang), math.sin(ang));
      final len = 60.0 * math.min(1.0, q * 5);
      _line(c, g - d * len / 2, g + d * len / 2, _a(mint, 0.85 * (1 - q)), 3 * (1 - q) + 1);
      _line(c, g - d * len / 2, g + d * len / 2, _a(const Color(0xFFFFFFFF), 1 - q), 1);
    }
    // Remolino de hojas verdes durante la ráfaga.
    if (a >= s.buildMs + 200 && a < s.impactMs + 300) {
      for (var k = 0; k < 12; k++) {
        final ang = a / 120 + k * math.pi / 6;
        final r = 18 + 6 * math.sin(a / 80 + k);
        final p = g + Offset(math.cos(ang) * r, math.sin(ang) * r * 0.5);
        _fill.color = _a(k.isEven ? mint : const Color(0xFFDFF9FB), 0.8);
        c.drawRect(Rect.fromCenter(center: p, width: 2, height: 2), _fill);
      }
    }
    // El final: un tajo horizontal que cruza la vista y una estrella de
    // ocho cortes.
    final imp = s.impactMs;
    if (a >= imp - 80 && a < imp + 380) {
      final q = _q(a, imp - 80, 460);
      final span = vis.width * math.min(1.0, q * 3);
      _line(c, Offset(g.dx - span / 2, g.dy), Offset(g.dx + span / 2, g.dy),
          _a(mint, 0.9 * (1 - q)), 6 * (1 - q) + 2);
      _line(c, Offset(g.dx - span / 2, g.dy), Offset(g.dx + span / 2, g.dy),
          _a(const Color(0xFFFFFFFF), 1 - q * 0.7), 2 * (1 - q) + 1);
      if (a >= imp) {
        final e = _q(a, imp, 380);
        for (var k = 0; k < 8; k++) {
          final ang = k * math.pi / 4 + 0.2;
          final d = Offset(math.cos(ang), math.sin(ang));
          _line(c, g + d * (6 + 10 * e), g + d * (18 + 34 * e),
              _a(mint, 1 - e), 2);
        }
        _ring(c, g, 55 * e, 28 * e, _a(const Color(0xFFFFFFFF), 1 - e), 2);
      }
    }
  }

  // ---------------- ULT de los jefes v0.3 ----------------

  /// Coro de Ecos (Hechicera del Eco): siluetas de la Hechicera la rodean
  /// cantando; las ondas del coro cruzan el campo y resuenan en cada
  /// objetivo.
  static void _echoChorus(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const cyan = Color(0xFF7FF3FF);
    const lilac = Color(0xFFB48CFF);
    const pale = Color(0xFFE8FFFF);
    _gather(c, o, a, s.buildMs, cyan);
    final tint = s.darkness(a) * 0.14;
    if (tint > 0) {
      _fill.color = Color.fromRGBO(40, 20, 80, tint);
      c.drawRect(vis, _fill);
    }
    if (a < s.buildMs + 200) {
      // Siluetas de eco (cabeza + túnica) en círculo, que titilan.
      final g = _ease(_q(a, 0, 400));
      final fade = 1 - _q(a, s.buildMs, 200);
      for (var k = 0; k < 6; k++) {
        final ang = a / 500 + k * math.pi / 3;
        final p = o.translate(math.cos(ang) * 30 * g, -14 + math.sin(ang) * 10 * g);
        final al = (0.35 + 0.35 * math.sin(a / 70 + k)) * g * fade;
        final path = Path()
          ..moveTo(p.dx, p.dy - 12)
          ..lineTo(p.dx - 5, p.dy + 6)
          ..lineTo(p.dx + 5, p.dy + 6)
          ..close();
        _fill.color = _a(k.isEven ? cyan : lilac, al);
        c.drawPath(path, _fill);
        _disc(c, p.translate(0, -12), 2.5, _a(pale, al));
      }
      // Ondas del canto que salen de la Hechicera.
      for (var k = 0; k < 3; k++) {
        final q = ((a / 450) + k / 3) % 1.0;
        _ring(c, o.translate(0, -16), 10 + 40 * q, 6 + 20 * q,
            _a(cyan, (1 - q) * 0.7 * fade), 1);
      }
    }
    if (st.targets.isEmpty) return;
    // Ondas que viajan al grupo (arcos en abanico).
    if (a >= s.buildMs && a < s.returnAt) {
      final from = o.translate(st.dir * 10, -16);
      for (var k = 0; k < 5; k++) {
        final q = _q(a, s.buildMs + k * 70, 420);
        if (q <= 0 || q >= 1) continue;
        final ctr = Offset.lerp(from, st.centroid.translate(0, -12), q)!;
        final r = 8 + 26 * q;
        _stroke
          ..strokeWidth = 2
          ..color = _a(k.isEven ? cyan : lilac, (1 - q * 0.6) * out);
        c.drawArc(Rect.fromCenter(center: ctr, width: r * 1.2, height: r * 2.2),
            st.dir > 0 ? -math.pi / 3 : math.pi * 2 / 3, math.pi * 2 / 3, false, _stroke);
      }
    }
    // Resonancia en cada objetivo: anillos concéntricos y notas.
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      if (a < imp) continue;
      final e = _q(a, imp, 520);
      if (e >= 1) continue;
      for (var k = 0; k < 3; k++) {
        final q = (e * 1.4 - k * 0.2).clamp(0.0, 1.0);
        _ring(c, g.translate(0, -10), 6 + 24 * q, 4 + 12 * q,
            _a(k == 1 ? lilac : cyan, (1 - q) * out), 2);
      }
      for (var k = 0; k < 3; k++) {
        final n = g.translate((k - 1) * 9.0, -26 - 16 * e - k * 3);
        _fill.color = _a(pale, (1 - e) * out);
        c.drawRect(Rect.fromLTWH(n.dx, n.dy, 2, 2), _fill);
        c.drawRect(Rect.fromLTWH(n.dx + 1, n.dy - 5, 1, 5), _fill);
      }
    }
  }

  /// Erupción Total (Bestia de Magma): el piso se agrieta y enrojece;
  /// columnas de lava revientan bajo cada objetivo y llueven rocas.
  static void _totalEruption(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const lava = Color(0xFFFF7B29);
    const core = Color(0xFFFFD166);
    const crust = Color(0xFF3A1206);
    _gather(c, o, a, s.buildMs, lava);
    final tint =
        s.darkness(a) * (a < s.buildMs ? 0.2 * _q(a, 100, 700) : 0.22);
    if (tint > 0) {
      _fill.color = Color.fromRGBO(120, 25, 0, tint);
      c.drawRect(vis, _fill);
    }
    // Grietas incandescentes de la Bestia hacia el grupo.
    if (st.targets.isNotEmpty) {
      final grow = _ease(_q(a, 150, s.buildMs - 150));
      for (var i = 0; i < st.targets.length; i++) {
        final g = st.targets[i];
        final pts = _fissure(o, g, 31 + i);
        final n = (pts.length * grow).floor();
        for (var k = 1; k < n; k++) {
          _line(c, pts[k - 1], pts[k], _a(crust, 0.9 * out), 3);
          _line(c, pts[k - 1], pts[k],
              _a(lava, (0.6 + 0.4 * math.sin(a / 60 + k)) * out), 1);
        }
      }
    }
    if (a < s.buildMs) {
      // La melena de fuego crece.
      final g = _ease(_q(a, 0, s.buildMs));
      for (var k = 0; k < 8; k++) {
        final f = ((a / 300) + _h(k, 4)) % 1.0;
        final p = o.translate((_h(k, 8) - 0.5) * 30, -18 - f * 24 * g);
        _disc(c, p, 2.5 * (1 - f) + 0.5, _a(k.isEven ? lava : core, (1 - f) * g));
      }
    }
    if (st.targets.isEmpty) return;
    // Rocas que caen.
    if (a >= s.buildMs && a < s.returnAt) {
      for (var k = 0; k < scaledCount(12, density); k++) {
        final t0 = s.buildMs + (k * 61) % 700;
        final q = (a - t0) / 380;
        if (q < 0 || q > 1) continue;
        final g = st.targets[k % st.targets.length];
        final x = g.dx + (_h(k, 2) - 0.5) * 40;
        final y = vis.top + (g.dy - vis.top) * q;
        _fill.color = _a(const Color(0xFF4A3B35), out);
        c.drawRect(Rect.fromCenter(center: Offset(x, y), width: 4, height: 4), _fill);
        _fill.color = _a(lava, 0.8 * out);
        c.drawRect(Rect.fromCenter(center: Offset(x, y - 3), width: 2, height: 3), _fill);
      }
    }
    // Columnas de lava bajo cada objetivo.
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      if (a < imp - 160) continue;
      final pre = _q(a, imp - 160, 160);
      _oval(c, g.translate(0, 1), 12 * pre + 2, 4 * pre + 1, _a(lava, 0.8 * out));
      if (a < imp) continue;
      final e = _q(a, imp, 600);
      final hgt = 50 *
          math.sin(math.min(1.0, e * 2) * math.pi / 2) *
          (1 - _q(a, imp + 380, 220));
      _fill.color = _a(lava, 0.9 * out);
      c.drawRect(Rect.fromLTWH(g.dx - 6, g.dy - hgt, 12, hgt), _fill);
      _fill.color = _a(core, 0.95 * out);
      c.drawRect(Rect.fromLTWH(g.dx - 2, g.dy - hgt, 4, hgt), _fill);
      if (e < 1) _ring(c, g, 30 * _ease(e), 10 * _ease(e), _a(core, 1 - e), 2);
    }
  }

  /// Lamento Eterno (Espectro Coronado): rostros que gimen giran en torno
  /// a su corona; una ola espectral barre al grupo y manos de escarcha los
  /// atrapan desde el piso.
  static void _eternalLament(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    final o = st.caster;
    const ghost = Color(0xFFB8C6FF);
    const pale = Color(0xFFE8F6FF);
    const gold = Color(0xFFE1B12C);
    _gather(c, o, a, s.buildMs, ghost);
    final tint = s.darkness(a) * 0.18;
    if (tint > 0) {
      _fill.color = Color.fromRGBO(20, 30, 60, tint);
      c.drawRect(vis, _fill);
    }
    if (a < s.buildMs + 100) {
      final g = _ease(_q(a, 0, 350));
      // Corona que brilla.
      if (a > 300) {
        final q = _q(a, 300, 400);
        _star(c, o.translate(0, -38), 2 + 6 * math.sin(q * math.pi), _a(gold, 1));
      }
      // Rostros que gimen (óvalos con ojos y boca) en espiral.
      for (var k = 0; k < 7; k++) {
        final ang = -a / 420 + k * math.pi * 2 / 7;
        final r = (36 - 10 * _q(a, 0, s.buildMs)) * g;
        final p = o.translate(math.cos(ang) * r, -18 + math.sin(ang) * r * 0.45);
        final al = 0.55 * g;
        _oval(c, p, 3.5, 4.5, _a(pale, al));
        _fill.color = _a(const Color(0xFF2B2D42), math.min(1.0, al * 1.4));
        c.drawRect(Rect.fromLTWH(p.dx - 2, p.dy - 2, 1, 1), _fill);
        c.drawRect(Rect.fromLTWH(p.dx + 1, p.dy - 2, 1, 1), _fill);
        c.drawRect(Rect.fromLTWH(p.dx - 1, p.dy + 1, 2, 2), _fill);
      }
    }
    if (st.targets.isEmpty) return;
    // Ola espectral que barre hacia el grupo.
    if (a >= s.buildMs && a < s.impactMs + 200) {
      final q = _ease(_q(a, s.buildMs, s.impactMs - s.buildMs));
      final x = o.dx + (st.centroid.dx - o.dx) * q;
      final half = st.targets.fold<double>(
              0, (m, t) => math.max(m, (t.dy - st.centroid.dy).abs())) +
          24;
      for (var k = 0; k < 14; k++) {
        final y = st.centroid.dy - half + k * half * 2 / 13;
        final wob = math.sin(a / 80 + k) * 4;
        _fill.color = _a(k.isEven ? ghost : pale, 0.55 * out);
        c.drawRect(Rect.fromLTWH(x + wob - st.dir * 10, y - 6, 8, 10), _fill);
        _line(c, Offset(x + wob - st.dir * 10, y),
            Offset(x + wob - st.dir * 30, y + 2), _a(ghost, 0.3 * out), 1);
      }
    }
    // Manos de escarcha que suben bajo cada objetivo.
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      if (a < imp) continue;
      final e = _q(a, imp, 600);
      final up = _ease(_q(a, imp, 160)) * (1 - _q(a, imp + 420, 180)) * out;
      for (final side in [-1.0, 1.0]) {
        final base = g.translate(side * 6, 2);
        final top = base.translate(side * 1, -16 * up);
        _line(c, base, top, _a(ghost, 0.9 * up), 3);
        for (var f = -1; f <= 1; f++) {
          _line(c, top, top.translate(f * 2.0 - side, -4 * up),
              _a(pale, 0.9 * up), 1);
        }
      }
      if (e < 1) {
        _ring(c, g.translate(0, -6), 26 * _ease(e), 12 * _ease(e),
            _a(pale, 1 - e), 2);
      }
    }
  }

  /// Colapso del Vacío: dónde está el agujero negro (sobre el lanzador en
  /// la preparación, viaja sobre el grupo en la descarga).
  static Offset _voidHole(UltCinematic u, double a, UltStage st) {
    final s = u.script;
    final home = st.caster.translate(0, -44);
    final over =
        Offset(st.centroid.dx, _topOf(st.targets, st.centroid.dy) - 34);
    final q = _ease(_q(a, s.buildMs, 360));
    return Offset.lerp(home, over, q)!;
  }

  /// Colapso del Vacío (Centinela): un agujero negro con disco violeta se
  /// forma sobre el Centinela, curva la luz hacia él, viaja sobre el grupo
  /// y colapsa; rayos del vacío y esquirlas en cada objetivo.
  static void _voidCollapse(Canvas c, UltCinematic u, double a, UltStage st,
      Rect vis, double out) {
    final s = u.script;
    const violet = Color(0xFF9B59FF);
    const glow = Color(0xFFC7A6FF);
    const black = Color(0xFF07040E);
    final hole = _voidHole(u, a, st);
    final tint = s.darkness(a) * 0.24;
    if (tint > 0) {
      _fill.color = Color.fromRGBO(15, 5, 35, tint);
      c.drawRect(vis, _fill);
    }
    final grow = _ease(_q(a, 0, s.buildMs));
    final collapse = _q(a, s.impactMs - 120, 160);
    final r = (4 + 14 * grow) * (1 - collapse);
    if (r > 0.5 && a < s.impactMs + 60) {
      // Luz que se curva hacia el agujero.
      for (var k = 0; k < 16; k++) {
        final f = ((a / 360) + _h(k, 5)) % 1.0;
        final ang = k * math.pi / 8 + f * 1.2;
        final d = Offset(math.cos(ang), math.sin(ang) * 0.6);
        final r1 = r + 50 * (1 - f);
        _line(c, hole + d * r1, hole + d * (r1 + 6), _a(glow, 0.7 * f * out), 1);
      }
      // Disco de acreción.
      _stroke
        ..strokeWidth = 3
        ..color = _a(violet, 0.8 * out);
      c.drawOval(Rect.fromCenter(center: hole, width: r * 3.6, height: r * 1.1),
          _stroke);
      _disc(c, hole, r + 1.5, _a(glow, 0.8 * out));
      _disc(c, hole, r, _a(black, out));
    }
    if (st.targets.isEmpty) return;
    // Colapso: onda que se abre.
    if (a >= s.impactMs - 40 && a < s.impactMs + 500) {
      final e = _q(a, s.impactMs - 40, 540);
      _ring(c, hole, 10 + 80 * e, 5 + 36 * e, _a(glow, 1 - e), 3);
      _ring(c, hole, 6 + 50 * e, 3 + 22 * e,
          _a(const Color(0xFFFFFFFF), 1 - e), 1);
    }
    // Cada objetivo: rayo del vacío desde el agujero y esquirlas.
    for (var i = 0; i < st.targets.length; i++) {
      final g = st.targets[i];
      final imp = s.impactFor(i);
      if (a < imp - 80 || a > imp + 420) continue;
      final e = _q(a, imp - 80, 500);
      _line(c, hole, g.translate(0, -10), _a(violet, (1 - e) * out), 3);
      _line(c, hole, g.translate(0, -10), _a(glow, (1 - e) * out), 1);
      for (var k = 0; k < 6; k++) {
        final ang = k * math.pi / 3 + e * 2;
        final p = g.translate(
            math.cos(ang) * 18 * e, -10 + math.sin(ang) * 10 * e);
        final path = Path()
          ..moveTo(p.dx, p.dy - 3)
          ..lineTo(p.dx + 2, p.dy)
          ..lineTo(p.dx, p.dy + 3)
          ..lineTo(p.dx - 2, p.dy)
          ..close();
        _fill.color = _a(k.isEven ? violet : black, (1 - e) * out);
        c.drawPath(path, _fill);
      }
    }
  }
}
