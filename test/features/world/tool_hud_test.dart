import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/services.dart';
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
  testWidgets('cerca de la huerta: barra Azada | Semilla | Regadera y aviso',
      (tester) async {
    final h = await FishingMapHarness.pump(tester, profile: _profile());
    final c = h.c;
    const bf = TownLayout.baseFarm;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((bf.x + 1.5) * 16, (bf.y + 1.5) * 16);
    await h.frames(6);
    expect(c.activeTool, ActiveTool.hoe);
    expect(find.byKey(const ValueKey('hud-farm-bar')), findsOneWidget);
    for (final k in ['hud-tool-hoe', 'hud-tool-seed', 'hud-tool-can']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('hud-seed-carousel')), findsOneWidget);
    // Sugerencia automática: tierra sin arar → azada.
    expect(c.farmHand, FarmHand.hoe);
    expect(c.farmHandManual, isFalse);
    expect(find.textContaining('[E o clic] Arar'), findsOneWidget);
    expect(c.farmTarget!.ok, isTrue);
    // Barra abajo al centro (v0.24.4); el aviso, una línea arriba de ella.
    expect(find.byKey(const ValueKey('hud-prompt')), findsNothing);
    final prompt =
        tester.getRect(find.byKey(const ValueKey('hud-tool-prompt')));
    final bar = tester.getRect(find.byKey(const ValueKey('hud-farm-bar')));
    expect(prompt.bottom, lessThanOrEqualTo(bar.top));
    expect((prompt.center.dx - bar.center.dx).abs(), lessThan(1));
    final seed = c.session!.players[c.localId]!.profile.life.farm.activeSeed;
    c.cycleSeed();
    await h.frames(2);
    expect(c.session!.players[c.localId]!.profile.life.farm.activeSeed,
        isNot(seed));
  });

  testWidgets('herramienta activa: solo la válida hace la labor',
      (tester) async {
    final h = await FishingMapHarness.pump(tester, profile: _profile());
    final c = h.c;
    const bf = TownLayout.baseFarm;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((bf.x + 1.5) * 16, (bf.y + 1.5) * 16);
    await h.frames(6);
    final (tx, ty) = c.farmTile!;

    Future<void> pick(String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await h.frames(2);
    }

    Future<void> press() async {
      expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
      await h.frames(8);
    }

    // Regadera sobre tierra sin arar: no hace nada y dice por qué.
    await pick('hud-tool-can');
    expect(c.farmHand, FarmHand.can);
    expect(c.farmHandManual, isTrue);
    expect(find.text('Primero arala'), findsOneWidget);
    expect(c.farmTarget!.ok, isFalse);
    await press();
    expect(c.plotAt(tx, ty), isNull);
    // Semilla: tampoco.
    await pick('hud-tool-seed');
    expect(find.text('Primero arala'), findsOneWidget);
    await press();
    expect(c.plotAt(tx, ty), isNull);
    // Azada: ara. La elección manual se queda aunque la parcela cambie.
    await pick('hud-tool-hoe');
    await press();
    expect(c.plotAt(tx, ty), isNotNull);
    expect(c.farmHand, FarmHand.hoe);
    expect(find.text('Ya está arada'), findsOneWidget);
    // Regadera sobre arada vacía: primero plantá.
    c.cycleFarmHand(); // Tab: azada → semilla
    expect(c.farmHand, FarmHand.seed);
    await h.frames(2);
    expect(find.textContaining('[E o clic] Plantar'), findsOneWidget);
    await press();
    expect(c.plotAt(tx, ty)!.planted, isTrue);
    await pick('hud-tool-can');
    expect(find.textContaining('[E o clic] Regar'), findsOneWidget);
    await press();
    expect(c.plotAt(tx, ty)!.watered, isTrue);
    // Tab con el teclado también cambia de herramienta.
    expect(c.handleKey(LogicalKeyboardKey.tab), isTrue);
    expect(c.farmHand, FarmHand.hoe);
    // Lejos de la huerta se olvida la elección manual.
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(17.0 * 16, 12.4 * 16); // junto a la fuente
    await h.frames(4);
    expect(c.nearFarm, isFalse);
    expect(c.farmHandManual, isFalse);
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
