import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fishing_map_harness.dart';

void main() {
  testWidgets('franjas de la edición: AMPLIAR y costo con lo que tenés',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester,
        profile: PlayerProfile(
            name: 'Ana',
            classId: 'guerrero',
            credits: 60000,
            materials: const {CraftMaterial.esquirla: 1}));
    expect(h.c.enterTownEdit(), isTrue);
    h.game.editZoom = 2;
    h.game.camX = -9 * 16;
    h.game.camY = -9 * 16;
    await h.frames(3);
    for (final s in ['n', 's', 'o']) {
      expect(find.byKey(ValueKey('town-strip-$s')), findsOneWidget);
    }
    // La paleta ocupa la derecha (town_editor.md § 1.2): para ver la
    // franja este se corre la cámara.
    final camX = h.game.camX;
    h.game.camX = camX + 24 * 16;
    await h.frames(3);
    expect(find.byKey(const ValueKey('town-strip-e')), findsOneWidget);
    h.game.camX = camX;
    await h.frames(3);
    // Oro alcanza (verde), Esquirlas no (rojo).
    Color colorOf(String k) =>
        tester.widget<Text>(find.byKey(ValueKey(k))).style!.color!;
    expect(find.textContaining('(tenés 60000)'), findsWidgets);
    expect(colorOf('town-strip-n-Oro'), isNot(colorOf('town-strip-n-Esquirlas')));
    // Cada tarjeta entra en la pantalla.
    for (final s in ['n', 's', 'o']) {
      final r = tester.getRect(find.byKey(ValueKey('town-strip-$s')));
      expect(const Rect.fromLTWH(0, 0, 1280, 720).contains(r.topLeft), isTrue);
      expect(r.right <= 1280 && r.bottom <= 720, isTrue);
    }
    h.c.exitTownEdit();
    await h.frames(2);
    expect(find.byKey(const ValueKey('town-strip-n')), findsNothing);
  });
}
