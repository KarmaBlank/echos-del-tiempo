import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fishing_map_harness.dart';

/// La huerta en el WorldScreen real (farming.md § 2): E ara, planta y
/// riega con el aviso de abajo; el mouse sobre la parcela muestra los
/// aportes y las chances; la fuente abre su panel.
void main() {
  testWidgets('huerta: arar, plantar, regar y tooltip de la parcela',
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

    // Sin tooltip sobre la parcela (v0.23.3).
    expect(find.byKey(const ValueKey('farm-tooltip')), findsNothing);
  });

  testWidgets('fuente rúnica: E abre su panel con ampliar y el tablero',
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
    expect(find.byKey(const ValueKey('fountain-expand-btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('fountain-board')), findsOneWidget);
  });
}
