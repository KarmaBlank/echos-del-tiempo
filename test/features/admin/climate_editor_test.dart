import 'dart:io';

import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/climate_editor_controller.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/weather_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/climate_data_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import 'fake_admin_host.dart';

/// CLIMA area of the Editor (docs/specs/weather_seasons.md § 8).
void main() {
  Future<(AdminController, FakeAdminHost)> admin(WidgetTester? t) async {
    final host = FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    });
    final c = AdminController(host: host);
    if (t == null) {
      await c.load();
    } else {
      await t.runAsync(c.load);
    }
    return (c, host);
  }

  // The game loads the data file at startup (ClimateDataLoader).
  setUp(() => ClimateData.decode(
          File(ClimateData.assetPath).readAsStringSync())
      .install());
  tearDown(ClimateData.restore);

  test('edit biome rules and seasons, save writes and applies', () async {
    final (b, host) = await admin(null);
    final c = ClimateEditorController(balance: b);
    expect(c.dirty, isFalse);
    expect(c.issues, isEmpty);
    c.setExposure(kBosque, Exposure.sheltered);
    c.toggleFishSeason('mojarra_claro', Season.summer);
    expect(c.dirty, isTrue);
    expect(await c.save(), isTrue);
    expect(host.files.keys.any((k) => k.endsWith('climate.json')), isTrue);
    expect(WeatherRules.hasSky(kBosque), isFalse);
    expect(c.dirty, isFalse);
  });

  test('a missing language blocks saving', () async {
    final (b, _) = await admin(null);
    final c = ClimateEditorController(balance: b);
    final key = c.draft.names.keys.first;
    c.setText(key, c.locales.last, '');
    expect(c.issues, isNotEmpty);
    expect(await c.save(), isFalse);
    expect(c.message, contains('No se guardó'));
  });

  test('numbers go to the Balance draft', () async {
    final (b, _) = await admin(null);
    final c = ClimateEditorController(balance: b);
    c.setValue(BalanceKind.town, 'seasonDays', 9);
    expect(c.value(BalanceKind.town, 'seasonDays'), 9);
    expect(ClimateEditorController.seasonKeys(Season.winter),
        contains('wWinterSnow'));
    for (final k in ClimateEditorController.baitKeys('lombriz')) {
      expect(c.value(BalanceKind.fishing, k), isNotNull, reason: k);
    }
  });

  testWidgets('CLIMA tab: grid with detail and subtabs', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await loadRealFonts(tester);
    final (b, _) = await admin(tester);
    final c = ClimateEditorController(balance: b);
    await tester.pumpWidget(
        AdminApp(controller: b, climate: c, initialArea: EditorArea.climate));
    await tester.pump();
    expect(find.byKey(const ValueKey('climate-tabs')), findsOneWidget);
    expect(find.byKey(const ValueKey('climate-detail')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('climate-exp-sheltered')));
    await tester.pump();
    expect(c.dirty, isTrue);
    for (var i = 1; i < 6; i++) {
      await tester.tap(find.text(const [
        'BIOMAS', 'ESTACIONES', 'PECES', 'CULTIVOS', 'CEBOS', 'TEXTOS'
      ][i]));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
