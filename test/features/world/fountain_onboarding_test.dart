import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';

import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fishing_map_harness.dart';

/// Rune fountain onboarding (town_editor.md § 1.5–1.6): gold "!" until
/// the first visit, saved in the profile; locked hires are grey with the
/// PROFESSION level and the current level in the tooltip.
void main() {
  PlayerProfile ana({LifeSkills? life}) => PlayerProfile(
      name: 'Ana', classId: 'guerrero', unlockedZone: 1, life: life ?? LifeSkills());

  test('seen flag survives a save / load and is per profile', () {
    final p = ana();
    expect(QuestTrackRules.seenFountain(p), isFalse);
    final seen = QuestTrackRules.markSeen(p, const TownState(),
        QuestTrackRules.fountainKey)!;
    expect(QuestTrackRules.seenFountain(seen), isTrue);
    final back = PlayerProfile.fromJson(seen.toJson());
    expect(QuestTrackRules.seenFountain(back), isTrue);
    // An old save without the key still shows the marker.
    expect(QuestTrackRules.seenFountain(PlayerProfile.fromJson(p.toJson())),
        isFalse);
  });

  testWidgets('marker before the first open, gone after; hire locked by level',
      (tester) async {
    final h = await FishingMapHarness.pump(tester, profile: ana());
    final c = h.c;
    expect(c.fountainAlert, isTrue);
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(17.0 * 16, 12.4 * 16);
    await h.frames(6);
    // FOUNTAIN_PREVIEW=1 writes docs/preview/rune_fountain_alert.png.
    if (Platform.environment['FOUNTAIN_PREVIEW'] == '1') {
      final png = await tester.runAsync(() async {
        final img = await captureImage(find.byType(WorldScreen).evaluate().single);
        return (await img.toByteData(format: ui.ImageByteFormat.png))!;
      });
      Directory('docs/preview').createSync(recursive: true);
      File('docs/preview/rune_fountain_alert.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    }
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    await h.frames(2);
    expect(c.view!.panel, WorldPanel.fountain);
    expect(c.fountainAlert, isFalse);
    final me = c.view!.me!.profile;
    expect(QuestTrackRules.seenFountain(me), isTrue);
    expect(QuestTrackRules.seenFountain(PlayerProfile.fromJson(me.toJson())),
        isTrue);

    final now = FarmingRules.level(me);
    final want =
        'Necesitás subir tu oficio de Granjero a nivel 5 (ahora: nivel $now)';
    final btn = tester.widget<DsButton>(
        find.byKey(const ValueKey('fountain-hire-farmer')));
    expect(btn.onPressed, isNull);
    expect(btn.tooltip, want);
    expect(c.cannotPickHire(BuildKind.huerta), want);
  });

  testWidgets('hire enabled once the profession level is met', (tester) async {
    final h = await FishingMapHarness.pump(tester,
        profile: ana(life: LifeSkills(farm: FarmSkills(xp: 1000000))));
    final c = h.c;
    expect(c.hireLevelWhy(BuildKind.huerta), isNull);
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(17.0 * 16, 12.4 * 16);
    await h.frames(6);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    await h.frames(2);
    final btn = tester.widget<DsButton>(
        find.byKey(const ValueKey('fountain-hire-farmer')));
    expect(btn.onPressed, isNotNull);
    expect(btn.tooltip, isNull);
  });
}