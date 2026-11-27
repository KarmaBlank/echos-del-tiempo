import 'package:echos_del_tiempo/features/world/presentation/panels/town_build_palette.dart';
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
  final place = find.byKey(const ValueKey('town-build-place'));

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
    // Un clic solo elige: la ventana sigue abierta.
    expect(window, findsOneWidget);
    expect(h.c.townEdit!.step, isNot(TownEditStep.placing));
    await tester.tap(place);
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
    expect(window, findsOneWidget);
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
      // El detalle muestra la miniatura grande de la pieza bajo el mouse
      // (afuera primero: la ficha de la casilla anterior no tapa).
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 1));
      await h.frames(2);
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
      expect(tester.getSize(big).width, TownBuildPalette.detailPreview);
      expect(tester.takeException(), isNull, reason: id);
    }
    h.c.exitTownEdit();
    await h.frames(2);
  });

  final name = find.byKey(const ValueKey('town-build-detail-name'));
  String shownName(WidgetTester t) => t.widget<Text>(name).data!;

  testWidgets('CONSTRUIR: el detalle elegido no sigue al hover',
      (tester) async {
    final h = await open(tester);
    await tester.tap(cell);
    await h.frames(2);
    final chosen = shownName(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    final other = find.byKey(const ValueKey('town-edit-build-$kFaroId'));
    await mouse.moveTo(tester.getRect(other).center);
    await h.frames(2);
    expect(shownName(tester), chosen);
    // Ir a la barra del detalle tampoco lo cambia.
    await mouse.moveTo(tester
            .getRect(find.byKey(const ValueKey('town-build-pane')))
            .centerRight -
        const Offset(4, 0));
    await h.frames(2);
    expect(shownName(tester), chosen);
    expect(window, findsOneWidget);
    h.c.exitTownEdit();
    await h.frames(2);
  });

  testWidgets('CONSTRUIR: doble clic coloca', (tester) async {
    final h = await open(tester);
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(cell);
    await h.frames(2);
    expect(h.c.townEdit!.step, TownEditStep.placing);
    expect(h.c.townEdit!.placeDef, 'huerta_chica');
    expect(window, findsNothing);
    h.c.exitTownEdit();
    await h.frames(2);
  });

  testWidgets('CONSTRUIR: flechas eligen y Enter coloca', (tester) async {
    final h = await open(tester);
    final ids = [for (final d in kConstructions) d.id, kFaroId];
    await tester.tap(find.byKey(ValueKey('town-edit-build-${ids[0]}')));
    await h.frames(2);
    final first = shownName(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await h.frames(2);
    expect(shownName(tester), isNot(first));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await h.frames(2);
    expect(shownName(tester), first);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await h.frames(2);
    expect(h.c.townEdit!.placeDef, ids[0]);
    expect(window, findsNothing);
    h.c.exitTownEdit();
    await h.frames(2);
  });

  testWidgets('CONSTRUIR: sin oro, COLOCAR queda gris con el motivo',
      (tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester,
        profile: PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 0));
    expect(h.c.enterTownEdit(), isTrue);
    await h.frames(3);
    await tester.tap(find.byKey(const ValueKey('town-edit-build-$kFaroId')));
    await h.frames(2);
    expect(find.byKey(const ValueKey('town-build-why')), findsOneWidget);
    await tester.tap(place, warnIfMissed: false);
    await h.frames(2);
    expect(window, findsOneWidget);
    expect(h.c.townEdit!.step, isNot(TownEditStep.placing));
    h.c.exitTownEdit();
    await h.frames(2);
  });

  for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
    testWidgets('CONSTRUIR: el detalle entra sin scroll a $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await FishingMapHarness.pump(tester,
          profile: PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 0));
      expect(h.c.enterTownEdit(), isTrue);
      await h.frames(3);
      for (final id in [for (final d in kConstructions) d.id, kFaroId]) {
        await tester.tap(find.byKey(ValueKey('town-edit-build-$id')));
        await h.frames(2);
        final body = find.descendant(
            of: find.byKey(const ValueKey('town-build-pane')),
            matching: find.byType(Scrollable));
        final pos = tester.state<ScrollableState>(body.first).position;
        expect(pos.maxScrollExtent, 0, reason: id);
        expect(tester.takeException(), isNull, reason: id);
      }
      h.c.exitTownEdit();
      await h.frames(2);
    });
  }
}
