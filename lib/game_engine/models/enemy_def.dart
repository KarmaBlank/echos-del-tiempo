import 'skill.dart' show PartyBuff;
import 'status.dart';

/// Un tipo de enemigo (`EN` en el prototipo).
class EnemyDef {
  final String id;
  final String name;
  final int hp;
  final int attack;
  final double speed;
  final int xp;
  final int credits;
  final StatusApplication? inflicts;
  final bool pierce;
  final bool boss;

  /// Ataque a todo el equipo cada 3 acciones (Devorador de Eras).
  final bool areaAttack;

  /// Umbral base de la barra de quiebre (con 1 jugador; escala con el
  /// grupo como la vida). Ver docs/specs/break_and_enemy_ults.md § 1.
  final int breakMax;

  /// ULT propia (`EnemyUltDef.id`), solo jefes.
  final String? ultId;

  /// ULT de su versión élite (docs/specs/ultimates_v2.md § 4.3); sin
  /// ella, Furia Élite (`kEliteUltId`).
  final String? eliteUltId;

  /// Título del cartel de entrada del jefe (docs/specs/bosses.md).
  final String? title;

  /// Mecánica propia del jefe (`BossMechanicDef.id` de
  /// `kBossMechanics`), ver docs/specs/bosses.md § "v0.2".
  final String? mechanicId;

  /// Legendario asociado (`UniqueDef.id`): el jefe tiene chance de
  /// soltarlo (dato para el loot).
  final String? legendaryId;

  /// Reducción del daño que recibe (0.2 = −20%): armadura de los comunes
  /// pesados.
  final double armor;

  /// Invocación que no actúa (cristales de la Sierpe): no tiene turno, no
  /// da XP ni créditos y muere con su jefe.
  final bool passive;

  /// Nombre femenino ("la Matriarca Araña") para los textos.
  final bool feminine;

  // ---- comunes v0.3 (docs/specs/bosses.md § "v0.3") ----

  /// Probabilidad de que un golpe primario del grupo solo lo roce (×0.3).
  final double evasion;

  /// Cada golpe que conecta retrasa al jugador `IV × delayHit`.
  final double delayHit;

  /// Cada golpe que conecta marca al jugador: +[markHit] de daño recibido
  /// 2 turnos (`TimedEffect` de origen `vigilancia`).
  final double markHit;

  /// Estados en ciclo, uno por acción (reemplaza a [inflicts]).
  final List<StatusApplication> inflictCycle;

  const EnemyDef({
    required this.id,
    required this.name,
    required this.hp,
    required this.attack,
    required this.speed,
    required this.xp,
    required this.credits,
    this.inflicts,
    this.pierce = false,
    this.boss = false,
    this.areaAttack = false,
    this.breakMax = 0,
    this.ultId,
    this.eliteUltId,
    this.title,
    this.mechanicId,
    this.legendaryId,
    this.armor = 0,
    this.passive = false,
    this.feminine = false,
    this.evasion = 0,
    this.delayHit = 0,
    this.markHit = 0,
    this.inflictCycle = const [],
  });

  /// "el Rey Limo" / "la Matriarca Araña".
  String get theName => '${feminine ? 'la' : 'el'} $name';
}

/// Tipo de mecánica de jefe (docs/specs/bosses.md § "v0.2"). El motor
/// tiene código por tipo, los números viven en [BossMechanicDef].
enum BossMechanicKind {
  /// Telaraña: atrapa a un jugador, que pierde su próximo turno salvo que
  /// un aliado lo libere con un ataque.
  web,

  /// Escarcha: −velocidad a todo el grupo por turno del jefe mientras
  /// vivan sus cristales.
  frost,

  /// Postura: alterna escudo (−daño físico) y espada (−daño mágico).
  stance,

  // ---- v0.3 (docs/specs/bosses.md § "v0.3") ----

  /// Ecos: copias que actúan y reciben daño reducido; vuelven si el jefe
  /// pasa `every` turnos con alguno caído.
  echo,

  /// Lava: cada `every` acciones el piso hace erupción `turns` turnos; el
  /// que se defiende con lava se quema.
  lava,

  /// Séquito: invocaciones que actúan; mientras viva alguna el jefe es
  /// inmune a los estados.
  summon,

  /// Marca del Vacío: marca a un jugador cada `every` acciones; su
  /// próximo golpe al marcado pega × `value` salvo que lo protejan.
  mark,

  /// Fases: al bajar del `value` de la vida se transforma (fase 2).
  phases,

  /// Jefe del Abismo v0.8: fases con rotación de movimientos
  /// (`kAbyssBosses`, docs/specs/abyss_bosses.md § 2). `value` = daño que
  /// reciben sus invocaciones si son ecos (0 = no son ecos).
  abyss,
}

/// Mecánica propia de un jefe, como datos.
class BossMechanicDef {
  const BossMechanicDef({
    required this.id,
    required this.kind,
    required this.name,
    required this.counter,
    this.every = 0,
    this.value = 0,
    this.soloValue = 0,
    this.cap = 0,
    this.addType,
    this.adds = 0,
    this.soloAdds = 0,
    this.turns = 0,
    this.power = 0,
    this.soloPower = 0,
  });

  final String id;
  final BossMechanicKind kind;
  final String name;

  /// Cómo contrarrestarla (tooltip del chip, markup).
  final String counter;

  /// Cada cuántas acciones / turnos propios se dispara (telaraña: cada N
  /// acciones; postura: cambia cada N turnos).
  final int every;

  /// Valor con grupo (escarcha: −velocidad por turno; postura: daño
  /// bloqueado; telaraña: fracción del ATQ del golpe que la teje).
  final double value;

  /// Variante en solo (escarcha: sin uso; postura: daño bloqueado;
  /// telaraña: fracción del turno que pierde al forcejear).
  final double soloValue;

  /// Tope (escarcha: −velocidad máxima).
  final double cap;

  /// Invocaciones al empezar (cristales): tipo y cantidad con grupo / solo.
  final String? addType;
  final int adds;
  final int soloAdds;

  /// Duración en turnos propios (lava).
  final int turns;

  /// Multiplicador de ATQ con grupo / en solo (lava: daño de la lava;
  /// fases: ATQ de la fase 2).
  final double power;
  final double soloPower;
}

/// ULT de un enemigo (jefes y élites). Ver
/// docs/specs/break_and_enemy_ults.md § 2.
class EnemyUltDef {
  final String id;
  final String name;

  /// Multiplicador del ATQ del enemigo.
  final double power;

  /// A todo el equipo (si no, al objetivo elegido como siempre).
  final bool allTargets;

  /// Estado que aplica a cada golpeado.
  final StatusApplication? status;

  /// Retrasa a todo el equipo `IV × delayAll`.
  final double delayAll;

  /// Borra los buffs del equipo (efectos positivos, escudos y DEF de
  /// batalla) después del golpe.
  final bool wipeBuffs;

  /// Crítico garantizado.
  final bool guaranteedCrit;

  /// Efecto extra de la mecánica del jefe (telaraña, cristales, postura).
  final EnemyUltExtra extra;

  /// Coro de Ecos: poder extra por invocación viva.
  final double perAdd;

  /// Erupción Total: turnos de lava.
  final int turns;

  // ---- ULT de élite v2 (docs/specs/ultimates_v2.md § 4.3) ----

  /// Golpes seguidos (a todos o, si no es a todos, cada uno a un jugador
  /// al azar).
  final int hits;

  /// Escudo propio: fracción de su vida máx., por [selfShieldTurns].
  final double selfShield;
  final int selfShieldTurns;

  /// Se cura esta fracción del daño hecho.
  final double drainHeal;

  /// Debuffs a cada golpeado (velocidad, daño recibido...).
  final List<PartyBuff> debuffs;

  /// Retrasa a cada golpeado `IV × delayTarget`.
  final double delayTarget;

  /// Estados extra a cada golpeado (con su probabilidad).
  final List<StatusApplication> extraStatuses;

  /// Aplica el estado de su ciclo (`EnemyDef.inflictCycle`) en vez de
  /// [status] (Heraldo de las Eras).
  final bool cycleStatus;

  const EnemyUltDef({
    required this.id,
    required this.name,
    required this.power,
    this.allTargets = false,
    this.status,
    this.delayAll = 0,
    this.wipeBuffs = false,
    this.guaranteedCrit = false,
    this.extra = EnemyUltExtra.none,
    this.perAdd = 0,
    this.turns = 0,
    this.hits = 1,
    this.selfShield = 0,
    this.selfShieldTurns = 2,
    this.drainHeal = 0,
    this.debuffs = const [],
    this.delayTarget = 0,
    this.extraStatuses = const [],
    this.cycleStatus = false,
  });
}

/// Efecto extra de una ULT de jefe ligado a su mecánica.
enum EnemyUltExtra {
  none,

  /// Nido Venenoso: con grupo, atrapa en telaraña al de más vida.
  web,

  /// Aliento Glacial: los cristales rotos se vuelven a formar.
  reformCrystals,

  /// Juicio Hueco: cambia de postura al terminar.
  stanceShift,

  // ---- v0.3 ----

  /// Coro de Ecos: +[EnemyUltDef.perAdd] de poder por eco vivo y rehace
  /// los ecos.
  echoChorus,

  /// Erupción Total: la lava sube `EnemyUltDef.turns` turnos.
  lavaFlood,

  /// Lamento Eterno: completa el séquito.
  summonAll,

  /// Colapso del Vacío: el marcado sin proteger recibe ×2 y después
  /// marca al de más vida.
  voidMark,
}
