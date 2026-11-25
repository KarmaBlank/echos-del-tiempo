import 'package:echos_del_tiempo/game_engine/data/bait_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/cooking_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_source_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_craft_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pimiento de brasa: forage in the grieta', () {
    expect(ItemSourceRules.of('pimiento_brasa'),
        [const ItemSource(ItemSourceKind.forage, biome: kGrieta)]);
  });

  test('shop seeds, planted crops, fish, ingots', () {
    expect(ItemSourceRules.of('semilla_trigo_dorado').single.kind,
        ItemSourceKind.farmShop);
    final wheat = ItemSourceRules.of('trigo_dorado').single;
    expect(wheat.kind, ItemSourceKind.crop);
    expect(wheat.biome, 'zona1');
    expect(ItemSourceRules.of('col_invierno').single.seasons,
        kCrops['col_invierno']!.seasons);
    expect(ItemSourceRules.of(kFish.keys.first).single.kind,
        ItemSourceKind.fishing);
    final ingot = ItemSourceRules.of('ingot_copper').single;
    expect(ingot.kind, ItemSourceKind.smelting);
    expect(ingot.from, 'ore_copper');
    expect(ItemSourceRules.of('ore_copper').single.biome, kBosque);
    expect(ItemSourceRules.of('tabla').single.kind, ItemSourceKind.workshop);
  });

  test('tools come from the crafts workshop, never the farm shop', () {
    for (final id in [...kFarmTools.keys, ...kRods.keys, 'pick_copper']) {
      final kinds = ItemSourceRules.of(id).map((s) => s.kind);
      expect(kinds, contains(ItemSourceKind.toolShop), reason: id);
      expect(kinds, isNot(contains(ItemSourceKind.farmShop)), reason: id);
    }
    expect(ItemSourceRules.of(kFertilizers.keys.first).single.kind,
        ItemSourceKind.farmShop);
  });

  test('every catalog item has at least one source', () {
    final ids = [
      for (final c in kCrops.keys) ...[c, 'semilla_$c'],
      ...kFish.keys.where((f) => kFish[f]!.biome != kWaterJunkBiome),
      ...kSmithMaterials.keys,
      ...kLifeMaterials.keys,
      ...kMeals.keys,
      ...kBaits.keys,
      ...kFertilizers.keys,
      ...kFarmTools.keys,
    ];
    final none = [
      for (final id in ids)
        if (ItemSourceRules.of(id).isEmpty &&
            // Wild products give no seed.
            !(id.startsWith('semilla_') &&
                kCrops[id.substring(8)]!.seedPrice <= 0))
          id
    ];
    expect(none, isEmpty);
  });

  test('owned sums every crop quality', () {
    var p = PlayerProfile(name: 'Ana', classId: 'maga', level: 3);
    p = p.copyWith(
        life: p.life.copyWith(
            crafts: {'tabla': 2},
            farm: p.life.farm.copyWith(crops: {
              cropKey('pimiento_brasa', CropQuality.values[0]): 1,
              cropKey('pimiento_brasa', CropQuality.values[1]): 2,
            })));
    expect(ItemSourceRules.owned(p, 'pimiento_brasa'), 3);
    expect(ItemSourceRules.owned(p, 'tabla'), 2);
    expect(ItemSourceRules.owned(p, 'ore_copper'), 0);
  });
}
