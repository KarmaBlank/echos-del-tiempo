// Guard (v0.49.20): hovering the seed slot of the farm bar (and every tool
// HUD slot) never builds the release-mode grey error box, also while the
// seed changes under the mouse or the chosen seed runs out.
import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import 'fishing_map_harness.dart';

PlayerProfile _profile(Map<String, int> seeds) => PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      unlockedZone: 1,
      life: LifeSkills(
        farm: FarmSkills(
          seeds: seeds,
          hoes: const ['azada_rama'],
          cans: const ['regadera_lata'],
        ),
      ),
    );

const _bags = <String, Map<String, int>>{
  'several': {'nabo_claro': 6, 'trigo_dorado': 4, 'calabaza_sendero': 2},
  'one': {'nabo_claro': 1},
  'empty': {},
};

const _farmKeys = [
  'hud-tool-hoe',
  'hud-tool-seed',
  'hud-seed-prev',
  'hud-seed-current',
  'hud-seed-next',
  'hud-tool-can',
  'hud-tool-fert',
];

const _rodKeys = ['hud-tool-rod', 'hud-tool-bait'];

void main() {
  for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
    for (final bag in _bags.entries) {
      for (final farm in [true, false]) {
        final w = size.width.toInt();
        testWidgets('hover ${farm ? 'huerta' : 'pesca'} ${bag.key} a $w',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await loadRealFonts(tester);
          final h = await FishingMapHarness.pump(tester,
              profile: _profile(bag.value));
          final c = h.c;
          if (farm) {
            const bf = TownLayout.baseFarm;
            // ignore: invalid_use_of_visible_for_testing_member
            c.teleport((bf.x + 1.5) * 16, (bf.y + 1.5) * 16);
            await h.frames(6);
            expect(c.activeTool, ActiveTool.hoe);
          }
          final mouse =
              await tester.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          for (final k in farm ? _farmKeys : _rodKeys) {
            final f = find.byKey(ValueKey(k));
            if (f.evaluate().isEmpty) continue;
            await mouse.moveTo(tester.getCenter(f));
            await h.frames(3);
            expect(tester.takeException(), isNull, reason: k);
            if (farm && k.startsWith('hud-tool-')) {
              expect(RetroHoverCard.anyShowing, isTrue, reason: 'tip $k');
            }
            if (farm && k == 'hud-tool-seed') {
              // Seed changes under the mouse (Q / the chips) while the
              // tip is open.
              for (var i = 0; i < 4; i++) {
                c.cycleSeed();
                await h.frames(2);
                expect(tester.takeException(), isNull, reason: 'cycle $i');
                c.prevSeedPick();
                await h.frames(2);
                expect(tester.takeException(), isNull, reason: 'prev $i');
              }
            }
            if (farm) {
              // The hero walks over the farm with the tip open: the
              // prompt above the bar comes and goes.
              const bf = TownLayout.baseFarm;
              for (var dx = -2; dx < 8; dx++) {
                for (var dy = -2; dy < 6; dy += 2) {
                  // ignore: invalid_use_of_visible_for_testing_member
                  c.teleport((bf.x + dx + 0.5) * 16, (bf.y + dy + 0.5) * 16);
                  await h.frames(2);
                  expect(tester.takeException(), isNull,
                      reason: 'walk $k $dx,$dy prompt=${c.toolPrompt}');
                }
              }
              // ignore: invalid_use_of_visible_for_testing_member
              c.teleport((bf.x + 1.5) * 16, (bf.y + 1.5) * 16);
              await h.frames(3);
            }
            if (farm && (k == 'hud-seed-next' || k == 'hud-seed-prev')) {
              await tester.tap(find.byKey(ValueKey(k)),
                  kind: PointerDeviceKind.mouse);
              await h.frames(3);
              expect(tester.takeException(), isNull, reason: 'tap $k');
              await mouse.moveTo(tester.getCenter(
                  find.byKey(ValueKey(k)).hitTestable().evaluate().isEmpty
                      ? find.byKey(const ValueKey('hud-tool-seed'))
                      : find.byKey(ValueKey(k))));
              await h.frames(3);
              expect(tester.takeException(), isNull, reason: 'rehover $k');
            }
          }
          await mouse.moveTo(Offset.zero);
          await h.frames(20);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
