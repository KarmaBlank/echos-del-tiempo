// HUD clock with season and weather (weather_seasons.md § 6.2): no text
// overflows or gets cut at the smallest window and the largest UI scale.
import 'package:echos_del_tiempo/features/world/presentation/hud/day_clock.dart';
import 'package:echos_del_tiempo/game_engine/rules/weather_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';

void main() {
  for (final size in const [Size(1024, 640), Size(1920, 1080)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('clock fits at ${size.width.toInt()} × $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await loadRealFonts(tester);
        // Winter, last day, foggy: the longest strings.
        final day = 4 * WeatherRules.seasonDays;
        final sky = SkyState(
            day: day,
            clock: 100,
            seed: 3,
            weather: Weather.fog,
            from: 0,
            to: 1,
            tomorrow: Weather.snow);
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(
              size: size, textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topRight,
              child: DayClock(sky: sky),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('hud-season-winter')), findsOneWidget);
        expect(find.byKey(const ValueKey('hud-weather-fog')), findsOneWidget);
        for (final k in ['hud-clock-text', 'hud-season-text']) {
          final p = tester.renderObject<RenderParagraph>(find.descendant(
              of: find.byKey(ValueKey(k)), matching: find.byType(RichText)));
          expect(p.didExceedMaxLines, isFalse, reason: '$k cut');
          expect(p.size.width, lessThanOrEqualTo(size.width));
        }
        final box = tester.getRect(find.byKey(const ValueKey('hud-day-clock')));
        expect(box.right, lessThanOrEqualTo(size.width));
        expect(box.left, greaterThanOrEqualTo(0));
        final txt = tester.widget<Text>(
            find.byKey(const ValueKey('hud-season-text')));
        expect(txt.data, contains('Último día de'));
        expect(txt.data, contains('mañana'));
        // The toggle opens the detail: now, next and after.
        await tester.tap(find.byKey(const ValueKey('hud-season-toggle')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final k in ['hud-season-now', 'hud-season-next', 'hud-season-after']) {
          expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
        }
      });
    }
  }
}
