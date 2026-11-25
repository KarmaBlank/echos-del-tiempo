import '../data/tuning_catalog.dart';
import '../models/world_save.dart';
import 'biome_regions.dart' show BiomeLayout;

/// Daily exploration loot of the wilds (docs/specs/biome_exploration.md
/// § 3.3–3.4). Pure: keys and checks; the host applies the reward.
abstract final class WildLootRules {
  static TuningDef get t => tuning(TuningId.regions);

  /// Prefix of every wilds loot key in `town.daily`.
  static const prefix = 'wx:';

  /// `town.daily` key of [player] opening chest / using shrine [i] of
  /// [biome] on [day] (pruned by the daily roll). [i] indexes the
  /// generated layout, so the key carries [BiomeLayout.version]: after a
  /// regeneration the same index is a different spot and must not inherit
  /// the old "used today" mark.
  static String lootKey(String player, String biome, int i, int day,
          {bool shrine = false}) =>
      '$prefix$player:$biome:v${BiomeLayout.version}:'
      '${shrine ? 's' : 'c'}$i:$day';

  /// [daily] without the wilds loot keys (layout migration).
  static Map<String, int> dropLoot(Map<String, int> daily) => {
        for (final e in daily.entries)
          if (!e.key.startsWith(prefix)) e.key: e.value,
      };

  /// [player] already took chest / shrine [i] today.
  static bool taken(TownState town, String player, String biome, int i,
          {bool shrine = false}) =>
      town.daily.containsKey(
          lootKey(player, biome, i, town.sky.day, shrine: shrine));
}
