import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Granjeros, pescadores y cofres (farming.md § 8, v0.25.5).

FarmPlot _ripe() {
  final p = FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!;
  return p.copyWith(
      grow: FarmingRules.growSec('nabo_claro'),
      wetGrow: FarmingRules.growSec('nabo_claro'));
}

Harvest _harvest(FarmPlot pl) => FarmingRules.harvest(
    () => 0.5, newProfile('Ana', 'guerrero'), pl,
    helper: true)!;

void main() {
  test('el granjero solo planta de sus semillas', () {
    var b = kBaseFarm.copyWith(helper: 1);
    expect(TownRules.farmerNext(b, 0), isNull, reason: 'sin semillas descansa');
    b = b.copyWith(seeds: {'nabo_claro': 3});
    expect(TownRules.farmerNext(b, 0), HelperTask.plantar);
    final (out, hs) = TownRules.farmerCycle(b, 0, _harvest);
    expect(hs, isEmpty);
    expect(out.plots.values.where((p) => p.planted), hasLength(3));
    expect(out.seeds, isEmpty);
  });

  test('una sola tarea por vuelta, en orden plantar → regar → cosechar', () {
    final dry = FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!;
    var b = kBaseFarm.copyWith(helper: 1, seeds: {'nabo_claro': 1}, plots: {
      '0,0': FarmingRules.till(),
      '1,0': dry,
      '2,0': _ripe(),
    });
    // Vuelta 1: planta (el maduro, sin cosechar). Además riega solo
    // (farming.md § 8.2, v0.45.0): lo seco queda regado.
    (b, _) = TownRules.farmerCycle(b, 0, _harvest);
    expect(b.plots['1,0']!.watered, isTrue);
    expect(b.plots['0,0']!.watered, isTrue);
    expect(FarmingRules.ripe(b.plots['2,0']!), isTrue);
    expect(b.seeds, isEmpty);
    // Vuelta 2: cosecha al cofre (nada para regar con la tarea).
    expect(TownRules.farmerNext(b, 0), HelperTask.cosechar);
    final List<(int, int, Harvest)> hs;
    (b, hs) = TownRules.farmerCycle(b, 0, _harvest);
    expect(hs, hasLength(1));
    expect(b.chestTotal, greaterThan(0));
    // Con regar apagado, salta a cosechar.
    final off = b.copyWith(tasks: [HelperTask.cosechar.bit]);
    expect(TownRules.farmerNext(off, 0), isNull);
  });

  test('el granjero riega solo aunque tenga regar apagado', () {
    final dry = FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!;
    var b = kBaseFarm.copyWith(
        helper: 1, tasks: [HelperTask.cosechar.bit], plots: {'1,0': dry});
    expect(TownRules.farmerNext(b, 0), isNull);
    (b, _) = TownRules.farmerCycle(b, 0, _harvest);
    expect(b.plots['1,0']!.watered, isTrue);
    expect(b.plots['1,0']!.waterer, 'Granjero');
  });

  test('recoger el cofre pasa todo a la bolsa PESCA Y CULTIVO', () {
    final key = cropKey('nabo_claro', CropQuality.normal);
    final town = const TownState().copyWith(builds: [
      kBaseLake.copyWith(chest: {'mojarra_claro': 2}),
      kBaseFarm.copyWith(chest: {key: 4}),
    ]);
    final p = newProfile('Ana', 'guerrero');
    final (p1, t1) = TownRules.collectChest(p, town, 'h0')!;
    expect(p1.life.farm.crops[key], 4);
    expect(t1.build('h0')!.chest, isEmpty);
    final (p2, t2) = TownRules.collectChest(p1, t1, 'l0')!;
    expect(p2.life.count('mojarra_claro'), 2);
    expect(t2.build('l0')!.chest, isEmpty);
    expect(TownRules.collectChest(p2, t2, 'l0'), isNull);
  });

  test('migración: el ayudante y el granero viejos van a la primera huerta', () {
    final key = cropKey('nabo_claro', CropQuality.normal);
    final t = TownState.fromJson({
      'builds': [kBaseLake.toJson(), kBaseFarm.toJson()],
      'helper': 2,
      'silo': {key: 5},
    });
    final h = t.build('h0')!;
    expect(h.helper, 1);
    expect(h.chest[key], 5);
    expect(t.toJson().containsKey('silo'), isFalse);
    expect(TownState.fromJson(t.toJson()).build('h0')!.chest[key], 5);
  });

  test('tope por tamaño y huertas que se tocan se funden', () {
    // 4 × 3 = 12 parcelas: 1 granjero de 12 (v0.45.0).
    expect(TownRules.helperCap(kBaseFarm), 1);
    expect(TownRules.helperArea(kBaseFarm, 0), hasLength(12));
  });
}
