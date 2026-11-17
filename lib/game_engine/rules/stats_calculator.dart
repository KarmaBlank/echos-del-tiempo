import 'dart:math' as math;

import '../models/attributes.dart';
import '../models/class_def.dart';
import '../models/player_state.dart';
import '../models/status.dart';
import '../models/weapon.dart';
import 'js_math.dart';
import 'passive_tree_rules.dart';

/// Puerto 1:1 de la función `stats(p)` del prototipo HTML, incluidos sus
/// redondeos intermedios — ver docs/specs/combat.md § "Cálculo de stats".
/// Dart puro, sin Flutter: se testea con
/// `test/game_engine/stats_calculator_test.dart`.
class StatsCalculator {
  final Map<String, ClassDef> classes;
  final PassiveTreeRules treeRules;

  const StatsCalculator({required this.classes, required this.treeRules});

  DerivedStats calculate(PlayerBuild build) {
    final s = build.attributes;
    final cls = classes[build.classId]!;
    final w = build.equippedWeapon;
    final up = build.weaponUpgrades;

    var maxHp = jsRound(20 + s[Attribute.vit] * 4 + build.level * 2);
    var maxMp = jsRound(4 + s[Attribute.esp] * 1.5 + build.level);
    var speed = jsRound((6 +
                s[Attribute.agi] * 0.5 +
                s[Attribute.des] * 0.1 -
                w.weight +
                up.spd * WeaponUpgradeLevels.spdPer) *
            10) /
        10;
    var crit = math.min(
      0.6,
      0.03 + s[Attribute.des] * 0.012 + up.crit * WeaponUpgradeLevels.critPer,
    );
    final defense =
        cls.baseDefense + w.shieldDefense + build.bonusDefense + up.def;

    final powMult = 1 + WeaponUpgradeLevels.powPer * up.pow;
    var attack = jsRound(w.atk.evaluate(s) * powMult);
    var magic = jsRound((w.mag ?? w.atk).evaluate(s) * powMult);

    final mods = treeRules.aggregate(build.classId, build.passiveProgress);
    maxHp = math.max(1, jsRound(maxHp * (1 + mods['hp'])));
    maxMp = jsRound(maxMp * (1 + mods['mp']));
    attack = math.max(1, jsRound(attack * (1 + mods['atk'])));
    magic = math.max(1, jsRound(magic * (1 + mods['mag'])));
    crit = math.min(mods.critCap, crit + mods['crit']);
    speed = jsRound((speed + mods['spd']) * 10) / 10;
    final defenseTotal = math.max(0.0, defense + mods['def']);

    return DerivedStats(
      maxHp: maxHp,
      maxMp: maxMp,
      speed: speed,
      critChance: crit,
      critMultiplier: mods.hasKey('halcon') ? 2.0 : 1.5,
      defense: jsRound(defenseTotal),
      defensePercent: math.min(0.6, defenseTotal * 0.03),
      attack: attack,
      magic: magic,
      ultChargeBonus: mods['ult'],
      healBonus: mods['heal'],
      keystones: mods.keys,
      mechanics: mods.mechanics,
      statusBonus: {
        StatusKind.burn: mods['burn'].toInt(),
        StatusKind.poison: mods['poi'].toInt(),
        StatusKind.freeze: mods['frz'].toInt(),
      },
    );
  }
}
