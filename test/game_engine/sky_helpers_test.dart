import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/models/item.dart' show CraftMaterial;
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_minigame.dart';
import 'package:echos_del_tiempo/game_engine/rules/helper_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/sky_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Día, noche y clima (day_night_weather.md) y progresión de ayudantes
// (farming.md § 8.5), v0.27.0.

void main() {
  group('reloj', () {
    test('10 minutos por día: 5 de luz y 5 de noche, con transición suave', () {
      expect(SkyRules.length, 600);
      final s = SkyRules.start(() => 0.9);
      expect(s.day, 1);
      expect(SkyRules.isNight(s), isFalse);
      double dark(double c) => SkyRules.darkness(s.copyWith(clock: c));
      expect(dark(100), 0);
      expect(dark(300), closeTo(0.5, 1e-9), reason: 'mitad del atardecer');
      expect(dark(290), inInclusiveRange(0.01, 0.49));
      expect(dark(450), 1);
      expect(dark(0), closeTo(0.5, 1e-9), reason: 'mitad del amanecer');
      expect(dark(599), greaterThan(0.5));
      // Monótona en el atardecer.
      var last = 0.0;
      for (var c = 270.0; c <= 330; c += 2) {
        expect(dark(c), greaterThanOrEqualTo(last));
        last = dark(c);
      }
    });

    test('al terminar el día empieza otro con el clima pronosticado', () {
      final r = math.Random(3);
      var s = SkyRules.start(r.nextDouble).copyWith(tomorrow: Weather.lluvia);
      s = SkyRules.advance(s, SkyRules.length, r.nextDouble);
      expect(s.day, 2);
      expect(s.weather, Weather.lluvia);
      expect(s.to - s.from, inInclusiveRange(0.2 - 1e-9, 0.45 + 1e-9));
      // Solo llueve en su tramo.
      expect(SkyRules.now(s.copyWith(clock: (s.from + s.to) / 2 * 600)),
          Weather.lluvia);
      if (s.from > 0.01) {
        expect(SkyRules.now(s.copyWith(clock: 0)), Weather.despejado);
      }
      expect(SkyRules.forecast(s), startsWith('Mañana: '));
      final back = SkyState.fromJson(s.toJson());
      expect((back.day, back.weather, back.tomorrow),
          (s.day, s.weather, s.tomorrow));
      expect(back.from, closeTo(s.from, 0.001));
    });

    test('reparto del clima: casi siempre despejado, ~25 % lluvia, tormenta rara', () {
      final r = math.Random(11);
      final n = {for (final w in Weather.values) w: 0};
      for (var i = 0; i < 20000; i++) {
        final w = SkyRules.rollWeather(r.nextDouble());
        n[w] = n[w]! + 1;
      }
      expect(n[Weather.despejado]! / 20000, closeTo(0.69, 0.03));
      expect(n[Weather.lluvia]! / 20000, closeTo(0.25, 0.03));
      expect(n[Weather.tormenta]! / 20000, closeTo(0.06, 0.02));
    });
  });

  group('clima en la huerta y la pesca', () {
    test('la lluvia riega lo plantado sin madurar', () {
      final dry = FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!;
      expect(dry.watered, isFalse);
      final w = FarmingRules.rain(dry);
      expect(w.watered, isTrue);
      expect(w.waterer, 'Lluvia');
      expect(FarmingRules.rain(FarmingRules.till()).watered, isFalse);
    });

    test('un rayo devuelve la parcela a pasto sin arar', () {
      final town = const TownState().copyWith(builds: [
        kBaseLake,
        kBaseFarm.copyWith(plots: {
          '0,0': FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!,
          '1,0': FarmingRules.till(),
        }),
      ]);
      final key = town.plots.keys.firstWhere((k) => town.plots[k]!.planted);
      final out = TownRules.strike(town, key);
      expect(out.plots.containsKey(key), isFalse);
      expect(out.plots, hasLength(1));
    });

    test('con tormenta casi no pica', () {
      final storm = SkyRules.start(() => 0.5)
          .copyWith(weather: Weather.tormenta, from: 0, to: 1);
      expect(SkyRules.biteChance(storm), closeTo(0.3, 1e-9));
      expect(SkyRules.biteChance(const SkyState()), 1);
      final r = math.Random(5);
      var bites = 0;
      for (var i = 0; i < 400; i++) {
        final g = FishingMinigame(r.nextDouble,
            biteChance: SkyRules.biteChance(storm));
        g.press();
        g.tick(0.5);
        g.release();
        for (var k = 0; k < 400 && g.phase != FishPhase.bite; k++) {
          if (g.phase == FishPhase.lost) break;
          g.tick(0.1);
        }
        if (g.phase == FishPhase.bite) bites++;
      }
      expect(bites / 400, closeTo(0.3, 0.08));
    });
  });

  group('ayudantes', () {
    test('migración: los ayudantes de antes quedan en nivel 1 sin mejoras', () {
      final t = TownState.fromJson({
        'builds': [kBaseLake.toJson(), kBaseFarm.copyWith(helper: 1).toJson()],
      });
      final h = t.build('h0')!;
      expect(HelperRules.level(h.stat(0)), 1);
      expect(h.stat(0).ups, isEmpty);
      expect(TownRules.helperArea(h, 0), hasLength(8));
    });

    test('nivel por XP de trabajo y costos crecientes', () {
      expect(HelperRules.level(const HelperStat()), 1);
      expect(HelperRules.level(HelperStat(xp: HelperRules.xpToNext(1))), 2);
      final c1 = HelperRules.upgradeCost(BuildKind.huerta, 1);
      final c2 = HelperRules.upgradeCost(BuildKind.huerta, 2);
      expect(c1.mats, {'fibra': 3});
      expect(c2.gold, greaterThan(c1.gold));
      expect(c2.mats['tabla'], 1);
      expect(c2.level, 4);
      expect(HelperRules.upgradeCost(BuildKind.lago, 1).mats, {'cebo': 3});
    });

    test('mejorar cuesta oro y fibras; Parcelas agranda el área', () {
      var p = newProfile('Ana', 'guerrero');
      p = p.copyWith(
          credits: 5000,
          life: p.life.copyWith(crafts: {'fibra': 10}));
      var town = const TownState()
          .copyWith(builds: [kBaseLake, kBaseFarm.copyWith(helper: 1)]);
      final why =
          HelperRules.cannotUpgrade(p, town.build('h0')!, 0, HelperUpgrade.red);
      expect(why, isNotNull, reason: 'Red es de pescador');
      final (p1, t1) =
          HelperRules.upgrade(p, town, 'h0', 0, HelperUpgrade.parcelas)!;
      expect(p1.credits, 5000 - 400);
      expect(p1.life.craft('fibra'), 7);
      final h = t1.build('h0')!;
      expect(h.stat(0).rank(HelperUpgrade.parcelas), 1);
      expect(TownRules.helperArea(h, 0), hasLength(10));
      // El rango 2 pide nivel 4 del ayudante.
      expect(HelperRules.cannotUpgrade(p1, h, 0, HelperUpgrade.parcelas),
          contains('nivel'));
      // Guarda y vuelve.
      town = TownState.fromJson(t1.toJson());
      expect(town.build('h0')!.stat(0).rank(HelperUpgrade.parcelas), 1);
    });

    test('contratar pide materiales de oficio y el granjero gana XP', () {
      var p = newProfile('Ana', 'guerrero');
      p = p.copyWith(credits: 5000);
      final town = const TownState().copyWith(builds: [kBaseLake, kBaseFarm]);
      expect(HelperRules.cannotPay(p, HelperRules.hireCost(BuildKind.huerta)),
          contains('Fibra'));
      final b = kBaseFarm.copyWith(helper: 1, seeds: {'nabo_claro': 3});
      final (out, _) = TownRules.farmerCycle(b, 0, (_) => throw 'no',
          rand: () => 0.99);
      expect(out.stat(0).xp, 3);
      expect(town.build('h0')!.helper, 0);
    });

    test('Calidad sube un escalón la cosecha del granjero', () {
      final ripe = FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!
          .copyWith(
              grow: FarmingRules.growSec('nabo_claro'),
              wetGrow: FarmingRules.growSec('nabo_claro'));
      final b = kBaseFarm.copyWith(
          helper: 1,
          plots: {'0,0': ripe},
          tasks: [HelperTask.cosechar.bit],
          crew: [
            const HelperStat(xp: 99999, ups: {HelperUpgrade.calidad: 4})
          ]);
      final h = FarmingRules.harvest(
          () => 0.0, newProfile('Ana', 'guerrero'), ripe,
          helper: true)!;
      final (out, _) =
          TownRules.farmerCycle(b, 0, (_) => h, rand: () => 0.0);
      final q = CropQuality.values[h.quality.index + 1];
      expect(out.chest.keys.single, cropKey('nabo_claro', q));
    });
  });

  group('condensar oficios', () {
    test('cosechas + Esquirla + oro → fibra; fibras → tabla', () {
      var p = newProfile('Ana', 'guerrero');
      final k = cropKey('nabo_claro', CropQuality.normal);
      p = p.copyWith(
          credits: 1000,
          materials: {...p.materials, CraftMaterial.esquirla: 10},
          life: p.life.copyWith(farm: p.life.farm.copyWith(crops: {k: 16})));
      expect(LifeCraftRules.maxTimes(p, 'fibra'), 3);
      final p1 = LifeCraftRules.condense(p, 'fibra', 3)!;
      expect(p1.life.craft('fibra'), 3);
      expect(p1.life.farm.crops[k], 1);
      expect(p1.material(CraftMaterial.esquirla), 7);
      expect(p1.credits, 940);
      final p2 = LifeCraftRules.condense(p1, 'tabla', 1)!;
      expect(p2.life.craft('tabla'), 1);
      expect(p2.life.craft('fibra'), 0);
      expect(LifeCraftRules.condense(p2, 'tabla', 1), isNull);
    });
  });

  group('faros', () {
    test('se compran, se mueven y se borran; no van sobre construcciones', () {
      var p = newProfile('Ana', 'guerrero');
      p = p.copyWith(credits: 1000);
      const town = TownState();
      final (ox, oy) = town.origin;
      // Sobre el lago base: no.
      expect(TownRules.lightError(town, 4, 15), isNotNull);
      // Busca un tile libre de pasto.
      (int, int)? free;
      for (var y = 3; y < 25 && free == null; y++) {
        for (var x = 3; x < 30 && free == null; x++) {
          if (TownRules.lightError(town, x, y) == null) free = (x, y);
        }
      }
      expect(free, isNotNull);
      final (p1, t1) =
          TownRules.placeLight(p, town, free!.$1 + ox, free.$2 + oy)!;
      expect(p1.credits, 1000 - TownRules.faroCost);
      expect(t1.lights, [free]);
      final id = TownState.lightId(free);
      expect(TownRules.lightError(t1, free.$1, free.$2), 'Ya hay un faro');
      final t2 = TownState.fromJson(t1.toJson());
      expect(t2.lights, [free]);
      expect(TownRules.removeLight(t2, id)!.lights, isEmpty);
    });
  });
}
