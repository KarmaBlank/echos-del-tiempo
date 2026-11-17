import 'status.dart';

/// Tipos de habilidad del prototipo (`kind` en `SK` / `ULTS`).
enum SkillKind {
  physical, // 'phys': daño con ATQ
  magical, // 'mag': daño con MAG
  heal,
  regen,
  haste,
  taunt,
  guard,
  defenseUp, // 'defup'
  protect,
  bulwark,
}

/// Una habilidad (o ULT). Puerto 1:1 de las entradas de `SK` / `ULTS`.
class SkillDef {
  final String id;
  final String name;
  final int mp;
  final SkillKind kind;
  final double power;
  final bool allTargets;
  final double delay;
  final StatusApplication? status;
  final double critBonus;
  final int cleanse;

  /// `n` del prototipo: turnos de Provocar o DEF de Fortaleza.
  final int amount;

  const SkillDef({
    required this.id,
    required this.name,
    required this.kind,
    this.mp = 0,
    this.power = 0,
    this.allTargets = false,
    this.delay = 0,
    this.status,
    this.critBonus = 0,
    this.cleanse = 0,
    this.amount = 0,
  });

  bool get dealsDamage =>
      kind == SkillKind.physical || kind == SkillKind.magical;
}

/// Ataque combinado de dos clases (`DUALS`).
class DualDef {
  final String name;
  final StatusApplication status;
  final double power;

  const DualDef(this.name, this.status, this.power);
}
