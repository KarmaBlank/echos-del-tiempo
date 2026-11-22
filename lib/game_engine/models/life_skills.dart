import '../data/fishing_catalog.dart';
import 'farm_skills.dart';

export 'farm_skills.dart';

/// Habilidades de vida del personaje (town_loop.md § 11c, fishing.md § 3):
/// Pesca (XP total; el nivel sale de la curva), cañas, la bolsa de
/// Pescados y el pity de legendarios. JSON `life` del perfil.
class LifeSkills {
  LifeSkills({
    this.fishXp = 0,
    List<String> rods = const [kStarterRod],
    String? rod,
    Map<String, int> bag = const {},
    this.pity = 0,
    this.dry = 0,
    FarmSkills? farm,
    List<String> fishTree = const [],
  })  : farm = farm ?? FarmSkills.initial,
        fishTree = List.unmodifiable(fishTree.toSet()),
        rods = List.unmodifiable(
            {kStarterRod, ...rods.where(kRods.containsKey)}),
        rod = rod != null && kRods.containsKey(rod) &&
                (rods.contains(rod) || rod == kStarterRod)
            ? rod
            : kStarterRod,
        bag = Map.unmodifiable({
          for (final e in bag.entries)
            if (e.value > 0 &&
                kFish.containsKey(e.key) &&
                e.key != kWaterBundle)
              e.key: e.value,
        });

  /// Todo personaje nuevo o migrado: caña de rama equipada.
  static final initial = LifeSkills();

  /// XP total de Pesca.
  final int fishXp;

  /// Cañas propias (siempre incluye la de rama) y la equipada (espacio de
  /// herramienta, aparte de las armas).
  final List<String> rods;
  final String rod;

  /// Bolsa de Pescados: especie → cantidad (apilable).
  final Map<String, int> bag;

  /// Capturas sin legendario desde el último (fishing.md § 2.3).
  final int pity;

  /// Capturas sin cofre ni arma del agua (pity del botín, fishing.md § 8).
  final int dry;

  /// Cultivo (farming.md § 3).
  final FarmSkills farm;

  /// Nodos tomados del árbol de Pesca (life_skill_trees.md).
  final List<String> fishTree;

  int count(String species) => bag[species] ?? 0;
  int get bagTotal => bag.values.fold(0, (a, b) => a + b);

  LifeSkills copyWith({
    int? fishXp,
    List<String>? rods,
    String? rod,
    Map<String, int>? bag,
    int? pity,
    int? dry,
    FarmSkills? farm,
    List<String>? fishTree,
  }) =>
      LifeSkills(
          fishXp: fishXp ?? this.fishXp,
          rods: rods ?? this.rods,
          rod: rod ?? this.rod,
          bag: bag ?? this.bag,
          pity: pity ?? this.pity,
          dry: dry ?? this.dry,
          farm: farm ?? this.farm,
          fishTree: fishTree ?? this.fishTree);

  LifeSkills addFish(String species, [int n = 1]) =>
      copyWith(bag: {...bag, species: count(species) + n});

  Map<String, Object?> toJson() => {
        if (fishXp > 0) 'fx': fishXp,
        'rods': rods,
        'rod': rod,
        if (bag.isNotEmpty) 'bag': bag,
        if (pity > 0) 'pity': pity,
        if (dry > 0) 'dry': dry,
        'farm': farm.toJson(),
        if (fishTree.isNotEmpty) 'ft': fishTree,
      };

  /// Tolerante; sin `life` (saves de antes de v0.22.0) → [initial]: así
  /// todo personaje recibe la caña de rama.
  static LifeSkills fromJson(Object? raw) {
    if (raw is! Map) return initial;
    int n(Object? v) => v is num && v.isFinite ? v.truncate() : 0;
    final rods = raw['rods'];
    final bag = raw['bag'];
    return LifeSkills(
      fishXp: n(raw['fx']),
      rods: rods is List ? [for (final r in rods) if (r is String) r] : const [],
      rod: raw['rod'] is String ? raw['rod'] as String : null,
      bag: bag is Map
          ? {for (final e in bag.entries) '${e.key}': n(e.value)}
          : const {},
      pity: n(raw['pity']),
      dry: n(raw['dry']),
      farm: FarmSkills.fromJson(raw['farm']),
      fishTree: raw['ft'] is List
          ? [for (final x in raw['ft'] as List) if (x is String) x]
          : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LifeSkills &&
      other.fishXp == fishXp &&
      other.rod == rod &&
      other.pity == pity &&
      other.dry == dry &&
      other.farm == farm &&
      other.fishTree.join(',') == fishTree.join(',') &&
      other.rods.join(',') == rods.join(',') &&
      other.bag.length == bag.length &&
      bag.entries.every((e) => other.bag[e.key] == e.value);

  @override
  int get hashCode => Object.hash(fishXp, rod, pity, rods.length, bag.length);
}
