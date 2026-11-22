import 'package:echos_del_tiempo/game_engine/models/fish_line.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_minigame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fishing_map_harness.dart';

/// Pesca en el mapa (fishing.md § 4, v0.22.2): sin ventana; la barra va
/// al lado del personaje y el mundo sigue a la vista.
void main() {
  testWidgets('lance, picada y barra en el mapa, sin panel', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester);
    expect(h.c.canFish, isTrue);
    await h.cast();
    expect(h.f.phase, FishPhase.waiting);
    expect(h.c.session!.players[h.c.localId]!.fishLine?.stage,
        FishLineStage.line);
    await h.forceReel(FishingMapHarness.sample);
    expect(h.f.phase, FishPhase.reel);
    expect(h.c.view!.panel, isNull);
    expect(find.byKey(const ValueKey('panel-fishing')), findsNothing);
    expect(find.byKey(const ValueKey('fish-pointer')), findsOneWidget);
    expect(h.game.fishing.barRect, isNotNull);
    // Caminar guarda la caña.
    h.c.updateLocal(0.05, 1, 0);
    expect(h.c.isFishing, isFalse);
    await h.frames(2);
    expect(h.game.fishing.barRect, isNull);
  });
}
