import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fishing_map_harness.dart';

void main() {
  const screen = Size(1280, 720);
  final window = find.byKey(const ValueKey('town-build-window'));
  final toggle = find.byKey(const ValueKey('town-build-toggle'));
  final cell = find.byKey(const ValueKey('town-edit-build-huerta_chica'));

  Future<FishingMapHarness> open(WidgetTester tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester,
        profile:
            PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 60000));
    expect(h.c.enterTownEdit(), isTrue);
    await h.frames(3);
    return h;
  }

  testWidgets('CONSTRUIR: ventana grande centrada al entrar', (tester) async {
    final h = await open(tester);
    expect(window, findsOneWidget);
    expect(toggle, findsNothing);
    final r = tester.getRect(window);
    expect(r.width, greaterThan(screen.width * 0.6));
    expect(r.height, greaterThan(screen.height * 0.5));
    // Centrada a lo ancho (el alto descuenta la barra de arriba).
    expect((r.center.dx - screen.width / 2).abs(), lessThan(2));
    expect(cell, findsOneWidget);
    h.c.exitTownEdit();
    await h.frames(2);
  });

  testWidgets('CONSTRUIR: elegir una pieza la cierra; el botón la reabre',
      (tester) async {
    final h = await open(tester);
    await tester.tap(cell);
    await h.frames(2);
    final e = h.c.townEdit!;
    expect(e.step, TownEditStep.placing);
    expect(e.placeDef, 'huerta_chica');
    expect(window, findsNothing);
    expect(toggle, findsOneWidget);
    // El botón queda en el borde derecho.
    expect(tester.getRect(toggle).right, greaterThan(screen.width - 40));

    await tester.tap(toggle);
    await h.frames(2);
    expect(window, findsOneWidget);
    expect(h.c.townEdit!.step, TownEditStep.placing);

    // Esc cierra primero la ventana, sin salir de la edición.
    expect(h.c.handleKey(LogicalKeyboardKey.escape), isTrue);
    await h.frames(2);
    expect(window, findsNothing);
    expect(h.c.editingTown, isTrue);
    expect(toggle, findsOneWidget);
    // El botón CERRAR también.
    await tester.tap(toggle);
    await h.frames(2);
    await tester.tap(find.byKey(const ValueKey('town-build-close')));
    await h.frames(2);
    expect(window, findsNothing);
    h.c.exitTownEdit();
    await h.frames(2);
  });

  testWidgets('CONSTRUIR: el hover repetido no mueve nada', (tester) async {
    final h = await open(tester);
    final rect0 = tester.getRect(cell);
    final win0 = tester.getRect(window);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    for (var i = 0; i < 5; i++) {
      await mouse.moveTo(rect0.center);
      await h.frames(2);
      expect(tester.getRect(cell), rect0);
      expect(tester.getRect(window), win0);
      await mouse.moveTo(rect0.center + const Offset(6, 6));
      await h.frames(2);
      expect(tester.getRect(cell), rect0);
      await mouse.moveTo(win0.center);
      await h.frames(2);
      expect(tester.getRect(cell), rect0);
      expect(tester.getRect(window), win0);
    }
    await mouse.moveTo(rect0.center);
    await h.frames(2);
    await tester.tap(cell, kind: PointerDeviceKind.mouse);
    await h.frames(2);
    expect(h.c.townEdit!.placeDef, 'huerta_chica');
    h.c.exitTownEdit();
    await h.frames(2);
  });

  testWidgets('CONSTRUIR: cada pieza muestra su miniatura sin errores',
      (tester) async {
    final h = await open(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    for (final id in [for (final d in kConstructions) d.id, kFaroId]) {
      final c = find.byKey(ValueKey('town-edit-build-$id'));
      expect(c, findsOneWidget, reason: id);
      expect(
          find.descendant(
              of: c, matching: find.byKey(ValueKey('town-piece-preview-$id'))),
          findsOneWidget,
          reason: id);
      // El detalle muestra la miniatura grande de la pieza bajo el mouse.
      await mouse.moveTo(tester.getRect(c).center);
      await h.frames(2);
      final big = find.byKey(const ValueKey('town-build-detail-preview'));
      expect(big, findsOneWidget, reason: id);
      expect(
          find.descendant(
              of: big,
              matching: find.byKey(ValueKey('town-piece-preview-$id'))),
          findsOneWidget,
          reason: id);
      expect(tester.getSize(big).width, 96);
      expect(tester.takeException(), isNull, reason: id);
    }
    h.c.exitTownEdit();
    await h.frames(2);
  });
}
