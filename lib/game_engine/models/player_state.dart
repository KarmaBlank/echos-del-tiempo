import 'attributes.dart';
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
    this.bonusDefense = 0,
  });

  PlayerBuild withBonusDefense(int value) => PlayerBuild(
        classId: classId,
        level: level,
        attributes: attributes,
        equippedWeapon: equippedWeapon,
        weaponUpgrades: weaponUpgrades,
        passiveProgress: passiveProgress,
        bonusDefense: value,
      );
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
  });
}
