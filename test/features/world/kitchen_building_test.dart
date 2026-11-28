import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/cooking_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/town_build.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import '../panel_test_harness.dart';
import 'fishing_map_harness.dart';

/// The town kitchen (docs/specs/farming.md § 17): a built COCINA shows a
/// gold "!" until the first open; E opens the cooking screen; OFICIOS →
/// INVENTARIO → CULTIVO no longer has a COCINA filter.
/// `PREVIEW=1` writes docs/preview/kitchen/*.png.
final _on = Platform.environment['PREVIEW'] == '1';

Future<void> _shot(WidgetTester tester, Finder f, String name) async {
  if (!_on) return;
  final png = await tester.runAsync(() async {
    final img = await captureImage(f.evaluate().single);
    return (await img.toByteData(format: ui.ImageByteFormat.png))!;
  });
  Directory('docs/preview/kitchen').createSync(recursive: true);
  File('docs/preview/kitchen/$name').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  PlayerProfile ana() => PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      unlockedZone: 1,
      life: LifeSkills(farm: FarmSkills.initial));

  testWidgets('"!" until the first open; E opens the cooking screen',
      (tester) async {
    if (_on) await loadRealFonts(tester);
    final h = await FishingMapHarness.pump(tester, profile: ana());
    final c = h.c;
    expect(c.kitchenAlert, isTrue);
    // Build the kitchen on the first free spot (host side).
    late TownBuild k;
    // ignore: invalid_use_of_visible_for_testing_member
    c.debugTown((t) {
      final (ox, oy) = t.origin;
      for (var y = 2; y < 30; y++) {
        for (var x = 2; x < 40; x++) {
          final r = TownRules.place(t, kKitchenId, x + ox, y + oy).town;
          if (r == null) continue;
          k = r.builds.firstWhere((b) => b.kind == BuildKind.cocina);
          return r;
        }
      }
      throw StateError('no free spot');
    });
    await h.frames(2);
    final (ox, oy) = c.town.origin;
    final r = k.bounds;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((r.x + ox + 1.5) * 16, (r.bottom + oy + 0.4) * 16);
    await h.frames(8);
    expect(c.nearKitchen, isTrue);
    expect(c.actionTarget?.key, 'kitchen:${k.id}');
    await _shot(tester, find.byType(WorldScreen), 'kitchen_town_alert.png');

    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    await h.frames(3);
    expect(c.view!.panel, WorldPanel.kitchen);
    expect(find.byKey(const ValueKey('panel-kitchen')), findsOneWidget);
    expect(find.byType(CookingView), findsOneWidget);
    expect(c.kitchenAlert, isFalse);
    expect(QuestTrackRules.seenKitchen(c.view!.me!.profile), isTrue);
    await _shot(tester, find.byType(WorldScreen), 'kitchen_cooking_screen.png');

    c.closePanel();
    await h.frames(3);
    expect(c.kitchenAlert, isFalse);
  });

  testWidgets('OFICIOS → INVENTARIO → CULTIVO has no COCINA filter',
      (tester) async {
    if (_on) await loadRealFonts(tester);
    final sprites = await tester.runAsync(
        () async => GameSprites.load(await SpriteCatalog.load()));
    await pumpPanel(tester,
        profile: ana(),
        sprites: sprites,
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.oficios));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('oficios-sub-inventario')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('oficio-bag-cultivo')));
    await tester.pump();
    expect(find.byKey(const ValueKey('oficio-filter-coleccion')), findsOneWidget);
    expect(find.byKey(const ValueKey('oficio-filter-cocina')), findsNothing);
    expect(find.byType(CookingView), findsNothing);
    await _shot(tester, find.byType(CharacterPanel), 'oficios_without_cocina.png');
  });
}
