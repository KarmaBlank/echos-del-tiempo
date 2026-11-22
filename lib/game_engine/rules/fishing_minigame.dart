import 'dart:math' as math;

import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import 'fishing_rules.dart';

/// Fases del minijuego (docs/specs/fishing.md § 4).
enum FishPhase {
  /// Listo para lanzar.
  idle,

  /// Manteniendo: carga la distancia del lance.
  charging,

  /// La boya vuela.
  flying,

  /// Boya en el agua: señuelos (nibbles) hasta la picada real.
  waiting,

  /// Picada real: hay que reaccionar dentro de la ventana.
  bite,

  /// Clavado: esperando el pez del anfitrión.
  hooking,

  /// Barra: mantener el pez dentro de la zona.
  reel,

  /// Sacado (esperando que el anfitrión lo otorgue).
  won,

  /// Se escapó (reaccionó antes, tarde o se vació la barra).
  lost,
}

/// Minijuego de pesca, **puro** y local de cada jugador (§ 10 de
/// town_loop.md). La UI llama [press] / [release] y [tick]; lee las
/// posiciones para dibujar. El pez lo tira el anfitrión: llega por [hook].
class FishingMinigame {
  FishingMinigame(this._rand, {this.biteBonus = 0, this.zoneBonus = 0});

  final double Function() _rand;
  final double biteBonus, zoneBonus;

  static TuningDef get _t => tuning(TuningId.fishing);

  FishPhase phase = FishPhase.idle;

  /// Por qué se perdió (para el aviso).
  String? lostReason;

  /// Carga del lance 0..1 (distancia).
  double power = 0;
  static const chargeSec = 1.2;
  static const flySec = 0.5;

  /// Tiempo en la fase actual.
  double phaseTime = 0;

  /// Picada real y los señuelos antes (s desde que cayó la boya).
  double biteAt = 0;
  final nibbles = <double>[];

  /// Hay un señuelo sonando ahora (la boya tiembla, pero no es la picada).
  bool get nibbling =>
      phase == FishPhase.waiting &&
      nibbles.any((n) => phaseTime >= n && phaseTime < n + 0.25);

  /// Pez clavado (lo manda el anfitrión).
  FishCatch? fish;

  // Barra (0 = abajo, 1 = arriba).
  double zonePos = 0;
  double zoneVel = 0;
  double fishPos = 0.5;
  double _fishTarget = 0.5;
  double _retarget = 0;
  double progress = 0;
  double reelTime = 0;
  bool _holding = false;

  double get zoneSize =>
      (_t.d('zoneBase') * (1 + zoneBonus)).clamp(0.08, 0.6);

  bool get fishInside =>
      fishPos >= zonePos && fishPos <= zonePos + zoneSize;

  double get _difficulty =>
      _t.d('barSpeed') * _t.d('diff${(fish?.rarity ?? FishRarity.comun).key}');

  /// Mantener: cargar el lance, clavar la picada o subir la zona.
  void press() {
    _holding = true;
    switch (phase) {
      case FishPhase.idle || FishPhase.won || FishPhase.lost:
        _go(FishPhase.charging);
        power = 0;
        fish = null;
        lostReason = null;
      case FishPhase.waiting:
        // Reaccionar antes de la picada real: se pierde.
        _lose('Tiraste antes de tiempo.');
      case FishPhase.bite:
        _go(FishPhase.hooking);
      default:
        break;
    }
  }

  void release() {
    _holding = false;
    if (phase == FishPhase.charging) {
      _go(FishPhase.flying);
    }
  }

  /// Llega el pez del anfitrión: arranca la barra.
  void hook(FishCatch c) {
    if (phase != FishPhase.hooking) return;
    fish = c;
    zonePos = 0;
    zoneVel = 0;
    fishPos = 0.5;
    _fishTarget = 0.5;
    progress = _t.d('progressStart');
    reelTime = 0;
    _go(FishPhase.reel);
  }

  /// El anfitrión rechazó la picada.
  void cancel() => _lose('Se escapó.');

  /// Se pierde el lance por [why] (p. ej. la boya cayó en la orilla).
  void fail(String why) => _lose(why);

  void tick(double dt) {
    phaseTime += dt;
    switch (phase) {
      case FishPhase.charging:
        power = math.min(1, power + dt / chargeSec);
      case FishPhase.flying:
        if (phaseTime >= flySec) _land();
      case FishPhase.waiting:
        if (phaseTime >= biteAt) _go(FishPhase.bite);
      case FishPhase.bite:
        if (phaseTime >= _t.d('biteWindowSec')) _lose('Se fue sin picar.');
      case FishPhase.reel:
        _reel(dt);
      default:
        break;
    }
  }

  void _land() {
    _go(FishPhase.waiting);
    biteAt = FishingRules.biteDelay(_rand(), biteBonus);
    nibbles.clear();
    final n = (_rand() * (_t.i('nibblesMax') + 1)).floor();
    for (var i = 0; i < n; i++) {
      nibbles.add(biteAt * (0.15 + 0.7 * _rand()));
    }
    nibbles.sort();
  }

  void _reel(double dt) {
    reelTime += dt;
    // Zona: mantener sube, soltar cae (con inercia).
    const lift = 3.2, gravity = 2.6, maxV = 1.2;
    zoneVel = (zoneVel + (_holding ? lift : -gravity) * dt).clamp(-maxV, maxV);
    zonePos += zoneVel * dt;
    final top = 1 - zoneSize;
    if (zonePos <= 0) {
      zonePos = 0;
      zoneVel = math.max(0, zoneVel);
    } else if (zonePos >= top) {
      zonePos = top;
      zoneVel = math.min(0, zoneVel);
    }
    // Pez: cambia de objetivo más seguido y salta más cuanto más raro.
    final d = _difficulty;
    _retarget -= dt;
    if (_retarget <= 0) {
      _fishTarget = _rand();
      _retarget = (1.6 - 0.6 * d).clamp(0.25, 2.0) * (0.5 + _rand());
    }
    final speed = 0.35 * d;
    final step = (_fishTarget - fishPos).clamp(-speed * dt, speed * dt);
    fishPos = (fishPos + step).clamp(0.0, 1.0);
    progress += (fishInside ? _t.d('progressGain') : -_t.d('progressDrain')) * dt;
    if (progress >= 1) {
      progress = 1;
      _go(FishPhase.won);
    } else if (progress <= 0) {
      progress = 0;
      _lose('Se soltó el pez.');
    }
  }

  void _lose(String why) {
    lostReason = why;
    _go(FishPhase.lost);
  }

  void _go(FishPhase p) {
    phase = p;
    phaseTime = 0;
  }
}
