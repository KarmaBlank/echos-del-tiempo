import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx_catalog.dart';
import '../../../core/audio/sfx_recipes.dart';
import '../../../core/audio/sfx_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../game_engine/data/skills_catalog.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/session_event.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/session_engine.dart';
import '../../combat/presentation/scene/battle_fx.dart';
import '../../combat/presentation/scene/fx_style.dart';
import 'session_controller.dart';
import 'session_view.dart';

/// El servicio de sonido (el del service locator; en tests, uno mudo).
final sfxServiceProvider = Provider<SfxService>((ref) =>
    sl.isRegistered<SfxService>() ? sl<SfxService>() : SfxService());

/// Conecta la sesión local con el sonido mientras `WorldScreen` está
/// montada.
final sessionSfxProvider = Provider.autoDispose<SessionSfx>((ref) {
  final controller = ref.watch(sessionControllerProvider.notifier);
  final sfx = SessionSfx(ref.watch(sfxServiceProvider),
      localId: controller.localId);
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
  _Act(this.event, this.actor, this.skill);

  final ActionEvent event;
  final Combatant? actor;
  final SkillDef? skill;

  /// Impactos ya sonados / objetivos vistos, en orden.
  final targets = <String>[];
  int impacts = 0;
  int heals = 0;
  final statuses = <StatusKind>{};
  bool delayed = false;
}

/// Traduce eventos y vistas de la sesión a efectos de sonido, fuera del
/// motor. Ver docs/specs/audio.md § "Qué evento suena".
class SessionSfx {
  SessionSfx(this.service, {required this.localId});

  final SfxService service;
  final String localId;

  /// Tope de impactos (y curas) que suenan por acción con varios
  /// objetivos; separación entre ellos.
  static const maxImpacts = 3;
  static const staggerMs = 70;

  /// Tope global de sonidos de un paso (el pool de voces).
  static const maxCuesPerStep = 12;

  /// Cuerpo a cuerpo: el impacto suena después del silbido.
  static const meleeImpactMs = 50;
  static const statusAfterMs = 90;
  static const koAfterMs = 100;
  static const healAfterMs = 120;
  static const potionHealMs = 200;
  static const heavyBoomMs = 80;

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
      case LevelUpEvent():
        service.play(Sfx.levelUp);
      default:
        break;
    }
  }

  /// Los sonidos de un paso, en orden de llegada (cada uno con su
  /// retraso). Sigue la acción en curso: de ella salen el arma, la
  /// habilidad, el elemento y los tiempos del efecto visual.
  List<SfxCue> battleSounds(List<BattleEvent> events) {
    final out = <SfxCue>[];
    final ticks = <StatusKind>{};
    _Act? action;

    for (final b in events) {
      switch (b) {
        case TurnStartedEvent():
          action = null;
        case ActionEvent():
          final sk = b.kind == BattleActionKind.skill ||
                  b.kind == BattleActionKind.ultimate
              ? kSkillsById[b.skillId]
              : null;
          action = _Act(b, battle?.byId(b.actorId), sk);
          out.addAll(_actionStart(action));
        case DamageEvent():
          out.addAll(_damage(b, action, ticks));
        case HealEvent():
          out.addAll(_heal(b, action));
        case StatusAppliedEvent(:final targetId, :final kind):
          final a = action;
          if (a == null) {
            out.add(cue(Sfx.status(kind.name)));
          } else if (a.event.kind != BattleActionKind.ultimate &&
              a.statuses.add(kind)) {
            out.add(cue(Sfx.status(kind.name),
                _impactTime(a, targetId) + statusAfterMs));
          }
        case TurnSkippedEvent(:final cause):
          out.add(cue(cause == StatusKind.freeze ? Sfx.skipFreeze : Sfx.skipStun));
        case DelayedEvent(:final targetId):
          final a = action;
          if (a == null) {
            out.add(cue(Sfx.delay));
          } else if (!a.delayed) {
            a.delayed = true;
            out.add(cue(Sfx.delay, _impactTime(a, targetId) + statusAfterMs));
          }
        case KnockedOutEvent(:final targetId):
          final a = action;
          final at = a == null ? 0 : _impactTime(a, targetId) + koAfterMs;
          out.add(cue(_isPlayer(targetId) ? Sfx.koPlayer : Sfx.koEnemy, at));
        case RevivedEvent():
          out.add(cue(Sfx.revive));
        case UltimateUsedEvent():
          out.addAll(ultimateCues(b));
        case BattleEndedEvent():
          break;
      }
    }
    return out.length > maxCuesPerStep ? out.sublist(0, maxCuesPerStep) : out;
  }

  /// Gancho de la ULT: hoy es el `beep` del prototipo. El diseño de
  /// sonido de cada ULT (junto con su cinemática) va acá.
  List<SfxCue> ultimateCues(UltimateUsedEvent e) => [cue(Sfx.ultimate)];

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
        return [cue(Sfx.flash), cue(_enemySfx(a.actor))];
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
        return (a.skill?.dealsDamage ?? false) ? BattleFx.ultDelayMs : 0;
      case BattleActionKind.skill:
        final sk = a.skill;
        if (sk == null || !sk.dealsDamage) return 0;
        if (sk.kind == SkillKind.regen) return 0; // luz de la rama creyente
        return sk.kind == SkillKind.magical || _ranged(a.actor)
            ? BattleFx.projMs
            : 0;
      case BattleActionKind.dual:
        return BattleFx.dualDelayMs;
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
    final dl = _hitDelay(a);
    final melee = dl == 0 && a.event.kind != BattleActionKind.ultimate;
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
    if (a.event.kind == BattleActionKind.ultimate) {
      // ULT: como el prototipo (el diseño de ULT va en ultimateCues).
      out.add(cue(!e.critical && _isPlayer(e.targetId) ? Sfx.hurt : Sfx.hit));
      if (e.critical) {
        out.add(cue(Sfx.critClink, _impactTime(a, e.targetId)));
      }
      return out;
    }
    final firstHit = !a.targets.contains(e.targetId);
    final at = _impactTime(a, e.targetId);
    if (firstHit && a.impacts < maxImpacts) {
      a.impacts++;
      out.add(cue(_impactSfx(a, e.targetId), at));
    }
    // Cada crítico, aunque su impacto no suene (tope de impactos).
    if (e.critical) out.add(cue(Sfx.critClink, at));
    return out;
  }

  /// Impacto según el elemento del golpe (`skillElement`) y el arma.
  String _impactSfx(_Act a, String targetId) {
    if (_isPlayer(targetId)) return Sfx.impactHurt;
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
    if (a.event.kind == BattleActionKind.ultimate) return [cue(Sfx.heal)];
    if (a.heals >= maxImpacts) return const [];
    final base = a.event.kind == BattleActionKind.potion
        ? potionHealMs
        : healAfterMs;
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
    final left = (SessionEngine.turnLimit - b.turnTime).ceil();
    if (left <= 5 && left != _lastTick) {
      _lastTick = left;
      service.play(Sfx.turnTick);
    }
  }
}

