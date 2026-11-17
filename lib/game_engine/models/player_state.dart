import 'attributes.dart';
import 'item.dart';
import 'passive_tree.dart';
import 'status.dart';
import 'weapon.dart';

/// Insumos de un jugador para calcular sus stats derivados. Inmutable:
/// `StatsCalculator.calculate` toma esto y devuelve un [DerivedStats]
/// nuevo, nunca muta nada. Equivale al `p` que entra a `stats(p)` en el
/// prototipo, pero separado del resultado (allá todo vivía en el mismo
/// objeto mutable).
class PlayerBuild {
  final String classId;
  final int level;
  final PlayerAttributes attributes;
  final WeaponDef equippedWeapon;
  final WeaponUpgradeLevels weaponUpgrades;
  final PlayerPassiveProgress passiveProgress;

  /// La instancia equipada (afijos, pasiva, habilidades trasladadas).
  /// `null` = la base sola, como antes de loot v2. Sus mejoras de forja
  /// mandan sobre [weaponUpgrades].
  final ItemInstance? item;

  /// DEF extra que solo existe dentro de una batalla (`p.bdef`: Fortaleza,
  /// Baluarte). Fuera de combate siempre es 0.
  final int bonusDefense;

  const PlayerBuild({
    required this.classId,
    required this.level,
    required this.attributes,
    required this.equippedWeapon,
    this.weaponUpgrades = const WeaponUpgradeLevels(),
    this.passiveProgress = PlayerPassiveProgress.empty,
    this.item,
    this.bonusDefense = 0,
  });

  /// Mejoras de forja efectivas.
  WeaponUpgradeLevels get forge => item?.forge ?? weaponUpgrades;

  PlayerBuild withBonusDefense(int value) => PlayerBuild(
        classId: classId,
        level: level,
        attributes: attributes,
        equippedWeapon: equippedWeapon,
        weaponUpgrades: weaponUpgrades,
        passiveProgress: passiveProgress,
        item: item,
        bonusDefense: value,
      );
}

/// Una línea del desglose de un stat ("ATQ 21 = base 15 + 40% arma"),
/// para el log de combate y la UI. Ver loot.md § 12.
class StatBreakdown {
  final String stat;
  final num total;

  /// Pasos en orden: base → implícito → afijos → forja → árbol.
  final List<String> steps;
  const StatBreakdown(this.stat, this.total, this.steps);

  String get text => '$stat $total = ${steps.join(' ')}';
}

/// Resultado de `StatsCalculator.calculate` — equivalente a los campos
/// `p.mhp, p.mmp, p.spd, p.crit, p.defn, p.atk, p.mag...` que el
/// prototipo calculaba mutando `p` dentro de `stats(p)`.
class DerivedStats {
  final int maxHp;
  final int maxMp;
  final double speed;
  final double critChance;
  final double critMultiplier;
  final int defense;
  final double defensePercent;
  final int attack;
  final int magic;
  final double ultChargeBonus;
  final double healBonus;
  final Set<String> keystones;

  /// Mecánicas del árbol v2 (`kMechanics`): notables y keystones nuevas.
  final Set<String> mechanics;

  /// Stacks extra de cada estado que este jugador aplica (`p.stb`).
  final Map<StatusKind, int> statusBonus;

  // ---- loot v2 (afijos del arma) ----

  /// Fracción del daño hecho que cura (robo de vida).
  final double lifeSteal;

  /// Fracción de la vida máx. que regenera al empezar su turno.
  final double regenPerTurn;

  /// Stacks menos de Quemadura / Veneno / Congelación al recibirlos
  /// (mínimo 1).
  final int statusResist;

  /// Bonus a la curación recibida.
  final double healReceived;

  /// Desglose por stat (`ATQ`, `MAG`, `HP`, `MP`, `VEL`, `CRIT`, `DEF`).
  final Map<String, StatBreakdown> breakdown;

  const DerivedStats({
    required this.maxHp,
    required this.maxMp,
    required this.speed,
    required this.critChance,
    required this.critMultiplier,
    required this.defense,
    required this.defensePercent,
    required this.attack,
    required this.magic,
    required this.ultChargeBonus,
    required this.healBonus,
    required this.keystones,
    this.mechanics = const {},
    this.statusBonus = const {},
    this.lifeSteal = 0,
    this.regenPerTurn = 0,
    this.statusResist = 0,
    this.healReceived = 0,
    this.breakdown = const {},
  });
}
