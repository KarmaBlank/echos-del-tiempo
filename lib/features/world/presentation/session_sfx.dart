import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx_catalog.dart';
import '../../../core/audio/sfx_recipes.dart';
import '../../../core/audio/sfx_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../game_engine/data/skills_catalog.dart';
import '../../../game_engine/models/ascension.dart' show TrapKind;
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/loot_filter.dart';
import '../../../game_engine/models/passive_mechanic.dart';
import '../../../game_engine/models/session_event.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/battle_engine.dart' show ultimateOf;
import '../../combat/presentation/scene/battle_fx.dart';
import '../../combat/presentation/scene/fx_style.dart';
import '../../combat/presentation/scene/proc_fx.dart';
import '../../combat/presentation/scene/ult_cinematic.dart';
import 'hud/loot_feed.dart';
import 'session_controller.dart';
import 'session_view.dart';

/// El servicio de sonido (el del service locator; en tests, uno mudo).
final sfxServiceProvider = Provider<SfxService>(
    (ref) => sl.isRegistered<SfxService>() ? sl<SfxService>() : SfxService());

/// Conecta la sesión local con el sonido mientras `WorldScreen` está
/// montada.
final sessionSfxProvider = Provider.autoDispose<SessionSfx>((ref) {
  final controller = ref.watch(sessionControllerProvider.notifier);
  final sfx = SessionSfx(ref.watch(sfxServiceProvider),
      localId: controller.localId,
      lootVerdict: (d) => controller.lootVerdictFor(controller.localId, d));
  // Mantiene vivo el registro de loot del HUD mientras la pantalla del
  // juego vive (también en batalla, cuando el HUD no está montado).
  ref.watch(lootFeedProvider);
  final sub = controller.events.listen(sfx.onEvent);
  final removeView = controller.addListener(sfx.onView);
  ref.onDispose(() {
    unawaited(sub.cancel());
    removeView();
  });
  return sfx;
});

/// Un sonido programado.
SfxCue cue(String id, [int delayMs = 0]) => (id: id, delayMs: delayMs);

/// Contexto de la acción en curso dentro de un paso.
class _Act {
  _Act(this.event, this.actor, this.skill, {UltScript? enemyUlt})
      : ult = enemyUlt ??
            (event.kind == BattleActionKind.ultimate
                ? ultScriptFor(event.skillId)
                : null),
        enemyUlt = enemyUlt != null;

  final ActionEvent event;
  final Combatant? actor;
  final SkillDef? skill;

  /// Guion de la ULT (acción `ultimate` o ULT enemiga).
  final UltScript? ult;

  /// ULT de un enemigo (`EnemyUltEvent`).
  final bool enemyUlt;

  /// Ya sonó el acento de golpe a un quebrado.
  bool vulnAccent = false;

  /// Impactos ya sonados / objetivos vistos, en orden.
  final targets = <String>[];
  int impacts = 0;
  int heals = 0;
  final statuses = <StatusKind>{};
  bool delayed = false;

  /// Saltos de rebote ya sonados.
  int hops = 0;
}

/// Traduce eventos y vistas de la sesión a efectos de sonido, fuera del
/// motor. Ver docs/specs/audio.md § "Qué evento suena".
class SessionSfx {
  SessionSfx(this.service, {required this.localId, this.lootVerdict});

  final SfxService service;
  final String localId;

  /// Cómo ve el jugador local un drop según su filtro (sonido del filtro).
  /// `null` = sin filtro: el estilo por defecto (sin sonido).
  final FilterVerdict? Function(LootDrop d)? lootVerdict;

  /// Tope de impactos (y curas) que suenan por acción con varios
  /// objetivos; separación entre ellos.
  static const maxImpacts = 3;
  static const staggerMs = 70;

  /// Tope global de sonidos de un paso (el pool de voces).
  static const maxCuesPerStep = 12;

  /// De ese tope, cuántos pueden ser de procs del árbol (se recortan
  /// los últimos primarios para dejarles lugar).
  static const maxProcCues = 4;

  /// Cuerpo a cuerpo: el impacto suena después del silbido.
  static const meleeImpactMs = 50;
  static const statusAfterMs = 90;
  static const koAfterMs = 100;
  static const healAfterMs = 120;
  static const potionHealMs = 200;

  /// Golpe brutal: con el golpe del enemigo (después del wind-up).
  static const heavyBoomMs = BattleFx.enemyStrikeMs;

  String? _lastTurn;
  int? _lastTick;

  /// Estado de la batalla de la última vista (armas, tipos de enemigo).
  /// Los eventos del controlador llegan después de la vista del mismo
  /// paso, así que es el estado DESPUÉS del paso, como en `battle_fx`.
  BattleState? battle;

  /// Un evento de `SessionController.events`.
  void onEvent(SessionEvent e) {
    switch (e) {
      case BattleStepEvent(:final events):
        for (final c in battleSounds(events)) {
          service.play(c.id, delayMs: c.delayMs);
        }
      case LevelUpEvent() || MasteryUpEvent():
        service.play(Sfx.levelUp);
      case BattleStartedEvent(:final boss) when boss:
        // Cartel de entrada del jefe.
        service.play(Sfx.bossIntro);
      case LootDropEvent() || LootPickedEvent():
        for (final c in lootSounds(e)) {
          service.play(c.id, delayMs: c.delayMs);
        }
      // Ascensión (docs/specs/ascension.md § 1.1 y § 5).
      case TrapTriggeredEvent(:final playerId, :final kind)
          when playerId == localId:
        service.play(kind == TrapKind.spikes ? Sfx.trapSpike : Sfx.trapPulse);
      case AscensionChosenEvent():
        for (final c in ascensionCues) {
          service.play(c.id, delayMs: c.delayMs);
        }
      default:
        break;
    }
  }

  /// La cinemática de ascensión: la luz que converge y, en el destello,
  /// la revelación.
  static List<SfxCue> get ascensionCues => [
        cue(Sfx.ascBuild, ascensionBuildMs),
        cue(Sfx.ascReveal, ascensionRevealMs),
      ];

  /// Tiempos de la cinemática (docs/specs/ascension.md § 5).
  static const ascensionBuildMs = 400;
  static const ascensionRevealMs = 2200;

  /// Orígenes de las trampas del Trampero (suena el resorte al saltar).
  static const _trapSources = {
    'trampero_r',
    'trampero_b3',
    'trampaPuas',
    'ult_trampero',
  };

  /// Sonidos del loot del jugador local (docs/specs/audio.md § "Loot"):
  /// al caer, el sonido que pide su filtro (y el haz si es Legendario);
  /// al levantar, el de levantar.
  List<SfxCue> lootSounds(SessionEvent e) {
    switch (e) {
      case LootDropEvent(:final playerId, :final drop) when playerId == localId:
        final v = lootVerdict?.call(drop);
        if (v != null && !v.visible) return const [];
        final out = <SfxCue>[];
        final sound = v?.style.sound;
        if (sound != null && service.catalog.containsKey(Sfx.loot(sound))) {
          out.add(cue(Sfx.loot(sound)));
        }
        if (drop.item?.rarity == Rarity.legendario) {
          out.add(cue(Sfx.lootBeam, lootBeamDelayMs));
        }
        return out;
      case LootPickedEvent(:final playerId) when playerId == localId:
        return [cue(Sfx.lootPickup)];
      default:
        return const [];
    }
  }

  /// El haz del Legendario suena un instante después del aviso.
  static const lootBeamDelayMs = 120;

  /// Los sonidos de un paso, en orden de llegada (cada uno con su
  /// retraso). Sigue la acción en curso: de ella salen el arma, la
  /// habilidad, el elemento y los tiempos del efecto visual.
  List<SfxCue> battleSounds(List<BattleEvent> events) {
    final out = <SfxCue>[];
    final ticks = <StatusKind>{};
    _Act? action;

    // Procs del árbol (docs/specs/audio.md § "Procs del árbol").
    final procs = <SfxCue>[];
    final played = <String>{};
    final procAt = <String, int>{};
    ProcEvent? lastProc;
    var blastIdx = 0, echoIdx = 0;
    int? pendingOffset, segOut, segProc;
    var segOffset = 0;

    int base() {
      final a = action;
      return ProcTiming.base(
          inAction: a != null,
          hitMs: a == null ? 0 : _hitDelay(a),
          ult: a?.ult);
    }

    int lateBase() {
      var b = base();
      for (final v in procAt.values) {
        if (v + 60 > b) b = v + 60;
      }
      return b;
    }

    void once(String id, int at) {
      if (played.add(id)) procs.add(cue(id, at));
    }

    void closeSegment() {
      final so = segOut, sp = segProc;
      if (so == null || sp == null) return;
      for (var i = so; i < out.length; i++) {
        out[i] = cue(out[i].id, out[i].delayMs + segOffset);
      }
      for (var i = sp; i < procs.length; i++) {
        procs[i] = cue(procs[i].id, procs[i].delayMs + segOffset);
      }
      segOut = segProc = null;
    }

    void proc(ProcEvent e) {
      final src = e.sourceId;
      final t = e.targetId;
      final a = action;
      final b = base();
      lastProc = e;
      if (kChainMechanics.contains(src) && t != null) {
        final hop = a?.hops ?? 0;
        if (a != null) a.hops = hop + 1;
        if (hop <= Sfx.maxZip) {
          procs.add(cue(Sfx.zip(hop), ProcTiming.hopAt(b, hop)));
        }
        procAt[t] = ProcTiming.hopHitAt(b, hop);
        return;
      }
      switch (src) {
        case 'combustion':
          blastIdx = 0;
          once(Sfx.whump, b);
        case 'ecoArcano':
          echoIdx = 0;
          final id = Sfx.echo(a?.event.skillId ?? '');
          if (service.catalog.containsKey(id)) {
            once(id, ProcTiming.echoAt(b, 0));
          }
        case 'contraataque':
          once(Sfx.clang, b + ProcTiming.counterHitMs);
          if (t != null) procAt[t] = b + ProcTiming.counterHitMs;
        case 'castigoDivino':
          once(Sfx.bell, b);
          if (t != null) procAt[t] = b + ProcTiming.beamHitMs;
        case 'choqueTermico':
          once(Sfx.steam, b);
          if (t != null) procAt[t] = b;
        case 'tiempoGelido':
          if (t != null) procAt[t] = b;
        case 'martilloBendito':
          once(Sfx.anvil, b);
          if (t != null) procAt[t] = b;
        case 'plagaContagiosa':
          final lb = lateBase();
          once(Sfx.plague, lb);
          if (t != null) procAt[t] = lb + ProcTiming.streamMs;
        case 'sedSangre' when t == null:
          once(Sfx.heartbeat, lateBase());
        case 'guardian':
          once(Sfx.ultCharge, b);
        case 'danza':
          once(Sfx.extraTurn, b);
        case 'vientoFavor':
          once(Sfx.wind, b);
          pendingOffset = b;
        case _ when a == null && _trapSources.contains(src):
          once(Sfx.trapSpring, 0);
          if (t != null) procAt[t] = 60;
        default:
          break;
      }
    }

    // Quiebre: el tic suena una vez por paso.
    var ticked = false;
    int hitAt(String id) {
      final p = procAt[id];
      if (p != null) return p;
      final a = action;
      return a == null ? 0 : _impactTime(a, id);
    }

    for (final b in events) {
      switch (b) {
        case TurnStartedEvent():
          closeSegment();
          action = null;
        case BreakEvent(:final targetId, :final phase):
          switch (phase) {
            case BreakPhase.fill:
              if (!ticked) {
                ticked = true;
                out.add(cue(Sfx.breakTick, hitAt(targetId)));
              }
            case BreakPhase.broken:
              out.add(cue(Sfx.breakShatter, hitAt(targetId)));
            case BreakPhase.skipped:
              out.add(cue(Sfx.breakDazed));
            case BreakPhase.decay || BreakPhase.recovered:
              break;
          }
        case EnemyUltWarningEvent():
          out.add(cue(Sfx.enemyUltWarn));
        case BossMechanicEvent(:final phase, :final actorId):
          // Mecánicas de jefe (docs/specs/audio.md § "Mecánicas de jefe").
          final ult = action?.ult;
          final afterUlt = ult == null ? 0 : ult.lastImpact(3) + 120;
          switch (phase) {
            case BossMechanicPhase.webCast:
              out.add(cue(Sfx.webCast,
                  ult != null ? afterUlt : BattleFx.enemyStrikeMs + 60));
            case BossMechanicPhase.webFreed:
              out.add(cue(Sfx.webFree, 100));
            case BossMechanicPhase.webSkip || BossMechanicPhase.webStruggle:
              out.add(cue(Sfx.webStuck));
            case BossMechanicPhase.frost:
              out.add(cue(Sfx.frost));
            case BossMechanicPhase.thaw:
              out.add(cue(Sfx.thaw, base() + 120));
            case BossMechanicPhase.shatter:
              out.add(cue(Sfx.crystalBreak, hitAt(actorId) + 180));
            case BossMechanicPhase.reform:
              once(Sfx.crystalReform, afterUlt + 80);
            case BossMechanicPhase.stanceShift:
              out.add(cue(Sfx.stanceShift, ult == null ? 0 : afterUlt + 80));
            case BossMechanicPhase.resisted:
              out.add(cue(Sfx.stanceBlock, hitAt(actorId)));
            // v0.3 (docs/specs/audio.md § "Mecánicas de jefe v0.3").
            case BossMechanicPhase.echoSummon:
              once(Sfx.echoSummon, ult != null ? afterUlt + 80 : 120);
            case BossMechanicPhase.summon:
              once(Sfx.summon, ult != null ? afterUlt + 80 : 120);
            case BossMechanicPhase.echoResist:
              out.add(cue(Sfx.echoResist, hitAt(actorId)));
            case BossMechanicPhase.lavaRise:
              out.add(cue(Sfx.lavaRise,
                  ult != null ? afterUlt : BattleFx.enemyStrikeMs + 220));
            case BossMechanicPhase.lavaBurn:
              once(Sfx.lavaBurn, 0);
            case BossMechanicPhase.lavaFade:
              out.add(cue(Sfx.lavaFade, action == null ? 0 : base() + 120));
            case BossMechanicPhase.immune:
              once(Sfx.immune, hitAt(actorId) + 90);
            case BossMechanicPhase.markCast:
              out.add(cue(Sfx.markCast, ult != null ? afterUlt : 120));
            case BossMechanicPhase.markHit:
              out.add(cue(Sfx.markHit, hitAt(b.targetId ?? actorId)));
            case BossMechanicPhase.markGuarded:
              out.add(cue(Sfx.markGuard, hitAt(actorId)));
            case BossMechanicPhase.phaseShift:
              out.add(cue(Sfx.phaseShift, hitAt(actorId) + 120));
            case BossMechanicPhase.evaded:
              out.add(cue(Sfx.evade, hitAt(actorId)));
          }
        case EnemyUltEvent():
          closeSegment();
          final script = ultScriptFor(b.ultId);
          action = _Act(
              ActionEvent(b.actorId, BattleActionKind.enemyAttack,
                  skillId: b.ultId,
                  targetId: b.targetId,
                  allTargets: b.allTargets),
              battle?.byId(b.actorId),
              null,
              enemyUlt: script);
          if (service.catalog.containsKey(Sfx.ult(b.ultId, Sfx.ultBuild))) {
            out.add(cue(Sfx.ult(b.ultId, Sfx.ultBuild)));
            out.add(cue(Sfx.ult(b.ultId, Sfx.ultRelease), script.buildMs));
          } else {
            out.add(cue(Sfx.ultimate));
          }
        case ActionEvent():
          closeSegment();
          final off = pendingOffset;
          if (off != null) {
            pendingOffset = null;
            segOut = out.length;
            segProc = procs.length;
            segOffset = off;
          }
          final sk = b.kind == BattleActionKind.skill ||
                  b.kind == BattleActionKind.ultimate
              ? kSkillsById[b.skillId]
              : null;
          action = _Act(b, battle?.byId(b.actorId), sk);
          out.addAll(_actionStart(action));
        case DamageEvent(:final sourceId, :final targetId)
            when sourceId != null && !b.fromStatus && !_isPlayer(targetId):
          // Daño secundario: suena el proc, no el impacto normal.
          final at = base();
          procAt[targetId] = switch (sourceId) {
            'combustion' => ProcTiming.blastHitAt(at, blastIdx++),
            'ecoArcano' => ProcTiming.echoAt(at, echoIdx++) + BattleFx.projMs,
            _ => procAt[targetId] ?? at,
          };
        case DamageEvent():
          out.addAll(_damage(b, action, ticks));
        case HealEvent():
          final lp = lastProc;
          if (lp != null &&
              lp.sourceId == 'sedSangre' &&
              lp.targetId == b.targetId &&
              !b.mana) {
            lastProc = null;
            out.add(cue(Sfx.healSparkle, lateBase() + ProcTiming.healAfterMs));
          } else {
            out.addAll(_heal(b, action));
          }
        case StatusAppliedEvent(:final targetId, :final kind):
          final a = action;
          if (a == null) {
            out.add(cue(Sfx.status(kind.name)));
          } else if (a.ult == null && a.statuses.add(kind)) {
            final p = procAt[targetId];
            out.add(cue(Sfx.status(kind.name),
                (p ?? _impactTime(a, targetId)) + statusAfterMs));
          }
        case TurnSkippedEvent(:final cause):
          out.add(
              cue(cause == StatusKind.freeze ? Sfx.skipFreeze : Sfx.skipStun));
        case DelayedEvent(:final targetId):
          final a = action;
          if (a == null) {
            out.add(cue(Sfx.delay));
          } else if (!a.delayed) {
            a.delayed = true;
            final p = procAt[targetId];
            out.add(cue(
                Sfx.delay, (p ?? _impactTime(a, targetId)) + statusAfterMs));
          }
        case KnockedOutEvent(:final targetId):
          final a = action;
          final p = procAt[targetId];
          final at = p != null
              ? p + koAfterMs
              : a == null
                  ? 0
                  : _impactTime(a, targetId) + koAfterMs;
          out.add(cue(_isPlayer(targetId) ? Sfx.koPlayer : Sfx.koEnemy, at));
        case RevivedEvent():
          out.add(cue(Sfx.revive));
        case UltimateUsedEvent():
          out.addAll(ultimateCues(b));
        case BattleEndedEvent():
          break;
        case ProcEvent():
          proc(b);
        case BuffAppliedEvent(:final targetId, :final stat, :final value):
          final at = procAt[targetId] ?? base();
          switch (stat) {
            case BuffStat.speed:
              once(Sfx.frenzyWhoosh, at);
            case BuffStat.attack:
              once(value >= 0 ? Sfx.flare : Sfx.weaken, at);
            case BuffStat.damageTaken:
              once(Sfx.mark, at);
            default:
              break;
          }
        case ShieldEvent(:final targetId, :final absorbed):
          if (absorbed) {
            final a = action;
            once(Sfx.shieldBreak, a == null ? 0 : _peekImpact(a));
          } else {
            once(Sfx.shieldUp, procAt[targetId] ?? base());
          }
      }
    }
    closeSegment();
    final reserve = math.min(procs.length, maxProcCues);
    final room = maxCuesPerStep - reserve;
    return [
      ...out.length > room ? out.sublist(0, room) : out,
      ...procs.take(reserve),
    ];
  }

  /// Cuándo suena el golpe de [a] en su primer objetivo, sin anotarlo
  /// (el escudo que absorbe suena con el golpe enemigo).
  int _peekImpact(_Act a) {
    final dl = _hitDelay(a);
    return dl + (dl == 0 ? meleeImpactMs : 0);
  }

  /// Preparación y descarga de la ULT del arma del lanzador, en los
  /// tiempos de su guion (docs/specs/audio.md § "Ultimates"); los
  /// impactos van con cada golpe. Con arma desconocida, el `beep` del
  /// prototipo.
  List<SfxCue> ultimateCues(UltimateUsedEvent e) {
    final c = battle?.byId(e.actorId);
    final sk = c == null ? null : ultimateOf(c);
    if (sk == null ||
        !service.catalog.containsKey(Sfx.ult(sk.id, Sfx.ultBuild))) {
      return [cue(Sfx.ultimate)];
    }
    final script = ultScriptFor(sk.id);
    return [
      cue(Sfx.ult(sk.id, Sfx.ultBuild)),
      cue(Sfx.ult(sk.id, Sfx.ultRelease), script.buildMs),
    ];
  }

  /// Impacto propio de la ULT de [a] (o el genérico si no tiene).
  String _ultImpact(_Act a) {
    final id = Sfx.ult(a.event.skillId ?? '', Sfx.ultImpact);
    return service.catalog.containsKey(id) ? id : Sfx.hit;
  }

  // ---------------------------------------------------------------- acción

  List<SfxCue> _actionStart(_Act a) {
    final e = a.event;
    final weapon = a.actor?.weaponType;
    final weaponStart = kWeaponStartSfx[weapon] ?? Sfx.swingBlade;
    switch (e.kind) {
      case BattleActionKind.attack:
        return [cue(weaponStart)];
      case BattleActionKind.skill:
        final sk = a.skill;
        final sig = cue(Sfx.skill(e.skillId ?? ''));
        if (sk != null && sk.kind == SkillKind.physical) {
          return [cue(weaponStart), sig];
        }
        return [sig];
      case BattleActionKind.ultimate:
        return const []; // lo cubre UltimateUsedEvent (ultimateCues)
      case BattleActionKind.dual:
        return [cue(Sfx.flash), cue(Sfx.dualCast)];
      case BattleActionKind.potion:
        return [cue(Sfx.potion)];
      case BattleActionKind.ether:
        return [cue(Sfx.ether)];
      case BattleActionKind.defend:
        return [cue(Sfx.defend)];
      case BattleActionKind.enemyAttack:
        return [cue(_enemySfx(a.actor))];
      case BattleActionKind.enemyHeavy:
        return [cue(_enemySfx(a.actor)), cue(Sfx.enemyHeavy, heavyBoomMs)];
      case BattleActionKind.enemyArea:
        return [
          cue(_enemySfx(a.actor)),
          cue(Sfx.flash, BattleFx.enemyStrikeMs),
        ];
    }
  }

  String _enemySfx(Combatant? c) {
    final id = Sfx.enemy(c?.enemyType ?? '');
    return service.catalog.containsKey(id) ? id : Sfx.enemyGeneric;
  }

  // ---------------------------------------------------------------- tiempos

  bool _ranged(Combatant? c) =>
      c != null && kRangedWeaponTypes.contains(c.weaponType);

  /// `hitDelay` de `battle_fx.dart`: cuándo aparece el golpe en [targetId].
  int _hitDelay(_Act a) {
    final e = a.event;
    switch (e.kind) {
      case BattleActionKind.attack:
        return !e.allTargets && _ranged(a.actor) ? BattleFx.projMs : 0;
      case BattleActionKind.ultimate:
        return (a.ult ?? kDefaultUltScript).impactMs;
      case BattleActionKind.skill:
        final sk = a.skill;
        if (sk == null || !sk.dealsDamage) return 0;
        if (sk.kind == SkillKind.regen) return 0; // luz de la rama creyente
        return sk.kind == SkillKind.magical || _ranged(a.actor)
            ? BattleFx.projMs
            : 0;
      case BattleActionKind.dual:
        return BattleFx.dualDelayMs;
      case BattleActionKind.enemyAttack ||
            BattleActionKind.enemyHeavy ||
            BattleActionKind.enemyArea:
        // El golpe cae después del wind-up (como en la escena).
        return a.ult?.impactMs ?? BattleFx.enemyStrikeMs;
      default:
        return 0;
    }
  }

  /// Cuándo suena el impacto en [targetId] (con la separación por
  /// objetivo y el adelanto del silbido cuerpo a cuerpo).
  int _impactTime(_Act a, String targetId) {
    var i = a.targets.indexOf(targetId);
    if (i < 0) {
      a.targets.add(targetId);
      i = a.targets.length - 1;
    }
    final ult = a.ult;
    // ULT: el impacto de su guion en ese objetivo (ya escalonado).
    if (ult != null) return ult.impactFor(i);
    final dl = _hitDelay(a);
    final melee = dl == 0;
    return dl + (melee ? meleeImpactMs : 0) + i * staggerMs;
  }

  // ---------------------------------------------------------------- daño

  List<SfxCue> _damage(DamageEvent e, _Act? a, Set<StatusKind> ticks) {
    if (e.fromStatus) {
      final src = e.statusSource ?? StatusKind.poison;
      return ticks.add(src) ? [cue(Sfx.tick(src.name))] : const [];
    }
    if (a == null) {
      return [cue(!e.critical && _isPlayer(e.targetId) ? Sfx.hurt : Sfx.hit)];
    }
    final out = <SfxCue>[];
    final firstHit = !a.targets.contains(e.targetId);
    if (a.ult != null) {
      // ULT: su impacto propio en el ms del guion (3 como máximo).
      final at = _impactTime(a, e.targetId);
      if (firstHit && a.impacts < maxImpacts) {
        a.impacts++;
        out.add(cue(_ultImpact(a), at));
      }
      if (e.critical) out.add(cue(Sfx.critClink, at));
      if (e.vulnerable && !a.vulnAccent) {
        a.vulnAccent = true;
        out.add(cue(Sfx.breakVuln, at));
      }
      return out;
    }
    final at = _impactTime(a, e.targetId);
    if (firstHit && a.impacts < maxImpacts) {
      a.impacts++;
      out.add(cue(_impactSfx(a, e.targetId), at));
    }
    // Cada crítico, aunque su impacto no suene (tope de impactos).
    if (e.critical) out.add(cue(Sfx.critClink, at));
    // Golpe a un quebrado: el acento, una vez por acción.
    if (e.vulnerable && !a.vulnAccent) {
      a.vulnAccent = true;
      out.add(cue(Sfx.breakVuln, at));
    }
    return out;
  }

  /// Impacto según el elemento del golpe (`skillElement`) y el arma.
  String _impactSfx(_Act a, String targetId) {
    if (_isPlayer(targetId)) {
      // El impacto propio del enemigo que pega.
      final type = a.actor?.isPlayer ?? true ? null : a.actor?.enemyType;
      final id = Sfx.enemyHit(type ?? '');
      return type != null && service.catalog.containsKey(id)
          ? id
          : Sfx.impactHurt;
    }
    final e = a.event;
    final sk = a.skill;
    FxElement el;
    switch (e.kind) {
      case BattleActionKind.skill:
        if (sk == null) {
          el = FxElement.phys;
        } else if (sk.kind == SkillKind.regen) {
          el = FxElement.holy;
        } else {
          el = skillElement(sk);
        }
      case BattleActionKind.dual:
        final partner = e.partnerId == null ? null : battle?.byId(e.partnerId!);
        final d = a.actor == null || partner == null
            ? null
            : kDuals[dualKey(a.actor!.classId ?? '', partner.classId ?? '')];
        el = d == null ? FxElement.arcane : elementOfStatus(d.status.kind);
      default:
        el = FxElement.phys;
    }
    return switch (el) {
      FxElement.burn => Sfx.impactFire,
      FxElement.freeze => Sfx.impactIce,
      FxElement.poison => Sfx.impactPoison,
      FxElement.holy => Sfx.impactHoly,
      FxElement.arcane => Sfx.impactArcane,
      _ => kWeaponImpactSfx[a.actor?.weaponType] ?? Sfx.impactSlash,
    };
  }

  // ---------------------------------------------------------------- curas

  List<SfxCue> _heal(HealEvent e, _Act? a) {
    if (a == null) {
      // Regeneración al empezar el turno (el maná no se muestra).
      return e.mana ? const [] : [cue(Sfx.tick(StatusKind.regen.name))];
    }
    if (e.mana) return [cue(Sfx.manaUp)];
    final ult = a.ult;
    if (ult != null) {
      // Baluarte: una vez, en el primer impacto.
      return a.heals++ == 0 ? [cue(_ultImpact(a), ult.impactFor(0))] : const [];
    }
    if (a.heals >= maxImpacts) return const [];
    final base =
        a.event.kind == BattleActionKind.potion ? potionHealMs : healAfterMs;
    return [cue(Sfx.healSparkle, base + staggerMs * a.heals++)];
  }

  // Los ids de jugador son los de la sala; los enemigos usan `e<uid>`.
  bool _isPlayer(String id) =>
      _players.contains(id) || (battle?.byId(id)?.isPlayer ?? false);
  Set<String> _players = const {};

  /// Cada vista nueva: estado de la batalla, inicio de tu turno y la
  /// cuenta regresiva.
  void onView(SessionView? view) {
    if (view == null) return;
    _players = view.session.players.keys.toSet();
    final b = view.session.battle;
    battle = b?.state ?? battle;
    if (b == null || !view.myTurn) {
      _lastTick = null;
      return;
    }
    final turn = '${b.id}:${b.state.clock}';
    if (turn != _lastTurn) {
      _lastTurn = turn;
      _lastTick = null;
      service.play(Sfx.myTurn);
    }
    // Sin límite (tiempo de turno de la sala): sin cuenta regresiva.
    final limit = view.session.turnLimit;
    if (limit == null) return;
    final left = (limit - b.turnTime).ceil();
    if (left <= 5 && left != _lastTick) {
      _lastTick = left;
      service.play(Sfx.turnTick);
    }
  }
}
