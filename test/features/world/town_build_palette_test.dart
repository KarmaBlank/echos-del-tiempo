import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fishing_map_harness.dart';

void main() {
  testWidgets('paleta del pueblo: el hover no mueve la casilla y el clic la elige',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester,
        profile: PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 60000));
    expect(h.c.enterTownEdit(), isTrue);
    await h.frames(3);

    final cell = find.byKey(const ValueKey('town-edit-build-huerta_chica'));
    final palette = find.byKey(const ValueKey('town-build-palette'));
    expect(cell, findsOneWidget);
    final rect0 = tester.getRect(cell);
    final pal0 = tester.getRect(palette);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    for (var i = 0; i < 5; i++) {
      await mouse.moveTo(rect0.center);
      await h.frames(2);
      expect(tester.getRect(cell), rect0);
      expect(tester.getRect(palette), pal0);
      // Se mueve dentro de la casilla: sigue quieta.
      await mouse.moveTo(rect0.center + const Offset(6, 6));
      await h.frames(2);
      expect(tester.getRect(cell), rect0);
      await mouse.moveTo(Offset.zero);
      await h.frames(2);
      expect(tester.getRect(cell), rect0);
      expect(tester.getRect(palette), pal0);
    }

    await mouse.moveTo(rect0.center);
    await h.frames(2);
    await tester.tap(cell, kind: PointerDeviceKind.mouse);
    await h.frames(2);
    final e = h.c.townEdit!;
    expect(e.step, TownEditStep.placing);
    expect(e.placeDef, 'huerta_chica');
    expect(tester.getRect(cell), rect0);
    h.c.exitTownEdit();
    await h.frames(2);
  });
}
