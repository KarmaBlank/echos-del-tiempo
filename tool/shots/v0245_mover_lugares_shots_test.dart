// Capturas de mover los lugares fijos (v0.24.5, docs/specs/town_editor.md
// § 3.3). NO es parte de la suite. Correr con
//   flutter test tool/shots/v0245_mover_lugares_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.24.5';

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

Future<void> _run(WidgetTester tester, Size size, String sfx) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await FishingMapHarness.pump(tester,
      profile: PlayerProfile(name: 'Ana', classId: 'guerrero', unlockedZone: 1));
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

  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);

  expect(c.enterTownEdit(), isTrue);
  game.editZoom = 1;
  game.camX = 0;
  game.camY = -2 * 16;
  await h.frames(4);
  await _shot(tester, 'base_$sfx', size);

  // Clic en la forja: MOVER.
  c.editClick(21, 3);
  await h.frames(3);
  await _shot(tester, 'forja_opciones_$sfx', size);
  c.editStartMove();
  await mouse.moveTo(screenOf((11, 3))!);
  await h.frames(3);
  expect(c.editGhostError, isNotNull);
  await _shot(tester, 'forja_mover_rojo_$sfx', size);
  await mouse.moveTo(screenOf((26, 8))!);
  await h.frames(3);
  expect(c.editGhostError, isNull);
  await _shot(tester, 'forja_mover_verde_$sfx', size);
  c.editClick(26, 8);
  await h.frames(4);
  await mouse.moveTo(Offset.zero);
  await h.frames(2);
  await _shot(tester, 'forja_movida_$sfx', size);

  // Pueblo reacomodado: tablero, comerciante y portal en otro lado.
  for (final (from, to) in [
    ((12, 3), (3, 8)),
    ((12, 17), (25, 2)),
    ((4, 3), (8, 2)),
  ]) {
    c.editClick(from.$1, from.$2);
    c.editStartMove();
    c.editHover(to.$1, to.$2);
    expect(c.editGhostError, isNull, reason: '$from → $to');
    c.editClick(to.$1, to.$2);
    await h.frames(2);
  }
  await h.frames(3);
  await _shot(tester, 'reacomodado_edicion_$sfx', size);
  c.exitTownEdit();
  // ignore: invalid_use_of_visible_for_testing_member
  c.teleport(17.0 * 16, 9.0 * 16);
  await h.frames(40);
  await _shot(tester, 'reacomodado_juego_$sfx', size);
}

void main() {
  testWidgets('1280x720', (t) => _run(t, const Size(1280, 720), '1280'));
}
