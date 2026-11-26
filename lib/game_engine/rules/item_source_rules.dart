// Where an item is obtained or made (docs/specs/item_sources.md). Pure
// data derived from the catalogs: the UI turns each [ItemSource] into a
// translated line (item tooltips, cost grids).

import '../data/bait_catalog.dart';
import '../data/biomes_catalog.dart';
import '../data/cooking_catalog.dart';
import '../data/cozy_catalog.dart' show kCompostRecipes;
import '../data/farming_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/mine_catalog.dart' show mineTool;
import '../data/smithing_catalog.dart';
import '../models/player_profile.dart';
import 'life_craft_rules.dart' show kLifeMaterials;
import 'resident_rules.dart' show ResidentRules;

/// How an item is obtained.
enum ItemSourceKind {
  /// Sold at the farm shop (seeds, fertilizers, baits, mine supplies).
  farmShop,

  /// Sold at the crafts workshop's TOOLS tab (rods, hoes, cans, picks;
  /// town_loop.md § 2.1, v0.48.5).
  toolShop,

  /// Grown from its seed ([ItemSource.biome] = where the seed is from,
  /// [ItemSource.seasons] = when it grows).
  crop,

  /// Gathered at wild forage spots of [ItemSource.biome] (`null` = any
  /// biome; [ItemSource.seasons] = only in that season).
  forage,

  /// Fished at the lake of [ItemSource.biome] (`zona1` = town).
  fishing,

  /// Mined in the mine of [ItemSource.biome].
  mine,

  /// Found in dungeon ore veins.
  dungeonVein,

  /// Dropped by zone bosses.
  bossDrop,

  /// Smelted at the forge from [ItemSource.from].
  smelting,

  /// Forged at the forge.
  smithing,

  /// Condensed at the crafts workshop.
  workshop,

  /// Cooked at the kitchen.
  cooking,

  /// Prepared at the bait bench.
  baitCraft,

  /// Made at the compost bin from a compost recipe (cozy_life.md,
  /// profession_gear.md § 3.3).
  compost,
}

class ItemSource {
  const ItemSource(this.kind, {this.biome, this.seasons, this.from});
  final ItemSourceKind kind;
  final String? biome;
  final Set<Season>? seasons;
  final String? from;

  @override
  bool operator ==(Object other) =>
      other is ItemSource &&
      other.kind == kind &&
      other.biome == biome &&
      other.from == from &&
      (other.seasons ?? const {}).length == (seasons ?? const {}).length &&
      (other.seasons ?? const {}).containsAll(seasons ?? const {});

  @override
  int get hashCode => Object.hash(kind, biome, from);

  @override
  String toString() => 'ItemSource($kind, $biome, $seasons, $from)';
}

abstract final class ItemSourceRules {
  /// Biomes whose wild forage spots give [item].
  static List<String> forageBiomes(String item) => [
        for (final b in kBiomeBases.values)
          if (b.forageKinds.any((i) => kForageKinds[i].item == item)) b.id
      ];

  /// Every way to get [id] (crop, fish, material, meal, bait, tool...).
  /// A seed is `semilla_<crop>`. Empty = unknown (the UI says nothing).
  static List<ItemSource> of(String id) {
    if (id.startsWith('semilla_')) {
      final c = kCrops[id.substring(8)];
      if (c == null) return const [];
      return [
        if (c.seedPrice > 0) const ItemSource(ItemSourceKind.farmShop),
        if (c.seedPrice <= 0 && c.biome != kWildBiome)
          ItemSource(ItemSourceKind.forage, biome: c.biome),
      ];
    }
    if (kFarmTools.containsKey(id) || kRods.containsKey(id)) {
      return const [ItemSource(ItemSourceKind.toolShop)];
    }
    if (kFertilizers[id] case final f?) {
      return [
        if (f.price > 0) const ItemSource(ItemSourceKind.farmShop),
        if (kCompostRecipes.values.any((r) => r.fert == id))
          const ItemSource(ItemSourceKind.compost),
      ];
    }
    if (kCrops[id] case final c?) {
      final seasonal = kSeasonalForage.indexOf(id);
      if (seasonal >= 0) {
        return [
          ItemSource(ItemSourceKind.forage,
              seasons: {Season.values[seasonal % Season.values.length]})
        ];
      }
      if (id == kForageKinds[kForageEchoBloom].item) {
        return const [ItemSource(ItemSourceKind.forage)];
      }
      final wild = forageBiomes(id);
      if (c.biome == kWildBiome || wild.isNotEmpty) {
        return [for (final b in wild) ItemSource(ItemSourceKind.forage, biome: b)];
      }
      return [ItemSource(ItemSourceKind.crop, biome: c.biome, seasons: c.seasons)];
    }
    if (kFish[id] case final f?) {
      return [ItemSource(ItemSourceKind.fishing, biome: f.biome, seasons: f.seasons)];
    }
    if (kSmithMaterials[id] case final m?) {
      return switch (m.kind) {
        _ when id == kSchematic => const [ItemSource(ItemSourceKind.dungeonVein)],
        _ when id == kGuardianCore || id.startsWith('boss_') =>
          const [ItemSource(ItemSourceKind.bossDrop)],
        SmithMatKind.ore || SmithMatKind.rare || SmithMatKind.special => [
            ItemSource(ItemSourceKind.mine, biome: m.biome)
          ],
        SmithMatKind.ingot => [
            ItemSource(ItemSourceKind.smelting, biome: m.biome, from: oreOf(id))
          ],
        SmithMatKind.tool when (mineTool(id)?.tier ?? 0) > 0 => const [
            ItemSource(ItemSourceKind.toolShop),
            ItemSource(ItemSourceKind.smithing),
          ],
        SmithMatKind.tool ||
        SmithMatKind.supply ||
        SmithMatKind.fishPart =>
          const [ItemSource(ItemSourceKind.smithing)],
      };
    }
    if (kLifeMaterials.containsKey(id)) {
      return const [ItemSource(ItemSourceKind.workshop)];
    }
    if (kMeals.containsKey(id)) return const [ItemSource(ItemSourceKind.cooking)];
    if (kBaits.containsKey(id)) {
      return const [ItemSource(ItemSourceKind.baitCraft)];
    }
    return const [];
  }

  /// How many of [id] [p] owns (any crop or meal quality), for the
  /// have/need counts of cost grids.
  static int owned(PlayerProfile p, String id) {
    final life = p.life;
    if (id.startsWith('semilla_')) return life.farm.seedCount(id.substring(8));
    if (kCrops.containsKey(id)) return ResidentRules.cropHave(p, id);
    if (kFish.containsKey(id)) return life.count(id);
    if (kSmithMaterials.containsKey(id)) return life.ore(id);
    if (kLifeMaterials.containsKey(id)) return life.craft(id);
    if (kBaits.containsKey(id)) return life.baitCount(id);
    if (kFertilizers.containsKey(id)) return life.farm.fertCount(id);
    if (kMeals.containsKey(id)) {
      return life.farm.meals.entries
          .where((e) => e.key == id || e.key.startsWith('$id@'))
          .fold(0, (a, e) => a + e.value);
    }
    return 0;
  }
}
