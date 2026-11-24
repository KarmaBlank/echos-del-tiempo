// COLECCIÓN of fish and crops (weather_seasons.md § 7) on the shared
// DsCollectionTemplate (design_system.md): every fish / crop appears,
// undiscovered ones hide their info, the bestiary has no fish, the crop
// log migrates from old saves, and nothing overflows at the smallest
// window and the largest UI scale.
import 'package:echos_del_tiempo/features/bestiary/domain/bestiary_text.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_collection.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

PlayerProfile _profile() {
  final p = newProfile('Ana', 'guerrero');
  return p.copyWith(
      life: LifeSkills(
          log: const {'mojarra_claro': 12},
          farm: FarmSkills.fromJson({
            'crops': {cropKey('nabo_claro', CropQuality.raro): 2},
          })));
}

Future<void> _pump(WidgetTester tester, Size size, double scale,
    Widget Function(BuildContext) build) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadRealFonts(tester);
  await tester.pumpWidget(ProviderScope(
      child: MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
    child: MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: size.width * 0.6,
                height: size.height * 0.7,
                child: Builder(builder: build)))),
  )));
  await tester.pump();
}

void main() {
  test('bestiary has no fish', () {
    final ids = {for (final e in bestiaryEntries()) e.id};
    expect(ids.intersection(kFish.keys.toSet()), isEmpty);
  });

  test('old saves: crop log migrates from the crops bag', () {
    final f = FarmSkills.fromJson({
      'crops': {
        cropKey('nabo_claro', CropQuality.normal): 1,
        cropKey('nabo_claro', CropQuality.epico): 1,
      },
    });
    expect(f.cropDiscovered('nabo_claro'), isTrue);
    expect(f.cropLog['nabo_claro'], CropQuality.epico.index);
    expect(FarmSkills.fromJson(f.toJson()).cropLog, f.cropLog);
  });

  testWidgets('fish collection shows every fish; unknown ones hide info',
      (tester) async {
    await _pump(tester, const Size(1920, 1080), 1,
        (c) => fishCollection(c, _profile()));
    expect(tester.takeException(), isNull);
    final total = collectionFish.length;
    final badge = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('fish-col-progress')),
        matching: find.byType(Text)));
    expect(badge.data, contains('1/$total'));
    // Every species has a cell; only the caught one is not a "?".
    for (final f in collectionFish) {
      final unknown = find.byKey(ValueKey('fish-col-unknown-${f.id}'));
      expect(unknown, f.id == 'mojarra_claro' ? findsNothing : findsOneWidget,
          reason: f.id);
    }
    // Picking an undiscovered fish shows no hints (no name, no place).
    final hidden = collectionFish.firstWhere((f) => f.id != 'mojarra_claro');
    await tester.tap(find.byKey(ValueKey('fish-col-unknown-${hidden.id}')));
    await tester.pump();
    final detail = find.byKey(const ValueKey('fish-col-detail'));
    expect(find.descendant(of: detail, matching: find.textContaining('Dónde')),
        findsNothing);
  });

  testWidgets('crop collection lists every planted crop', (tester) async {
    await _pump(tester, const Size(1920, 1080), 1,
        (c) => cropCollection(c, _profile()));
    expect(tester.takeException(), isNull);
    for (final d in collectionCrops) {
      final unknown = find.byKey(ValueKey('crop-col-unknown-${d.id}'));
      expect(unknown, d.id == 'nabo_claro' ? findsNothing : findsOneWidget,
          reason: d.id);
    }
  });

  for (final size in const [Size(1024, 640), Size(1920, 1080)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('template fits at ${size.width.toInt()} × $scale',
          (tester) async {
        await _pump(tester, size, scale, (c) => fishCollection(c, _profile()));
        expect(tester.takeException(), isNull);
        await _pump(tester, size, scale, (c) => cropCollection(c, _profile()));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
