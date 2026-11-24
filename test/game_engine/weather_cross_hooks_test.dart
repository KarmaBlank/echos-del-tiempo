// Cross-branch hooks of weather and seasons (weather_seasons.md) with
// mining/smithing (mining_smithing.md) and world events
// (world_events.md): baits in veins, season-limited materials and the
// climate condition of events.
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/bait_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/world_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/weather_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_event_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mining', () {
    test('today every material is found all year', () {
      for (final d in kSmithMaterials.values) {
        expect(d.seasons, isEmpty, reason: d.id);
        expect(MiningRules.inSeason(d, 1), isTrue);
      }
    });

    test('a season-limited material only in its season', () {
      const d = SmithMaterialDef('x', 'X', SmithMatKind.rare,
          seasons: {'winter'});
      final winterDay = WeatherRules.seasonDays * 3 + 1;
      expect(WeatherRules.season(winterDay), Season.winter);
      expect(MiningRules.inSeason(d, winterDay), isTrue);
      expect(MiningRules.inSeason(d, 1), isFalse);
    });

    test('a vein sometimes gives a bait', () {
      expect(MiningRules.t.d('mineBaitChance'), inExclusiveRange(0, 0.2));
      var i = 0;
      final rolls = [0.0, 0.0];
      final b = MiningRules.veinBait(() => rolls[i++]);
      expect(kBaits.containsKey(b), isTrue);
      expect(MiningRules.veinBait(() => 0.99), isNull);
    });
  });

  group('world events', () {
    test('season / weather condition', () {
      const any = WorldEventDef(id: 'a', category: WorldEventCategory.visitor);
      const winter = WorldEventDef(
          id: 'w', category: WorldEventCategory.visitor, season: 'winter');
      final f = WorldEventRules.climateCondition(7, 1);
      expect(f(any), isTrue);
      expect(f(winter), isFalse);
      final weather = WeatherRules.dayWeather(7, 1, null).name;
      final other = Weather.values.firstWhere((w) => w.name != weather).name;
      expect(
          f(WorldEventDef(
              id: 'x', category: WorldEventCategory.visitor, weather: weather)),
          isTrue);
      expect(
          f(WorldEventDef(
              id: 'y', category: WorldEventCategory.visitor, weather: other)),
          isFalse);
    });

    test('json round trip and validation', () {
      const e = WorldEventDef(
          id: 'w',
          category: WorldEventCategory.visitor,
          season: 'winter',
          weather: 'snow');
      final back = WorldEventDef.fromJson(e.toJson());
      expect(back.season, 'winter');
      expect(back.weather, 'snow');
      const bad = WorldEventsConfig(events: [
        WorldEventDef(
            id: 'b',
            category: WorldEventCategory.visitor,
            season: 'monsoon',
            weather: 'hail'),
      ]);
      final p = bad.validate(const []);
      expect(p.any((s) => s.contains('monsoon')), isTrue);
      expect(p.any((s) => s.contains('hail')), isTrue);
    });
  });
}
