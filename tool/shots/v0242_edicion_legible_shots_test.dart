// Capturas de la edición del pueblo (v0.24.2, docs/specs/town_editor.md).
// NO es parte de la suite. Correr con
//   flutter test tool/shots/v0242_edicion_legible_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.24.2';


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

PlayerProfile _profile() => PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      unlockedZone: 1,
      credits: 60000,
      materials: const {CraftMaterial.esquirla: 90, CraftMaterial.cristal: 30},
      life: LifeSkills(
        bag: const {'carpa_musgo': 3, 'trucha_cobre': 4},
        farm: FarmSkills(seeds: const {'nabo_claro': 6, 'trigo_dorado': 4}),
      ),
    );


Future<void> _run(WidgetTester tester, Size size, String sfx) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await FishingMapHarness.pump(tester, profile: _profile());
  final c = h.c;
  final game = h.game;
  final box = Offset.zero & size;
  Offset? screenOf((int, int) tile) {
    for (var y = 0.0; y < box.height; y += 3) {
      for (var x = 0.0; x < box.width; x += 3) {
        if (game.tileAtScreen(Offset(x, y)) == tile) return Offset(x + 4, y + 4);
      }
    }
    return null;
  }

  // Fuente rúnica: filas completas, sin "…".
  // ignore: invalid_use_of_visible_for_testing_member
  c.teleport(17.0 * 16, 12.4 * 16);
  await h.frames(6);
  c.handleKey(LogicalKeyboardKey.keyE);
  await h.frames(3);
  await _shot(tester, 'fuente_$sfx', size);
  c.closePanel();
  await h.frames(2);

  // PESCA Y CULTIVO: pestañas con íconos.
  c.openPanel(WorldPanel.character);
  await h.frames(2);
  await tester.tap(find.text('PESCA Y CULTIVO'));
  await h.frames(3);
  await _shot(tester, 'pesca_cultivo_$sfx', size);
  await tester.tap(find.byKey(const ValueKey('life-cat-pescados')));
  await h.frames(3);
  await _shot(tester, 'pesca_cultivo_pescados_$sfx', size);
  c.closePanel();
  await h.frames(2);

  // Juego normal: carteles de los lugares (fila de arriba).
  // ignore: invalid_use_of_visible_for_testing_member
  c.teleport(17.0 * 16, 6.0 * 16);
  await h.frames(40);
  await _shot(tester, 'lugares_juego_$sfx', size);

  expect(c.enterTownEdit(), isTrue);
  game.editZoom = 2;
  game.camX = -9 * 16;
  game.camY = -9 * 16;
  await h.frames(4);
  expect(find.byType(WorldHud), findsNothing);
  await _shot(tester, 'edicion_vista_$sfx', size);

  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(screenOf((10, -3))!);
  await h.frames(3);
  expect(find.byKey(const ValueKey('town-strip-n')), findsOneWidget);
  await _shot(tester, 'edicion_franja_hover_$sfx', size);

  game.editZoom = 1;
  game.camX = 0;
  game.camY = -4 * 16;
  await mouse.moveTo(Offset.zero);
  await h.frames(4);
  await _shot(tester, 'edicion_zoom1_$sfx', size);

  // MOVER la huerta un tile: pisa su lugar viejo y es válido.
  game.editZoom = 1.5;
  game.camX = 6 * 16;
  game.camY = 6 * 16;
  c.editClick(20, 19);
  c.editStartMove();
  await h.frames(2);
  await mouse.moveTo(screenOf((20, 18))!);
  await h.frames(3);
  expect(c.editGhostError, isNull);
  await _shot(tester, 'edicion_mover_$sfx', size);
}

void main() {
  testWidgets('1280x720', (t) => _run(t, const Size(1280, 720), '1280'));
  testWidgets('1024x640', (t) => _run(t, const Size(1024, 640), '1024'));
}
