import '../data/cooking_catalog.dart';

/// The meal a player ate (farming.md § 17): its recipe, quality and the
/// missions it still lasts. Each player has their own (coop). JSON `mb`
/// inside `farm`, and `meal` inside a battle build (HUD).
class MealBuff {
  const MealBuff(this.meal, this.quality, this.left,
      {this.boost = 0, this.atkPlus = 0});

  final String meal;
  final CropQuality quality;

  /// Missions left (≥ 1 while active).
  final int left;

  /// × (1 + [boost]) on the buff and its regen, from the eater's life
  /// trees when it was eaten (Mesa del pescador / Cocina sub-paths A,
  /// life_trees_v2.md § 2.1). JSON `b`.
  final double boost;

  /// ATK / MAG fraction a fish meal adds (Mesa del pescador sub-path B).
  /// JSON `a`.
  final double atkPlus;

  MealDef? get def => kMeals[meal];

  MealBuff withLeft(int n) =>
      MealBuff(meal, quality, n, boost: boost, atkPlus: atkPlus);

  static double _r(double v) => (v * 1000).roundToDouble() / 1000;

  Map<String, Object?> toJson() => {
        'm': meal,
        'q': quality.index,
        'n': left,
        if (boost > 0) 'b': _r(boost),
        if (atkPlus > 0) 'a': _r(atkPlus),
      };

  static MealBuff? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw['m'], q = raw['q'], n = raw['n'];
    if (m is! String || !kMeals.containsKey(m) || q is! num || n is! num) {
      return null;
    }
    final qi = q.toInt();
    if (qi < 0 || qi >= CropQuality.values.length || n < 1) return null;
    double d(Object? v) => v is num && v.isFinite && v > 0 ? v.toDouble() : 0;
    return MealBuff(m, CropQuality.values[qi], n.toInt(),
        boost: d(raw['b']), atkPlus: d(raw['a']));
  }

  @override
  bool operator ==(Object other) =>
      other is MealBuff &&
      other.meal == meal &&
      other.quality == quality &&
      other.left == left &&
      other.boost == boost &&
      other.atkPlus == atkPlus;

  @override
  int get hashCode => Object.hash(meal, quality, left, boost, atkPlus);
}
