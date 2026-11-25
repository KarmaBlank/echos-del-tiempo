// Previews of the shared item grid (design_system.md § 6.2). Only runs
// with PREVIEW_SHOTS=1:
//   $env:PREVIEW_SHOTS = "1"; flutter test test/design/grid_preview_shots_test.dart
// Writes docs/preview/design_system/{atoms,molecules,organisms,templates}.png
// and docs/preview/grids/*.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/app/design/gallery/ds_gallery_screen.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:echos_del_tiempo/core/settings/crt_filter.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';
import '../real_fonts.dart';

final _on = Platform.environment['PREVIEW_SHOTS'] != null;

Future<void> _save(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final b = tester.renderObjectList(find.byType(RepaintBoundary)).first
        as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path).parent.createSync(recursive: true);
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
    img.dispose();
  });
}

void main() {
  const pages = {
    'atoms': DsGalleryPage.buttons,
    'molecules': DsGalleryPage.surfaces,
    'organisms': DsGalleryPage.transfer,
    'templates': DsGalleryPage.grids,
  };
  for (final e in pages.entries) {
    testWidgets('design system ${e.key}', (tester) async {
      await loadRealFonts(tester);
      await tester.runAsync(CrtShaders.load);
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(UiTheme.reset);
      addTearDown(RetroType.reset);
      await tester.pumpWidget(RepaintBoundary(
          child: EcosApp(home: DsGalleryScreen(initialPage: e.value))));
      await tester.pump();
      await tester.pump();
      await _save(tester, 'docs/preview/design_system/${e.key}.png');
    }, skip: !_on);
  }

  testWidgets('caravana COMPRAR', (tester) async {
    final c = await pumpPanel(tester,
        profile: progression.normalize(PlayerProfile(
            name: 'Ana',
            classId: 'guerrero',
            credits: 900,
            life: LifeSkills(
                farm: FarmSkills(xp: 300, seeds: const {'nabo_claro': 6})))),
        build: (v, c) => RepaintBoundary(
            child: BiomeNpcPanel(view: v, controller: c)));
    tester.view.physicalSize = const Size(1280, 720);
    c.openResident(kBiomeNpcs.first);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ds-dialogue-text')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('npc-choice-comprar')));
    await tester.pump();
    await tester.pump();
    await _save(tester, 'docs/preview/grids/shop_caravana_1280.png');
  }, skip: !_on);
}
