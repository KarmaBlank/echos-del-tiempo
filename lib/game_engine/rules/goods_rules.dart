import '../models/farm_animal.dart' show parseAnimalGoodsKey;
import '../data/bait_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/profession_gear_catalog.dart';
import '../data/smithing_catalog.dart';
import '../models/loot.dart';
import '../models/player_profile.dart';
import 'mining_rules.dart';

/// Overworld goods as ground loot (docs/specs/loot.md § 4c): what wilds
/// chests, shrines, mine chests, sunken chests and harvests spill on the
/// floor besides weapons and potions. A [LootDrop.goods] key is
/// `kind[:id]`:
///
/// - `gold` → credits.
/// - `ore:<id>` → smithing bag (ores, ingots, rare materials).
/// - `crop:<cropKey>` → farm bag (`id@quality`).
/// - `seed:<cropId>` → farm seeds.
/// - `wseed:<id>` → weapon seeds (profession_gear.md § 3.1).
/// - `bait:<id>` → baits.
/// - `fert:<id>` → fertilizers.
///
/// Goods never take inventory cells: picking them up always fits (the
/// ore bag clamps at its own cap, as digging does).
abstract final class GoodsRules {
  static const gold = 'gold';

  static LootDrop goldDrop(int n) => LootDrop.goods(gold, n);
  static LootDrop ore(String id, int n) => LootDrop.goods('ore:$id', n);
  static LootDrop crop(String key, int n) => LootDrop.goods('crop:$key', n);
  static LootDrop seed(String id, int n) => LootDrop.goods('seed:$id', n);
  static LootDrop wseed(String id) => LootDrop.goods('wseed:$id', 1);
  static LootDrop bait(String id, int n) => LootDrop.goods('bait:$id', n);
  static LootDrop fert(String id, int n) => LootDrop.goods('fert:$id', n);

  /// An animal product (`<product>@<quality>`, animals.md § 4.2).
  static LootDrop animal(String key, int n) => LootDrop.goods('agood:$key', n);

  /// (kind, id) of a goods key.
  static (String, String) split(String key) {
    final i = key.indexOf(':');
    return i < 0 ? (key, '') : (key.substring(0, i), key.substring(i + 1));
  }

  /// Harvest goods (crops, seeds, baits, fertilizer, weapon seeds) pop
  /// out of a plot, a bush or a tree: the short magnet pulls them to
  /// their owner. Gold and ore wait on the floor (loot.md § 4c).
  static bool magnet(LootDrop d) {
    final g = d.goods;
    if (g == null) return false;
    final k = split(g).$1;
    return k != gold && k != 'ore';
  }

  /// [p] with [d] added; `null` if [d] is not a valid goods drop.
  static PlayerProfile? give(PlayerProfile p, LootDrop d) {
    final g = d.goods;
    if (g == null || d.count <= 0) return null;
    final (kind, id) = split(g);
    final n = d.count;
    final farm = p.life.farm;
    switch (kind) {
      case gold:
        return p.copyWith(credits: p.credits + n);
      case 'ore':
        if (!kSmithMaterials.containsKey(id)) return null;
        return MiningRules.give(p, {id: n});
      case 'crop':
        if (parseCropKey(id) == null) return null;
        return p.copyWith(life: p.life.copyWith(farm: farm.addCrop(id, n)));
      case 'seed':
        if (!kCrops.containsKey(id)) return null;
        return p.copyWith(life: p.life.copyWith(farm: farm.addSeed(id, n)));
      case 'wseed':
        if (!kWeaponSeedNames.containsKey(id)) return null;
        return p.copyWith(life: p.life.copyWith(farm: farm.addWseed(id, n)));
      case 'bait':
        if (!kBaits.containsKey(id)) return null;
        return p.copyWith(life: p.life.addBait(id, n));
      case 'agood':
        if (parseAnimalGoodsKey(id) == null) return null;
        return p.copyWith(life: p.life.copyWith(farm: farm.addGoods(id, n)));
      case 'fert':
        if (!kFertilizers.containsKey(id)) return null;
        return p.copyWith(
            life: p.life.copyWith(
                farm: farm.copyWith(
                    ferts: {...farm.ferts, id: farm.fertCount(id) + n})));
      default:
        return null;
    }
  }

  /// es-AR name (host notices; the HUD shows the localized one).
  static String name(LootDrop d) {
    final (kind, id) = split(d.goods ?? '');
    final n = d.count;
    final base = switch (kind) {
      gold => 'de oro',
      'ore' => kSmithMaterials[id]?.name ?? id,
      'crop' => parseCropKey(id)?.$1.name ?? id,
      'seed' => kCrops[id]?.seedName ?? id,
      'wseed' => kWeaponSeedNames[id] ?? id,
      'bait' => kBaits[id]?.name ?? id,
      'fert' => kFertilizers[id]?.name ?? id,
      _ => id,
    };
    return n > 1 || kind == gold ? '$n $base' : base;
  }
}
