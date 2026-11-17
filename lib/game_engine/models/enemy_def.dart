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
  });
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

  const EnemyUltDef({
    required this.id,
    required this.name,
    required this.power,
    this.allTargets = false,
    this.status,
    this.delayAll = 0,
    this.wipeBuffs = false,
    this.guaranteedCrit = false,
  });
}
