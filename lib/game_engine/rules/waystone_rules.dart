import '../data/biomes_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import '../models/world_save.dart';

/// Region waystones (docs/specs/biome_regions.md § 4): fast travel
/// between the activated waystones of one biome. Per player, saved in the
/// world (`TownState.waystones`). The entrance waystone is always active.
abstract final class WaystoneRules {
  static TuningDef get t => tuning(TuningId.regions);

  static String key(String player, String biome, int i) => '$player|$biome:$i';

  /// [i] is active for [player] in [lay].
  static bool isActive(
      TownState town, String player, BiomeLayout lay, int i) {
    if (i < 0 || i >= lay.waystones.length) return false;
    if (lay.waystones[i].site == WaystoneSite.entrance) return true;
    return town.waystones.contains(key(player, lay.id, i));
  }

  /// The waystones [player] can travel to in [lay] (indices).
  static List<int> destinations(
          TownState town, String player, BiomeLayout lay) =>
      [
        for (var i = 0; i < lay.waystones.length; i++)
          if (isActive(town, player, lay, i)) i
      ];

  /// The waystone within reach of ([x], [y]) px, or `null`.
  static int? near(BiomeLayout lay, double x, double y) {
    final reach = t.d('waystoneReach');
    for (var i = 0; i < lay.waystones.length; i++) {
      final w = lay.waystones[i];
      final dx = (w.x + 0.5) * 16 - x, dy = (w.y + 0.5) * 16 - y;
      if (dx * dx + dy * dy <= reach * reach) return i;
    }
    return null;
  }

  /// [town] with [i] activated for [player] (same instance if it was).
  static TownState activate(
      TownState town, String player, BiomeLayout lay, int i) {
    if (isActive(town, player, lay, i)) return town;
    return town.copyWith(
        waystones: {...town.waystones, key(player, lay.id, i)});
  }

  /// Where a traveller to waystone [i] arrives (px): the walkway beside it.
  static WorldPoint arrival(BiomeLayout lay, int i) {
    final w = lay.waystones[i];
    return WorldPoint((w.ax + 0.5) * 16, (w.ay + 0.5) * 16);
  }

  /// Why [player] at ([x], [y]) cannot go from the stone in reach to [to]
  /// (`null` = can go).
  static String? blocked(TownState town, String player, BiomeLayout lay,
      double x, double y, int to) {
    final from = near(lay, x, y);
    if (from == null) return 'far';
    if (!isActive(town, player, lay, from)) return 'inactive';
    if (!isActive(town, player, lay, to)) return 'unknown';
    if (from == to) return 'here';
    return null;
  }
}
