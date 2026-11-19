import '../data/skills_catalog.dart';
import '../models/battle_state.dart';
import '../models/item.dart';
import '../models/skill.dart';
import '../models/weapon.dart';
import 'stats_calculator.dart';

/// Quién puede quebrar (combo_balance.md § 5.3, v0.9.1). Dart puro.
///
/// Una habilidad quiebra a un Fisurado si tiene `breaks` ("Puede
/// quebrar") o si es la habilidad principal de un arma con el afijo
/// Quebrantador (`ModStat.breakSkill`).
abstract final class BreakRules {
  /// La habilidad a la que el afijo Quebrantador de [w] le da "Puede
  /// quebrar": la primera de daño a un objetivo de la base que todavía no
  /// quiebra; si no hay, la primera de daño que no quiebra; si no, la
  /// primera de daño. `null` si la base no tiene habilidades de daño.
  static String? modSkillOf(WeaponDef w,
      [Map<String, SkillDef> skills = kSkills]) {
    final dmg = [
      for (final id in w.skillIds)
        if (skills[id] case final sk? when sk.dealsDamage && sk.charge <= 0)
          sk,
    ];
    for (final sk in dmg) {
      if (!sk.breaks && !sk.allTargets) return sk.id;
    }
    for (final sk in dmg) {
      if (!sk.breaks) return sk.id;
    }
    return dmg.firstOrNull?.id;
  }

  /// [w] + [item] tienen el afijo Quebrantador.
  static bool hasBreakMod(WeaponDef w, ItemInstance? item) =>
      (StatsCalculator.modTotals(w, item)[ModStat.breakSkill] ?? 0) > 0;

  /// [sk] puede quebrar en manos de [c] (su arma y sus afijos).
  static bool canBreak(SkillDef sk, Combatant c,
      [Map<String, SkillDef> skills = kSkills]) {
    if (sk.breaks) return true;
    final b = c.build;
    if (b == null) return false;
    final w = b.equippedWeapon;
    return hasBreakMod(w, b.item) && modSkillOf(w, skills) == sk.id;
  }
}
