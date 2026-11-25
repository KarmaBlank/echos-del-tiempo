import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/gear_v2_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/profession_gear_rules.dart';

import 'session_test_helpers.dart';

/// Profession parity model (docs/specs/profession_gear.md § 7): the gear
/// (weapons by rarity) one hour of manual play of a profession yields at
/// a profession level, with a dedicated tree build. Uses the real rules
/// (water loot, sunken / fish-forged weapons, living weapon quality,
/// vein yield and forge costs) with a seeded RNG; the activity per hour
/// comes from the `parity*` keys of `kTuning[TuningId.gear]`.
class ParityResult {
  ParityResult(this.kind, this.level, this.perHour, this.score,
      {this.manual = true});
  final LifeSkillKind kind;
  final int level;
  final bool manual;

  /// Weapons per hour by rarity.
  final Map<Rarity, double> perHour;

  /// v2 (profession_gear_v2.md § 2): Σ weapons/h × `parityRarity<R>` ×
  /// (1 + expected extra slots × `parityExtraSlotW`).
  final double score;

  /// Rarity weight of the parity model.
  static double weight(Rarity r) {
    final t = tuning(TuningId.gear);
    return switch (r) {
      Rarity.raro => t.d('parityRarityRaro'),
      Rarity.epico => t.d('parityRarityEpico'),
      Rarity.legendario => t.d('parityRarityLegendario'),
      _ => 0,
    };
  }

  String row() => '${kind.name.padRight(9)} L${level.toString().padLeft(2)}  '
      'raro ${perHour[Rarity.raro]!.toStringAsFixed(2)}  '
      'épico ${perHour[Rarity.epico]!.toStringAsFixed(2)}  '
      'leg ${perHour[Rarity.legendario]!.toStringAsFixed(2)}  '
      'score ${score.toStringAsFixed(2)}';
}

int _xpFor(int Function(int) need, int level) {
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += need(l);
  }
  return xp;
}

/// Dedicated tree build of each profession, in taking order.
const kParityBuilds = <LifeSkillKind, List<String>>{
  // Hondura (chests, legend) on its main path, then Calma.
  LifeSkillKind.pesca: [
    'fish_b1', 'fish_b2', 'fish_b3', 'fish_b4', 'fish_b5', 'fish_b6',
    'fish_b7', 'fish_b8', 'fish_b9', 'fish_b10', 'fish_a1', 'fish_a2',
    'fish_a3', 'fish_a4s', 'fish_a5s', 'fish_a6s', 'fish_a7s',
  ],
  // Madera viva (rarity, then affixes), then Semilla's mutations.
  LifeSkillKind.cultivo: [
    'farm_d1', 'farm_d2', 'farm_d3', 'farm_d4', 'farm_d5', 'farm_d6',
    'farm_d7', 'farm_d8', 'farm_d9', 'farm_d10', 'farm_b1', 'farm_b2',
    'farm_b3', 'farm_b4s', 'farm_b5s', 'farm_b6s', 'farm_b7s',
  ],
  // Veta (area, then rare ore) and Forja's extra affixes.
  LifeSkillKind.herreria: [
    'smith_b1', 'smith_b2', 'smith_b3', 'smith_b4s', 'smith_b5s',
    'smith_b6s', 'smith_b7s', 'smith_b8', 'smith_a1', 'smith_a2',
    'smith_a3', 'smith_a4s', 'smith_a5s', 'smith_a6s', 'smith_a7s',
    'smith_a8', 'smith_a9',
  ],
};

/// A character of level [level] in [kind] (and as adventurer), with the
/// best rod for its level and the dedicated build.
PlayerProfile parityProfile(LifeSkillKind kind, int level) {
  final b = newProfile('Ana', 'guerrero');
  var p = b.copyWith(
      level: level,
      life: b.life.copyWith(
          fishXp: kind == LifeSkillKind.pesca
              ? _xpFor(FishingRules.xpNeed, level)
              : 0,
          smithXp: kind == LifeSkillKind.herreria
              ? _xpFor(SmithRules.xpNeed, level)
              : 0,
          farm: b.life.farm.copyWith(
              xp: kind == LifeSkillKind.cultivo
                  ? _xpFor(FarmingRules.xpNeed, level)
                  : 0)));
  if (kind == LifeSkillKind.pesca) {
    final rods = [
      for (final r in kRods.values)
        if (r.reqLevel <= level) r
    ]..sort((a, b) => a.rarity.index.compareTo(b.rarity.index));
    if (rods.isNotEmpty) {
      p = p.copyWith(
          life: p.life.copyWith(
              rods: [for (final r in rods) r.id], rod: rods.last.id));
    }
  }
  var changed = true;
  while (changed) {
    changed = false;
    for (final id in kParityBuilds[kind]!) {
      final next = LifeTreeRules.take(p, kind, id);
      if (next != null) {
        p = next;
        changed = true;
      }
    }
  }
  return p;
}

/// [hours] simulated hours of [kind] at [level] (seed [seed]); [manual]
/// false = the same hour done by helpers (auto-fishing, a farmhand's
/// harvest, Brann forging the parts).
ParityResult simulateParity(LifeSkillKind kind, int level,
    {int hours = 200, int seed = 7, bool manual = true}) {
  final rng = math.Random(seed * 1000 + level * 10 + kind.index);
  double rand() => rng.nextDouble();
  final p = parityProfile(kind, level);
  final t = tuning(TuningId.gear);
  const loot = LootRules();
  final got = {Rarity.raro: 0.0, Rarity.epico: 0.0, Rarity.legendario: 0.0};
  var score = 0.0;
  final slotW = tuning(TuningId.gearV2).d('parityExtraSlotW');
  // [q] = the v2 quality of the weapon (null: no v2 touch).
  void add(Rarity r, [double? q]) {
    if (!got.containsKey(r)) return;
    got[r] = got[r]! + 1;
    score += ParityResult.weight(r) *
        (1 + (q == null ? 0 : GearV2Rules.extraSlots(r, q)) * slotW);
  }

  for (var h = 0; h < hours; h++) {
    switch (kind) {
      case LifeSkillKind.pesca:
        _fishHour(p, t, rand, add, loot, manual);
      case LifeSkillKind.cultivo:
        _farmHour(p, t, rand, add, loot, manual);
      case LifeSkillKind.herreria:
        _smithHour(p, t, rand, add, manual);
    }
  }
  return ParityResult(kind, level,
      {for (final e in got.entries) e.key: e.value / hours}, score / hours,
      manual: manual);
}

typedef _Add = void Function(Rarity r, [double? q]);

void _fishHour(PlayerProfile p, TuningDef t, double Function() rand,
    _Add add, LootRules loot, bool manual) {
  final lv = FishingRules.level(p);
  final qSunken =
      GearV2Rules.quality(level: lv, materials: 0.8, manual: manual);
  final qFish = GearV2Rules.quality(level: lv, materials: 1, manual: manual);
  final n = (t.d('parityCatchesPerHour') * (1 - t.d('parityAutoShare')))
      .round();
  final rb = FishingRules.rodBonus(p);
  final il = LootRules.itemLevelFor(p.level, LootSource.chest);
  const depth = 2;
  var pity = 0;
  final lake = [for (final f in kFish.values) if (f.biome == 'zona1') f.id];
  for (var i = 0; i < n; i++) {
    final kind = FishingRules.rollLoot(rand, p, luck: rb.rare);
    switch (kind) {
      case WaterLootKind.arma:
        if (rand() < GearRules.sunkenChance(p, depth)) {
          add(GearRules.sunkenRarity(rand, p), qSunken);
        } else {
          add(loot.rollRarity(rand, il, LootSource.chest));
        }
      case WaterLootKind.cofre:
        if (rand() < GearRules.sunkenChestChance(p)) {
          add(GearRules.sunkenRarity(rand, p), qSunken);
        }
      case WaterLootKind.fish:
        final c = FishingRules.roll(rand, lake, rareBonus: rb.rare, pity: pity);
        pity = c.rarity == FishRarity.legendario ? 0 : pity + 1;
        // Every legendary goes to the fish forge (gold assumed).
        if (c.rarity == FishRarity.legendario &&
            FishingRules.level(p) >= t.i('fishForgeLevel')) {
          add(
              rand() < GearRules.fishForgeLegend(p)
                  ? Rarity.legendario
                  : Rarity.epico,
              qFish);
        }
      default:
    }
  }
}

void _farmHour(PlayerProfile p, TuningDef t, double Function() rand,
    _Add add, LootRules loot, bool manual) {
  // Weapon seeds of the hour: tree searches, orders, cave chests and the
  // mutations of the crop harvests of the other plots.
  var seeds = 0.0;
  seeds += t.d('parityTreeSearchesPerHour') * t.d('seedSearchChance');
  seeds += t.d('parityOrdersPerHour') * t.d('seedOrderChance');
  seeds += t.d('parityChestsPerHour') * t.d('seedMineChestChance');
  final cropHarvests = t.d('parityPlots') * 3600 / 300;
  seeds += cropHarvests *
      LifeTreeRules.farm(p, LifeFx.mutate) *
      t.d('seedMutateShare');
  // Plot capacity: one living weapon per plot per grow cycle.
  final cap = t.d('parityPlots') * 3600 / GearRules.growSec;
  var n = math.min(seeds, cap);
  final ancient = t.d('seedAncientChance');
  while (n > 0) {
    if (n < 1 && rand() >= n) break;
    n -= 1;
    final old = rand() < ancient;
    final lv = FarmingRules.level(p);
    // Dedicated care: three composts, the top one from level 20 on.
    final composts = lv >= 20
        ? {kTopCompost: 2, 'abono_brasa': 1}
        : lv >= 10
            ? {'abono_runico': 2, 'abono': 1}
            : {'abono': 3};
    final plot = FarmPlot(
        seed: old ? 'ws_arco_old' : 'ws_arco',
        grow: GearRules.growSec,
        wetGrow: GearRules.growSec,
        potential: FarmingRules.personScore(p, FarmingRules.hoeOf(p)),
        waterQ: FarmingRules.personScore(p, FarmingRules.canOf(p)),
        waterings: 4,
        composts: composts);
    final q = GearV2Rules.quality(
        level: lv, materials: old ? 1 : 0.5, manual: manual);
    add(GearRules.rarityOf(GearRules.quality(p, plot, rand())), q);
  }
}

void _smithHour(PlayerProfile p, TuningDef t, double Function() rand,
    _Add add, bool manual) {
  final lv = SmithRules.level(p);
  final biome = kBiomeOres.values
      .where((b) => b.tier <= 1 + lv ~/ 8)
      .reduce((a, b) => a.tier > b.tier ? a : b);
  // Veins of the hour; the Veta area breaks more per blow.
  final veins =
      t.d('parityVeinsPerHour') * (1 + GearRules.veinArea(p) * 0.5);
  var ore = 0, rares = 0;
  for (var i = 0; i < veins.round(); i++) {
    final y = MiningRules.veinYield(rand, biome.biome,
        rareBonus: LifeTreeRules.smith(p, LifeFx.rareOre));
    ore += y[biome.ore] ?? 0;
    rares += y[biome.rare] ?? 0;
  }
  final (per, _) = SmithCraftRules.smeltCost(biome.ore)!;
  var ingots = ore ~/ per;
  ingots += (ingots * GearRules.smeltDouble(p)).round();
  // v2 forge by parts (profession_gear_v2.md § 3): base + head + grip of
  // the best ingot, a biome rare as setting; rarity by quality, capped by
  // the smith level (Legendary needs a boss recipe: not part of an hour).
  final v2 = tuning(TuningId.gearV2);
  final perWeapon = v2.i('partsBaseIngots') + 2;
  final q = (GearV2Rules.quality(
              level: lv, materials: biome.tier / 5, manual: manual) +
          v2.d('settingQ'))
      .clamp(0.0, 1.0)
      .toDouble();
  var r = GearV2Rules.rarityForQ(q);
  final cap = SmithCraftRules.maxRarity(lv);
  if (r.index > cap.index) r = cap;
  if (r == Rarity.legendario) r = Rarity.epico;
  var n = ingots ~/ perWeapon;
  n = math.min(n, rares);
  for (var i = 0; i < n; i++) {
    // Forja B: sometimes one rarity up (Epic tops it).
    final up = rand() < LifeTreeRules.smith(p, LifeFx.forgeAffix) &&
        rand() < t.d('forgeTierShare') &&
        r.index < Rarity.epico.index;
    add(up ? Rarity.values[r.index + 1] : r, q);
  }
}
