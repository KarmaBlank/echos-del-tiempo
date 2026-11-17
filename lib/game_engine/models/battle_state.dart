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
    this.pierceWeakness = 1,
    this.statusWeakness = 0,
    this.stunOnAttackChance = 0,
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
  })  : statusBonus = statusBonus ?? {},
        keystones = keystones ?? {},
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
  final double pierceWeakness;
  final int statusWeakness;
  final double stunOnAttackChance;

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

  bool get alive => hp > 0;
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
        pierceWeakness: pierceWeakness,
        statusWeakness: statusWeakness,
        stunOnAttackChance: stunOnAttackChance,
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
