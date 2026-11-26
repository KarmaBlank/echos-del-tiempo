import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/mine_catalog.dart';
import '../data/smithing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import '../models/item.dart' show ItemInstance, Rarity;
import '../models/mine_state.dart';
import '../models/player_profile.dart';
import '../models/weapon.dart';
import '../models/world_save.dart' show TownState;
import 'battle_engine.dart' show RandomSource;
import 'bait_rules.dart';
import 'craft_rules.dart' show CraftRules;
import '../models/loot.dart' show LootSource;
import 'loot_rules.dart';
import 'mine_generator.dart';
import 'shop_interior_rules.dart';
import 'weather_rules.dart';

export '../models/mine_state.dart';
export 'mine_generator.dart' show MineLevel;

/// Mines (docs/specs/mining_smithing.md § 1, v2): dig-through levels,
/// tools, torches, bombs and the booster. Pure; numbers in
/// `kTuning[TuningId.smithing]`.
abstract final class MiningRules {
  static TuningDef get t => tuning(TuningId.smithing);

  /// The ingot the cart station of a mine level costs (§ 1.7).
  static String get stationIngot => kBiomeOres[kBosque]!.ingot;

  /// How near (px, player to the spot's center) E builds the station;
  /// facing is not required (`stationReachTiles`).
  static double get stationReach =>
      t.d('stationReachTiles').clamp(0.5, 2.0) * 16;

  static const _prefix = 'mine:';

  /// Levels per mine (≥ 1).
  static int get levels => math.max(1, t.i('mineLevels'));

  /// Place id of level [level] of mine [i] of [biome]. Level 0 keeps the
  /// v1 id (`mine:<biome>:<i>`).
  static String placeOf(String biome, int i, [int level = 0]) =>
      level == 0 ? '$_prefix$biome:$i' : '$_prefix$biome:$i:$level';

  /// `(biome, index, level)` of a mine place, or `null`.
  static (String, int, int)? parse(String? place) {
    if (place == null || !place.startsWith(_prefix)) return null;
    final rest = place.substring(_prefix.length).split(':');
    if (rest.length != 2 && rest.length != 3) return null;
    final i = int.tryParse(rest[1]);
    final l = rest.length == 3 ? int.tryParse(rest[2]) : 0;
    final lay = biomeLayout(rest[0]);
    if (i == null ||
        l == null ||
        lay == null ||
        i < 0 ||
        i >= entrances(lay).length ||
        l < 0 ||
        l >= levels ||
        (rest.length == 3 && l == 0)) {
      return null;
    }
    return (rest[0], i, l);
  }

  static bool isMine(String? place) => parse(place) != null;

  /// Mine entrances of a biome exterior: the one hook the lobby layout
  /// goes through (§ 1.1).
  static List<(int, int)> entrances(BiomeLayout lay) => mineEntrances(lay);

  /// From [from] (`null` = town) one can travel to [to]: a mine's first
  /// level only from its biome; between levels of the same mine only one
  /// step up or down; out of a mine only from its first level, back to
  /// its biome.
  static bool canTravel(String? from, String to) {
    final dst = parse(to), src = parse(from);
    if (dst != null) {
      if (src == null) return from == dst.$1 && dst.$3 == 0;
      return src.$1 == dst.$1 &&
          src.$2 == dst.$2 &&
          (src.$3 - dst.$3).abs() == 1;
    }
    return src == null || (src.$1 == to && src.$3 == 0);
  }

  /// Where a player stands when leaving mine [i] of [biome] (px): the
  /// path tile under the entrance.
  static WorldPoint entranceFront(String biome, int i) {
    final (x, y) = entrances(biomeLayout(biome)!)[i];
    return WorldPoint(x * 16 + 8.0, (y + 1) * 16 + 10.0);
  }

  /// Where the group lands travelling [from] → [to] when [to] is a mine
  /// level: going up, next to that level's shaft; else its arrival.
  static WorldPoint? arrival(String? from, String to, {String? worldId}) {
    final dst = parse(to);
    if (dst == null) return null;
    final lvl = level(to, worldId: worldId)!;
    final src = parse(from);
    if (src != null && src.$3 > dst.$3 && lvl.shaft != null) {
      final (x, y) = lvl.shaft!;
      return WorldPoint(x * 16 + 8.0, y * 16 - 6.0);
    }
    return WorldPoint(lvl.spawn.$1 * 16 + 8.0, lvl.spawn.$2 * 16 + 8.0);
  }

  /// Log name of a place (es-AR, like the rest of the room log).
  static String placeName(String place) {
    if (ShopInteriorRules.isShop(place)) return 'la tienda';
    final m = parse(place);
    if (m == null) return biomeDef(place)?.name ?? place;
    final lv = m.$3 == 0 ? '' : ' (nivel ${m.$3 + 1})';
    return 'la mina ${m.$2 + 1} de ${biomeDef(m.$1)?.name ?? m.$1}$lv';
  }

  /// FNV-1a seed of a level. Fixed per world: the levels never reshape;
  /// only veins grow back (§ 1.5).
  static int seedFor(String? worldId, String biome, int i, int level) {
    var h = 0x811c9dc5;
    for (final c in '${worldId ?? ''}|${placeOf(biome, i, level)}|v2'.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h % 1000000000;
  }

  /// Vein weights of [biome] at [level] (§ 1.3).
  static Map<String, double> weights(String biome, int level) {
    final rich = t.values.containsKey('rich_$biome') ? t.d('rich_$biome') : 1.0;
    final next = kBiomeOres.values
        .any((b) => b.tier == (kBiomeOres[biome]?.tier ?? 9) + 1);
    return {
      Tile.ore: t.d('wCommon'),
      MineTile.rich: (t.d('wRich') + t.d('wRichPerLevel') * level) * rich,
      MineTile.deep:
          next ? t.d('wDeep') + t.d('wDeepPerLevel') * level : 0,
      MineTile.gem: (t.d('wGem') + t.d('wGemPerLevel') * level) * rich,
    };
  }

  static MineGenParams params(String biome, int level) => MineGenParams(
        width: t.i('mineW'),
        height: t.i('mineH'),
        caveDensity: t.d('caveDensity'),
        formations: t.i('formations'),
        streamChance: t.d('streamChance'),
        lakeChance: t.d('lakeChance'),
        chambers: t.i('chambers'),
        chamberMin: t.i('chamberMin'),
        chamberMax: t.i('chamberMax'),
        grottoChance: t.d('grottoChance'),
        secretChance: t.d('secretChance'),
        relicChance: t.d('relicChance'),
        mushroomChance: t.d('mushroomChance'),
        loreChance: t.d('loreChance'),
        chestRate: t.d('chestRate'),
        clusters: t.i('veinClusters') + t.i('veinClustersPerLevel') * level,
        sizeMin: t.i('veinSizeMin'),
        sizeMax: t.i('veinSizeMax'),
        weights: weights(biome, level),
        npcChance: t.d('mineNpcChance'),
        last: level >= levels - 1,
      );

  static final _cache = <String, MineLevel>{};

  /// The generated level at [place] (cached; `null` if not a mine).
  static MineLevel? level(String? place, {String? worldId}) {
    final m = parse(place);
    if (m == null) return null;
    final seed = seedFor(worldId, m.$1, m.$2, m.$3);
    final p = params(m.$1, m.$3);
    final key = '${place!}|$seed|${p.width}x${p.height}|${p.clusters}|'
        '${p.weights.values.join(',')}|${p.caveDensity}|${p.chestRate}|${p.chambers}|${p.chamberMin}|${p.chamberMax}|${p.lakeChance}|${p.streamChance}';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 24) _cache.clear();
    return _cache[key] = MineGenerator.generate(m.$1, m.$2, m.$3, seed, p);
  }

  /// The tile at ([x], [y]) of [lvl] with [st] laid on top.
  /// The cart track of [lvl] (mining_smithing.md § 1.7): the open tiles
  /// of the station row from 4 tiles west of the station to 3 east,
  /// stopping at the first wall each way. Drawn as rail tiles on the
  /// floor (autotiled), never over the actors.
  static List<(int, int)> track(MineLevel lvl, MineLevelState st) {
    final (sx, sy) = lvl.station;
    bool open(int x) {
      final c = tileAt(lvl, st, x, sy);
      return c == Tile.floor || c == MineTile.station || c == MineTile.torch;
    }

    final out = <(int, int)>[];
    if (!open(sx)) return out;
    var x0 = sx, x1 = sx;
    while (x0 > sx - 4 && open(x0 - 1)) {
      x0--;
    }
    while (x1 < sx + 3 && open(x1 + 1)) {
      x1++;
    }
    for (var x = x0; x <= x1; x++) {
      out.add((x, sy));
    }
    return out;
  }

  static String tileAt(MineLevel lvl, MineLevelState st, int x, int y) {
    if (x < 0 || y < 0 || x >= lvl.width || y >= lvl.height) {
      return MineTile.bedrock;
    }
    final i = lvl.idx(x, y);
    final base = lvl.at(x, y);
    if (st.dug.contains(i)) {
      return st.torches.contains(i) ? MineTile.torch : Tile.floor;
    }
    if (st.grown[i] case final g?) return g;
    if (st.torches.contains(i)) {
      return base == Tile.floor || base == MineTile.station
          ? MineTile.torch
          : MineTile.wallTorch;
    }
    if (st.opened.contains(i)) {
      return switch (base) {
        MineTile.chest || MineTile.relic => MineTile.chestOpen,
        MineTile.mushroom => Tile.floor,
        _ => base,
      };
    }
    return base;
  }

  static final _rows = Expando<(MineLevel, List<String>)>('mine rows');

  /// The rows of [lvl] with [st] (memoized per state instance).
  static List<String> rowsOf(MineLevel lvl, MineLevelState st) {
    final hit = _rows[st];
    if (hit != null && identical(hit.$1, lvl)) return hit.$2;
    final out = st.isEmpty
        ? lvl.rows
        : [
            for (var y = 0; y < lvl.height; y++)
              String.fromCharCodes([
                for (var x = 0; x < lvl.width; x++)
                  tileAt(lvl, st, x, y).codeUnitAt(0)
              ])
          ];
    _rows[st] = (lvl, out);
    return out;
  }

  static final _maps = Expando<(MineLevel, GameMap)>('mine map');

  /// The map of [lvl] with [st] (a safe lobby map, theme `mina_<biome>`).
  static GameMap mapOf(MineLevel lvl, MineLevelState st) {
    final hit = _maps[st];
    if (hit != null && identical(hit.$1, lvl)) return hit.$2;
    final map = GameMap(
      width: lvl.width,
      height: lvl.height,
      rows: rowsOf(lvl, st),
      theme: themeOf(lvl.biome),
      spawn: WorldPoint(lvl.spawn.$1 * 16 + 8.0, lvl.spawn.$2 * 16 + 8.0),
      lobby: true,
      place: placeOf(lvl.biome, lvl.index, lvl.level),
    );
    _maps[st] = (lvl, map);
    return map;
  }

  /// Map theme of the mines of [biome] (`mina_<biome>`; all dark).
  static String themeOf(String biome) => 'mina_$biome';

  // ---------------- digging (§ 1.3, § 1.6) ----------------

  /// Hardness tier needed to break rock at [level].
  static int reqTier(int level) =>
      t.values.containsKey('reqTierLv$level') ? t.i('reqTierLv$level') : level;

  /// Pick tier needed for [code] at [level]: the level's, one more for
  /// deep and gem veins (at most the top tier).
  static int reqTierOf(String code, int level) {
    final base = reqTier(level);
    final extra = code == MineTile.deep || code == MineTile.gem ? 1 : 0;
    return math.min(kMineTools.last.tier, base + extra);
  }

  /// Hits to break [code] at [level] (`0` = unbreakable).
  static int hits(String code, int level) {
    if (!MineTile.breakable.contains(code)) return 0;
    final rock = math.max(1, t.i('rockHits') + t.i('rockHitsPerLevel') * level);
    if (code == MineTile.wallTorch) return 1;
    if (code == MineTile.crystal) return math.max(1, rock ~/ 2);
    if (MineTile.veins.contains(code)) {
      return math.max(1, (rock * t.d('veinHitMult')).round());
    }
    return rock;
  }

  /// The best mining tool [p] owns.
  static MineToolDef tool(PlayerProfile p) {
    var best = kMineTools.first;
    for (final d in kMineTools) {
      if (d.tier > best.tier && p.life.ore(d.id) > 0) best = d;
    }
    return best;
  }

  /// Why [tool] cannot break [code] at [level] (`null` = it can).
  static String? cannotBreak(String code, int level, MineToolDef tool) {
    if (code == MineTile.bedrock) return 'bedrock';
    if (hits(code, level) <= 0) return 'solid';
    if (code != MineTile.wallTorch && tool.tier < reqTierOf(code, level)) {
      return 'tier';
    }
    return null;
  }

  /// The tiles a bomb at ([x], [y]) breaks: every breakable tile within
  /// `bombRadius` (round), never bedrock nor solid finds.
  static List<(int, int)> bombTiles(
      MineLevel lvl, MineLevelState st, int x, int y) {
    final r = math.max(0, t.i('bombRadius'));
    final out = <(int, int)>[];
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy > r * r + r) continue;
        final c = tileAt(lvl, st, x + dx, y + dy);
        if (MineTile.breakable.contains(c)) out.add((x + dx, y + dy));
      }
    }
    return out;
  }

  /// [st] with ([x], [y]) dug at room second [now]. A vein of the level
  /// (not one that grew back) starts its regrow clock; a torch on the
  /// rock comes off with it.
  static MineLevelState dig(
      MineLevel lvl, MineLevelState st, int x, int y, double now) {
    final i = lvl.idx(x, y);
    final code = tileAt(lvl, st, x, y);
    final grown = st.grown.containsKey(i);
    final base = lvl.at(x, y);
    return st.copyWith(
      dug: {...st.dug, i},
      torches: code == MineTile.wallTorch
          ? ({...st.torches}..remove(i))
          : st.torches,
      grown: grown ? ({...st.grown}..remove(i)) : st.grown,
      regrow: MineTile.veins.contains(code)
          ? {
              ...st.regrow,
              // A regrown vein keeps echoing from its first origin.
              if (!grown && MineTile.veins.contains(base))
                i: now + t.d('regrowSec')
              else if (grown)
                i: now + t.d('regrowSec'),
            }
          : st.regrow,
    );
  }

  /// Whether a torch can go on ([x], [y]): floor or a rock face next to
  /// a walkable tile, and none there yet.
  static bool canTorch(MineLevel lvl, MineLevelState st, int x, int y) {
    final c = tileAt(lvl, st, x, y);
    if (c == Tile.floor || c == MineTile.station) return true;
    if (c != Tile.wall) return false;
    for (final (dx, dy) in const [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
      if (Tile.isWalkable(tileAt(lvl, st, x + dx, y + dy))) return true;
    }
    return false;
  }

  /// Material [d] can be found on world [day] (mining_smithing.md § 0):
  /// an empty `seasons` means all year; otherwise the season of [day]
  /// ([WeatherRules.season]) must be listed.
  static bool inSeason(SmithMaterialDef d, int day) =>
      d.seasons.isEmpty || d.seasons.contains(WeatherRules.season(day).name);

  /// [got] without the materials out of season on [day].
  static Map<String, int> _seasonal(Map<String, int> got, int day) => {
        for (final e in got.entries)
          if (kSmithMaterials[e.key] case final d?
              when inSeason(d, day))
            e.key: e.value,
      };

  /// What breaking [code] in a mine of [biome] gives (§ 1.3). [toolBonus]
  /// is the tool's extra-ore chance; [boosted]: the booster is on.
  /// Materials out of season on world [day] are dropped ([inSeason]).
  static Map<String, int> veinYield(RandomSource rand, String biome,
      {String code = Tile.ore,
      double toolBonus = 0,
      bool boosted = false,
      int day = 0,
      double rareBonus = 0}) {
    final b = kBiomeOres[biome];
    if (b == null) return const {};
    // [rareBonus]: the Veta sub-path B (life_trees_v2.md § 2.1).
    final rareMult = (boosted ? 1 + t.d('boostRare') : 1.0) * (1 + rareBonus);
    final extra = toolBonus + (boosted ? t.d('boostYield') : 0);
    int more() => rand() < extra ? 1 : 0;
    if (code == MineTile.crystal) {
      return {
        if (rand() < t.d('crystalRareChance') * rareMult) b.rare: 1,
      };
    }
    if (!MineTile.veins.contains(code)) return const {};
    if (code == MineTile.gem) return {b.rare: 1 + more()};
    final lo = t.i('mineOreMin'), hi = math.max(lo, t.i('mineOreMax'));
    var n = lo + (rand() * (hi - lo + 1)).floor().clamp(0, hi - lo) + more();
    var ore = b.ore;
    var rare = t.d('mineRareChance');
    if (code == MineTile.rich) {
      n += t.i('richOreBonus');
      rare = t.d('richRareChance');
    } else if (code == MineTile.deep) {
      final next = kBiomeOres.values.where((o) => o.tier == b.tier + 1);
      if (next.isNotEmpty) ore = next.first.ore;
    }
    return _seasonal({
      if (n > 0) ore: n,
      if (rand() < rare * rareMult) b.rare: 1,
    }, day);
  }

  /// A bait found in a vein (weather_seasons.md / fishing.md § 14.4):
  /// with `mineBaitChance`, [BaitRules.foundBait]; `null` otherwise.
  static String? veinBait(RandomSource rand) =>
      rand() < t.d('mineBaitChance') ? BaitRules.foundBait(rand()) : null;

  /// Smith XP of a vein of [biome].
  static int veinXp(String biome) =>
      t.i('mineXp') * (kBiomeOres[biome]?.tier ?? 1);

  /// Smith XP of breaking [code] in a mine of [biome].
  static int digXp(String biome, String code) =>
      MineTile.veins.contains(code)
          ? t.i('mineXp') * (kBiomeOres[biome]?.tier ?? 1)
          : t.i('digXp');

  /// Loading a world (the room clock restarts at [now]): no vein waits
  /// longer than a full regrow and carts keep their remaining time.
  static TownState rebase(TownState town, double now) {
    if (town.mines.isEmpty) return town;
    final cap = now + t.d('regrowSec');
    return town.copyWith(mines: {
      for (final e in town.mines.entries)
        e.key: e.value.copyWith(
          regrow: {
            for (final r in e.value.regrow.entries)
              r.key: math.min(r.value, cap)
          },
          cart: e.value.cart.phase == CartPhase.mine
              ? e.value.cart
              : e.value.cart.copyWith(t: now),
        ),
    });
  }

  /// What a rare dungeon vein of zone [zone] yields: one rare material of
  /// its biome and, with `dungeonSchematicChance`, a schematic (only
  /// materials in season on [day]).
  static Map<String, int> dungeonYield(RandomSource rand, int zone,
      {int day = 0}) {
    final b = kBiomeOres[biomeOfZone(zone) ?? kBosque]!;
    return _seasonal({
      b.rare: 1,
      if (rand() < t.d('dungeonSchematicChance')) kSchematic: 1,
    }, day);
  }

  /// Rare ore veins of a dungeon floor (see [MineGenerator.dungeonVeins]).
  static List<(int, int)> dungeonVeins(
          List<String> rows, List<(int, int)> spots, int seed) =>
      MineGenerator.dungeonVeins(rows, spots, seed,
          chance: t.d('dungeonOreChance'));

  /// [p] with [delta] smithing materials (capped by `stackCap`).
  static PlayerProfile give(PlayerProfile p, Map<String, int> delta,
      {String? source, int day = 0}) {
    var life = p.life.addOres(delta, cap: math.max(1, t.i('stackCap')));
    if (source != null) life = life.logOres(delta, source, day);
    return p.copyWith(life: life);
  }

  /// Collection source of a mine of [biome] / a dungeon of [zone].
  static String mineSource(String biome) => 'mine:$biome';
  static String dungeonSource(int zone) => 'dungeon:$zone';

  // ---------------- shop and crafting (§ 1.6) ----------------

  /// Gold price of a mine consumable or tool at the trader.
  static int price(String id) {
    final tool = mineTool(id);
    if (tool != null) return tool.gold;
    final k = kMineSupplyKey[id];
    return k == null ? 0 : t.i('${k}Gold');
  }

  /// What the smith pays to craft [id]: materials and gold; the amount
  /// made. `null` if it is not craftable.
  static ({Map<String, int> mats, int gold, int n})? recipe(
      String id, String biomeOre) {
    final tool = mineTool(id);
    if (tool != null) {
      if (tool.ingot == null) return null;
      return (
        mats: {tool.ingot!: tool.ingots},
        gold: tool.gold ~/ 3,
        n: 1
      );
    }
    return switch (id) {
      kMineTorch => (
          mats: {biomeOre: t.i('torchOre')},
          gold: 0,
          n: math.max(1, t.i('torchBatch'))
        ),
      kMineBomb => (mats: {biomeOre: t.i('bombOre')}, gold: 0, n: 1),
      kVeinOil => (mats: {biomeOre: t.i('oilOre')}, gold: 0, n: 1),
      _ => null,
    };
  }
}

/// Why a smelt or forge is refused (UI key `ui.inventory.smith.why.<name>`).
enum SmithBlock {
  notOre,
  noOre,
  noGold,
  notIngot,
  noIngots,
  noRare,
  noRecipe,
  level,
  brannAbsent,
  brannRarity,
  badBase,
  baseLevel,
}

/// The cost of forging (mining_smithing.md § 4).
class SmithCost {
  const SmithCost(
      {required this.ingot,
      required this.ingots,
      required this.rare,
      required this.rares,
      required this.gold,
      required this.itemLevel,
      required this.recipe});

  final String ingot;
  final int ingots;
  final String rare;
  final int rares;
  final int gold;
  final int itemLevel;

  /// Needs a schematic or a guardian core (legendary).
  final bool recipe;
}

/// Smelting and forging weapons from scratch (mining_smithing.md § 3–5).
abstract final class SmithCraftRules {
  static TuningDef get t => MiningRules.t;

  // ---------------- smelt ----------------

  /// Ores per ingot and gold per ingot of [ore].
  static (int, int)? smeltCost(String ore) {
    final d = kSmithMaterials[ore];
    if (d == null || d.kind != SmithMatKind.ore) return null;
    return (math.max(1, t.i('smeltOre')), t.i('smeltGoldPerTier') * d.tier);
  }

  static SmithBlock? cannotSmelt(PlayerProfile p, String ore, int n) {
    final c = smeltCost(ore);
    if (c == null || ingotOf(ore) == null || n < 1) return SmithBlock.notOre;
    if (p.life.ore(ore) < c.$1 * n) return SmithBlock.noOre;
    if (p.credits < c.$2 * n) return SmithBlock.noGold;
    return null;
  }

  /// How many ingots [p] can smelt from [ore] now.
  static int smeltMax(PlayerProfile p, String ore) {
    final c = smeltCost(ore);
    if (c == null) return 0;
    final byOre = p.life.ore(ore) ~/ c.$1;
    final byGold = c.$2 <= 0 ? byOre : p.credits ~/ c.$2;
    return math.max(0, math.min(byOre, byGold));
  }

  /// [p] after smelting [n] ingots of [ore], or `null`.
  static PlayerProfile? smelt(PlayerProfile p, String ore, int n,
      {int day = 0}) {
    if (cannotSmelt(p, ore, n) != null) return null;
    final (per, gold) = smeltCost(ore)!;
    return MiningRules.give(p, {ore: -per * n, ingotOf(ore)!: n},
            source: 'smelt', day: day)
        .copyWith(credits: p.credits - gold * n);
  }

  static int smeltXp(String ore, int n) =>
      t.i('smeltXp') * (kSmithMaterials[ore]?.tier ?? 1) * n;

  // ---------------- forge ----------------

  /// Smith level needed for [r].
  static int levelFor(Rarity r) => switch (r) {
        Rarity.comun => 1,
        Rarity.magico => t.i('lvMagico'),
        Rarity.raro => t.i('lvRaro'),
        Rarity.epico => t.i('lvEpico'),
        Rarity.legendario => t.i('lvLegend'),
      };

  /// Best rarity a smith of level [lv] can forge.
  static Rarity maxRarity(int lv) {
    var best = Rarity.comun;
    for (final r in Rarity.values) {
      if (lv >= levelFor(r)) best = r;
    }
    return best;
  }

  static int _ingots(Rarity r) => t.i(switch (r) {
        Rarity.comun => 'ingotsComun',
        Rarity.magico => 'ingotsMagico',
        Rarity.raro => 'ingotsRaro',
        Rarity.epico => 'ingotsEpico',
        Rarity.legendario => 'ingotsLegend',
      });

  static int _rares(Rarity r) => switch (r) {
        Rarity.comun || Rarity.magico => 0,
        Rarity.raro => t.i('rareRaro'),
        Rarity.epico => t.i('rareEpico'),
        Rarity.legendario => t.i('rareLegend'),
      };

  /// Item level of a weapon forged with [ingot] by a character of level
  /// [charLevel]: below the character and capped by the ingot tier.
  static int itemLevel(int charLevel, String ingot) {
    final tier = kSmithMaterials[ingot]?.tier ?? 1;
    return math.max(
        1,
        math.min(charLevel - t.i('craftIlGap'),
            t.i('ingotIlPerTier') * tier));
  }

  /// Full cost; [brann] = Brann forges it (his price).
  static SmithCost? cost(int charLevel, String ingot, Rarity r,
      {bool brann = false}) {
    final d = kSmithMaterials[ingot];
    if (d == null || d.kind != SmithMatKind.ingot) return null;
    final il = itemLevel(charLevel, ingot);
    return SmithCost(
      ingot: ingot,
      ingots: _ingots(r),
      rare: kBiomeOres[d.biome]!.rare,
      rares: _rares(r),
      gold: t.i(brann ? 'brannGoldPerIl' : 'craftGoldPerIl') * il,
      itemLevel: il,
      recipe: r == Rarity.legendario,
    );
  }

  /// Bases [p] could forge with [ingot]: catalog weapons of level ≤ the
  /// item level.
  static List<WeaponDef> bases(
      Iterable<WeaponDef> catalog, int charLevel, String ingot) {
    final il = itemLevel(charLevel, ingot);
    return [
      for (final w in catalog)
        if (w.level <= il) w
    ]..sort((a, b) => a.level != b.level
        ? a.level.compareTo(b.level)
        : a.id.compareTo(b.id));
  }

  /// Why [p] cannot forge [base] with [ingot] at [r]. [maxRarity] is the
  /// cap (smith level, or Brann's commission rarity); [brannHome] only
  /// matters when [brann].
  static SmithBlock? cannotForge(PlayerProfile p, WeaponDef? base,
      String ingot, Rarity r,
      {required Rarity maxRarity, bool brann = false, bool brannHome = true}) {
    if (brann && !brannHome) return SmithBlock.brannAbsent;
    final c = cost(p.level, ingot, r, brann: brann);
    if (c == null) return SmithBlock.notIngot;
    if (base == null) return SmithBlock.badBase;
    if (base.level > c.itemLevel) return SmithBlock.baseLevel;
    if (r.index > maxRarity.index) {
      return brann ? SmithBlock.brannRarity : SmithBlock.level;
    }
    if (p.life.ore(ingot) < c.ingots) return SmithBlock.noIngots;
    if (c.rares > 0 && p.life.ore(c.rare) < c.rares) return SmithBlock.noRare;
    if (c.recipe &&
        p.life.ore(kSchematic) < 1 &&
        p.life.ore(kGuardianCore) < 1) {
      return SmithBlock.noRecipe;
    }
    if (p.credits < c.gold) return SmithBlock.noGold;
    return null;
  }

  /// [p] with the forge cost paid (the schematic first, else the core).
  static PlayerProfile? pay(PlayerProfile p, String ingot, Rarity r,
      {bool brann = false}) {
    final c = cost(p.level, ingot, r, brann: brann);
    if (c == null) return null;
    final take = <String, int>{
      ingot: -c.ingots,
      if (c.rares > 0) c.rare: -c.rares,
      if (c.recipe)
        p.life.ore(kSchematic) > 0 ? kSchematic : kGuardianCore: -1,
    };
    return MiningRules.give(p, take).copyWith(credits: p.credits - c.gold);
  }

  /// The forged weapon: [base] at [r] (a legendary is a unique, preferring
  /// the base's family), item level from [cost].
  static ItemInstance make(LootRules loot, RandomSource rand, WeaponDef base,
      Rarity r, int itemLevel) {
    ItemInstance forged(ItemInstance i) =>
        i.copyWith(uid: '${CraftRules.forgedPrefix}${i.uid}');
    if (r == Rarity.legendario) {
      final u = loot.pickUnique(rand, itemLevel, family: base.classId);
      if (u != null) return forged(loot.generateUnique(rand, u, itemLevel));
      r = Rarity.epico;
    }
    return forged(loot.generate(rand,
        itemLevel: itemLevel,
        rarity: r,
        baseId: base.id,
        source: LootSource.chest));
  }

  static int forgeXp(Rarity r) => t.i('craftXp') * (r.index + 1);

  // ---------------- income (§ 2.2) ----------------

  /// What the trader pays for one [id] (0 = not sold there). An ingot is
  /// worth more than its ores plus the smelting gold.
  static int sellPrice(String id) {
    final d = kSmithMaterials[id];
    if (d == null) return 0;
    final tier = math.max(1, d.tier);
    return switch (d.kind) {
      SmithMatKind.ore => t.i('orePricePerTier') * tier,
      SmithMatKind.ingot => t.i('ingotPricePerTier') * tier,
      SmithMatKind.rare => t.i('rarePricePerTier') * tier,
      SmithMatKind.special => t.i('specialPrice'),
      SmithMatKind.tool ||
      SmithMatKind.supply ||
      SmithMatKind.fishPart ||
      SmithMatKind.animalPart =>
        0,
    };
  }
}

/// One entry of the smithing material collection (mining_smithing.md
/// § 2.1). The UI plugs it into the shared collection template: [icon] is
/// a sprite manifest id, [rows] are (i18n key, args) pairs; undiscovered
/// entries have no rows and show a grey "?".
class SmithCollectionEntry {
  const SmithCollectionEntry(
      {required this.id,
      required this.icon,
      required this.nameKey,
      required this.discovered,
      this.rows = const []});
  final String id;
  final String icon;
  final String nameKey;
  final bool discovered;
  final List<(String, Map<String, Object>)> rows;
}

abstract final class SmithCollection {
  /// Rarity word key of a material kind.
  static String rarityKey(SmithMaterialDef d) =>
      'ui.inventory.smith.col.rarity.${d.kind.name}';

  /// Material kinds shown in the collection (tools and mine supplies
  /// are shop goods, not finds).
  static const kinds = [
    SmithMatKind.ore,
    SmithMatKind.ingot,
    SmithMatKind.rare,
    SmithMatKind.special,
  ];

  /// The materials of the collection, in catalog order.
  static Iterable<SmithMaterialDef> get materials =>
      kSmithMaterials.values.where((d) => kinds.contains(d.kind));

  /// Every smithing material, in catalog order, for [p]'s collection.
  static List<SmithCollectionEntry> entries(PlayerProfile p) => [
        for (final d in materials)
          if (p.life.oreLog[d.id] case final f?)
            SmithCollectionEntry(
              id: d.id,
              icon: 'vida_${d.id}',
              nameKey: d.textKey,
              discovered: true,
              rows: [
                ('ui.inventory.smith.col.found', {'source': f.source}),
                ('ui.inventory.smith.col.day', {'n': f.day}),
                ('ui.inventory.smith.col.count', {'n': f.count}),
                (rarityKey(d), const {}),
                for (final u in usesOf(d.id))
                  ('ui.inventory.smith.col.use.${u.$1}', {'id': u.$2}),
              ],
            )
          else
            SmithCollectionEntry(
                id: d.id,
                icon: 'vida_${d.id}',
                nameKey: d.textKey,
                discovered: false),
      ];

  /// Data-driven uses of a material: (kind, target id). Kinds: `smelt`
  /// (ore → ingot), `forge` (ingot → weapons), `rare` (Raro+ with ingots
  /// of its biome), `legend` (recipe of a forged legendary).
  static List<(String, String)> usesOf(String id) {
    final d = kSmithMaterials[id];
    if (d == null) return const [];
    return switch (d.kind) {
      SmithMatKind.ore => [('smelt', ingotOf(id)!)],
      SmithMatKind.ingot => [('forge', id)],
      SmithMatKind.rare => [('rare', kBiomeOres[d.biome]!.ingot)],
      SmithMatKind.special => [('legend', id)],
      SmithMatKind.tool ||
      SmithMatKind.supply ||
      SmithMatKind.fishPart ||
      SmithMatKind.animalPart =>
        const [],
    };
  }
}
