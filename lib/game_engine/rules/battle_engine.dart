import 'dart:math' as math;

import '../data/ascension_catalog.dart';
import '../data/branch_ults_catalog.dart';
import '../data/elements_catalog.dart';
import '../data/enemies_catalog.dart';
import '../data/game_catalog.dart';
import '../data/passive_mechanics.dart' show mechanicById;
import '../data/skills_catalog.dart';
import '../data/summoner_catalog.dart';
import '../models/battle_command.dart';
import '../models/battle_event.dart';
import '../models/battle_state.dart';
import '../models/enemy_def.dart';
import '../models/passive_mechanic.dart';
import '../models/skill.dart';
import '../models/status.dart';
import '../data/abyss_catalog.dart';
import 'abyss_rules.dart';
import 'dual_rules.dart';
import 'family_rules.dart';
import 'js_math.dart';
import 'stats_calculator.dart';
import 'summon_rules.dart';

part 'battle_engine_abyss.dart';
part 'battle_engine_summons.dart';

/// Fuente de azar: devuelve un número en [0, 1), igual que `Math.random`.
/// Los tests inyectan una secuencia fija para que todo sea reproducible.
typedef RandomSource = double Function();

/// La ULT de [c]: la de su ascensión si ascendió (docs/specs/ascension.md
/// § 4); si no, la propia de su arma (tomos del Invocador,
/// docs/specs/summoner.md § 7) o la de su tipo de arma.
SkillDef? ultimateOf(Combatant c,
    [GameCatalog catalog = GameCatalog.standard]) {
  final asc = kAscensions[c.ascensionId];
  if (asc != null && asc.classId == c.classId) {
    final u = kAscensionUltimates[asc.id];
    if (u != null) return u;
  }
  // Mod "ULT: <nombre>" / legendario (branch_ults.md) o base propia.
  final own = ownWeaponUlt(c.build?.equippedWeapon.id, c.build?.item);
  if (own != null) return own;
  return catalog.ultimates[c.weaponType];
}

/// Los 3 estados elementales (Elementalista).
const kElementalStatuses = [StatusKind.burn, StatusKind.freeze, StatusKind.poison];

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
    this.familiesEnabled = true,
  }) : _random = random ?? math.Random().nextDouble;

  final StatsCalculator stats;
  final GameCatalog catalog;
  final RandomSource _random;

  /// Barra de quiebre de los enemigos (docs/specs/break_and_enemy_ults.md
  /// § 1). Los tests angostos pueden apagarla.
  final bool breakEnabled;

  /// ULT de jefes y élites (§ 2).
  final bool enemyUltsEnabled;

  /// Familias de enemigos: debilidades, resistencias, inmunidades y curas
  /// que dañan (docs/specs/bestiary.md § 1). Los tests de otras fórmulas
  /// pueden apagarlas.
  final bool familiesEnabled;

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

  /// Golpe esquivado por un común (Eco Sombrío): solo lo roza.
  static const evadeFactor = 0.3;

  /// Pasar turno (v0.8.3, combat.md § "Pasar turno"): el próximo turno
  /// llega en IV × esto (Defender: × 0.7; acción normal: × 1).
  static const passTurnFactor = 0.5;

  // ---- ULT enemiga ----
  /// Carga por turno propio.
  static const enemyUltPerTurn = 25.0;

  /// Carga por vida perdida: +1 por cada 1% (= 100 × fracción).
  static const enemyUltPerHp = 100.0;

  /// Carga con la que empiezan jefes y élites (la primera ULT llega
  /// hacia su 3.er turno).
  static const enemyUltStart = 40.0;

  /// −velocidad por stack de Congelación del código (§ 7); el motor usa
  /// la del catálogo (`ElementStatusDef.slowPerStack`, editable).
  static const freezeSlowPerStack = 0.06;
  static const enemyCritMultiplier = 1.5;
  static const maxBonusDefense = 12;
  static const dualMpCost = 4;

  /// Tope de efectos disparados por el árbol en un paso del motor
  /// (passive_tree_v2.md § 5, regla 4).
  static const maxProcsPerStep = 64;

  /// Tope de la defensa de grupo sumada (`BuffStat.guard`, ascension.md).
  static const maxGuard = 0.6;

  /// Tiempo entre turnos (`IVa`): 100 / velocidad efectiva. Los buffs de
  /// velocidad del árbol (Frenesí) suben la velocidad efectiva.
  double interval(Combatant a) =>
      100 /
      (a.speed *
          (1 + a.effectTotal(BuffStat.speed)) *
          (1 -
              catalog.elementStatus(StatusKind.freeze).slowPerStack *
                  a.stacks(StatusKind.freeze)));

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
        breakBase: breakEnabled ? d.breakMax * mult * (el ? eliteBreak : 1) : 0,
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

    // Mecánica propia del jefe (docs/specs/bosses.md § "v0.2").
    final mech = first.boss ? bossMechanicOf(first) : null;
    if (mech != null) {
      final boss = enemies.first;
      if (mech.kind == BossMechanicKind.stance) {
        boss
          ..stance = 1
          ..stanceTurns = mech.every;
      }
      // Jefe del Abismo (abyss_bosses.md § 2): fase 1, su aspecto, y las
      // invocaciones solo si su primera fase las pide.
      final abyss = catalog.abyssOf(first.id);
      if (abyss != null) {
        final ph = abyss.phases.first;
        boss.phase = 1;
        if (ph.aspects.isNotEmpty) boss.abyssAspect = ph.aspects.first.index + 1;
      }
      final add = abyss != null && !abyss.phases.first.summon
          ? null
          : catalog.enemies[mech.addType];
      if (add != null) {
        final n = party.length == 1 ? mech.soloAdds : mech.adds;
        for (var k = 0; k < n; k++) {
          final c = addCombatant(add, 'e${enemies.length}', mult, 1);
          // Las invocaciones que actúan (ecos, séquito) entran a la línea
          // de tiempo sin tirar dados (docs/specs/bosses.md § "v0.3").
          if (!add.passive) c.nextTurn = (100 / add.speed) * (0.6 + 0.2 * k);
          enemies.add(c);
        }
      }
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
    if (e.alive && e.isSummon) {
      // Invocación (summoner.md § 3): su IA y su próxima espera.
      t._summonTurn(e);
      e.nextTurn = t.state.clock + interval(e);
    } else if (e.alive) {
      final before = e.nextTurn;
      t.enemyAct(e);
      t.tickEffects(e);
      // Un retraso recibido durante su propia acción (Contratiempo) se
      // suma a su próxima espera.
      e.nextTurn =
          t.state.clock + interval(e) + math.max(0.0, e.nextTurn - before);
      // Distorsión de un Jefe del Abismo: su próximo turno llega antes.
      final haste = _abyssHaste[t];
      if (haste != null) e.nextTurn -= interval(e) * haste;
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

  /// Una invocación de jefe (cristal, eco, siervo) de tipo [add]: vida ×
  /// [hpMult], ATQ × [atkMult], sin crítico, quiebre ni ULT.
  Combatant addCombatant(
      EnemyDef add, String id, double hpMult, double atkMult) {
    final hp = math.max(1, jsRound(add.hp * hpMult));
    return Combatant(
      id: id,
      name: add.name,
      isPlayer: false,
      hp: hp,
      maxHp: hp,
      speed: add.speed,
      attack: jsRound(add.attack * atkMult),
      critChance: 0,
      enemyType: add.id,
      pierce: add.pierce,
      inflicts: add.inflicts,
    );
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
    // Kit de la ascensión (docs/specs/ascension.md § 4).
    final asc = kAscensions[m.build.ascension.id];
    if (asc != null && asc.classId == cls.id) {
      for (final id in asc.skillIds) {
        if (catalog.skills.containsKey(id) && !skills.contains(id)) {
          skills.add(id);
        }
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

  /// Dúo (la postura del Caballero Hueco no lo bloquea).
  bool dual = false;
}

/// Contexto de una reacción para las mecánicas del árbol (§ 8 de
/// passive_tree_v4.md): tipo, stacks consumidos, quién detonó, a quiénes
/// ya les llegó (objetivo y salto) y el estado del golpe.
class _Rx {
  _Rx(this.kind, this.consumed, this.by, this.hitIds, this.hitStatus);
  final ReactionKind kind;
  final int consumed;
  final Combatant by;
  final Set<String> hitIds;
  final StatusApplication? hitStatus;
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

  /// Enemigos cuya postura ya bloqueó en este paso (un evento por paso;
  /// también los ecos que recibieron daño reducido).
  final _resisted = <String>{};

  /// Jefes cuya inmunidad ya se avisó en este paso.
  final _immuneShown = <String>{};

  /// Derretidos en este paso: Choque Térmico igual los aturde (la
  /// reacción ya les quitó la Congelación).
  final _meltedNow = <String>{};

  /// Reacción cuyos disparadores del árbol se están evaluando
  /// (passive_tree_v4.md § 8).
  _Rx? _rx;

  /// Golpe de jugador cuyos `onHit` / `onCrit` se están disparando: si
  /// todavía no reaccionó, un estado elemental que el golpe deja por el
  /// árbol o el arma (Dios del Trueno...) lo detona
  /// (elemental_reactions.md § 9).
  ({Combatant target, int damage, bool reacted})? _hitNow;

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
    for (final c in [...state.party, ...state.enemies, ...state.summons]) {
      if (c.alive &&
          !_passive(c) &&
          (best == null || c.nextTurn < best.nextTurn)) {
        best = c;
      }
    }
    if (best == null) return;

    state.clock = math.max(state.clock, best.nextTurn);
    state.currentId = best.id;
    events.add(TurnStartedEvent(best.id));
    if (best.isSummon) {
      state.log = 'Turno de ${best.name}';
      return;
    }
    if (best.isPlayer) {
      best.defending = false;
      best.protecting = false;
      best.extraTurn = best.extraTurn == 1 ? 2 : 0;
      state.log = 'Turno de ${best.name}';
    } else {
      _decayBreak(best);
    }
    var (skip, text) = _statusTick(best);
    // Trampas del Trampero: saltan al empezar el turno del enemigo.
    if (!best.isPlayer && best.alive) _springTraps(best);
    // Disparo cargado (variantes): cae al empezar el turno del tirador.
    if (best.isPlayer && best.alive) _fireCharge(best);
    final cleared = state.enemies.every((e) => !e.alive);
    if (!skip && best.alive && best.breakSkip) {
      // Quebrado: pierde su turno (como aturdido).
      skip = true;
      best.breakSkip = false;
      events.add(BreakEvent(
          best.id, BreakPhase.skipped, best.breakGauge, best.breakMax));
      final t = '${best.name} está QUEBRADO y pierde su turno';
      text = text == null ? t : '$text · $t';
    }
    var struggle = false;
    if (!skip && best.alive && best.isPlayer && best.webbed) {
      // Telaraña de la Matriarca: pierde el turno (solo: medio turno).
      best.webbed = false;
      skip = true;
      struggle = !_aliveParty.any((q) => q != best);
      events.add(BossMechanicEvent(best.id,
          struggle ? BossMechanicPhase.webStruggle : BossMechanicPhase.webSkip,
          targetId: best.id));
      final t = struggle
          ? '${best.name} forcejea con la telaraña y pierde medio turno'
          : '${best.name} está atrapado en la telaraña y pierde su turno';
      text = text == null ? t : '$text · $t';
    }
    if (text != null) state.log = text;
    // Regeneración del arma (afijo `del Renacer`, loot.md § 12).
    if (best.alive &&
        best.isPlayer &&
        best.regenPerTurn > 0 &&
        best.hp < best.maxHp) {
      final h = math.max(1, jsRound(best.maxHp * best.regenPerTurn));
      _heal(best, h);
      _notes.add('${best.name} regenera $h HP (arma)');
    }
    if (best.alive) _fire(ProcTrigger.onTurnStart, best);
    if (best.alive && best.isPlayer) _summonPactTick(best);
    if ((!best.alive || skip) && best.isPlayer) _tickVulnerable();
    _flush();
    if (!best.alive || skip || cleared) {
      if (skip) {
        tickEffects(best);
        best.nextTurn = state.clock +
            _iv(best) * (struggle ? kBossMechanics['telarana']!.soloValue : 1);
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
    // El control se mira como estaba al EMPEZAR el turno: si el daño de
    // los estados transforma al Devorador (fase 2 limpia los estados), el
    // aturdimiento / congelación ya ganado igual le cuesta este turno.
    final stunnedAtStart = a.stacks(StatusKind.stun) > 0;
    // Hielo v0.7 (elemental_reactions.md § 7): con 5 stacks pierde el
    // turno y queda Quebradizo; el turno siguiente se descongela solo.
    final frozenAtStart =
        a.stacks(StatusKind.freeze) >= StatusKind.freeze.maxStacks &&
            !a.brittle;
    final brittleAtStart = a.brittle;
    if (a.freezeResist > 0) a.freezeResist--;
    // Mojado y Cargado: pierden 1 turno (no hacen daño).
    for (final k in const [StatusKind.wet, StatusKind.charged]) {
      final n = a.stacks(k);
      if (n > 0) a.statuses[k] = n - 1;
    }

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
      // Ira Divina (Templario): el Sagrado de los enemigos hace más.
      // No muertos / espectros: el Sagrado arde más (bestiary.md § 1).
      // Simétrico (§ 5.3): la familia / raza vale también para jugadores.
      final d = jsRound(5 *
          holy *
          (a.isPlayer ? 1 : 1 + _aura(BuffStat.holyPower)) *
          (_fam(a)?.holyTick ?? 1));
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
      final harm = _fam(a)?.healHarm ?? 0;
      if (harm > 0) {
        // Raza / familia a la que las curas dañan (no muertos).
        a.statuses[StatusKind.regen] = regen - 1;
        final d = _rawDamage(null, a, math.max(1, jsRound(hh * harm)),
            kHealHarmSourceId);
        healText = '¡La regeneración quema a ${a.name}! $d';
      } else {
        a.hp = math.min(a.maxHp, a.hp + hh);
        if (a.maxMp > 0) a.mp = math.min(a.maxMp.toDouble(), a.mp + mm);
        a.statuses[StatusKind.regen] = regen - 1;
        healText = '${a.name} regenera +$hh HP${mm > 0 ? ' +$mm MP' : ''}';
        events.add(HealEvent(a.id, hh));
        if (mm > 0) events.add(HealEvent(a.id, mm, mana: true));
      }
    }

    if (total > 0) {
      _chargeUlt(a, math.min(total, a.hp));
      a.hp = math.max(0, a.hp - total);
      final shift = !a.isPlayer && _gatePhase(a);
      events.add(DamageEvent(a.id, total,
          fromStatus: true,
          statusSource: burn > 0
              ? StatusKind.burn
              : poison > 0
                  ? StatusKind.poison
                  : StatusKind.holy));
      if (!a.alive) _knockedOut(a);
      if (shift) _transform(a);
    }

    var skip = false;
    var stunned = false;
    var locked = false;
    if (stunnedAtStart && a.alive) {
      skip = true;
      stunned = true;
      // Martillo Bendito: el aturdimiento dura un turno más (salvo que la
      // transformación se lo haya quitado).
      locked = a.hasEffect(BuffStat.stunLock) &&
          a.stacks(StatusKind.stun) > 0;
      if (a.hasEffect(BuffStat.stunLock)) {
        a.effects =
            a.effects.where((e) => e.stat != BuffStat.stunLock).toList();
      }
      if (!locked) a.statuses[StatusKind.stun] = 0;
      events.add(TurnSkippedEvent(a.id, StatusKind.stun));
    } else if (frozenAtStart && a.alive) {
      // Congelado: pierde el turno y queda Quebradizo (el próximo golpe
      // físico hace ×1.5 y lo descongela).
      skip = true;
      a.brittle = true;
      events.add(TurnSkippedEvent(a.id, StatusKind.freeze));
      events.add(IceEvent(a.id, IcePhase.brittle));
    } else if (brittleAtStart && a.alive) {
      // Nadie lo rompió: se descongela solo (salvo Alma de Hielo).
      if (a.isPlayer || !_almaHielo) {
        _thawFreeze(a);
        _notes.add('${a.name} se descongela');
      }
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
            '${locked ? ' (Martillo Bendito: sigue aturdido 1 turno más)' : ''}'
            '${stunned ? '' : ' · queda QUEBRADIZO (próximo golpe físico ×'
                '${fm(_frz.brittleMult)})'}',
    ];
    return (skip, texts.isEmpty ? null : texts.join(' · '));
  }

  /// `addStatus`. [source]: quién lo aplica; con [primary] (golpe
  /// primario de su acción) dispara `onStatusApplied`.
  bool _addStatus(Combatant a, StatusApplication st,
      {int bonus = 0, Combatant? source, bool primary = false}) {
    if (!a.alive) return false;
    // Séquito del Espectro Coronado: inmune a los estados.
    if (!a.isPlayer && _immune(a)) {
      if (_immuneShown.add(a.id)) {
        events.add(BossMechanicEvent(a.id, BossMechanicPhase.immune));
        _notes.add('${a.name} es INMUNE a los estados (séquito vivo)');
      }
      return false;
    }
    // Alma de Hielo: no puede aplicar Quemadura.
    if (st.kind == StatusKind.burn &&
        source != null &&
        source.keystones.contains('almaHielo')) {
      return false;
    }
    if (st.chance != null && _rand() >= st.chance!) return false;
    // Recién descongelado: resiste la Congelación (§ 7).
    if (st.kind == StatusKind.freeze && a.freezeResist > 0) {
      if (_immuneShown.add('${a.id}|resist')) {
        events.add(IceEvent(a.id, IcePhase.resisted));
        _notes.add('${a.name} resiste la Congelación (recién descongelado)');
      }
      return false;
    }
    // Familia (bestiary.md § 1): inmunidades y stacks de más / de menos.
    final family = _fam(a);
    if (family != null && family.immune.contains(st.kind)) {
      if (_immuneShown.add('${a.id}|${st.kind.name}')) {
        _notes.add('${a.name} es INMUNE a ${st.kind.label} '
            '(${family.family.label})');
      }
      return false;
    }
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
    if (family != null) n = familyStacks(family, st.kind, n);
    if (st.kind.timed) {
      // Mojado / Cargado: no se acumulan, se renuevan a su duración.
      final turns = engine.catalog.elementStatus(st.kind).turns;
      if (turns <= 0) return false;
      a.statuses[st.kind] = math.max(a.stacks(st.kind), turns);
    } else {
      a.statuses[st.kind] =
          math.min(st.kind.maxStacks, a.stacks(st.kind) + n);
    }
    if (st.kind == StatusKind.holy) a.holyTurns = 3;
    if (st.kind == StatusKind.regen) a.statuses[StatusKind.regen] = 3;
    // Quién preparó la reacción (árbol v5: onPrimedReaction).
    if (source != null &&
        source.isPlayer &&
        !a.isPlayer &&
        kReactionTable.any((r) => r.primer == st.kind)) {
      a.primedBy[st.kind] = source.id;
    }
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
    final before = q.hp;
    q.hp = math.min(q.maxHp, q.hp + amount);
    events.add(HealEvent(q.id, amount));
    // Jefes del Abismo: las curas del grupo los dañan.
    if (q.isPlayer) _abyssHealed(q, q.hp - before);
  }

  // ---------------- daño ----------------

  /// `hurt`: enemigo → jugador. Los escudos del árbol absorben antes que
  /// la vida; [from] es el enemigo que pega (Contraataque, Represalia).
  ///
  /// v0.7: el golpe tiene [element] (reacciones sobre el jugador, § 5.3)
  /// y la familia / raza del jugador cuenta como la de un enemigo.
  /// [inflicted]: el estado del golpe (Cortocircuito lo lleva al salto).
  _Hurt _hurt(Combatant p, double base, double critChance, bool pierce,
      {Combatant? from,
      GameElement element = GameElement.fisico,
      StatusApplication? inflicted}) {
    final crit = _rand() < critChance;
    // Reacción (una por golpe) o golpe a un Quebradizo (los golpes
    // enemigos cuentan como físicos).
    // El estado que deja el golpe también cuenta como su elemento (§ 9).
    final reaction = _reactionFor(p, element) ??
        _carriedReaction(p, [if (inflicted != null) inflicted]);
    var react = _reactionMult(reaction);
    if (reaction == null && _isBrittle(p)) react = _frz.brittleMult;
    // Familia / raza del jugador (null hasta que existan las razas).
    final affinity = familyMultiplier(_fam(p), {
      DamageTag.physical,
      if (damageTagOf(element) case final t?) t,
    });
    final pmul = pierce ? p.pierceWeakness : 1.0;
    final defp = p.defensePercent;
    // Marca del Vigilante del Vacío: +daño recibido.
    final marked = 1 + p.effectTotal(BuffStat.damageTaken);
    // Defensa de grupo (Estandarte, Bandera Firme, Bastión): tope 60%.
    final guard = math.min(
        BattleEngine.maxGuard,
        p.effectTotal(BuffStat.guard) +
            _aura(BuffStat.guard) +
            // Guarda propia por condición (árbol v3: Voto de Hierro, Inamovible).
            _conditionBonus(p, BuffStat.guard));
    var dmg = math.max(
      1,
      jsRound(base *
          (crit ? BattleEngine.enemyCritMultiplier : 1) *
          marked *
          pmul *
          (p.defending ? 0.5 : 1) *
          (1 - defp) *
          (1 - guard) *
          react *
          affinity),
    );
    // Juramento Eterno (Guardián): parte del golpe va al Guardián.
    dmg -= _shareDamage(p, dmg);
    final absorbed = _absorb(p, dmg, from: from);
    var taken = dmg - absorbed;
    if (taken >= p.hp && p.hp > 0) taken = _cheatDeath(p, taken);
    if (taken > 0) {
      p.ult =
          math.min(100, p.ult + taken / p.maxHp * 110 * (1 + p.ultChargeBonus));
    }
    p.hp = math.max(0, p.hp - taken);
    events.add(DamageEvent(p.id, taken,
        critical: crit,
        critMultiplier: BattleEngine.enemyCritMultiplier,
        pierceMultiplier: pmul,
        affinity: affinity));
    if (!p.alive) {
      events.add(KnockedOutEvent(p.id));
      p.voidMarked = false;
      _allyDown(p);
    }
    if (reaction != null) {
      _react(from, p, reaction, dmg, hitStatus: inflicted);
    } else if (react != 1) {
      _shatter(p);
    }
    if (from != null && p.alive) {
      _fire(ProcTrigger.onHitTaken, p, target: from, amount: dmg);
    }
    return _Hurt(dmg, crit, pmul, defp);
  }

  /// Los escudos de [p] absorben hasta [dmg]; devuelve cuánto absorbieron.
  /// Con [from], los escudos de un dueño con Égida Reflectante devuelven
  /// parte de lo absorbido al atacante.
  int _absorb(Combatant p, int dmg, {Combatant? from}) {
    if (!p.hasEffect(BuffStat.shield)) return 0;
    var left = dmg;
    final next = <TimedEffect>[];
    final byOwner = <String, int>{};
    // Variantes: escudos que reflejan, explotan o crecen (por habilidad).
    final reflects = <(String, SkillDef, int)>[];
    final bursts = <(String, SkillDef)>[];
    for (final e in p.effects) {
      if (e.stat != BuffStat.shield || left <= 0) {
        next.add(e);
        continue;
      }
      final v = e.value.round();
      final use = math.min(v, left);
      left -= use;
      final o = e.ownerId;
      if (o != null) byOwner[o] = (byOwner[o] ?? 0) + use;
      var rest = (v - use).toDouble();
      final sk = engine.catalog.skills[e.sourceId];
      if (sk != null && use > 0) {
        if (sk.shieldGrow > 0) {
          rest = math.max(rest,
              math.min(p.maxHp * 0.5, rest + use * sk.shieldGrow).roundToDouble());
        }
        if (sk.shieldReflect > 0 && o != null) reflects.add((o, sk, use));
        if (sk.shieldBurst > 0 && rest <= 0 && o != null) bursts.add((o, sk));
      }
      if (rest > 0) next.add(e.copyWith(value: rest));
    }
    p.effects = next;
    final absorbed = dmg - left;
    if (absorbed > 0) {
      events.add(ShieldEvent(p.id, absorbed, absorbed: true));
      _notes.add('escudo de ${p.name} absorbe $absorbed');
    }
    for (final (o, sk, use) in reflects) {
      final owner = state.byId(o);
      if (from == null || !from.alive || from.isPlayer || owner == null) {
        continue;
      }
      events.add(ProcEvent(owner.id, sk.id, targetId: from.id));
      final d = _procDamage(
          owner, from, math.max(1, jsRound(use * sk.shieldReflect)), sk.id);
      _notes.add('${sk.name}: refleja $d a ${from.name}');
    }
    for (final (o, sk) in bursts) {
      final owner = state.byId(o);
      if (owner == null) continue;
      final foes = state.enemies.where((e) => e.alive).toList();
      if (foes.isEmpty) break;
      final d = math.max(1, jsRound(_atk(owner) * sk.shieldBurst));
      events.add(ProcEvent(owner.id, sk.id, targetId: p.id));
      for (final e in foes) {
        _procDamage(owner, e, d, sk.id);
      }
      _notes.add('¡${sk.name} explota! $d a cada enemigo');
    }
    if (from != null && from.alive && !from.isPlayer) {
      for (final e in byOwner.entries) {
        final owner = state.byId(e.key);
        if (owner == null || !owner.alive) continue;
        final r = _conditionBonus(owner, BuffStat.shieldReflect);
        if (r <= 0 || !_spend()) continue;
        final src = _sourceOf(owner, BuffStat.shieldReflect) ?? 'escudo';
        events.add(ProcEvent(owner.id, src, targetId: from.id));
        final d = _procDamage(owner, from, math.max(1, jsRound(e.value * r)), src);
        _notes.add('${mechanicById(src)?.name ?? src}: $d a ${from.name}');
      }
    }
    return absorbed;
  }

  // ---------------- ascensión (docs/specs/ascension.md § 3.1) ----------

  /// Suma de los `statBonus` de [stat] de las auras de grupo
  /// (`partyAura`) de los jugadores en pie.
  double _aura(BuffStat stat) {
    var t = 0.0;
    for (final q in state.party) {
      if (!q.alive) continue;
      for (final m in _mechanicsOf(q)) {
        if (m.trigger != ProcTrigger.partyAura) continue;
        for (final fx in m.effects) {
          if (fx.kind == ProcEffectKind.statBonus && fx.stat == stat) {
            t += fx.value;
          }
        }
      }
    }
    return t;
  }

  /// La primera mecánica de [c] que da `statBonus` de [stat].
  String? _sourceOf(Combatant c, BuffStat stat) {
    for (final m in _mechanicsOf(c)) {
      if (m.effects.any(
          (fx) => fx.kind == ProcEffectKind.statBonus && fx.stat == stat)) {
        return m.id;
      }
    }
    return null;
  }

  /// Juramento Eterno: un Guardián en pie (no [p]) recibe su parte de
  /// [dmg]. Devuelve cuánto se llevó.
  int _shareDamage(Combatant p, int dmg) {
    if (!p.isPlayer || dmg <= 1) return 0;
    for (final g in state.party) {
      if (g == p || !g.alive) continue;
      for (final m in _mechanicsOf(g)) {
        if (m.trigger != ProcTrigger.partyAura) continue;
        for (final fx in m.effects) {
          if (fx.kind != ProcEffectKind.statBonus ||
              fx.stat != BuffStat.shareDamage) {
            continue;
          }
          final part = math.min(dmg - 1, jsRound(dmg * fx.value));
          if (part <= 0) return 0;
          events.add(ProcEvent(g.id, m.id, targetId: p.id));
          final taken = part - _absorb(g, part);
          g.hp = math.max(0, g.hp - taken);
          events.add(DamageEvent(g.id, taken, sourceId: m.id));
          _notes.add('${m.name}: ${g.name} recibe $part por ${p.name}');
          if (!g.alive) {
            events.add(KnockedOutEvent(g.id));
            g.voidMarked = false;
            _allyDown(g);
          }
          return part;
        }
      }
    }
    return 0;
  }

  /// Inmortal / Mártir: el golpe mortal deja a [p] en 1 HP (1 vez por
  /// batalla y por dueño). Devuelve el daño que pasa.
  int _cheatDeath(Combatant p, int taken) {
    // Primero la propia (Inmortal), después el aura de un aliado (Mártir).
    for (final pass in [false, true]) {
      for (final owner in pass ? state.party : [p]) {
        if (!owner.alive) continue;
        for (final m in _mechanicsOf(owner)) {
          final ok = pass
              ? m.trigger == ProcTrigger.partyAura
              : m.trigger == ProcTrigger.always;
          if (!ok ||
              !m.effects.any((fx) => fx.kind == ProcEffectKind.cheatDeath) ||
              owner.once.contains(m.id)) {
            continue;
          }
          owner.once.add(m.id);
          events.add(ProcEvent(owner.id, m.id, targetId: p.id));
          _notes.add('${m.name}: ${p.name} queda en 1 HP');
          return math.max(0, p.hp - 1);
        }
      }
    }
    return taken;
  }

  /// Cayó el jugador [p]: `onAllyDown` de los demás en pie.
  void _allyDown(Combatant p) {
    for (final q in state.party) {
      if (q != p && q.alive) _fire(ProcTrigger.onAllyDown, q, target: p);
    }
  }

  /// Las trampas de [e] saltan (al empezar su turno).
  void _springTraps(Combatant e) {
    final traps = [
      for (final fx in e.effects)
        if (fx.stat == BuffStat.trap) fx
    ];
    for (final t in traps) {
      if (!e.alive) return;
      final owner = t.ownerId == null ? null : state.byId(t.ownerId!);
      if (owner == null) continue;
      events.add(ProcEvent(owner.id, t.sourceId, targetId: e.id));
      final d = _procDamage(owner, e, math.max(1, t.value.round()), t.sourceId);
      _notes.add('¡Trampa de ${owner.name}! $d a ${e.name}');
      _fire(ProcTrigger.onTrap, owner, target: e, amount: d);
    }
  }

  /// Pone una trampa de [owner] en [target] (ATQ × [power]).
  void _plantTrap(Combatant owner, Combatant target, String sourceId,
      double power, int turns) {
    if (!target.alive || target.isPlayer) return;
    final dmg = math.max(
        1,
        jsRound(_atk(owner) *
            power *
            (1 + _conditionBonus(owner, BuffStat.trapPower))));
    final n = turns + _conditionBonus(owner, BuffStat.trapTurns).round();
    target.effects = [
      for (final e in target.effects)
        if (!(e.sourceId == sourceId && e.stat == BuffStat.trap)) e,
      TimedEffect(
          sourceId: sourceId,
          stat: BuffStat.trap,
          value: dmg.toDouble(),
          turns: n,
          ownerId: owner.id),
    ];
    events.add(BuffAppliedEvent(
        target.id, sourceId, BuffStat.trap, dmg.toDouble(), n));
  }

  /// Remata a [target] (no jefes ni élites) si quedó por debajo de
  /// [threshold] de su vida.
  void _execute(Combatant owner, Combatant target, double threshold,
      String sourceId, String name) {
    if (!target.alive ||
        target.isPlayer ||
        target.boss ||
        target.elite ||
        target.hp >= target.maxHp * threshold) {
      return;
    }
    events.add(ProcEvent(owner.id, sourceId, targetId: target.id));
    final d = target.hp;
    target.hp = 0;
    if (owner == _attacker) _dealt += d;
    events.add(DamageEvent(target.id, d, sourceId: sourceId));
    _knockedOut(target);
    _notes.add('$name: ¡${target.name} rematado!');
  }

  /// Buff de grupo de [owner] (con Eco del Grito y Señor de la Guerra).
  void _partyBuff(Combatant owner, String sourceId, String name,
      BuffStat stat, double value, int turns) {
    final v = value * (1 + _conditionBonus(owner, BuffStat.buffPower));
    final n = turns + _conditionBonus(owner, BuffStat.buffTurns).round();
    final m = PassiveMechanic(
        id: sourceId,
        name: name,
        trigger: ProcTrigger.onSkill,
        effects: const [],
        description: '');
    for (final q in _aliveParty) {
      _giveEffect(q, owner, m, stat, v, n);
      events.add(BuffAppliedEvent(q.id, sourceId, stat, v, n));
    }
    _notes.add('$name: grupo ${v < 0 ? '−' : '+'}${_pct(v)} ${stat.label} '
        '${_turns(n)}');
  }

  /// Escudo a todo el grupo: [frac] de la vida máx. de [owner].
  void _partyShield(Combatant owner, PassiveMechanic m, double frac, int turns,
      {Iterable<Combatant>? only}) {
    final amount = jsRound(owner.maxHp *
        frac *
        (1 + _conditionBonus(owner, BuffStat.shieldPower)));
    for (final q in only ?? _aliveParty.toList()) {
      _shield(q, owner, m, amount, turns);
    }
  }

  /// Adelanta a [allies] la fracción [frac] de su espera; sin aliados,
  /// adelanta el próximo turno de [owner] (tope [soloCap]).
  void _advance(Combatant owner, List<Combatant> allies, double frac,
      String name, {double soloCap = 1}) {
    if (allies.isEmpty) {
      final act = _act;
      if (act == null || act.extraTurn) return;
      final f = math.min(frac, soloCap);
      act.turnFactor = math.min(act.turnFactor, 1 - f);
      _notes.add('$name: tu próximo turno llega ${_pct(f)} antes');
      return;
    }
    for (final (i, q) in allies.indexed) {
      // 100% o más: actúa ya (en orden, después del reloj).
      q.nextTurn = frac >= 1
          ? math.min(q.nextTurn, state.clock + 0.01 * (i + 1))
          : math.max(state.clock + 0.01, q.nextTurn - _iv(q) * frac);
    }
    _notes.add(frac >= 1
        ? '$name: ${allies.map((q) => q.name).join(', ')} actúa'
            '${allies.length == 1 ? '' : 'n'} ya'
        : '$name: ${allies.map((q) => q.name).join(', ')} se adelanta'
            '${allies.length == 1 ? '' : 'n'} ${_pct(frac)}');
  }

  /// Una habilidad como "mecánica" (origen de sus efectos con duración).
  PassiveMechanic _skillMech(SkillDef sk) => PassiveMechanic(
      id: sk.id,
      name: sk.name,
      trigger: ProcTrigger.onSkill,
      effects: const [],
      description: '');

  /// Debuffs y Silencio de una variante sobre el enemigo [e]
  /// (combat.md § "Variantes de habilidades").
  void _variantOnHit(Combatant p, Combatant e, SkillDef tk) {
    if (!e.alive || e.isPlayer) return;
    if (tk.debuffs.isNotEmpty) {
      final m = _skillMech(tk);
      for (final d in tk.debuffs) {
        _giveEffect(e, p, m, d.stat, d.value, d.turns);
        events.add(BuffAppliedEvent(e.id, tk.id, d.stat, d.value, d.turns));
      }
    }
    if (tk.ultDrain > 0 && e.ultId != null && !e.ultPending && e.ult > 0) {
      e.ult = math.max(0, e.ult - tk.ultDrain);
      _notes.add('${tk.name}: ${e.name} −${jsRound(tk.ultDrain)} carga de ULT');
    }
  }

  /// Texto de los debuffs de [tk] para el log.
  String _debuffText(SkillDef tk) => [
        for (final d in tk.debuffs)
          ' · ${switch (d.stat) {
            BuffStat.damageTaken => 'Marca +${_pct(d.value)}',
            BuffStat.attack => 'ATQ −${_pct(d.value)}',
            BuffStat.speed => 'velocidad −${_pct(d.value)}',
            _ => '${d.stat.label} ${_pct(d.value)}',
          }} ${_turns(d.turns)}',
      ].join();

  /// Revive a [q] con la fracción `revive` de su vida (Resurrección).
  void _revive(Combatant p, Combatant q, SkillDef tk) {
    final h = math.max(1, jsRound(q.maxHp * tk.revive));
    _heal(q, h);
    if (tk.cleanse > 0) {
      for (final k in q.statuses.keys.toList()) {
        q.statuses[k] = 0;
      }
    } else {
      q.statuses[StatusKind.burn] = 0;
      q.statuses[StatusKind.poison] = 0;
    }
    q.nextTurn = state.clock + _iv(q);
    events.add(RevivedEvent(q.id));
    _fire(ProcTrigger.onHeal, p, target: q, amount: h);
    state.log = '${p.name} · ${tk.name}: ¡${q.name} revive con $h HP '
        '(${_pct(tk.revive)} de su vida)!';
  }

  /// Atraviesa y rebota (variantes): golpes secundarios tras el golpe a
  /// [target]. Aplican el estado (sin disparar el árbol) y los debuffs.
  void _pierceAndBounce(Combatant p, SkillDef tk, Combatant target,
      double base, StatusApplication? st, int bonus,
      {bool blocked = false}) {
    void extra(Combatant e, double dmg, List<String> parts,
        {String? from, bool pierced = false}) {
      final h = _damageEnemy(e, dmg, p.critChance + tk.critBonus,
          primary: false, chainFrom: from, pierced: pierced);
      parts.add('${h.damage} a ${e.name}');
      if (st != null && !blocked) _addStatus(e, st, bonus: bonus, source: p);
      _variantOnHit(p, e, tk);
    }

    if (tk.pierce > 0) {
      final i = state.enemies.indexOf(target);
      final behind = [
        for (final e in state.enemies.skip(i + 1))
          if (e.alive) e
      ];
      final parts = <String>[];
      for (final e in behind) {
        extra(e, base * tk.pierce, parts, pierced: true);
      }
      if (parts.isNotEmpty) _notes.add('atraviesa: ${parts.join(', ')}');
    }
    if (tk.bounces > 0) {
      var last = target;
      var f = 1.0;
      final parts = <String>[];
      for (var i = 0; i < tk.bounces; i++) {
        f *= 0.7;
        final others = [
          for (final e in state.enemies)
            if (e.alive && e != last) e
        ];
        final pick = others.isEmpty
            ? (last.alive ? last : null)
            : others[math.min(others.length - 1, (_rand() * others.length).floor())];
        if (pick == null) break;
        extra(pick, base * f, parts, from: last.id);
        last = pick;
      }
      if (parts.isNotEmpty) _notes.add('rebota: ${parts.join(', ')}');
    }
  }

  /// Disparo cargado: al empezar el turno de [p] cae sobre su objetivo
  /// (o el primer enemigo en pie).
  void _fireCharge(Combatant p) {
    final ch = [for (final e in p.effects) if (e.stat == BuffStat.charge) e];
    if (ch.isEmpty) return;
    p.effects = [for (final e in p.effects) if (e.stat != BuffStat.charge) e];
    for (final c in ch) {
      final foes = state.enemies.where((e) => e.alive).toList();
      if (foes.isEmpty) return;
      final t = foes.where((e) => e.id == c.ownerId).firstOrNull ?? foes.first;
      final sk = engine.catalog.skills[c.sourceId] ?? _ultById(c.sourceId);
      events.add(ProcEvent(p.id, c.sourceId, targetId: t.id));
      final d = _skillProcDamage(
          p, t, math.max(1, c.value.round()), c.sourceId, sk);
      var note = '¡${sk?.name ?? 'Disparo cargado'} de ${p.name}! $d a ${t.name}';
      final st = sk?.status;
      if (st != null && t.alive && _addStatus(t, st, source: p)) {
        note += ' · ${st.kind.label}';
      }
      _notes.add(note);
    }
  }

  /// Efectos de grupo / propios de una habilidad o ULT (kit de ascensión).
  void _skillExtras(Combatant p, SkillDef sk) {
    final asMech = PassiveMechanic(
        id: sk.id,
        name: sk.name,
        trigger: ProcTrigger.onSkill,
        effects: const [],
        description: '');
    for (final b in sk.partyBuffs) {
      _partyBuff(p, sk.id, sk.name, b.stat, b.value, b.turns);
    }
    if (sk.partyShield > 0) {
      _partyShield(p, asMech, sk.partyShield, sk.partyShieldTurns);
    }
    // Variantes: escudo al aliado más herido / a uno mismo.
    if (sk.allyShield > 0) {
      final q = _lowest(_aliveParty, (c) => c.hp / c.maxHp);
      if (q != null) {
        _partyShield(p, asMech, sk.allyShield, sk.shieldTurns, only: [q]);
      }
    }
    if (sk.selfShield > 0 && p.alive) {
      _partyShield(p, asMech, sk.selfShield, sk.shieldTurns, only: [p]);
    }
    if (sk.advanceAllies > 0) {
      _advance(p, [for (final q in _aliveParty) if (q != p) q],
          sk.advanceAllies, sk.name);
    }
    final sb = sk.selfBuff;
    if (sb != null) {
      _giveEffect(p, p, asMech, sb.stat, sb.value, sb.turns);
      events.add(BuffAppliedEvent(p.id, sk.id, sb.stat, sb.value, sb.turns));
      _notes.add('${sk.name}: +${_pct(sb.value)} ${sb.stat.label} '
          '${_turns(sb.turns)}');
    }
    if (sk.selfTurn < 1) {
      final act = _act;
      if (act != null) act.turnFactor = math.min(act.turnFactor, sk.selfTurn);
    }
    if (sk.protect) p.protecting = true;
  }

  /// Bonus de las condiciones del árbol de [a] (Último Aliento, Fractura,
  /// Punto Débil) sobre [stat], contra [target] si hay.
  double _conditionBonus(Combatant a, BuffStat stat, [Combatant? target]) {
    var total = 0.0;
    for (final (_, v) in _conditionParts(a, stat, target)) {
      total += v;
    }
    return total;
  }

  /// Las condiciones de [a] que suman a [stat] (mecánica, valor).
  List<(PassiveMechanic, double)> _conditionParts(Combatant a, BuffStat stat,
      [Combatant? target]) {
    final out = <(PassiveMechanic, double)>[];
    for (final m in _mechanicsOf(a)) {
      var scale = 1.0;
      final ok = switch (m.trigger) {
        ProcTrigger.whileLowHealth => a.hp < a.maxHp * m.threshold,
        ProcTrigger.vsStatus =>
          target != null && m.status != null && target.stacks(m.status!) > 0,
        ProcTrigger.vsMarked =>
          target != null && target.hasEffect(BuffStat.damageTaken),
        ProcTrigger.always => true,
        ProcTrigger.whileMissingHealth => () {
            scale = (1 - a.hp / a.maxHp).clamp(0.0, 1.0);
            return scale > 0;
          }(),
        ProcTrigger.vsBroken => target != null && target.broken,
        ProcTrigger.vsFamily => target != null &&
            m.family != null &&
            _fam(target)?.family == m.family,
        ProcTrigger.vsElements => target != null &&
            kElementalStatuses.where((k) => target.stacks(k) > 0).length >=
                m.minStacks,
        _ => false,
      };
      if (!ok || !_filterOk(m, a)) continue;
      for (final fx in m.effects) {
        if (fx.kind == ProcEffectKind.statBonus && fx.stat == stat) {
          out.add((m, fx.value * scale));
        }
      }
    }
    return out;
  }

  /// Multiplicador de crítico de [a] (con Un Disparo, Una Baja y Leyenda
  /// del Gatillo).
  double _critMult(Combatant? a) => a == null
      ? 1.5
      : a.critMultiplier +
          _conditionBonus(a, BuffStat.critMulti) +
          a.effectTotal(BuffStat.critMulti);

  /// Bonus al llenado de quiebre de las pasivas de arma de [a] contra
  /// [target] (Rompehielos, Grieta).
  double _breakBonus(Combatant a, Combatant target) {
    var total = 0.0;
    for (final m in _mechanicsOf(a)) {
      final ok = switch (m.trigger) {
        ProcTrigger.vsStatus =>
          m.status != null && target.stacks(m.status!) > 0,
        ProcTrigger.vsMarked => target.hasEffect(BuffStat.damageTaken),
        ProcTrigger.vsBroken => target.broken,
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
      {bool primary = true,
      bool single = false,
      int hitIndex = 0,
      String? chainFrom,
      bool pierced = false,
      Set<DamageTag>? tags,
      GameElement? element,
      bool? physical,
      StatusApplication? hitStatus}) {
    final a = _attacker;
    final cm = _critMult(a);
    // Elemento del golpe (v0.7): el de la habilidad de la acción, si no
    // físico (ataque normal).
    // Catalizador (Elementalista, ascension.md § 4.1): toma el elemento
    // que reacciona con lo que tenga el objetivo.
    final sk0 = _act?.skill;
    final catalyst = element == null && sk0 != null ? sk0.catalyst : 0.0;
    final el = element ??
        (catalyst > 0 ? _catalystElement(e) : null) ??
        elementOf(sk0?.id);
    final phys = physical ??
        (_act?.skill == null || _act!.skill!.kind == SkillKind.physical);
    var chance = critChance;
    var mult = 1.0;
    final mods = <String>[];
    if (a != null) {
      chance += _conditionBonus(a, BuffStat.crit, e) +
          a.effectTotal(BuffStat.crit);
      if (a.keystones.contains('danza')) chance = math.min(chance, 0.40);
      final parts = _conditionParts(a, BuffStat.damage, e);
      var dmgBonus = 0.0;
      for (final (_, v) in parts) {
        dmgBonus += v;
      }
      // Buffs de daño con duración (Combo de Equipo; árbol v6:
      // Preparación, Golpe Maestro, Ejecución Pública). Antes de la v0.8
      // no se leían (passive_tree_v6.md § 5).
      final buff = a.effectTotal(BuffStat.damage);
      if (buff != 0) {
        mult *= 1 + buff;
        mods.add('× ${fm(1 + buff)} buff');
      }
      // Aura Sagrada (Templario): todo el grupo hace más daño.
      final aura = a.isPlayer ? _aura(BuffStat.damage) : 0.0;
      if (dmgBonus != 0) {
        mult *= 1 + dmgBonus;
        mods.add('× ${fm(1 + dmgBonus)} '
            '${parts.map((p) => p.$1.name).toSet().join(' + ')}');
      }
      if (aura != 0) {
        mult *= 1 + aura;
        mods.add('× ${fm(1 + aura)} aura');
      }
      if (single && primary && a.keystones.contains('cadena')) {
        mult *= 0.8;
        mods.add('× 0.8 Cadena Infinita');
      }
    }
    final family = _fam(e);
    var taken = e.effectTotal(BuffStat.damageTaken);
    // Bestias: la Marca pega más (bestiary.md § 1).
    if (taken > 0) taken *= family?.markMult ?? 1;
    if (taken != 0) {
      mult *= 1 + taken;
      mods.add('× ${fm(1 + taken)} Marca');
    }
    final vul = e.broken;
    if (vul) {
      mult *= 1 + BattleEngine.vulnerableBonus;
      mods.add('× ${fm(1 + BattleEngine.vulnerableBonus)} QUIEBRE');
    }
    final armor = engine.catalog.enemies[e.enemyType]?.armor ?? 0;
    if (armor > 0) {
      mult *= 1 - armor;
      mods.add('× ${fm(1 - armor)} armadura');
    }
    // Familia: debilidades y resistencias por tipo de daño
    // (bestiary.md § 1.3).
    final affinity = _familyMods(
        family,
        {
          ...(tags ?? skillDamageTags(_act?.skill)),
          if (damageTagOf(el) case final t?) t,
        },
        mods);
    mult *= affinity;
    // Reacción elemental (una por golpe) o golpe físico a un Quebradizo
    // (elemental_reactions.md § 2 y § 7). Si el elemento propio del golpe
    // no reacciona, cuentan los estados que el golpe lleva (§ 9): los
    // extra de la habilidad (Electrólisis: Agua + Cargado) y los del
    // Avatar del Pacto.
    final carried = <StatusApplication>[
      if (hitStatus != null) hitStatus,
      if (element == null &&
          sk0 != null &&
          !kPrimeOnlySkills.contains(sk0.id)) ...[
        if (sk0.status != null) sk0.status!,
        ...sk0.extraStatuses,
      ],
      if (a != null) ..._avatarStatuses(a),
    ];
    final reaction = _reactionFor(e, el) ?? _carriedReaction(e, carried);
    var shatter = false;
    if (reaction != null) {
      final rm = _reactionMult(reaction);
      if (rm != 1) {
        mult *= rm;
        mods.add('× ${fm(rm)} ${reaction.label.toUpperCase()}');
      }
      if (catalyst > 0) {
        mult *= 1 + catalyst;
        mods.add('× ${fm(1 + catalyst)} CATALIZADOR');
      }
      final rb = a == null ? 0.0 : _modTotal(a, ProcEffectKind.reactionBonus);
      if (rb > 0) {
        mult *= 1 + rb;
        mods.add('× ${fm(1 + rb)} reacción');
      }
    } else if (phys && _isBrittle(e)) {
      shatter = true;
      mult *= _frz.brittleMult;
      mods.add('× ${fm(_frz.brittleMult)} QUEBRADIZO');
    }
    final res = primary ? _stanceResist(e) : 0.0;
    if (res > 0) {
      mult *= 1 - res;
      mods.add('× ${fm(1 - res)} POSTURA');
      if (_resisted.add(e.id)) {
        events.add(
            BossMechanicEvent(e.id, BossMechanicPhase.resisted, value: res));
      }
    }
    // Ecos de la Hechicera: reciben daño reducido.
    final echo = _echoFactor(e);
    if (echo < 1) {
      mult *= echo;
      mods.add('× ${fm(echo)} ECO');
      if (_resisted.add(e.id)) {
        events.add(
            BossMechanicEvent(e.id, BossMechanicPhase.echoResist, value: echo));
      }
    }
    // Jefes del Abismo: inmunidad, sello y aspecto (abyss_bosses.md § 2).
    final abyss = _abyssFactor(e, el, mods);
    mult *= abyss;
    // Esquiva de los comunes (solo tira el dado si la tiene).
    final ev = engine.catalog.enemies[e.enemyType]?.evasion ?? 0;
    if (primary && ev > 0 && _rand() < ev) {
      mult *= BattleEngine.evadeFactor;
      mods.add('× ${fm(BattleEngine.evadeFactor)} ESQUIVA');
      events.add(BossMechanicEvent(e.id, BossMechanicPhase.evaded));
    }
    final crit = _rand() < chance;
    final dmg = abyss == 0
        ? 0
        : math.max(1, jsRound(base * (crit ? cm : 1) * mult));
    final breakBonus = a == null ? 0.0 : _breakBonus(a, e);
    final before = e.hp;
    e.hp = math.max(0, e.hp - dmg);
    final shift = _gatePhase(e);
    final lost = before - e.hp;
    _dealt += lost;
    _dealtMaxHp = math.max(_dealtMaxHp, e.maxHp);
    events.add(DamageEvent(e.id, dmg,
        critical: crit,
        critMultiplier: cm,
        vulnerable: vul,
        hitIndex: hitIndex,
        chainFrom: chainFrom,
        pierced: pierced,
        affinity: affinity));
    if (!e.alive) _knockedOut(e);
    if (shift) _transform(e);
    _chargeUlt(e, lost);
    if (reaction != null) {
      _react(a, e, reaction, dmg, hitStatus: hitStatus ?? _act?.skill?.status);
    } else if (shatter) {
      _shatter(e);
    }
    // Avatar del Pacto (summoner.md § 7): los estados de lo absorbido.
    if (primary && a != null) _avatarHit(a, e);
    // La transformación vacía la barra: el golpe que la causa no llena.
    if (!shift) {
      _addBreak(
          e,
          dmg *
              (primary
                  ? (_act?.breakFactor ?? BattleEngine.breakAttack)
                  : BattleEngine.breakSecondary) *
              (crit ? BattleEngine.breakCrit : 1) *
              (1 + breakBonus));
    }
    final hit = _Hit(dmg, crit, e, mods);
    if (primary && a != null && _act != null) {
      final prevHit = _hitNow;
      _hitNow = (target: e, damage: dmg, reacted: reaction != null);
      _fire(ProcTrigger.onHit, a, target: e, amount: dmg);
      if (crit) _fire(ProcTrigger.onCrit, a, target: e, amount: dmg);
      _hitNow = prevHit;
    }
    return hit;
  }

  /// Daño secundario de una mecánica: sin crítico, solo la Marca del
  /// objetivo. No dispara nada (salvo las muertes).
  int _procDamage(Combatant owner, Combatant e, int amount, String sourceId) {
    if (!e.alive) return 0;
    final taken = e.effectTotal(BuffStat.damageTaken);
    final vul = e.broken;
    final abyss = _abyssFactor(e, null);
    final dmg = abyss == 0
        ? 0
        : math.max(
            1,
            jsRound(amount *
                (1 + taken) *
                _echoFactor(e) *
                abyss *
                (vul ? 1 + BattleEngine.vulnerableBonus : 1)));
    final before = e.hp;
    e.hp = math.max(0, e.hp - dmg);
    final shift = _gatePhase(e);
    final lost = before - e.hp;
    if (owner == _attacker) {
      _dealt += lost;
      _dealtMaxHp = math.max(_dealtMaxHp, e.maxHp);
    }
    events.add(DamageEvent(e.id, dmg, sourceId: sourceId, vulnerable: vul));
    if (!e.alive) _knockedOut(e);
    if (shift) _transform(e);
    _chargeUlt(e, lost);
    if (!shift) _addBreak(e, dmg * BattleEngine.breakSecondary);
    return dmg;
  }

  // ---------------- familias (docs/specs/bestiary.md § 1) ----------------

  /// Reglas de la familia / raza de [c] (`null`: sin familia o familias
  /// apagadas). Simétrico desde v0.7 (elemental_reactions.md § 5.3): un
  /// jugador con raza usa las mismas reglas que un enemigo.
  FamilyRule? _fam(Combatant c) {
    final f = c.family;
    return !engine.familiesEnabled || f == null ? null : kFamilyRules[f];
  }

  // ---------------- elementos v0.7 (elemental_reactions.md) ------------

  /// Reglas de la Congelación (§ 7).
  ElementStatusDef get _frz =>
      engine.catalog.elementStatus(StatusKind.freeze);

  /// La reacción que detonaría un golpe de [el] sobre [t] (§ 2), o
  /// `null`. Congelación súbita solo si [t] se puede congelar.
  ReactionKind? _reactionFor(Combatant t, GameElement el) {
    if (el == GameElement.fisico || !t.alive) return null;
    for (final r in kReactionTable) {
      if (r.detonator != el || t.stacks(r.primer) <= 0) continue;
      if (r.kind == ReactionKind.congelacionSubita && !_canFreeze(t)) continue;
      return r.kind;
    }
    return null;
  }

  /// La reacción que detona algún estado que lleva el golpe ([carried],
  /// en orden), o `null` (§ 9: el golpe cuenta como de ese elemento).
  ReactionKind? _carriedReaction(
      Combatant t, Iterable<StatusApplication> carried) {
    for (final s in carried) {
      final el = statusElement(s.kind);
      if (el == null) continue;
      final r = _reactionFor(t, el);
      if (r != null) return r;
    }
    return null;
  }

  /// La reacción que detonaría un golpe de la habilidad [tk] sobre [t]
  /// (como la calcula `_damageEnemy`), o `null`.
  ReactionKind? _skillReaction(Combatant t, SkillDef tk) {
    final el = (tk.catalyst > 0 ? _catalystElement(t) : null) ??
        elementOf(tk.id);
    final prime = kPrimeOnlySkills.contains(tk.id);
    return _reactionFor(t, el) ??
        _carriedReaction(t, [
          if (!prime && tk.status != null) tk.status!,
          if (!prime) ...tk.extraStatuses,
          if (_attacker case final a?) ..._avatarStatuses(a),
        ]);
  }

  /// La ULT [id] (de tipo de arma, de camino / Invocador o de ascensión).
  SkillDef? _ultById(String id) =>
      kWeaponUltSkills[id] ??
      engine.catalog.ultimates.values.where((u) => u.id == id).firstOrNull ??
      kAscensionUltimates.values.where((u) => u.id == id).firstOrNull;

  /// Daño de mecánica que repite / difiere un golpe de la habilidad [sk]
  /// (Eco Arcano, Disparo cargado): lleva su elemento, así que detona
  /// como el golpe original (§ 9). Devuelve el daño hecho.
  int _skillProcDamage(Combatant owner, Combatant e, int amount,
      String sourceId, SkillDef? sk) {
    final k = sk == null || !e.alive ? null : _skillReaction(e, sk);
    final d = _procDamage(
        owner,
        e,
        k == null ? amount : math.max(1, jsRound(amount * _reactionMult(k))),
        sourceId);
    if (k != null) _react(owner, e, k, d, hitStatus: sk!.status);
    return d;
  }

  /// Un estado elemental [st] que [owner] deja con el golpe en curso
  /// (`onHit` / `onCrit` del árbol o del arma: Dios del Trueno, Señora
  /// de las Mareas...) detona la reacción si el golpe no reaccionó ya
  /// (§ 9). Lo que falta del ×1.5 entra como daño de la reacción. Se
  /// resuelve ANTES de aplicar [st].
  void _procHitReact(Combatant owner, Combatant target, PassiveMechanic m,
      StatusApplication st) {
    final h = _hitNow;
    // Las mecánicas "contra un X" (`status`: Aguanieve sobre Mojados)
    // trabajan SOBRE el estado preparado: no lo detonan.
    if (h == null ||
        h.reacted ||
        h.target != target ||
        m.status != null ||
        (m.trigger != ProcTrigger.onHit && m.trigger != ProcTrigger.onCrit)) {
      return;
    }
    final el = statusElement(st.kind);
    if (el == null) return;
    final k = _reactionFor(target, el);
    if (k == null) return;
    _hitNow = (target: h.target, damage: h.damage, reacted: true);
    final rb = _modTotal(owner, ProcEffectKind.reactionBonus);
    final mult = _reactionMult(k) * (1 + rb);
    final total = math.max(h.damage, jsRound(h.damage * mult));
    if (total > h.damage) {
      _rawDamage(owner, target, total - h.damage, reactionSourceId(k));
    }
    _react(owner, target, k, total, hitStatus: st);
  }

  /// Elemento con el que un golpe catalizador detona lo que tiene [t]
  /// (orden de prioridad de la tabla), o `null` si no hay nada.
  GameElement? _catalystElement(Combatant t) {
    for (final r in kReactionTable) {
      if (t.stacks(r.primer) > 0 && _reactionFor(t, r.detonator) == r.kind) {
        return r.detonator;
      }
    }
    return null;
  }

  /// Suma de un modificador fijo (`always`) del árbol de [a]
  /// (`reactionBonus`, `healHarmBonus`).
  double _modTotal(Combatant a, ProcEffectKind kind) {
    var total = 0.0;
    for (final m in _mechanicsOf(a)) {
      if (m.trigger != ProcTrigger.always || !_filterOk(m, a)) continue;
      for (final fx in m.effects) {
        if (fx.kind == kind) total += fx.value;
      }
    }
    return total;
  }

  /// [t] puede quedar congelado ya (Congelación súbita).
  bool _canFreeze(Combatant t) =>
      t.freezeResist <= 0 &&
      !t.brittle &&
      t.stacks(StatusKind.freeze) < StatusKind.freeze.maxStacks &&
      !(_fam(t)?.immune.contains(StatusKind.freeze) ?? false) &&
      !(!t.isPlayer && _immune(t));

  /// Multiplicador del golpe que detona [k] (1 si no cambia el golpe).
  double _reactionMult(ReactionKind? k) => switch (k) {
        ReactionKind.electrocucion ||
        ReactionKind.derretir =>
          engine.catalog.reaction(k!).damageMult,
        _ => 1.0,
      };

  /// Quebradizo con Congelación encima.
  bool _isBrittle(Combatant c) =>
      c.brittle && c.stacks(StatusKind.freeze) > 0;

  /// Se descongela: sin Congelación ni Quebradizo y, si estaba congelado,
  /// resistencia a la Congelación ([ElementStatusDef.turns]).
  void _thawFreeze(Combatant c, {bool resist = true}) {
    final wasFrozen = c.brittle ||
        c.stacks(StatusKind.freeze) >= StatusKind.freeze.maxStacks;
    c.statuses[StatusKind.freeze] = 0;
    c.brittle = false;
    if (resist && wasFrozen) {
      c.freezeResist = math.max(c.freezeResist, _frz.turns);
      events.add(IceEvent(c.id, IcePhase.thawed));
    }
  }

  /// Un golpe físico rompió al Quebradizo [c].
  void _shatter(Combatant c) {
    _thawFreeze(c, resist: false);
    c.freezeResist = math.max(c.freezeResist, _frz.turns);
    events.add(IceEvent(c.id, IcePhase.shattered));
    _notes.add('¡${c.name} se rompe! (Quebradizo ×${fm(_frz.brittleMult)}, '
        'se descongela)');
  }

  /// Los demás vivos del bando de [t], en orden de formación desde [t].
  List<Combatant> _sideOf(Combatant t) {
    final side = t.isPlayer ? state.party : state.enemies;
    final i = side.indexOf(t);
    final out = <Combatant>[];
    for (var k = 1; k < side.length; k++) {
      final c = side[(i + k) % side.length];
      if (c.alive && !_passive(c)) out.add(c);
    }
    return out;
  }

  /// La reacción [k]: [by] detonó el estado de [t] con un golpe de
  /// [hitDamage] (ya con el ×1.5 si corresponde). [hitStatus]: el estado
  /// del golpe (Cortocircuito lo lleva al salto).
  void _react(Combatant? by, Combatant t, ReactionKind k, int hitDamage,
      {StatusApplication? hitStatus}) {
    final def = engine.catalog.reaction(k);
    final consumed = t.stacks(k.primer);
    // La transformación (Devorador) pudo limpiar el estado.
    if (consumed <= 0) return;
    final primer = t.primedBy.remove(k.primer);
    final src = reactionSourceId(k);
    final splash = <String, int>{};
    var amount = hitDamage;
    switch (k) {
      case ReactionKind.electrocucion:
        t.statuses[StatusKind.wet] = 0;
        events.add(ReactionEvent(t.id, k, amount,
            sourceId: by?.id, consumedStacks: consumed));
        final stunned = def.stunTurns > 0 &&
            _addStatus(t, StatusApplication(StatusKind.stun, def.stunTurns),
                source: by);
        _notes.add('¡ELECTROCUCIÓN! ${t.name} ×${fm(def.damageMult)}'
            '${stunned ? ' y queda aturdido' : ''}');
      case ReactionKind.explosionToxica:
        t.statuses[StatusKind.poison] = 0;
        final base = math.max(1, jsRound(hitDamage * def.perStack * consumed));
        int capped(Combatant c, int d) => c.boss && def.bossCap > 0
            ? math.min(d, math.max(1, jsRound(c.maxHp * def.bossCap)))
            : d;
        amount = t.alive ? capped(t, base) : 0;
        final others = _sideOf(t);
        if (def.splash > 0) {
          final sp = math.max(1, jsRound(base * def.splash));
          for (final c in others) {
            splash[c.id] = capped(c, sp);
          }
        }
        events.add(ReactionEvent(t.id, k, amount,
            sourceId: by?.id, consumedStacks: consumed, splash: splash));
        if (amount > 0) _rawDamage(by, t, amount, src);
        for (final c in others) {
          final d = splash[c.id];
          if (d != null) _rawDamage(by, c, d, src);
        }
        final capNote = t.boss && amount < base ? ' (tope de jefe)' : '';
        final splashNote = splash.isEmpty
            ? ''
            : ' · salpica a ${splash.length} '
                '(${splash.values.map((d) => '$d').join(', ')})';
        _notes.add('¡EXPLOSIÓN TÓXICA! $consumed Veneno × $hitDamage = '
            '$amount a ${t.name}$capNote$splashNote');
      case ReactionKind.congelacionSubita:
        t.statuses[StatusKind.wet] = 0;
        final n = StatusKind.freeze.maxStacks - t.stacks(StatusKind.freeze);
        t.statuses[StatusKind.freeze] = StatusKind.freeze.maxStacks;
        events.add(ReactionEvent(t.id, k, 0,
            sourceId: by?.id, consumedStacks: consumed));
        events.add(StatusAppliedEvent(t.id, StatusKind.freeze, n));
        if (by != null && by.isPlayer && !t.isPlayer) {
          _addBreak(t, BattleEngine.breakStatusFlat);
        }
        _notes.add('¡CONGELACIÓN SÚBITA! ${t.name} queda CONGELADO');
      case ReactionKind.derretir:
        events.add(ReactionEvent(t.id, k, amount,
            sourceId: by?.id, consumedStacks: consumed));
        _meltedNow.add(t.id);
        _thawFreeze(t);
        _notes.add('¡DERRETIR! ${t.name} ×${fm(def.damageMult)} y pierde la '
            'Congelación');
      case ReactionKind.cortocircuito:
        t.statuses[StatusKind.charged] = 0;
        final next = _sideOf(t).firstOrNull;
        amount = 0;
        if (next != null && def.splash > 0) {
          amount = math.max(1, jsRound(hitDamage * def.splash));
          splash[next.id] = amount;
        }
        events.add(ReactionEvent(t.id, k, amount,
            sourceId: by?.id, consumedStacks: consumed, splash: splash));
        if (next != null && amount > 0) {
          final d = _rawDamage(by, next, amount, src);
          if (hitStatus != null && next.alive) {
            _addStatus(next, hitStatus, source: by);
          }
          _notes.add('¡CORTOCIRCUITO! salta a ${next.name}: $d');
        } else {
          _notes.add('¡CORTOCIRCUITO! (nadie a quien saltar)');
        }
    }
    _reactionTriggers(by, t, k, hitDamage, consumed, primer,
        {t.id, ...splash.keys}, hitStatus);
    // Sello de un Jefe del Abismo: lo rompe la reacción pedida.
    _abyssReacted(by, t, k);
  }

  /// Disparadores del árbol de una reacción que detonó [by] sobre [t]
  /// (passive_tree_v4.md § 8): `onReaction` (quien detonó),
  /// `onPrimedReaction` (quien preparó el estado consumido) y
  /// `onPartyReaction` (todo el grupo vivo). Solo jugadores sobre
  /// enemigos.
  void _reactionTriggers(
      Combatant? by,
      Combatant t,
      ReactionKind k,
      int hitDamage,
      int consumed,
      String? primer,
      Set<String> hitIds,
      StatusApplication? hitStatus) {
    if (by == null || !by.isPlayer || t.isPlayer) return;
    final prev = _rx;
    _rx = _Rx(k, consumed, by, hitIds, hitStatus);
    _fire(ProcTrigger.onReaction, by, target: t, amount: hitDamage);
    if (primer != null) {
      final q = state.party.where((c) => c.id == primer).firstOrNull;
      if (q != null && q.alive) {
        _fire(ProcTrigger.onPrimedReaction, q, target: t, amount: hitDamage);
      }
    }
    for (final q in state.party) {
      if (q.alive) {
        _fire(ProcTrigger.onPartyReaction, q, target: t, amount: hitDamage);
      }
    }
    _rx = prev;
  }

  /// Daño directo (reacciones, curas que dañan): sin crítico ni
  /// multiplicadores; a un jugador lo absorben sus escudos. Devuelve el
  /// daño hecho.
  int _rawDamage(Combatant? by, Combatant t, int amount, String sourceId) {
    if (!t.alive || amount <= 0) return 0;
    if (t.isPlayer) {
      final absorbed = _absorb(t, amount);
      var taken = amount - absorbed;
      if (taken >= t.hp) taken = _cheatDeath(t, taken);
      if (taken > 0) {
        t.ult = math.min(
            100, t.ult + taken / t.maxHp * 110 * (1 + t.ultChargeBonus));
      }
      t.hp = math.max(0, t.hp - taken);
      events.add(DamageEvent(t.id, taken, sourceId: sourceId));
      if (!t.alive) {
        t.voidMarked = false;
        _knockedOut(t);
      }
      return taken;
    }
    // Jefe del Abismo inmune al daño (las curas que dañan sí entran).
    if (sourceId != kAbyssHealSourceId && _abyssFactor(t, null) == 0) {
      return 0;
    }
    final before = t.hp;
    t.hp = math.max(0, t.hp - amount);
    final shift = _gatePhase(t);
    final lost = before - t.hp;
    if (by != null && by == _attacker) {
      _dealt += lost;
      _dealtMaxHp = math.max(_dealtMaxHp, t.maxHp);
    }
    events.add(DamageEvent(t.id, amount, sourceId: sourceId));
    if (!t.alive) _knockedOut(t);
    if (shift) _transform(t);
    _chargeUlt(t, lost);
    if (!shift && by != null && by.isPlayer) {
      _addBreak(t, amount * BattleEngine.breakSecondary);
    }
    return amount;
  }

  /// Cura de habilidad de [p] a [q]; a una raza / familia con `healHarm`
  /// (no muerto) le hace daño (§ 5.4). Devuelve lo curado (0 si dañó).
  int _skillHeal(Combatant p, Combatant q, int amount) {
    final harm = _fam(q)?.healHarm ?? 0;
    if (harm <= 0) {
      _heal(q, amount);
      return amount;
    }
    final d = _rawDamage(null, q, math.max(1, jsRound(amount * harm)),
        kHealHarmSourceId);
    _notes.add('¡La cura quema a ${q.name}! $d');
    return 0;
  }

  /// Factor de la familia [r] para un golpe con [tags]; agrega cada
  /// factor a [mods] (`× 1.5 DÉBIL Sagrado`).
  double _familyMods(FamilyRule? r, Set<DamageTag> tags, List<String> mods) {
    var m = 1.0;
    for (final f in familyFactors(r, tags)) {
      m *= f.value;
      mods.add('× ${fm(f.value)} ${f.weak ? 'DÉBIL' : 'RESISTE'} '
          '${f.tag.label}');
    }
    return m;
  }

  /// Las curas de habilidad del grupo dañan a las familias con
  /// `healHarm` (no muertos, espectros): cada enemigo vivo así recibe
  /// [amount] × `healHarm` (más Marca y quiebre). Devuelve el texto del
  /// log ("¡La cura quema al Esqueleto! 34") o vacío.
  String _healHarm(Combatant p, int amount) {
    final hit = <(Combatant, int)>[];
    for (final e in state.enemies) {
      if (!e.alive) continue;
      final r = _fam(e);
      if (r == null || r.healHarm <= 0) continue;
      // Luz Purificadora (árbol v5): +daño de tus curas a estas familias.
      final bonus = 1 + _modTotal(p, ProcEffectKind.healHarmBonus);
      final d = math.max(1, jsRound(amount * r.healHarm * bonus));
      hit.add((e, _procDamage(p, e, d, kHealHarmSourceId)));
    }
    if (hit.isEmpty) return '';
    if (hit.length == 1) {
      final (e, d) = hit.first;
      final fem = engine.catalog.enemies[e.enemyType]?.feminine ?? false;
      return ' · ¡La cura quema ${fem ? 'a la' : 'al'} ${e.name}! $d';
    }
    return ' · ¡La cura quema a los no muertos! '
        '${hit.map((h) => '${h.$1.name} ${h.$2}').join(', ')}';
  }

  /// Un actor cae. Si es un enemigo: cuenta para `onKill` de la acción y
  /// dispara `onEnemyDeath` (Plaga) del primer jugador que la tenga.
  void _knockedOut(Combatant c) {
    events.add(KnockedOutEvent(c.id));
    if (c.isPlayer) {
      _allyDown(c);
      return;
    }
    _mechanicDeath(c);
    _act?.killed = true;
    // Cada mecánica `onEnemyDeath` dispara una vez por muerte: la del
    // primer jugador que la tenga (Plaga, Detonación).
    final used = <String>{};
    for (final p in state.party) {
      if (!p.alive) continue;
      if (_mechanicsOf(p).any((m) => m.trigger == ProcTrigger.onEnemyDeath)) {
        _fire(ProcTrigger.onEnemyDeath, p, target: c, once: used);
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
    final cm = _critMult(_attacker);
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

  /// Texto del estado principal de una acción del grupo según lo que
  /// PASÓ: intentado en [tried] objetivos vivos, entró en [landed]. Nunca
  /// dice que un estado entró si no entró (falló la probabilidad o el
  /// objetivo es inmune: "un enemigo aturdido igual me atacó", v0.5.1).
  String _statusOutcome(
      StatusApplication st, int bonus, int tried, int landed) {
    final n = st.stacks + bonus;
    final chance = st.chance;
    final pct = chance == null ? '' : ' (${jsRound(chance * 100)}%)';
    if (tried == 0) {
      // Los objetivos cayeron con el golpe: nada que informar.
      return chance == null ? _statusText(st, bonus: bonus) : '';
    }
    if (landed == 0) {
      // Inmune (el aviso de INMUNE ya va en el log) o falló la tirada.
      return chance == null ? '' : ' · ${st.kind.label}: falla$pct';
    }
    if (tried == 1 || (landed == tried && chance == null)) {
      return ' · +$n ${st.kind.label}$pct';
    }
    return ' · +$n ${st.kind.label} a $landed de $tried$pct';
  }

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
    if (!_filterOk(m, owner)) return false;
    if (m.reaction != null &&
        (m.trigger == ProcTrigger.onReaction ||
            m.trigger == ProcTrigger.onPrimedReaction ||
            m.trigger == ProcTrigger.onPartyReaction) &&
        _rx?.kind != m.reaction) {
      return false;
    }
    final st = m.status;
    if (st == null) return true;
    return switch (m.trigger) {
      ProcTrigger.onStatusApplied => status == st,
      ProcTrigger.onHit => target != null && target.stacks(st) >= m.minStacks,
      ProcTrigger.onEnemyDeath => target != null && target.stacks(st) > 0,
      _ => true,
    };
  }

  /// El filtro de [m] sobre la acción en curso de [owner].
  bool _filterOk(PassiveMechanic m, Combatant owner) {
    final act = _act;
    final sk = act?.skill;
    final ult = act?.ultimate ?? false;
    return switch (m.filter) {
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
      ProcFilter.belowThreshold => owner.hp < owner.maxHp * m.threshold,
      ProcFilter.rallySkill => sk != null && sk.rally,
    };
  }

  /// Evalúa las mecánicas de [owner] con disparador [trigger]. [amount]:
  /// daño del golpe, daño recibido o vida curada, según el disparador.
  void _fire(ProcTrigger trigger, Combatant owner,
      {Combatant? target,
      StatusKind? status,
      int amount = 0,
      Set<String>? once}) {
    if (owner.mechanics.isEmpty) return;
    for (final m in _mechanicsOf(owner).toList()) {
      if (m.trigger != trigger || m.effects.isEmpty) continue;
      if (!_passes(m, owner, target, status)) continue;
      if (once != null && once.contains(m.id)) continue;
      final act = _act;
      if (act != null) {
        final perTarget = target != null && m.effects.any((e) => e.onTarget);
        // Reacciones (árbol v5): cada dueño dispara la suya.
        final who = trigger == ProcTrigger.onPrimedReaction ||
                trigger == ProcTrigger.onPartyReaction
            ? '@${owner.id}'
            : '';
        if (!act.fired
            .add('${perTarget ? '${m.id}|${target.id}' : m.id}$who')) {
          continue;
        }
      }
      if (m.chance < 1 && _rand() >= m.chance) continue;
      if (!_spend()) return;
      once?.add(m.id);
      for (final fx in m.effects) {
        _applyEffect(m, fx, owner, target, amount, status);
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
      Combatant? target, int amount, [StatusKind? status]) {
    final act = _act;
    switch (fx.kind) {
      // ---- ascensión (docs/specs/ascension.md § 3.1) ----
      case ProcEffectKind.buffParty:
        events.add(ProcEvent(owner.id, m.id));
        _partyBuff(owner, m.id, m.name, fx.stat!, fx.value, fx.turns);
      case ProcEffectKind.shieldParty:
        _partyShield(owner, m, fx.value, fx.turns);
      case ProcEffectKind.shieldLowestAlly:
        final q = _lowest(_aliveParty, (c) => c.hp / c.maxHp);
        if (q == null) return;
        _partyShield(owner, m, fx.value, fx.turns, only: [q]);
      case ProcEffectKind.healParty:
        events.add(ProcEvent(owner.id, m.id));
        for (final q in _aliveParty) {
          _heal(q, math.max(1, jsRound(q.maxHp * fx.value)));
        }
        _notes.add('${m.name}: el grupo se cura ${_pct(fx.value)}');
      case ProcEffectKind.advanceAlly:
        Combatant? slow;
        for (final q in _aliveParty) {
          if (q != owner && (slow == null || q.nextTurn > slow.nextTurn)) {
            slow = q;
          }
        }
        events.add(ProcEvent(owner.id, m.id, targetId: slow?.id));
        _advance(owner, [if (slow != null) slow], fx.value, m.name);
      case ProcEffectKind.advanceParty:
        events.add(ProcEvent(owner.id, m.id));
        _advance(owner, [for (final q in _aliveParty) if (q != owner) q],
            fx.value, m.name,
            soloCap: 0.5);
      case ProcEffectKind.ultChargeParty:
        final allies = [for (final q in _aliveParty) if (q != owner) q];
        if (allies.isEmpty) return;
        events.add(ProcEvent(owner.id, m.id));
        for (final q in allies) {
          q.ult = math.min(100, q.ult + fx.value);
        }
        _notes.add('${m.name}: aliados +${jsRound(fx.value)} carga de ULT');
      case ProcEffectKind.drainUlt:
        if (target == null ||
            !target.alive ||
            target.ultId == null ||
            target.ultPending ||
            target.ult <= 0) {
          return;
        }
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        target.ult = math.max(0, target.ult - fx.value);
        _notes.add('${m.name}: ${target.name} −${jsRound(fx.value)} carga '
            'de ULT');
      case ProcEffectKind.execute:
        if (target == null) return;
        _execute(owner, target, fx.value, m.id, m.name);
      case ProcEffectKind.plantTrap:
        if (target == null || !target.alive) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        _plantTrap(owner, target, m.id, fx.value, fx.turns);
      case ProcEffectKind.burst:
        if (target == null) return;
        final others =
            state.enemies.where((e) => e != target && e.alive).toList();
        if (others.isEmpty) return;
        final d = math.max(1, jsRound(amount * fx.value));
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        final parts = [
          for (final e in others) '${_procDamage(owner, e, d, m.id)} a ${e.name}',
        ];
        _notes.add('${m.name}: ${parts.join(', ')}');
      case ProcEffectKind.spreadAll:
        if (target == null) return;
        final stacks = {
          for (final k in kElementalStatuses)
            if (target.stacks(k) > 0) k: (target.stacks(k) * fx.value).ceil(),
        };
        final others = state.enemies.where((e) => e != target && e.alive);
        if (stacks.isEmpty || others.isEmpty) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        for (final e in others.toList()) {
          stacks.forEach(
              (k, n) => _addStatus(e, StatusApplication(k, n), source: owner));
        }
        _notes.add('${m.name}: los estados de ${target.name} se esparcen');
      case ProcEffectKind.addElement:
        if (target == null ||
            !target.alive ||
            status == null ||
            !kElementalStatuses.contains(status)) {
          return;
        }
        final k = kElementalStatuses
            .where((s) => s != status && target.stacks(s) == 0)
            .firstOrNull;
        if (k == null) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        if (_addStatus(target, StatusApplication(k, fx.value.round()),
            source: owner)) {
          _notes.add('${m.name}: ${target.name} +${fx.value.round()} '
              '${k.label}');
        }
      case ProcEffectKind.cheatDeath:
        break; // modificador: lo aplica `_cheatDeath`

      // ---- reacciones v0.7 (passive_tree_v4.md § 8) ----
      case ProcEffectKind.extraJump:
        final rx = _rx;
        if (rx == null || target == null) return;
        final def = engine.catalog.reaction(rx.kind);
        final d = math.max(1, jsRound(amount * def.splash));
        final next = [
          for (final c in _sideOf(target))
            if (!rx.hitIds.contains(c.id)) c,
        ].take(math.max(1, fx.value.round())).toList();
        if (next.isEmpty || def.splash <= 0) return;
        events.add(ProcEvent(owner.id, m.id, targetId: next.first.id));
        final parts = <String>[];
        for (final c in next) {
          rx.hitIds.add(c.id);
          final dealt = _rawDamage(owner, c, d, reactionSourceId(rx.kind));
          if (rx.hitStatus != null && c.alive) {
            _addStatus(c, rx.hitStatus!, source: owner);
          }
          parts.add('$dealt a ${c.name}');
        }
        _notes.add('${m.name}: salta otra vez · ${parts.join(', ')}');
      case ProcEffectKind.refundMp:
        final sk = act?.skill;
        if (act == null || sk == null || act.ultimate || sk.mp <= 0) return;
        events.add(ProcEvent(owner.id, m.id));
        owner.mp = math.min(owner.maxMp.toDouble(), owner.mp + sk.mp);
        events.add(HealEvent(owner.id, sk.mp, mana: true));
        _notes.add('${m.name}: +${sk.mp} MP');
      case ProcEffectKind.reactionStatus:
        final rx = _rx;
        final st = fx.status;
        if (rx == null || st == null || target == null || !target.alive) {
          return;
        }
        final n = (rx.consumed * fx.value).ceil();
        if (n <= 0) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        if (_addStatus(target, StatusApplication(st, n), source: owner)) {
          _notes.add('${m.name}: ${target.name} +$n ${st.label}');
        }
      case ProcEffectKind.brittleAll:
        final hit = [
          for (final e in state.enemies)
            if (e != target &&
                e.alive &&
                !e.brittle &&
                e.stacks(StatusKind.freeze) > 0 &&
                e.stacks(StatusKind.freeze) < StatusKind.freeze.maxStacks)
              e,
        ];
        if (hit.isEmpty) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target?.id));
        for (final e in hit) {
          e.brittle = true;
          events.add(IceEvent(e.id, IcePhase.brittle));
        }
        _notes.add('${m.name}: ${hit.map((e) => e.name).join(', ')} '
            'quedan QUEBRADIZOS');
      case ProcEffectKind.lockStun:
        if (target == null ||
            !target.alive ||
            target.boss ||
            target.stacks(StatusKind.stun) <= 0 ||
            target.hasEffect(BuffStat.stunLock)) {
          return;
        }
        final turns = math.max(1, fx.turns);
        target.effects = [
          ...target.effects,
          TimedEffect(
              sourceId: m.id,
              stat: BuffStat.stunLock,
              value: 1,
              turns: turns,
              ownerId: owner.id),
        ];
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        events.add(
            BuffAppliedEvent(target.id, m.id, BuffStat.stunLock, 1, turns));
        _notes.add('${m.name}: ${target.name} queda aturdido 1 turno más');
      case ProcEffectKind.buffDuo:
        final rx = _rx;
        events.add(ProcEvent(owner.id, m.id));
        final who = [
          owner,
          if (rx != null && rx.by != owner && rx.by.alive) rx.by,
        ];
        for (final c in who) {
          _giveEffect(c, owner, m, fx.stat!, fx.value, fx.turns);
          events.add(
              BuffAppliedEvent(c.id, m.id, fx.stat!, fx.value, fx.turns));
        }
        _notes.add('${m.name}: ${who.map((c) => c.name).join(' y ')} '
            '+${_pct(fx.value)} ${fx.stat!.label} ${_turns(fx.turns)}');
      case ProcEffectKind.reactionBonus:
      case ProcEffectKind.healHarmBonus:
      case ProcEffectKind.summon:
        break; // modificadores: los aplican `_damageEnemy` y `_healHarm`

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
            (target.stacks(StatusKind.freeze) <= 0 &&
                !_meltedNow.contains(target.id))) {
          return;
        }
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        target.statuses[StatusKind.freeze] = 0;
        target.brittle = false;
        // El log solo dice "aturdido" si el estado entró.
        final stunned = _addStatus(
            target, const StatusApplication(StatusKind.stun, 1),
            source: owner);
        _notes.add('${m.name}: ${target.name} pierde la Congelación'
            '${stunned ? ' y queda aturdido' : ''}');
      case ProcEffectKind.delayTarget:
        if (target == null || !target.alive) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        target.nextTurn += _iv(target) *
            fx.value *
            (_fam(target)?.delayMult ?? 1);
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
        if (_addStatus(dest, StatusApplication(st, n), source: owner)) {
          _notes.add('${m.name}: $n ${st.label} pasan a ${dest.name}');
        }
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
        if (_addStatus(target, StatusApplication(st, n), source: owner)) {
          _notes.add('${m.name}: +$n ${st.label} a ${target.name}');
        }
      case ProcEffectKind.inflict:
        final st = fx.status;
        if (target == null || !target.alive || st == null) return;
        final n = math.max(1, fx.value.round());
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        // El golpe lleva este estado: primero la reacción (§ 9).
        _procHitReact(owner, target, m, StatusApplication(st, n));
        if (!target.alive) return;
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
          parts.add('${_skillProcDamage(p, e, d, m.id, sk)} a ${e.name}');
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
            primary: false, element: GameElement.fisico, physical: true);
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
    // Familia (bestiary.md § 1): los constructos se quiebran antes.
    amount *= _fam(e)?.breakMult ?? 1;
    // Hielo (elemental_reactions.md § 7): +10% de quiebre por stack.
    final ice = e.stacks(StatusKind.freeze);
    if (ice > 0) amount *= 1 + _frz.breakPerStack * ice;
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
    events.add(
        BreakEvent(e.id, BreakPhase.broken, max, max, cancelledUlt: cancelled));
    final ult = engine.catalog.enemyUlts[e.ultId];
    _notes.add('¡QUIEBRE! ${e.name}: pierde su turno, +50% de daño'
        '${cancelled && ult != null ? ' · ${ult.name} cancelada' : ''}');
    // Estratega (Señor de la Guerra): cualquier quiebre del grupo.
    for (final q in state.party) {
      if (q.alive) _fire(ProcTrigger.onBreak, q, target: e);
    }
    // Jefe del Abismo: el quiebre rompe su sello.
    _abyssBroken(e);
    // Sierpe: el quiebre rompe uno de sus cristales (Hechicera: disipa un
    // eco).
    final m = _mechanicOf(e);
    if (m != null &&
        m.addType != null &&
        (m.kind == BossMechanicKind.frost || m.kind == BossMechanicKind.echo)) {
      final crystal =
          state.enemies.where((c) => c.alive && c.enemyType == m.addType);
      if (crystal.isNotEmpty) {
        final c = crystal.first;
        c.hp = 0;
        events.add(
            BossMechanicEvent(e.id, BossMechanicPhase.shatter, targetId: c.id));
        _notes.add(m.kind == BossMechanicKind.echo
            ? 'el quiebre disipa un ${c.name}'
            : 'el quiebre rompe un ${c.name}');
        _knockedOut(c);
      }
    }
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
    // Rebobinar (Jefes del Abismo): lo recibido desde su acción anterior.
    if (lost > 0 && _abyssDef(e) != null) e.abyssTaken += lost;
    if (e.isPlayer || e.ultId == null || e.ultPending || lost <= 0) return;
    e.ult = math.min(100, e.ult + lost / e.maxHp * BattleEngine.enemyUltPerHp);
  }

  // ---------------- enemigos ----------------

  /// `enemyAct`. Con ULT (jefes y élites): con la carga llena avisa (pierde
  /// la acción) y en su siguiente turno la lanza.
  void enemyAct(Combatant e) {
    if (_aliveParty.isEmpty) return;
    final mech = _mechanicOf(e);
    if (mech != null) _mechanicTurn(e, mech);
    // La lava puede tumbar a alguien al empezar el turno.
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
        final fem = engine.catalog.enemies[e.enemyType]?.feminine ?? false;
        state.log = '¡${fem ? 'La' : 'El'} ${e.name} se prepara para '
            '${ult.name}! · Quiébralo, defiéndete o protégete';
        return;
      }
      e.ult = math.min(100, e.ult + BattleEngine.enemyUltPerTurn);
    }
    e.actions++;
    // Jefe del Abismo: su rotación de movimientos (abyss_bosses.md § 2).
    if (mech != null && mech.kind == BossMechanicKind.abyss) {
      _abyssAct(e, mech, alive);
      return;
    }
    if (mech != null &&
        mech.kind == BossMechanicKind.web &&
        e.actions % mech.every == 0 &&
        _castWeb(e, mech, alive)) {
      return;
    }
    if (mech != null && mech.kind == BossMechanicKind.mark) {
      // Marca del Vacío: el golpe al marcado, o marcar a alguien.
      final marked = alive.where((p) => p.voidMarked).firstOrNull;
      if (marked != null) {
        _markStrike(e, mech, marked, alive);
        return;
      }
      if (e.actions % mech.every == 0) {
        _castMark(e, mech, alive);
        return;
      }
    }
    _basicAttack(e, mech, alive);
    if (mech != null &&
        mech.kind == BossMechanicKind.lava &&
        e.lava <= 0 &&
        e.actions % mech.every == 0) {
      _lavaRise(e, mech.turns);
    }
  }

  /// Estado que aplica el golpe de [e] (en ciclo si su tipo lo tiene).
  StatusApplication? _inflictsOf(Combatant e) {
    // Aspecto de un Jefe del Abismo: sus golpes dejan el estado de ese
    // elemento.
    final asp = _abyssAspectStatus(e);
    if (asp != null) return asp;
    final cyc = engine.catalog.enemies[e.enemyType]?.inflictCycle ?? const [];
    if (cyc.isEmpty) return e.inflicts;
    return cyc[math.max(0, e.actions - 1) % cyc.length];
  }

  /// Efectos de los comunes v0.3 sobre el jugador que golpean: retraso
  /// (Guardián del Reloj, Fragmento) y marca (Vigilante). Texto del log.
  String _onHitExtras(Combatant e, Combatant p) {
    final d = engine.catalog.enemies[e.enemyType];
    if (d == null || !p.alive) return '';
    var log = '';
    if (d.delayHit > 0) {
      p.nextTurn += _iv(p) * d.delayHit;
      events.add(DelayedEvent(p.id));
      log += ' · retrasa ${_pct(d.delayHit)}';
    }
    if (d.markHit > 0) {
      const src = 'vigilancia';
      p.effects = [
        for (final fx in p.effects)
          if (!(fx.sourceId == src && fx.stat == BuffStat.damageTaken)) fx,
        TimedEffect(
            sourceId: src,
            stat: BuffStat.damageTaken,
            value: d.markHit,
            turns: 2,
            ownerId: e.id),
      ];
      events
          .add(BuffAppliedEvent(p.id, src, BuffStat.damageTaken, d.markHit, 2));
      log += ' · marcado +${_pct(d.markHit)} daño recibido (2 turnos)';
    }
    return log;
  }

  /// Ataque normal, Golpe Brutal o Colapso Temporal de [e].
  void _basicAttack(Combatant e, BossMechanicDef? mech, List<Combatant> alive) {
    // Invocaciones del grupo: el Gólem provoca (summoner.md § 3).
    if (_summonIntercept(e)) return;
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
    final inf = _inflictsOf(e);
    // Elemento del golpe (v0.7): reacciones sobre los jugadores.
    final el = enemyAttackElement(engine.catalog.enemies[e.enemyType], inf);
    // Devorador en fase 2: Colapso Temporal cada `every` acciones.
    final areaEvery =
        mech != null && mech.kind == BossMechanicKind.phases && e.phase >= 2
            ? mech.every
            : 3;
    final area = e.areaAttack && e.actions % areaEvery == 0;
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
        '${p.effectTotal(BuffStat.damageTaken) > 0 ? ' × ${fm(1 + p.effectTotal(BuffStat.damageTaken))} marca' : ''}'
        '${h.defensePercent > 0 ? ' − ${jsRound(h.defensePercent * 100)}% DEF' : ''}';
    String infText(Combatant p) => p.alive && inf != null
        ? _statusText(inf,
            bonus: inf.kind == StatusKind.regen ? 0 : p.statusWeakness)
        : '';
    final tauntText = taunter != null ? ' (provocado)' : '';
    // Guardián: el protector recibió un golpe dirigido a un aliado.
    void guarded(Combatant p, Combatant p0, int dmg) {
      if (p != p0 && p.alive) {
        _fire(ProcTrigger.onProtectHit, p, target: e, amount: dmg);
      }
    }

    if (area) {
      final parts = <String>[];
      for (final p0 in alive) {
        final p = victim(p0);
        if (!p.alive) {
          parts.add('${p0.name} 0');
          continue;
        }
        final h = _hurt(p, atk * 0.7, e.critChance, e.pierce,
            from: e, element: el, inflicted: inf);
        guarded(p, p0, h.damage);
        p.nextTurn += _iv(p) * 0.4;
        if (inf != null) _addStatus(p, inf);
        events.add(DelayedEvent(p.id));
        final who = p != p0 ? '${p.name} (por ${p0.name})' : p.name;
        parts.add('$who ${h.damage}${h.critical ? '!' : ''}');
      }
      state.log = '${e.name} · Colapso Temporal (todos, $atkText × 0.7, '
          'retrasa): ${parts.join(', ')}';
    } else if (e.boss && e.actions % 4 == 0) {
      final h = _hurt(pick, atk * 1.6, e.critChance, e.pierce,
          from: e, element: el, inflicted: inf);
      guarded(pick, pick0, h.damage);
      final got = inf != null && _addStatus(pick, inf);
      state.log = '${e.name} · Golpe Brutal → ${pick.name}: ${h.damage} = '
          '${detail(h, 1.6, pick)}${got ? infText(pick) : ''}$tauntText$protText${_onHitExtras(e, pick)}';
    } else {
      final h = _hurt(pick, atk.toDouble(), e.critChance, e.pierce,
          from: e, element: el, inflicted: inf);
      guarded(pick, pick0, h.damage);
      final got = inf != null && _addStatus(pick, inf);
      final explain = h.critical ||
          pick.defending ||
          h.pierce > 1 ||
          h.defensePercent > 0 ||
          pick.effectTotal(BuffStat.damageTaken) > 0 ||
          atkMod != 0;
      state.log = '${e.name} → ${pick.name}: ${h.damage}'
          '${explain ? ' = ${detail(h, 1, pick)}' : ''}'
          '${got ? infText(pick) : ''}$tauntText$protText${_onHitExtras(e, pick)}';
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
    final mech = _mechanicOf(e);
    // Coro de Ecos: más poder por cada eco vivo.
    var power = ult.power;
    if (ult.extra == EnemyUltExtra.echoChorus && mech?.addType != null) {
      power += ult.perAdd *
          state.enemies
              .where((c) => c.alive && c.enemyType == mech!.addType)
              .length;
    }
    final solo = alive.length == 1;
    final parts = <String>[];
    void strike(Combatant p0) {
      final p = victim(p0);
      if (!p.alive) {
        parts.add('${p0.name} 0');
        return;
      }
      // Colapso del Vacío: el marcado sin proteger recibe × value.
      var mult = 1.0;
      if (ult.extra == EnemyUltExtra.voidMark &&
          mech != null &&
          p0.voidMarked &&
          p == p0 &&
          !(solo && p0.defending)) {
        mult = solo ? mech.soloValue : mech.value;
        events.add(BossMechanicEvent(e.id, BossMechanicPhase.markHit,
            targetId: p0.id, value: mult));
      }
      final h = _hurt(p, atk * power * mult, crit, e.pierce,
          from: e, element: enemyUltElement(ult), inflicted: ult.status);
      if (p != p0 && p.alive) {
        _fire(ProcTrigger.onProtectHit, p, target: e, amount: h.damage);
      }
      final st = ult.status;
      if (st != null) _addStatus(p, st);
      final who = p != p0 ? '${p.name} (por ${p0.name})' : p.name;
      parts.add('$who ${h.damage}${h.critical ? '!' : ''}'
          '${mult != 1 ? ' (MARCA ×${fm(mult)})' : ''}');
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
            if (fx.value <= 0 ||
                fx.stat == BuffStat.stunLock ||
                fx.stat == BuffStat.damageTaken)
              fx,
        ];
        if (p.bonusDefense > 0) {
          p.bonusDefense = 0;
          engine._refreshStats(p);
        }
      }
    }
    final extra = _ultExtra(e, ult);
    final st = ult.status;
    state.log = '${e.name} · ULT ${ult.name} '
        '(${ult.allTargets ? 'todos, ' : ''}$atkText × ${fm(power)}'
        '${ult.guaranteedCrit ? ' × ${fm(BattleEngine.enemyCritMultiplier)} CRÍTICO' : ''}): '
        '${parts.join(', ')}'
        '${st != null ? _statusText(st) : ''}'
        '${ult.delayAll > 0 ? ' · retrasa a todos' : ''}'
        '${ult.wipeBuffs ? ' · borra los buffs del grupo' : ''}'
        '$extra';
  }

  // ---------------- mecánicas de jefe (docs/specs/bosses.md § "v0.2") ----

  /// Invocación que no actúa (cristales).
  bool _passive(Combatant c) =>
      !c.isPlayer && (engine.catalog.enemies[c.enemyType]?.passive ?? false);

  BossMechanicDef? _mechanicOf(Combatant e) =>
      e.isPlayer ? null : bossMechanicOf(engine.catalog.enemies[e.enemyType]);

  /// Quedan invocaciones vivas del tipo [type].
  bool _addsAlive(String type) =>
      state.enemies.any((c) => c.alive && c.enemyType == type);

  /// Fracción del golpe que bloquea la postura de [e] (0 si no aplica):
  /// escudo → físico (ataque, habilidad o ULT física), espada → mágico.
  /// Quebrado no bloquea; el dúo y los secundarios tampoco.
  double _stanceResist(Combatant e) {
    if (e.stance == 0 || e.broken) return 0;
    final act = _act;
    if (act == null || act.dual) return 0;
    final sk = act.skill;
    final physical = sk == null || sk.kind == SkillKind.physical;
    if ((e.stance == 1) != physical) return 0;
    final m = _mechanicOf(e);
    if (m == null) return 0;
    return _aliveParty.length == 1 ? m.soloValue : m.value;
  }

  /// Al empezar el turno del jefe: Campo Helado o cambio de postura.
  void _mechanicTurn(Combatant e, BossMechanicDef m) {
    switch (m.kind) {
      case BossMechanicKind.frost:
        if (m.addType != null && _addsAlive(m.addType!)) _frost(e, m);
      case BossMechanicKind.stance:
        e.stanceTurns--;
        if (e.stanceTurns <= 0) _shiftStance(e, m);
      case BossMechanicKind.echo || BossMechanicKind.summon:
        _refillTurn(e, m);
      case BossMechanicKind.lava:
        _lavaTick(e, m);
      case BossMechanicKind.abyss:
        _abyssTurnStart(e);
      case BossMechanicKind.web ||
            BossMechanicKind.mark ||
            BossMechanicKind.phases:
        break;
    }
  }

  // ---------------- mecánicas de jefe v0.3 (docs/specs/bosses.md § "v0.3")

  /// Fracción del daño que recibe cada tipo de eco (`ecoHechicera` 0.5).
  static final Map<String, double> _echoAdds = {
    for (final m in kBossMechanics.values)
      if ((m.kind == BossMechanicKind.echo ||
              (m.kind == BossMechanicKind.abyss && m.value > 0)) &&
          m.addType != null)
        m.addType!: m.value,
  };

  /// Fracción del daño que recibe [e] (1 salvo los ecos).
  double _echoFactor(Combatant e) =>
      e.isPlayer ? 1 : (_echoAdds[e.enemyType] ?? 1);

  /// Séquito vivo: el jefe es inmune a los estados.
  bool _immune(Combatant e) {
    final m = _mechanicOf(e);
    if (m != null && m.kind == BossMechanicKind.abyss) {
      return _abyssStatusImmune(e);
    }
    return m != null &&
        m.kind == BossMechanicKind.summon &&
        m.addType != null &&
        _addsAlive(m.addType!);
  }

  /// Invocaciones que tiene que tener [m] (con grupo / solo).
  int _addsMax(BossMechanicDef m) =>
      state.party.length == 1 ? m.soloAdds : m.adds;

  /// Al empezar su turno: si le faltan invocaciones, cuenta; al llegar a
  /// `every` turnos, las vuelve a crear.
  void _refillTurn(Combatant e, BossMechanicDef m) {
    final type = m.addType;
    if (type == null) return;
    final n = state.enemies.where((c) => c.alive && c.enemyType == type).length;
    if (n >= _addsMax(m)) {
      e.mechTurns = 0;
      return;
    }
    e.mechTurns++;
    if (e.mechTurns < m.every) return;
    e.mechTurns = 0;
    final k = _summonAdds(e, m);
    if (k > 0) {
      _notes.add(m.kind == BossMechanicKind.echo
          ? '${m.name}: ${e.name} se desdobla en $k eco${k == 1 ? '' : 's'}'
          : '${m.name}: ${e.name} invoca $k siervo${k == 1 ? '' : 's'}'
              ' (inmune a estados mientras vivan)');
    }
  }

  /// Completa las invocaciones de [boss]: revive las caídas y, si faltan,
  /// agrega nuevas escaladas como el jefe. Devuelve cuántas volvieron.
  int _summonAdds(Combatant boss, BossMechanicDef m) {
    final add = engine.catalog.enemies[m.addType];
    if (add == null) return 0;
    final phase = m.kind == BossMechanicKind.echo
        ? BossMechanicPhase.echoSummon
        : BossMechanicPhase.summon;
    final max = _addsMax(m);
    var alive =
        state.enemies.where((c) => c.alive && c.enemyType == add.id).length;
    var n = 0;
    void entered(Combatant c) {
      c.nextTurn = state.clock + _iv(c) * 0.5;
      alive++;
      n++;
      events.add(BossMechanicEvent(boss.id, phase, targetId: c.id));
    }

    for (final c in state.enemies) {
      if (alive >= max) break;
      if (c.alive || c.enemyType != add.id) continue;
      c
        ..hp = c.maxHp
        ..statuses = {}
        ..holyTurns = 0
        ..brittle = false
        ..freezeResist = 0
        ..effects = []
        ..actions = 0;
      entered(c);
    }
    final bd = engine.catalog.enemies[boss.enemyType];
    while (alive < max && bd != null) {
      final c = engine.addCombatant(add, 'e${state.enemies.length}',
          boss.maxHp / bd.hp, boss.attack / math.max(1, bd.attack));
      state.enemies.add(c);
      entered(c);
    }
    return n;
  }

  /// Al empezar el turno de la Bestia con lava: quema a los que se
  /// defienden; baja 1 turno.
  void _lavaTick(Combatant e, BossMechanicDef m) {
    if (e.lava <= 0) return;
    final party = _aliveParty.toList();
    final solo = party.length == 1;
    final power = solo ? m.soloPower : m.power;
    final stacks = (solo ? m.soloValue : m.value).round();
    final atkMod = e.effectTotal(BuffStat.attack);
    final atk =
        atkMod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + atkMod)));
    final parts = <String>[];
    for (final p in party) {
      if (!p.defending) continue;
      events.add(BossMechanicEvent(e.id, BossMechanicPhase.lavaBurn,
          targetId: p.id, value: stacks.toDouble()));
      // Defender no lo reduce (es el piso); la DEF sí.
      final dmg = math.max(1, jsRound(atk * power * (1 - p.defensePercent)));
      final taken = dmg - _absorb(p, dmg);
      if (taken > 0) {
        p.ult = math.min(
            100, p.ult + taken / p.maxHp * 110 * (1 + p.ultChargeBonus));
      }
      p.hp = math.max(0, p.hp - taken);
      events.add(DamageEvent(p.id, taken));
      if (!p.alive) {
        events.add(KnockedOutEvent(p.id));
        p.voidMarked = false;
        _allyDown(p);
      } else {
        _addStatus(p, StatusApplication(StatusKind.burn, stacks));
      }
      parts.add('${p.name} $taken');
    }
    if (parts.isNotEmpty) {
      _notes.add('${m.name}: se queman por defenderse (ATQ $atk × '
          '${fm(power)} + $stacks Quemadura): ${parts.join(', ')}');
    }
    e.lava--;
    if (e.lava <= 0) {
      e.lava = 0;
      events.add(BossMechanicEvent(e.id, BossMechanicPhase.lavaFade));
      _notes.add('la lava se enfría');
    }
  }

  /// La lava sube [turns] turnos de [e].
  void _lavaRise(Combatant e, int turns) {
    if (turns <= 0) return;
    e.lava = math.max(e.lava, turns);
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.lavaRise,
        value: e.lava.toDouble()));
    _notes.add('¡la lava sube ${e.lava} turnos! No te defiendas sobre ella');
  }

  /// El Centinela marca a un jugador (el provocador si hay).
  void _castMark(Combatant e, BossMechanicDef m, List<Combatant> alive) {
    final taunter = alive.where((p) => p.taunt > 0).firstOrNull;
    final p = taunter ?? alive[(_rand() * alive.length).floor()];
    if (taunter != null) taunter.taunt--;
    p.voidMarked = true;
    events.add(
        BossMechanicEvent(e.id, BossMechanicPhase.markCast, targetId: p.id));
    final solo = alive.length == 1;
    state.log = '${e.name} · ${m.name} → ${p.name}: su próximo golpe pega '
        '×${fm(solo ? m.soloValue : m.value)} · '
        '${solo ? 'defendete para contrarrestarla' : 'que un aliado lo proteja'}';
  }

  /// El golpe al marcado: × value, salvo que otro lo proteja (o, en solo,
  /// que se esté defendiendo).
  void _markStrike(
      Combatant e, BossMechanicDef m, Combatant marked, List<Combatant> alive) {
    final protector =
        alive.where((q) => q.protecting && q != marked).firstOrNull;
    final solo = alive.length == 1;
    final guarded = protector != null || (solo && marked.defending);
    final victim = protector ?? marked;
    final mult = guarded ? 1.0 : (solo ? m.soloValue : m.value);
    marked.voidMarked = false;
    events.add(ActionEvent(e.id,
        guarded ? BattleActionKind.enemyAttack : BattleActionKind.enemyHeavy,
        targetId: victim.id));
    events.add(guarded
        ? BossMechanicEvent(victim.id, BossMechanicPhase.markGuarded,
            targetId: marked.id)
        : BossMechanicEvent(e.id, BossMechanicPhase.markHit,
            targetId: marked.id, value: mult));
    final atkMod = e.effectTotal(BuffStat.attack);
    final atk =
        atkMod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + atkMod)));
    final inf = _inflictsOf(e);
    final h = _hurt(victim, atk * mult, e.critChance, e.pierce,
        from: e,
        element: enemyAttackElement(engine.catalog.enemies[e.enemyType], inf),
        inflicted: inf);
    if (protector != null && victim.alive) {
      _fire(ProcTrigger.onProtectHit, victim, target: e, amount: h.damage);
    }
    final got = inf != null && _addStatus(victim, inf);
    state.log = guarded
        ? '${e.name} · ${m.name} → ${marked.name}: '
            '${protector != null ? '${protector.name} lo protege' : 'se defiende'}'
            ' y la marca se disipa: ${h.damage}'
            '${got ? _statusText(inf) : ''}'
        : '${e.name} · ${m.name} → ${marked.name}: ${h.damage} = ATQ $atk × '
            '${fm(mult)} (MARCA)'
            '${h.critical ? ' × ${fm(BattleEngine.enemyCritMultiplier)} CRÍTICO' : ''}'
            '${marked.defending ? ' × ½ defender' : ''}'
            '${got ? _statusText(inf) : ''}';
  }

  /// Fases (Devorador): si [e] llegó al umbral, la vida queda en él y
  /// pasa a la fase 2. `true` si hay que llamar a [_transform] (después
  /// del `DamageEvent`).
  bool _gatePhase(Combatant e) {
    if (e.isPlayer) return false;
    // Jefes del Abismo: 2–3 fases (abyss_bosses.md § 2).
    if (_abyssDef(e) != null) return _abyssGate(e);
    if (e.phase >= 2) return false;
    final m = _mechanicOf(e);
    if (m == null || m.kind != BossMechanicKind.phases) return false;
    final gate = (e.maxHp * m.value).ceil();
    if (e.hp > gate) return false;
    e
      ..hp = gate
      ..phase = 2;
    return true;
  }

  /// Transformación: fuera estados y barra, ATQ × power, acciones a 0.
  void _transform(Combatant e) {
    if (_abyssDef(e) != null) {
      _abyssTransform(e);
      return;
    }
    final m = _mechanicOf(e);
    if (m == null) return;
    e
      ..statuses = {}
      ..holyTurns = 0
      ..brittle = false
      ..attack = jsRound(e.attack * (m.power > 0 ? m.power : 1))
      ..actions = 0;
    if (!e.broken) e.breakGauge = 0;
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.phaseShift, value: 2));
    _notes.add('¡${e.name} se transforma! FASE 2: pierde sus estados, ATQ '
        '+${_pct(m.power - 1)} y Colapso Temporal cada ${m.every} acciones');
  }

  void _shiftStance(Combatant e, BossMechanicDef m) {
    e
      ..stance = e.stance == 1 ? 2 : 1
      ..stanceTurns = m.every;
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.stanceShift,
        value: e.stance.toDouble()));
    _notes.add('${e.name} cambia a postura de ${stanceName(e.stance)} '
        '(−${_pct(m.value)} daño ${e.stance == 1 ? 'físico' : 'mágico'})');
  }

  /// −[BossMechanicDef.value] de velocidad a todo el grupo (tope `cap`).
  void _frost(Combatant e, BossMechanicDef m) {
    var total = 0.0;
    for (final p in _aliveParty) {
      final old = p.effectFrom(m.id, BuffStat.speed);
      final v = math.max(-m.cap, (old?.value ?? 0) - m.value);
      p.effects = [
        for (final fx in p.effects)
          if (!(fx.sourceId == m.id && fx.stat == BuffStat.speed)) fx,
        TimedEffect(
            sourceId: m.id,
            stat: BuffStat.speed,
            value: _r2(v),
            turns: 99,
            ownerId: e.id),
      ];
      total = math.max(total, _r2(-v));
    }
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.frost, value: total));
    _notes.add('${m.name}: el grupo pierde ${_pct(m.value)} de velocidad '
        '(−${_pct(total)}) · rompé los cristales');
  }

  static double _r2(double v) => (v * 100).round() / 100;

  /// Se fue la escarcha: el grupo recupera la velocidad.
  void _thaw(Combatant boss, BossMechanicDef m) {
    for (final p in state.party) {
      p.effects = [
        for (final fx in p.effects)
          if (fx.sourceId != m.id) fx,
      ];
    }
    events.add(BossMechanicEvent(boss.id, BossMechanicPhase.thaw));
    _notes.add('¡Cristales rotos! El campo se descongela');
  }

  /// Murió [c]: si es un jefe, sus invocaciones caen con él; si era la
  /// última invocación, se termina su efecto.
  void _mechanicDeath(Combatant c) {
    final m = _mechanicOf(c);
    if (m != null && m.kind == BossMechanicKind.mark) {
      for (final p in state.party) {
        p.voidMarked = false;
      }
    }
    if (m != null && c.lava > 0) {
      c.lava = 0;
      events.add(BossMechanicEvent(c.id, BossMechanicPhase.lavaFade));
    }
    if (m != null && m.addType != null) {
      for (final a in state.enemies) {
        if (a.alive && a.enemyType == m.addType) {
          a.hp = 0;
          events.add(KnockedOutEvent(a.id));
        }
      }
      if (state.party.any((p) => p.effectFrom(m.id, BuffStat.speed) != null)) {
        _thaw(c, m);
      }
      return;
    }
    if (!_passive(c) || _addsAlive(c.enemyType!)) return;
    for (final b in state.enemies) {
      final bm = _mechanicOf(b);
      if (b.alive && bm != null && bm.addType == c.enemyType) {
        _thaw(b, bm);
        return;
      }
    }
  }

  /// Golpe que teje la telaraña: ATQ × `value` a un jugador no atrapado
  /// (el provocador si hay). `false` si todos están atrapados.
  bool _castWeb(Combatant e, BossMechanicDef m, List<Combatant> alive) {
    final free = alive.where((p) => !p.webbed).toList();
    if (free.isEmpty) return false;
    final taunter = free.where((p) => p.taunt > 0).firstOrNull;
    final p = taunter ?? free[(_rand() * free.length).floor()];
    if (taunter != null) taunter.taunt--;
    events.add(ActionEvent(e.id, BattleActionKind.enemyAttack, targetId: p.id));
    final atkMod = e.effectTotal(BuffStat.attack);
    final atk =
        atkMod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + atkMod)));
    final h = _hurt(p, atk * m.value, e.critChance, e.pierce, from: e);
    var log = '${e.name} · ${m.name} → ${p.name}: ${h.damage}';
    if (p.alive) {
      p.webbed = true;
      events.add(
          BossMechanicEvent(e.id, BossMechanicPhase.webCast, targetId: p.id));
      log += _aliveParty.length > 1
          ? ' · ¡atrapado! Pierde su próximo turno si nadie lo libera '
              '(Atacar sobre él)'
          : ' · ¡atrapado! Forcejeará medio turno';
    }
    state.log = log;
    return true;
  }

  /// [p] libera a [ally] de la telaraña: cuesta medio turno.
  bool _freeAlly(Combatant p, Combatant ally) {
    if (ally == p || !ally.alive || !ally.webbed) return false;
    ally.webbed = false;
    _act = null;
    _attacker = null;
    events.add(ActionEvent(p.id, BattleActionKind.attack, targetId: ally.id));
    events.add(
        BossMechanicEvent(p.id, BossMechanicPhase.webFreed, targetId: ally.id));
    state.log = '${p.name} corta la telaraña: ¡${ally.name} queda libre! '
        '(medio turno)';
    tickEffects(p);
    p.nextTurn = state.clock + _iv(p) * 0.5;
    endTurn();
    return true;
  }

  /// Efecto extra de la ULT de un jefe; devuelve el texto del log.
  String _ultExtra(Combatant e, EnemyUltDef ult) {
    final m = _mechanicOf(e);
    switch (ult.extra) {
      case EnemyUltExtra.none:
        return '';
      case EnemyUltExtra.web:
        final free = _aliveParty.where((p) => !p.webbed).toList();
        if (_aliveParty.length < 2 || free.isEmpty) return '';
        final p = _lowest(free, (c) => -c.hp.toDouble())!;
        p.webbed = true;
        events.add(
            BossMechanicEvent(e.id, BossMechanicPhase.webCast, targetId: p.id));
        return ' · ${p.name} queda atrapado en la telaraña';
      case EnemyUltExtra.reformCrystals:
        if (m == null || m.addType == null) return '';
        var n = 0;
        for (final c in state.enemies) {
          if (c.alive || c.enemyType != m.addType) continue;
          c.hp = c.maxHp;
          n++;
          events.add(BossMechanicEvent(e.id, BossMechanicPhase.reform,
              targetId: c.id));
        }
        return n == 0 ? '' : ' · se forman $n cristal${n == 1 ? '' : 'es'}';
      case EnemyUltExtra.stanceShift:
        if (m == null || e.stance == 0) return '';
        _shiftStance(e, m);
        return '';
      case EnemyUltExtra.echoChorus:
        if (m == null) return '';
        e.mechTurns = 0;
        final n = _summonAdds(e, m);
        return n == 0 ? '' : ' · vuelven $n eco${n == 1 ? '' : 's'}';
      case EnemyUltExtra.summonAll:
        if (m == null) return '';
        e.mechTurns = 0;
        final n = _summonAdds(e, m);
        return n == 0 ? '' : ' · invoca $n siervo${n == 1 ? '' : 's'}';
      case EnemyUltExtra.lavaFlood:
        e.lava = math.max(e.lava, ult.turns);
        events.add(BossMechanicEvent(e.id, BossMechanicPhase.lavaRise,
            value: e.lava.toDouble()));
        return ' · ¡la lava sube ${e.lava} turnos!';
      case EnemyUltExtra.voidMark:
        for (final p in state.party) {
          p.voidMarked = false;
        }
        final p = _lowest(_aliveParty, (c) => -c.hp.toDouble());
        if (p == null || m == null) return '';
        p.voidMarked = true;
        events.add(BossMechanicEvent(e.id, BossMechanicPhase.markCast,
            targetId: p.id));
        return ' · marca a ${p.name}';
    }
  }

  // ---------------- jugadores ----------------

  /// `battleCmd`. Devuelve false si el comando no es válido.
  bool command(Combatant p, BattleCommand cmd) {
    final foes = state.enemies.where((e) => e.alive).toList();
    if (foes.isEmpty) return false;
    if (cmd is AttackCommand) {
      // Atacar a un aliado atrapado = liberarlo de la telaraña.
      final ally = state.party.where((q) => q.id == cmd.targetId).firstOrNull;
      if (ally != null) return _freeAlly(p, ally);
    }
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
        act.breakFactor = (sk.kind == SkillKind.physical
                ? BattleEngine.breakPhysicalSkill
                : BattleEngine.breakMagicalSkill) *
            (1 + sk.breakBonus);
        p.mp -= sk.mp;
        // Sangría: cuesta vida (nunca deja en menos de 1).
        if (sk.hpCost > 0) {
          final cost = math.min(p.hp - 1, jsRound(p.maxHp * sk.hpCost));
          if (cost > 0) {
            p.hp -= cost;
            events.add(DamageEvent(p.id, cost, sourceId: sk.id));
            _notes.add('${sk.name}: cuesta $cost HP');
          }
        }
        events.add(ActionEvent(p.id, BattleActionKind.skill,
            skillId: sk.id,
            targetId: sk.dealsDamage && !sk.allTargets ? target.id : null,
            allTargets: sk.allTargets));
        act.skill = sk;
        // Reflejo de los Jefes del Abismo: copian la última habilidad.
        _abyssCopied(sk.id);
        final gain = _useSkill(p, sk, foes, target, ultimate: false);
        // Prisa sin aliados: ya terminó el turno.
        if (gain == null) return true;
        ultGain = gain;
        _skillExtras(p, sk);
        _fire(ProcTrigger.onSkill, p);
      case UltimateCommand():
        final sk = ultimateOf(p, engine.catalog);
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
        _skillExtras(p, sk);
        _fire(ProcTrigger.onSkill, p);
        _fire(ProcTrigger.onUltimate, p);
      case DualCommand(:final partnerId, :final dualId):
        act
          ..breakFactor = BattleEngine.breakDual
          ..dual = true;
        if (!_dual(p, partnerId, dualId, foes)) return false;
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
      case PassCommand():
        // Sin acción: no carga ULT, no defiende, no dispara procs ni
        // emite ActionEvent (los eventos siguen siendo los de v0.8.2).
        state.log = '${p.name} pasa el turno (el próximo llega antes)';
        _act = null;
        _attacker = null;
        tickEffects(p);
        p.nextTurn = state.clock + _iv(p) * BattleEngine.passTurnFactor;
        endTurn();
        return true;
    }

    _resolveAction(p, act);
    // Robo de vida del arma (afijo `del Vampiro`): sobre todo el daño de
    // la acción.
    // Más el de la ascensión (Sangre por Sangre) y el de la habilidad.
    final steal = p.lifeSteal +
        _conditionBonus(p, BuffStat.lifeSteal) +
        (act.skill?.lifeSteal ?? 0);
    if (steal > 0 && _dealt > 0 && p.alive && p.hp < p.maxHp) {
      final h = math.max(1, jsRound(_dealt * steal));
      _heal(p, h);
      _notes.add('robo de vida +$h HP');
    }
    // Drenaje (variantes): el daño cura al aliado más herido.
    final drain = act.skill?.drainHeal ?? 0;
    if (drain > 0 && _dealt > 0) {
      final q = _lowest(_aliveParty, (c) => c.hp / c.maxHp);
      if (q != null && q.hp < q.maxHp) {
        final h = math.max(1, jsRound(_dealt * drain));
        _heal(q, h);
        _fire(ProcTrigger.onHeal, p, target: q, amount: h);
        _notes.add('${act.skill!.name}: ${q.name} +$h HP '
            '(${_pct(drain)} del daño)');
      }
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
    if (stunChance > 0 &&
        target.alive &&
        _rand() < stunChance &&
        // Solo si entró (un jefe con séquito es inmune).
        _addStatus(target, const StatusApplication(StatusKind.stun, 1),
            source: p, primary: true)) {
      log += ' · ¡aturde! (${jsRound(stunChance * 100)}%)';
    }
    if (p.branch == 'creyente' && _rand() < 0.25) {
      for (final q in _aliveParty) {
        _heal(q, math.max(1, jsRound(q.maxHp * 0.02)));
      }
      log += ' · Fe: cura 2% a todos';
    }
    if (p.branch == 'inherente' &&
        target.alive &&
        _rand() < 0.25 &&
        _addStatus(target, const StatusApplication(StatusKind.holy, 1),
            source: p, primary: true)) {
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
      case SkillKind.support:
        // Invocador (summoner.md): invocar, sacrificar, comandar, Portal.
        if (_summonSkill(p, tk, foes)) return ultimate ? 0 : 6;
        // Kit de ascensión: los efectos los pone `_skillExtras`; las
        // trampas sin daño, acá.
        if (tk.trap > 0) {
          for (final e in tk.allTargets ? foes : [target]) {
            _plantTrap(p, e, tk.id, tk.trap, 1);
          }
          state.log = '${p.name} · ${tk.name}: trampa en '
              '${tk.allTargets ? 'todos los enemigos' : target.name}';
        } else if (tk.debuffs.isNotEmpty || tk.ultDrain > 0) {
          // Variantes sin daño: Rugido, Señalar Presa.
          for (final e in tk.allTargets ? foes : [target]) {
            _variantOnHit(p, e, tk);
          }
          state.log = '${p.name} · ${tk.name} → '
              '${tk.allTargets ? 'todos los enemigos' : target.name}'
              '${_debuffText(tk)}';
        } else {
          state.log = '${p.name} · ${tk.name}';
        }
        return 6;

      case SkillKind.regen:
        final a = jsRound((p.magic * tk.power + 4) * (1 + p.healBonus));
        final regenTo = tk.lowestAlly
            ? [if (_lowest(allies, (c) => c.hp / c.maxHp) case final q?) q]
            : allies;
        for (final q in regenTo) {
          if (_skillHeal(p, q, a) <= 0) continue;
          _addStatus(q, const StatusApplication(StatusKind.regen, 3));
          _fire(ProcTrigger.onHeal, p, target: q, amount: a);
        }
        var log = '${p.name} · ${tk.name}: +$a '
            '${tk.lowestAlly && regenTo.isNotEmpty ? 'a ${regenTo.first.name}' : 'a cada aliado'} '
            '(MAG ${p.magic} × ${fm(tk.power)} + 4) y Regeneración 5% vida y maná × 3 turnos';
        log += _healHarm(p, a);
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
        // Resurrección: primero el aliado caído.
        if (tk.revive > 0) {
          final down = state.party.where((q) => !q.alive).firstOrNull;
          if (down != null) {
            _revive(p, down, tk);
            return 8;
          }
        }
        final healed = tk.lowestAlly
            ? [if (_lowest(allies, (c) => c.hp / c.maxHp) case final q?) q]
            : allies;
        final m = _skillMech(tk);
        for (final q in healed) {
          final before = q.hp;
          if (_skillHeal(p, q, a) <= 0) continue;
          // Desborde: lo que sobra de la cura se vuelve escudo.
          final over = a - (q.hp - before);
          if (tk.overheal > 0 && over > 0) {
            _shield(q, p, m, math.max(1, jsRound(over * tk.overheal)),
                tk.shieldTurns);
          }
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
        state.log = '${p.name} · ${tk.name}: +$a '
            '${tk.lowestAlly && healed.isNotEmpty ? 'a ${healed.first.name}' : 'a cada aliado'} = '
            'MAG ${p.magic} × ${fm(tk.power)} + 6$cleanseText'
            '${_healHarm(p, a)}';
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
        if (tk.charge > 0) {
          // Disparo cargado: apunta ahora, cae al empezar tu próximo turno.
          // También las ULT cargadas (Tensión Máxima): antes caían al
          // golpe normal con `power` 0 y hacían 1 de daño.
          final dmg = math.max(1, jsRound(_atk(p) * tk.charge));
          p.effects = [
            for (final e in p.effects)
              if (e.stat != BuffStat.charge) e,
            TimedEffect(
                sourceId: tk.id,
                stat: BuffStat.charge,
                value: dmg.toDouble(),
                turns: 1,
                ownerId: target.id,
                fresh: true),
          ];
          events.add(
              BuffAppliedEvent(p.id, tk.id, BuffStat.charge, dmg.toDouble(), 1));
          state.log = '${p.name} · ${tk.name} → ${target.name}: carga $dmg '
              '(${_atkText(p)} × ${fm(tk.charge)}) · cae al empezar su '
              'próximo turno';
          return 6;
        }
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
        final delayMult = 1 + _conditionBonus(p, BuffStat.delayPower);
        var detonated = 0;
        // Estado principal: a cuántos se intentó aplicar y en cuántos entró
        // (el log informa el resultado, no la probabilidad).
        var tried = 0, landed = 0;
        for (final e in tk.allTargets ? foes : [target]) {
          // Detonar: +daño por cada stack elemental, que se consumen.
          var b = base;
          if (tk.detonate > 0) {
            final n = kElementalStatuses.fold(0, (s, k) => s + e.stacks(k));
            b = base * (1 + tk.detonate * n);
            detonated += n;
            // El estado que el golpe detona (Supernova sobre Veneno →
            // Explosión tóxica) queda para la reacción, que lo consume
            // (elemental_reactions.md § 9).
            final keep = _skillReaction(e, tk)?.primer;
            for (final k in kElementalStatuses) {
              if (k != keep) e.statuses[k] = 0;
            }
            if (keep != StatusKind.freeze) e.brittle = false;
          }
          final hit = _damageEnemy(e, b, p.critChance + tk.critBonus,
              single: !tk.allTargets);
          hits.add(hit);
          if (!tk.allTargets) {
            act
              ..mainTarget = e
              ..mainHit = hit;
          }
          // Ráfaga (variantes): golpes seguidos al mismo objetivo.
          if (tk.hits > 1) {
            final more = <int>[hit.damage];
            for (var h = 1; h < tk.hits && e.alive; h++) {
              more.add(_damageEnemy(e, b, p.critChance + tk.critBonus,
                      single: !tk.allTargets, hitIndex: h)
                  .damage);
            }
            _notes.add('${more.length} golpes: ${more.join(' + ')} = '
                '${more.fold(0, (s, d) => s + d)}');
          }
          _variantOnHit(p, e, tk);
          if (st != null && !burnBlocked) {
            if (e.alive) tried++;
            if (_addStatus(e, st, bonus: bonus, source: p, primary: true)) {
              landed++;
            }
          }
          for (final x in tk.extraStatuses) {
            if (x.kind == StatusKind.burn && p.keystones.contains('almaHielo')) {
              continue;
            }
            _addStatus(e, x,
                bonus: p.statusBonus[x.kind] ?? 0, source: p, primary: true);
          }
          if (tk.delay > 0 && e.alive) {
            e.nextTurn += _iv(e) *
                tk.delay *
                delayMult *
                (_fam(e)?.delayMult ?? 1);
            events.add(DelayedEvent(e.id));
            _fire(ProcTrigger.onDelayApplied, p, target: e);
          }
          if (tk.execute > 0) _execute(p, e, tk.execute, tk.id, tk.name);
          if (tk.trap > 0 && e.alive) _plantTrap(p, e, tk.id, tk.trap, 1);
        }
        if (detonated > 0) {
          _notes.add('${tk.name}: detona $detonated stack'
              '${detonated == 1 ? '' : 's'} (+${_pct(tk.detonate * detonated)})');
        }
        if (!tk.allTargets) {
          _pierceAndBounce(p, tk, target, base, st, burnBlocked ? 0 : bonus,
              blocked: burnBlocked);
        }
        final head = '${p.name} · ${ultimate ? 'ULT ' : ''}${tk.name}'
            '${tk.allTargets ? ' (todos)' : ' → ${target.name}'}';
        var log = _damageLog(head, magical ? 'MAG $sourceValue' : _atkText(p),
            sourceValue, tk.power, hits,
            all: tk.allTargets, tormenta: tormenta);
        if (tk.delay > 0) log += ' · retrasa';
        log += _debuffText(tk);
        if (burnBlocked) {
          log += ' · sin Quemadura (Alma de Hielo)';
        } else if (st != null) {
          log += _statusOutcome(st, bonus, tried, landed);
        }
        state.log = log;
        return 0;
    }
  }

  bool _dual(
      Combatant p, String partnerId, String? dualId, List<Combatant> foes) {
    final q = state.party.where((c) => c.id == partnerId).firstOrNull;
    if (q == null ||
        q == p ||
        !q.alive ||
        p.mp < BattleEngine.dualMpCost ||
        q.mp < BattleEngine.dualMpCost) {
      return false;
    }
    // Sin id: el dúo de clase del par (v0.8.2). Con id: ese dúo, si el
    // par lo puede hacer (clase o tipos de arma, dual_rules.dart).
    final id = dualId ?? dualKey(p.classId ?? '', q.classId ?? '');
    final du = engine.catalog.duals[id];
    if (du == null || !dualFits(id, du, p, q)) return false;

    events.add(ActionEvent(p.id, BattleActionKind.dual,
        skillId: id, partnerId: q.id, allTargets: true));
    q.defending = false;
    p.mp -= BattleEngine.dualMpCost;
    q.mp -= BattleEngine.dualMpCost;
    q.nextTurn = math.max(q.nextTurn, state.clock) + _iv(q);

    final pv = math.max(_atk(p), p.magic);
    final qv = math.max(_atk(q), q.magic);
    final bonus = p.statusBonus[du.status.kind] ?? 0;
    final hits = <_Hit>[];
    var tried = 0, landed = 0;
    for (final e in foes) {
      hits.add(_damageEnemy(
          e, (pv + qv) * du.power, (p.critChance + q.critChance) / 2,
          element: elementOfDual(du), hitStatus: du.status));
      if (e.alive) tried++;
      if (_addStatus(e, du.status, bonus: bonus, source: p, primary: true)) {
        landed++;
      }
    }
    state.log = _damageLog('${p.name} + ${q.name} · ${du.name} (todos)',
            '($pv + $qv)', pv + qv, du.power, hits,
            all: true) +
        _statusOutcome(du.status, bonus, tried, landed);
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

/// Nombre de la postura del Caballero Hueco (`Combatant.stance`).
String stanceName(int stance) => stance == 1
    ? 'ESCUDO'
    : stance == 2
        ? 'ESPADA'
        : '—';
