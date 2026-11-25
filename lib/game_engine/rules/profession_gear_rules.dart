import 'dart:math' as math;

import '../data/fishing_catalog.dart';
import '../data/game_catalog.dart';
import '../data/profession_gear_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/item.dart';
import '../models/loot.dart' show LootSource;
import '../models/player_profile.dart';
import '../models/weapon.dart';
import 'battle_engine.dart' show RandomSource;
import 'farming_rules.dart';
import 'fishing_rules.dart';
import 'gear_v2_rules.dart';
import 'item_rules.dart';
import 'life_tree_rules.dart';
import 'loot_rules.dart';

export '../data/profession_gear_catalog.dart';

/// Why Brann can't forge a legendary fish (profession_gear.md § 4.2).
enum FishForgeBlock { notLegend, noFish, level, gold }

/// Profession weapons (docs/specs/profession_gear.md): marking, making,
/// living weapons, sunken / fish-forged / forge-only weapons and the
/// sub-path mechanics of the life trees (life_trees_v2.md § 2.1). Pure:
/// the host applies it. Numbers: `kTuning[TuningId.gear]`.
abstract final class GearRules {
  static TuningDef get t => tuning(TuningId.gear);

  // ---------------- marking (§ 1) ----------------

  static final _mark = RegExp(r'gear-([a-z0-9_]+)-');

  /// `uid` of a new profession weapon [id] (the inventory keeps the mark).
  static String uidFor(String id) => 'gear-$id-${LootRules.newUid}';

  /// Gear id of [i] (`null` = not a profession weapon).
  static String? gearIdOf(ItemInstance i) => _mark.firstMatch(i.uid)?.group(1);

  static bool isGear(ItemInstance i) => gearIdOf(i) != null;

  /// The fixed definition of [i] (`null` for fish-forged ones).
  static ProfessionGearDef? defOf(ItemInstance i) =>
      kProfessionGear[gearIdOf(i)];

  /// Legendary fish a fish-forged weapon was made from.
  static String? fishOf(ItemInstance i) {
    final id = gearIdOf(i);
    return id != null && id.startsWith('fish_') ? id.substring(5) : null;
  }

  /// Profession that makes [i].
  static LifeSkillKind? professionOf(ItemInstance i) => fishOf(i) != null
      ? LifeSkillKind.pesca
      : (gearIdOf(i)?.startsWith(kPartsGearPrefix) ?? false)
          ? LifeSkillKind.herreria
          : defOf(i)?.source.profession;

  // ---------------- making (§ 1) ----------------

  /// Best base of [type] up to [itemLevel] (the lowest one below it).
  static WeaponDef? baseFor(GameCatalog c, String type, int itemLevel) {
    final of = [
      for (final w in c.weapons.values)
        if (w.type == type) w
    ]..sort((a, b) => a.level.compareTo(b.level));
    if (of.isEmpty) return null;
    var best = of.first;
    for (final w in of) {
      if (w.level <= itemLevel) best = w;
    }
    return best;
  }

  /// A profession weapon: a weapon of [type] at [itemLevel] and [rarity]
  /// carrying [signature] and [extra] as fixed affixes (they push random
  /// ones out), plus [bonusAffixes] random ones if there's room. A
  /// Legendary one is an Epic made Legendary with a weapon passive.
  static ItemInstance make(LootRules loot, RandomSource rng,
      {required String gearId,
      required String type,
      required UniqueMod signature,
      required Rarity rarity,
      required int itemLevel,
      required String name,
      List<UniqueMod> extra = const [],
      int bonusAffixes = 0}) {
    final il = itemLevel.clamp(1, LootRules.maxLevel);
    final base = baseFor(loot.catalog, type, il) ??
        loot.catalog.weapons.values.first;
    final r0 = switch (rarity) {
      Rarity.legendario => Rarity.epico,
      Rarity.comun || Rarity.magico => Rarity.raro,
      _ => rarity,
    };
    var item = loot.generate(rng,
        itemLevel: math.max(il, base.level),
        rarity: r0,
        baseId: base.id,
        source: LootSource.chest);
    if (rarity == Rarity.legendario) {
      item = item.copyWith(
          rarity: Rarity.legendario,
          passiveId: item.passiveId ?? loot.rollPassiveId(rng, base.type));
    }
    final fixed = <UniqueMod>[];
    for (final m in [signature, ...extra]) {
      if (fixed.every((f) => f.affixId != m.affixId)) fixed.add(m);
    }
    final rolls = [
      for (final f in fixed.take(item.rarity.maxMods))
        if (ItemRules.fixedRangeAt(f, item.itemLevel) case (final lo, final hi))
          AffixRoll(f.affixId, 0, LootRules.rollValue(rng, lo, hi)),
    ];
    final ids = {for (final r in rolls) r.affixId};
    final random = [
      for (final a in item.affixes)
        if (!ids.contains(a.affixId)) a
    ];
    final room = math.max(0, item.rarity.maxMods - rolls.length);
    item = item.copyWith(
        uid: uidFor(gearId),
        name: name,
        affixes: [...rolls, ...random.take(room)]);
    return loot.addRandomAffixes(rng, item, bonusAffixes);
  }

  /// [g] at [rarity] (its legendary name on a Legendary).
  static ItemInstance makeDef(LootRules loot, RandomSource rng,
          ProfessionGearDef g, Rarity rarity, int itemLevel,
          {List<UniqueMod> extra = const [], int bonusAffixes = 0}) =>
      make(loot, rng,
          gearId: g.id,
          type: g.type,
          signature: g.signature,
          rarity: rarity,
          itemLevel: itemLevel,
          name: rarity == Rarity.legendario ? g.legend : g.name,
          extra: extra,
          bonusAffixes: bonusAffixes);

  static T _pick<T>(RandomSource rng, List<T> l) =>
      l[(rng() * l.length).floor().clamp(0, l.length - 1)];

  // ---------------- living weapons (§ 3) ----------------

  /// Whether a plot [seed] grows a living weapon (new or regrowing).
  static bool isLiving(String? seed) =>
      seed != null &&
      (kWeaponSeeds.containsKey(seed) || seed.startsWith(kRegrowPrefix));

  /// Gear id a living plot grows.
  static String? livingGear(FarmPlot p) {
    final s = p.seed;
    if (s == null) return null;
    if (s.startsWith(kRegrowPrefix)) return s.substring(kRegrowPrefix.length);
    return kWeaponSeeds[s]?.gear;
  }

  static bool ancient(FarmPlot p) => kWeaponSeeds[p.seed]?.ancient ?? false;

  static double get growSec => math.max(1, t.d('livingGrowSec'));

  /// Plants weapon seed [seed] (planter's potential like a crop).
  static FarmPlot? plant(FarmPlot p, String seed, PlayerProfile who) =>
      p.seed != null || !kWeaponSeeds.containsKey(seed)
          ? null
          : FarmPlot(
              seed: seed,
              wet: p.wet,
              boost: LifeTreeRules.farm(who, LifeFx.grow),
              potential:
                  FarmingRules.personScore(who, FarmingRules.hoeOf(who)),
              planter: who.name);

  /// Replants the living weapon [item] to grow it further (§ 3.5).
  static FarmPlot? regrow(FarmPlot p, ItemInstance item, PlayerProfile who) {
    final g = defOf(item);
    if (p.seed != null || g == null || g.source != GearSource.living) {
      return null;
    }
    return FarmPlot(
        seed: '$kRegrowPrefix${g.id}',
        held: item,
        wet: p.wet,
        boost: LifeTreeRules.farm(who, LifeFx.grow),
        potential: FarmingRules.personScore(who, FarmingRules.hoeOf(who)),
        planter: who.name);
  }

  /// One bag of compost [fert] on a living plot (up to
  /// `livingCompostMax`), or `null`.
  static FarmPlot? compost(FarmPlot p, String fert, PlayerProfile who) {
    if (!isLiving(p.seed) ||
        !kFertilizers.containsKey(fert) ||
        FarmingRules.ripe(p) ||
        p.compostCount >= t.i('livingCompostMax')) {
      return null;
    }
    return p.copyWith(
        composts: {...p.composts, fert: (p.composts[fert] ?? 0) + 1},
        fertBy: who.name);
  }

  /// Quality score of a living plot harvested by [harvester].
  static double score(PlayerProfile harvester, FarmPlot plot) =>
      FarmingRules.score(harvester, plot) * t.d('livingWaterQ') +
      plot.compostCount * t.d('livingCompostQ') +
      (ancient(plot) ? t.d('livingAncientQ') : 0) +
      LifeTreeRules.farm(harvester, LifeFx.livingRarity) * t.d('livingTreeQ') +
      FarmingRules.level(harvester) * t.d('livingLevelQ');

  /// Whether the plot is on the dedicated path to a Legendary (§ 3.4):
  /// ancient seed, enough top compost and the Madera viva branch.
  static bool legendPath(PlayerProfile harvester, FarmPlot plot) =>
      (ancient(plot) || plot.held?.rarity == Rarity.legendario) &&
      (plot.composts[kTopCompost] ?? 0) >= t.i('livingLegendCompost') &&
      LifeTreeRules.farm(harvester, LifeFx.livingRarity) >=
          t.d('livingLegendTree') - 1e-9;

  /// Crop quality of a living harvest (roll 0..1 jitters ±0.2).
  static CropQuality quality(
      PlayerProfile harvester, FarmPlot plot, double roll) {
    final s = score(harvester, plot) + (roll.clamp(0.0, 1.0) - 0.5) * 0.4;
    if (s >= t.d('livingLegend') && legendPath(harvester, plot)) {
      return CropQuality.legendario;
    }
    if (s >= t.d('livingExcelente')) return CropQuality.epico;
    if (s >= t.d('livingFina')) return CropQuality.raro;
    return CropQuality.normal;
  }

  /// Weapon rarity of a living harvest quality: normal → Rare, fine →
  /// Epic, excellent → Epic with one more affix, legendary → Legendary.
  static Rarity rarityOf(CropQuality q) => switch (q) {
        CropQuality.normal => Rarity.raro,
        CropQuality.raro || CropQuality.epico => Rarity.epico,
        CropQuality.legendario => Rarity.legendario,
      };

  /// Item level of a living weapon grown by [p].
  static int livingLevel(PlayerProfile p) => math
      .max(p.level,
          (FarmingRules.level(p) * t.d('livingItemLevelPerFarm')).round())
      .clamp(1, LootRules.maxLevel);

  /// Affixes the composts of [plot] give (one per compost type).
  static List<UniqueMod> compostMods(FarmPlot plot) => [
        for (final f in plot.composts.keys)
          if (kCompostAffix[f] case final m?) m
      ];

  /// The living weapon of a ripe [plot] harvested by [p] (§ 3.4–3.5).
  static ItemInstance? harvest(
      LootRules loot, RandomSource rng, PlayerProfile p, FarmPlot plot) {
    if (!FarmingRules.ripe(plot)) return null;
    final id = livingGear(plot);
    final g = kProfessionGear[id];
    if (g == null) return null;
    final q = quality(p, plot, rng());
    final extraAffix = (q == CropQuality.epico ? 1 : 0) +
        (rng() < LifeTreeRules.farm(p, LifeFx.livingAffix) ? 1 : 0);
    final held = plot.held;
    if (held != null) return _grown(loot, rng, g, held, q, plot, extraAffix);
    // v2 (profession_gear_v2.md § 5): affinity, quality and slots.
    return GearV2Rules.living(loot, rng, p, plot,
        makeDef(loot, rng, g, rarityOf(q), livingLevel(p),
            extra: compostMods(plot), bonusAffixes: extraAffix));
  }

  /// A regrown living weapon: more item level, its rarity rises to what
  /// the harvest quality gives, and new compost affixes join if room.
  static ItemInstance _grown(LootRules loot, RandomSource rng,
      ProfessionGearDef g, ItemInstance held, CropQuality q, FarmPlot plot,
      int extraAffix) {
    final il = (held.itemLevel + t.i('livingRegrowLevels'))
        .clamp(1, LootRules.maxLevel);
    final r = rarityOf(q).index > held.rarity.index ? rarityOf(q) : held.rarity;
    final base = baseFor(loot.catalog, g.type, il);
    var item = held.copyWith(
        itemLevel: il,
        baseId: base?.id,
        rarity: r,
        name: r == Rarity.legendario ? g.legend : g.name);
    if (r == Rarity.legendario && item.passiveId == null) {
      item = item.copyWith(passiveId: loot.rollPassiveId(rng, g.type));
    }
    final have = {for (final a in item.affixes) a.affixId};
    for (final m in compostMods(plot)) {
      if (have.contains(m.affixId) || item.affixes.length >= r.maxMods) {
        continue;
      }
      final (lo, hi) = ItemRules.fixedRangeAt(m, il);
      item = item.copyWith(affixes: [
        ...item.affixes,
        AffixRoll(m.affixId, 0, LootRules.rollValue(rng, lo, hi)),
      ]);
    }
    return loot.addRandomAffixes(rng, item, extraAffix);
  }

  /// A weapon seed found somewhere: a random kind; ancient with
  /// `seedAncientChance` (+ [ancientBonus]).
  static String rollSeed(RandomSource rng, {double ancientBonus = 0}) {
    final kinds = [
      for (final s in kWeaponSeeds.values)
        if (!s.ancient) s
    ];
    final s = _pick(rng, kinds);
    final old = rng() < t.d('seedAncientChance') + ancientBonus;
    return old ? '${s.id}_old' : s.id;
  }

  // ---------------- Pesca (§ 4) ----------------

  /// Chance that a weapon from the water is a sunken echo weapon at
  /// [depth] tiles from the shore (the Hondura sub-path adds).
  static double sunkenChance(PlayerProfile p, int depth) => math.min(
      0.95,
      t.d('sunkenShare') * (1 + LifeTreeRules.fish(p, LifeFx.chest)) +
          t.d('sunkenDepth') * math.max(0, depth));

  /// Chance a sunken chest also holds a sunken echo weapon.
  /// Fades with the fishing level (`sunkenChestFade` per level): the water
  /// loot already grows with it (fishing.md § 9), parity § 7.
  static double sunkenChestChance(PlayerProfile p) => (t.d('sunkenChestChance') *
          (1 - t.d('sunkenChestFade') * FishingRules.level(p)))
      .clamp(0.0, 0.95);

  /// Rarity of a sunken echo weapon: Legendary needs the legendary water
  /// gate (level and rod) and rises with the tree's `legend`.
  static Rarity sunkenRarity(RandomSource rng, PlayerProfile p) {
    final legend = t.d('sunkenLegend') +
        LifeTreeRules.fish(p, LifeFx.legend) * t.d('sunkenLegendTree');
    if (FishingRules.legendEligible(p) && rng() < legend) {
      return Rarity.legendario;
    }
    return rng() < t.d('sunkenEpic') ? Rarity.epico : Rarity.raro;
  }

  /// A sunken echo weapon for [p] at [itemLevel].
  static ItemInstance sunken(
          LootRules loot, RandomSource rng, PlayerProfile p, int itemLevel,
          {bool manual = true}) =>
      GearV2Rules.sunken(
          loot,
          rng,
          p,
          makeDef(loot, rng, _pick(rng, gearOf(GearSource.sunken)),
              sunkenRarity(rng, p), itemLevel),
          manual: manual);

  /// Why Brann can't forge [species] for [p] now (`null` = can).
  static FishForgeBlock? fishForgeBlock(PlayerProfile p, String species) {
    if (kFish[species]?.rarity != FishRarity.legendario) {
      return FishForgeBlock.notLegend;
    }
    if (p.life.count(species) < 1) return FishForgeBlock.noFish;
    if (FishingRules.level(p) < t.i('fishForgeLevel')) {
      return FishForgeBlock.level;
    }
    if (p.credits < t.i('fishForgeGold')) return FishForgeBlock.gold;
    return null;
  }

  /// Chance the fish forge comes out Legendary for [p].
  static double fishForgeLegend(PlayerProfile p) => math.min(
      1,
      t.d('fishForgeLegend') +
          LifeTreeRules.fish(p, LifeFx.legend) * t.d('fishForgeLegendTree'));

  /// es-AR name of the weapon forged from [species].
  static String fishForgeName(String species) =>
      '${kGearTypeNames[fishForgeType(species)] ?? 'Arma'} de '
      '${kFish[species]?.name ?? species}';

  /// Brann forges [species] into a weapon for [p] (§ 4.2): one fish and
  /// `fishForgeGold` gold. Epic, Legendary with [fishForgeLegend].
  static (PlayerProfile, ItemInstance)? fishForge(
      LootRules loot, RandomSource rng, PlayerProfile p, String species) {
    if (fishForgeBlock(p, species) != null) return null;
    final r = rng() < fishForgeLegend(p) ? Rarity.legendario : Rarity.epico;
    final il = LootRules.itemLevelFor(p.level, LootSource.chest);
    final item = make(loot, rng,
        gearId: fishForgeGearId(species),
        type: fishForgeType(species),
        signature: fishForgeSignature(species),
        rarity: r,
        itemLevel: il,
        name: fishForgeName(species));
    // v2 (profession_gear_v2.md § 4): affinity of the species, a
    // helper's quality (Brann does it).
    final touched = GearV2Rules.wholeFish(loot, rng, p, species, item);
    final paid = p.copyWith(
        credits: p.credits - t.i('fishForgeGold'),
        life: p.life
            .copyWith(bag: {...p.life.bag, species: p.life.count(species) - 1}));
    return (paid, touched);
  }

  // Fishing sub-paths (life_trees_v2.md § 2.1).

  /// × of the calm / auto-fishing wait (Calma A).
  static double calmMult(PlayerProfile p) =>
      1 - math.min(t.d('calmMax'), LifeTreeRules.fish(p, LifeFx.calm));

  /// Chance of a double catch (Calma B).
  static double twinChance(PlayerProfile p) =>
      math.min(t.d('twinMax'), LifeTreeRules.fish(p, LifeFx.twin));

  /// Size push toward the top of the range (Hondura B).
  static double bigBonus(PlayerProfile p) =>
      LifeTreeRules.fish(p, LifeFx.big).clamp(0.0, 1.0).toDouble();

  /// Raft net catches per [netEverySec] while sailing (Red B).
  static double netRate(PlayerProfile p) => LifeTreeRules.fish(p, LifeFx.net);

  /// × of the raft speed (Arpón A).
  static double raftMult(PlayerProfile p) =>
      1 + math.min(t.d('raftMax'), LifeTreeRules.fish(p, LifeFx.raft));

  /// Chance to harpoon a big fish from the raft at depth ≥
  /// `harpoonDepth` (Arpón B): one rarity up and the top size.
  static double harpoonChance(PlayerProfile p, int depth) =>
      depth >= t.i('harpoonDepth') ? LifeTreeRules.fish(p, LifeFx.harpoon) : 0;

  // ---------------- Herrería (§ 5) ----------------

  /// The forge-only weapon a forge at the town smithy turns into (or
  /// `null`): from `forgeGearLevel`, `forgeGearChance`.
  static ProfessionGearDef? forgeGear(RandomSource rng, PlayerProfile p) {
    if (SmithRules.level(p) < t.i('forgeGearLevel')) return null;
    if (rng() >= t.d('forgeGearChance')) return null;
    return _pick(rng, gearOf(GearSource.forge));
  }

  /// Forja B: a forged weapon sometimes gets one more affix, or (a share
  /// of those) one rarity up to Epic.
  static ItemInstance forgeAffix(
      LootRules loot, RandomSource rng, PlayerProfile p, ItemInstance item) {
    final c = LifeTreeRules.smith(p, LifeFx.forgeAffix);
    if (c <= 0 || rng() >= c) return item;
    if (rng() < t.d('forgeTierShare') &&
        item.rarity.index < Rarity.epico.index) {
      final up = Rarity.values[item.rarity.index + 1];
      var out = item.copyWith(rarity: up);
      if (up == Rarity.epico && out.passiveId == null) {
        final w = loot.catalog.weapons[item.baseId];
        if (w != null) out = out.copyWith(passiveId: loot.rollPassiveId(rng, w.type));
      }
      return loot.addRandomAffixes(rng, out, 1);
    }
    return loot.addRandomAffixes(rng, item, 1);
  }

  /// Extra veins one pickaxe blow breaks around the target (Veta A):
  /// 2 per area step, capped.
  static int veinArea(PlayerProfile p) => math.min(t.i('veinAreaMax'),
      2 * (LifeTreeRules.smith(p, LifeFx.veinArea) + 1e-6).floor());

  /// × of the pickaxe swing wait (Pico A).
  static double swingMult(PlayerProfile p) =>
      1 - math.min(t.d('mineSpeedMax'), LifeTreeRules.smith(p, LifeFx.mineSpeed));

  /// Tiles around the player where hidden veins glow (Pico B).
  static double detectRadius(PlayerProfile p) =>
      math.min(t.d('detectMax'), LifeTreeRules.smith(p, LifeFx.detect));

  /// Chance one smelt gives double ingots (Fundición A).
  static double smeltDouble(PlayerProfile p) =>
      math.min(0.9, LifeTreeRules.smith(p, LifeFx.smeltDouble));

  /// × of what salvaging returns (Fundición B).
  static double salvageMult(PlayerProfile p) =>
      1 + LifeTreeRules.smith(p, LifeFx.salvage);

  /// × of the gold an order pays (Encargos A).
  static double orderPayMult(PlayerProfile p) =>
      1 + LifeTreeRules.smith(p, LifeFx.orderPay);

  /// Extra chance an order brings a chest (Encargos B).
  static double orderChest(PlayerProfile p) =>
      LifeTreeRules.smith(p, LifeFx.orderChest);
}
