import 'dart:math' as math;

import '../data/affixes_catalog.dart';
import '../data/ascension_catalog.dart';
import '../data/weapon_passives.dart';
import '../models/attributes.dart';
import '../models/class_def.dart';
import '../models/item.dart';
import '../models/player_state.dart';
import '../models/status.dart';
import '../models/weapon.dart';
import 'js_math.dart';
import 'passive_tree_rules.dart';

/// Puerto 1:1 de la función `stats(p)` del prototipo HTML, incluidos sus
/// redondeos intermedios — ver docs/specs/combat.md § "Cálculo de stats".
/// Loot v2 (docs/specs/loot.md § 12) agrega, en este orden: atributos de
/// los afijos → base del arma → implícito → afijos → forja → árbol. Sin
/// arma con mods los números son los de siempre.
/// Dart puro, sin Flutter: se testea con
/// `test/game_engine/stats_calculator_test.dart`.
class StatsCalculator {
  final Map<String, ClassDef> classes;
  final PassiveTreeRules treeRules;

  const StatsCalculator({required this.classes, required this.treeRules});

  /// Suma de implícito + afijos del arma, por estadística (puntos).
  static Map<ModStat, int> modTotals(WeaponDef w, ItemInstance? item) {
    final out = <ModStat, int>{};
    for (final m in w.implicit) {
      out[m.stat] = (out[m.stat] ?? 0) + m.value;
    }
    if (item != null) {
      for (final a in item.affixes) {
        final def = kAffixes[a.affixId];
        if (def == null) continue;
        out[def.stat] = (out[def.stat] ?? 0) + a.value;
      }
    }
    return out;
  }

  static String _n(num v) => v == v.roundToDouble()
      ? v.round().toString()
      : (v * 10).round() / 10 == v
          ? v.toString()
          : v.toStringAsFixed(1);

  static String _x(double v) => '× ${v.toStringAsFixed(2)}';

  DerivedStats calculate(PlayerBuild build) {
    final cls = classes[build.classId]!;
    final w = build.equippedWeapon;
    final up = build.forge;
    final mods = modTotals(w, build.item);
    int m(ModStat s) => mods[s] ?? 0;

    // Atributos de los afijos (no cuentan para los requisitos del arma).
    final attrMods = {
      Attribute.vit: m(ModStat.vit),
      Attribute.esp: m(ModStat.esp),
      Attribute.agi: m(ModStat.agi),
      Attribute.fue: m(ModStat.fue),
      Attribute.des: m(ModStat.des),
    };
    final s = attrMods.values.any((v) => v != 0)
        ? build.attributes.add(attrMods)
        : build.attributes;
    // Tope blando (progression_v2.md § 2.2): las fórmulas usan el valor
    // efectivo; los requisitos del arma miran el crudo.
    double e(Attribute a) => effectiveAttr(a, s[a]);

    final hpBase = jsRound(20 + e(Attribute.vit) * 4 + build.level * 2);
    final mpBase = jsRound(4 + e(Attribute.esp) * 1.5 + build.level);
    var maxHp = hpBase + m(ModStat.maxHp);
    var maxMp = mpBase + m(ModStat.maxMp);
    var speed = jsRound((6 +
                e(Attribute.agi) * 0.5 +
                e(Attribute.des) * 0.1 -
                w.weight +
                up.spd * WeaponUpgradeLevels.spdPer +
                m(ModStat.speed) * ModStat.speed.scale) *
            10) /
        10;
    var crit = math.min(
      0.6,
      0.03 +
          e(Attribute.des) * 0.012 +
          up.crit * WeaponUpgradeLevels.critPer +
          m(ModStat.critChance) * ModStat.critChance.scale,
    );
    final defense = cls.baseDefense +
        w.shieldDefense +
        build.bonusDefense +
        up.def +
        m(ModStat.defense);

    final powMult = 1 + WeaponUpgradeLevels.powPer * up.pow;
    final atkBase = w.atk.evaluateEffective(e);
    final atkFlat = m(ModStat.flatAtk);
    final atkPct = m(ModStat.atkPct) * ModStat.atkPct.scale;
    var attack = jsRound((atkBase + atkFlat) * (1 + atkPct) * powMult);
    // Sin fórmula de MAG, la magia copia al ataque (como el prototipo).
    final magFormula = w.mag;
    final magBase = (magFormula ?? w.atk).evaluateEffective(e);
    final magFlat = magFormula == null ? atkFlat : m(ModStat.flatMag);
    final magPct = magFormula == null
        ? atkPct
        : m(ModStat.magPct) * ModStat.magPct.scale;
    var magic = jsRound((magBase + magFlat) * (1 + magPct) * powMult);

    final tree = treeRules.aggregate(build.classId, build.passiveProgress);
    // Ascensión (docs/specs/ascension.md § 3): mecánicas y stats de sus
    // nodos (la raíz siempre, si la eligió).
    final ascMechanics = <String>{};
    final asc = kAscensions[build.ascension.id];
    if (asc != null && asc.classId == build.classId) {
      for (final id in [asc.rootId, ...build.ascension.nodes]) {
        final node = asc.node(id);
        if (node == null) continue;
        if (node.mechanicId case final m?) ascMechanics.add(m);
        node.stats.forEach((k, v) => tree.add(k, v.toDouble()));
      }
    }
    maxHp = math.max(1, jsRound(maxHp * (1 + tree['hp'])));
    maxMp = jsRound(maxMp * (1 + tree['mp']));
    attack = math.max(1, jsRound(attack * (1 + tree['atk'])));
    magic = math.max(1, jsRound(magic * (1 + tree['mag'])));
    final critBeforeTree = crit;
    crit = math.min(tree.critCap, crit + tree['crit']);
    speed = jsRound((speed + tree['spd']) * 10) / 10;
    final defenseTotal = math.max(0.0, defense + tree['def']);

    final item = build.item;
    final mechanics = {...tree.mechanics, ...ascMechanics};
    final passive = item?.passiveId;
    if (item != null && passive != null && item.rarity.hasPassive) {
      mechanics.addAll(
          weaponPassiveMechanicIds(passive, item.effectivePassiveLevel));
    }

    String treeStep(String key) =>
        tree[key] == 0 ? '' : _x(1 + tree[key]);
    List<String> clean(List<String> l) => [for (final x in l) if (x.isNotEmpty) x];
    final breakdown = <String, StatBreakdown>{
      'ATQ': StatBreakdown('ATQ', attack, clean([
        'base ${_n(atkBase)}',
        if (atkFlat != 0) '+ $atkFlat plano',
        if (atkPct != 0) '${_x(1 + atkPct)} afijos',
        if (up.pow > 0) '${_x(powMult)} forja',
        if (tree['atk'] != 0) '${treeStep('atk')} árbol',
      ])),
      'MAG': StatBreakdown('MAG', magic, clean([
        'base ${_n(magBase)}',
        if (magFlat != 0) '+ $magFlat plano',
        if (magPct != 0) '${_x(1 + magPct)} afijos',
        if (up.pow > 0) '${_x(powMult)} forja',
        if (tree['mag'] != 0) '${treeStep('mag')} árbol',
      ])),
      'HP': StatBreakdown('HP', maxHp, clean([
        'base $hpBase',
        if (m(ModStat.maxHp) != 0) '+ ${m(ModStat.maxHp)} afijos',
        if (tree['hp'] != 0) '${treeStep('hp')} árbol',
      ])),
      'MP': StatBreakdown('MP', maxMp, clean([
        'base $mpBase',
        if (m(ModStat.maxMp) != 0) '+ ${m(ModStat.maxMp)} afijos',
        if (tree['mp'] != 0) '${treeStep('mp')} árbol',
      ])),
      'VEL': StatBreakdown('VEL', speed, clean([
        'base ${_n(6 + e(Attribute.agi) * 0.5 + e(Attribute.des) * 0.1)}',
        if (w.weight != 0) '− ${_n(w.weight)} peso',
        if (m(ModStat.speed) != 0)
          '+ ${_n(m(ModStat.speed) * ModStat.speed.scale)} afijos',
        if (up.spd > 0) '+ ${_n(up.spd * WeaponUpgradeLevels.spdPer)} forja',
        if (tree['spd'] != 0) '+ ${_n(tree['spd'])} árbol',
      ])),
      'CRIT': StatBreakdown('CRIT', jsRound(crit * 100), clean([
        'base ${jsRound((0.03 + e(Attribute.des) * 0.012) * 100)}%',
        if (m(ModStat.critChance) != 0) '+ ${m(ModStat.critChance)}% afijos',
        if (up.crit > 0)
          '+ ${jsRound(up.crit * WeaponUpgradeLevels.critPer * 100)}% forja',
        if (tree['crit'] != 0) '+ ${jsRound(tree['crit'] * 100)}% árbol',
        if (critBeforeTree >= 0.6) '(tope 60% sin árbol)',
      ])),
      'DEF': StatBreakdown('DEF', jsRound(defenseTotal), clean([
        'clase ${cls.baseDefense}',
        if (w.shieldDefense != 0) '+ ${w.shieldDefense} escudo',
        if (m(ModStat.defense) != 0) '+ ${m(ModStat.defense)} afijos',
        if (up.def > 0) '+ ${up.def} forja',
        if (build.bonusDefense != 0) '+ ${build.bonusDefense} batalla',
        if (tree['def'] != 0) '+ ${_n(tree['def'])} árbol',
      ])),
    };

    return DerivedStats(
      maxHp: maxHp,
      maxMp: maxMp,
      speed: speed,
      critChance: crit,
      critMultiplier: (tree.hasKey('halcon') ? 2.0 : 1.5) +
          m(ModStat.critMulti) * ModStat.critMulti.scale,
      defense: jsRound(defenseTotal),
      defensePercent: math.min(0.6, defenseTotal * 0.03),
      attack: attack,
      magic: magic,
      ultChargeBonus: tree['ult'] + m(ModStat.ultCharge) * ModStat.ultCharge.scale,
      healBonus: tree['heal'] + m(ModStat.healPower) * ModStat.healPower.scale,
      keystones: tree.keys,
      mechanics: mechanics,
      statusBonus: {
        StatusKind.burn: tree['burn'].toInt() + m(ModStat.burnStacks),
        StatusKind.poison: tree['poi'].toInt() + m(ModStat.poisonStacks),
        StatusKind.freeze: tree['frz'].toInt() + m(ModStat.freezeStacks),
      },
      lifeSteal: m(ModStat.lifeSteal) * ModStat.lifeSteal.scale,
      regenPerTurn: m(ModStat.regen) * ModStat.regen.scale,
      statusResist: m(ModStat.statusResist),
      healReceived: m(ModStat.healReceived) * ModStat.healReceived.scale,
      breakdown: breakdown,
    );
  }
}
