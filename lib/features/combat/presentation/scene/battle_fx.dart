import 'dart:ui';

import '../../../../game_engine/data/skills_catalog.dart';
import '../../../../game_engine/models/battle_event.dart';
import '../../../../game_engine/models/battle_state.dart';
import '../../../../game_engine/models/skill.dart';
import '../../../../game_engine/models/status.dart';
import '../../../../game_engine/rules/js_math.dart';
import 'fx_style.dart';
import 'ult_cinematic.dart';

/// Tipo de efecto (`k` de `addFx` en el prototipo).
enum FxKind { num, txt, slash, proj, ring, aura, flash, poof, act, ult }

/// Datos de la cinemática de una ultimate (`addFx({k:'ult'})`).
class UltFx {
  const UltFx({
    required this.name,
    required this.casterName,
    required this.bulwark,
    this.ultId,
    this.casterClass,
    this.script = kDefaultUltScript,
    this.targets = const [],
  });

  final String name;
  final String casterName;

  /// Baluarte: los objetivos de la cinemática son los aliados.
  final bool bulwark;

  /// `SkillDef.id` de la ULT (`null` si el arma no se conoce).
  final String? ultId;

  /// Clase del lanzador (sprite grande de la tarjeta).
  final String? casterClass;

  /// Guion (fases, impactos): docs/specs/battle_presentation.md
  /// § "Ultimates".
  final UltScript script;

  /// Objetivos en el orden de los eventos (el índice `i` de
  /// `impactFor(i)`): los golpeados, o los curados en Baluarte.
  final List<String> targets;

  UltFx withTargets(List<String> ids) => UltFx(
      name: name,
      casterName: casterName,
      bulwark: bulwark,
      ultId: ultId,
      casterClass: casterClass,
      script: script,
      targets: ids);
}

/// Un efecto de batalla: el objeto de `addFx` del prototipo, en
/// coordenadas del mundo (píxeles virtuales, `(x, y)` = pies o punto de
/// impacto). Inmutable; la escena le agrega la hora de inicio.
class BattleFx {
  const BattleFx(
    this.kind, {
    this.x = 0,
    this.y = 0,
    this.tx = 0,
    this.ty = 0,
    this.color = fxWhite,
    this.text,
    this.big = false,
    this.hurt = false,
    this.heavy = false,
    this.el = FxElement.phys,
    this.delayMs = 0,
    this.who,
    this.ult,
  });

  final FxKind kind;
  final double x, y;

  /// Destino de un `proj`.
  final double tx, ty;
  final Color color;
  final String? text;

  /// `num` de crítico (12 px) o `ring` grande.
  final bool big;

  /// Daño recibido por un jugador (sacudida y destello rojo).
  final bool hurt;

  /// Número de una ULT: más grande, con rebote, dura más.
  final bool heavy;
  final FxElement el;

  /// `dl`: el efecto empieza [delayMs] después de agregarse.
  final int delayMs;

  /// `act`: el actor que se lanza. `slash`: el golpeado (destello).
  final String? who;
  final UltFx? ult;

  /// Duración visible (ms), contada desde que empieza.
  int get durationMs => switch (kind) {
        FxKind.num => heavy ? heavyNumMs : numMs,
        FxKind.txt => txtMs,
        FxKind.slash => slashMs,
        FxKind.proj => projMs,
        FxKind.ring => ringMs,
        FxKind.poof => poofMs,
        FxKind.flash => flashMs,
        FxKind.act => actMs,
        FxKind.ult => ult?.script.totalMs ?? kDefaultUltScript.totalMs,
        FxKind.aura => 0,
      };

  static const numMs = 1100;
  static const heavyNumMs = 1400;
  static const txtMs = 1400;
  static const slashMs = 220;
  static const projMs = 280;
  static const ringMs = 450;
  static const poofMs = 500;
  static const flashMs = 350;
  static const actMs = 260;

  /// Retraso del impacto de un dúo.
  static const dualDelayMs = 300;

  /// La misma cinemática con otro [UltFx].
  BattleFx withUlt(UltFx u) => BattleFx(kind,
      x: x,
      y: y,
      tx: tx,
      ty: ty,
      color: color,
      text: text,
      big: big,
      hurt: hurt,
      heavy: heavy,
      el: el,
      delayMs: delayMs,
      who: who,
      ult: u);

  @override
  String toString() => 'BattleFx($kind, ($x, $y), text: $text, '
      'color: $color, big: $big, dl: $delayMs, who: $who)';
}

// Colores fijos del prototipo (arte).
const _gold = Color(0xFFFFD166);
const _hurtRed = Color(0xFFFF6B81);
const _critRed = Color(0xFFFF4757);
const _healGreen = Color(0xFF7BED9F);
const _regenGreen = Color(0xFF55EFC4);
const _manaBlue = Color(0xFF74B9FF);
const _orange = Color(0xFFFF9F43);
const _violet = Color(0xFFA29BFE);
const _holyLight = Color(0xFFFFF3B0);

/// Contexto de la acción en curso dentro de un paso.
class _Action {
  _Action(this.event, this.actor);

  final ActionEvent event;
  final Combatant? actor;
  SkillDef? skill;
  Color color = fxWhite;

  /// Guion de la ULT (solo en una acción `ultimate`).
  UltScript? ult;
  FxElement el = FxElement.phys;

  /// Retraso del impacto ya decidido por objetivo.
  final dl = <String, int>{};
}

/// Traduce los [BattleEvent] de un paso a efectos (los `addFx` que el
/// prototipo hacía dentro de la lógica). Puro: no tiene reloj ni azar.
/// Tabla en docs/specs/battle_presentation.md § "Eventos → efectos".
///
/// [state] es el estado DESPUÉS del paso (quién es jugador, nombres,
/// armas, aliados vivos); [position] da los pies de cada actor en la
/// escena.
List<BattleFx> mapBattleEvents(
  List<BattleEvent> events,
  BattleState state,
  Offset Function(String id) position,
) {
  final out = <BattleFx>[];
  _Action? action;

  // La acción de la ULT del paso y dónde quedó su cinemática.
  _Action? ultAction;
  int? ultIndex;

  bool isPlayer(String id) => state.byId(id)?.isPlayer ?? false;
  Iterable<Combatant> aliveParty() => state.party.where((p) => p.alive);

  void txt(String id, double dy, String text, Color color, {int dl = 0}) {
    final p = position(id);
    out.add(BattleFx(FxKind.txt,
        x: p.dx, y: p.dy + dy, text: text, color: color, delayMs: dl));
  }

  void num(String id, double dy, String text, Color color,
      {bool big = false, bool hurt = false, bool heavy = false, int dl = 0}) {
    final p = position(id);
    out.add(BattleFx(FxKind.num,
        x: p.dx,
        y: p.dy + dy,
        text: text,
        color: color,
        big: big,
        hurt: hurt,
        heavy: heavy,
        delayMs: dl));
  }

  void aura(String id, FxElement el, {int dl = 0}) {
    final p = position(id);
    out.add(BattleFx(FxKind.aura, x: p.dx, y: p.dy, el: el, delayMs: dl));
  }

  /// Impacto de la ULT en [id] (en el orden en que aparecen).
  int ultDelay(_Action a, String id) =>
      a.dl[id] ??= (a.ult ?? kDefaultUltScript).impactFor(a.dl.length);

  void ring(double x, double y, Color color, {bool big = false}) =>
      out.add(BattleFx(FxKind.ring, x: x, y: y, color: color, big: big));

  void act(String id) => out.add(BattleFx(FxKind.act, who: id));

  /// `proj(p, e, col, el)`: devuelve el `dl` (280).
  int proj(String from, String to, Color color, FxElement el) {
    final a = position(from), b = position(to);
    out.add(BattleFx(FxKind.proj,
        x: a.dx, y: a.dy - 10, tx: b.dx, ty: b.dy - 10, color: color, el: el));
    return BattleFx.projMs;
  }

  bool ranged(Combatant? c) =>
      c != null && kRangedWeaponTypes.contains(c.weaponType);

  /// Retraso del golpe a [targetId] dentro de la acción (y sus
  /// proyectiles, la primera vez).
  int hitDelay(_Action a, String targetId) {
    final known = a.dl[targetId];
    if (known != null) return known;
    final e = a.event;
    final actorId = e.actorId;
    var dl = 0;
    switch (e.kind) {
      case BattleActionKind.attack:
        if (!e.allTargets && ranged(a.actor)) {
          dl = proj(actorId, targetId, fxWhite, FxElement.phys);
        }
      case BattleActionKind.ultimate:
        if (a.skill?.dealsDamage ?? false) return ultDelay(a, targetId);
      case BattleActionKind.skill:
        final sk = a.skill;
        if (sk != null &&
            sk.dealsDamage &&
            (sk.kind == SkillKind.magical || ranged(a.actor))) {
          dl = proj(actorId, targetId, a.color, a.el);
        }
      case BattleActionKind.dual:
        proj(actorId, targetId, a.color, a.el);
        if (e.partnerId != null) proj(e.partnerId!, targetId, a.color, a.el);
        dl = BattleFx.dualDelayMs;
      default:
        break;
    }
    a.dl[targetId] = dl;
    return dl;
  }

  void startAction(ActionEvent e) {
    final actor = state.byId(e.actorId);
    final a = _Action(e, actor);
    action = a;
    final here = position(e.actorId);
    switch (e.kind) {
      case BattleActionKind.attack:
        act(e.actorId);
        if (e.allTargets) ring(here.dx, here.dy - 8, fxWhite);
      case BattleActionKind.skill:
      case BattleActionKind.ultimate:
        final sk = kSkillsById[e.skillId];
        a
          ..skill = sk
          ..color = skillColor(e.skillId)
          ..el = sk == null ? FxElement.phys : skillElement(sk);
        final ult = e.kind == BattleActionKind.ultimate;
        if (ult) {
          final script = ultScriptFor(e.skillId);
          a.ult = script;
          ultAction = a;
          // El lanzador se lanza al descargar.
          out.add(BattleFx(FxKind.act,
              who: e.actorId, delayMs: script.buildMs));
        } else {
          act(e.actorId);
        }
        if (sk == null) break;
        switch (sk.kind) {
          case SkillKind.physical || SkillKind.magical:
            if (sk.allTargets && !ult) ring(here.dx, here.dy - 8, a.color);
          case SkillKind.defenseUp:
            txt(e.actorId, -30, 'DEF +${sk.amount}', _manaBlue);
            aura(e.actorId, FxElement.mana);
          case SkillKind.protect:
            ring(here.dx, here.dy - 8, const Color(0xFFFFEAA7), big: true);
            for (final q in aliveParty()) {
              if (q.id != e.actorId) aura(q.id, FxElement.holy);
            }
          case SkillKind.taunt:
            txt(e.actorId, -30, '¡PROVOCA!', const Color(0xFFFF7675));
            ring(here.dx, here.dy - 8, const Color(0xFFFF7675), big: true);
          case SkillKind.guard:
            for (final q in aliveParty()) {
              txt(q.id, -30, 'ESCUDO', _manaBlue);
              aura(q.id, FxElement.holy);
            }
          case SkillKind.haste:
            for (final q in aliveParty()) {
              if (q.id != e.actorId) txt(q.id, -26, '¡PRISA!', _gold);
            }
          case SkillKind.heal || SkillKind.regen || SkillKind.bulwark:
            break; // los HealEvent traen números y auras
        }
      case BattleActionKind.dual:
        final partner = e.partnerId;
        final q = partner == null ? null : state.byId(partner);
        final st = actor == null || q == null
            ? null
            : kDuals[dualKey(actor.classId ?? '', q.classId ?? '')];
        a
          ..color = actor == null || q == null
              ? fxWhite
              : kDualColors[dualKey(actor.classId ?? '', q.classId ?? '')] ??
                  fxWhite
          ..el = st == null ? FxElement.arcane : elementOfStatus(st.status.kind);
        act(e.actorId);
        if (partner != null) act(partner);
        out.add(BattleFx(FxKind.flash, color: a.color));
        final pq = partner == null ? here : position(partner);
        ring((here.dx + pq.dx) / 2, (here.dy + pq.dy) / 2 - 8, a.color,
            big: true);
      case BattleActionKind.enemyAttack || BattleActionKind.enemyHeavy:
        act(e.actorId);
        a.el = actor?.inflicts == null
            ? FxElement.phys
            : elementOfStatus(actor!.inflicts!.kind);
      case BattleActionKind.enemyArea:
        act(e.actorId);
        a.el = actor?.inflicts == null
            ? FxElement.phys
            : elementOfStatus(actor!.inflicts!.kind);
        const pink = Color(0xFFE84393);
        out.add(const BattleFx(FxKind.flash, color: pink));
        ring(here.dx, here.dy - 10, pink, big: true);
      case BattleActionKind.potion ||
            BattleActionKind.ether ||
            BattleActionKind.defend:
        break;
    }
  }

  void damage(DamageEvent e) {
    final id = e.targetId;
    if (e.fromStatus) {
      final burn = e.statusSource == StatusKind.burn;
      aura(id, burn ? FxElement.burn : FxElement.poison);
      num(id, -20, '${e.amount}', burn ? _orange : _healGreen);
      return;
    }
    if (isPlayer(id)) {
      // `hurt`: enemigo → jugador.
      final p = position(id);
      num(id, -18, '${e.amount}', e.critical ? _critRed : _hurtRed,
          big: e.critical, hurt: true);
      out.add(BattleFx(FxKind.slash,
          x: p.dx,
          y: p.dy - 8,
          color: _hurtRed,
          el: action?.el ?? FxElement.phys,
          who: id));
      if (e.critical) {
        txt(id, -34, '¡CRÍTICO ×${fm(e.critMultiplier)}!', _critRed);
      }
      if (e.pierceMultiplier > 1) {
        txt(id, -44, '¡PERFORANTE ×${fm(e.pierceMultiplier)}!', _orange);
      }
      return;
    }
    // `dmgEnemy`: jugador → enemigo.
    final a = action;
    var color = a?.color ?? fxWhite;
    var el = a?.el ?? FxElement.phys;
    var dl = 0;
    if (a != null) {
      if (a.event.kind == BattleActionKind.skill &&
          a.skill?.kind == SkillKind.regen) {
        // Luz de la rama creyente.
        color = _holyLight;
        el = FxElement.holy;
      } else {
        dl = hitDelay(a, id);
      }
    }
    final p = position(id);
    final heavy = a?.ult != null;
    num(id, -20, '${e.amount}', e.critical ? _gold : fxWhite,
        big: e.critical, heavy: heavy, dl: dl);
    if (e.critical) {
      txt(id, -34, '¡CRÍTICO ×${fm(e.critMultiplier)}!', _gold, dl: dl);
      if (heavy) out.add(BattleFx(FxKind.flash, color: fxWhite, delayMs: dl));
    }
    out.add(BattleFx(FxKind.slash,
        x: p.dx, y: p.dy - 8, color: color, el: el, delayMs: dl, who: id));
  }

  void heal(HealEvent e) {
    final a = action;
    final id = e.targetId;
    if (a == null) {
      // Regeneración al empezar el turno (el maná no se muestra).
      if (e.mana) return;
      num(id, -30, '+${e.amount}', _regenGreen);
      aura(id, FxElement.heal);
      return;
    }
    if (e.mana) {
      num(id, -18, '+${e.amount} MP', _manaBlue);
      aura(id, FxElement.mana);
      return;
    }
    switch (a.event.kind) {
      case BattleActionKind.attack:
        // Fe (rama creyente).
        num(id, -26, '+${e.amount}', _healGreen);
        aura(id, FxElement.holy);
      case BattleActionKind.ultimate:
        // Baluarte: con el impacto de su guion en cada aliado.
        final dl = ultDelay(a, id);
        num(id, -18, '+${e.amount}', _healGreen, heavy: true, dl: dl);
        aura(id, FxElement.holy, dl: dl);
      default:
        aura(id, FxElement.heal);
        num(id, -18, '+${e.amount}', _healGreen);
    }
  }

  for (final e in events) {
    switch (e) {
      case TurnStartedEvent():
        action = null;
      case ActionEvent():
        startAction(e);
      case UltimateUsedEvent(:final actorId, :final name):
        final c = state.byId(actorId);
        final sk = kUltimates[c?.weaponType];
        final p = position(actorId);
        ultIndex = out.length;
        out.add(BattleFx(FxKind.ult,
            x: p.dx,
            y: p.dy,
            color: skillColor(sk?.id),
            el: sk == null ? FxElement.phys : skillElement(sk),
            who: actorId,
            ult: UltFx(
              name: name,
              casterName: c?.name ?? '',
              bulwark: sk?.kind == SkillKind.bulwark,
              ultId: sk?.id,
              casterClass: c?.classId,
              script: ultScriptFor(sk?.id),
            )));
      case DamageEvent():
        damage(e);
      case HealEvent():
        heal(e);
      case StatusAppliedEvent(:final targetId, :final kind, :final stacks):
        txt(targetId, -46,
            '${statusLetter(kind)}+$stacks${e.weakness ? ' (débil)' : ''}',
            statusColor(kind),
            dl: action?.dl[targetId] ?? 0);
      case DelayedEvent(:final targetId):
        if (!isPlayer(targetId)) txt(targetId, -44, 'RETRASO', _violet);
      case TurnSkippedEvent(:final actorId, :final cause):
        if (cause == StatusKind.stun) {
          txt(actorId, -34, '¡ATURDIDO!', const Color(0xFFFFEAA7));
        } else {
          txt(actorId, -34, '¡CONGELADO!', _manaBlue);
          aura(actorId, FxElement.freeze);
        }
      case KnockedOutEvent(:final targetId):
        if (isPlayer(targetId)) {
          txt(targetId, -28, 'K.O.', _critRed);
        } else {
          final p = position(targetId);
          // En una ULT, al impactar en él.
          final a = action;
          final dl = a?.ult == null ? 0 : a!.dl[targetId] ?? 0;
          out.add(BattleFx(FxKind.poof, x: p.dx, y: p.dy - 6, delayMs: dl));
        }
      case RevivedEvent():
        break;
      case BattleEndedEvent(:final victory, :final credits):
        if (victory) {
          for (final p in state.party) {
            txt(p.id, -40, '+₵$credits', _gold);
          }
        }
    }
  }
  // Los objetivos de la cinemática, en el orden de sus impactos.
  final ui = ultIndex;
  if (ui != null) {
    final u = out[ui];
    out[ui] = u.withUlt(u.ult!.withTargets([...?ultAction?.dl.keys]));
  }
  return out;
}

