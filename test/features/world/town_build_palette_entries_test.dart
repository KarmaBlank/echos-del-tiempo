// Every EDITAR PUEBLO build-palette entry shows its own art and its own
// cost line (town_editor.md § 1.2). With PREVIEW=1 also writes the
// CULTIVO tab with the coop and the barn selected:
//   $env:PREVIEW = "1"; flutter test test/features/world/town_build_palette_entries_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_icon.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/town_build_palette.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_strings.dart';
import 'package:echos_del_tiempo/game_engine/data/animals_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/cozy_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/town_build.dart';
import 'package:echos_del_tiempo/game_engine/rules/cozy_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fishing_map_harness.dart';

final _shots = Platform.environment['PREVIEW'] != null;

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  await tester.runAsync(() async {
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final img = await layer.toImage(const Rect.fromLTWH(0, 0, 1280, 720));
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview/build_palette_fix').createSync(recursive: true);
    File('docs/preview/build_palette_fix/$name.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  Future<FishingMapHarness> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester,
        profile:
            PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 60000));
    expect(h.c.enterTownEdit(), isTrue);
    await h.frames(3);
    return h;
  }

  testWidgets('every entry: own sprite, own footprint, own cost and flags',
      (tester) async {
    final h = await open(tester);
    final ctx = tester.element(find.byType(TownBuildPalette));
    final s = worldStrings(ctx);
    final sprites =
        ProviderScope.containerOf(ctx).read(gameSpritesProvider).value!;
    final pieces = TownBuildPalette.pieces(s, h.c);
    final light = s.t('ui.town.edit.flag_light');
    final spriteOf = <String, String>{};
    for (final p in pieces) {
      final preview = find.byKey(ValueKey('town-piece-preview-${p.id}'));
      expect(preview, findsWidgets, reason: p.id);
      final icons = find.descendant(
          of: preview.first, matching: find.byType(LifeIcon));
      final def = construction(p.id);
      final painted = p.id == kFaroId ||
          def?.kind == BuildKind.huerta ||
          def?.kind == BuildKind.lago;
      if (painted) {
        // Drawn with the map painters (farm soil only for farms).
        expect(icons, findsNothing, reason: p.id);
      } else {
        expect(icons, findsOneWidget, reason: p.id);
        final id = tester.widget<LifeIcon>(icons).id;
        expect(sprites.lifeIcon(id, ''), isNotNull,
            reason: '${p.id}: manifest sprite $id');
        expect(spriteOf.values, isNot(contains(id)), reason: p.id);
        spriteOf[p.id] = id;
      }
      // Footprint: the catalog's (decorations and the lamp are 1×1).
      expect((p.w, p.h), def == null ? (1, 1) : (def.w, def.h),
          reason: p.id);
      // Light flag only on light sources.
      final lights = p.id == kFaroId || p.id == 'lamp';
      expect(p.flags.contains(light), lights, reason: p.id);
      expect(p.flags.toSet().length, p.flags.length, reason: p.id);
      // Cost: its own price, never a footprint glued in.
      final price = p.id == kFaroId
          ? TownRules.faroCost
          : p.id == kKitchenId
          ? TownRules.kitchenCost
          : animalHomeById(p.id)?.price ??
              (kFarmDecos.containsKey(p.id) ? CozyRules.decorCost(p.id) : null);
      if (price != null) {
        expect(p.cost, s.t('ui.town.edit.gold', {'cost': price}),
            reason: p.id);
      }
      expect(p.cost ?? '', isNot(contains('×')), reason: p.id);
    }
    expect(spriteOf['gallinero'], animalHomeById('gallinero')!.sprite);
    expect(spriteOf['establo'], animalHomeById('establo')!.sprite);
    expect(spriteOf['fence'], isNot(spriteOf['fence_gate']));
    // The town kitchen (farming.md § 17): its own sprite, size and flags.
    expect(spriteOf[kKitchenId], 'cocina');
    final k = pieces.firstWhere((p) => p.id == kKitchenId);
    expect((k.w, k.h), (3, 3));
    expect(k.flags, contains(s.t('ui.town.edit.flag_unique')));
    h.c.exitTownEdit();
    await h.frames(2);
  });

  testWidgets('CULTIVO tab: coop and barn selected', (tester) async {
    final h = await open(tester);
    await tester.tap(find.byKey(const ValueKey('town-build-filter-farm')));
    await h.frames(2);
    for (final id in ['gallinero', 'establo']) {
      await tester.tap(find.byKey(ValueKey('town-edit-build-$id')));
      await h.frames(2);
      final preview = find.descendant(
          of: find.byKey(const ValueKey('town-build-detail-preview')),
          matching: find.byType(LifeIcon));
      expect(tester.widget<LifeIcon>(preview).id, id);
      // Wait past the double-click window so the next tap only selects.
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, 'cultivo_$id');
    }
    h.c.exitTownEdit();
    await h.frames(2);
  });
}
