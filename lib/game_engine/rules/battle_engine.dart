import 'dart:math' as math;

import '../data/enemies_catalog.dart';
import '../data/game_catalog.dart';
import '../data/passive_mechanics.dart' show mechanicById;
import '../data/skills_catalog.dart';
import '../models/battle_command.dart';
import '../models/battle_event.dart';
import '../models/battle_state.dart';
import '../models/enemy_def.dart';
import '../models/passive_mechanic.dart';
import '../models/skill.dart';
import '../models/status.dart';
import 'js_math.dart';
import 'stats_calculator.dart';

/// Fuente de azar: devuelve un número en [0, 1), igual que `Math.random`.
/// Los tests inyectan una secuencia fija para que todo sea reproducible.
typedef RandomSource = double Function();

/// Resultado de un paso del motor: el estado nuevo y lo que pasó, en orden.
class BattleStep {
  final BattleState state;
  final List<BattleEvent> events;
  const BattleStep(this.state, this.events);
}

/// Motor de combate por timeline — puerto de `startBattle`, `nextTurn`,
/// `statusTick`, `addStatus`, `enemyAct`, `hurt`, `dmgEnemy`, `battleCmd`
/// y `checkEnd` del prototipo. Reglas en docs/specs/combat.md.
///
/// Dart puro y sin estado propio: cada método recibe un [BattleState],
/// trabaja sobre una copia y devuelve el estado nuevo. Quien lo usa (el
/// host en P2P) maneja los tiempos: llama a [nextTurn] cuando no hay
/// turno en curso, a [enemyTurn] si le toca a un enemigo, y espera un
/// [command] (o [timeout]) si le toca a un jugador.
class BattleEngine {
  BattleEngine({
    required this.stats,
    this.catalog = GameCatalog.standard,
    RandomSource? random,
    this.breakEnabled = true,
    this.enemyUltsEnabled = true,
  }) : _random = random ?? math.Random().nextDouble;

  final StatsCalculator stats;
  final GameCatalog catalog;
  final RandomSource _random;

  /// Barra de quiebre de los enemigos (docs/specs/break_and_enemy_ults.md
  /// § 1). Los tests angostos pueden apagarla.
  final bool breakEnabled;

  /// ULT de jefes y élites (§ 2).
  final bool enemyUltsEnabled;

  // ---- quiebre: llenado por tipo de acción ----
  static const breakAttack = 1.0;
  static const breakPhysicalSkill = 1.3;
  static const breakMagicalSkill = 0.8;
  static const breakUltimate = 2.0;
  static const breakDual = 1.5;

  /// Daño secundario de notables (rebotes, explosiones, eco, reflejo,
  /// ataque gratis).
  static const breakSecondary = 0.5;
  static const breakCrit = 1.5;

  /// Aturdir / congelar aplicado por el grupo.
  static const breakStatusFlat = 15.0;

  /// Baja al empezar el turno del enemigo (fracción del umbral).
  static const breakDecay = 0.10;

  /// Turnos del grupo con +50% de daño.
  static const vulnerableTurns = 2;
  static const vulnerableBonus = 0.5;

  /// Élite: umbral × 1.5.
  static const eliteBreak = 1.5;

  // ---- ULT enemiga ----
  /// Carga por turno propio.
  static const enemyUltPerTurn = 25.0;

  /// Carga por vida perdida: +1 por cada 1% (= 100 × fracción).
  static const enemyUltPerHp = 100.0;

  /// Carga con la que empiezan jefes y élites (la primera ULT llega
  /// hacia su 3.er turno).
  static const enemyUltStart = 40.0;

  static const freezeSlowPerStack = 0.12;
  static const enemyCritMultiplier = 1.5;
  static const maxBonusDefense = 12;
  static const dualMpCost = 4;

  /// Tope de efectos disparados por el árbol en un paso del motor
  /// (passive_tree_v2.md § 5, regla 4).
  static const maxProcsPerStep = 64;

  /// Tiempo entre turnos (`IVa`): 100 / velocidad efectiva. Los buffs de
  /// velocidad del árbol (Frenesí) suben la velocidad efectiva.
  double interval(Combatant a) =>
      100 /
      (a.speed *
          (1 + a.effectTotal(BuffStat.speed)) *
          (1 - freezeSlowPerStack * a.stacks(StatusKind.freeze)));

  // ------------------------------------------------------------------
  // API pública
  // ------------------------------------------------------------------

  BattleStep start({
    required List<BattlePartyMember> party,
    required List<String> enemyTypes,
    bool elite = false,
    String? triggeredBy,
  }) {
    final mult = 0.55 + 0.45 * party.length;
    final first = catalog.enemies[enemyTypes.first]!;

    final enemies = <Combatant>[];
    for (var i = 0; i < enemyTypes.length; i++) {
      final d = catalog.enemies[enemyTypes[i]]!;
      final el = elite && i == 0;
      final hp = jsRound(d.hp * mult * (el ? 2.6 : 1));
      final ultId = el ? kEliteUltId : d.ultId;
      enemies.add(Combatant(
        id: 'e$i',
        name: el ? '${d.name} Élite' : d.name,
        isPlayer: false,
        hp: hp,
        maxHp: hp,
        speed: d.speed * (el ? 1.1 : 1),
        attack: jsRound(d.attack * (el ? 1.35 : 1)),
        critChance: el ? 0.15 : (d.boss ? 0.12 : 0.08),
        enemyType: d.id,
        elite: el,
        boss: d.boss,
        areaAttack: d.areaAttack,
        pierce: d.pierce,
        inflicts: d.inflicts,
        breakBase: breakEnabled
            ? d.breakMax * mult * (el ? eliteBreak : 1)
            : 0,
        ultId: enemyUltsEnabled && catalog.enemyUlts.containsKey(ultId)
            ? ultId
            : null,
        ult: enemyUltsEnabled && catalog.enemyUlts.containsKey(ultId)
            ? enemyUltStart
            : 0,
        // Con la velocidad base, como el prototipo (IVa(d)).
        nextTurn: (100 / d.speed) * (0.35 + _random() * 0.6),
      ));
    }

    final players = <Combatant>[];
    for (final m in party) {
      final c = _playerCombatant(m);
      c.nextTurn =
          interval(c) * (triggeredBy == m.id ? 0.2 : 0.3 + _random() * 0.5);
      players.add(c);
    }

    final state = BattleState(
      party: players,
      enemies: enemies,
      boss: first.boss,
      elite: elite,
      log: first.boss
          ? '¡Jefe: ${first.name}!'
          : elite
              ? '¡ÉLITE: ${first.name} Élite! (opcional, mucho más fuerte)'
              : '¡Emboscada!',
    );
    return BattleStep(state, const []);
  }

  /// Le da el turno al próximo actor y procesa sus estados alterados.
  BattleStep nextTurn(BattleState state) {
    final t = _Turn(this, state.copy());
    t.nextTurn();
    return t.result;
  }

  /// Hace actuar al enemigo que tiene el turno. `null` si no le toca a
  /// un enemigo.
  BattleStep? enemyTurn(BattleState state) {
    final cur = state.current;
    if (state.ended || cur == null || cur.isPlayer) return null;
    final t = _Turn(this, state.copy());
    final e = t.state.current!;
    if (e.alive) {
      t.enemyAct(e);
      t.tickEffects(e);
      e.nextTurn = t.state.clock + interval(e);
    }
    t.endTurn();
    return t.result;
  }

  /// El jugador [playerId] actúa. `null` si el comando no es válido
  /// (no es su turno, no le alcanza el MP, etc.): el estado no cambia.
  BattleStep? command(BattleState state, String playerId, BattleCommand cmd) {
    final cur = state.current;
    if (state.ended ||
        cur == null ||
        !cur.isPlayer ||
        cur.id != playerId ||
        !cur.alive) {
      return null;
    }
    final t = _Turn(this, state.copy());
    return t.command(t.state.current!, cmd) ? t.result : null;
  }

  /// Se le acabó el tiempo al jugador de turno: se defiende solo.
  BattleStep? timeout(BattleState state) {
    final cur = state.current;
    if (state.ended || cur == null || !cur.isPlayer) return null;
    final t = _Turn(this, state.copy());
    final p = t.state.current!;
    t.events.add(ActionEvent(p.id, BattleActionKind.defend));
    p.defending = true;
    t.tickEffects(p);
    p.nextTurn = t.state.clock + interval(p);
    t.state.log = 'Tiempo agotado: ${p.name} se defiende automáticamente';
    t.endTurn();
    return t.result;
  }

  /// Un jugador llega a mitad de batalla (`addPlayer` con `S.battle`):
  /// entra con su vida/maná y su primer turno en `reloj + IV`. Si ya
  /// estaba, no cambia nada.
  BattleStep join(BattleState state, BattlePartyMember member) {
    final s = state.copy();
    if (s.ended || s.party.any((c) => c.id == member.id)) {
      return BattleStep(s, const []);
    }
    final c = _playerCombatant(member);
    c.nextTurn = s.clock + interval(c);
    s.party.add(c);
    return BattleStep(s, const []);
  }

  /// Un jugador se va de la sala en plena batalla: sale del timeline y,
  /// si tenía el turno, el turno queda libre.
  BattleStep leave(BattleState state, String playerId) {
    final s = state.copy();
    s.party.removeWhere((c) => c.id == playerId);
    if (s.currentId == playerId) s.currentId = null;
    return BattleStep(s, const []);
  }

  // ------------------------------------------------------------------
  // Jugadores
  // ------------------------------------------------------------------

  Combatant _playerCombatant(BattlePartyMember m) {
    final cls = catalog.classes[m.build.classId]!;
    final w = m.build.equippedWeapon;
    final skills = [...cls.kitSkillIds, ...w.skillIds];
    // Habilidades trasladadas por fusión (loot v2) y la fusión vieja.
    for (final extra in [
      ...?m.build.item?.extraSkills,
      if (m.fusedSkillId != null) m.fusedSkillId!,
    ]) {
      if (catalog.skills.containsKey(extra) && !skills.contains(extra)) {
        skills.add(extra);
      }
    }
    final c = Combatant(
      id: m.id,
      name: m.name,
      isPlayer: true,
      hp: 0,
      maxHp: 1,
      speed: 1,
      attack: 1,
      critChance: 0,
      pierceWeakness: cls.pierceWeakness,
      statusWeakness: cls.statusWeakness,
      stunOnAttackChance: cls.stunOnAttackChance,
      build: m.build.withBonusDefense(0),
      classId: cls.id,
      weaponType: w.type,
      skillIds: skills,
      potions: m.potions,
      ethers: m.ethers,
      ult: m.ult,
    );
    _refreshStats(c);
    c.hp = math.min(m.hp ?? c.maxHp, c.maxHp);
    c.mp = math.min(m.mp ?? c.maxMp.toDouble(), c.maxMp.toDouble());
    return c;
  }

  /// `stats(p)` dentro de la batalla: recalcula con el bonus de DEF actual.
  void _refreshStats(Combatant c) {
    final d = stats.calculate(c.build!.withBonusDefense(c.bonusDefense));
    c
      ..maxHp = d.maxHp
      ..maxMp = d.maxMp
      ..speed = d.speed
      ..attack = d.attack
      ..magic = d.magic
      ..critChance = d.critChance
      ..critMultiplier = d.critMultiplier
      ..defense = d.defense
      ..defensePercent = d.defensePercent
      ..ultChargeBonus = d.ultChargeBonus
      ..healBonus = d.healBonus
      ..statusBonus = Map.of(d.statusBonus)
      ..keystones = Set.of(d.keystones)
      ..mechanics = Set.of(d.mechanics)
      ..lifeSteal = d.lifeSteal
      ..regenPerTurn = d.regenPerTurn
      ..statusResist = d.statusResist
      ..healReceived = d.healReceived
      ..hp = math.min(c.hp, d.maxHp)
      ..mp = math.min(c.mp, d.maxMp.toDouble());
  }
}

class _Hit {
  final int damage;
  final bool critical;
  final Combatant target;

  /// Multiplicadores del árbol que entraron en el golpe (`× 1.15 Marca`).
  final List<String> mods;
  const _Hit(this.damage, this.critical, this.target, [this.mods = const []]);
}

class _Hurt {
  final int damage;
  final bool critical;
  final double pierce;
  final double defensePercent;
  const _Hurt(this.damage, this.critical, this.pierce, this.defensePercent);
}

/// Contexto de una acción de jugador para el sistema de disparadores del
/// árbol v2 (passive_tree_v2.md § 5): qué acción es y qué efectos quedan
/// diferidos para después de los golpes primarios.
class _Action {
  SkillDef? skill;
  bool ultimate = false;

  /// Acción de daño a un solo objetivo (ataque, habilidad o ULT).
  bool single = false;
  Combatant? mainTarget;
  _Hit? mainHit;

  /// Daño base de la habilidad (para Eco Arcano) y bonus de su estado.
  double skillBase = 0;
  int skillStatusBonus = 0;

  /// Mecánicas ya disparadas en esta acción (`id` o `id|objetivo`).
  final fired = <String>{};

  double chain = 0;
  PassiveMechanic? chainSource;
  (Combatant, int, PassiveMechanic)? explosion;
  (double, PassiveMechanic)? repeat;
  PassiveMechanic? freeAttack;
  bool killed = false;
  bool extraTurn = false;

  /// Factor del próximo turno (Sed de Sangre: 0.5).
  double turnFactor = 1;

  /// Llenado de la barra de quiebre por punto de daño de los golpes
  /// primarios (ataque 1.0, habilidad física 1.3, mágica 0.8, ULT 2.0,
  /// dúo 1.5).
  double breakFactor = BattleEngine.breakAttack;
}

/// Un paso del motor sobre una copia del estado. Equivale al contexto
/// global (`S.battle`, `DEALT`, `ATT`) que el prototipo usaba durante
/// un `battleCmd`.
class _Turn {
  _Turn(this.engine, this.state);

  final BattleEngine engine;
  final BattleState state;
  final events = <BattleEvent>[];

  // `DEALT` / `DEALT_MHP` / `ATT` del prototipo.
  int _dealt = 0;
  int _dealtMaxHp = 1;
  Combatant? _attacker;

  /// Acción de jugador en curso (disparadores del árbol).
  _Action? _act;

  /// Efectos disparados que se agregan al log, con su origen.
  final _notes = <String>[];
  int _procBudget = BattleEngine.maxProcsPerStep;

  /// Enemigos quebrados en este paso (su vulnerabilidad empieza a
  /// contar en el próximo turno del grupo).
  final _brokenNow = <String>{};

  BattleStep get result => BattleStep(state, List.unmodifiable(events));

  double _rand() => engine._random();
  double _iv(Combatant c) => engine.interval(c);
  Iterable<Combatant> get _aliveParty => state.party.where((p) => p.alive);

  /// Agrega los efectos disparados a la línea del log.
  void _flush() {
    if (_notes.isEmpty) return;
    state.log = state.log.isEmpty
        ? _notes.join(' · ')
        : '${state.log} · ${_notes.join(' · ')}';
    _notes.clear();
  }

  // ---------------- turnos ----------------

  void nextTurn() {
    if (state.ended) return;
    Combatant? best;
    for (final c in [...state.party, ...state.enemies]) {
      if (c.alive && (best == null || c.nextTurn < best.nextTurn)) best = c;
    }
    if (best == null) return;

    state.clock = math.max(state.clock, best.nextTurn);
    state.currentId = best.id;
    events.add(TurnStartedEvent(best.id));
    if (best.isPlayer) {
      best.defending = false;
      best.protecting = false;
      best.extraTurn = best.extraTurn == 1 ? 2 : 0;
      state.log = 'Turno de ${best.name}';
    } else {
      _decayBreak(best);
    }
    var (skip, text) = _statusTick(best);
    if (!skip && best.alive && best.breakSkip) {
      // Quebrado: pierde su turno (como aturdido).
      skip = true;
      best.breakSkip = false;
      events.add(BreakEvent(
          best.id, BreakPhase.skipped, best.breakGauge, best.breakMax));
      final t = '${best.name} está QUEBRADO y pierde su turno';
      text = text == null ? t : '$text · $t';
    }
    if (text != null) state.log = text;
    // Regeneración del arma (afijo `del Renacer`, loot.md § 12).
    if (best.alive && best.isPlayer && best.regenPerTurn > 0 &&
        best.hp < best.maxHp) {
      final h = math.max(1, jsRound(best.maxHp * best.regenPerTurn));
      _heal(best, h);
      _notes.add('${best.name} regenera $h HP (arma)');
    }
    if (best.alive) _fire(ProcTrigger.onTurnStart, best);
    if ((!best.alive || skip) && best.isPlayer) _tickVulnerable();
    _flush();
    if (!best.alive || skip) {
      if (skip) {
        tickEffects(best);
        best.nextTurn = state.clock + _iv(best);
      }
      state.currentId = null;
      _checkEnd();
    }
  }

  void endTurn() {
    final cur = state.current;
    if (cur != null && cur.isPlayer) _tickVulnerable();
    _flush();
    state.currentId = null;
    _checkEnd();
  }

  /// Fin del turno de [c]: descuenta 1 turno a sus efectos con duración
  /// (los aplicados en este mismo turno empiezan a contar desde el
  /// próximo) y quita los que llegan a 0.
  void tickEffects(Combatant c) {
    if (c.effects.isEmpty) return;
    final next = <TimedEffect>[];
    for (final e in c.effects) {
      if (e.fresh) {
        next.add(e.copyWith(fresh: false));
      } else if (e.turns > 1) {
        next.add(e.copyWith(turns: e.turns - 1));
      }
    }
    c.effects = next;
  }

  void _checkEnd() {
    if (state.ended) return;
    if (state.enemies.every((e) => !e.alive)) {
      var xp = 0, credits = 0;
      for (final e in state.enemies) {
        final d = engine.catalog.enemies[e.enemyType]!;
        final m = e.elite ? 3 : 1;
        xp += d.xp * m;
        credits += d.credits * m;
      }
      state
        ..outcome = BattleOutcome(victory: true, xp: xp, credits: credits)
        ..currentId = null
        ..log = '¡Victoria! +$xp XP · +$credits créditos para cada uno';
      events.add(BattleEndedEvent(true, xp, credits));
    } else if (state.party.every((p) => !p.alive)) {
      state
        ..outcome = const BattleOutcome(victory: false)
        ..currentId = null
        ..log = 'El equipo ha caído…';
      events.add(const BattleEndedEvent(false, 0, 0));
    }
  }

  // ---------------- estados ----------------

  /// Alma de Hielo: algún jugador en pie con la keystone.
  bool get _almaHielo =>
      state.party.any((p) => p.alive && p.keystones.contains('almaHielo'));

  /// `statusTick`: devuelve (pierde el turno, texto para el log).
  (bool, String?) _statusTick(Combatant a) {
    final parts = <String>[];
    var total = 0;

    final burn = a.stacks(StatusKind.burn);
    if (burn > 0) {
      final d = math.max(1, math.min(8 * burn, jsRound(a.maxHp * 0.04 * burn)));
      total += d;
      parts.add('Quemadura $d');
      a.statuses[StatusKind.burn] = burn ~/ 2;
    }
    final poison = a.stacks(StatusKind.poison);
    if (poison > 0) {
      final d =
          math.max(1, math.min(5 * poison, jsRound(a.maxHp * 0.03 * poison)));
      total += d;
      parts.add('Veneno $d');
      a.statuses[StatusKind.poison] = poison - 1;
    }
    final holy = a.stacks(StatusKind.holy);
    if (holy > 0) {
      final d = 5 * holy;
      total += d;
      parts.add('Sagrado $d');
      a.holyTurns = (a.holyTurns == 0 ? 1 : a.holyTurns) - 1;
      if (a.holyTurns <= 0) a.statuses[StatusKind.holy] = 0;
    }

    String? healText;
    final regen = a.stacks(StatusKind.regen);
    if (regen > 0 && a.alive) {
      final hh = jsRound(a.maxHp * 0.05);
      final mm = jsRound(a.maxMp * 0.05);
      a.hp = math.min(a.maxHp, a.hp + hh);
      if (a.maxMp > 0) a.mp = math.min(a.maxMp.toDouble(), a.mp + mm);
      a.statuses[StatusKind.regen] = regen - 1;
      healText = '${a.name} regenera +$hh HP${mm > 0 ? ' +$mm MP' : ''}';
      events.add(HealEvent(a.id, hh));
      if (mm > 0) events.add(HealEvent(a.id, mm, mana: true));
    }

    if (total > 0) {
      _chargeUlt(a, math.min(total, a.hp));
      a.hp = math.max(0, a.hp - total);
      events.add(DamageEvent(a.id, total,
          fromStatus: true,
          statusSource: burn > 0
              ? StatusKind.burn
              : poison > 0
                  ? StatusKind.poison
                  : StatusKind.holy));
      if (!a.alive) _knockedOut(a);
    }

    var skip = false;
    var stunned = false;
    var locked = false;
    if (a.stacks(StatusKind.stun) > 0 && a.alive) {
      skip = true;
      stunned = true;
      // Martillo Bendito: el aturdimiento dura un turno más.
      locked = a.hasEffect(BuffStat.stunLock);
      if (locked) {
        a.effects =
            a.effects.where((e) => e.stat != BuffStat.stunLock).toList();
      } else {
        a.statuses[StatusKind.stun] = 0;
      }
      events.add(TurnSkippedEvent(a.id, StatusKind.stun));
    } else if (a.stacks(StatusKind.freeze) >= StatusKind.freeze.maxStacks &&
        a.alive) {
      skip = true;
      a.statuses[StatusKind.freeze] = 0;
      events.add(TurnSkippedEvent(a.id, StatusKind.freeze));
    } else if (a.stacks(StatusKind.freeze) > 0 && (a.isPlayer || !_almaHielo)) {
      a.statuses[StatusKind.freeze] = a.stacks(StatusKind.freeze) - 1;
    }

    final texts = <String>[
      if (total > 0)
        '${a.name} sufre ${parts.join(' + ')} = $total de daño'
            '${a.alive ? '' : ' y cae'}',
      if (healText != null) healText,
      if (skip)
        '${a.name} está ${stunned ? 'ATURDIDO' : 'CONGELADO'} y pierde su turno'
            '${locked ? ' (Martillo Bendito: sigue aturdido 1 turno más)' : ''}',
    ];
    return (skip, texts.isEmpty ? null : texts.join(' · '));
  }

  /// `addStatus`. [source]: quién lo aplica; con [primary] (golpe
  /// primario de su acción) dispara `onStatusApplied`.
  bool _addStatus(Combatant a, StatusApplication st,
      {int bonus = 0, Combatant? source, bool primary = false}) {
    if (!a.alive) return false;
    // Alma de Hielo: no puede aplicar Quemadura.
    if (st.kind == StatusKind.burn &&
        source != null &&
        source.keystones.contains('almaHielo')) {
      return false;
    }
    if (st.chance != null && _rand() >= st.chance!) return false;
    final weak =
        a.isPlayer && a.statusWeakness > 0 && st.kind != StatusKind.regen
            ? a.statusWeakness
            : 0;
    var n = st.stacks + bonus + weak;
    // Resistencia del arma: menos stacks de daño / Congelación (mín. 1).
    if (a.isPlayer &&
        a.statusResist > 0 &&
        (st.kind == StatusKind.burn ||
            st.kind == StatusKind.poison ||
            st.kind == StatusKind.freeze)) {
      n = math.max(1, n - a.statusResist);
    }
    a.statuses[st.kind] = math.min(st.kind.maxStacks, a.stacks(st.kind) + n);
    if (st.kind == StatusKind.holy) a.holyTurns = 3;
    if (st.kind == StatusKind.regen) a.statuses[StatusKind.regen] = 3;
    events.add(StatusAppliedEvent(a.id, st.kind, n, weakness: weak > 0));
    if (source != null && source.isPlayer && !a.isPlayer) {
      if (st.kind == StatusKind.stun || st.kind == StatusKind.freeze) {
        _addBreak(a, BattleEngine.breakStatusFlat);
      }
      if (st.kind == StatusKind.stun && !a.boss) _extendStun(source, a);
      if (primary) {
        _fire(ProcTrigger.onStatusApplied, source, target: a, status: st.kind);
      }
    }
    return true;
  }

  /// Efecto `stunExtend` (Martillo Bendito): modificador, se aplica a
  /// todos los aturdimientos de [source] (también los secundarios).
  void _extendStun(Combatant source, Combatant target) {
    for (final m in _mechanicsOf(source)) {
      for (final fx in m.effects) {
        if (fx.kind != ProcEffectKind.stunExtend) continue;
        if (target.hasEffect(BuffStat.stunLock) || !_spend()) return;
        target.effects = [
          ...target.effects,
          TimedEffect(
              sourceId: m.id,
              stat: BuffStat.stunLock,
              value: 1,
              turns: fx.turns,
              ownerId: source.id),
        ];
        events.add(ProcEvent(source.id, m.id, targetId: target.id));
        events.add(
            BuffAppliedEvent(target.id, m.id, BuffStat.stunLock, 1, fx.turns));
        _notes.add('${m.name}: ${target.name} queda aturdido 1 turno más');
        return;
      }
    }
  }

  void _heal(Combatant q, int amount) {
    // Curación recibida del arma (afijo `de la Gracia`).
    if (q.isPlayer && q.healReceived != 0) {
      amount = math.max(1, jsRound(amount * (1 + q.healReceived)));
    }
    q.hp = math.min(q.maxHp, q.hp + amount);
    events.add(HealEvent(q.id, amount));
  }

  // ---------------- daño ----------------

  /// `hurt`: enemigo → jugador. Los escudos del árbol absorben antes que
  /// la vida; [from] es el enemigo que pega (Contraataque, Represalia).
  _Hurt _hurt(Combatant p, double base, double critChance, bool pierce,
      {Combatant? from}) {
    final crit = _rand() < critChance;
    final pmul = pierce ? p.pierceWeakness : 1.0;
    final defp = p.defensePercent;
    final dmg = math.max(
      1,
      jsRound(base *
          (crit ? BattleEngine.enemyCritMultiplier : 1) *
          pmul *
          (p.defending ? 0.5 : 1) *
          (1 - defp)),
    );
    final absorbed = _absorb(p, dmg);
    final taken = dmg - absorbed;
    if (taken > 0) {
      p.ult =
          math.min(100, p.ult + taken / p.maxHp * 110 * (1 + p.ultChargeBonus));
    }
    p.hp = math.max(0, p.hp - taken);
    events.add(DamageEvent(p.id, taken,
        critical: crit,
        critMultiplier: BattleEngine.enemyCritMultiplier,
        pierceMultiplier: pmul));
    if (!p.alive) events.add(KnockedOutEvent(p.id));
    if (from != null && p.alive) {
      _fire(ProcTrigger.onHitTaken, p, target: from, amount: dmg);
    }
    return _Hurt(dmg, crit, pmul, defp);
  }

  /// Los escudos de [p] absorben hasta [dmg]; devuelve cuánto absorbieron.
  int _absorb(Combatant p, int dmg) {
    if (!p.hasEffect(BuffStat.shield)) return 0;
    var left = dmg;
    final next = <TimedEffect>[];
    for (final e in p.effects) {
      if (e.stat != BuffStat.shield || left <= 0) {
        next.add(e);
        continue;
      }
      final v = e.value.round();
      final use = math.min(v, left);
      left -= use;
      if (v - use > 0) next.add(e.copyWith(value: (v - use).toDouble()));
    }
    p.effects = next;
    final absorbed = dmg - left;
    if (absorbed > 0) {
      events.add(ShieldEvent(p.id, absorbed, absorbed: true));
      _notes.add('escudo de ${p.name} absorbe $absorbed');
    }
    return absorbed;
  }

  /// Bonus de las condiciones del árbol de [a] (Último Aliento, Fractura,
  /// Punto Débil) sobre [stat], contra [target] si hay.
  double _conditionBonus(Combatant a, BuffStat stat, [Combatant? target]) {
    var total = 0.0;
    for (final m in _mechanicsOf(a)) {
      final ok = switch (m.trigger) {
        ProcTrigger.whileLowHealth => a.hp < a.maxHp * m.threshold,
        ProcTrigger.vsStatus =>
          target != null && m.status != null && target.stacks(m.status!) > 0,
        ProcTrigger.vsMarked =>
          target != null && target.hasEffect(BuffStat.damageTaken),
        ProcTrigger.always => true,
        _ => false,
      };
      if (!ok) continue;
      for (final fx in m.effects) {
        if (fx.kind == ProcEffectKind.statBonus && fx.stat == stat) {
          total += fx.value;
        }
      }
    }
    return total;
  }

  /// Bonus al llenado de quiebre de las pasivas de arma de [a] contra
  /// [target] (Rompehielos, Grieta).
  double _breakBonus(Combatant a, Combatant target) {
    var total = 0.0;
    for (final m in _mechanicsOf(a)) {
      final ok = switch (m.trigger) {
        ProcTrigger.vsStatus =>
          m.status != null && target.stacks(m.status!) > 0,
        ProcTrigger.vsMarked => target.hasEffect(BuffStat.damageTaken),
        ProcTrigger.whileLowHealth => a.hp < a.maxHp * m.threshold,
        ProcTrigger.always => true,
        _ => false,
      };
      if (!ok) continue;
      for (final fx in m.effects) {
        if (fx.kind == ProcEffectKind.breakBonus) total += fx.value;
      }
    }
    return total;
  }

  /// ATQ efectivo: con buffs (Represalia) y Último Aliento.
  int _atk(Combatant p) {
    final b =
        p.effectTotal(BuffStat.attack) + _conditionBonus(p, BuffStat.attack);
    return b == 0 ? p.attack : math.max(1, jsRound(p.attack * (1 + b)));
  }

  /// Texto de la fuente de daño con ATQ efectivo (`ATQ 36 (30 +20%)`).
  String _atkText(Combatant p) {
    final a = _atk(p);
    if (a == p.attack) return 'ATQ ${p.attack}';
    final pct = jsRound((a / p.attack - 1) * 100);
    return 'ATQ $a (${p.attack} ${pct >= 0 ? '+' : ''}$pct%)';
  }

  /// `dmgEnemy`: jugador → enemigo. Con [primary] (golpe de la acción,
  /// no de una mecánica) dispara `onHit` / `onCrit`.
  _Hit _damageEnemy(Combatant e, double base, double critChance,
      {bool primary = true, bool single = false}) {
    final a = _attacker;
    final cm = a?.critMultiplier ?? 1.5;
    var chance = critChance;
    var mult = 1.0;
    final mods = <String>[];
    if (a != null) {
      chance += _conditionBonus(a, BuffStat.crit, e);
      if (a.keystones.contains('danza')) chance = math.min(chance, 0.40);
      final dmgBonus = _conditionBonus(a, BuffStat.damage, e);
      if (dmgBonus != 0) {
        mult *= 1 + dmgBonus;
        mods.add('× ${fm(1 + dmgBonus)} Fractura');
      }
      if (single && primary && a.keystones.contains('cadena')) {
        mult *= 0.8;
        mods.add('× 0.8 Cadena Infinita');
      }
    }
    final taken = e.effectTotal(BuffStat.damageTaken);
    if (taken != 0) {
      mult *= 1 + taken;
      mods.add('× ${fm(1 + taken)} Marca');
    }
    final vul = e.broken;
    if (vul) {
      mult *= 1 + BattleEngine.vulnerableBonus;
      mods.add('× ${fm(1 + BattleEngine.vulnerableBonus)} QUIEBRE');
    }
    final crit = _rand() < chance;
    final dmg = math.max(1, jsRound(base * (crit ? cm : 1) * mult));
    final breakBonus = a == null ? 0.0 : _breakBonus(a, e);
    final lost = math.min(dmg, e.hp);
    _dealt += lost;
    _dealtMaxHp = math.max(_dealtMaxHp, e.maxHp);
    e.hp = math.max(0, e.hp - dmg);
    events.add(DamageEvent(e.id, dmg,
        critical: crit, critMultiplier: cm, vulnerable: vul));
    if (!e.alive) _knockedOut(e);
    _chargeUlt(e, lost);
    _addBreak(
        e,
        dmg *
            (primary
                ? (_act?.breakFactor ?? BattleEngine.breakAttack)
                : BattleEngine.breakSecondary) *
            (crit ? BattleEngine.breakCrit : 1) *
            (1 + breakBonus));
    final hit = _Hit(dmg, crit, e, mods);
    if (primary && a != null && _act != null) {
      _fire(ProcTrigger.onHit, a, target: e, amount: dmg);
      if (crit) _fire(ProcTrigger.onCrit, a, target: e, amount: dmg);
    }
    return hit;
  }

  /// Daño secundario de una mecánica: sin crítico, solo la Marca del
  /// objetivo. No dispara nada (salvo las muertes).
  int _procDamage(Combatant owner, Combatant e, int amount, String sourceId) {
    if (!e.alive) return 0;
    final taken = e.effectTotal(BuffStat.damageTaken);
    final vul = e.broken;
    final dmg = math.max(
        1,
        jsRound(amount *
            (1 + taken) *
            (vul ? 1 + BattleEngine.vulnerableBonus : 1)));
    final lost = math.min(dmg, e.hp);
    if (owner == _attacker) {
      _dealt += lost;
      _dealtMaxHp = math.max(_dealtMaxHp, e.maxHp);
    }
    e.hp = math.max(0, e.hp - dmg);
    events.add(DamageEvent(e.id, dmg, sourceId: sourceId, vulnerable: vul));
    if (!e.alive) _knockedOut(e);
    _chargeUlt(e, lost);
    _addBreak(e, dmg * BattleEngine.breakSecondary);
    return dmg;
  }

  /// Un actor cae. Si es un enemigo: cuenta para `onKill` de la acción y
  /// dispara `onEnemyDeath` (Plaga) del primer jugador que la tenga.
  void _knockedOut(Combatant c) {
    events.add(KnockedOutEvent(c.id));
    if (c.isPlayer) return;
    _act?.killed = true;
    for (final p in state.party) {
      if (!p.alive) continue;
      if (_mechanicsOf(p).any((m) => m.trigger == ProcTrigger.onEnemyDeath)) {
        _fire(ProcTrigger.onEnemyDeath, p, target: c);
        return;
      }
    }
  }

  /// `dmgLog`: el desglose que ve el jugador. Muestra siempre el
  /// multiplicador de crítico real del atacante.
  String _damageLog(
    String head,
    String source,
    num sourceValue,
    double power,
    List<_Hit> hits, {
    required bool all,
    double tormenta = 1,
  }) {
    final cm = _attacker?.critMultiplier ?? 1.5;
    final formula = '$source × ${fm(power)}'
        '${tormenta != 1 ? ' × ${fm(tormenta)} Tormenta' : ''}';
    if (!all) {
      final r = hits.first;
      return '$head: ${r.damage} = $formula'
          '${r.critical ? ' × ${fm(cm)} CRÍTICO' : ''}'
          '${r.mods.isEmpty ? '' : ' ${r.mods.join(' ')}'}';
    }
    final base = jsRound(sourceValue * power * tormenta);
    final crits = hits.where((h) => h.critical).length;
    final modded = [
      for (final h in hits)
        if (h.mods.isNotEmpty)
          '${h.target.name} ${h.mods.join(' ')} = ${h.damage}',
    ];
    return '$head: $base c/u = $formula'
        '${crits > 0 ? ' ($crits crítico${crits > 1 ? 's' : ''} → ${jsRound(base * cm)})' : ''}'
        '${modded.isEmpty ? '' : ' · ${modded.join(', ')}'}';
  }

  String _statusText(StatusApplication? st, {int bonus = 0}) =>
      st == null ? '' : ' · +${st.stacks + bonus} ${st.kind.label}';

  // ---------------- disparadores del árbol ----------------

  Iterable<PassiveMechanic> _mechanicsOf(Combatant c) sync* {
    for (final id in c.mechanics) {
      final m = mechanicById(id);
      if (m != null) yield m;
    }
  }

  /// Gasta 1 del tope de efectos del paso. `false` si se acabó.
  bool _spend() {
    if (_procBudget <= 0) return false;
    _procBudget--;
    return true;
  }

  bool _passes(PassiveMechanic m, Combatant owner, Combatant? target,
      StatusKind? status) {
    final act = _act;
    final sk = act?.skill;
    final ult = act?.ultimate ?? false;
    final okFilter = switch (m.filter) {
      ProcFilter.any => true,
      ProcFilter.singleTarget => act != null && act.single,
      ProcFilter.magicalSingle =>
        act != null && act.single && sk?.kind == SkillKind.magical,
      ProcFilter.magicalSkill =>
        sk != null && sk.kind == SkillKind.magical && !ult,
      ProcFilter.areaSkill =>
        sk != null && sk.dealsDamage && sk.allTargets && !ult,
      ProcFilter.defending => owner.defending,
      ProcFilter.guardSkill => sk != null &&
          (sk.kind == SkillKind.taunt ||
              sk.kind == SkillKind.protect ||
              sk.kind == SkillKind.guard),
    };
    if (!okFilter) return false;
    final st = m.status;
    if (st == null) return true;
    return switch (m.trigger) {
      ProcTrigger.onStatusApplied => status == st,
      ProcTrigger.onHit => target != null && target.stacks(st) >= m.minStacks,
      ProcTrigger.onEnemyDeath => target != null && target.stacks(st) > 0,
      _ => true,
    };
  }

  /// Evalúa las mecánicas de [owner] con disparador [trigger]. [amount]:
  /// daño del golpe, daño recibido o vida curada, según el disparador.
  void _fire(ProcTrigger trigger, Combatant owner,
      {Combatant? target, StatusKind? status, int amount = 0}) {
    if (owner.mechanics.isEmpty) return;
    for (final m in _mechanicsOf(owner).toList()) {
      if (m.trigger != trigger || m.effects.isEmpty) continue;
      if (!_passes(m, owner, target, status)) continue;
      final act = _act;
      if (act != null) {
        final perTarget = target != null && m.effects.any((e) => e.onTarget);
        if (!act.fired.add(perTarget ? '${m.id}|${target.id}' : m.id)) {
          continue;
        }
      }
      if (m.chance < 1 && _rand() >= m.chance) continue;
      if (!_spend()) return;
      for (final fx in m.effects) {
        _applyEffect(m, fx, owner, target, amount);
      }
    }
  }

  String _pct(double v) => '${jsRound(v.abs() * 100)}%';
  String _turns(int n) => '($n turno${n == 1 ? '' : 's'})';

  /// Pone (o renueva) un efecto con duración de [m] sobre [c]. Los
  /// escudos del mismo origen no acumulan: queda el mayor.
  void _giveEffect(Combatant c, Combatant owner, PassiveMechanic m,
      BuffStat stat, double value, int turns) {
    final old = c.effectFrom(m.id, stat);
    final v = stat == BuffStat.shield && old != null
        ? math.max(old.value, value)
        : value;
    c.effects = [
      for (final e in c.effects)
        if (!(e.sourceId == m.id && e.stat == stat)) e,
      TimedEffect(
        sourceId: m.id,
        stat: stat,
        value: v,
        turns: turns,
        ownerId: owner.id,
        fresh: state.currentId == c.id,
      ),
    ];
  }

  void _shield(
      Combatant c, Combatant owner, PassiveMechanic m, int amount, int turns) {
    if (amount <= 0 || !c.alive) return;
    events.add(ProcEvent(owner.id, m.id, targetId: c.id));
    _giveEffect(c, owner, m, BuffStat.shield, amount.toDouble(), turns);
    events.add(ShieldEvent(c.id, amount));
    _notes.add('${m.name}: escudo de $amount a ${c.name} ${_turns(turns)}');
  }

  void _applyEffect(PassiveMechanic m, ProcEffect fx, Combatant owner,
      Combatant? target, int amount) {
    final act = _act;
    switch (fx.kind) {
      case ProcEffectKind.buffSelf:
        events.add(ProcEvent(owner.id, m.id));
        _giveEffect(owner, owner, m, fx.stat!, fx.value, fx.turns);
        events.add(
            BuffAppliedEvent(owner.id, m.id, fx.stat!, fx.value, fx.turns));
        _notes.add('${m.name}: +${_pct(fx.value)} ${fx.stat!.label} '
            '${_turns(fx.turns)}');
      case ProcEffectKind.debuffTarget:
      case ProcEffectKind.markTarget:
        if (target == null || !target.alive) return;
        if (fx.kind == ProcEffectKind.markTarget &&
            target.hasEffect(fx.stat!)) {
          return;
        }
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        _giveEffect(target, owner, m, fx.stat!, fx.value, fx.turns);
        events.add(
            BuffAppliedEvent(target.id, m.id, fx.stat!, fx.value, fx.turns));
        _notes.add(fx.kind == ProcEffectKind.markTarget
            ? '${m.name}: ${target.name} recibe +${_pct(fx.value)} de daño '
                '${_turns(fx.turns)}'
            : '${m.name}: ${target.name} ${fx.value < 0 ? '−' : '+'}'
                '${_pct(fx.value)} ${fx.stat!.label} ${_turns(fx.turns)}');
      case ProcEffectKind.advanceTurn:
        if (act == null) return;
        events.add(ProcEvent(owner.id, m.id));
        act.turnFactor = math.min(act.turnFactor, 1 - fx.value);
        _notes.add('${m.name}: tu próximo turno llega ${_pct(fx.value)} antes');
      case ProcEffectKind.extraTurn:
        if (act == null || owner.extraTurn == 2 || act.extraTurn) return;
        events.add(ProcEvent(owner.id, m.id));
        act.extraTurn = true;
        _notes.add('${m.name}: ¡turno extra!');
      case ProcEffectKind.healSelf:
        if (!owner.alive) return;
        final h = math.max(1, jsRound(owner.maxHp * fx.value));
        events.add(ProcEvent(owner.id, m.id, targetId: owner.id));
        _heal(owner, h);
        _notes.add('${m.name}: +$h HP');
      case ProcEffectKind.healLowestAlly:
        final q = _lowest(_aliveParty, (c) => c.hp / c.maxHp);
        if (q == null || q.hp >= q.maxHp) return;
        final h = math.max(1, jsRound(q.maxHp * fx.value));
        events.add(ProcEvent(owner.id, m.id, targetId: q.id));
        _heal(q, h);
        _notes.add('${m.name}: ${q.name} +$h HP');
      case ProcEffectKind.chain:
        if (act == null || fx.value <= act.chain) return;
        act
          ..chain = fx.value
          ..chainSource = m;
      case ProcEffectKind.explode:
        if (act == null || act.explosion != null || target == null) return;
        act.explosion = (target, math.max(1, jsRound(amount * fx.value)), m);
      case ProcEffectKind.reflect:
        if (target == null || !target.alive) return;
        final d = math.max(1, jsRound(amount * fx.value));
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        final dealt = _procDamage(owner, target, d, m.id);
        _notes.add('${m.name}: $dealt a ${target.name}');
      case ProcEffectKind.shatterStun:
        if (target == null ||
            !target.alive ||
            target.stacks(StatusKind.freeze) <= 0) {
          return;
        }
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        target.statuses[StatusKind.freeze] = 0;
        _notes.add('${m.name}: ${target.name} pierde la Congelación y queda '
            'aturdido');
        _addStatus(target, const StatusApplication(StatusKind.stun, 1),
            source: owner);
      case ProcEffectKind.delayTarget:
        if (target == null || !target.alive) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        target.nextTurn += _iv(target) * fx.value;
        events.add(DelayedEvent(target.id));
        _notes.add('${m.name}: ${target.name} se retrasa ${_pct(fx.value)}');
      case ProcEffectKind.repeatSkill:
        if (act == null || act.repeat != null) return;
        act.repeat = (fx.value, m);
      case ProcEffectKind.spreadStatus:
        final st = m.status;
        if (target == null || st == null) return;
        final n = target.stacks(st);
        Combatant? dest;
        for (final e in state.enemies) {
          if (e != target && e.alive && (dest == null || e.hp > dest.hp)) {
            dest = e;
          }
        }
        if (n <= 0 || dest == null) return;
        events.add(ProcEvent(owner.id, m.id, targetId: dest.id));
        _addStatus(dest, StatusApplication(st, n), source: owner);
        _notes.add('${m.name}: $n ${st.label} pasan a ${dest.name}');
      case ProcEffectKind.freeAttack:
        if (act == null || act.freeAttack != null) return;
        act.freeAttack = m;
      case ProcEffectKind.shieldHealed:
        if (target == null) return;
        _shield(target, owner, m, jsRound(amount * fx.value), fx.turns);
      case ProcEffectKind.shieldSelf:
        _shield(owner, owner, m, jsRound(owner.maxHp * fx.value), fx.turns);
      case ProcEffectKind.ultCharge:
        events.add(ProcEvent(owner.id, m.id));
        owner.ult = math.min(100, owner.ult + fx.value);
        _notes.add('${m.name}: +${jsRound(fx.value)} carga de ULT');
      case ProcEffectKind.holyDamage:
        if (target == null || !target.alive) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        final dealt = _procDamage(
            owner, target, math.max(1, jsRound(owner.magic * fx.value)), m.id);
        _notes.add('${m.name}: $dealt sagrado a ${target.name} '
            '(MAG ${owner.magic} × ${fm(fx.value)})');
      case ProcEffectKind.extraStacks:
        final st = fx.status ?? m.status;
        if (target == null || !target.alive || st == null) return;
        final n = fx.value.round();
        if (n <= 0) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        _addStatus(target, StatusApplication(st, n), source: owner);
        _notes.add('${m.name}: +$n ${st.label} a ${target.name}');
      case ProcEffectKind.inflict:
        final st = fx.status;
        if (target == null || !target.alive || st == null) return;
        final n = math.max(1, fx.value.round());
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        if (_addStatus(target, StatusApplication(st, n), source: owner)) {
          _notes.add('${m.name}: ${target.name} +$n ${st.label}');
        }
      case ProcEffectKind.stunExtend:
      case ProcEffectKind.statBonus:
      case ProcEffectKind.breakBonus:
        // Modificadores: los aplican `_addStatus`, `_conditionBonus` y
        // `_breakBonus`.
        break;
    }
  }

  /// Resolución diferida de la acción (passive_tree_v2.md § 5, pasos 3-4):
  /// rebote, explosión, eco, ataque gratis y `onKill`.
  void _resolveAction(Combatant p, _Action act) {
    // Rebote / cadena.
    final hit = act.mainHit;
    final src = act.chainSource;
    if (act.chain > 0 && hit != null && src != null && _spend()) {
      final infinite = p.keystones.contains('cadena');
      final hitIds = {hit.target.id};
      final start = state.enemies.indexOf(hit.target);
      var prev = hit.damage.toDouble();
      var frac = act.chain;
      final parts = <String>[];
      for (var k = 1; k < state.enemies.length; k++) {
        final e = state.enemies[(start + k) % state.enemies.length];
        if (!e.alive || hitIds.contains(e.id)) continue;
        final d = math.max(1, jsRound(prev * frac));
        events.add(ProcEvent(p.id, src.id, targetId: e.id));
        parts.add('${_procDamage(p, e, d, src.id)} a ${e.name}');
        hitIds.add(e.id);
        prev = d.toDouble();
        frac = 0.6;
        if (!infinite) break;
      }
      if (parts.isNotEmpty) {
        _notes.add('${src.name}${infinite ? ' (Cadena Infinita)' : ''}: '
            '${parts.join(', ')}');
      }
    }

    // Explosión (Combustión).
    final ex = act.explosion;
    if (ex != null) {
      final (center, d, m) = ex;
      final others =
          state.enemies.where((e) => e != center && e.alive).toList();
      if (others.isNotEmpty) {
        events.add(ProcEvent(p.id, m.id, targetId: center.id));
        final parts = [
          for (final e in others) '${_procDamage(p, e, d, m.id)} a ${e.name}',
        ];
        _notes.add('${m.name}: ${center.name} explota → ${parts.join(', ')}');
      }
    }

    // Eco Arcano.
    final rep = act.repeat;
    final sk = act.skill;
    if (rep != null && sk != null) {
      final (frac, m) = rep;
      final alive = state.enemies.where((e) => e.alive).toList();
      final main = act.mainTarget;
      final targets = sk.allTargets
          ? alive
          : [
              if (main != null && main.alive)
                main
              else if (alive.isNotEmpty)
                alive.first,
            ];
      if (targets.isNotEmpty) {
        events.add(ProcEvent(p.id, m.id));
        final d = math.max(1, jsRound(act.skillBase * frac));
        final parts = <String>[];
        for (final e in targets) {
          parts.add('${_procDamage(p, e, d, m.id)} a ${e.name}');
          final st = sk.status;
          if (st != null && e.alive) {
            _addStatus(e, st, bonus: act.skillStatusBonus, source: p);
          }
        }
        _notes.add('${m.name}: ${sk.name} se repite al ${_pct(frac)} '
            '(${parts.join(', ')})');
      }
    }

    // Viento a Favor.
    final free = act.freeAttack;
    if (free != null) {
      final target =
          _lowest(state.enemies.where((e) => e.alive), (c) => c.hp.toDouble());
      if (target != null) {
        events.add(ProcEvent(p.id, free.id, targetId: target.id));
        events.add(
            ActionEvent(p.id, BattleActionKind.attack, targetId: target.id));
        final h = _damageEnemy(target, _atk(p).toDouble(), p.critChance,
            primary: false);
        _notes.add('${free.name}: ataque gratis → ${target.name}: ${h.damage}'
            '${h.critical ? ' CRÍTICO' : ''}');
      }
    }

    if (act.killed) _fire(ProcTrigger.onKill, p);
  }

  // ---------------- quiebre (docs/specs/break_and_enemy_ults.md § 1) ----

  static double _r1(double v) => (v * 10).round() / 10;

  /// Suma [amount] a la barra de quiebre de [e]; al llegar al umbral,
  /// ¡QUIEBRE!. Quebrado, la barra no se llena.
  void _addBreak(Combatant e, double amount) {
    if (e.isPlayer || !e.alive || !e.hasBreak || e.broken || amount <= 0) {
      return;
    }
    final max = e.breakMax;
    e.breakGauge = math.min(max, _r1(e.breakGauge + amount));
    if (e.breakGauge >= max) {
      _break(e);
    } else {
      events.add(BreakEvent(e.id, BreakPhase.fill, e.breakGauge, max));
    }
  }

  /// Quiebre: pierde su próximo turno, su ULT vuelve a 0 (y se cancela
  /// si la había avisado) y recibe +50% de daño 2 turnos del grupo.
  void _break(Combatant e) {
    final max = e.breakMax;
    final cancelled = e.ultPending;
    e
      ..breakGauge = max
      ..vulnerable = BattleEngine.vulnerableTurns
      ..breakSkip = true
      ..ultPending = false;
    if (e.ultId != null) e.ult = 0;
    _brokenNow.add(e.id);
    events.add(BreakEvent(e.id, BreakPhase.broken, max, max,
        cancelledUlt: cancelled));
    final ult = engine.catalog.enemyUlts[e.ultId];
    _notes.add('¡QUIEBRE! ${e.name}: pierde su turno, +50% de daño'
        '${cancelled && ult != null ? ' · ${ult.name} cancelada' : ''}');
  }

  /// Al empezar su turno, la barra baja 10% del umbral (si no está
  /// quebrado).
  void _decayBreak(Combatant e) {
    if (!e.alive || !e.hasBreak || e.broken || e.breakGauge <= 0) return;
    final max = e.breakMax;
    e.breakGauge =
        math.max(0, _r1(e.breakGauge - max * BattleEngine.breakDecay));
    events.add(BreakEvent(e.id, BreakPhase.decay, e.breakGauge, max));
  }

  /// Terminó un turno del grupo: descuenta la vulnerabilidad de los
  /// quebrados antes de este paso; al llegar a 0 se recuperan (barra a 0
  /// y umbral +25%).
  void _tickVulnerable() {
    for (final e in state.enemies) {
      if (e.vulnerable <= 0 || _brokenNow.contains(e.id)) continue;
      e.vulnerable--;
      if (e.vulnerable > 0) continue;
      e
        ..breakGauge = 0
        ..breaks += 1;
      if (!e.alive) continue;
      events.add(BreakEvent(e.id, BreakPhase.recovered, 0, e.breakMax));
      _notes.add('${e.name} se recupera del quiebre');
    }
  }

  /// Carga de ULT enemiga por vida perdida: +1 cada 2%.
  void _chargeUlt(Combatant e, int lost) {
    if (e.isPlayer || e.ultId == null || e.ultPending || lost <= 0) return;
    e.ult = math.min(100, e.ult + lost / e.maxHp * BattleEngine.enemyUltPerHp);
  }

  // ---------------- enemigos ----------------

  /// `enemyAct`. Con ULT (jefes y élites): con la carga llena avisa (pierde
  /// la acción) y en su siguiente turno la lanza.
  void enemyAct(Combatant e) {
    final alive = _aliveParty.toList();
    if (alive.isEmpty) return;
    final ult = engine.catalog.enemyUlts[e.ultId];
    if (ult != null) {
      if (e.ultPending) {
        _enemyUlt(e, ult, alive);
        return;
      }
      if (e.ult >= 100) {
        e.ultPending = true;
        events.add(EnemyUltWarningEvent(e.id, ult.id, ult.name));
        state.log = '¡El ${e.name} se prepara para ${ult.name}! · '
            'Quiébralo, defiéndete o protégete';
        return;
      }
      e.ult = math.min(100, e.ult + BattleEngine.enemyUltPerTurn);
    }
    e.actions++;

    final taunter = alive.where((p) => p.taunt > 0).firstOrNull;
    final pick0 = taunter ?? alive[(_rand() * alive.length).floor()];
    if (taunter != null) taunter.taunt--;
    final protector = alive.where((p) => p.protecting).firstOrNull;
    Combatant victim(Combatant q) =>
        protector != null && q != protector ? protector : q;
    final pick = victim(pick0);
    final protText = protector != null && pick0 != protector
        ? ' (Protección: ${protector.name} recibe el golpe dirigido a ${pick0.name})'
        : '';
    final inf = e.inflicts;
    final area = e.areaAttack && e.actions % 3 == 0;
    events.add(ActionEvent(
      e.id,
      area
          ? BattleActionKind.enemyArea
          : e.boss && e.actions % 4 == 0
              ? BattleActionKind.enemyHeavy
              : BattleActionKind.enemyAttack,
      targetId: area ? null : pick.id,
      allTargets: area,
    ));

    // Debilitar: el enemigo pega con menos ATQ.
    final atkMod = e.effectTotal(BuffStat.attack);
    final atk =
        atkMod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + atkMod)));
    final atkText = atkMod == 0 ? 'ATQ ${e.attack}' : 'ATQ $atk (debilitado)';

    String detail(_Hurt h, double mult, Combatant p) => '$atkText'
        '${mult != 1 ? ' × ${fm(mult)}' : ''}'
        '${h.critical ? ' × ${fm(BattleEngine.enemyCritMultiplier)} CRÍTICO' : ''}'
        '${h.pierce > 1 ? ' × ${fm(h.pierce)} perforante' : ''}'
        '${p.defending ? ' × ½ defender' : ''}'
        '${h.defensePercent > 0 ? ' − ${jsRound(h.defensePercent * 100)}% DEF' : ''}';
    String infText(Combatant p) => p.alive && inf != null
        ? _statusText(inf,
            bonus: inf.kind == StatusKind.regen ? 0 : p.statusWeakness)
        : '';
    final tauntText = taunter != null ? ' (provocado)' : '';
    // Guardián: el protector recibió un golpe dirigido a un aliado.
    void guarded(Combatant p, Combatant p0) {
      if (p != p0 && p.alive) _fire(ProcTrigger.onProtectHit, p, target: e);
    }

    if (area) {
      final parts = <String>[];
      for (final p0 in alive) {
        final p = victim(p0);
        if (!p.alive) {
          parts.add('${p0.name} 0');
          continue;
        }
        final h = _hurt(p, atk * 0.7, e.critChance, e.pierce, from: e);
        guarded(p, p0);
        p.nextTurn += _iv(p) * 0.4;
        if (inf != null) _addStatus(p, inf);
        events.add(DelayedEvent(p.id));
        final who = p != p0 ? '${p.name} (por ${p0.name})' : p.name;
        parts.add('$who ${h.damage}${h.critical ? '!' : ''}');
      }
      state.log = '${e.name} · Colapso Temporal (todos, $atkText × 0.7, '
          'retrasa): ${parts.join(', ')}';
    } else if (e.boss && e.actions % 4 == 0) {
      final h = _hurt(pick, atk * 1.6, e.critChance, e.pierce, from: e);
      guarded(pick, pick0);
      if (inf != null) _addStatus(pick, inf);
      state.log = '${e.name} · Golpe Brutal → ${pick.name}: ${h.damage} = '
          '${detail(h, 1.6, pick)}${infText(pick)}$tauntText$protText';
    } else {
      final h = _hurt(pick, atk.toDouble(), e.critChance, e.pierce, from: e);
      guarded(pick, pick0);
      if (inf != null) _addStatus(pick, inf);
      final explain = h.critical ||
          pick.defending ||
          h.pierce > 1 ||
          h.defensePercent > 0 ||
          atkMod != 0;
      state.log = '${e.name} → ${pick.name}: ${h.damage}'
          '${explain ? ' = ${detail(h, 1, pick)}' : ''}'
          '${infText(pick)}$tauntText$protText';
    }
  }

  /// La ULT de [e] (docs/specs/break_and_enemy_ults.md § 2): Defender,
  /// Protección, Provocar y escudos aplican como en un golpe normal.
  void _enemyUlt(Combatant e, EnemyUltDef ult, List<Combatant> alive) {
    e
      ..ultPending = false
      ..ult = 0;
    final taunter = alive.where((p) => p.taunt > 0).firstOrNull;
    final protector = alive.where((p) => p.protecting).firstOrNull;
    Combatant victim(Combatant q) =>
        protector != null && q != protector ? protector : q;
    Combatant? pick0;
    if (!ult.allTargets) {
      pick0 = taunter ?? alive[(_rand() * alive.length).floor()];
      if (taunter != null) taunter.taunt--;
    }
    events.add(EnemyUltEvent(e.id, ult.id, ult.name,
        targetId: pick0?.id,
        allTargets: ult.allTargets,
        wipedBuffs: ult.wipeBuffs));

    final atkMod = e.effectTotal(BuffStat.attack);
    final atk =
        atkMod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + atkMod)));
    final atkText = atkMod == 0 ? 'ATQ ${e.attack}' : 'ATQ $atk (debilitado)';
    final crit = ult.guaranteedCrit ? 1.0 : e.critChance;
    final parts = <String>[];
    void strike(Combatant p0) {
      final p = victim(p0);
      if (!p.alive) {
        parts.add('${p0.name} 0');
        return;
      }
      final h = _hurt(p, atk * ult.power, crit, e.pierce, from: e);
      if (p != p0 && p.alive) _fire(ProcTrigger.onProtectHit, p, target: e);
      final st = ult.status;
      if (st != null) _addStatus(p, st);
      final who = p != p0 ? '${p.name} (por ${p0.name})' : p.name;
      parts.add('$who ${h.damage}${h.critical ? '!' : ''}');
    }

    if (ult.allTargets) {
      alive.forEach(strike);
    } else {
      strike(pick0!);
    }
    if (ult.delayAll > 0) {
      for (final p in _aliveParty) {
        p.nextTurn += _iv(p) * ult.delayAll;
        events.add(DelayedEvent(p.id));
      }
    }
    if (ult.wipeBuffs) {
      for (final p in state.party) {
        p.effects = [
          for (final fx in p.effects)
            if (fx.value <= 0 || fx.stat == BuffStat.stunLock) fx,
        ];
        if (p.bonusDefense > 0) {
          p.bonusDefense = 0;
          engine._refreshStats(p);
        }
      }
    }
    final st = ult.status;
    state.log = '${e.name} · ULT ${ult.name} '
        '(${ult.allTargets ? 'todos, ' : ''}$atkText × ${fm(ult.power)}'
        '${ult.guaranteedCrit ? ' × ${fm(BattleEngine.enemyCritMultiplier)} CRÍTICO' : ''}): '
        '${parts.join(', ')}'
        '${st != null ? _statusText(st) : ''}'
        '${ult.delayAll > 0 ? ' · retrasa a todos' : ''}'
        '${ult.wipeBuffs ? ' · borra los buffs del grupo' : ''}';
  }

  // ---------------- jugadores ----------------

  /// `battleCmd`. Devuelve false si el comando no es válido.
  bool command(Combatant p, BattleCommand cmd) {
    final foes = state.enemies.where((e) => e.alive).toList();
    if (foes.isEmpty) return false;
    final targetId = switch (cmd) {
      AttackCommand(:final targetId) => targetId,
      SkillCommand(:final targetId) => targetId,
      UltimateCommand(:final targetId) => targetId,
      _ => null,
    };
    final target =
        foes.firstWhere((e) => e.id == targetId, orElse: () => foes.first);

    _dealt = 0;
    _dealtMaxHp = 1;
    _attacker = p;
    final act = _act = _Action();
    var ultGain = 0.0;
    var usedUlt = false;

    switch (cmd) {
      case AttackCommand():
        events.add(ActionEvent(p.id, BattleActionKind.attack,
            targetId: target.id,
            allTargets: p.keystones.contains('imparable')));
        _attack(p, foes, target);
      case SkillCommand(:final skillId):
        final sk = engine.catalog.skills[skillId];
        if (sk == null || !p.skillIds.contains(skillId) || p.mp < sk.mp) {
          return false;
        }
        act.breakFactor = sk.kind == SkillKind.physical
            ? BattleEngine.breakPhysicalSkill
            : BattleEngine.breakMagicalSkill;
        p.mp -= sk.mp;
        events.add(ActionEvent(p.id, BattleActionKind.skill,
            skillId: sk.id,
            targetId: sk.dealsDamage && !sk.allTargets ? target.id : null,
            allTargets: sk.allTargets));
        act.skill = sk;
        final gain = _useSkill(p, sk, foes, target, ultimate: false);
        // Prisa sin aliados: ya terminó el turno.
        if (gain == null) return true;
        ultGain = gain;
        _fire(ProcTrigger.onSkill, p);
      case UltimateCommand():
        final sk = engine.catalog.ultimates[p.weaponType];
        if (sk == null || p.ult < 100) return false;
        p.ult = 0;
        usedUlt = true;
        events.add(UltimateUsedEvent(p.id, sk.name));
        events.add(ActionEvent(p.id, BattleActionKind.ultimate,
            skillId: sk.id,
            targetId: sk.dealsDamage && !sk.allTargets ? target.id : null,
            allTargets: sk.allTargets));
        act
          ..skill = sk
          ..ultimate = true
          ..breakFactor = BattleEngine.breakUltimate;
        _useSkill(p, sk, foes, target, ultimate: true);
        _fire(ProcTrigger.onSkill, p);
      case DualCommand(:final partnerId):
        act.breakFactor = BattleEngine.breakDual;
        if (!_dual(p, partnerId, foes)) return false;
      case ItemCommand(:final item, :final targetPlayerId):
        final ok = item == BattleItem.ether
            ? _ether(p, targetPlayerId)
            : _potion(p, targetPlayerId);
        if (!ok) return false;
      case DefendCommand():
        events.add(ActionEvent(p.id, BattleActionKind.defend));
        p.defending = true;
        state.log = '${p.name} se defiende (actúa antes)';
        _act = null;
        tickEffects(p);
        p.nextTurn = state.clock + _iv(p) * 0.7;
        endTurn();
        return true;
    }

    _resolveAction(p, act);
    // Robo de vida del arma (afijo `del Vampiro`): sobre todo el daño de
    // la acción.
    if (p.lifeSteal > 0 && _dealt > 0 && p.alive && p.hp < p.maxHp) {
      final h = math.max(1, jsRound(_dealt * p.lifeSteal));
      _heal(p, h);
      _notes.add('robo de vida +$h HP');
    }
    if (!usedUlt) {
      final dealtBonus =
          _dealt > 0 ? math.min(22.0, 5 + _dealt / _dealtMaxHp * 30) : 0.0;
      p.ult = math.min(
          100, p.ult + (ultGain + dealtBonus) * (1 + p.ultChargeBonus));
    }
    _attacker = null;
    _act = null;
    tickEffects(p);
    if (act.extraTurn) {
      // Danza de Cuchillas: el próximo turno es ahora.
      p.extraTurn = 1;
      p.nextTurn = state.clock;
    } else {
      p.nextTurn = state.clock + _iv(p) * act.turnFactor;
    }
    endTurn();
    return true;
  }

  void _attack(Combatant p, List<Combatant> foes, Combatant target) {
    final atk = _atk(p);
    if (p.keystones.contains('imparable')) {
      final hits = [
        for (final e in foes) _damageEnemy(e, atk * 0.6, p.critChance),
      ];
      state.log = _damageLog(
          '${p.name} · Golpe Imparable (todos)', _atkText(p), atk, 0.6, hits,
          all: true);
      return;
    }
    final act = _act!..single = true;
    final hit =
        _damageEnemy(target, atk.toDouble(), p.critChance, single: true);
    act
      ..mainTarget = target
      ..mainHit = hit;
    var log = _damageLog(
        '${p.name} ataca → ${target.name}', _atkText(p), atk, 1, [hit],
        all: false);
    final stunChance = p.stunOnAttackChance;
    if (stunChance > 0 && target.alive && _rand() < stunChance) {
      _addStatus(target, const StatusApplication(StatusKind.stun, 1),
          source: p, primary: true);
      log += ' · ¡aturde! (${jsRound(stunChance * 100)}%)';
    }
    if (p.branch == 'creyente' && _rand() < 0.25) {
      for (final q in _aliveParty) {
        _heal(q, math.max(1, jsRound(q.maxHp * 0.02)));
      }
      log += ' · Fe: cura 2% a todos';
    }
    if (p.branch == 'inherente' && target.alive && _rand() < 0.25) {
      _addStatus(target, const StatusApplication(StatusKind.holy, 1),
          source: p, primary: true);
      log += ' · Sagrado (5/turno, 3 turnos)';
    }
    state.log = log;
  }

  /// Rama `tech`/`ult` de `battleCmd`. Devuelve la carga de ULT base de
  /// la acción, o `null` si el turno ya terminó (Prisa sin aliados).
  double? _useSkill(
    Combatant p,
    SkillDef tk,
    List<Combatant> foes,
    Combatant target, {
    required bool ultimate,
  }) {
    state.log = '${p.name} · ${tk.name}';
    final allies = _aliveParty.toList();

    switch (tk.kind) {
      case SkillKind.regen:
        final a = jsRound((p.magic * tk.power + 4) * (1 + p.healBonus));
        for (final q in allies) {
          _heal(q, a);
          _addStatus(q, const StatusApplication(StatusKind.regen, 3));
          _fire(ProcTrigger.onHeal, p, target: q, amount: a);
        }
        var log = '${p.name} · ${tk.name}: +$a a cada aliado '
            '(MAG ${p.magic} × ${fm(tk.power)} + 4) y Regeneración 5% vida y maná × 3 turnos';
        if (p.branch == 'creyente') {
          final base = p.magic * 0.8;
          for (final e in foes) {
            _damageEnemy(e, base, p.critChance);
          }
          log += ' · Luz: ${jsRound(base)} a cada enemigo (MAG × 0.8)';
        }
        state.log = log;
        return 8;

      case SkillKind.defenseUp:
        p.bonusDefense =
            math.min(BattleEngine.maxBonusDefense, p.bonusDefense + tk.amount);
        engine._refreshStats(p);
        state.log = '${p.name} · ${tk.name}: DEF ${p.defense} '
            '(−${jsRound(p.defensePercent * 100)}% daño recibido)';
        return 6;

      case SkillKind.protect:
        p.protecting = true;
        state.log = '${p.name} · ${tk.name}: absorbe todo el daño dirigido a '
            'sus aliados hasta su próximo turno';
        return 8;

      case SkillKind.bulwark:
        for (final q in allies) {
          final h = jsRound(q.maxHp * 0.3);
          _heal(q, h);
          q.defending = true;
          _fire(ProcTrigger.onHeal, p, target: q, amount: h);
        }
        p.protecting = true;
        p.bonusDefense =
            math.min(BattleEngine.maxBonusDefense, p.bonusDefense + 4);
        engine._refreshStats(p);
        state.log = '${p.name} · ${tk.name}: cura 30% a todos, todos '
            'defienden, Protección y DEF +4';
        return 0;

      case SkillKind.heal:
        final a = jsRound((p.magic * tk.power + 6) * (1 + p.healBonus));
        for (final q in allies) {
          _heal(q, a);
          if (tk.cleanse > 0) {
            for (final k in q.statuses.keys.toList()) {
              q.statuses[k] = math.max(0, q.statuses[k]! - tk.cleanse);
            }
            q.holyTurns = math.max(0, q.holyTurns - tk.cleanse);
          }
          _fire(ProcTrigger.onHeal, p, target: q, amount: a);
        }
        final cleanseText = tk.cleanse <= 0
            ? ''
            : tk.cleanse >= 5
                ? ' · quita todos los estados'
                : ' · quita 1 stack de cada estado';
        state.log = '${p.name} · ${tk.name}: +$a a cada aliado = '
            'MAG ${p.magic} × ${fm(tk.power)} + 6$cleanseText';
        return 8;

      case SkillKind.taunt:
        p.taunt = tk.amount;
        state.log = '${p.name} · ${tk.name}: los próximos ${tk.amount} '
            'ataques enemigos van contra ${p.name}';
        return 0;

      case SkillKind.guard:
        for (final q in allies) {
          q.defending = true;
        }
        state.log = '${p.name} · ${tk.name}: todo el equipo recibe ½ daño '
            'hasta su próximo turno';
        return 0;

      case SkillKind.haste:
        for (final q in allies.where((q) => q != p)) {
          q.nextTurn = math.max(state.clock + 0.01, q.nextTurn - _iv(q) * 0.5);
        }
        if (state.party.length == 1) {
          p.mp += tk.mp;
          p.nextTurn = state.clock;
          state.log = 'Prisa necesita aliados';
          _act = null;
          endTurn();
          return null;
        }
        return 0;

      case SkillKind.physical:
      case SkillKind.magical:
        final tormenta = p.keystones.contains('tormenta')
            ? (tk.allTargets ? 1.25 : 0.85)
            : 1.0;
        final magical = tk.kind == SkillKind.magical;
        final sourceValue = magical ? p.magic : _atk(p);
        final base = sourceValue * tk.power * tormenta;
        final st = tk.status;
        final bonus = st == null ? 0 : (p.statusBonus[st.kind] ?? 0);
        final act = _act!
          ..single = !tk.allTargets
          ..skillBase = base
          ..skillStatusBonus = bonus;
        final burnBlocked =
            st?.kind == StatusKind.burn && p.keystones.contains('almaHielo');
        final hits = <_Hit>[];
        for (final e in tk.allTargets ? foes : [target]) {
          final hit = _damageEnemy(e, base, p.critChance + tk.critBonus,
              single: !tk.allTargets);
          hits.add(hit);
          if (!tk.allTargets) {
            act
              ..mainTarget = e
              ..mainHit = hit;
          }
          if (st != null && !burnBlocked) {
            _addStatus(e, st, bonus: bonus, source: p, primary: true);
          }
          if (tk.delay > 0 && e.alive) {
            e.nextTurn += _iv(e) * tk.delay;
            events.add(DelayedEvent(e.id));
          }
        }
        final head = '${p.name} · ${ultimate ? 'ULT ' : ''}${tk.name}'
            '${tk.allTargets ? ' (todos)' : ' → ${target.name}'}';
        var log = _damageLog(head, magical ? 'MAG $sourceValue' : _atkText(p),
            sourceValue, tk.power, hits,
            all: tk.allTargets, tormenta: tormenta);
        if (tk.delay > 0) log += ' · retrasa';
        if (burnBlocked) {
          log += ' · sin Quemadura (Alma de Hielo)';
        } else if (st != null) {
          log += st.chance != null
              ? ' · ${jsRound(st.chance! * 100)}% ${st.stacks + bonus} ${st.kind.label}'
              : _statusText(st, bonus: bonus);
        }
        state.log = log;
        return 0;
    }
  }

  bool _dual(Combatant p, String partnerId, List<Combatant> foes) {
    final q = state.party.where((c) => c.id == partnerId).firstOrNull;
    if (q == null ||
        q == p ||
        !q.alive ||
        p.mp < BattleEngine.dualMpCost ||
        q.mp < BattleEngine.dualMpCost) {
      return false;
    }
    final du = engine.catalog.duals[dualKey(p.classId!, q.classId!)];
    if (du == null) return false;

    events.add(ActionEvent(p.id, BattleActionKind.dual,
        partnerId: q.id, allTargets: true));
    q.defending = false;
    p.mp -= BattleEngine.dualMpCost;
    q.mp -= BattleEngine.dualMpCost;
    q.nextTurn = math.max(q.nextTurn, state.clock) + _iv(q);

    final pv = math.max(_atk(p), p.magic);
    final qv = math.max(_atk(q), q.magic);
    final bonus = p.statusBonus[du.status.kind] ?? 0;
    final hits = <_Hit>[];
    for (final e in foes) {
      hits.add(_damageEnemy(
          e, (pv + qv) * du.power, (p.critChance + q.critChance) / 2));
      _addStatus(e, du.status, bonus: bonus, source: p, primary: true);
    }
    state.log = _damageLog('${p.name} + ${q.name} · ${du.name} (todos)',
            '($pv + $qv)', pv + qv, du.power, hits,
            all: true) +
        _statusText(du.status, bonus: bonus);
    return true;
  }

  /// Primer aliado con el menor valor (como el `sort(...)[0]` estable
  /// del prototipo).
  Combatant? _lowest(Iterable<Combatant> list, double Function(Combatant) f) {
    Combatant? best;
    for (final c in list) {
      if (best == null || f(c) < f(best)) best = c;
    }
    return best;
  }

  bool _ether(Combatant p, String? targetId) {
    if (p.ethers <= 0) return false;
    final chosen = targetId == null ? null : state.byId(targetId);
    final t = chosen != null && chosen.isPlayer && chosen.alive
        ? chosen
        : _lowest(_aliveParty, (c) => c.mp / c.maxMp);
    if (t == null) return false;
    events.add(ActionEvent(p.id, BattleActionKind.ether, targetId: t.id));
    p.ethers--;
    final a = jsRound(t.maxMp * 0.5);
    t.mp = math.min(t.maxMp.toDouble(), t.mp + a);
    events.add(HealEvent(t.id, a, mana: true));
    state.log =
        '${p.name} usa Poción de maná en ${t.name}: +$a MP = 50% de ${t.maxMp}';
    return true;
  }

  bool _potion(Combatant p, String? targetId) {
    if (p.potions <= 0) return false;
    final chosen = targetId == null ? null : state.byId(targetId);
    final t = chosen != null && chosen.isPlayer
        ? chosen
        : _lowest(state.party, (c) => c.hp / c.maxHp);
    if (t == null) return false;
    events.add(ActionEvent(p.id, BattleActionKind.potion, targetId: t.id));
    p.potions--;
    final a = jsRound(t.maxHp * 0.45);
    final was = t.hp;
    _heal(t, a);
    t.statuses[StatusKind.burn] = 0;
    t.statuses[StatusKind.poison] = 0;
    if (was == 0) {
      t.nextTurn = state.clock + _iv(t);
      events.add(RevivedEvent(t.id));
    }
    state.log = '${p.name} usa Poción de vida en ${t.name}: +$a HP = 45% de '
        '${t.maxHp}${was == 0 ? ' (¡revive!)' : ''} · quita Quemadura y Veneno';
    return true;
  }
}
