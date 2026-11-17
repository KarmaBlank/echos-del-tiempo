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
  });
}
