// Capturas de los ayudantes (v0.25.7, fuente rúnica, town_editor.md § 1). NO es
// parte de la suite. Correr con
//   flutter test tool/shots/v0257_fuente_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/town_build.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.25.7';

Future<void> _shot(WidgetTester tester, String name, Size size) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _run(WidgetTester tester, Size size) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await FishingMapHarness.pump(tester,
      profile: PlayerProfile(
          name: 'Ana',
          classId: 'guerrero',
          unlockedZone: 1,
          credits: 900000,
          materials: const {
            CraftMaterial.esquirla: 9999,
            CraftMaterial.cristal: 9999
          },
          life: LifeSkills(fishXp: 4000, farm: FarmSkills(xp: 4000))));
  final c = h.c;
  // ignore: invalid_use_of_visible_for_testing_member
  c.teleport(17.0 * 16, 12.4 * 16);
  await h.frames(6);
  c.handleKey(LogicalKeyboardKey.keyE);
  await h.frames(3);
  await _shot(tester, '01_fuente_panel', size);
  c.closePanel();
  expect(c.enterHirePick(BuildKind.huerta), isTrue);
  h.game.editZoom = 1;
  h.game.camX = 6 * 16;
  h.game.camY = 8 * 16;
  await h.frames(4);
  await _shot(tester, '02_elegir_huerta', size);
  c.exitTownEdit();
  expect(c.enterTownEdit(), isTrue);
  // Tope bajo solo para la captura (el costo sube con cada ampliación).
  final def = kTuning[TuningId.town]!;
  kTuning[TuningId.town] =
      TuningDef(def.name, {...def.values, 'maxExpansions': 4, 'maxPerSide': 2});
  addTearDown(() => kTuning[TuningId.town] = def);
  for (final s in [TownSide.norte, TownSide.sur, TownSide.este, TownSide.este]) {
    expect(c.expandTown(s), isTrue, reason: c.cannotExpandTown(s));
    await h.frames(1);
  }
  h.game.editZoom = 2;
  h.game.camX = -12 * 16;
  h.game.camY = -12 * 16;
  await h.frames(4);
  await _shot(tester, '03_limite_ampliacion', size);
  c.exitTownEdit();
  await h.frames(2);
}

void main() {
  testWidgets('1280x720', (t) => _run(t, const Size(1280, 720)));
}
