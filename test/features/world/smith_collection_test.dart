// OFICIOS → HERRERÍA → COLECCIÓN (mining_smithing.md § 2.1) on the shared
// DsCollectionTemplate (design_system.md § 6.1): every material appears,
// undiscovered ones are a grey "?", discovered ones say where they were
// found, and nothing overflows at the smallest window and largest scale.
import 'package:echos_del_tiempo/features/world/presentation/panels/smith_collection.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
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
          ores: const {'ore_copper': 4},
          oreLog: const {'ore_copper': OreFind(3, 'mine:bosque', 7)}));
}

Future<void> _pump(WidgetTester tester, Size size, double scale) async {
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
                child: Builder(
                    builder: (c) => smithCollection(c, _profile()))))),
  )));
  await tester.pump();
}

void main() {
  testWidgets('every material has a cell; only found ones are known',
      (tester) async {
    await _pump(tester, const Size(1920, 1080), 1);
    expect(tester.takeException(), isNull);
    final badge = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('smith-col-progress')),
        matching: find.byType(Text)));
    expect(badge.data, contains('1/${SmithCollection.materials.length}'));
    for (final id in SmithCollection.materials.map((d) => d.id)) {
      expect(find.byKey(ValueKey('smith-col-unknown-$id')),
          id == 'ore_copper' ? findsNothing : findsOneWidget,
          reason: id);
    }
    await tester.tap(find.byKey(const ValueKey('smith-col-ore_copper')));
    await tester.pump();
    final detail = find.byKey(const ValueKey('smith-col-detail'));
    expect(
        find.descendant(of: detail, matching: find.textContaining('BOSQUE')),
        findsWidgets);
    expect(find.descendant(of: detail, matching: find.textContaining('7')),
        findsWidgets);
  });

  for (final size in const [Size(1024, 640), Size(1920, 1080)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('smith collection fits at ${size.width.toInt()} × $scale',
          (tester) async {
        await _pump(tester, size, scale);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('smith-col-ore_copper')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
