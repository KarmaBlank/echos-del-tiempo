import '../models/attributes.dart';
import '../models/class_def.dart';
import '../models/player_state.dart';
import '../models/weapon.dart';
import 'passive_tree_rules.dart';

/// Puerto 1:1 de la función `stats(p)` del prototipo HTML — ver
/// docs/specs/combat.md § "Cálculo de stats" para la fórmula de
/// referencia exacta. Dart puro, sin Flutter: se testea con
/// `test/game_engine/stats_calculator_test.dart` comparando contra los
/// mismos casos que se verificaron a mano en el prototipo.
class StatsCalculator {
  final Map<String, ClassDef> classes;
  final PassiveTreeRules treeRules;

  const StatsCalculator({required this.classes, required this.treeRules});

  DerivedStats calculate(PlayerBuild build) {
    final s = build.attributes;
    final cls = classes[build.classId]!;
    final w = build.equippedWeapon;
    final up = build.weaponUpgrades;

    double maxHp = 20 + s[Attribute.vit] * 4 + build.level * 2;
    double maxMp = 4 + s[Attribute.esp] * 1.5 + build.level;
    double speed = 6 +
        s[Attribute.agi] * 0.5 +
        s[Attribute.des] * 0.1 -
        w.weight +
        up.spd * WeaponUpgradeLevels.spdPer;
    double crit = 0.03 + s[Attribute.des] * 0.012 + up.crit * WeaponUpgradeLevels.critPer;
    double defense =
        cls.baseDefense + w.shieldDefense + up.def * WeaponUpgradeLevels.defPer;

    final double powMult = 1 + WeaponUpgradeLevels.powPer * up.pow;
    double attack = w.atk.evaluate(s) * powMult;
    double magic = (w.mag ?? w.atk).evaluate(s) * powMult;

    final mods = treeRules.aggregate(build.classId, build.passiveProgress);
    maxHp = _clampMin1(maxHp * (1 + mods['hp']));
    maxMp = maxMp * (1 + mods['mp']);
    attack = _clampMin1(attack * (1 + mods['atk']));
    magic = _clampMin1(magic * (1 + mods['mag']));
    crit = (crit + mods['crit']).clamp(0, 0.75).toDouble();
    speed = speed + mods['spd'];
    defense = (defense + mods['def']).clamp(0, double.infinity).toDouble();

    final defensePercent = (defense * 0.03).clamp(0, 0.6).toDouble();
    final critMultiplier = mods.hasKey('halcon') ? 2.0 : 1.5;

    return DerivedStats(
      maxHp: maxHp.round(),
      maxMp: maxMp.round(),
      speed: (speed * 10).round() / 10,
      critChance: crit,
      critMultiplier: critMultiplier,
      defense: defense.round(),
      defensePercent: defensePercent,
      attack: attack.round(),
      magic: magic.round(),
      ultChargeBonus: mods['ult'],
      healBonus: mods['heal'],
      keystones: mods.keys,
    );
  }

  double _clampMin1(double v) => v < 1 ? 1 : v;
}
