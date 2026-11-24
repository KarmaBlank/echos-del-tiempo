import '../data/cooking_catalog.dart';

/// The meal a player ate (farming.md § 17): its recipe, quality and the
/// missions it still lasts. Each player has their own (coop). JSON `mb`
/// inside `farm`, and `meal` inside a battle build (HUD).
class MealBuff {
  const MealBuff(this.meal, this.quality, this.left);

  final String meal;
  final CropQuality quality;

  /// Missions left (≥ 1 while active).
  final int left;

  MealDef? get def => kMeals[meal];

  MealBuff withLeft(int n) => MealBuff(meal, quality, n);

  Map<String, Object?> toJson() => {'m': meal, 'q': quality.index, 'n': left};

  static MealBuff? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw['m'], q = raw['q'], n = raw['n'];
    if (m is! String || !kMeals.containsKey(m) || q is! num || n is! num) {
      return null;
    }
    final qi = q.toInt();
    if (qi < 0 || qi >= CropQuality.values.length || n < 1) return null;
    return MealBuff(m, CropQuality.values[qi], n.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is MealBuff &&
      other.meal == meal &&
      other.quality == quality &&
      other.left == left;

  @override
  int get hashCode => Object.hash(meal, quality, left);
}
