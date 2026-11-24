import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:echos_del_tiempo/features/world/presentation/map/ground_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/climate_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_time_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/weather_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/climate_data_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Climate per biome (docs/specs/weather_seasons.md § 2.3, § 6.3, § 8).

const _locales = ['es-AR', 'en', 'zh-Hans'];

void main() {
  tearDown(ClimateData.restore);

  group('coherence', () {
    test('caves: sheltered, never any weather, no ground marks', () {
      for (var d = 1; d < 120; d++) {
        expect(WeatherRules.dayWeather(9, d, kCavernas), Weather.despejado);
      }
      expect(WeatherRules.hasSky(kCavernas), isFalse);
      for (final s in Season.values) {
        expect(
            MapGroundLayer.markFor(
                lobby: true,
                place: kCavernas,
                season: s,
                weather: Weather.lluvia),
            isNull);
      }
    });

    test('volcanic Grieta: no snow nor rain; snow melts into steam (fog)',
        () {
      final c = climateOf(kGrieta);
      expect(c.exposure, Exposure.volcanic);
      expect(c.allows(Weather.snow), isFalse);
      expect(c.allows(Weather.lluvia), isFalse);
      expect(c.showsPrecipitation, isFalse);
      expect(c.groundShown.any, isFalse);
      // The winter snow weight goes to fog.
      final fog = WeatherRules.weight(Season.winter, kGrieta, Weather.fog);
      expect(fog, greaterThan(
          WeatherRules.weight(Season.summer, kGrieta, Weather.fog)));
      for (var seed = 1; seed < 20; seed++) {
        for (var d = 1; d <= 4 * WeatherRules.seasonDays; d++) {
          final w = WeatherRules.dayWeather(seed, d, kGrieta);
          expect(w, isNot(Weather.snow));
          expect(w, isNot(Weather.lluvia));
        }
      }
    });

    test('outdoor biomes: ground marks follow season and weather', () {
      GroundMark? m(Season s, Weather w) => MapGroundLayer.markFor(
          lobby: true, place: kBosque, season: s, weather: w);
      expect(m(Season.winter, Weather.despejado), GroundMark.snow);
      expect(m(Season.summer, Weather.lluvia), GroundMark.puddles);
      expect(m(Season.autumn, Weather.despejado), GroundMark.leaves);
      expect(m(Season.spring, Weather.despejado), GroundMark.flowers);
      expect(m(Season.summer, Weather.despejado), isNull);
      // Dungeons and mines: never.
      expect(
          MapGroundLayer.markFor(
              lobby: false,
              place: null,
              season: Season.winter,
              weather: Weather.snow),
          isNull);
    });

    test('ground marks only on visible ground tiles', () {
      final rows = [for (var y = 0; y < 40; y++) ('g' * 30) + ('#' * 30)];
      final map = GameMap(
          width: 60,
          height: 40,
          rows: rows,
          theme: 'pueblo',
          spawn: const WorldPoint(0, 0),
          lobby: true);
      final a = Float32List(MapGroundLayer.maxPoints * 2);
      final b = Float32List(MapGroundLayer.maxPoints * 2);
      const view = Rect.fromLTWH(160, 160, 320, 180);
      for (final mark in GroundMark.values) {
        final (na, nb) = MapGroundLayer.fill(map, view, mark, a, b);
        expect(na, greaterThan(0), reason: mark.name);
        for (final (buf, n) in [(a, na), (b, nb)]) {
          for (var i = 0; i < n; i++) {
            final x = buf[i * 2], y = buf[i * 2 + 1];
            expect(map.tileAt(x ~/ 16, y ~/ 16), 'g');
            expect(x, inInclusiveRange(view.left - 32, view.right + 32));
            expect(y, inInclusiveRange(view.top - 32, view.bottom + 32));
          }
        }
      }
    });
  });

  group('climate data', () {
    test('defaults are valid and round-trip', () {
      final d = ClimateData.defaults;
      final back = ClimateData.decode(d.encode());
      expect(back.biomes, d.biomes);
      expect(back.issues(const ['es-AR']), isEmpty);
    });

    test('the shipped climate.json is valid in every locale', () {
      final d =
          ClimateData.decode(File(ClimateData.assetPath).readAsStringSync());
      expect(d.issues(_locales), isEmpty);
      expect(d.biomes[kGrieta], kBiomeClimateDefaults[kGrieta]);
    });

    test('validation catches broken rules', () {
      final bad = ClimateData(biomes: {
        ...kBiomeClimateDefaults,
        kBosque: const BiomeClimate(
            allowed: {Weather.lluvia}, snowMelt: Weather.snow),
        'nope': const BiomeClimate(),
      }, fishSeasons: {
        'mojarra_claro': {},
      }, names: ClimateData.sourceNames);
      final issues = bad.issues(_locales);
      expect(issues.any((i) => i.contains('despejado')), isTrue);
      expect(issues.any((i) => i.contains('nope')), isTrue);
      expect(issues.any((i) => i.contains('mojarra_claro')), isTrue);
      expect(issues.any((i) => i.contains('zh-Hans')), isTrue);
    });

    test('installing overrides fish and crop seasons and biome rules', () {
      ClimateData(biomes: Map.of(kBiomeClimateDefaults)..addAll({
        kBosque: const BiomeClimate(exposure: Exposure.sheltered),
      }), fishSeasons: {
        'mojarra_claro': {Season.summer},
      }, cropSeasons: {
        'nabo_claro': {Season.winter},
      }).install();
      expect(LifeTimeRules.fishSeasons('mojarra_claro'), {Season.summer});
      expect(LifeTimeRules.cropWinterOnly('nabo_claro'), isTrue);
      expect(WeatherRules.dayWeather(3, 5, kBosque), Weather.despejado);
      ClimateData.restore();
      expect(LifeTimeRules.fishSeasons('mojarra_claro').length, 4);
    });
  });
}
