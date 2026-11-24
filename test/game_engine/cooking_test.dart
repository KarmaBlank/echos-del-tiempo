import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/cooking_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_time_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Cocina y balance de Cultivo (farming.md § 16–17, v0.45.0).

PlayerProfile _cook({Map<String, int> crops = const {}, Map<String, int> fish = const {}}) {
  final p = newProfile('Ana', 'guerrero');
  return p.copyWith(
      life: p.life.copyWith(
          bag: fish, farm: p.life.farm.copyWith(crops: crops)));
}

double _v(String k) => kTuning[TuningId.farming]!.values[k]!.toDouble();

void main() {
  group('cocina', () {
    test('cocinar gasta los cultivos de la calidad elegida', () {
      final key = cropKey('nabo_claro', CropQuality.raro);
      var p = _cook(crops: {key: 4, cropKey('nabo_claro', CropQuality.normal): 1});
      expect(CookingRules.cookBlock(p, 'sopa_nabo', CropQuality.normal),
          CookBlock.crops);
      p = CookingRules.cook(p, 'sopa_nabo', CropQuality.raro)!;
      expect(p.life.farm.cropCount(key), 1);
      expect(p.life.farm.mealCount(mealKey('sopa_nabo', CropQuality.raro)), 1);
      expect(p.life.farm.mealLog['sopa_nabo'], CropQuality.raro.index);
      expect(CookingRules.cook(p, 'sopa_nabo', CropQuality.raro), isNull);
    });

    test('las recetas con pescado gastan el pez y duran una misión más', () {
      var p = _cook(
          crops: {cropKey('nabo_claro', CropQuality.normal): 2},
          fish: {'mojarra_claro': 1});
      p = CookingRules.cook(p, 'mojarra_nabo', CropQuality.normal)!;
      expect(p.life.count('mojarra_claro'), 0);
      final m = kMeals['mojarra_nabo']!;
      expect(CookingRules.missionsFor(m), _v('mealMissions').toInt() + 1);
      expect(CookingRules.cookBlock(p, 'mojarra_nabo', CropQuality.normal),
          isNot(isNull));
    });

    test('comer da el buff y vence a las N misiones', () {
      var p = _cook(crops: {cropKey('trigo_dorado', CropQuality.normal): 3});
      p = CookingRules.cook(p, 'pan_dorado', CropQuality.normal)!;
      p = CookingRules.eat(p, mealKey('pan_dorado', CropQuality.normal))!;
      final b = p.life.farm.meal!;
      expect(b.left, _v('mealMissions').toInt());
      expect(CookingRules.atk(b), closeTo(_v('mealBuffBase'), 1e-9));
      expect(CookingRules.hp(b), 0);
      for (var i = 0; i < _v('mealMissions').toInt() - 1; i++) {
        p = CookingRules.afterMission(p);
        expect(p.life.farm.meal, isNotNull);
      }
      p = CookingRules.afterMission(p);
      expect(p.life.farm.meal, isNull);
      expect(p.life.farm.meals, isEmpty);
    });

    test('el buff entra a los stats y la resistencia al elemento', () {
      final rules = progression;
      var p = _cook(crops: {cropKey('nabo_claro', CropQuality.epico): 3});
      final before = rules.derivedStats(p).maxHp;
      p = CookingRules.cook(p, 'sopa_nabo', CropQuality.epico)!;
      p = CookingRules.eat(p, mealKey('sopa_nabo', CropQuality.epico))!;
      expect(rules.derivedStats(p).maxHp, greaterThan(before));
      const res = MealBuff('caldo_invierno', CropQuality.normal, 2);
      expect(CookingRules.resist(res, DamageTag.ice), greaterThan(0));
      expect(CookingRules.resist(res, DamageTag.fire), 0);
    });

    test('la calidad escala el buff con qualityMult', () {
      final m = kMeals['sopa_nabo']!;
      final values = [for (final q in CropQuality.values) CookingRules.buffValue(m, q)];
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
      expect(
          values[CropQuality.epico.index],
          closeTo(
              _v('mealBuffBase') * _v('qualityMultEpico') +
                  _v('mealBuffPerQuality') * 2,
              1e-9));
      expect(CookingRules.buffValue(kMeals['melon_glaseado']!, CropQuality.normal),
          closeTo(2 * values.first, 1e-9));
    });

    test('JSON ida y vuelta de comidas, colección y buff', () {
      var p = _cook(crops: {cropKey('trigo_dorado', CropQuality.raro): 6});
      p = CookingRules.cook(p, 'pan_dorado', CropQuality.raro)!;
      p = CookingRules.cook(p, 'pan_dorado', CropQuality.raro)!;
      p = CookingRules.eat(p, mealKey('pan_dorado', CropQuality.raro))!;
      final back = PlayerProfile.fromJson(p.toJson());
      expect(back.life.farm, p.life.farm);
      expect(back.life.farm.meal, const MealBuff('pan_dorado', CropQuality.raro, 2));
      expect(back.life.farm.mealCount(mealKey('pan_dorado', CropQuality.raro)), 1);
      expect(back.life.farm.mealLog, {'pan_dorado': CropQuality.raro.index});
      expect(MealBuff.fromJson({'m': 'nada', 'q': 0, 'n': 1}), isNull);
    });
  });

  group('estación', () {
    test('un cultivo de estación vale y crece más en su estación', () {
      final p = newProfile('Ana', 'guerrero');
      final c = kCrops['nabo_claro']!;
      final base = FarmingRules.unitPrice(p, c, CropQuality.normal);
      final summer =
          FarmingRules.unitPrice(p, c, CropQuality.normal, Season.summer);
      expect(summer, (c.price * _v('seasonPriceMult')).round());
      expect(summer, greaterThan(base));
      expect(LifeTimeRules.seasonGrow('nabo_claro', Season.summer),
          _v('seasonGrowMult'));
      // Fuera de estación no hay bonus (y no crece).
      expect(LifeTimeRules.seasonPrice('nabo_claro', Season.winter), 1);
      // Los de todo el año no tienen estación.
      expect(LifeTimeRules.seasonGrow('flor_cristal', Season.summer), 1);
      final plot = FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!;
      expect(FarmingRules.missionGrow(plot, season: Season.summer).grow,
          closeTo(_v('missionGrowSec') * _v('seasonGrowMult'), 1e-9));
    });
  });

  group('tuning de v0.45.0', () {
    test('los valores por defecto', () {
      final f = kTuning[TuningId.farming]!.values;
      expect(f['workXp'], 3);
      expect(f['lootChance'], 0.12);
      expect(f['legendPityAfter'], 100);
      expect(f['seedDropChance'], 0.55);
      expect(f['dryRate'], 0.5);
      expect(f['missionGrowSec'], 600);
      expect(f['seasonPriceMult'], 1.3);
      expect(f['seasonGrowMult'], 1.2);
      expect(f['mealBuffBase'], 0.05);
      expect(f['mealBuffPerQuality'], 0.03);
      expect(f['mealMissions'], 2);
      expect(kTuning[TuningId.town]!.values['helperPlots'], 12);
      expect(kCrops['nabo_claro']!.xp, 9);
    });
  });
}
