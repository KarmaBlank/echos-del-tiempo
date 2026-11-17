import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/models/battle_event.dart';
import '../../../../game_engine/models/battle_state.dart';
import '../game_sprites.dart';
import 'battle_fx.dart';
import 'battle_layout.dart';
import 'fx_style.dart';
import 'particles.dart';

/// Lo que la escena dibuja en este frame (datos del widget). Inmutable.
class SceneFrame {
  const SceneFrame({
    required this.battle,
    required this.geometry,
    required this.layout,
    this.arena,
    this.sprites,
    this.localId,
    this.targetId,
    this.turnTimeLeft,
    this.coverBottom = 0,
  });

  final BattleState battle;
  final SceneGeometry geometry;
  final BattleLayout layout;
  final BattleArena? arena;
  final GameSprites? sprites;

  /// Jugador de este dispositivo (nombre dorado, borde del timeline).
  final String? localId;

  /// Enemigo apuntado; solo se marca si es el turno del jugador local.
  final String? targetId;

  /// Segundos del turno del jugador (barra de tiempo); `null` si no espera.
  final double? turnTimeLeft;

  /// Px virtuales de escena tapados por los paneles de abajo.
  final double coverBottom;
}

/// Un efecto vivo: el [BattleFx] con su hora de alta (`fxSeen`).
class LiveFx {
  LiveFx(this.fx, this.t0);

  final BattleFx fx;
  final double t0;

  /// Ya disparó sus partículas / sacudida (`fxVisual`).
  bool fired = false;

  /// Edad en ms descontado el retraso (`age` del prototipo).
  double age(double t) => t - t0 - fx.delayMs;
}

/// Cinemática de ultimate en curso (`ultCine`).
class UltCinematic {
  UltCinematic(this.fx, this.t0);

  final BattleFx fx;
  final double t0;
  final done = <String>{};
}

/// Estado de animación de la escena de batalla: reloj, efectos vivos,
/// partículas, cinemática, muertes vistas y cámara. No decide nada del
/// juego: se alimenta de los eventos y el estado que recibe. Ver
/// docs/specs/battle_presentation.md.
class BattleSceneController extends ChangeNotifier {
  BattleSceneController({math.Random? random})
      : particles = ParticleSystem(random);

  /// Reloj de animación en ms (`performance.now()`).
  double t = 0;
  final ParticleSystem particles;
  final fx = <LiveFx>[];
  UltCinematic? ult;

  /// `deathSeen`: cuándo vio la escena caer a cada enemigo.
  final deathSeen = <String, double>{};

  /// Cámara (esquina superior izquierda de la escena, px del mundo).
  Offset? camera;

  /// Lo último que pidió dibujar el widget.
  SceneFrame? frame;

  int? _battleId;
  int? _seenSeq;

  static const maxFx = 70;

  /// Otra batalla: se borra todo lo visual.
  void reset() {
    fx.clear();
    particles.clear();
    ult = null;
    deathSeen.clear();
    camera = null;
  }

  /// Recibe el paso actual. Los eventos se traducen una sola vez por
  /// [eventSeq]; la primera vez (o en otra batalla) solo se marcan vistos.
  void sync({
    required int battleId,
    required int eventSeq,
    required List<BattleEvent> events,
    required BattleState state,
    required BattleLayout layout,
  }) {
    if (_battleId != battleId) {
      if (_battleId != null) reset();
      _battleId = battleId;
      _seenSeq = eventSeq;
      return;
    }
    if (_seenSeq == eventSeq) return;
    _seenSeq = eventSeq;
    addEffects(mapBattleEvents(events, state, layout.of));
  }

  void addEffects(List<BattleFx> list) {
    for (final f in list) {
      fx.add(LiveFx(f, t));
    }
    if (fx.length > maxFx) fx.removeRange(0, fx.length - maxFx);
  }

  /// Avanza [dtMs] milisegundos.
  void advance(double dtMs) {
    final f = frame;
    t += dtMs;
    particles.update(dtMs / 1000);
    if (f != null) {
      _trackDeaths(f.battle);
      _fire();
      _updateUlt(f);
      _updateCamera(f, dtMs / 1000);
    }
    fx.removeWhere((e) => e.age(t) > e.fx.durationMs && e.fired);
    notifyListeners();
  }

  void _trackDeaths(BattleState s) {
    for (final e in s.enemies) {
      if (!e.alive) deathSeen.putIfAbsent(e.id, () => t);
    }
  }

  /// `fxVisual`: lo que dispara cada efecto al empezar.
  void _fire() {
    for (final live in fx) {
      if (live.fired || live.age(t) < 0) continue;
      live.fired = true;
      final f = live.fx;
      switch (f.kind) {
        case FxKind.ult:
          ult = UltCinematic(f, live.t0 + f.delayMs);
          particles.addShake(4);
        case FxKind.slash:
          particles.burst(f.x, f.y, f.el);
        case FxKind.aura:
          particles.burst(f.x, f.y - 8, f.el);
        case FxKind.num when f.big:
          particles.addShake(f.hurt ? 7 : 5);
          if (f.hurt) particles.hurtFlash = 0.45;
          particles.burst(f.x, f.y + 10, FxElement.phys, 1.5);
        case FxKind.num when f.hurt:
          particles.addShake(2);
        case FxKind.flash:
          particles.addShake(6);
        case FxKind.poof:
          particles.burst(f.x, f.y, FxElement.arcane, 0.8);
        default:
          break;
      }
    }
  }

  /// Objetivos de la cinemática: enemigos vivos o caídos hace < 1500 ms
  /// (con Baluarte, los jugadores).
  List<Offset> ultTargets(SceneFrame f) {
    final u = ult;
    if (u == null) return const [];
    if (u.fx.ult?.bulwark ?? false) {
      return [for (final p in f.battle.party) f.layout.of(p.id)];
    }
    return [
      for (final e in f.battle.enemies)
        if (e.alive ||
            (deathSeen[e.id] != null && t - deathSeen[e.id]! < 1500))
          f.layout.of(e.id),
    ];
  }

  /// La parte "una vez" de `ultWorld` (ráfagas y sacudidas).
  void _updateUlt(SceneFrame f) {
    final u = ult;
    if (u == null) return;
    final a = t - u.t0;
    if (a > BattleFx.ultMs) {
      ult = null;
      return;
    }
    final el = u.fx.el;
    final auraEl = el == FxElement.phys ? FxElement.level : el;
    if (a < 1100 && a % 90 < 20) {
      particles.burst(u.fx.x, u.fx.y - 6, auraEl, 0.3);
    }
    final tg = ultTargets(f);
    void once(String k, void Function() fn) {
      if (u.done.add(k)) fn();
    }

    final ph = (a - 300) / 800;
    if (ph > 0 && ph < 1.15) {
      for (var i = 0; i < tg.length; i++) {
        final g = tg[i];
        final lp = (ph * 1.25 - i * 0.1).clamp(0.0, 1.0);
        if (lp < 1) continue;
        switch (el) {
          case FxElement.burn:
            once('m$i', () {
              particles.burst(g.dx, g.dy - 8, FxElement.burn, 3);
              particles.burst(g.dx, g.dy - 8, FxElement.phys, 1.5);
              particles.addShake(7);
            });
          case FxElement.freeze:
            once('f$i', () {
              particles.burst(g.dx, g.dy - 10, FxElement.freeze, 3);
              particles.addShake(6);
            });
          case FxElement.poison:
            once('p$i', () => particles.burst(g.dx, g.dy - 8, FxElement.poison, 2.5));
          case FxElement.holy:
            once('h$i', () {
              particles.burst(g.dx, g.dy - 8, FxElement.holy, 3);
              particles.addShake(5);
            });
          case FxElement.arcane:
            once('a$i', () => particles.burst(g.dx, g.dy - 10, FxElement.arcane, 3));
          default:
            once('s$i', () {
              particles.burst(g.dx, g.dy - 10, FxElement.phys, 3);
              particles.addShake(8);
            });
        }
      }
    }
    if (a >= BattleFx.ultDelayMs) {
      once('impact', () {
        for (final g in tg) {
          particles.burst(g.dx, g.dy - 10, auraEl, 1.5);
        }
      });
    }
  }

  void _updateCamera(SceneFrame f, double dt) {
    final target = f.layout.cameraTarget(f.geometry, f.arena,
        coverBottom: f.coverBottom);
    final arena = f.arena;
    var cam = camera ??
        (arena == null ? target : BattleLayout.fieldCamera(f.geometry, arena));
    final k = 1 - math.pow(1 - 0.12, dt * 60).toDouble();
    cam = cam + (target - cam) * k;
    if ((cam.dx - target.dx).abs() > 200 || (cam.dy - target.dy).abs() > 200) {
      cam = target;
    }
    camera = cam;
  }

  /// El actor [id] se está lanzando (`act` de edad < 260 ms).
  bool lunging(String id) => fx.any((e) =>
      e.fx.kind == FxKind.act &&
      e.fx.who == id &&
      e.age(t) >= 0 &&
      e.age(t) < BattleFx.actMs);

  /// El enemigo [id] recibe un `slash` de edad en [0, 120) ms.
  bool flashing(String id) => fx.any((e) =>
      e.fx.kind == FxKind.slash &&
      e.fx.who == id &&
      e.age(t) >= 0 &&
      e.age(t) < 120);

  /// Alfa del enemigo caído, o `null` si ya no se dibuja.
  double? deathAlpha(String id) {
    final ds = deathSeen[id];
    if (ds == null) return 1;
    final cine = ult != null;
    if (t - ds > (cine ? 1250 : 350)) return null;
    return math.max(0.15, 1 - (t - ds - (cine ? 900 : 0)) / 350).clamp(0.0, 1.0);
  }
}
