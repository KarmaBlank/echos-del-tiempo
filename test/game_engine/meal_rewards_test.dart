import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/cooking_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Comidas que valen la pena (farming.md § 19).

PlayerProfile _with(
    {Map<String, int> crops = const {}, Map<String, int> meals = const {}}) {
  final p = newProfile('Ana', 'guerrero');
  return p.copyWith(
      life: p.life
          .copyWith(farm: p.life.farm.copyWith(crops: crops, meals: meals)));
}

double _f(String k) => kTuning[TuningId.farming]!.values[k]!.toDouble();
double _town(String k) => kTuning[TuningId.town]!.values[k]!.toDouble();

final _calc =
    StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattlePartyMember _member(MealBuff? meal) {
  final cls = kClasses['guerrero']!;
  return BattlePartyMember(
    id: 'p1',
    name: cls.name,
    build: PlayerBuild(
      classId: 'guerrero',
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
      meal: meal,
    ),
  );
}

Combatant _start(MealBuff? meal) =>
    BattleEngine(stats: _calc, random: () => 0.5)
        .start(party: [_member(meal)], enemyTypes: ['slime'])
        .state
        .party
        .first;

void main() {
  group('pedidos de comidas', () {
    test('una comida paga más que sus ingredientes crudos', () {
      expect(_town('mealOrderPay'), greaterThanOrEqualTo(1.6));
      for (final m in kMeals.values) {
        var raw = 0;
        for (final e in {...m.crops, ...m.fish}.entries) {
          raw += ResidentRules.orderReward(
                  ResidentState('lina', order: e.key, orderN: e.value))
              .gold;
        }
        final gold = ResidentRules.orderReward(
                ResidentState('lina', order: m.id, orderN: 1))
            .gold;
        expect(gold, greaterThanOrEqualTo((raw * 1.6).floor()), reason: m.id);
        expect(gold, greaterThan(raw), reason: m.id);
      }
    });

    test('se entrega con comidas de escalón suficiente', () {
      final fine = mealKey('sopa_nabo', CropQuality.raro);
      final common = mealKey('sopa_nabo', CropQuality.normal);
      final p = _with(meals: {fine: 2, common: 3});
      const r = ResidentState('lina', order: 'sopa_nabo', orderN: 2, orderQ: 1);
      expect(ResidentRules.orderHave(p, 'sopa_nabo', 1), 2);
      final town = const TownState().withResident(r);
      final out = ResidentRules.deliverOrder(p, town, 'lina', 9999)!;
      expect(out.$1.life.farm.mealCount(fine), 0);
      expect(out.$1.life.farm.mealCount(common), 3);
      expect(out.$1.credits, greaterThan(p.credits));
      expect(out.$2.resident('lina').order, isNull);
    });

    test('con nivel de Granjero aparecen órdenes de comida', () {
      var found = false;
      for (var day = 1; day < 60 && !found; day++) {
        found = ResidentRules.mealOrder('lina', day, 30) != null;
      }
      expect(found, isTrue);
      expect(ResidentRules.mealOrder('lina', 3, 0), isNull);
    });
  });

  group('comidas compartidas', () {
    test('DAR A: el compañero queda con la comida, reemplaza la suya', () {
      final key = mealKey('pan_dorado', CropQuality.epico);
      final a = _with(meals: {key: 1});
      final b = CookingRules.serve(newProfile('Beto', 'maga'),
          const MealBuff('sopa_nabo', CropQuality.normal, 1));
      final (ga, gb) = CookingRules.give(a, b, key)!;
      expect(ga.life.farm.mealCount(key), 0);
      expect(gb.life.farm.meal!.meal, 'pan_dorado');
      expect(gb.life.farm.meal!.quality, CropQuality.epico);
      expect(CookingRules.give(ga, gb, key), isNull);
    });

    test('FESTÍN gasta ingredientes × mealFeastMult', () {
      final k = cropKey('nabo_claro', CropQuality.normal);
      final need = (3 * _f('mealFeastMult')).ceil();
      expect(
          CookingRules.feast(
              _with(crops: {k: need - 1}), 'sopa_nabo', CropQuality.normal),
          isNull);
      final (p, b) = CookingRules.feast(
          _with(crops: {k: need + 1}), 'sopa_nabo', CropQuality.normal)!;
      expect(p.life.farm.cropCount(k), 1);
      expect(b.meal, 'sopa_nabo');
      expect(p.life.farm.mealLog['sopa_nabo'], 0);
    });
  });

  group('escalones', () {
    test('calidad → escalón y misiones extra', () {
      final m = kMeals['sopa_nabo']!;
      expect(mealTierOf(CropQuality.legendario), MealTier.legendary);
      expect(mealTierOf(CropQuality.raro), MealTier.fine);
      expect(CookingRules.missionsFor(m, CropQuality.legendario),
          (_f('mealMissions') + _f('mealMissionsLegendario')).toInt());
      expect(CookingRules.missionsFor(m, CropQuality.epico),
          (_f('mealMissions') + _f('mealMissionsEpico')).toInt());
      expect(CookingRules.missionsFor(m), _f('mealMissions').toInt());
    });

    test('el extra legendario solo en LEGENDARIA y por tipo', () {
      const hpL = MealBuff('sopa_nabo', CropQuality.legendario, 2);
      const hpE = MealBuff('sopa_nabo', CropQuality.epico, 2);
      const atkL = MealBuff('pan_dorado', CropQuality.legendario, 2);
      const resL = MealBuff('caldo_invierno', CropQuality.legendario, 2);
      expect(CookingRules.regen(hpL), _f('mealRegen'));
      expect(CookingRules.regen(hpE), 0);
      expect(CookingRules.breakBonus(atkL), _f('mealBreak'));
      expect(CookingRules.shield(resL), _f('mealShield'));
      expect(CookingRules.shield(atkL), 0);
    });

    test('en batalla: regeneración y escudo inicial', () {
      final plain = _start(null);
      final regen =
          _start(const MealBuff('sopa_nabo', CropQuality.legendario, 2));
      expect(regen.regenPerTurn - plain.regenPerTurn,
          closeTo(_f('mealRegen'), 1e-9));
      final shielded =
          _start(const MealBuff('caldo_invierno', CropQuality.legendario, 2));
      final sh = shielded.effects
          .where(
              (e) => e.sourceId == kMealShieldId && e.stat == BuffStat.shield)
          .toList();
      expect(sh, hasLength(1));
      expect(sh.first.value, (shielded.maxHp * _f('mealShield')).round());
      expect(plain.effects.where((e) => e.sourceId == kMealShieldId), isEmpty);
    });
  });
}
