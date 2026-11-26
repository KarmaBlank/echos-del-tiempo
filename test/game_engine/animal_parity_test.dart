import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/animal_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Parity of the ranch (animals.md § 6, profession_gear_v2.md § 2): the
/// owner's own care yields at least `parityManualEdge` × a ranch helper
/// in gold per day, both from a fresh animal over 30 world days and in
/// steady state (manual at full hearts, helper at its cap). Deterministic.
({double gold, int xp}) simulate(String species,
    {required bool manual, int days = 30, int aff0 = 0, int seed = 11}) {
  final r = math.Random(seed);
  final d = kAnimals[species]!;
  final home = d.home;
  var b = TownBuild('x0', home,
      [TownRect(0, 0, kAnimalHomes[home]!.w, kAnimalHomes[home]!.h)],
      animals: [FarmAnimal(0, species, aff: aff0)],
      hay: manual ? 0 : 999,
      helper: manual ? 0 : 1);
  final base = newProfile('Ana', 'guerrero');
  var p = base.copyWith(
      life: base.life.copyWith(
          farm: base.life.farm.copyWith(
              hay: 999, rtools: [for (final t in RanchTool.values) t.id])));
  var gold = 0.0;
  var xp = 0;
  for (var day = 1; day <= days; day++) {
    if (manual) {
      if (AnimalRules.collect(p, b, 0) case final c?) {
        b = c.$1;
        gold += AnimalRules.unitPrice(c.$2);
        xp += c.$3;
      }
      final f = AnimalRules.feed(p, b, 0, day)!;
      p = f.$1;
      b = f.$2;
      b = AnimalRules.pet(b, 0, day)!.$1;
    } else {
      b = AnimalRules.helperCare(
          b, day, (bb, k) => TownRules.addToChest(bb, k, 1));
      for (final e in b.chest.entries) {
        gold += AnimalRules.unitPrice(e.key) * e.value;
      }
      b = b.copyWith(chest: const {});
    }
    b = AnimalRules.onDay(b, day + 1, r.nextDouble);
  }
  return (gold: gold / days, xp: xp);
}

void main() {
  final edge = tuning(TuningId.gearV2).d('parityManualEdge');

  test('manual care ≥ parityManualEdge × the ranch helper', () {
    final report = StringBuffer();
    final fails = <String>[];
    for (final sp in kAnimals.keys) {
      // Averaged over seeds so the quality rolls even out.
      double avg(bool manual, int days, int aff0) {
        var g = 0.0;
        for (var s = 0; s < 40; s++) {
          g += simulate(sp, manual: manual, days: days, aff0: aff0, seed: s)
              .gold;
        }
        return g / 40;
      }

      final m30 = avg(true, 30, 0), h30 = avg(false, 30, 0);
      final mSs = avg(true, 60, AnimalRules.affMax);
      final hSs = avg(false, 60, AnimalRules.helperAffCap);
      report.writeln('${sp.padRight(8)} 30 días: manual '
          '${m30.toStringAsFixed(1)} ayudante ${h30.toStringAsFixed(1)} '
          'x${(m30 / h30).toStringAsFixed(2)} · régimen: '
          'x${(mSs / hSs).toStringAsFixed(2)}');
      if (m30 / h30 < edge) fails.add('$sp 30d');
      if (mSs / hSs < edge) fails.add('$sp steady');
    }
    // ignore: avoid_print
    print(report);
    expect(fails, isEmpty, reason: '$report');
  });

  test('the expected quality multiplier keeps the edge in steady state', () {
    final m = AnimalRules.expectedMult(AnimalRules.maxHearts);
    final h = AnimalRules.expectedMult(
        AnimalRules.t.i('helperHeartCap'));
    expect(m / h, greaterThanOrEqualTo(edge));
  });

  // The old daily XP cap is gone (v0.50, animals.md § 7): the hourly
  // parity with crops lives in granjero_parity_test.
}
