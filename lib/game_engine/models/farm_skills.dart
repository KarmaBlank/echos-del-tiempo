import '../data/cooking_catalog.dart';
import '../data/cozy_catalog.dart' show kCompostRecipes;
import '../data/farming_catalog.dart';
import '../data/life_tree_catalog.dart';
import 'meal_buff.dart';

export 'meal_buff.dart';

/// Cultivo del personaje (farming.md § 3): XP, azadas y regaderas, la
/// semilla elegida, semillas, cosechas (por calidad), abono y los pity.
/// JSON `farm` dentro de `life` del perfil.
class FarmSkills {
  FarmSkills({
    this.xp = 0,
    List<String> hoes = const [kStarterHoe],
    String? hoe,
    List<String> cans = const [kStarterCan],
    String? can,
    Map<String, int> seeds = const {},
    Map<String, int> crops = const {},
    Map<String, int>? cropLog,
    String? seed,
    Map<String, int> ferts = const {},
    this.pity = 0,
    this.dry = 0,
    List<String> tree = const [],
    Map<String, int> meals = const {},
    Map<String, int> mealLog = const {},
    this.meal,
    Set<String> recipes = const {},
  })  : recipes = Set.unmodifiable(recipes.where(kCompostRecipes.containsKey)),
        meals = Map.unmodifiable({
          for (final e in meals.entries)
            if (e.value > 0 && parseMealKey(e.key) != null) e.key: e.value,
        }),
        mealLog = Map.unmodifiable({
          for (final e in mealLog.entries)
            if (kMeals.containsKey(e.key)) e.key: e.value.clamp(0, 3),
        }),
        tree = List.unmodifiable(tree.toSet()),
        hoes = List.unmodifiable({kStarterHoe, ...hoes.where(_isHoe)}),
        cans = List.unmodifiable({kStarterCan, ...cans.where(_isCan)}),
        hoe = hoe != null && _isHoe(hoe) && hoes.contains(hoe) ? hoe : kStarterHoe,
        can = can != null && _isCan(can) && cans.contains(can) ? can : kStarterCan,
        seeds = Map.unmodifiable({
          for (final e in seeds.entries)
            if (e.value > 0 && kCrops.containsKey(e.key)) e.key: e.value,
        }),
        crops = Map.unmodifiable({
          for (final e in crops.entries)
            if (e.value > 0 && parseCropKey(e.key) != null) e.key: e.value,
        }),
        cropLog = Map.unmodifiable(_logOf(cropLog, crops)),
        ferts = Map.unmodifiable({
          for (final e in ferts.entries)
            if (e.value > 0 && kFertilizers.containsKey(e.key)) e.key: e.value,
        }),
        seed = seed != null && kCrops.containsKey(seed) ? seed : null;

  /// The crop log, or (old saves without one) the crops in the bag.
  static Map<String, int> _logOf(
      Map<String, int>? log, Map<String, int> crops) {
    final out = <String, int>{
      for (final e in (log ?? const {}).entries)
        if (kCrops.containsKey(e.key)) e.key: e.value.clamp(0, 3),
    };
    for (final e in crops.entries) {
      if (e.value <= 0) continue;
      final pc = parseCropKey(e.key);
      if (pc == null) continue;
      final q = pc.$2.index;
      if ((out[pc.$1.id] ?? -1) < q) out[pc.$1.id] = q;
    }
    return out;
  }

  static bool _isHoe(String id) => kFarmTools[id]?.kind == FarmToolKind.azada;
  static bool _isCan(String id) =>
      kFarmTools[id]?.kind == FarmToolKind.regadera;

  /// Todo personaje nuevo o migrado: azada de rama y regadera de lata y
  /// un puñado de nabos para arrancar.
  /// Compost recipes found searching trees (cozy_life.md § 3). JSON `rc`.
  final Set<String> recipes;

  static final initial = FarmSkills(seeds: const {'nabo_claro': 6});

  final int xp;
  final List<String> hoes, cans;
  final String hoe, can;

  /// Semillas: cultivo → cantidad.
  final Map<String, int> seeds;

  /// Cosechas: `cropKey(cultivo, calidad)` → cantidad.
  final Map<String, int> crops;

  /// COLECCIÓN de Cultivo (weather_seasons.md § 7): crop id → best
  /// quality ever harvested (index of `CropQuality`). Migrated from the
  /// bag on old saves.
  final Map<String, int> cropLog;
  bool cropDiscovered(String id) => cropLog.containsKey(id);

  /// Semilla elegida para plantar (`null` = la primera que haya).
  final String? seed;

  /// Bolsas de abono por tipo (`kFertilizers`).
  final Map<String, int> ferts;
  int fertCount(String id) => ferts[id] ?? 0;

  /// Cosechas sin semilla legendaria desde la última (farming.md § 5).
  final int pity;

  /// Cosechas sin hallazgo especial (pity del botín de la huerta).
  final int dry;

  /// Nodos tomados del árbol de Cultivo (life_skill_trees.md).
  final List<String> tree;

  /// Cooked meals (farming.md § 17): `mealKey(meal, quality)` → count.
  final Map<String, int> meals;
  int mealCount(String key) => meals[key] ?? 0;

  /// Cocina collection: meal id → best quality ever cooked.
  final Map<String, int> mealLog;

  /// The meal eaten and still active (`null` = none).
  final MealBuff? meal;

  int seedCount(String id) => seeds[id] ?? 0;
  int cropCount(String key) => crops[key] ?? 0;
  int get cropTotal => crops.values.fold(0, (a, b) => a + b);
  int get seedTotal => seeds.values.fold(0, (a, b) => a + b);

  /// La semilla con que se planta: la elegida si queda, si no la primera.
  String? get activeSeed {
    if (seed != null && seedCount(seed!) > 0) return seed;
    for (final c in kCrops.keys) {
      if (seedCount(c) > 0) return c;
    }
    return null;
  }

  FarmSkills copyWith({
    int? xp,
    List<String>? hoes,
    String? hoe,
    List<String>? cans,
    String? can,
    Map<String, int>? seeds,
    Map<String, int>? crops,
    Map<String, int>? cropLog,
    String? seed,
    Map<String, int>? ferts,
    int? pity,
    int? dry,
    List<String>? tree,
    Map<String, int>? meals,
    Map<String, int>? mealLog,
    Object? meal = _keep,
    Set<String>? recipes,
  }) =>
      FarmSkills(
          recipes: recipes ?? this.recipes,
          xp: xp ?? this.xp,
          hoes: hoes ?? this.hoes,
          hoe: hoe ?? this.hoe,
          cans: cans ?? this.cans,
          can: can ?? this.can,
          seeds: seeds ?? this.seeds,
          crops: crops ?? this.crops,
          cropLog: cropLog ?? this.cropLog,
          seed: seed ?? this.seed,
          ferts: ferts ?? this.ferts,
          pity: pity ?? this.pity,
          dry: dry ?? this.dry,
          tree: tree ?? this.tree,
          meals: meals ?? this.meals,
          mealLog: mealLog ?? this.mealLog,
          meal: identical(meal, _keep) ? this.meal : meal as MealBuff?);

  static const _keep = Object();

  FarmSkills addSeed(String id, [int n = 1]) =>
      copyWith(seeds: {...seeds, id: seedCount(id) + n});
  FarmSkills addCrop(String key, [int n = 1]) =>
      copyWith(crops: {...crops, key: cropCount(key) + n});

  Map<String, Object?> toJson() => {
        if (xp > 0) 'xp': xp,
        'hoes': hoes,
        'hoe': hoe,
        'cans': cans,
        'can': can,
        if (seeds.isNotEmpty) 'seeds': seeds,
        if (crops.isNotEmpty) 'crops': crops,
        if (cropLog.isNotEmpty) 'cl': cropLog,
        if (seed != null) 'sd': seed,
        if (ferts.isNotEmpty) 'ferts': ferts,
        if (pity > 0) 'pity': pity,
        if (dry > 0) 'dry': dry,
        if (tree.isNotEmpty) 'tree': tree,
        if (meals.isNotEmpty) 'ml': meals,
        if (mealLog.isNotEmpty) 'mlg': mealLog,
        if (meal != null) 'mb': meal!.toJson(),
        if (recipes.isNotEmpty) 'rc': [...recipes]..sort(),
      };

  /// Tolerante; sin `farm` (saves de antes de v0.23.0) → [initial].
  static FarmSkills fromJson(Object? raw) {
    if (raw is! Map) return initial;
    int n(Object? v) => v is num && v.isFinite ? v.truncate() : 0;
    List<String> l(Object? v) =>
        v is List ? [for (final x in v) if (x is String) x] : const [];
    Map<String, int> m(Object? v) => v is Map
        ? {for (final e in v.entries) '${e.key}': n(e.value)}
        : const {};
    return FarmSkills(
      xp: n(raw['xp']),
      hoes: l(raw['hoes']),
      hoe: raw['hoe'] is String ? raw['hoe'] as String : null,
      cans: l(raw['cans']),
      can: raw['can'] is String ? raw['can'] as String : null,
      seeds: m(raw['seeds']),
      crops: m(raw['crops']),
      cropLog: raw['cl'] is Map ? m(raw['cl']) : null,
      seed: raw['sd'] is String ? raw['sd'] as String : null,
      ferts: m(raw['ferts']),
      pity: n(raw['pity']),
      dry: n(raw['dry']),
      // life_trees_v2.md § 6: v1 ids are dropped (full refund).
      tree: [
        for (final x in l(raw['tree']))
          if (isLifeTreeNode(LifeSkillKind.cultivo, x)) x
      ],
      meals: m(raw['ml']),
      mealLog: m(raw['mlg']),
      meal: MealBuff.fromJson(raw['mb']),
      recipes: {...l(raw['rc'])},
    );
  }

  static bool _mapEq(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  @override
  bool operator ==(Object other) =>
      other is FarmSkills &&
      other.xp == xp &&
      other.hoe == hoe &&
      other.can == can &&
      other.seed == seed &&
      _mapEq(other.ferts, ferts) &&
      other.pity == pity &&
      other.dry == dry &&
      other.tree.join(',') == tree.join(',') &&
      other.hoes.join(',') == hoes.join(',') &&
      other.cans.join(',') == cans.join(',') &&
      _mapEq(other.seeds, seeds) &&
      _mapEq(other.crops, crops) &&
      _mapEq(other.cropLog, cropLog) &&
      _mapEq(other.meals, meals) &&
      _mapEq(other.mealLog, mealLog) &&
      other.meal == meal &&
      other.recipes.length == recipes.length &&
      other.recipes.containsAll(recipes);

  @override
  int get hashCode => Object.hash(xp, hoe, can, seeds.length, crops.length);
}
