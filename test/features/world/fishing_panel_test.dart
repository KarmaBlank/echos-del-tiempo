import 'package:echos_del_tiempo/features/world/presentation/panels/fishing_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/trader_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_minigame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// Paneles PESCA y COMERCIANTE (fishing.md § 4 y § 5).
void main() {
  testWidgets('PESCA: mantener carga el lance y soltar lo tira', (tester) async {
    final g = FishingMinigame(() => 0.5);
    await pumpPanel(tester,
        profile: newProfile('Ana', 'guerrero'),
        build: (v, c) => FishingPanel(view: v, controller: c, game: g));
    expect(find.text('PESCA NIVEL 1'), findsOneWidget);
    final scene = find.byKey(const ValueKey('fish-scene'));
    final gesture = await tester.startGesture(tester.getCenter(scene));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump(const Duration(milliseconds: 40));
    expect(g.phase, FishPhase.charging);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 40));
    expect(g.phase, FishPhase.flying);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('COMERCIANTE: vender todo y cañas', (tester) async {
    final p = newProfile('Ana', 'guerrero').copyWith(
        credits: 450,
        life: LifeSkills(bag: const {'carpa_musgo': 2, 'pez_reloj': 1}));
    final c = await pumpPanel(tester,
        profile: p, build: (v, c) => TraderPanel(view: v, controller: c));
    expect(find.byKey(const ValueKey('trade-row-carpa_musgo')), findsOneWidget);
    expect(find.byKey(const ValueKey('trade-swap-pez_reloj')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trade-sell-all')));
    await tester.pump();
    expect(c.view!.me!.profile.credits, 450 + 36);
    expect(c.view!.me!.profile.life.count('pez_reloj'), 1);
    await tester.tap(find.byKey(const ValueKey('trade-rod-buy-cana_roble')));
    await tester.pump();
    expect(c.view!.me!.profile.life.rods, contains('cana_roble'));
  });
}
