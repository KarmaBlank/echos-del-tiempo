import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/smithing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart';
import '../models/item.dart' show ItemInstance, Rarity;
import '../models/player_profile.dart';
import '../models/weapon.dart';
import '../models/world_save.dart' show TownState;
import 'battle_engine.dart' show RandomSource;
import 'biome_rules.dart';
import '../models/loot.dart' show LootSource;
import 'loot_rules.dart';
import 'mine_generator.dart';

/// Mines and veins (docs/specs/mining_smithing.md § 1). Pure; numbers in
/// `kTuning[TuningId.smithing]`.
abstract final class MiningRules {
  static TuningDef get t => tuning(TuningId.smithing);

  static const _prefix = 'mine:';

  /// Place id of mine [i] of [biome].
  static String placeOf(String biome, int i) => '$_prefix$biome:$i';

  /// `(biome, index)` of a mine place, or `null`.
  static (String, int)? parse(String? place) {
    if (place == null || !place.startsWith(_prefix)) return null;
    final rest = place.substring(_prefix.length).split(':');
    if (rest.length != 2) return null;
    final i = int.tryParse(rest[1]);
    final lay = biomeLayout(rest[0]);
    if (i == null || lay == null || i < 0 || i >= lay.mines.length) {
      return null;
    }
    return (rest[0], i);
  }

  static bool isMine(String? place) => parse(place) != null;

  /// From [from] (current place; `null` = town) one can travel to the mine
  /// [to]: only from its biome exterior. Leaving a mine goes back to its
  /// biome only.
  static bool canTravel(String? from, String to) {
    final dst = parse(to);
    if (dst != null) return from == dst.$1;
    final src = parse(from);
    return src == null || src.$1 == to;
  }

  /// Where a player stands when leaving mine [i] of [biome] (px): the
  /// path tile under the entrance.
  static WorldPoint entranceFront(String biome, int i) {
    final (x, y) = biomeLayout(biome)!.mines[i];
    return WorldPoint(x * 16 + 8.0, (y + 1) * 16 + 10.0);
  }

  /// Log name of a place (es-AR, like the rest of the room log).
  static String placeName(String place) {
    final m = parse(place);
    if (m == null) return biomeDef(place)?.name ?? place;
    return 'la mina ${m.$2 + 1} de ${biomeDef(m.$1)?.name ?? m.$1}';
  }

  /// FNV-1a seed of the mine, reshaped every `mineReshapeDays` days.
  static int seedFor(String? worldId, String biome, int i, int day) {
    final week = day ~/ math.max(1, t.i('mineReshapeDays'));
    var h = 0x811c9dc5;
    for (final c in '${worldId ?? ''}|${placeOf(biome, i)}|$week'.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h % 1000000000;
  }

  static final _cache = <String, MineLayout>{};

  /// The mine at [place] (cached; `null` if not a mine).
  static MineLayout? layout(String? place, {String? worldId, int day = 0}) {
    final m = parse(place);
    if (m == null) return null;
    final seed = seedFor(worldId, m.$1, m.$2, day);
    final key = '${place!}|$seed|${t.i('mineNodes')}|${t.d('mineNpcChance')}';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 16) _cache.clear();
    return _cache[key] = MineGenerator.generate(m.$1, m.$2, seed,
        nodes: t.i('mineNodes'), npcChance: t.d('mineNpcChance'));
  }

  static final _maps = <String, GameMap>{};

  /// The map of [lay] with [spent] veins (a safe lobby map, theme `mina`).
  static GameMap mapOf(MineLayout lay, Set<int> spent) {
    final key =
        '${placeOf(lay.biome, lay.index)}|${lay.rows.hashCode}|${(spent.toList()..sort()).join(',')}';
    final hit = _maps[key];
    if (hit != null) return hit;
    if (_maps.length > 16) _maps.clear();
    return _maps[key] = GameMap(
      width: lay.width,
      height: lay.height,
      rows: lay.rowsWith(spent),
      theme: themeOf(lay.biome),
      spawn: WorldPoint(lay.spawn.$1 * 16 + 8.0, lay.spawn.$2 * 16 + 8.0),
      lobby: true,
      place: placeOf(lay.biome, lay.index),
    );
  }

  /// Map theme of the mines of [biome] (`mina_<biome>`; all dark,
  /// lighting.md § 5).
  static String themeOf(String biome) => 'mina_$biome';

  /// Spent veins of [place] at [now].
  static Set<int> spent(TownState town, String place, double now) =>
      BiomeRules.picked(town, place, now);

  static double regrowIn(TownState town, String place, int i, double now) =>
      BiomeRules.regrowIn(town, place, i, now);

  /// [town] with vein [i] of [place] spent for `mineRespawnSec`.
  static TownState spend(TownState town, String place, int i, double now) {
    final wild = {
      for (final e in town.wild.entries)
        if (e.value > now) e.key: e.value,
      BiomeRules.wildKey(place, i): (now + t.d('mineRespawnSec')).ceil(),
    };
    return town.copyWith(wild: wild);
  }

  /// What a vein of [biome] yields: `mineOreMin..mineOreMax` ores and,
  /// with `mineRareChance`, one rare material. [season] is the hook for
  /// the season rules (unused today).
  static Map<String, int> veinYield(RandomSource rand, String biome,
      {String? season}) {
    final b = kBiomeOres[biome];
    if (b == null) return const {};
    final lo = t.i('mineOreMin'), hi = math.max(lo, t.i('mineOreMax'));
    final n = lo + (rand() * (hi - lo + 1)).floor().clamp(0, hi - lo);
    return {
      if (n > 0) b.ore: n,
      if (rand() < t.d('mineRareChance')) b.rare: 1,
    };
  }

  /// Smith XP of a vein of [biome].
  static int veinXp(String biome) =>
      t.i('mineXp') * (kBiomeOres[biome]?.tier ?? 1);

  /// What a rare dungeon vein of zone [zone] yields: one rare material of
  /// its biome and, with `dungeonSchematicChance`, a schematic.
  static Map<String, int> dungeonYield(RandomSource rand, int zone) {
    final b = kBiomeOres[biomeOfZone(zone) ?? kBosque]!;
    return {
      b.rare: 1,
      if (rand() < t.d('dungeonSchematicChance')) kSchematic: 1,
    };
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
    if (r == Rarity.legendario) {
      final u = loot.pickUnique(rand, itemLevel, family: base.classId);
      if (u != null) return loot.generateUnique(rand, u, itemLevel);
      r = Rarity.epico;
    }
    return loot.generate(rand,
        itemLevel: itemLevel,
        rarity: r,
        baseId: base.id,
        source: LootSource.chest);
  }

  static int forgeXp(Rarity r) => t.i('craftXp') * (r.index + 1);
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

  /// Every smithing material, in catalog order, for [p]'s collection.
  static List<SmithCollectionEntry> entries(PlayerProfile p) => [
        for (final d in kSmithMaterials.values)
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
    };
  }
}
