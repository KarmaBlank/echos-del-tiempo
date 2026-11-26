import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/animal_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Income parity of the Granjero reform (animals.md § 7): one hour of
/// only crops, only animals or both pays the same Granjero XP and gold
/// (± `incomeBand`); fishing and mining + smithing are reported beside
/// them. Activity per hour comes from the `income*` keys of
/// `kTuning[TuningId.gear]`; everything else is the real rules and
/// catalogs, with seeded rolls. No tree (the bonuses are tested apart).
typedef Income = ({double xp, double gold});

TuningDef get _g => tuning(TuningId.gear);

/// Expected quality multiplier of a crop with no care bonus (S = 0).
double _cropMult() {
  final f = FarmingRules.t;
  var w = 0.0, m = 0.0;
  for (final q in CropQuality.values) {
    final wq = f.d('wQ${q.key}');
    w += wq;
    m += wq * f.d('qualityMult${q.key}');
  }
  return m / w;
}

/// Crops: `incomePlots` plots of the town's common all-year crops, a
/// round every grow time + `incomeCropLoopSec`; plant and water give
/// work XP, the harvest its XP and price, minus the seed.
Income cropsHour() {
  final crops = [
    for (final c in kCrops.values)
      if (c.biome == kFarmStartBiome &&
          c.rarity == FishRarity.comun &&
          c.seasons.length > 1)
        c
  ];
  final m = _cropMult();
  final work = 2 * FarmingRules.t.i('workXp');
  var xp = 0.0, gold = 0.0;
  for (final c in crops) {
    final perH = 3600 / (c.growSec + _g.d('incomeCropLoopSec'));
    xp += perH * (work + c.xp * FarmingRules.t.d('xp${c.rarity.key}') * m);
    gold += perH * (c.price * m - c.seedPrice);
  }
  final plots = _g.d('incomePlots');
  return (xp: xp / crops.length * plots, gold: gold / crops.length * plots);
}

/// One animal of [species] cared for by hand every day for [days] days
/// from `incomeHearts` hearts (bought hay): XP and gold per animal-day.
Income animalDay(String species, {int days = 60, int seeds = 40}) {
  var xp = 0.0, gold = 0.0;
  for (var s = 0; s < seeds; s++) {
    final r = math.Random(s);
    final d = kAnimals[species]!;
    var b = TownBuild('x0', d.home,
        [TownRect(0, 0, kAnimalHomes[d.home]!.w, kAnimalHomes[d.home]!.h)],
        animals: [
          FarmAnimal(0, species, aff: _g.i('incomeHearts') * 100)
        ]);
    final base = newProfile('Ana', 'guerrero');
    var p = base.copyWith(
        life: base.life.copyWith(
            farm: base.life.farm.copyWith(
                hay: 999, rtools: [for (final t in RanchTool.values) t.id])));
    for (var day = 1; day <= days; day++) {
      if (AnimalRules.collectBy(p, b, 0, r.nextDouble) case final c?) {
        b = c.build;
        xp += c.xp;
        for (final k in c.goods) {
          gold += AnimalRules.unitPrice(k);
        }
      }
      final f = AnimalRules.feed(p, b, 0, day)!;
      p = f.$1;
      b = f.$2;
      xp += f.$3;
      gold -= AnimalRules.hayPrice;
      final pt = AnimalRules.petBy(p, b, 0, day, r.nextDouble)!;
      b = pt.$1;
      xp += pt.$2;
      b = AnimalRules.onDay(b, day + 1, r.nextDouble);
    }
  }
  return (xp: xp / days / seeds, gold: gold / days / seeds);
}

/// Animals: `3600 / incomeAnimalCareSec` animal-days per hour, the
/// species averaged (a mixed ranch).
Income animalsHour() {
  final perH = 3600 / _g.d('incomeAnimalCareSec');
  var xp = 0.0, gold = 0.0;
  for (final sp in kAnimals.keys) {
    final d = animalDay(sp);
    xp += d.xp;
    gold += d.gold;
  }
  final n = kAnimals.length;
  return (xp: xp / n * perH, gold: gold / n * perH);
}

/// Fishing at the town lake: `incomeCatchesPerHour` real rolls.
Income fishingHour() {
  final r = math.Random(5);
  final lake = [
    for (final f in kFish.values)
      if (f.biome == kTownStartBiome) f.id
  ];
  const n = 20000;
  var xp = 0.0, gold = 0.0;
  for (var i = 0; i < n; i++) {
    final c = FishingRules.roll(r.nextDouble, lake);
    xp += FishingRules.fishXp(c);
    gold += c.def.price;
  }
  final perH = _g.d('incomeCatchesPerHour');
  return (xp: xp / n * perH, gold: gold / n * perH);
}

/// Mining + smithing in the first biome: veins (and other tiles) of the
/// hour, the ore smelted and sold as ingots, the rares sold.
Income miningHour() {
  final r = math.Random(9);
  final b = kBiomeOres.values.first;
  const n = 20000;
  var ore = 0, rare = 0;
  for (var i = 0; i < n; i++) {
    final y = MiningRules.veinYield(r.nextDouble, b.biome);
    ore += y[b.ore] ?? 0;
    rare += y[b.rare] ?? 0;
  }
  final veins = _g.d('incomeVeinsPerHour');
  final (per, smeltGold) = SmithCraftRules.smeltCost(b.ore)!;
  final ingots = ore / n * veins / per;
  final xp = veins * MiningRules.veinXp(b.biome) +
      _g.d('incomeDigPerHour') * MiningRules.t.i('digXp') +
      SmithCraftRules.smeltXp(b.ore, 1) * ingots;
  final gold = ingots * (SmithCraftRules.sellPrice(b.ingot) - smeltGold) +
      rare / n * veins * SmithCraftRules.sellPrice(b.rare);
  return (xp: xp, gold: gold);
}

String _row(String name, Income i) =>
    '${name.padRight(22)} ${i.xp.round().toString().padLeft(5)} XP/h  '
    '${i.gold.round().toString().padLeft(5)} oro/h';

void main() {
  test('crops only, animals only and both pay the same per hour', () {
    final crops = cropsHour();
    final animals = animalsHour();
    final both = (
      xp: (crops.xp + animals.xp) / 2,
      gold: (crops.gold + animals.gold) / 2,
    );
    final fish = fishingHour();
    final mine = miningHour();
    final report = StringBuffer()
      ..writeln(_row('Granjero: cultivos', crops))
      ..writeln(_row('Granjero: animales', animals))
      ..writeln(_row('Granjero: ambos', both))
      ..writeln(_row('Pesca', fish))
      ..writeln(_row('Minería + herrería', mine));
    for (final sp in kAnimals.keys) {
      final d = animalDay(sp);
      report.writeln('  ${sp.padRight(8)} por animal y día: '
          '${d.xp.toStringAsFixed(1)} XP, ${d.gold.toStringAsFixed(1)} oro');
    }
    // ignore: avoid_print
    print(report);
    final band = _g.d('incomeBand');
    for (final (name, i) in [('animales', animals), ('ambos', both)]) {
      expect((i.xp / crops.xp - 1).abs(), lessThanOrEqualTo(band),
          reason: '$name XP\n$report');
      expect((i.gold / crops.gold - 1).abs(), lessThanOrEqualTo(band),
          reason: '$name oro\n$report');
    }
  });

  test('every species alone stays near the ranch average', () {
    final days = {for (final sp in kAnimals.keys) sp: animalDay(sp)};
    final xp = days.values.fold(0.0, (a, d) => a + d.xp) / days.length;
    final gold = days.values.fold(0.0, (a, d) => a + d.gold) / days.length;
    for (final e in days.entries) {
      expect((e.value.xp / xp - 1).abs(), lessThan(0.25), reason: e.key);
      expect((e.value.gold / gold - 1).abs(), lessThan(0.25), reason: e.key);
    }
  });

  test('no daily XP cap on animals any more', () {
    expect(AnimalRules.t.i('xpDayCap'), 0);
    expect(AnimalRules.capXp(10000, 50), 50);
  });
}
