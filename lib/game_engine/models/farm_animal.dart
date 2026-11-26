import '../data/animals_catalog.dart';
import '../data/farming_catalog.dart' show CropQuality;

/// A farm animal living in a coop or a barn (animals.md § 4.2).
/// Immutable; travels inside its `TownBuild` (JSON `an`).
class FarmAnimal {
  const FarmAnimal(this.uid, this.species,
      {this.aff = 0, this.fed = 0, this.pet = 0, this.cycle = 0, this.ready});

  /// Number of the animal in its building (stable; picks its name).
  final int uid;
  final String species;

  /// Affection points (0 … `affMax`; 100 = one heart).
  final int aff;

  /// Last world day it ate / was petted (0 = never).
  final int fed, pet;

  /// Fed days accumulated toward the next product.
  final int cycle;

  /// Product waiting to be collected (its quality), or `null`.
  final CropQuality? ready;

  AnimalDef get def => kAnimals[species]!;

  int get hearts => aff ~/ 100;

  FarmAnimal copyWith(
          {int? aff,
          int? fed,
          int? pet,
          int? cycle,
          CropQuality? ready,
          bool clearReady = false}) =>
      FarmAnimal(uid, species,
          aff: aff ?? this.aff,
          fed: fed ?? this.fed,
          pet: pet ?? this.pet,
          cycle: cycle ?? this.cycle,
          ready: clearReady ? null : (ready ?? this.ready));

  Map<String, Object?> toJson() => {
        'u': uid,
        's': species,
        if (aff > 0) 'a': aff,
        if (fed > 0) 'f': fed,
        if (pet > 0) 'p': pet,
        if (cycle > 0) 'c': cycle,
        if (ready != null) 'r': ready!.index,
      };

  /// Tolerant: unknown species → `null` (dropped on load).
  static FarmAnimal? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final s = raw['s'];
    if (s is! String || !kAnimals.containsKey(s)) return null;
    int n(Object? v, [int max = 1 << 30]) =>
        v is num && v.isFinite ? v.round().clamp(0, max) : 0;
    final r = raw['r'];
    return FarmAnimal(n(raw['u'], 9999), s,
        aff: n(raw['a'], 100000),
        fed: n(raw['f']),
        pet: n(raw['p']),
        cycle: n(raw['c'], 30),
        // Never legendary (animals.md § 1).
        ready: r is num && r >= 0 && r < CropQuality.legendario.index
            ? CropQuality.values[r.round()]
            : null);
  }

  @override
  bool operator ==(Object other) =>
      other is FarmAnimal &&
      other.uid == uid &&
      other.species == species &&
      other.aff == aff &&
      other.fed == fed &&
      other.pet == pet &&
      other.cycle == cycle &&
      other.ready == ready;

  @override
  int get hashCode => Object.hash(uid, species, aff, fed, pet, cycle, ready);
}

/// Bag key of an animal product: `<product>@<quality index>`.
String animalGoodsKey(String product, CropQuality q) => '$product@${q.index}';

/// (product, quality) of a bag key; `null` if invalid.
(AnimalProductDef, CropQuality)? parseAnimalGoodsKey(String key) {
  final i = key.lastIndexOf('@');
  if (i <= 0) return null;
  final d = kAnimalProducts[key.substring(0, i)];
  final q = int.tryParse(key.substring(i + 1));
  if (d == null || q == null || q < 0 || q >= CropQuality.values.length) {
    return null;
  }
  return (d, CropQuality.values[q]);
}
