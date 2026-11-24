import 'dart:typed_data';
import 'dart:ui';

import 'package:echos_del_tiempo/features/world/presentation/map/sky_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_time_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/sky_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/weather_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// Seasons and weather per biome (docs/specs/weather_seasons.md).

/// First day of [s] in the first year.
int dayOf(Season s) => 1 + s.index * WeatherRules.seasonDays;

/// A started sky on [day] at [clock] seconds.
SkyState skyOn(int day, {double clock = 100, int seed = 1234}) {
  var s = SkyState(day: day, clock: clock, seed: seed);
  final (from, to) = WeatherRules.window(seed, day, null);
  final w = WeatherRules.dayWeather(seed, day, null);
  s = s.copyWith(weather: w, from: from, to: to);
  return s;
}

void main() {
  group('season cycle', () {
    test('spring → summer → autumn → winter → spring, seasonDays each', () {
      final n = WeatherRules.seasonDays;
      expect(n, 7);
      expect(WeatherRules.season(0), Season.spring);
      expect(WeatherRules.season(1), Season.spring);
      expect(WeatherRules.season(n), Season.spring);
      expect(WeatherRules.season(n + 1), Season.summer);
      expect(WeatherRules.season(2 * n + 1), Season.autumn);
      expect(WeatherRules.season(3 * n + 1), Season.winter);
      expect(WeatherRules.season(4 * n), Season.winter);
      expect(WeatherRules.season(4 * n + 1), Season.spring, reason: 'year 2');
      expect(WeatherRules.seasonDay(n + 3), 3);
      expect(WeatherRules.daysToNextSeason(n), 1);
      expect(WeatherRules.daysToNextSeason(1), n);
    });
  });

  group('weather per seed, day and biome', () {
    test('same inputs, same weather; the seed matters', () {
      for (final b in [null, kBosque, kRuinas, kGrieta, kAbismo]) {
        for (var d = 1; d < 60; d++) {
          expect(WeatherRules.dayWeather(99, d, b),
              WeatherRules.dayWeather(99, d, b));
          expect(WeatherRules.window(99, d, b), WeatherRules.window(99, d, b));
        }
      }
      String run(int seed) => [
            for (var d = 1; d < 60; d++)
              WeatherRules.dayWeather(seed, d, kBosque).name
          ].join(',');
      expect(run(1), isNot(run(2)));
    });

    test('biomes differ on the same day; caves have no weather', () {
      var differ = 0;
      for (var d = 1; d < 80; d++) {
        if (WeatherRules.dayWeather(7, d, kBosque) !=
            WeatherRules.dayWeather(7, d, kAbismo)) {
          differ++;
        }
        expect(WeatherRules.dayWeather(7, d, kCavernas), Weather.despejado);
      }
      expect(differ, greaterThan(10));
    });

    test('snow only in winter, never in the hot Grieta', () {
      for (var seed = 1; seed < 30; seed++) {
        for (var d = 1; d <= 4 * WeatherRules.seasonDays; d++) {
          final w = WeatherRules.dayWeather(seed, d, null);
          if (w == Weather.snow) {
            expect(WeatherRules.season(d), Season.winter);
          }
          expect(WeatherRules.dayWeather(seed, d, kGrieta),
              isNot(Weather.snow));
        }
      }
      var snow = 0;
      for (var i = 0; i < 2000; i++) {
        if (WeatherRules.pick(i / 2000, Season.winter, null) == Weather.snow) {
          snow++;
        }
      }
      expect(snow, greaterThan(300));
    });

    test('the town sky follows the seed: forecast = dayWeather', () {
      final s0 = SkyRules.start(() => 0.37);
      expect(s0.seed, isNot(0));
      expect(s0.tomorrow, WeatherRules.dayWeather(s0.seed, 2, null));
      var s = s0;
      for (var d = 0; d < 30; d++) {
        s = SkyRules.advance(s, SkyRules.length, () => 0.5);
        expect(s.weather, WeatherRules.dayWeather(s.seed, s.day, null));
        expect(s.tomorrow, WeatherRules.dayWeather(s.seed, s.day + 1, null));
      }
      // Two hosts with the same seed see the same sky.
      var a = s0, b = s0;
      for (var i = 0; i < 50; i++) {
        a = SkyRules.advance(a, 37, () => 0.1);
        b = SkyRules.advance(b, 37, () => 0.9);
      }
      expect(a, b);
    });

    test('current() only inside its window', () {
      for (var d = 1; d < 40; d++) {
        final w = WeatherRules.dayWeather(5, d, kBosque);
        if (w == Weather.despejado) continue;
        final (from, to) = WeatherRules.window(5, d, kBosque);
        final mid = SkyState(
            day: d, seed: 5, clock: (from + to) / 2 * SkyRules.length);
        expect(WeatherRules.current(mid, biome: kBosque), w);
        return;
      }
      fail('no wet day found');
    });

    test('JSON round trip keeps the seed', () {
      final s = SkyRules.advance(SkyRules.start(() => 0.8), 1500, () => 0.2)
          .copyWith(weather: Weather.fog, from: 0.1, to: 0.5,
              tomorrow: Weather.snow);
      final back = SkyState.fromJson(s.toJson());
      expect(back.seed, s.seed);
      expect(back.weather, Weather.fog);
      expect(back.tomorrow, Weather.snow);
      expect(back.day, s.day);
      expect(SkyState.fromJson(const SkyState().toJson()).seed, 0);
    });

    test('fog and snow do not water crops; bite chances from tuning', () {
      expect(Weather.fog.wet, isFalse);
      expect(Weather.snow.wet, isFalse);
      expect(Weather.tormenta.wet, isTrue);
      expect(WeatherRules.biteChance(Weather.snow), closeTo(0.7, 1e-9));
      expect(WeatherRules.biteChance(Weather.fog), closeTo(0.85, 1e-9));
      expect(WeatherRules.biteChance(Weather.despejado), 1);
    });
  });

  group('seasonal fish', () {
    test('winter fish only in winter; spring fish only in spring', () {
      final winter = skyOn(dayOf(Season.winter));
      final spring = skyOn(dayOf(Season.spring));
      expect(LifeTimeRules.fishInSeason('carpa_nevada', winter), isTrue);
      expect(LifeTimeRules.fishInSeason('carpa_nevada', spring), isFalse);
      expect(LifeTimeRules.fishInSeason('mojarra_primavera', spring), isTrue);
      final lake = kTownLakeDefault;
      final w = LifeTimeRules.activeTable(lake, winter, () => 0,
          biome: kTownStartBiome, weather: Weather.despejado);
      expect(w, contains('carpa_nevada'));
      expect(w, isNot(contains('mojarra_primavera')));
      expect(w, isNot(contains('carpa_musgo')), reason: 'not in winter');
      final sp = LifeTimeRules.activeTable(lake, spring, () => 0,
          biome: kTownStartBiome, weather: Weather.despejado);
      expect(sp, contains('mojarra_primavera'));
      expect(sp, isNot(contains('carpa_nevada')));
    });

    test('weather fish only in their weather; off-hours never bypasses it',
        () {
      final s = skyOn(dayOf(Season.summer));
      List<String> t(Weather w) => LifeTimeRules.activeTable(
          kForestFish, s, () => 0,
          biome: kBosque, weather: w);
      expect(t(Weather.tormenta), contains('trucha_tormenta'));
      expect(t(Weather.despejado), isNot(contains('trucha_tormenta')));
      final town = LifeTimeRules.activeTable(['pez_bruma'], s, () => 0,
          biome: kTownStartBiome, weather: Weather.despejado);
      expect(town, ['pez_bruma'], reason: 'never empty: falls back');
      final snow = skyOn(dayOf(Season.winter));
      expect(
          LifeTimeRules.activeTable(kTownLakeDefault, snow, () => 1,
              biome: kTownStartBiome, weather: Weather.snow),
          contains('pez_copo'));
    });

    test('most existing fish live all year', () {
      final old = [
        for (final f in kFish.values)
          if (!f.visitor && f.biome != kWaterJunkBiome) f
      ];
      final allYear = old.where((f) => f.seasons.length == 4).length;
      expect(allYear / old.length, greaterThan(0.75));
      final visitors = kFish.values.where((f) => f.visitor).toList();
      expect(visitors.length, greaterThanOrEqualTo(8));
      for (final v in visitors) {
        expect(v.seasons.length < 4 || v.weather != null, isTrue,
            reason: v.id);
      }
      expect(kTownLakeDefault, isNot(contains('carpa_nevada')));
    });
  });

  group('crop seasons', () {
    FarmPlot planted(String id) =>
        FarmingRules.plant(FarmingRules.till(), id)!;

    test('most crops stall in winter and resume after (never die)', () {
      final winter = skyOn(dayOf(Season.winter));
      final spring = skyOn(dayOf(Season.spring));
      expect(LifeTimeRules.cropGrowth('nabo_claro', winter), 0);
      expect(LifeTimeRules.cropGrowth('nabo_claro', spring), greaterThan(0));
      var p = planted('nabo_claro');
      p = FarmingRules.rain(p);
      final before = FarmingRules.ratio(p);
      final stalled = FarmingRules.grow(p, 60,
          mult: LifeTimeRules.cropGrowth('nabo_claro', winter));
      expect(FarmingRules.ratio(stalled), before);
      expect(stalled.planted, isTrue);
      final grown = FarmingRules.grow(stalled, 60,
          mult: LifeTimeRules.cropGrowth('nabo_claro', spring));
      expect(FarmingRules.ratio(grown), greaterThan(before));
      final crops = kCrops.values
          .where((c) => c.biome != kWildBiome)
          .toList();
      final skip = crops.where((c) => !c.seasons.contains(Season.winter));
      expect(skip.length / crops.length, greaterThan(0.5));
    });

    test('winter crops grow only in winter and are harvested only then', () {
      final winter = skyOn(dayOf(Season.winter));
      final summer = skyOn(dayOf(Season.summer));
      for (final id in ['rabano_nieve', 'col_invierno', 'puerro_helado']) {
        expect(kCrops[id]!.winterOnly, isTrue, reason: id);
        expect(kCrops[id]!.seedPrice, greaterThan(0), reason: 'in the shop');
        expect(LifeTimeRules.cropGrowth(id, winter), greaterThan(0));
        expect(LifeTimeRules.cropGrowth(id, summer), 0);
      }
      final ripe = planted('rabano_nieve').copyWith(grow: 1e6);
      expect(FarmingRules.ripe(ripe), isTrue);
      expect(FarmingRules.harvestable(ripe, Season.winter), isTrue);
      expect(FarmingRules.harvestable(ripe, Season.spring), isFalse);
      final nabo = planted('nabo_claro').copyWith(grow: 1e6);
      expect(FarmingRules.harvestable(nabo, Season.winter), isTrue,
          reason: 'already ripe: picking is always allowed');
    });
  });

  group('overlay', () {
    test('snowflakes are all inside the visible area, no matter the view',
        () {
      final buf = Float32List(MapSkyLayer.maxFlakes * 2);
      for (final view in [
        const Rect.fromLTWH(0, 0, 320, 180),
        const Rect.fromLTWH(-500, 1200, 640, 360),
        const Rect.fromLTWH(10000, -3000, 100, 50),
      ]) {
        for (final t in [0.0, 1234.5, 9e6]) {
          final n = MapSkyLayer.snowFlakes(view, t, 200, buf);
          expect(n, MapSkyLayer.maxFlakes, reason: 'capped by the buffer');
          for (var i = 0; i < n; i++) {
            expect(buf[i * 2], inInclusiveRange(view.left, view.right));
            expect(buf[i * 2 + 1], inInclusiveRange(view.top, view.bottom));
          }
        }
      }
      expect(
          MapSkyLayer.snowFlakes(Rect.zero, 0, 50, buf), 0);
    });
  });
}
