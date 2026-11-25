import '../data/tuning_catalog.dart';
import '../models/world_save.dart';

/// Daily exploration loot of the wilds (docs/specs/biome_exploration.md
/// § 3.3–3.4). Pure: keys and checks; the host applies the reward.
abstract final class WildLootRules {
  static TuningDef get t => tuning(TuningId.regions);

  /// `town.daily` key of [player] opening chest / using shrine [i] of
  /// [biome] on [day] (pruned by the daily roll).
  static String lootKey(String player, String biome, int i, int day,
          {bool shrine = false}) =>
      'wx:$player:$biome:${shrine ? 's' : 'c'}$i:$day';

  /// [player] already took chest / shrine [i] today.
  static bool taken(TownState town, String player, String biome, int i,
          {bool shrine = false}) =>
      town.daily.containsKey(
          lootKey(player, biome, i, town.sky.day, shrine: shrine));
}
