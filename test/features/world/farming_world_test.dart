import 'package:echos_del_tiempo/game_engine/models/town_build.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fishing_map_harness.dart';

/// La huerta en el WorldScreen real (farming.md § 2): E ara, planta y
/// riega con el aviso de abajo; el mouse sobre la parcela muestra los
/// aportes y las chances; la fuente abre su panel.
void main() {
  testWidgets('huerta: arar, plantar, regar y cartel con lo plantado',
      (tester) async {
    final h = await FishingMapHarness.pump(tester);
    final c = h.c;
    const bf = TownLayout.baseFarm;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((bf.x + 1.5) * 16, (bf.y + 1.5) * 16);
    await h.frames(6);
    expect(c.view!.prompt, WorldPrompt.farm);
    expect(find.textContaining('[E o clic] Arar'), findsOneWidget);
    final (tx, ty) = c.farmTile!;

    Future<void> press(FarmOp op) async {
      expect(c.farmOp, op);
      expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
      await h.frames(8);
    }

    await press(FarmOp.till);
    expect(c.plotAt(tx, ty), isNotNull);
    expect(find.textContaining('[E o clic] Plantar'), findsOneWidget);
    await press(FarmOp.plant);
    expect(c.plotAt(tx, ty)!.planted, isTrue);
    expect(find.textContaining('[E o clic] Regar'), findsOneWidget);
    await press(FarmOp.water);
    expect(c.plotAt(tx, ty)!.watered, isTrue);

    // Mouse sobre la parcela: nada; sobre el cartel de la huerta, qué
    // hay plantado (town_editor.md § 6).
    final game = tester
        .widget<GameWidget<MapGame>>(find.byType(GameWidget<MapGame>))
        .game!;
    final box = tester.getRect(find.byType(GameWidget<MapGame>));
    Offset? screenOf((int, int) tile) {
      for (var y = 0.0; y < box.height; y += 4) {
        for (var x = 0.0; x < box.width; x += 4) {
          if (game.tileAtScreen(Offset(x, y)) == tile) {
            return box.topLeft + Offset(x + 2, y + 2);
          }
        }
      }
      return null;
    }

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(screenOf((tx, ty))!);
    await tester.pump();
    expect(find.byKey(const ValueKey('sign-tooltip')), findsNothing);
    final sign = TownPlan.signOf(c.town, c.town.build('h0')!);
    await mouse.moveTo(screenOf(sign)!);
    await tester.pump();
    expect(find.byKey(const ValueKey('sign-tooltip')), findsOneWidget);
    expect(find.textContaining('1 de 12 parcelas'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.byKey(const ValueKey('sign-tooltip')), findsNothing);
  });

  testWidgets(
      'fuente rúnica: EDITAR PUEBLO, cámara libre y opciones de un lago',
      (tester) async {
    final h = await FishingMapHarness.pump(tester);
    final c = h.c;
    // Debajo de la fuente (tiles 16–17 × 10–11).
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(17.0 * 16, 12.4 * 16);
    await h.frames(6);
    expect(c.view!.prompt, WorldPrompt.fountain);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    await h.frames(2);
    expect(find.byKey(const ValueKey('panel-fountain')), findsOneWidget);
    expect(find.byKey(const ValueKey('fountain-board')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fountain-edit-btn')));
    await h.frames(3);
    expect(c.editingTown, isTrue);
    expect(find.byKey(const ValueKey('town-edit-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('town-edit-done')), findsOneWidget);
    // El HUD normal se oculta en la edición (town_editor.md § 1).
    expect(find.byType(WorldHud), findsNothing);
    // Entra con la ventana CONSTRUIR abierta; Esc la cierra (§ 1.2).
    expect(find.byKey(const ValueKey('town-build-window')), findsOneWidget);
    expect(c.handleKey(LogicalKeyboardKey.escape), isTrue);
    await h.frames(2);
    expect(c.editingTown, isTrue);
    expect(find.byKey(const ValueKey('town-build-window')), findsNothing);
    final me = (c.local.x, c.local.y);

    final game = tester
        .widget<GameWidget<MapGame>>(find.byType(GameWidget<MapGame>))
        .game!;
    final box = tester.getRect(find.byType(GameWidget<MapGame>));
    Offset? screenOf((int, int) tile) {
      for (var y = 0.0; y < box.height; y += 4) {
        for (var x = 0.0; x < box.width; x += 4) {
          if (game.tileAtScreen(Offset(x, y)) == tile) {
            return box.topLeft + Offset(x + 2, y + 2);
          }
        }
      }
      return null;
    }

    // Arrastrar mueve la cámara, no al personaje.
    final cam0 = game.camX;
    await tester.dragFrom(box.center, const Offset(-120, 0));
    await h.frames(2);
    expect(game.camX, greaterThan(cam0));
    expect((c.local.x, c.local.y), me);
    await tester.dragFrom(box.center, const Offset(120, 0));
    await h.frames(2);

    // Clic en el lago base: sus opciones.
    final at = screenOf((6, 17));
    expect(at, isNotNull);
    await tester.tapAt(at!);
    await h.frames(2);
    expect(find.byKey(const ValueKey('town-edit-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('town-edit-stock')), findsOneWidget);
    expect(find.byKey(const ValueKey('town-edit-move')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('town-edit-delete')));
    await h.frames(2);
    expect(find.textContaining('peces soltados'), findsWidgets);
    // Esc vuelve un paso; LISTO sale.
    expect(c.handleKey(LogicalKeyboardKey.escape), isTrue);
    await tester.tap(find.byKey(const ValueKey('town-edit-done')));
    await h.frames(2);
    expect(c.editingTown, isFalse);
  });
  testWidgets('fuente rúnica: CONTRATAR PESCADOR elige el lago en el mapa',
      (tester) async {
    final h = await FishingMapHarness.pump(tester);
    final c = h.c;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(17.0 * 16, 12.4 * 16);
    await h.frames(6);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    await h.frames(2);
    expect(find.byKey(const ValueKey('fountain-exp-count')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('fountain-hire-fisher')));
    await h.frames(3);
    expect(c.editingTown, isTrue);
    expect(c.townEdit!.hire, BuildKind.lago);
    expect(find.text('¿En qué lago querés el pescador?'), findsOneWidget);
    final lake = c.town.builds.firstWhere((b) => b.kind == BuildKind.lago);
    expect(find.byKey(ValueKey('town-hire-${lake.id}')), findsOneWidget);
    // Sin nivel de Pesca: gris con el motivo, el clic no contrata.
    expect(c.hireWhy(lake), isNotNull);
    expect(find.text(c.hireWhy(lake)!), findsWidgets);
    expect(c.handleKey(LogicalKeyboardKey.escape), isTrue);
    await h.frames(2);
    expect(c.editingTown, isFalse);
    expect(c.town.build(lake.id)!.helper, lake.helper);
  });
}
