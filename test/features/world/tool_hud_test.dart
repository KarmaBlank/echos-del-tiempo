import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fishing_map_harness.dart';

/// HUD de herramienta sobre las pociones (farming.md § 4, v0.23.2).
PlayerProfile _profile() => PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      unlockedZone: 1,
      life: LifeSkills(
        farm: FarmSkills(
          seeds: const {'nabo_claro': 6, 'trigo_dorado': 4},
          hoes: const ['azada_rama', 'azada_hierro'],
          cans: const ['regadera_lata'],
        ),
      ),
    );

void main() {
  testWidgets('cerca de la huerta: azada, carrusel y aviso sobre pociones',
      (tester) async {
    final h = await FishingMapHarness.pump(tester, profile: _profile());
    final c = h.c;
    const bf = TownLayout.baseFarm;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((bf.x + 1.5) * 16, (bf.y + 1.5) * 16);
    await h.frames(6);
    expect(c.activeTool, ActiveTool.hoe);
    expect(find.byKey(const ValueKey('hud-tool-hoe')), findsOneWidget);
    expect(find.byKey(const ValueKey('hud-seed-carousel')), findsOneWidget);
    final seed = c.session!.players[c.localId]!.profile.life.farm.activeSeed;
    expect(seed, isNotNull);
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('hud-seed-name'))).data,
        matches(RegExp(r'^Semilla de .+ ×\d+$')));
    expect(find.textContaining('[E o clic] Arar'), findsOneWidget);
    // El aviso va arriba de las pociones, no en el cartel de abajo.
    expect(find.byKey(const ValueKey('hud-prompt')), findsNothing);
    final prompt =
        tester.getRect(find.byKey(const ValueKey('hud-tool-prompt')));
    final potions = tester.getRect(find.byKey(const ValueKey('hud-potions')));
    expect(prompt.bottom, lessThanOrEqualTo(potions.top));
    // Q cambia de semilla.
    c.cycleSeed();
    await h.frames(2);
    expect(c.session!.players[c.localId]!.profile.life.farm.activeSeed,
        isNot(seed));
  });

  testWidgets('en una misión no hay HUD de herramienta', (tester) async {
    final h = await FishingMapHarness.pump(tester, profile: _profile());
    final c = h.c;
    c.session!.mode = SessionMode.field;
    // Re-emite la vista sin correr el tick del campo.
    c.openPanel(WorldPanel.character);
    c.closePanel();
    await tester.pump();
    expect(c.activeTool, isNull);
    expect(find.byKey(const ValueKey('hud-tool')), findsNothing);
  });

  testWidgets('PESCA Y CULTIVO: EQUIPAR otra azada', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester, profile: _profile());
    final c = h.c;
    c.openPanel(WorldPanel.character);
    await h.frames(2);
    await tester.tap(find.text('PESCA Y CULTIVO'));
    await h.frames(2);
    expect(find.byKey(const ValueKey('life-tool-azada_rama')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('life-tool-eq-azada_hierro')));
    await h.frames(2);
    expect(
        c.session!.players[c.localId]!.profile.life.farm.hoe, 'azada_hierro');
    expect(
        find.byKey(const ValueKey('life-tool-eq-azada_hierro')), findsNothing);
  });
}
