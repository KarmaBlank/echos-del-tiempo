import 'dart:math' as math;

import '../data/cooking_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/meal_buff.dart';
import '../models/player_profile.dart';

export '../data/cooking_catalog.dart';
export '../models/meal_buff.dart';

/// Why a recipe can't be cooked right now.
enum CookBlock { unknown, crops, fish }

/// Cooking (docs/specs/farming.md § 17). Pure: the numbers come from
/// `kTuning[TuningId.farming]` (Editor → Balance → Cultivo).
abstract final class CookingRules {
  static TuningDef get t => tuning(TuningId.farming);

  /// Buff of [m] cooked at quality [q] (fraction): (base × qualityMult +
  /// perQuality × quality index) × the recipe power.
  static double buffValue(MealDef m, CropQuality q) => math.max(
      0,
      (t.d('mealBuffBase') * t.d('qualityMult${q.key}') +
              t.d('mealBuffPerQuality') * q.index) *
          m.power);

  static double buffOf(MealBuff b) =>
      b.def == null ? 0 : buffValue(b.def!, b.quality);

  /// Missions a meal lasts: `mealMissions`, +1 with fish (1–3 by default).
  static int missionsFor(MealDef m) =>
      math.max(1, t.i('mealMissions') + (m.hasFish ? 1 : 0));

  static CookBlock? cookBlock(PlayerProfile p, String id, CropQuality q) {
    final m = kMeals[id];
    if (m == null) return CookBlock.unknown;
    final f = p.life.farm;
    for (final e in m.crops.entries) {
      if (f.cropCount(cropKey(e.key, q)) < e.value) return CookBlock.crops;
    }
    for (final e in m.fish.entries) {
      if (p.life.count(e.key) < e.value) return CookBlock.fish;
    }
    return null;
  }

  /// Cooks one [id] with crops of quality [q] at the town pot.
  static PlayerProfile? cook(PlayerProfile p, String id, CropQuality q) {
    if (cookBlock(p, id, q) != null) return null;
    final m = kMeals[id]!;
    final f = p.life.farm;
    final crops = {...f.crops};
    for (final e in m.crops.entries) {
      final k = cropKey(e.key, q);
      crops[k] = (crops[k] ?? 0) - e.value;
    }
    var life = p.life;
    for (final e in m.fish.entries) {
      life = life.copyWith(bag: {...life.bag, e.key: life.count(e.key) - e.value});
    }
    final key = mealKey(id, q);
    final best = f.mealLog[id];
    final farm = f.copyWith(
        crops: crops,
        meals: {...f.meals, key: f.mealCount(key) + 1},
        mealLog: best != null && best >= q.index
            ? null
            : {...f.mealLog, id: q.index});
    return p.copyWith(life: life.copyWith(farm: farm));
  }

  /// Eats the meal [key]: replaces any active meal.
  static PlayerProfile? eat(PlayerProfile p, String key) {
    final pm = parseMealKey(key);
    final f = p.life.farm;
    if (pm == null || f.mealCount(key) < 1) return null;
    final farm = f.copyWith(
        meals: {...f.meals, key: f.mealCount(key) - 1},
        meal: MealBuff(pm.$1.id, pm.$2, missionsFor(pm.$1)));
    return p.copyWith(life: p.life.copyWith(farm: farm));
  }

  /// A mission ended (won or lost): one mission less of the meal.
  static PlayerProfile afterMission(PlayerProfile p) {
    final b = p.life.farm.meal;
    if (b == null) return p;
    final f = p.life.farm.copyWith(meal: b.left <= 1 ? null : b.withLeft(b.left - 1));
    return p.copyWith(life: p.life.copyWith(farm: f));
  }

  static double hp(MealBuff? b) =>
      b?.def?.stat == MealStat.hp ? buffOf(b!) : 0;
  static double atk(MealBuff? b) =>
      b?.def?.stat == MealStat.atk ? buffOf(b!) : 0;

  /// Fraction of [el] damage the meal blocks (capped at 0.9).
  static double resist(MealBuff? b, DamageTag el) {
    final d = b?.def;
    if (d == null || d.stat != MealStat.res || d.element != el) return 0;
    return buffOf(b!).clamp(0.0, 0.9);
  }
}
