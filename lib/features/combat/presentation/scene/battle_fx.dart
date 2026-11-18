import 'dart:math' as math;
import 'dart:ui';

import '../../../../game_engine/data/passive_mechanics.dart';
import '../../../../game_engine/data/skills_catalog.dart';
import '../../../../game_engine/models/battle_event.dart';
import '../../../../game_engine/models/battle_state.dart';
import '../../../../game_engine/models/passive_mechanic.dart';
import '../../../../game_engine/models/skill.dart';
import '../../../../game_engine/models/status.dart';
import '../../../../game_engine/rules/battle_engine.dart'
    show stanceName, ultimateOf;
import '../../../../game_engine/rules/js_math.dart';
import 'fx_style.dart';
import 'proc_fx.dart';
import 'ult_cinematic.dart';

/// Tipo de efecto (`k` de `addFx` en el prototipo, más los de los
/// disparadores del árbol: docs/specs/battle_presentation.md
/// § "Disparadores del árbol (procs)").
enum FxKind {
  num,
  txt,
  slash,
  proj,
  ring,
  aura,
  flash,
  poof,
  act,
  ult,

  /// Cartel con el nombre de una notable / keystone.
  tag,

  /// Rayo o estela de un rebote (de `(x, y)` a `(tx, ty)`).
  arc,

  /// Estallido de Combustión.
  blast,

  /// Rayo de luz desde arriba (Castigo Divino).
  beam,

  /// Escudo que se arma.
  bubble,

  /// Escudo que se quiebra al absorber.
  crack,

  /// Pulso / latido alrededor de un actor.
  pulse,

  /// Retícula que se cierra (Marca del Cazador).
  reticle,

  /// Flecha arriba / abajo (buff / debuff de ATQ).
  arrow,

  /// Chorro de partículas de `(x, y)` a `(tx, ty)` (Plaga Contagiosa).
  stream,

  /// Congelado del tiempo (Danza de Cuchillas).
  timeStop,

  /// Copias del héroe detrás de él (Frenesí).
  afterimage,

  /// Vapor (Choque Térmico): solo partículas.
  puff,

  /// Chispas doradas (Guardián): solo partículas.
  spark,

  /// ¡QUIEBRE!: cristal que estalla sobre el enemigo.
  shatter,

  /// Cartel de aviso de una ULT enemiga (pantalla).
  warn,

  /// Preparación del golpe de un enemigo (se echa atrás y brilla).
  windup,

  /// Transformación del Devorador (fase 2): oscurece, vórtice y destello.
  transform,

  /// Erupción de lava bajo un actor (Bestia de Magma).
  lavaBurst,
}

/// Datos de la cinemática de una ultimate (`addFx({k:'ult'})`).
class UltFx {
  const UltFx({
    required this.name,
    required this.casterName,
    required this.bulwark,
    this.ultId,
    this.casterClass,
    this.casterAscension,
    this.script = kDefaultUltScript,
    this.targets = const [],
    this.enemyType,
  });

  /// Ascensión del lanzador (sprite ascendido de la tarjeta).
  final String? casterAscension;

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

  /// ULT de un enemigo: su tipo (sprite de la tarjeta). `null` si es de
  /// un jugador.
  final String? enemyType;

  bool get enemy => enemyType != null;

  UltFx withTargets(List<String> ids) => UltFx(
      name: name,
      casterName: casterName,
      bulwark: bulwark,
      ultId: ultId,
      casterClass: casterClass,
      casterAscension: casterAscension,
      script: script,
      targets: ids,
      enemyType: enemyType);
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
    this.ghost = false,
    this.up = false,
    this.slot = 0,
    this.weapon,
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

  /// Repetición fantasma (Eco Arcano): `proj`, `slash` y `ring` a 50%.
  final bool ghost;

  /// `arrow` hacia arriba (si no, abajo).
  final bool up;

  /// `tag`: lugar en la pila de carteles del actor en el paso (0, 1...).
  final int slot;

  /// Tipo de arma de quien lanza el `proj` o da el `slash` (estilo del
  /// dibujo: `projStyleFor` / `slashStyleFor`); `null` = el del prototipo.
  final String? weapon;

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
        FxKind.aura || FxKind.puff || FxKind.spark => 0,
        FxKind.tag => tagMs,
        FxKind.arc => arcMs,
        FxKind.blast => blastMs,
        FxKind.beam => beamMs,
        FxKind.bubble => bubbleMs,
        FxKind.crack => crackMs,
        FxKind.pulse => heavy ? heartbeatMs : pulseMs,
        FxKind.reticle => reticleMs,
        FxKind.arrow => arrowMs,
        FxKind.stream => streamMs,
        FxKind.timeStop => timeStopMs,
        FxKind.afterimage => afterimageMs,
        FxKind.shatter => shatterMs,
        FxKind.warn => warnMs,
        FxKind.windup => windupMs,
        FxKind.transform => transformMs,
        FxKind.lavaBurst => lavaBurstMs,
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
  static const tagMs = 1300;
  static const arcMs = 240;
  static const blastMs = 520;
  static const beamMs = 480;
  static const bubbleMs = 650;
  static const crackMs = 420;
  static const pulseMs = 520;
  static const heartbeatMs = 700;
  static const reticleMs = 500;
  static const arrowMs = 900;
  static const streamMs = 520;
  static const timeStopMs = 420;
  static const afterimageMs = 650;
  static const shatterMs = 650;
  static const warnMs = 2000;

  /// Transformación del Devorador y erupción de lava (v0.3).
  static const transformMs = 1800;
  static const lavaBurstMs = 700;

  /// Destello de la transformación (desde que empieza).
  static const transformFlashMs = 900;

  /// Golpe de un enemigo: se echa atrás [windupMs], se lanza en
  /// [enemyLungeMs] y el golpe (número, tajo, sonido de impacto) cae en
  /// [enemyStrikeMs]. Lo comparte el sonido (`session_sfx.dart`).
  static const windupMs = 160;
  static const enemyLungeMs = 100;
  static const enemyStrikeMs = 160;

  /// `¡QUIEBRE!` sale esto después del estallido.
  static const breakBannerMs = 60;

  /// Retraso del impacto de un dúo.
  static const dualDelayMs = 300;

  /// La misma cinemática con otro [UltFx].
  BattleFx withUlt(UltFx u) => _copy(ult: u);

  /// El mismo efecto [ms] más tarde.
  BattleFx shifted(int ms) => ms == 0 ? this : _copy(delayMs: delayMs + ms);

  /// El mismo efecto con otro texto (cartel con el valor del buff).
  BattleFx withText(String s) => _copy(text: s);

  BattleFx _copy({UltFx? ult, int? delayMs, String? text}) => BattleFx(kind,
      x: x,
      y: y,
      tx: tx,
      ty: ty,
      color: color,
      text: text ?? this.text,
      big: big,
      hurt: hurt,
      heavy: heavy,
      el: el,
      delayMs: delayMs ?? this.delayMs,
      who: who,
      ult: ult ?? this.ult,
      ghost: ghost,
      up: up,
      slot: slot);

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
const _gray = Color(0xFFB2BEC3);

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

  /// Último enemigo golpeado por un golpe primario (de ahí sale el
  /// primer rebote).
  String? lastTarget;

  /// Rebotes: último objetivo del salto y cuántos saltos van.
  String? chainPrev;
  int hops = 0;

  /// ULT de un enemigo (sus golpes caen en los impactos del guion).
  bool enemyUlt = false;
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

  // Procs del árbol (§ "Disparadores del árbol (procs)").
  /// `dl` del último efecto secundario en cada objetivo (sus estados,
  /// `RETRASO` y `poof` caen con él).
  final procDl = <String, int>{};
  final tagCount = <String, int>{};

  /// Índice en `out` del cartel de cada `actor|mecánica`.
  final tagAt = <String, int>{};
  ProcEvent? lastProc;
  String? lastKo;
  String? blastCenter;
  var blastIdx = 0, echoIdx = 0;

  /// Escudos que absorbieron un golpe en este paso.
  final shieldHit = <String>{};

  /// Enemigos quebrados que ya mostraron `QUIEBRE ×1.5` en el paso.
  final vulnShown = <String>{};
  EnemyUltEvent? wipe;

  /// Viento a Favor: la próxima acción (el ataque gratis) se corre.
  int? pendingOffset;
  int? segStart;
  var segOffset = 0;

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

  /// Golpe de un enemigo: se echa atrás y después se lanza.
  void windup(String id) {
    final p = position(id);
    out.add(BattleFx(FxKind.windup, x: p.dx, y: p.dy, who: id));
    out.add(BattleFx(FxKind.act, who: id, delayMs: BattleFx.enemyLungeMs));
  }

  /// `proj(p, e, col, el)`: devuelve el `dl` (280).
  int proj(String from, String to, Color color, FxElement el) {
    final a = position(from), b = position(to);
    out.add(BattleFx(FxKind.proj,
        x: a.dx,
        y: a.dy - 10,
        tx: b.dx,
        ty: b.dy - 10,
        color: color,
        el: el,
        weapon: state.byId(from)?.weaponType));
    return BattleFx.projMs;
  }

  bool ranged(Combatant? c) =>
      c != null && kRangedWeaponTypes.contains(c.weaponType);

  /// Retraso del golpe a [targetId] dentro de la acción (y sus
  /// proyectiles, la primera vez).
  int hitDelay(_Action a, String targetId) {
    final known = a.dl[targetId];
    if (known != null) return known;
    if (a.enemyUlt) return ultDelay(a, targetId);
    final e = a.event;
    final actorId = e.actorId;
    var dl = 0;
    switch (e.kind) {
      case BattleActionKind.enemyAttack ||
            BattleActionKind.enemyHeavy ||
            BattleActionKind.enemyArea:
        dl = BattleFx.enemyStrikeMs;
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
          out.add(
              BattleFx(FxKind.act, who: e.actorId, delayMs: script.buildMs));
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
          case SkillKind.support:
            // Kit de ascensión: grito / escudo / adelanto para el grupo.
            ring(here.dx, here.dy - 8, a.color, big: true);
            if (sk.rally || sk.protect) {
              for (final q in aliveParty()) {
                aura(q.id, FxElement.level);
              }
            }
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
          ..el =
              st == null ? FxElement.arcane : elementOfStatus(st.status.kind);
        act(e.actorId);
        if (partner != null) act(partner);
        out.add(BattleFx(FxKind.flash, color: a.color));
        final pq = partner == null ? here : position(partner);
        ring((here.dx + pq.dx) / 2, (here.dy + pq.dy) / 2 - 8, a.color,
            big: true);
      case BattleActionKind.enemyAttack || BattleActionKind.enemyHeavy:
        windup(e.actorId);
        a.el = actor?.inflicts == null
            ? FxElement.phys
            : elementOfStatus(actor!.inflicts!.kind);
      case BattleActionKind.enemyArea:
        windup(e.actorId);
        a.el = actor?.inflicts == null
            ? FxElement.phys
            : elementOfStatus(actor!.inflicts!.kind);
        const pink = Color(0xFFE84393);
        out.add(const BattleFx(FxKind.flash,
            color: pink, delayMs: BattleFx.enemyStrikeMs));
        out.add(BattleFx(FxKind.ring,
            x: here.dx,
            y: here.dy - 10,
            color: pink,
            big: true,
            delayMs: BattleFx.enemyStrikeMs));
      case BattleActionKind.potion ||
            BattleActionKind.ether ||
            BattleActionKind.defend:
        break;
    }
  }

  // ------------------------------------------------ procs del árbol

  /// Hora base de los procs en este punto del paso.
  int procBase() {
    final a = action;
    var hit = 0;
    if (a != null) {
      for (final v in a.dl.values) {
        if (v > hit) hit = v;
      }
    }
    return ProcTiming.base(inAction: a != null, hitMs: hit, ult: a?.ult);
  }

  /// La base, pero después de todo lo secundario ya programado (lo que
  /// se dispara al final de la acción: Sed de Sangre, Plaga).
  int lateBase() {
    var b = procBase();
    for (final v in procDl.values) {
      if (v + 60 > b) b = v + 60;
    }
    return b;
  }

  /// Cartel con el nombre (una vez por actor y mecánica en el paso). El
  /// pintor lo pone sobre la etiqueta del actor, apilado por `slot`.
  void tag(String actorId, String source, int base) {
    final key = '$actorId|$source';
    if (tagAt.containsKey(key)) return;
    final k = tagCount[actorId] ?? 0;
    tagCount[actorId] = k + 1;
    final p = position(actorId);
    tagAt[key] = out.length;
    out.add(BattleFx(FxKind.tag,
        x: p.dx,
        y: p.dy - 30,
        text: procName(source),
        color: procTagColor(source),
        delayMs: ProcTiming.tagAt(base, k),
        who: actorId,
        slot: k % 4));
  }

  /// Suma [extra] al cartel de [source] de [actorId] (el valor de un
  /// buff o escudo propio: `Frenesí · VEL +20%`). `false` si no hay.
  bool addToTag(String actorId, String source, String extra) {
    final i = tagAt['$actorId|$source'];
    if (i == null) return false;
    out[i] = out[i].withText('${out[i].text} · $extra');
    return true;
  }

  /// El efecto es del propio dueño de la mecánica del último proc.
  bool own(String targetId, String source) {
    final lp = lastProc;
    return lp != null && lp.actorId == targetId && lp.sourceId == source;
  }

  /// Un efecto en [id] (`(x, y+dy)`), con destino [to] si lo tiene.
  void at(FxKind kind, String id,
      {double dy = -8,
      Color color = fxWhite,
      FxElement el = FxElement.phys,
      int dl = 0,
      bool heavy = false,
      bool up = false,
      String? to}) {
    final p = position(id);
    final q = to == null ? null : position(to);
    out.add(BattleFx(kind,
        x: p.dx,
        y: p.dy + dy,
        tx: q?.dx ?? 0,
        ty: (q?.dy ?? 0) + dy,
        color: color,
        el: el,
        delayMs: dl,
        heavy: heavy,
        up: up,
        who: id));
  }

  void proc(ProcEvent e) {
    final src = e.sourceId;
    final late = src == 'sedSangre' || src == 'plagaContagiosa';
    final base = late ? lateBase() : procBase();
    lastProc = e;
    tag(e.actorId, src, base);
    final t = e.targetId;
    final a = action;
    if (kChainMechanics.contains(src) && t != null) {
      final hop = a?.hops ?? 0;
      final from = a?.chainPrev ?? a?.lastTarget ?? e.actorId;
      if (a != null) {
        a
          ..hops = hop + 1
          ..chainPrev = t;
      }
      final (color, el) = procHitStyle(src)!;
      at(FxKind.arc, from,
          to: t, color: color, el: el, dl: ProcTiming.hopAt(base, hop));
      procDl[t] = ProcTiming.hopHitAt(base, hop);
      return;
    }
    switch (src) {
      case 'combustion' when t != null:
        at(FxKind.blast, t,
            color: const Color(0xFFFF7B29), el: FxElement.burn, dl: base);
        blastCenter = t;
        blastIdx = 0;
      case 'ecoArcano':
        echoIdx = 0;
        final p = position(e.actorId);
        out.add(BattleFx(FxKind.ring,
            x: p.dx,
            y: p.dy - 8,
            color: a?.color ?? fxWhite,
            delayMs: ProcTiming.echoAt(base, 0),
            ghost: true));
      case 'contraataque' when t != null:
        out.add(BattleFx(FxKind.act, who: e.actorId, delayMs: base));
        at(FxKind.arc, e.actorId, to: t, color: fxWhite, dl: base);
        procDl[t] = base + ProcTiming.counterHitMs;
      case 'castigoDivino' when t != null:
        at(FxKind.beam, t, dy: 0, color: const Color(0xFFFFD166), dl: base);
        procDl[t] = base + ProcTiming.beamHitMs;
      case 'choqueTermico' when t != null:
        at(FxKind.puff, t, dy: -10, dl: base);
        txt(t, -34, '¡ATURDIDO!', ProcColors.stun, dl: base);
        procDl[t] = base;
      case 'tiempoGelido' when t != null:
        aura(t, FxElement.freeze, dl: base);
        procDl[t] = base;
      case 'martilloBendito' when t != null:
        aura(t, FxElement.stun, dl: base);
        procDl[t] = base;
      case 'plagaContagiosa' when t != null:
        at(FxKind.stream, lastKo ?? e.actorId,
            to: t, color: ProcColors.plague, el: FxElement.poison, dl: base);
        procDl[t] = base + ProcTiming.streamMs;
      case 'sedSangre' when t == null:
        at(FxKind.pulse, e.actorId,
            color: ProcColors.blood, heavy: true, dl: base);
      case 'guardian':
        at(FxKind.spark, e.actorId, dy: -10, dl: base);
        final v = kMechanics[src]?.effects.firstOrNull?.value ?? 0;
        addToTag(e.actorId, src, '+${v.round()} ULT');
      case 'danza':
        at(FxKind.timeStop, e.actorId, dl: base);
        final p = position(e.actorId);
        // Cartel grande sobre el cuerpo del actor (no en la pila).
        out.add(BattleFx(FxKind.tag,
            x: p.dx,
            y: p.dy - 10,
            text: '¡OTRA VEZ!',
            color: procKeystoneColor,
            big: true,
            delayMs: base + ProcTiming.bannerMs,
            who: e.actorId));
      case 'vientoFavor':
        pendingOffset = base;
      default:
        break;
    }
  }

  /// Daño secundario de una mecánica (`DamageEvent.sourceId`).
  void procDamage(DamageEvent e, String src) {
    final id = e.targetId;
    final base = procBase();
    final style = procHitStyle(src);
    final color = style?.$1 ?? action?.color ?? fxWhite;
    final el = style?.$2 ?? action?.el ?? FxElement.phys;
    var ghost = false;
    int dl;
    switch (src) {
      case 'combustion':
        dl = ProcTiming.blastHitAt(base, blastIdx++);
        final a = position(blastCenter ?? id), b = position(id);
        out.add(BattleFx(FxKind.proj,
            x: a.dx,
            y: a.dy - 10,
            tx: b.dx,
            ty: b.dy - 10,
            color: color,
            el: el,
            delayMs: dl - BattleFx.projMs));
      case 'ecoArcano':
        final from = lastProc?.actorId ?? action?.event.actorId ?? id;
        final go = ProcTiming.echoAt(base, echoIdx++);
        final a = position(from), b = position(id);
        out.add(BattleFx(FxKind.proj,
            x: a.dx,
            y: a.dy - 10,
            tx: b.dx,
            ty: b.dy - 10,
            color: color,
            el: el,
            delayMs: go,
            ghost: true));
        dl = go + BattleFx.projMs;
        ghost = true;
      default:
        dl = procDl[id] ?? base;
    }
    procDl[id] = dl;
    final p = position(id);
    num(id, -20, '${e.amount}', color, dl: dl);
    out.add(BattleFx(FxKind.slash,
        x: p.dx,
        y: p.dy - 8,
        color: color,
        el: el,
        delayMs: dl,
        who: id,
        ghost: ghost));
  }

  /// Cura de una mecánica (Sed de Sangre, Plegaria). `false` si no es.
  bool procHeal(HealEvent e) {
    final lp = lastProc;
    if (lp == null || e.mana || lp.targetId != e.targetId) return false;
    final sed = lp.sourceId == 'sedSangre';
    if (!sed && lp.sourceId != 'plegaria') return false;
    lastProc = null;
    final dl = sed ? lateBase() + ProcTiming.healAfterMs : procBase();
    num(e.targetId, -26, '+${e.amount}', _healGreen, dl: dl);
    aura(e.targetId, sed ? FxElement.heal : FxElement.holy, dl: dl);
    return true;
  }

  void shield(ShieldEvent e) {
    final id = e.targetId;
    if (e.absorbed) {
      shieldHit.add(id);
      // Con el golpe enemigo que absorbe.
      final a = action;
      final dl = a == null ? 0 : hitDelay(a, id);
      at(FxKind.crack, id, color: ProcColors.shield, dl: dl);
      txt(id, -30, 'ABSORBE ${e.amount}', ProcColors.shield, dl: dl);
      return;
    }
    final dl = procDl[id] ?? procBase();
    at(FxKind.bubble, id, color: ProcColors.shield, dl: dl);
    final lp = lastProc;
    final label = 'ESCUDO +${e.amount}';
    // Escudo propio: el valor va en el cartel; si no, sobre el aliado.
    if (lp == null ||
        lp.actorId != id ||
        lp.targetId != id ||
        !addToTag(id, lp.sourceId, label)) {
      txt(id, -30, label, ProcColors.shield, dl: dl);
    }
  }

  void buff(BuffAppliedEvent e) {
    final id = e.targetId;
    final dl = procDl[id] ?? procBase();
    final pct = '${(e.value.abs() * 100).round()}%';
    final (String label, Color color) = switch (e.stat) {
      BuffStat.speed => ('VEL +$pct', ProcColors.frenzy),
      BuffStat.attack when e.value >= 0 => ('ATQ +$pct', ProcColors.retaliate),
      BuffStat.attack => ('ATQ −$pct', ProcColors.weaken),
      BuffStat.damageTaken => ('+$pct DAÑO', ProcColors.mark),
      BuffStat.stunLock => ('ATURDIDO +${e.turns}', ProcColors.stun),
      _ => ('${e.stat.label} ${e.value < 0 ? '−' : '+'}$pct', _gold),
    };
    switch (e.stat) {
      case BuffStat.speed:
        at(FxKind.afterimage, id, color: color, dl: dl);
      case BuffStat.attack when e.value >= 0:
        at(FxKind.pulse, id, color: color, dl: dl);
        at(FxKind.arrow, id, color: color, up: true, dl: dl);
      case BuffStat.attack:
        at(FxKind.arrow, id, color: color, dl: dl);
      case BuffStat.damageTaken:
        at(FxKind.reticle, id, dy: -10, color: color, dl: dl);
      default:
        break;
    }
    // Buff propio: el valor va en el cartel; si no, sobre el objetivo.
    if (!own(id, e.sourceId) || !addToTag(id, e.sourceId, label)) {
      txt(id, -30, label, color, dl: dl);
    }
  }

  /// Cierra el tramo corrido por Viento a Favor.
  void closeSegment() {
    final st = segStart;
    if (st == null) return;
    for (var i = st; i < out.length; i++) {
      out[i] = out[i].shifted(segOffset);
    }
    segStart = null;
  }

  // ------------------------------------------------ golpes y curas

  void damage(DamageEvent e) {
    final id = e.targetId;
    final src = e.sourceId;
    if (src != null && !e.fromStatus && !isPlayer(id)) {
      procDamage(e, src);
      return;
    }
    if (e.fromStatus) {
      final burn = e.statusSource == StatusKind.burn;
      aura(id, burn ? FxElement.burn : FxElement.poison);
      num(id, -20, '${e.amount}', burn ? _orange : _healGreen);
      return;
    }
    if (isPlayer(id)) {
      // `hurt`: enemigo → jugador (con el golpe del enemigo: después de
      // echarse atrás, o en el impacto de su ULT).
      final p = position(id);
      final a = action;
      final dl = a == null ? 0 : hitDelay(a, id);
      if (e.amount == 0 && shieldHit.contains(id)) {
        // El escudo absorbió todo: la grieta es el golpe (sin número,
        // tajo ni sacudida).
        return;
      }
      final heavy = a?.enemyUlt ?? false;
      num(id, -18, '${e.amount}', e.critical ? _critRed : _hurtRed,
          big: e.critical, hurt: true, heavy: heavy, dl: dl);
      out.add(BattleFx(FxKind.slash,
          x: p.dx,
          y: p.dy - 8,
          color: heavy ? a!.color : _hurtRed,
          el: a?.el ?? FxElement.phys,
          delayMs: dl,
          who: id));
      if (e.critical) {
        txt(id, -34, '¡CRÍTICO ×${fm(e.critMultiplier)}!', _critRed, dl: dl);
      }
      if (e.pierceMultiplier > 1) {
        txt(id, -44, '¡PERFORANTE ×${fm(e.pierceMultiplier)}!', _orange,
            dl: dl);
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
      a.lastTarget = id;
    }
    final p = position(id);
    final heavy = a?.ult != null;
    // Quebrado: el número y el tajo en el amarillo del quiebre.
    num(id, -20, '${e.amount}',
        e.critical ? _gold : (e.vulnerable ? breakColor : fxWhite),
        big: e.critical || e.vulnerable, heavy: heavy, dl: dl);
    if (e.critical) {
      txt(id, -34, '¡CRÍTICO ×${fm(e.critMultiplier)}!', _gold, dl: dl);
      if (heavy) out.add(BattleFx(FxKind.flash, color: fxWhite, delayMs: dl));
    }
    if (e.vulnerable && vulnShown.add(id)) {
      txt(id, -44, 'QUIEBRE ×1.5', breakColor, dl: dl);
    }
    out.add(BattleFx(FxKind.slash,
        x: p.dx,
        y: p.dy - 8,
        color: e.vulnerable ? breakColor : color,
        el: el,
        delayMs: dl,
        who: id,
        weapon: a?.actor?.weaponType));
  }

  void heal(HealEvent e) {
    if (procHeal(e)) return;
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

  /// Barra de quiebre (docs/specs/battle_presentation.md § "Quiebre").
  void breakFx(BreakEvent e) {
    final id = e.targetId;
    switch (e.phase) {
      case BreakPhase.broken:
        // Con el golpe que lo quebró.
        final dl = procDl[id] ?? action?.dl[id] ?? 0;
        at(FxKind.shatter, id, dy: -10, color: breakColor, dl: dl);
        out.add(BattleFx(FxKind.flash, color: breakFlashColor, delayMs: dl));
        final p = position(id);
        out.add(BattleFx(FxKind.tag,
            x: p.dx,
            y: p.dy - 10,
            text: '¡QUIEBRE!',
            color: breakColor,
            big: true,
            delayMs: dl + BattleFx.breakBannerMs,
            who: id));
        if (e.cancelledUlt) {
          txt(id, -60, 'ULT CANCELADA', _critRed, dl: dl + 250);
        }
      case BreakPhase.skipped:
        txt(id, -34, '¡QUEBRADO!', breakColor);
        aura(id, FxElement.stun);
      case BreakPhase.recovered:
        txt(id, -40, 'SE RECUPERA', _gray, dl: action == null ? 0 : lateBase());
      case BreakPhase.fill || BreakPhase.decay:
        break; // la barra de la etiqueta ya lo muestra
    }
  }

  /// La ULT de un enemigo: cinemática y acción (sus golpes caen en los
  /// impactos del guion).
  void enemyUlt(EnemyUltEvent e) {
    final c = state.byId(e.actorId);
    final script = ultScriptFor(e.ultId);
    final color = enemyUltColor(e.ultId);
    final el = enemyUltElement(e.ultId);
    final a = _Action(
        ActionEvent(e.actorId, BattleActionKind.enemyAttack,
            targetId: e.targetId, allTargets: e.allTargets),
        c)
      ..ult = script
      ..enemyUlt = true
      ..color = color
      ..el = el;
    action = a;
    ultAction = a;
    final p = position(e.actorId);
    ultIndex = out.length;
    out.add(BattleFx(FxKind.ult,
        x: p.dx,
        y: p.dy,
        color: color,
        el: el,
        who: e.actorId,
        ult: UltFx(
          name: e.name,
          casterName: c?.name ?? '',
          bulwark: false,
          ultId: e.ultId,
          script: script,
          enemyType: c?.enemyType ?? '',
        )));
    // El enemigo se lanza al descargar.
    out.add(BattleFx(FxKind.act, who: e.actorId, delayMs: script.buildMs));
    if (e.wipedBuffs) wipe = e;
  }

  /// Después del último impacto de la ULT en curso (o [plain] sin ULT).
  int afterUlt(int plain) {
    final a = action;
    final u = a?.ult;
    if (a == null || u == null) return a == null ? 0 : plain;
    return u.lastImpact(math.max(1, a.dl.length)) + 200;
  }

  /// Mecánica de un jefe (docs/specs/battle_presentation.md § "Mecánicas
  /// de jefe").
  void bossMech(BossMechanicEvent e) {
    final tg = e.targetId;
    final strike = action == null ? 0 : BattleFx.enemyStrikeMs;
    switch (e.phase) {
      case BossMechanicPhase.webCast:
        if (tg == null) return;
        final a = action;
        final dl = a != null && a.enemyUlt
            ? a.ult!.lastImpact(math.max(1, a.dl.length)) + 120
            : strike + 60;
        txt(tg, -50, '¡TELARAÑA!', webColor, dl: dl);
        at(FxKind.ring, tg, dy: -8, color: webColor, dl: dl);
      case BossMechanicPhase.webFreed:
        if (tg == null) return;
        txt(tg, -40, '¡LIBRE!', _healGreen, dl: 120);
        at(FxKind.ring, tg, dy: -8, color: _healGreen, dl: 120);
        aura(tg, FxElement.heal, dl: 120);
      case BossMechanicPhase.webSkip:
        if (tg == null) return;
        txt(tg, -34, '¡ATRAPADO!', webColor);
        aura(tg, FxElement.stun);
      case BossMechanicPhase.webStruggle:
        if (tg == null) return;
        txt(tg, -34, 'FORCEJEA ½', webColor);
        at(FxKind.ring, tg, dy: -8, color: webColor);
      case BossMechanicPhase.frost:
        final pct = jsRound(e.value * 100);
        for (final q in aliveParty()) {
          txt(q.id, -40, 'VEL −$pct%', frostColor, dl: 80);
          aura(q.id, FxElement.freeze, dl: 80);
        }
        at(FxKind.pulse, e.actorId, dy: -12, color: frostColor);
      case BossMechanicPhase.thaw:
        final dl = action == null ? 0 : lateBase();
        for (final q in aliveParty()) {
          txt(q.id, -40, 'DESHIELO', _healGreen, dl: dl + 120);
          aura(q.id, FxElement.heal, dl: dl + 120);
        }
      case BossMechanicPhase.shatter:
        if (tg == null) return;
        final dl = procDl[e.actorId] ?? action?.dl[e.actorId] ?? 0;
        procDl[tg] = dl + 180;
        at(FxKind.shatter, tg, dy: -6, color: frostColor, dl: dl + 180);
        txt(tg, -30, 'CRISTAL ROTO', frostColor, dl: dl + 200);
      case BossMechanicPhase.reform:
        if (tg == null) return;
        final a = action;
        final dl = a?.ult == null
            ? 0
            : a!.ult!.lastImpact(math.max(1, a.dl.length)) + 200;
        aura(tg, FxElement.freeze, dl: dl);
        at(FxKind.ring, tg, dy: -6, color: frostColor, dl: dl);
        txt(tg, -30, 'SE REFORMA', frostColor, dl: dl);
      case BossMechanicPhase.stanceShift:
        final st = e.value.round();
        final p = position(e.actorId);
        final a = action;
        final dl = a?.ult == null ? 0 : a!.ult!.lastImpact(1) + 200;
        out.add(BattleFx(FxKind.tag,
            x: p.dx,
            y: p.dy - 10,
            text: 'POSTURA: ${stanceName(st)}',
            color: stanceColor(st),
            big: true,
            delayMs: dl,
            who: e.actorId));
        at(FxKind.pulse, e.actorId, dy: -14, color: stanceColor(st), dl: dl);
      case BossMechanicPhase.resisted:
        final a = action;
        final dl = a == null ? 0 : hitDelay(a, e.actorId);
        txt(e.actorId, -54, 'BLOQUEA −${jsRound(e.value * 100)}%',
            const Color(0xFFB2BEC3),
            dl: dl);

      // ---- v0.3 (docs/specs/battle_presentation.md § "Mecánicas de jefe
      // v0.3") ----
      case BossMechanicPhase.echoSummon || BossMechanicPhase.summon:
        if (tg == null) return;
        final echo = e.phase == BossMechanicPhase.echoSummon;
        final col = echo ? echoColor : immuneColor;
        final dl = afterUlt(160);
        at(FxKind.arc, e.actorId,
            dy: -14, to: tg, color: col, el: FxElement.arcane, dl: dl);
        at(FxKind.poof, tg, dy: -10, dl: dl + 120);
        at(FxKind.ring, tg, dy: -8, color: col, dl: dl + 120);
        txt(tg, -34, echo ? '¡ECO!' : '¡SIERVO!', col, dl: dl + 160);
      case BossMechanicPhase.echoResist:
        final a = action;
        final dl = a == null ? 0 : hitDelay(a, e.actorId);
        txt(e.actorId, -54, 'ECO ×${fm(e.value)}', echoColor, dl: dl);
      case BossMechanicPhase.lavaRise:
        final a = action;
        final dl = a?.ult != null
            ? afterUlt(120)
            : a == null
                ? 0
                : BattleFx.enemyStrikeMs + 220;
        for (final q in aliveParty()) {
          at(FxKind.lavaBurst, q.id,
              dy: 0, color: lavaColor, el: FxElement.burn, dl: dl);
        }
        final p = position(e.actorId);
        out.add(BattleFx(FxKind.tag,
            x: p.dx,
            y: p.dy - 10,
            text: '¡LAVA ${e.value.round()} TURNOS!',
            color: lavaColor,
            big: true,
            delayMs: dl + 80,
            who: e.actorId));
      case BossMechanicPhase.lavaBurn:
        if (tg == null) return;
        at(FxKind.lavaBurst, tg, dy: 0, color: lavaColor, el: FxElement.burn);
        aura(tg, FxElement.burn, dl: 120);
        txt(tg, -44, '¡LAVA! Q+${e.value.round()}', lavaColor, dl: 80);
      case BossMechanicPhase.lavaFade:
        txt(e.actorId, -40, 'LA LAVA SE ENFRÍA', _gray,
            dl: action == null ? 0 : lateBase());
      case BossMechanicPhase.immune:
        final a = action;
        final dl = a == null ? 0 : hitDelay(a, e.actorId) + 90;
        at(FxKind.pulse, e.actorId, dy: -14, color: immuneColor, dl: dl);
        txt(e.actorId, -60, 'INMUNE', immuneColor, dl: dl);
      case BossMechanicPhase.markCast:
        if (tg == null) return;
        final dl = action?.ult != null ? afterUlt(160) : 120;
        at(FxKind.arc, e.actorId,
            dy: -14,
            to: tg,
            color: voidMarkColor,
            el: FxElement.arcane,
            dl: dl);
        at(FxKind.reticle, tg, dy: -10, color: voidMarkColor, dl: dl + 200);
        txt(tg, -46, '¡MARCADO!', voidMarkColor, dl: dl + 200);
      case BossMechanicPhase.markHit:
        if (tg == null) return;
        final a = action;
        final dl = a == null ? 0 : hitDelay(a, tg);
        at(FxKind.shatter, tg, dy: -10, color: voidMarkColor, dl: dl);
        txt(tg, -56, 'MARCA ×${fm(e.value)}', voidMarkColor, dl: dl);
      case BossMechanicPhase.markGuarded:
        final a = action;
        final dl = a == null ? 0 : hitDelay(a, e.actorId);
        at(FxKind.ring, e.actorId, dy: -8, color: _healGreen, dl: dl);
        txt(
            e.actorId,
            -56,
            tg == e.actorId ? 'MARCA ANULADA' : '¡PROTEGE LA MARCA!',
            _healGreen,
            dl: dl);
      case BossMechanicPhase.phaseShift:
        final dl = (procDl[e.actorId] ?? action?.dl[e.actorId] ?? 0) + 120;
        final p = position(e.actorId);
        out.add(BattleFx(FxKind.transform,
            x: p.dx,
            y: p.dy,
            color: phaseColor,
            el: FxElement.burn,
            delayMs: dl,
            who: e.actorId));
        out.add(BattleFx(FxKind.flash,
            color: phaseColor, delayMs: dl + BattleFx.transformFlashMs));
        out.add(BattleFx(FxKind.tag,
            x: p.dx,
            y: p.dy - 10,
            text: 'FASE 2',
            color: phaseColor,
            big: true,
            delayMs: dl + BattleFx.transformFlashMs + 60,
            who: e.actorId));
      case BossMechanicPhase.evaded:
        final a = action;
        final dl = a == null ? 0 : hitDelay(a, e.actorId);
        txt(e.actorId, -54, '¡ESQUIVA!', const Color(0xFFB2BEC3), dl: dl);
    }
  }

  for (final e in events) {
    switch (e) {
      case BossMechanicEvent():
        bossMech(e);
      case TurnStartedEvent():
        closeSegment();
        action = null;
      case ActionEvent():
        closeSegment();
        final off = pendingOffset;
        if (off != null) {
          pendingOffset = null;
          segStart = out.length;
          segOffset = off;
        }
        startAction(e);
      case UltimateUsedEvent(:final actorId, :final name):
        final c = state.byId(actorId);
        final sk = c == null ? null : ultimateOf(c);
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
              bulwark: sk?.kind == SkillKind.bulwark ||
                  sk?.kind == SkillKind.support,
              ultId: sk?.id,
              casterClass: c?.classId,
              casterAscension: c?.ascensionId,
              script: ultScriptFor(sk?.id),
            )));
      case DamageEvent():
        damage(e);
      case HealEvent():
        heal(e);
      case StatusAppliedEvent(:final targetId, :final kind, :final stacks):
        txt(
            targetId,
            -46,
            '${statusLetter(kind)}+$stacks${e.weakness ? ' (débil)' : ''}',
            statusColor(kind),
            dl: procDl[targetId] ?? action?.dl[targetId] ?? 0);
      case DelayedEvent(:final targetId):
        final a = action;
        if (!isPlayer(targetId)) {
          txt(targetId, -44, 'RETRASO', _violet, dl: procDl[targetId] ?? 0);
        } else if (a != null && a.enemyUlt) {
          // Engranaje del Fin: todo el grupo se retrasa con el impacto.
          txt(targetId, -44, 'RETRASO', _violet,
              dl: a.dl[targetId] ??
                  a.ult!.lastImpact(math.max(1, a.dl.length)));
        }
      case TurnSkippedEvent(:final actorId, :final cause):
        if (cause == StatusKind.stun) {
          txt(actorId, -34, '¡ATURDIDO!', const Color(0xFFFFEAA7));
        } else {
          txt(actorId, -34, '¡CONGELADO!', _manaBlue);
          aura(actorId, FxElement.freeze);
        }
      case KnockedOutEvent(:final targetId):
        if (isPlayer(targetId)) {
          txt(targetId, -28, 'K.O.', _critRed, dl: action?.dl[targetId] ?? 0);
        } else {
          final p = position(targetId);
          lastKo = targetId;
          // En una ULT, al impactar en él; por un efecto secundario, con él.
          final a = action;
          final dl =
              procDl[targetId] ?? (a?.ult == null ? 0 : a!.dl[targetId] ?? 0);
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
      case ProcEvent():
        proc(e);
      case BuffAppliedEvent():
        buff(e);
      case ShieldEvent():
        shield(e);
      case BreakEvent():
        breakFx(e);
      case EnemyUltWarningEvent(:final actorId, :final name):
        final c = state.byId(actorId);
        final p = position(actorId);
        out.add(BattleFx(FxKind.warn,
            x: p.dx,
            y: p.dy,
            text: '¡El ${c?.name ?? '?'} se prepara para $name!',
            color: enemyUltColor(e.ultId),
            who: actorId));
        at(FxKind.pulse, actorId, dy: -10, color: _critRed, heavy: true);
      case EnemyUltEvent():
        closeSegment();
        enemyUlt(e);
    }
  }
  closeSegment();
  // Fin de las Eras: los buffs del grupo se borran con el último impacto.
  if (wipe != null) {
    final u = ultAction;
    final at = (u?.ult ?? kDefaultUltScript)
            .lastImpact(math.max(1, u?.dl.length ?? 1)) +
        120;
    for (final q in aliveParty()) {
      txt(q.id, -56, 'BUFFS BORRADOS', _violet, dl: at);
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
