// AGROPECUARIO and NPC shop: inventory grid (44 px icon cells, no text
// under the icon), filters (kind, seed biome, grow time), standard hover
// card and buying, without overflow at 1280x720 (fishing.md § 5).
import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/seed_text.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/trader_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

PlayerProfile _profile() => progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      credits: 900,
      life: LifeSkills(
        farm: FarmSkills(
          hoes: const ['azada_rama'],
          cans: const ['regadera_lata'],
        ),
      ),
    ));

List<CropDef> get _seeds => [
      for (final s in kCrops.values)
        if (s.seedPrice > 0) s
    ];

String _gold(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('trade-gold-have'))).data!;

Future<void> _open(WidgetTester tester, Size size) async {
  await pumpPanel(tester,
      profile: _profile(),
      build: (v, c) => TraderPanel(view: v, controller: c, mode: 0, tab: 1));
  tester.view.physicalSize = size;
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('trade-filter-semillas')));
  await tester.pump();
}

void main() {
  testWidgets('the trader panel has no MI PUESTO button', (tester) async {
    await _open(tester, const Size(1280, 720));
    expect(find.byKey(const ValueKey('trade-stall')), findsNothing);
  });

  for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
    testWidgets('seed grid fits at ${size.width.toInt()}', (tester) async {
      await _open(tester, size);
      expect(tester.takeException(), isNull);
      final s = _seeds.first;
      // Same cell as INVENTARIO: 44 px, icon only.
      expect(tester.getSize(find.byKey(ValueKey('trade-seed-${s.id}-tip'))),
          const Size(44, 44));
    });
  }

  testWidgets('seed filters: biome and grow time', (tester) async {
    await _open(tester, const Size(1280, 720));
    final long = _seeds.where((s) => GrowBucket.of(s) == GrowBucket.long);
    final short = _seeds.where((s) => GrowBucket.of(s) == GrowBucket.short);
    await tester.tap(find.byKey(const ValueKey('trade-grow-long')));
    await tester.pump();
    for (final s in long) {
      expect(find.byKey(ValueKey('trade-seed-${s.id}')), findsOneWidget);
    }
    for (final s in short) {
      expect(find.byKey(ValueKey('trade-seed-${s.id}')), findsNothing);
    }
    await tester.tap(find.byKey(const ValueKey('trade-grow-all')));
    await tester.pump();
    final b = _seeds.first.biome;
    await tester.tap(find.byKey(ValueKey('trade-biome-$b')));
    await tester.pump();
    for (final s in _seeds) {
      expect(find.byKey(ValueKey('trade-seed-${s.id}')),
          s.biome == b ? findsOneWidget : findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('hover shows the standard card; buying still works',
      (tester) async {
    await _open(tester, const Size(1280, 720));
    final s = _seeds.first;
    final cell = find.byKey(ValueKey('trade-seed-${s.id}-tip'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(cell));
    await tester.pumpAndSettle();
    expect(find.byType(DsTooltipCard), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('trade-seed-${s.id}')));
    await tester.pump();
    final before = _gold(tester);
    await tester.tap(find.byKey(ValueKey('trade-seed-buy-${s.id}')));
    await tester.pumpAndSettle();
    expect(_gold(tester), isNot(before));
    expect(tester.takeException(), isNull);
  });
}
