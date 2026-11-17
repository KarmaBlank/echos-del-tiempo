import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/skills_catalog.dart';
import '../models/battle_command.dart';
import '../models/battle_event.dart';
import '../models/battle_state.dart';
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
  }) : _random = random ?? math.Random().nextDouble;

  final StatsCalculator stats;
  final GameCatalog catalog;
  final RandomSource _random;

  static const freezeSlowPerStack = 0.12;
  static const enemyCritMultiplier = 1.5;
  static const maxBonusDefense = 12;
  static const dualMpCost = 4;

  /// Tiempo entre turnos (`IVa`): 100 / velocidad efectiva.
  double interval(Combatant a) =>
      100 / (a.speed * (1 - freezeSlowPerStack * a.stacks(StatusKind.freeze)));

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
    final fused = m.fusedSkillId;
    if (fused != null &&
        catalog.skills.containsKey(fused) &&
        !skills.contains(fused)) {
      skills.add(fused);
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
      ..hp = math.min(c.hp, d.maxHp)
      ..mp = math.min(c.mp, d.maxMp.toDouble());
  }
}

class _Hit {
  final int damage;
  final bool critical;
  const _Hit(this.damage, this.critical);
}

class _Hurt {
  final int damage;
  final bool critical;
  final double pierce;
  final double defensePercent;
  const _Hurt(this.damage, this.critical, this.pierce, this.defensePercent);
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

  BattleStep get result => BattleStep(state, List.unmodifiable(events));

  double _rand() => engine._random();
  double _iv(Combatant c) => engine.interval(c);
  Iterable<Combatant> get _aliveParty => state.party.where((p) => p.alive);

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
      state.log = 'Turno de ${best.name}';
    }
    final (skip, text) = _statusTick(best);
    if (text != null) state.log = text;
    if (!best.alive || skip) {
      if (skip) best.nextTurn = state.clock + _iv(best);
      state.currentId = null;
      _checkEnd();
    }
  }

  void endTurn() {
    state.currentId = null;
    _checkEnd();
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
      a.hp = math.max(0, a.hp - total);
      events.add(DamageEvent(a.id, total,
          fromStatus: true,
          statusSource: burn > 0
              ? StatusKind.burn
              : poison > 0
                  ? StatusKind.poison
                  : StatusKind.holy));
      if (!a.alive) events.add(KnockedOutEvent(a.id));
    }

    var skip = false;
    var stunned = false;
    if (a.stacks(StatusKind.stun) > 0 && a.alive) {
      skip = true;
      stunned = true;
      a.statuses[StatusKind.stun] = 0;
      events.add(TurnSkippedEvent(a.id, StatusKind.stun));
    } else if (a.stacks(StatusKind.freeze) >= StatusKind.freeze.maxStacks &&
        a.alive) {
      skip = true;
      a.statuses[StatusKind.freeze] = 0;
      events.add(TurnSkippedEvent(a.id, StatusKind.freeze));
    } else if (a.stacks(StatusKind.freeze) > 0) {
      a.statuses[StatusKind.freeze] = a.stacks(StatusKind.freeze) - 1;
    }

    final texts = <String>[
      if (total > 0)
        '${a.name} sufre ${parts.join(' + ')} = $total de daño'
            '${a.alive ? '' : ' y cae'}',
      if (healText != null) healText,
      if (skip)
        '${a.name} está ${stunned ? 'ATURDIDO' : 'CONGELADO'} y pierde su turno',
    ];
    return (skip, texts.isEmpty ? null : texts.join(' · '));
  }

  /// `addStatus`.
  bool _addStatus(Combatant a, StatusApplication st, {int bonus = 0}) {
    if (!a.alive) return false;
    if (st.chance != null && _rand() >= st.chance!) return false;
    final weak = a.isPlayer && a.statusWeakness > 0 && st.kind != StatusKind.regen
        ? a.statusWeakness
        : 0;
    final n = st.stacks + bonus + weak;
    a.statuses[st.kind] = math.min(st.kind.maxStacks, a.stacks(st.kind) + n);
    if (st.kind == StatusKind.holy) a.holyTurns = 3;
    if (st.kind == StatusKind.regen) a.statuses[StatusKind.regen] = 3;
    events.add(StatusAppliedEvent(a.id, st.kind, n, weakness: weak > 0));
    return true;
  }

  void _heal(Combatant q, int amount) {
    q.hp = math.min(q.maxHp, q.hp + amount);
    events.add(HealEvent(q.id, amount));
  }

  // ---------------- daño ----------------

  /// `hurt`: enemigo → jugador.
  _Hurt _hurt(Combatant p, double base, double critChance, bool pierce) {
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
    p.ult = math.min(100, p.ult + dmg / p.maxHp * 110 * (1 + p.ultChargeBonus));
    p.hp = math.max(0, p.hp - dmg);
    events.add(DamageEvent(p.id, dmg,
        critical: crit,
        critMultiplier: BattleEngine.enemyCritMultiplier,
        pierceMultiplier: pmul));
    if (!p.alive) events.add(KnockedOutEvent(p.id));
    return _Hurt(dmg, crit, pmul, defp);
  }

  /// `dmgEnemy`: jugador → enemigo.
  _Hit _damageEnemy(Combatant e, double base, double critChance) {
    final cm = _attacker?.critMultiplier ?? 1.5;
    final crit = _rand() < critChance;
    final dmg = math.max(1, jsRound(base * (crit ? cm : 1)));
    _dealt += math.min(dmg, e.hp);
    _dealtMaxHp = math.max(_dealtMaxHp, e.maxHp);
    e.hp = math.max(0, e.hp - dmg);
    events.add(DamageEvent(e.id, dmg, critical: crit, critMultiplier: cm));
    if (!e.alive) events.add(KnockedOutEvent(e.id));
    return _Hit(dmg, crit);
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
          '${r.critical ? ' × ${fm(cm)} CRÍTICO' : ''}';
    }
    final base = jsRound(sourceValue * power * tormenta);
    final crits = hits.where((h) => h.critical).length;
    return '$head: $base c/u = $formula'
        '${crits > 0 ? ' ($crits crítico${crits > 1 ? 's' : ''} → ${jsRound(base * cm)})' : ''}';
  }

  String _statusText(StatusApplication? st, {int bonus = 0}) =>
      st == null ? '' : ' · +${st.stacks + bonus} ${st.kind.label}';

  // ---------------- enemigos ----------------

  /// `enemyAct`.
  void enemyAct(Combatant e) {
    final alive = _aliveParty.toList();
    if (alive.isEmpty) return;
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

    String detail(_Hurt h, double mult, Combatant p) => 'ATQ ${e.attack}'
        '${mult != 1 ? ' × ${fm(mult)}' : ''}'
        '${h.critical ? ' × ${fm(BattleEngine.enemyCritMultiplier)} CRÍTICO' : ''}'
        '${h.pierce > 1 ? ' × ${fm(h.pierce)} perforante' : ''}'
        '${p.defending ? ' × ½ defender' : ''}'
        '${h.defensePercent > 0 ? ' − ${jsRound(h.defensePercent * 100)}% DEF' : ''}';
    String infText(Combatant p) => p.alive && inf != null
        ? _statusText(inf, bonus: inf.kind == StatusKind.regen ? 0 : p.statusWeakness)
        : '';
    final tauntText = taunter != null ? ' (provocado)' : '';

    if (area) {
      final parts = <String>[];
      for (final p0 in alive) {
        final p = victim(p0);
        if (!p.alive) {
          parts.add('${p0.name} 0');
          continue;
        }
        final h = _hurt(p, e.attack * 0.7, e.critChance, e.pierce);
        p.nextTurn += _iv(p) * 0.4;
        if (inf != null) _addStatus(p, inf);
        events.add(DelayedEvent(p.id));
        final who = p != p0 ? '${p.name} (por ${p0.name})' : p.name;
        parts.add('$who ${h.damage}${h.critical ? '!' : ''}');
      }
      state.log = '${e.name} · Colapso Temporal (todos, ATQ ${e.attack} × 0.7, '
          'retrasa): ${parts.join(', ')}';
    } else if (e.boss && e.actions % 4 == 0) {
      final h = _hurt(pick, e.attack * 1.6, e.critChance, e.pierce);
      if (inf != null) _addStatus(pick, inf);
      state.log = '${e.name} · Golpe Brutal → ${pick.name}: ${h.damage} = '
          '${detail(h, 1.6, pick)}${infText(pick)}$tauntText$protText';
    } else {
      final h = _hurt(pick, e.attack.toDouble(), e.critChance, e.pierce);
      if (inf != null) _addStatus(pick, inf);
      final explain =
          h.critical || pick.defending || h.pierce > 1 || h.defensePercent > 0;
      state.log = '${e.name} → ${pick.name}: ${h.damage}'
          '${explain ? ' = ${detail(h, 1, pick)}' : ''}'
          '${infText(pick)}$tauntText$protText';
    }
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
        p.mp -= sk.mp;
        events.add(ActionEvent(p.id, BattleActionKind.skill,
            skillId: sk.id,
            targetId: sk.dealsDamage && !sk.allTargets ? target.id : null,
            allTargets: sk.allTargets));
        final gain = _useSkill(p, sk, foes, target, ultimate: false);
        if (gain == null) return true; // Prisa sin aliados: ya terminó el turno.
        ultGain = gain;
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
        _useSkill(p, sk, foes, target, ultimate: true);
      case DualCommand(:final partnerId):
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
        p.nextTurn = state.clock + _iv(p) * 0.7;
        endTurn();
        return true;
    }

    if (!usedUlt) {
      final dealtBonus =
          _dealt > 0 ? math.min(22.0, 5 + _dealt / _dealtMaxHp * 30) : 0.0;
      p.ult = math.min(100, p.ult + (ultGain + dealtBonus) * (1 + p.ultChargeBonus));
    }
    _attacker = null;
    p.nextTurn = state.clock + _iv(p);
    endTurn();
    return true;
  }

  void _attack(Combatant p, List<Combatant> foes, Combatant target) {
    if (p.keystones.contains('imparable')) {
      final hits = [
        for (final e in foes) _damageEnemy(e, p.attack * 0.6, p.critChance),
      ];
      state.log = _damageLog('${p.name} · Golpe Imparable (todos)',
          'ATQ ${p.attack}', p.attack, 0.6, hits,
          all: true);
      return;
    }
    final hit = _damageEnemy(target, p.attack.toDouble(), p.critChance);
    var log = _damageLog('${p.name} ataca → ${target.name}', 'ATQ ${p.attack}',
        p.attack, 1, [hit],
        all: false);
    final stunChance = p.stunOnAttackChance;
    if (stunChance > 0 && target.alive && _rand() < stunChance) {
      _addStatus(target, const StatusApplication(StatusKind.stun, 1));
      log += ' · ¡aturde! (${jsRound(stunChance * 100)}%)';
    }
    if (p.branch == 'creyente' && _rand() < 0.25) {
      for (final q in _aliveParty) {
        _heal(q, math.max(1, jsRound(q.maxHp * 0.02)));
      }
      log += ' · Fe: cura 2% a todos';
    }
    if (p.branch == 'inherente' && target.alive && _rand() < 0.25) {
      _addStatus(target, const StatusApplication(StatusKind.holy, 1));
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
          _heal(q, jsRound(q.maxHp * 0.3));
          q.defending = true;
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
          q.nextTurn =
              math.max(state.clock + 0.01, q.nextTurn - _iv(q) * 0.5);
        }
        if (state.party.length == 1) {
          p.mp += tk.mp;
          p.nextTurn = state.clock;
          state.log = 'Prisa necesita aliados';
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
        final sourceValue = magical ? p.magic : p.attack;
        final base = sourceValue * tk.power * tormenta;
        final st = tk.status;
        final bonus = st == null ? 0 : (p.statusBonus[st.kind] ?? 0);
        final hits = <_Hit>[];
        for (final e in tk.allTargets ? foes : [target]) {
          hits.add(_damageEnemy(e, base, p.critChance + tk.critBonus));
          if (st != null) _addStatus(e, st, bonus: bonus);
          if (tk.delay > 0 && e.alive) {
            e.nextTurn += _iv(e) * tk.delay;
            events.add(DelayedEvent(e.id));
          }
        }
        final head = '${p.name} · ${ultimate ? 'ULT ' : ''}${tk.name}'
            '${tk.allTargets ? ' (todos)' : ' → ${target.name}'}';
        var log = _damageLog(
            head, '${magical ? 'MAG' : 'ATQ'} $sourceValue', sourceValue, tk.power, hits,
            all: tk.allTargets, tormenta: tormenta);
        if (tk.delay > 0) log += ' · retrasa';
        if (st != null) {
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

    final pv = math.max(p.attack, p.magic);
    final qv = math.max(q.attack, q.magic);
    final bonus = p.statusBonus[du.status.kind] ?? 0;
    final hits = <_Hit>[];
    for (final e in foes) {
      hits.add(_damageEnemy(
          e, (pv + qv) * du.power, (p.critChance + q.critChance) / 2));
      _addStatus(e, du.status, bonus: bonus);
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
    state.log = '${p.name} usa Poción de maná en ${t.name}: +$a MP = 50% de ${t.maxMp}';
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
