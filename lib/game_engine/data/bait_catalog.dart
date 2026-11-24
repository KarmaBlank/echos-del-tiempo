// Baits (docs/specs/fishing.md § 14, v0.44.0). Pure data: `BaitRules`
// reads it. Numbers (bite, rarity, size, price, recipe gold) live in
// `kTuning[fishing]` as `bait<Key>*` (Editor → Balance → Pesca and the
// CEBOS subtab of CLIMA). The crafted base is the trade material
// "Cebo prensado" (`cebo`, kLifeMaterialIds).

import 'fishing_catalog.dart';

/// A bait: what it attracts and how to craft it.
class BaitDef {
  const BaitDef(this.id, this.name, this.key, this.rarity,
      {this.species = const {},
      this.weather,
      this.season,
      this.attractsRarity,
      required this.recipe});

  final String id;
  final String name;

  /// Tuning key suffix (`baitLombrizBite`, …).
  final String key;
  final FishRarity rarity;

  /// Affinity (§ 14.2): these species, fish that need [weather], fish of
  /// [season] (seasonal ones) or fish of [attractsRarity].
  final Set<String> species;
  final Weather? weather;
  final Season? season;
  final FishRarity? attractsRarity;

  /// Craft: pressed bait (`cebo`) + one bag item → [BaitRecipe.yield].
  final BaitRecipe recipe;
}

/// Recipe of a bait in the trade workshop: [cebo] pressed baits, plus
/// [n] of [item] (a fish id from the fish bag or a crop key `id@0` from
/// the harvest bag; `null` = none) and `bait<Key>Gold` gold.
class BaitRecipe {
  const BaitRecipe({this.cebo = 1, this.item, this.n = 0, this.yield = 1});
  final int cebo;
  final String? item;
  final int n;
  final int yield;
}

const kBaits = <String, BaitDef>{
  'lombriz': BaitDef('lombriz', 'Lombriz común', 'Lombriz', FishRarity.comun,
      attractsRarity: FishRarity.comun,
      recipe: BaitRecipe(cebo: 1, yield: 4)),
  'larva_brillante': BaitDef(
      'larva_brillante', 'Larva brillante', 'Larva', FishRarity.raro,
      weather: Weather.fog,
      recipe: BaitRecipe(cebo: 1, item: 'hongo_ambar@0', n: 1, yield: 2)),
  'cebo_escarcha': BaitDef(
      'cebo_escarcha', 'Cebo de escarcha', 'Escarcha', FishRarity.raro,
      season: Season.winter,
      weather: Weather.snow,
      recipe: BaitRecipe(cebo: 1, item: 'cristal_escarcha@0', n: 1, yield: 2)),
  'cebo_tormenta': BaitDef(
      'cebo_tormenta', 'Cebo de tormenta', 'Tormenta', FishRarity.epico,
      weather: Weather.tormenta,
      recipe: BaitRecipe(cebo: 2, item: 'pez_ceniza', n: 1, yield: 2)),
  'senuelo_eco': BaitDef(
      'senuelo_eco', 'Señuelo del eco', 'Eco', FishRarity.legendario,
      attractsRarity: FishRarity.legendario,
      recipe: BaitRecipe(cebo: 3, item: 'pez_eco', n: 1, yield: 1)),
};

/// i18n key of a bait's name.
String baitNameKey(String id) => 'data.materials.bait.$id.name';

/// Bait ids from worst to best (catalog order).
List<String> get kBaitOrder => kBaits.keys.toList();

