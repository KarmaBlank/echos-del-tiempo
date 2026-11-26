import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/profession_gear_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fishing_map_harness.dart';

/// A weapon seed in hand over tilled soil (v0.49.22): the farm prompt
/// names it instead of throwing, so the view keeps updating.
void main() {
  testWidgets('weapon seed over a tilled plot: prompt names it, no freeze',
      (tester) async {
    final ws = kWeaponSeeds.keys.first;
    final h = await FishingMapHarness.pump(tester,
        profile: PlayerProfile(
          name: 'Ana',
          classId: 'guerrero',
          unlockedZone: 1,
          life: LifeSkills(
            farm: FarmSkills(
              wseeds: {ws: 2},
              seed: ws,
              hoes: const ['azada_rama'],
              cans: const ['regadera_lata'],
            ),
          ),
        ));
    final c = h.c;
    const bf = TownLayout.baseFarm;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((bf.x + 1.5) * 16, (bf.y + 1.5) * 16);
    await h.frames(6);
    final (tx, ty) = c.farmTile!;
    c.selectFarmHand(FarmHand.hoe);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    await h.frames(8);
    expect(c.plotAt(tx, ty), isNotNull);
    c.selectFarmHand(FarmHand.seed);
    await h.frames(2);
    final hint = c.farmHint();
    expect(hint, contains(c.plantableName(ws)));
    expect(c.view!.promptText, startsWith(hint!));
    expect(tester.takeException(), isNull);
    // The view still follows the hero after that.
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(17.0 * 16, 12.4 * 16);
    await h.frames(4);
    expect(c.view!.promptText, isNot(startsWith(hint)));
  });
}
