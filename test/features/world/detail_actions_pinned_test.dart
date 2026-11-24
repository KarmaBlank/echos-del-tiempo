// Grid + detail layouts: the detail column fills the panel body and its
// action area (quantity, total, COMPRAR) stays pinned and visible without
// scrolling, even with a long description (panels.md "Grillas de
// comercio", design_system.md DsDetailPane).
import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/trader_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

PlayerProfile _profile() => progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      credits: 900,
      life:
          LifeSkills(farm: FarmSkills(xp: 300, seeds: const {'nabo_claro': 6})),
    ));

/// Fully inside the screen and the hit-test reaches it (not covered,
/// not clipped by a scroll).
void _visible(WidgetTester tester, Finder f, Size screen) {
  expect(f, findsOneWidget);
  final r = tester.getRect(f);
  expect(r.top >= 0 && r.left >= 0, isTrue, reason: '$r');
  expect(r.bottom <= screen.height && r.right <= screen.width, isTrue,
      reason: '$r in $screen');
  expect(f.hitTestable(), findsOneWidget);
}

void main() {
  for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
    final w = size.width.toInt();

    testWidgets('NPC shop COMPRAR visible at $w', (tester) async {
      final n = kBiomeNpcs.first;
      final c = await pumpPanel(tester,
          profile: _profile(),
          build: (v, c) => BiomeNpcPanel(view: v, controller: c));
      tester.view.physicalSize = size;
      c.openResident(n);
      await tester.pump();
      await tester.pump();
      // Skip the typewriter so the menu shows.
      await tester.tap(find.byKey(const ValueKey('ds-dialogue-text')));
      await tester.pump();
      final choice = find.byKey(const ValueKey('npc-choice-comprar'));
      expect(choice, findsOneWidget);
      await tester.tap(choice);
      await tester.pump();
      final buy = find.byWidgetPredicate((wd) =>
          wd.key is ValueKey<String> &&
          (wd.key! as ValueKey<String>).value.startsWith('npc-seed-buy-'));
      _visible(tester, buy, size);
      // The detail fills the panel body (not a small box).
      final detail =
          tester.getRect(find.byKey(const ValueKey('npc-shop-detail')));
      expect(detail.height, greaterThan(size.height * 0.4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('trader COMPRAR visible at $w', (tester) async {
      await pumpPanel(tester,
          profile: _profile(),
          build: (v, c) =>
              TraderPanel(view: v, controller: c, mode: 0, tab: 1));
      tester.view.physicalSize = size;
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('trade-seed-trigo_dorado')));
      await tester.pump();
      _visible(tester,
          find.byKey(const ValueKey('trade-seed-buy-trigo_dorado')), size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DsDetailPane pins actions with a long body at $w',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Expanded(child: SizedBox()),
            SizedBox(
              width: 280,
              child: DsDetailPane(
                body: Text('Lorem ipsum dolor sit amet. ' * 400),
                actions: DsButton('COMPRAR',
                    key: const ValueKey('buy'),
                    kind: DsButtonKind.primary,
                    onPressed: () {}),
              ),
            ),
          ]),
        ),
      ));
      _visible(tester, find.byKey(const ValueKey('buy')), size);
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
