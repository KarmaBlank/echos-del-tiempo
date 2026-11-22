import '../data/enemy_families.dart';
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
  final int aethers;

  /// Habilidad fusionada al arma equipada (`p.fuse[p.eq]`), si hay.
  final String? fusedSkillId;

  /// Habilidades que trae aparte del arma (loadout de la Travesía,
  /// roguelike.md § 8.1). El Mundo no las usa.
  final List<String> extraSkills;

  /// Poder de cada habilidad (× sobre el del catálogo; mejoras de la
  /// armería de la Travesía, roguelike.md § 12.2). Vacío en el Mundo.
  final Map<String, double> skillScale;

  const BattlePartyMember({
    required this.id,
    required this.name,
    required this.build,
    this.hp,
    this.mp,
    this.ult = 0,
    this.potions = 0,
    this.ethers = 0,
    this.aethers = 0,
    this.fusedSkillId,
    this.extraSkills = const [],
    this.skillScale = const {},
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
    this.duoStunBonus = 0,
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
    this.aethers = 0,
    this.enemyType,
    this.elite = false,
    this.boss = false,
    this.areaAttack = false,
    this.pierce = false,
    this.inflicts,
    Map<StatusKind, int>? statuses,
    this.holyTurns = 0,
    this.basicHits = 0,
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
    this.level = 0,
    this.breakGauge = 0,
    this.breaks = 0,
    this.vulnerable = 0,
    this.breakSkip = false,
    this.fissured = false,
    this.ultId,
    this.ultPending = false,
    this.webbed = false,
    this.stance = 0,
    this.stanceTurns = 0,
    this.lava = 0,
    this.voidMarked = false,
    this.phase = 0,
    this.mechTurns = 0,
    Set<String>? once,
    EnemyFamily? family,
    this.brittle = false,
    this.freezeResist = 0,
    Map<StatusKind, String>? primedBy,
    this.abyssTurns = 0,
    this.abyssEnraged = false,
    this.abyssSeal = 0,
    this.abyssSealTurns = 0,
    this.abyssAspect = 0,
    this.abyssTaken = 0,
    this.delayStreak = 0,
    this.abyssFeast = 0,
    this.abyssCopy,
    this.summonOwner,
    this.summonKind,
    this.summonTurns = 0,
    this.summonKills = 0,
    this.pulse = 0,
    this.ultBonusTurn = 0,
    this.chained = false,
    this.guardStreak = false,
    this.guardHitPending = false,
    this.practice = false,
    this.ultWeaken = 0,
    this.lastSkillId,
    this.skillScale = const {},
    this.doom = 0,
    this.doomTurns = 0,
    this.doomBy,
    this.tag,
  })  : primedBy = primedBy ?? {},
        family = family ??
            (isPlayer || enemyType == null ? null : kEnemyFamily[enemyType]),
        once = once ?? {},
        statusBonus = statusBonus ?? {},
        keystones = keystones ?? {},
        mechanics = mechanics ?? {},
        effects = effects ?? [],
        skillIds = skillIds ?? const [],
        statuses = statuses ?? {};

  final String id;

  /// Nombre a mostrar (arena, línea de tiempo, logs). Con repetidos lleva
  /// al final la letra de [tag] ("Lobo B"; battle_presentation.md
  /// § "Identificador de repetidos").
  String name;

  /// Letra que distingue a dos combatientes del mismo tipo en la misma
  /// batalla (A, B, C…); `null` si el tipo no se repite. Estable: se
  /// asigna una vez ([assignCombatantTags]) y no cambia.
  String? tag;
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

  /// Aturdir extra con un aliado vivo (Escudo compartido, clase).
  final double duoStunBonus;

  // ---- afijos del arma (loot v2, solo jugadores) ----
  double lifeSteal;
  double regenPerTurn;
  int statusResist;
  double healReceived;

  // ---- solo jugadores ----
  final PlayerBuild? build;
  final String? classId;
  final String? weaponType;

  /// Mutable solo para el tutorial: las habilidades prestadas del guion
  /// (combat_tutorial.md § 3).
  List<String> skillIds;
  int potions;
  int ethers;
  int aethers;

  // ---- solo enemigos ----
  final String? enemyType;
  final bool elite;
  final bool boss;
  final bool areaAttack;
  final bool pierce;
  StatusApplication? inflicts;

  // ---- estado de batalla ----
  Map<StatusKind, int> statuses;
  int holyTurns;

  /// Ataques básicos con elemento de arma dados (weapon_identity.md § 4:
  /// 1 pila cada `kWeaponElementHitsPerStack`).
  int basicHits;
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

  /// Nivel del enemigo en esta batalla (`ZoneRules.scaleBattle`); 0 =
  /// sin escalar (vale el nivel base del catálogo). Para el tope por golpe
  /// (combo_balance.md § 3.2).
  int level;

  /// Barra de quiebre actual (0..[breakMax]).
  double breakGauge;

  /// Quiebres ya sufridos: cada uno sube el umbral +25% (tope ×2).
  int breaks;

  /// Turnos del grupo que le quedan de vulnerabilidad (+50% de daño).
  int vulnerable;

  /// Quebrado: pierde su próximo turno.
  bool breakSkip;

  /// Fisurado (combo_balance.md § 5): la barra se llenó; un golpe con
  /// Quebrar lo quiebra. Si llega a su turno así, la barra vuelve a la
  /// mitad.
  bool fissured;

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

  /// Mecánicas de "1 vez por batalla" ya usadas (Inmortal, Mártir;
  /// docs/specs/ascension.md § 3.1).
  Set<String> once;

  // ---- elementos v0.7 (docs/specs/elemental_reactions.md) ----

  /// Familia / raza (§ 5.3–5.4): vale igual para jugadores y enemigos.
  /// Enemigos: la de su tipo (`kEnemyFamily`) si no se pasa otra;
  /// jugadores: `null` hasta que existan las razas.
  final EnemyFamily? family;

  /// Quebradizo (§ 7): perdió el turno congelado; el próximo golpe
  /// físico hace ×1.5 y lo descongela.
  bool brittle;

  /// Turnos propios que le quedan de resistencia a la Congelación
  /// (recién descongelado).
  int freezeResist;

  /// Quién preparó cada estado que una reacción puede consumir (el
  /// último jugador que lo aplicó): disparador `onPrimedReaction` del
  /// árbol (passive_tree_v4.md § 8).
  Map<StatusKind, String> primedBy;

  // ---- Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md § 2) ----

  /// Turnos propios jugados (la furia llega en `enrageTurns`).
  int abyssTurns;

  /// En furia: ATQ × `enragePower` y golpes a todos.
  bool abyssEnraged;

  /// Sello activo: `ReactionKind.index + 1` (0 = sin sello).
  int abyssSeal;

  /// Turnos propios que le quedan al sello.
  int abyssSealTurns;

  /// Aspecto elemental: `GameElement.index + 1` (0 = sin aspecto).
  int abyssAspect;

  /// Daño recibido desde su acción anterior (Rebobinar).
  int abyssTaken;

  /// Retrasos recibidos del grupo desde su último turno (rendimiento
  /// decreciente, combo_balance.md § 3.3).
  int delayStreak;

  /// Buffs del grupo que se comió (Devorar).
  int abyssFeast;

  /// Última habilidad del grupo que copia (Reflejo).
  String? abyssCopy;

  // ---- Invocador v0.8.1 (docs/specs/summoner.md § 3) ----

  /// Id del jugador que la invocó (`null` = no es una invocación).
  final String? summonOwner;

  /// `SummonKind.name` de la invocación.
  final String? summonKind;

  /// Turnos propios que le quedan (99 = Pacto Eterno).
  int summonTurns;

  /// Enemigos que mató (Festín Arcano).
  int summonKills;

  // ---- Pulso e Instante v0.9 (combo_balance.md § 5.2) ----

  /// Pulso del jugador (0..`BattleEngine.pulseMax`; arranca en
  /// `pulseStart`). Enemigos e invocaciones: 0.
  int pulse;

  /// Carga de ULT extra (árbol, mods, efectos) ganada desde que empezó su
  /// turno en curso, con tope por turno (combat.md § "Límites"). Vuelve a
  /// 0 al empezar su turno.
  double ultBonusTurn;

  /// Ya usó una habilidad Instante en este turno: el turno sigue para
  /// una acción más, pero no otra Instante encadenada.
  bool chained;

  /// Su última defensa fue un Defender elegido (no la automática por
  /// tiempo agotado) y no hizo otra cosa desde entonces: el próximo
  /// Defender da +1 Pulso en vez de +2 (battle_attack_menu.md § 6).
  /// Lo decide el host; viaja en el estado como `gst` (opcional).
  bool guardStreak;

  /// Defendió a mano y todavía no le cobró el +6 de ULT por recibir un
  /// golpe defendiendo (una vez por defensa).
  bool guardHitPending;

  /// De práctica (combat_tutorial.md § 3): su vida nunca baja de 1, no
  /// cae ("se recompone").
  bool practice;

  // ---- ULT v2 (docs/specs/ultimates_v2.md) ----

  /// ULT enemiga avisada y drenada (§ 4.1): fracción de poder que pierde
  /// al lanzarla (tope 0.4).
  double ultWeaken;

  /// Última habilidad que usó el jugador (Eco Doble la repite).
  String? lastSkillId;

  /// Poder × por habilidad ([BattlePartyMember.skillScale]).
  final Map<String, double> skillScale;

  /// Marca de Lo Que Será: daño que cae cuando [doomTurns] llega a 0
  /// (baja al empezar cada turno del marcado) y quién la puso.
  int doom;
  int doomTurns;
  String? doomBy;

  bool get isSummon => summonOwner != null;

  /// Ascensión del jugador (`null` = clase base o enemigo).
  String? get ascensionId => build?.ascension.id;

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
        duoStunBonus: duoStunBonus,
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
        aethers: aethers,
        enemyType: enemyType,
        elite: elite,
        boss: boss,
        areaAttack: areaAttack,
        pierce: pierce,
        inflicts: inflicts,
        statuses: Map.of(statuses),
        holyTurns: holyTurns,
        basicHits: basicHits,
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
        level: level,
        breakGauge: breakGauge,
        breaks: breaks,
        vulnerable: vulnerable,
        breakSkip: breakSkip,
        fissured: fissured,
        ultId: ultId,
        ultPending: ultPending,
        webbed: webbed,
        stance: stance,
        stanceTurns: stanceTurns,
        lava: lava,
        voidMarked: voidMarked,
        phase: phase,
        mechTurns: mechTurns,
        once: Set.of(once),
        family: family,
        brittle: brittle,
        freezeResist: freezeResist,
        primedBy: Map.of(primedBy),
        abyssTurns: abyssTurns,
        abyssEnraged: abyssEnraged,
        abyssSeal: abyssSeal,
        abyssSealTurns: abyssSealTurns,
        abyssAspect: abyssAspect,
        abyssTaken: abyssTaken,
        delayStreak: delayStreak,
        abyssFeast: abyssFeast,
        abyssCopy: abyssCopy,
        summonOwner: summonOwner,
        summonKind: summonKind,
        summonTurns: summonTurns,
        summonKills: summonKills,
        pulse: pulse,
        ultBonusTurn: ultBonusTurn,
        chained: chained,
        guardStreak: guardStreak,
        guardHitPending: guardHitPending,
        practice: practice,
        ultWeaken: ultWeaken,
        lastSkillId: lastSkillId,
        skillScale: skillScale,
        doom: doom,
        doomTurns: doomTurns,
        doomBy: doomBy,
        tag: tag,
      );
}

/// Letras de repetidos (battle_presentation.md § "Identificador de
/// repetidos"): dentro de enemigos (por tipo), grupo (por nombre) e
/// invocaciones (por tipo), si dos o más comparten clave, los que todavía
/// no tienen letra reciben la primera libre (A, B, C…, después números) y
/// se les agrega al nombre. Los que ya tienen letra la conservan.
void assignCombatantTags(BattleState s) {
  _tagGroup(s.enemies, (c) => c.enemyType ?? _baseName(c));
  _tagGroup(s.party, _baseName);
  _tagGroup(s.summons, (c) => c.summonKind ?? _baseName(c));
}

String _baseName(Combatant c) => c.tag == null
    ? c.name
    : c.name.substring(0, c.name.length - c.tag!.length - 1);

String _tagLetter(int i) =>
    i < 26 ? String.fromCharCode(65 + i) : '${i + 1}';

void _tagGroup(List<Combatant> list, String Function(Combatant) key) {
  final groups = <String, List<Combatant>>{};
  for (final c in list) {
    groups.putIfAbsent(key(c), () => []).add(c);
  }
  for (final g in groups.values) {
    if (g.length < 2) continue;
    final used = {for (final c in g) if (c.tag != null) c.tag!};
    var i = 0;
    for (final c in g) {
      if (c.tag != null) continue;
      while (used.contains(_tagLetter(i))) {
        i++;
      }
      c.tag = _tagLetter(i);
      used.add(c.tag!);
      c.name = '${c.name} ${c.tag}';
    }
  }
}

/// Resultado final de una batalla. XP y créditos son por jugador.
class BattleOutcome {
  final bool victory;
  final int xp;
  final int credits;

  const BattleOutcome({required this.victory, this.xp = 0, this.credits = 0});
}

/// Regla de turnos (docs/specs/roguelike.md § 6). La elige quien arma la
/// batalla: el Mundo siempre [velocidad]; la Travesía [porBando].
enum TurnRule {
  /// Línea de tiempo por velocidad (la de siempre).
  velocidad,

  /// Turno del grupo (cada jugador una vez, en el orden que quiera) y
  /// después turno enemigo (todos en orden). La velocidad no cuenta.
  porBando,

  /// Por rondas (docs/specs/turn_modes.md § 4): cada combatiente vivo
  /// actúa una vez por ronda, en orden de velocidad; los jugadores
  /// seguidos en el orden forman un bloque y actúan en cualquier orden.
  porRonda,

  /// Por fases (turn_modes.md § 3): fase enemiga y después fase de
  /// jugadores (cada uno actúa o TERMINA TURNO). Es `porBando` con los
  /// enemigos primero.
  porFases,
}

/// Estado completo de una batalla (`S.battle` del prototipo, sin la
/// parte visual: posiciones, efectos y tiempos de animación son de la UI).
class BattleState {
  BattleState({
    required this.party,
    required this.enemies,
    List<Combatant>? summons,
    this.clock = 0,
    this.currentId,
    this.log = '',
    this.outcome,
    this.boss = false,
    this.elite = false,
    this.turnRule = TurnRule.velocidad,
    this.groupPhase = false,
    Set<String>? acted,
    this.round = 0,
    List<String>? roundOrder,
    Set<String>? waited,
  })  : summons = summons ?? [],
        acted = acted ?? {},
        roundOrder = roundOrder ?? [],
        waited = waited ?? {};

  final List<Combatant> party;
  final List<Combatant> enemies;

  /// Invocaciones vivas del grupo (docs/specs/summoner.md § 3): actúan
  /// en la línea de tiempo con IA; no cuentan para ganar ni perder.
  final List<Combatant> summons;
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

  final TurnRule turnRule;

  /// `porBando`: es el turno del grupo (si no, el de los enemigos).
  bool groupPhase;

  /// `porBando`: quiénes ya actuaron en esta ronda.
  final Set<String> acted;

  /// `porBando`: ronda en curso (1 = la primera).
  int round;

  /// Regla de fase de grupo: la de la Travesía y Por fases (comparten el
  /// turno del grupo, `groupPhase` y `acted`).
  bool get porBando =>
      turnRule == TurnRule.porBando || turnRule == TurnRule.porFases;

  bool get porFases => turnRule == TurnRule.porFases;
  bool get porRonda => turnRule == TurnRule.porRonda;

  /// Cualquier regla que no sea la línea de tiempo.
  bool get grouped => turnRule != TurnRule.velocidad;

  /// `porRonda`: orden de la ronda en curso (ids), fijado al empezarla.
  final List<String> roundOrder;

  /// `porRonda`: quiénes ya usaron Esperar en esta ronda.
  final Set<String> waited;

  /// `porRonda`: los que faltan actuar en la ronda, en orden (vivos).
  List<Combatant> get roundRemaining => [
        for (final id in roundOrder)
          if (byId(id) case final c? when c.alive && !acted.contains(id)) c
      ];

  /// `porRonda`: el bloque de jugadores al frente de lo que falta.
  List<Combatant> get roundBlock {
    final out = <Combatant>[];
    for (final c in roundRemaining) {
      if (!c.isPlayer || c.isSummon) break;
      out.add(c);
    }
    return out;
  }

  /// `porBando`: jugadores vivos que todavía no actuaron en el turno del
  /// grupo (vacío fuera de él).
  List<Combatant> get pendingGroup => !grouped || !groupPhase
      ? const []
      : porRonda
          ? roundBlock
          : [
          for (final p in party)
            if (p.alive && !acted.contains(p.id)) p
        ];

  /// `porBando`: nadie tiene el turno y el grupo puede mandar comandos
  /// (el primero que manda, actúa).
  bool get awaitingGroup =>
      grouped &&
      !ended &&
      groupPhase &&
      currentId == null &&
      pendingGroup.isNotEmpty;

  Combatant? byId(String id) {
    for (final c in party) {
      if (c.id == id) return c;
    }
    for (final c in enemies) {
      if (c.id == id) return c;
    }
    for (final c in summons) {
      if (c.id == id) return c;
    }
    return null;
  }

  Combatant? get current => currentId == null ? null : byId(currentId!);

  BattleState copy() => BattleState(
        party: [for (final c in party) c.copy()],
        enemies: [for (final c in enemies) c.copy()],
        summons: [for (final c in summons) c.copy()],
        clock: clock,
        currentId: currentId,
        log: log,
        outcome: outcome,
        boss: boss,
        elite: elite,
        turnRule: turnRule,
        groupPhase: groupPhase,
        acted: {...acted},
        round: round,
        roundOrder: [...roundOrder],
        waited: {...waited},
      );
}
