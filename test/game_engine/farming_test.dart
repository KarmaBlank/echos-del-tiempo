import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// XP total para llegar a [level] de Cultivo.
int _farmXpFor(int level) {
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += FarmingRules.xpNeed(l);
  }
  return xp;
}

int _fishXpFor(int level) {
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += FishingRules.xpNeed(l);
  }
  return xp;
}

PlayerProfile _farmer(String name, int level, {FarmSkills? farm}) {
  final base = newProfile(name, 'guerrero');
  final f = (farm ?? FarmSkills()).copyWith(xp: _farmXpFor(level));
  return base.copyWith(life: base.life.copyWith(farm: f));
}

/// Una parcela de nabo madura y regada todo el tiempo.
FarmPlot _ripe(PlayerProfile planter, PlayerProfile waterer, {String? fert}) {
  var p = FarmingRules.plant(FarmingRules.till(), 'nabo_claro', planter)!;
  p = FarmingRules.water(p, waterer);
  if (fert != null) p = FarmingRules.fertilize(p, fert, planter)!;
  p = p.copyWith(grow: FarmingRules.growSec('nabo_claro'), wetGrow: FarmingRules.growSec('nabo_claro'));
  return p;
}

void main() {
  group('crecimiento', () {
    test('regado crece más rápido que seco; etapas hasta maduro', () {
      final ana = _farmer('Ana', 1);
      final seca = FarmingRules.plant(FarmingRules.till(), 'nabo_claro', ana)!;
      final regada = FarmingRules.water(seca, ana);
      final s1 = FarmingRules.grow(seca, 10);
      final r1 = FarmingRules.grow(regada, 10);
      expect(r1.grow, greaterThan(s1.grow));
      expect(FarmingRules.stage(seca), CropStage.semilla);
      var p = regada;
      final steps = (FarmingRules.growSec('nabo_claro') * 4).ceil();
      for (var i = 0; i < steps && !FarmingRules.ripe(p); i++) {
        p = FarmingRules.grow(p, 1);
      }
      expect(FarmingRules.ripe(p), isTrue);
      expect(FarmingRules.stage(p), CropStage.maduro);
    });

    test('una misión ganada suma tiempo de crecimiento', () {
      final p = FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!;
      final m = FarmingRules.missionGrow(p);
      expect(m.grow, kTuning[TuningId.farming]!.values['missionGrowSec']);
    });

    test('el abono acelera y sesga la calidad', () {
      final ana = _farmer('Ana', 1);
      final p = FarmingRules.plant(FarmingRules.till(), 'nabo_claro', ana)!;
      final f = FarmingRules.fertilize(p, 'abono_eco', ana)!;
      expect(FarmingRules.grow(f, 10).grow,
          greaterThan(FarmingRules.grow(p, 10).grow));
      expect(f.fertBy, 'Ana');
      expect(FarmingRules.fertilize(f, 'abono', ana), isNull);
    });
  });

  group('calidad compartida', () {
    test('cosechador alto vs bajo sobre la misma parcela', () {
      final low = _farmer('Bajo', 1);
      final high = _farmer('Alto', 25);
      final plot = _ripe(low, low, fert: 'abono_runico');
      final lo = FarmingRules.odds(low, plot);
      final hi = FarmingRules.odds(high, plot);
      expect(lo.values.fold(0.0, (a, b) => a + b), closeTo(1, 1e-9));
      expect(hi[CropQuality.legendario]!,
          greaterThan(lo[CropQuality.legendario]! * 2));
      expect(hi[CropQuality.normal]!, lessThan(lo[CropQuality.normal]!));
      // Los aportes quedan en la parcela.
      expect(plot.planter, 'Bajo');
      expect(plot.waterer, 'Bajo');
      expect(plot.waterings, 1);
    });

    test('mejor abono sesga más', () {
      final ana = _farmer('Ana', 5);
      double leg(String f) =>
          FarmingRules.odds(ana, _ripe(ana, ana, fert: f))[CropQuality.legendario]!;
      expect(leg('abono_runico'), greaterThan(leg('abono')));
      expect(leg('abono_eco'), greaterThan(leg('abono_runico')));
    });

    test('un regador de nivel bajo riega más lento', () {
      expect(FarmingRules.waterRate(_farmer('a', 1)),
          lessThan(FarmingRules.waterRate(_farmer('b', 15))));
    });
  });

  group('hallazgos y pity', () {
    test('pity de hallazgo y de semilla legendaria', () {
      final ana = _farmer('Ana', 1);
      expect(FarmingRules.rollLoot(() => 0.99, ana), FarmLootKind.none);
      final dry = _farmer('Ana', 1,
          farm: FarmSkills().copyWith(dry: 40));
      expect(FarmingRules.rollLoot(() => 0.99, dry), FarmLootKind.materiales);
      final pity = _farmer('Ana', 1,
          farm: FarmSkills().copyWith(pity: 150));
      expect(FarmingRules.rollLoot(() => 0.99, pity), FarmLootKind.legendaria);
    });

    test('cosecha, venta y canje legendario', () {
      final ana = _farmer('Ana', 1);
      final h = FarmingRules.harvest(() => 0.0, ana, _ripe(ana, ana))!;
      expect(h.crop.id, 'nabo_claro');
      final p = FarmingRules.addHarvest(ana, h);
      expect(p.life.farm.xp, greaterThan(ana.life.farm.xp));
      expect(FarmingRules.sell(p)!.credits, greaterThan(0));
      final key = cropKey('trigo_manana', CropQuality.legendario);
      final withLeg = p.copyWith(
          life: p.life.copyWith(farm: p.life.farm.addCrop(key, 1)));
      final ex = FarmingRules.exchangeLegendary(withLeg, key)!;
      expect(ex.materials[CraftMaterial.cristal] ?? 0, greaterThan(0));
    });
  });

  group('pueblo', () {
    test('peces soltados sesgan la tirada y crían', () {
      final species = kFish.values
          .firstWhere((f) => f.biome != kWaterJunkBiome)
          .id;
      final base = newProfile('Ana', 'guerrero');
      final p = base.copyWith(life: LifeSkills(bag: {species: 3}));
      var (p2, s) = TownRules.stock(p, const TownState(), species)!;
      (p2, s) = TownRules.stock(p2, s, species)!;
      expect(p2.life.count(species), 1);
      final before = TownRules.lakeRoll(const TownState())
          .where((x) => x == species)
          .length;
      final after = TownRules.lakeRoll(s).where((x) => x == species).length;
      expect(after, greaterThan(before));
      expect(TownRules.lakeRare(s), greaterThan(0));
      final bred = TownRules.breed(() => 0, s);
      expect(bred.stock[species], 3);
    });
  });

  group('árboles de oficios', () {
    test('Pesca: un punto por nivel, excluyentes, efecto y reinicio', () {
      final base = newProfile('Ana', 'guerrero');
      var p = base.copyWith(
          life: base.life.copyWith(fishXp: _fishXpFor(4)));
      expect(LifeTreeRules.earned(p, LifeSkillKind.pesca), 3);
      final zone0 = FishingRules.rodBonus(p).zone;
      p = LifeTreeRules.take(p, LifeSkillKind.pesca, 'p_a1')!;
      expect(FishingRules.rodBonus(p).zone, greaterThan(zone0));
      p = LifeTreeRules.take(p, LifeSkillKind.pesca, 'p_a2')!;
      expect(LifeTreeRules.cannotTake(p, LifeSkillKind.pesca, 'p_a3'),
          isNotNull);
      expect(LifeTreeRules.free(p, LifeSkillKind.pesca), 1);
      p = LifeTreeRules.reset(p, LifeSkillKind.pesca)!;
      expect(LifeTreeRules.free(p, LifeSkillKind.pesca), 3);
      expect(LifeSkills.fromJson(p.life.toJson()).fishTree, isEmpty);
    });

    test('Cultivo: calidad del árbol sube la legendaria y se guarda', () {
      var p = _farmer('Ana', 4);
      final plot = _ripe(p, p);
      final leg0 = FarmingRules.odds(p, plot)[CropQuality.legendario]!;
      p = LifeTreeRules.take(p, LifeSkillKind.cultivo, 'c_b1')!;
      expect(FarmingRules.odds(p, plot)[CropQuality.legendario]!,
          greaterThan(leg0));
      expect(LifeTreeRules.take(p, LifeSkillKind.cultivo, 'c_k1'), isNull);
      final back = LifeSkills.fromJson(p.life.toJson());
      expect(back.farm.tree, ['c_b1']);
      expect(kLifeTrees[LifeSkillKind.cultivo]!.length, inInclusiveRange(10, 16));
    });
  });
}
