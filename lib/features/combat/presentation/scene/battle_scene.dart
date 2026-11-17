import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/enemies_catalog.dart';
import '../../../../game_engine/models/battle_event.dart';
import '../../../../game_engine/models/battle_state.dart';
import '../game_sprites.dart';
import 'battle_fx.dart';
import 'battle_layout.dart';
import 'fx_style.dart';
import 'particles.dart';
import 'proc_fx.dart';
import 'ult_cinematic.dart';
import 'ult_fx.dart';

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
}

/// Cartel de entrada de un jefe (docs/specs/battle_presentation.md
/// § "Mecánicas de jefe").
class BossIntro {
  const BossIntro(this.enemyType, this.name, this.title, this.t0);
  final String enemyType;
  final String name;
  final String title;

  /// Hora de inicio en el reloj de la escena.
  final double t0;

  static const durationMs = 2600;
}

/// Un efecto vivo: el [BattleFx] con su hora de alta (`fxSeen`).
class LiveFx {
  LiveFx(this.fx, this.t0, [this.batch = 0]);

  final BattleFx fx;

  /// Hora de alta (se corre si la cinemática se adelanta).
  double t0;

  /// Paso del que viene (para adelantar los de una ULT).
  final int batch;

  /// Ya disparó sus partículas / sacudida (`fxVisual`).
  bool fired = false;

  /// Edad en ms descontado el retraso (`age` del prototipo).
  double age(double t) => t - t0 - fx.delayMs;
}

/// Estado de animación de la escena de batalla: reloj, efectos vivos,
/// partículas, cinemática de ULT, muertes vistas y cámara. No decide
/// nada del juego: se alimenta de los eventos y el estado que recibe.
/// Ver docs/specs/battle_presentation.md.
class BattleSceneController extends ChangeNotifier {
  BattleSceneController({math.Random? random})
      : particles = ParticleSystem(random);

  /// Reloj de animación en ms (`performance.now()`); se detiene durante
  /// el hit-stop.
  double t = 0;

  /// Reloj de pose (flotación, rebotes): quieto mientras una ULT
  /// "congela el tiempo".
  double poseT = 0;

  /// Hit-stop pendiente (ms de reloj real).
  double hitStop = 0;

  final ParticleSystem particles;
  final fx = <LiveFx>[];
  UltCinematic? ult;

  /// Cartel de entrada del jefe de esta batalla (mientras dure).
  BossIntro? intro;

  /// Pasos que llegaron con una cinemática en curso (§ "Nuevos pasos
  /// durante la cinemática").
  final pending = <List<BattleFx>>[];

  /// `deathSeen`: cuándo vio la escena caer a cada enemigo.
  final deathSeen = <String, double>{};

  /// Cámara actual (centro y zoom, px del mundo).
  CameraView? camera;

  /// Lo último que pidió dibujar el widget.
  SceneFrame? frame;

  int? _battleId;
  int? _seenSeq;
  int _batch = 0;

  static const maxFx = 70;

  /// Hit-stop del quiebre (ms).
  static const breakHitStopMs = 80;

  /// Otra batalla: se borra todo lo visual.
  void reset() {
    fx.clear();
    pending.clear();
    particles.clear();
    ult = null;
    intro = null;
    hitStop = 0;
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
      final boss = state.enemies.isEmpty ? null : state.enemies.first;
      if (state.boss && boss != null) {
        final d = kEnemies[boss.enemyType];
        intro = BossIntro(boss.enemyType ?? '', boss.name, d?.title ?? 'Jefe', t);
      }
      return;
    }
    if (_seenSeq == eventSeq) return;
    _seenSeq = eventSeq;
    addEffects(mapBattleEvents(events, state, layout.of));
  }

  /// La cinemática ocupa la escena (preparación o descarga, o está por
  /// empezar): los pasos nuevos esperan.
  bool get holding {
    final u = ult;
    if (u != null) {
      final ph = u.script.phaseAt(t - u.t0);
      return ph == UltPhase.buildUp || ph == UltPhase.release;
    }
    return fx.any((e) => e.fx.kind == FxKind.ult && !e.fired);
  }

  /// El tiempo está "congelado" (sin flotación ni rebotes).
  bool get frozen => ult != null && holding;

  void addEffects(List<BattleFx> list) {
    if (list.isEmpty) return;
    if (holding) {
      pending.add(list);
      if (pending.length >= 2) fastForward();
      return;
    }
    _add(list);
  }

  void _add(List<BattleFx> list) {
    final b = ++_batch;
    for (final f in list) {
      fx.add(LiveFx(f, t, b));
    }
    if (fx.length > maxFx) fx.removeRange(0, fx.length - maxFx);
  }

  /// Adelanta la cinemática al regreso: lo pendiente de la ULT arranca
  /// ya y los pasos en cola también.
  void fastForward() {
    for (final live in fx) {
      if (live.fx.kind == FxKind.ult && !live.fired) {
        live.t0 = t - live.fx.delayMs;
      }
    }
    _fire();
    final u = ult;
    if (u != null) {
      final a = t - u.t0;
      if (a < u.script.returnAt) {
        u.t0 = t - u.script.returnAt;
        u.skipped = true;
        hitStop = 0;
      }
      for (final live in fx) {
        if (live.batch == u.batch && live.age(t) < 0) {
          live.t0 = t - live.fx.delayMs;
        }
      }
    }
    _flush();
  }

  void _flush() {
    if (pending.isEmpty || holding) return;
    final batches = [...pending];
    pending.clear();
    batches.forEach(_add);
  }

  /// Avanza [dtMs] milisegundos de reloj real.
  void advance(double dtMs) {
    final f = frame;
    var dt = dtMs;
    if (hitStop > 0) {
      final eat = math.min(hitStop, dt);
      hitStop -= eat;
      dt -= eat;
    }
    t += dt;
    if (!frozen) poseT += dt;
    particles.update(dt / 1000);
    if (f != null) {
      _trackDeaths(f.battle);
    }
    _fire();
    if (f != null) _updateUlt(f);
    _flush();
    if (f != null) _updateCamera(f, dt / 1000);
    fx.removeWhere((e) => e.age(t) > e.fx.durationMs && e.fired);
    final i = intro;
    if (i != null && t - i.t0 > BossIntro.durationMs) intro = null;
    notifyListeners();
  }

  void _trackDeaths(BattleState s) {
    for (final e in s.enemies) {
      if (!e.alive) {
        deathSeen.putIfAbsent(e.id, () => t);
      } else {
        // Un cristal que se volvió a formar.
        deathSeen.remove(e.id);
      }
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
          ult = UltCinematic(f, live.t0 + f.delayMs, live.batch);
        case FxKind.slash:
          particles.burst(f.x, f.y, f.el, f.ghost ? 0.5 : 1);
        // Procs del árbol (docs/specs/battle_presentation.md
        // § "Disparadores del árbol (procs)").
        case FxKind.arc:
          particles.burst(f.tx, f.ty, f.el, 0.6);
        case FxKind.blast:
          particles.burst(f.x, f.y, FxElement.burn, 2.2);
          particles.addShake(5);
        case FxKind.bubble:
          particles.burstWith(kShieldFx, f.x, f.y);
        case FxKind.crack:
          particles.burstWith(kShardFx, f.x, f.y);
          particles.addShake(2);
        case FxKind.puff:
          particles.burstWith(kSteamFx, f.x, f.y);
        case FxKind.spark:
          particles.burstWith(kSparkFx, f.x, f.y);
        case FxKind.beam:
          particles.burst(f.x, f.y - 4, FxElement.holy, 1.2);
        case FxKind.timeStop:
          hitStop = math.max(hitStop, ProcTiming.timeStopHoldMs.toDouble());
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
        // ¡QUIEBRE!: cristal que estalla, sacudida y un hit-stop corto.
        case FxKind.shatter:
          particles.burstWith(kBreakShardFx, f.x, f.y, 2.2);
          particles.addShake(7);
          hitStop = math.max(hitStop, breakHitStopMs.toDouble());
        default:
          break;
      }
    }
  }

  /// Dónde están el lanzador, los objetivos y el grupo de la ULT.
  UltStage? ultStage([SceneFrame? at]) {
    final u = ult;
    final f = at ?? frame;
    if (u == null || f == null) return null;
    final b = f.battle;
    var ids = u.fx.ult?.targets ?? const <String>[];
    if (ids.isEmpty) {
      ids = (u.fx.ult?.bulwark ?? false) || (u.fx.ult?.enemy ?? false)
          ? [for (final p in b.party) p.id]
          : [
              for (final e in b.enemies)
                if (e.alive ||
                    (deathSeen[e.id] != null && t - deathSeen[e.id]! < 1500))
                  e.id,
            ];
    }
    return UltStage(
      caster: u.fx.who == null ? Offset(u.fx.x, u.fx.y) : f.layout.of(u.fx.who!),
      targets: [for (final id in ids) f.layout.of(id)],
      targetBoxes: [for (final id in ids) f.layout.boxOf(id)],
      party: [for (final p in b.party) f.layout.of(p.id)],
    );
  }

  void _updateUlt(SceneFrame f) {
    final u = ult;
    if (u == null) return;
    final a = t - u.t0;
    if (a > u.script.totalMs) {
      ult = null;
      return;
    }
    final stage = ultStage(f);
    if (stage == null) return;
    UltDirector.tick(u, a, stage, particles, (ms) {
      hitStop = math.max(hitStop, ms.toDouble());
    });
  }

  /// Encuadre base de [f] (docs/specs/battle_presentation.md § "Cámara
  /// y encuadre").
  CameraView baseView(SceneFrame f) => f.layout.frame(f.geometry, f.arena);

  void _updateCamera(SceneFrame f, double dt) {
    final base = baseView(f);
    final u = ult;
    final stage = ultStage(f);
    if (u != null && stage != null) {
      camera = ultCameraAt(u.script, t - u.t0,
          base: base,
          caster: stage.caster,
          targets: stage.targets,
          party: stage.party);
      return;
    }
    final arena = f.arena;
    var cam = camera ??
        (arena == null ? base : BattleLayout.fieldView(arena, base));
    final k = 1 - math.pow(1 - 0.12, dt * 60).toDouble();
    var c = cam.center + (base.center - cam.center) * k;
    var z = cam.zoom + (base.zoom - cam.zoom) * k;
    if ((c.dx - base.center.dx).abs() > 200 ||
        (c.dy - base.center.dy).abs() > 200) {
      c = base.center;
    }
    if ((z - base.zoom).abs() < 0.01) z = base.zoom;
    if ((c - base.center).distance < 0.05) c = base.center;
    cam = CameraView(c, z);
    camera = cam;
  }

  /// Cámara para dibujar este frame.
  CameraView viewFor(SceneFrame f) => camera ?? baseView(f);

  /// El actor [id] se está lanzando (`act` de edad < 260 ms).
  bool lunging(String id) => fx.any((e) =>
      e.fx.kind == FxKind.act &&
      e.fx.who == id &&
      e.age(t) >= 0 &&
      e.age(t) < BattleFx.actMs);

  /// El efecto [kind] activo sobre [id] (edad en [0, duración)), o
  /// `null` (estelas de Frenesí).
  LiveFx? activeOn(FxKind kind, String id) {
    for (final e in fx) {
      if (e.fx.kind != kind || e.fx.who != id) continue;
      final a = e.age(t);
      if (a >= 0 && a < e.fx.durationMs) return e;
    }
    return null;
  }

  /// El enemigo [id] recibe un `slash` de edad en [0, 120) ms.
  bool flashing(String id) => fx.any((e) =>
      e.fx.kind == FxKind.slash &&
      e.fx.who == id &&
      e.age(t) >= 0 &&
      e.age(t) < 120);

  /// Alfa del enemigo caído, o `null` si ya no se dibuja. Si es objetivo
  /// de la ULT en curso, cae recién al recibir su impacto.
  double? deathAlpha(String id) {
    var ds = deathSeen[id];
    if (ds == null) return 1;
    final u = ult;
    final i = u?.fx.ult?.targets.indexOf(id) ?? -1;
    if (u != null && i >= 0) {
      ds = math.max(ds, u.t0 + u.script.impactFor(i) + 120);
      if (t < ds) return 1;
    }
    if (t - ds > 350) return null;
    return math.max(0.15, 1 - (t - ds) / 350).clamp(0.0, 1.0);
  }

  /// Oscurecido del fondo del mundo por la ULT (0..0.85).
  double get ultDim {
    final u = ult;
    if (u == null) return 0;
    return UltDirector.worldDim(u, t - u.t0);
  }
}
