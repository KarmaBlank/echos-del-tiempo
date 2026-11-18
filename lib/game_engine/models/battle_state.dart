import 'passive_mechanic.dart';
import 'player_state.dart';
import 'status.dart';

/// Un jugador tal como entra a la batalla (lo que el prototipo leía de
/// `p` en `startBattle`). Vida/maná son los que traía del mapa: `null`
/// significa "lleno".
class BattlePartyMember {
  final String id;
  final String name;
  final PlayerBuild build;
  final int? hp;
  final double? mp;
  final double ult;
  final int potions;
  final int ethers;

  /// Habilidad fusionada al arma equipada (`p.fuse[p.eq]`), si hay.
  final String? fusedSkillId;

  const BattlePartyMember({
    required this.id,
    required this.name,
    required this.build,
    this.hp,
    this.mp,
    this.ult = 0,
    this.potions = 0,
    this.ethers = 0,
    this.fusedSkillId,
  });
}

/// Un actor dentro de la batalla (jugador o enemigo). Mutable a propósito:
/// el motor siempre trabaja sobre una copia ([BattleState.copy]) y
/// devuelve el estado nuevo, así que desde afuera es inmutable.
class Combatant {
  Combatant({
    required this.id,
    required this.name,
    required this.isPlayer,
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.attack,
    required this.critChance,
    this.mp = 0,
    this.maxMp = 0,
    this.magic = 0,
    this.critMultiplier = 1.5,
    this.defense = 0,
    this.defensePercent = 0,
    this.ultChargeBonus = 0,
    this.healBonus = 0,
    Map<StatusKind, int>? statusBonus,
    Set<String>? keystones,
    Set<String>? mechanics,
    this.pierceWeakness = 1,
    this.statusWeakness = 0,
    this.stunOnAttackChance = 0,
    this.lifeSteal = 0,
    this.regenPerTurn = 0,
    this.statusResist = 0,
    this.healReceived = 0,
    this.build,
    this.classId,
    this.weaponType,
    List<String>? skillIds,
    this.potions = 0,
    this.ethers = 0,
    this.enemyType,
    this.elite = false,
    this.boss = false,
    this.areaAttack = false,
    this.pierce = false,
    this.inflicts,
    Map<StatusKind, int>? statuses,
    this.holyTurns = 0,
    this.nextTurn = 0,
    this.defending = false,
    this.protecting = false,
    this.taunt = 0,
    this.bonusDefense = 0,
    this.ult = 0,
    this.actions = 0,
    List<TimedEffect>? effects,
    this.extraTurn = 0,
    this.breakBase = 0,
    this.breakGauge = 0,
    this.breaks = 0,
    this.vulnerable = 0,
    this.breakSkip = false,
    this.ultId,
    this.ultPending = false,
    this.webbed = false,
    this.stance = 0,
    this.stanceTurns = 0,
    this.lava = 0,
    this.voidMarked = false,
    this.phase = 0,
    this.mechTurns = 0,
  })  : statusBonus = statusBonus ?? {},
        keystones = keystones ?? {},
        mechanics = mechanics ?? {},
        effects = effects ?? [],
        skillIds = skillIds ?? const [],
        statuses = statuses ?? {};

  final String id;
  final String name;
  final bool isPlayer;

  // ---- stats ----
  int hp;
  int maxHp;
  double mp;
  int maxMp;
  double speed;
  int attack;
  int magic;
  double critChance;
  double critMultiplier;
  int defense;
  double defensePercent;
  double ultChargeBonus;
  double healBonus;
  Map<StatusKind, int> statusBonus;
  Set<String> keystones;

  /// Mecánicas del árbol v2 (`kMechanics`), ver passive_tree_v2.md.
  Set<String> mechanics;
  final double pierceWeakness;
  final int statusWeakness;
  final double stunOnAttackChance;

  // ---- afijos del arma (loot v2, solo jugadores) ----
  double lifeSteal;
  double regenPerTurn;
  int statusResist;
  double healReceived;

  // ---- solo jugadores ----
  final PlayerBuild? build;
  final String? classId;
  final String? weaponType;
  final List<String> skillIds;
  int potions;
  int ethers;

  // ---- solo enemigos ----
  final String? enemyType;
  final bool elite;
  final bool boss;
  final bool areaAttack;
  final bool pierce;
  final StatusApplication? inflicts;

  // ---- estado de batalla ----
  Map<StatusKind, int> statuses;
  int holyTurns;
  double nextTurn;
  bool defending;
  bool protecting;
  int taunt;
  int bonusDefense;
  double ult;
  int actions;

  /// Buffs, debuffs, marcas y escudos con duración (árbol v2).
  List<TimedEffect> effects;

  /// Danza de Cuchillas: 0 nada, 1 tiene un turno extra pendiente, 2 está
  /// jugando un turno extra (no puede ganar otro).
  int extraTurn;

  // ---- quiebre y ULT enemiga (docs/specs/break_and_enemy_ults.md) ----

  /// Umbral base de la barra de quiebre (ya escalado por grupo, élite y
  /// nivel de zona: `ZoneRules.scaleBattle`, por eso es mutable).
  /// 0: sin barra (jugadores).
  double breakBase;

  /// Barra de quiebre actual (0..[breakMax]).
  double breakGauge;

  /// Quiebres ya sufridos: cada uno sube el umbral +25% (tope ×2).
  int breaks;

  /// Turnos del grupo que le quedan de vulnerabilidad (+50% de daño).
  int vulnerable;

  /// Quebrado: pierde su próximo turno.
  bool breakSkip;

  /// ULT del enemigo (`EnemyUltDef.id`), si tiene. Su carga es [ult].
  final String? ultId;

  /// Avisó su ULT: la lanza en su próximo turno.
  bool ultPending;

  // ---- mecánicas de jefe (docs/specs/bosses.md § "v0.2") ----

  /// Jugador atrapado en una telaraña de la Matriarca: pierde su próximo
  /// turno salvo que un aliado lo libere.
  bool webbed;

  /// Postura del Caballero Hueco: 0 ninguna, 1 escudo (−daño físico),
  /// 2 espada (−daño mágico).
  int stance;

  /// Turnos propios que faltan para cambiar de postura (1 = cambia en su
  /// próximo turno).
  int stanceTurns;

  // ---- mecánicas de jefe v0.3 (docs/specs/bosses.md § "v0.3") ----

  /// Bestia de Magma: turnos propios de lava que quedan (0 = sin lava).
  int lava;

  /// Jugador con la Marca del Vacío del Centinela.
  bool voidMarked;

  /// Fase del jefe (Devorador): 0/1 = primera, 2 = transformado.
  int phase;

  /// Turnos propios del jefe con sus invocaciones incompletas (ecos,
  /// séquito): al llegar a `every` las vuelve a crear.
  int mechTurns;

  bool get hasBreak => breakBase > 0;

  /// Umbral actual: `base × min(2, 1 + 0.25 × quiebres)`.
  double get breakMax =>
      breakBase * (1 + 0.25 * breaks).clamp(1.0, 2.0).toDouble();

  /// Quebrado y vulnerable.
  bool get broken => vulnerable > 0;

  bool get alive => hp > 0;

  /// Suma de los efectos con duración sobre [stat].
  double effectTotal(BuffStat stat) {
    var t = 0.0;
    for (final e in effects) {
      if (e.stat == stat) t += e.value;
    }
    return t;
  }

  /// El efecto de [sourceId] sobre [stat], si tiene.
  TimedEffect? effectFrom(String sourceId, BuffStat stat) {
    for (final e in effects) {
      if (e.sourceId == sourceId && e.stat == stat) return e;
    }
    return null;
  }

  bool hasEffect(BuffStat stat) => effects.any((e) => e.stat == stat);

  /// Vida que absorben sus escudos.
  int get shield => effectTotal(BuffStat.shield).round();
  int stacks(StatusKind k) => statuses[k] ?? 0;

  /// Rama de Paladín elegida en el árbol (`p.branch`).
  String? get branch => keystones.contains('creyente')
      ? 'creyente'
      : keystones.contains('inherente')
          ? 'inherente'
          : null;

  Combatant copy() => Combatant(
        id: id,
        name: name,
        isPlayer: isPlayer,
        hp: hp,
        maxHp: maxHp,
        mp: mp,
        maxMp: maxMp,
        speed: speed,
        attack: attack,
        magic: magic,
        critChance: critChance,
        critMultiplier: critMultiplier,
        defense: defense,
        defensePercent: defensePercent,
        ultChargeBonus: ultChargeBonus,
        healBonus: healBonus,
        statusBonus: Map.of(statusBonus),
        keystones: Set.of(keystones),
        mechanics: Set.of(mechanics),
        pierceWeakness: pierceWeakness,
        statusWeakness: statusWeakness,
        stunOnAttackChance: stunOnAttackChance,
        lifeSteal: lifeSteal,
        regenPerTurn: regenPerTurn,
        statusResist: statusResist,
        healReceived: healReceived,
        build: build,
        classId: classId,
        weaponType: weaponType,
        skillIds: skillIds,
        potions: potions,
        ethers: ethers,
        enemyType: enemyType,
        elite: elite,
        boss: boss,
        areaAttack: areaAttack,
        pierce: pierce,
        inflicts: inflicts,
        statuses: Map.of(statuses),
        holyTurns: holyTurns,
        nextTurn: nextTurn,
        defending: defending,
        protecting: protecting,
        taunt: taunt,
        bonusDefense: bonusDefense,
        ult: ult,
        actions: actions,
        effects: List.of(effects),
        extraTurn: extraTurn,
        breakBase: breakBase,
        breakGauge: breakGauge,
        breaks: breaks,
        vulnerable: vulnerable,
        breakSkip: breakSkip,
        ultId: ultId,
        ultPending: ultPending,
        webbed: webbed,
        stance: stance,
        stanceTurns: stanceTurns,
        lava: lava,
        voidMarked: voidMarked,
        phase: phase,
        mechTurns: mechTurns,
      );
}

/// Resultado final de una batalla. XP y créditos son por jugador.
class BattleOutcome {
  final bool victory;
  final int xp;
  final int credits;

  const BattleOutcome({required this.victory, this.xp = 0, this.credits = 0});
}

/// Estado completo de una batalla (`S.battle` del prototipo, sin la
/// parte visual: posiciones, efectos y tiempos de animación son de la UI).
class BattleState {
  BattleState({
    required this.party,
    required this.enemies,
    this.clock = 0,
    this.currentId,
    this.log = '',
    this.outcome,
    this.boss = false,
    this.elite = false,
  });

  final List<Combatant> party;
  final List<Combatant> enemies;
  double clock;

  /// Id del actor que tiene el turno, o `null` si hay que llamar a
  /// `BattleEngine.nextTurn`.
  String? currentId;

  /// Última línea del log de batalla, con el desglose de los números.
  String log;
  BattleOutcome? outcome;
  final bool boss;
  final bool elite;

  bool get ended => outcome != null;

  Combatant? byId(String id) {
    for (final c in party) {
      if (c.id == id) return c;
    }
    for (final c in enemies) {
      if (c.id == id) return c;
    }
    return null;
  }

  Combatant? get current => currentId == null ? null : byId(currentId!);

  BattleState copy() => BattleState(
        party: [for (final c in party) c.copy()],
        enemies: [for (final c in enemies) c.copy()],
        clock: clock,
        currentId: currentId,
        log: log,
        outcome: outcome,
        boss: boss,
        elite: elite,
      );
}
