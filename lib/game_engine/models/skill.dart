import 'passive_mechanic.dart' show BuffStat;
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

  /// Sin daño: solo sus efectos de grupo / propios (kit de ascensión,
  /// docs/specs/ascension.md § 4).
  support,
}

/// Buff de grupo de una habilidad (gritos del kit de ascensión).
class PartyBuff {
  const PartyBuff(this.stat, this.value, this.turns);
  final BuffStat stat;
  final double value;
  final int turns;
}

/// Una habilidad (o ULT). Puerto 1:1 de las entradas de `SK` / `ULTS`,
/// más los efectos opcionales del kit de ascensión (ascension.md § 4).
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

  // ---- kit de ascensión (todo apagado por defecto) ----

  /// Fracción de la vida máx. que cuesta usarla (no baja de 1).
  final double hpCost;

  /// Fracción del daño de la acción que cura.
  final double lifeSteal;

  /// Estados extra que aplica a cada golpeado (secundarios).
  final List<StatusApplication> extraStatuses;

  /// +daño por cada stack elemental del objetivo (los consume).
  final double detonate;

  /// Remata (no jefes ni élites) si el objetivo queda por debajo de esto.
  final double execute;

  /// Poder de la trampa que deja en cada objetivo (ATQ × trap).
  final double trap;

  /// Buffs para todos los aliados vivos (el que la usa incluido).
  final List<PartyBuff> partyBuffs;

  /// Escudo para cada aliado: fracción de la vida máx. del que la usa.
  final double partyShield;
  final int partyShieldTurns;

  /// Adelanta a cada aliado (no al que la usa) esta fracción de su
  /// espera; sin aliados, adelanta el próximo turno propio.
  final double advanceAllies;

  /// Buff propio (Apuntar).
  final PartyBuff? selfBuff;

  /// Factor del próximo turno propio (Apuntar: 0.5).
  final double selfTurn;

  /// Pone Protección (como la habilidad Protección).
  final bool protect;

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
    this.hpCost = 0,
    this.lifeSteal = 0,
    this.extraStatuses = const [],
    this.detonate = 0,
    this.execute = 0,
    this.trap = 0,
    this.partyBuffs = const [],
    this.partyShield = 0,
    this.partyShieldTurns = 0,
    this.advanceAllies = 0,
    this.selfBuff,
    this.selfTurn = 1,
    this.protect = false,
  });

  bool get dealsDamage =>
      kind == SkillKind.physical || kind == SkillKind.magical;

  /// Tiene un efecto para el grupo (filtro `rallySkill`).
  bool get rally =>
      partyBuffs.isNotEmpty || partyShield > 0 || advanceAllies > 0;
}

/// Ataque combinado de dos clases (`DUALS`).
class DualDef {
  final String name;
  final StatusApplication status;
  final double power;

  const DualDef(this.name, this.status, this.power);
}
