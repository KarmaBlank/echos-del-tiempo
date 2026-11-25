import 'dart:math' as math;

import '../data/branch_ults_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/gear_v2_catalog.dart';
import '../data/smithing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../data/ults_v2_catalog.dart';
import '../data/weapon_elements_catalog.dart' show rarityAllowsElement;
import '../models/elements.dart';
import '../models/item.dart';
import '../models/loot.dart' show LootSource;
import '../models/player_profile.dart';
import '../models/ult_def.dart' show UltSource;
import 'battle_engine.dart' show RandomSource;
import 'farming_rules.dart';
import 'fishing_rules.dart';
import 'life_tree_rules.dart' show SmithRules;
import 'loot_rules.dart';
import 'mining_rules.dart';
import 'profession_gear_rules.dart';

export '../data/gear_v2_catalog.dart';

/// Why the forge by parts can't run (profession_gear_v2.md § 3).
enum PartsBlock { badType, badPart, noMaterials, noGold }

/// Why Brann can't take a fish apart (§ 4).
enum FishSplitBlock { notMagic, noFish, level, gold }

/// What a forge by parts costs and gives (§ 3).
class PartsPlan {
  const PartsPlan(
      {required this.need,
      required this.gold,
      required this.itemLevel,
      required this.quality,
      required this.rarity,
      required this.affinity,
      required this.masterwork,
      required this.recipe});

  /// Materials (ingots, fish parts, rares, recipe) taken.
  final Map<String, int> need;
  final int gold;
  final int itemLevel;
  final double quality;
  final Rarity rarity;
  final GameElement affinity;
  final bool masterwork;

  /// A Legendary that takes a Plano antiguo / Núcleo de guardián.
  final bool recipe;
}

/// Profession gear v2 (docs/specs/profession_gear_v2.md): affinity, quality
/// and slots, the forge by parts, fish taken apart and the v2 touch of
/// living / fish weapons. Pure; numbers in `kTuning[TuningId.gearV2]`.
abstract final class GearV2Rules {
  static TuningDef get t => tuning(TuningId.gearV2);

  // ---------------- quality and slots (§ 2) ----------------

  /// Quality q (0..1): profession level, material quality (0..1) and the
  /// hand ([manual] false = a helper did it).
  static double quality(
      {required int level, required double materials, required bool manual}) {
    final lv = level / math.max(1, t.d('slotLevelCap'));
    final hand = manual ? 1.0 : t.d('autoQualityShare');
    return (math.min(1.0, lv) * t.d('slotLevelW') +
            materials.clamp(0.0, 1.0) * t.d('slotMatW') +
            hand * t.d('slotManualW'))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// Mods of a [r] item of quality [q] (without the masterwork one): the
  /// minimum plus `q × span`, the fraction as a chance of one more.
  static int rollMods(RandomSource rng, Rarity r, double q) {
    final x = q.clamp(0.0, 1.0) * (r.maxMods - r.minMods);
    final n = x.floor() + (rng() < x - x.floor() ? 1 : 0);
    return math.min(r.maxMods, r.minMods + n);
  }

  /// Whether quality [q] makes a masterwork (+1 mod, never more).
  static bool masterworkFor(Rarity r, double q) =>
      r.maxMods > 0 && q >= t.d('masterworkQ') - 1e-9;

  /// Expected mods over the rarity's minimum (the parity's "extra
  /// slots"), masterwork included.
  static double extraSlots(Rarity r, double q) =>
      q.clamp(0.0, 1.0) * (r.maxMods - r.minMods) +
      (masterworkFor(r, q) ? 1 : 0);

  /// Rarity the forge by parts reaches with [q].
  static Rarity rarityForQ(double q) {
    if (q >= t.d('forgeQLegend')) return Rarity.legendario;
    if (q >= t.d('forgeQEpico')) return Rarity.epico;
    if (q >= t.d('forgeQRaro')) return Rarity.raro;
    if (q >= t.d('forgeQMagico')) return Rarity.magico;
    return Rarity.comun;
  }

  /// Quality (0..1) of one material: tier / 5; fish parts Epic 0.8,
  /// Legendary 1.
  static double materialQ(String id) {
    if (parseFishPart(id) case (final sp, _)?) {
      return kFish[sp]?.rarity == FishRarity.legendario ? 1 : 0.8;
    }
    final d = kSmithMaterials[id];
    return d == null ? 0 : (d.tier / 5).clamp(0.0, 1.0).toDouble();
  }

  // ---------------- affinity (§ 1) ----------------

  /// Affinity of a parts list (§ 7): the setting's if any, else the base.
  static GameElement partsAffinity(List<String> pt) {
    if (pt.isEmpty) return GameElement.fisico;
    if (pt.length >= 2 &&
        (pt[0] == 'living' || pt[0] == 'v1')) {
      return GameElement.values.asNameMap()[pt[1]] ?? GameElement.fisico;
    }
    if (pt[0] == 'fish' && pt.length >= 2) return fishAffinity(pt[1]);
    if (pt.length >= 4) {
      final s = pt[3];
      if (kRareAffinity[s] case final e?) return e;
      if (parseFishPart(s) case (final sp, FishPart.essence)?) {
        return fishAffinity(sp);
      }
    }
    return kIngotAffinity[pt[0]] ?? GameElement.fisico;
  }

  /// Affinity of [i] (its parts, else its element, else physical).
  static GameElement affinityOf(ItemInstance i) => i.parts.isNotEmpty
      ? partsAffinity(i.parts)
      : i.element ?? GameElement.fisico;

  /// Affinity of a living plot: its most-used elemental compost.
  static GameElement livingAffinity(Map<String, int> composts) {
    GameElement? best;
    var n = 0;
    for (final e in composts.entries) {
      final a = kCompostAffinity[e.key];
      if (a != null && e.value > n) {
        best = a;
        n = e.value;
      }
    }
    return best ?? GameElement.fisico;
  }

  /// The existing ULTs a [type] weapon of affinity [aff] can roll (§ 1):
  /// path ULTs of the type and, on a Legendary, the legendary v2 ULTs of
  /// the type, whose element is [aff]. Empty match → the type's own pool
  /// (or every path ULT of the type).
  static List<String> ultPool(String type, GameElement aff, Rarity r) {
    final all = [
      ...branchUltsForType(type),
      if (r == Rarity.legendario)
        for (final u in kUltV2List)
          if (u.source == UltSource.unique && u.weapons.contains(type)) u.id,
    ];
    final match = [
      for (final id in all)
        if (kBranchUltElement[id] == aff) id
    ];
    if (match.isNotEmpty) return match;
    final own = ultV2ModsForType(type);
    return own.isNotEmpty ? own : all;
  }

  /// A ULT for a profession weapon of [r] (or `null`): the usual mod
  /// chance on Rare / Epic, `legendUltChance` on a Legendary.
  static String? rollUlt(
      RandomSource rng, String type, GameElement aff, Rarity r) {
    final chance = switch (r) {
      Rarity.raro => kBranchUltChanceRare,
      Rarity.epico => kBranchUltChanceEpic,
      Rarity.legendario => t.d('legendUltChance'),
      _ => 0.0,
    };
    if (chance <= 0 || rng() >= chance) return null;
    final pool = ultPool(type, aff, r);
    if (pool.isEmpty) return null;
    return pool[(rng() * pool.length).floor().clamp(0, pool.length - 1)];
  }

  /// [item] with the v2 touch: [parts], element of [aff] (Rare up, not
  /// physical), mods up to what [q] gives (+1 masterwork) and a ULT from
  /// the affinity pool. Never removes a mod it already has.
  static ItemInstance touch(LootRules loot, RandomSource rng,
      ItemInstance item, String type,
      {required List<String> parts,
      required GameElement aff,
      required double q}) {
    final r = item.rarity;
    final mw = masterworkFor(r, q);
    var out = item.copyWith(
        parts: parts,
        masterwork: mw,
        element: aff != GameElement.fisico && rarityAllowsElement(r) ? aff : null,
        clearElement: aff == GameElement.fisico || !rarityAllowsElement(r));
    final want = rollMods(rng, r, q) + (mw ? 1 : 0);
    if (out.affixes.length < want) {
      out = loot.addRandomAffixes(rng, out, want - out.affixes.length);
    }
    final u = rollUlt(rng, type, aff, r);
    return u == null ? out.copyWith(clearUlt: true) : out.copyWith(ultId: u);
  }

  // ---------------- forge by parts (§ 3) ----------------

  /// Whether [id] fits the [slot] step.
  static bool fits(PartSlot slot, String id) {
    final d = kSmithMaterials[id];
    final fish = parseFishPart(id);
    return switch (slot) {
      PartSlot.base => d?.kind == SmithMatKind.ingot,
      PartSlot.head =>
        d?.kind == SmithMatKind.ingot || fish?.$2 == FishPart.scale,
      PartSlot.grip =>
        d?.kind == SmithMatKind.ingot || fish?.$2 == FishPart.bone,
      PartSlot.setting =>
        d?.kind == SmithMatKind.rare || fish?.$2 == FishPart.essence,
    };
  }

  /// The plan for [p] forging a [type] from [parts] (`[base, head, grip,
  /// setting?]`), or `null` if the parts don't fit.
  static PartsPlan? plan(PlayerProfile p, String type, List<String> parts) {
    if (!kForgeWeaponTypes.contains(type)) return null;
    if (parts.length < 3 || parts.length > 4) return null;
    for (var i = 0; i < parts.length; i++) {
      if (!fits(PartSlot.values[i], parts[i])) return null;
    }
    final need = <String, int>{};
    void add(String id, int n) => need[id] = (need[id] ?? 0) + n;
    add(parts[0], math.max(1, t.i('partsBaseIngots')));
    for (final x in parts.skip(1)) {
      add(x, 1);
    }
    final setting = parts.length == 4;
    final mats = parts.map(materialQ).reduce((a, b) => a + b) / parts.length;
    final q = (quality(
                level: SmithRules.level(p), materials: mats, manual: true) +
            (setting ? t.d('settingQ') : 0))
        .clamp(0.0, 1.0)
        .toDouble();
    final cap = SmithCraftRules.maxRarity(SmithRules.level(p));
    var r = rarityForQ(q);
    if (r.index > cap.index) r = cap;
    final hasRecipe =
        p.life.ore(kSchematic) > 0 || p.life.ore(kGuardianCore) > 0;
    if (r == Rarity.legendario && !hasRecipe) r = Rarity.epico;
    final recipe = r == Rarity.legendario;
    if (recipe) {
      add(p.life.ore(kSchematic) > 0 ? kSchematic : kGuardianCore, 1);
    }
    final il = SmithCraftRules.itemLevel(p.level, parts[0]);
    return PartsPlan(
        need: need,
        gold: SmithCraftRules.t.i('craftGoldPerIl') * il,
        itemLevel: il,
        quality: q,
        rarity: r,
        affinity: partsAffinity(parts),
        masterwork: masterworkFor(r, q),
        recipe: recipe);
  }

  /// Why [p] can't forge [type] from [parts] now (`null` = can).
  static PartsBlock? cannotForge(
      PlayerProfile p, String type, List<String> parts) {
    if (!kForgeWeaponTypes.contains(type)) return PartsBlock.badType;
    final pl = plan(p, type, parts);
    if (pl == null) return PartsBlock.badPart;
    for (final e in pl.need.entries) {
      if (p.life.ore(e.key) < e.value) return PartsBlock.noMaterials;
    }
    if (p.credits < pl.gold) return PartsBlock.noGold;
    return null;
  }

  /// Forges [type] from [parts] for [p]: (paid profile, weapon) or `null`.
  static (PlayerProfile, ItemInstance)? forge(LootRules loot,
      RandomSource rng, PlayerProfile p, String type, List<String> parts) {
    if (cannotForge(p, type, parts) != null) return null;
    final pl = plan(p, type, parts)!;
    final paid = MiningRules.give(
            p, {for (final e in pl.need.entries) e.key: -e.value})
        .copyWith(credits: p.credits - pl.gold);
    final base = GearRules.baseFor(loot.catalog, type, pl.itemLevel) ??
        loot.catalog.weapons.values.first;
    final il = math.max(pl.itemLevel, base.level);
    final r = pl.rarity;
    var item = loot.generate(rng,
        itemLevel: il,
        rarity: r == Rarity.legendario ? Rarity.epico : r,
        baseId: base.id,
        source: LootSource.chest);
    if (r == Rarity.legendario) {
      item = item.copyWith(
          rarity: Rarity.legendario,
          passiveId: item.passiveId ?? loot.rollPassiveId(rng, base.type));
    }
    item = item.copyWith(
        uid: GearRules.uidFor('$kPartsGearPrefix${gearTypeKey(type)}'),
        name: partsName(type, parts[0]),
        affixes: item.affixes.take(r.minMods).toList());
    item = touch(loot, rng, item, type,
        parts: parts, aff: pl.affinity, q: pl.quality);
    return (paid, item);
  }

  /// es-AR name of a weapon forged by parts ("Espada de cobre").
  static String partsName(String type, String baseIngot) =>
      '${kGearTypeNames[type] ?? type} de ${metalName(baseIngot)}';

  /// es-AR metal of an ingot ("cobre"; `data.items.gear.metal.<id>`).
  static String metalName(String ingot) {
    final m = kSmithMaterials[ingot]?.name ?? ingot;
    return m.startsWith('Lingote de ') ? m.substring(11) : m;
  }

  /// Weapon type of a weapon forged by parts (`null` if it isn't one).
  static String? partsType(ItemInstance i) {
    final id = GearRules.gearIdOf(i);
    if (id == null || !id.startsWith(kPartsGearPrefix)) return null;
    final k = id.substring(kPartsGearPrefix.length);
    for (final t in kForgeWeaponTypes) {
      if (gearTypeKey(t) == k) return t;
    }
    return null;
  }

  // ---------------- fish taken apart (§ 4) ----------------

  /// What taking one [species] apart yields (`{}` if it can't be).
  static Map<String, int> splitYield(String species) {
    final r = kFish[species]?.rarity;
    final legend = r == FishRarity.legendario;
    if (r != FishRarity.epico && !legend) return const {};
    return {
      fishPartId(species, FishPart.scale):
          t.i(legend ? 'fishScaleLegend' : 'fishScaleEpic'),
      fishPartId(species, FishPart.bone): t.i('fishBone'),
      fishPartId(species, FishPart.essence):
          t.i(legend ? 'fishEssenceLegend' : 'fishEssenceEpic'),
    };
  }

  /// Why Brann can't take [species] apart for [p] (`null` = can).
  static FishSplitBlock? cannotSplit(PlayerProfile p, String species) {
    if (splitYield(species).isEmpty) return FishSplitBlock.notMagic;
    if (p.life.count(species) < 1) return FishSplitBlock.noFish;
    if (FishingRules.level(p) < t.i('fishPartLevel')) {
      return FishSplitBlock.level;
    }
    if (p.credits < t.i('fishPartGold')) return FishSplitBlock.gold;
    return null;
  }

  /// [p] after Brann takes one [species] apart: the fish is gone, the
  /// parts are in the smithing materials. `null` if he can't.
  static PlayerProfile? split(PlayerProfile p, String species) {
    if (cannotSplit(p, species) != null) return null;
    final bag = {...p.life.bag, species: p.life.count(species) - 1};
    if (bag[species]! <= 0) bag.remove(species);
    final out = p.copyWith(
        credits: p.credits - t.i('fishPartGold'),
        life: p.life.copyWith(bag: bag));
    return MiningRules.give(out, splitYield(species), source: 'fish');
  }

  // ---------------- living and whole-fish weapons (§ 4, § 5) ----------------

  /// The v2 touch of a living weapon grown in [plot] and harvested by
  /// [harvester]: affinity of its composts, quality of the seed and the
  /// hand (the planter harvesting it = by hand).
  static ItemInstance living(LootRules loot, RandomSource rng,
      PlayerProfile harvester, FarmPlot plot, ItemInstance item) {
    final def = GearRules.defOf(item);
    if (def == null) return item;
    final aff = livingAffinity(plot.composts);
    final q = quality(
        level: FarmingRules.level(harvester),
        materials: GearRules.ancient(plot) ? 1 : 0.5,
        manual: plot.planter == null || plot.planter == harvester.name);
    return touch(loot, rng, item, def.type,
        parts: ['living', aff.name], aff: aff, q: q);
  }

  /// The v2 touch of a sunken echo weapon: affinity of its signature,
  /// the fishing level and the hand ([manual] false = auto-fishing).
  static ItemInstance sunken(LootRules loot, RandomSource rng,
      PlayerProfile p, ItemInstance item, {required bool manual}) {
    final def = GearRules.defOf(item);
    if (def == null) return item;
    final aff = _signatureAffinity(def.signature.affixId);
    final q = quality(
        level: FishingRules.level(p), materials: 0.8, manual: manual);
    return touch(loot, rng, item, def.type,
        parts: ['v1', aff.name], aff: aff, q: q);
  }

  /// The v2 touch of a weapon Brann forges from a whole legendary fish
  /// (a helper's hand).
  static ItemInstance wholeFish(LootRules loot, RandomSource rng,
      PlayerProfile p, String species, ItemInstance item) {
    final q = quality(
        level: FishingRules.level(p), materials: 1, manual: false);
    return touch(loot, rng, item, fishForgeType(species),
        parts: ['fish', species], aff: fishAffinity(species), q: q);
  }

  // ---------------- migration (§ 8) ----------------

  /// A v1 profession weapon gets `pt = ['v1', <affinity>]` (from its
  /// element, else its signature); everything else stays.
  static ItemInstance migrate(ItemInstance i) {
    if (i.parts.isNotEmpty || !GearRules.isGear(i)) return i;
    final fish = GearRules.fishOf(i);
    final aff = i.element ??
        (fish != null
            ? fishAffinity(fish)
            : _signatureAffinity(GearRules.defOf(i)?.signature.affixId));
    return i.copyWith(parts: ['v1', aff.name]);
  }

  static GameElement _signatureAffinity(String? affix) => switch (affix) {
        'gelido' => GameElement.hielo,
        'abrasador' => GameElement.fuego,
        'runico' || 'arcano' => GameElement.electro,
        'de_la_vida' => GameElement.sagrado,
        _ => GameElement.fisico,
      };
}
