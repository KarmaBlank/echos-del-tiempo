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

  /// ULT propia (`EnemyUltDef.id`), solo jefes. Los élites usan Furia
  /// Élite (`kEliteUltId`).
  final String? ultId;

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
    this.title,
    this.mechanicId,
    this.legendaryId,
    this.armor = 0,
    this.passive = false,
    this.feminine = false,
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
}
