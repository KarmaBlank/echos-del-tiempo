import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_controller.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/demo_battle.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('el guerrero ataca al Limo desde el menú', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final engine = BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99, // nunca crítico
    );
    final setup = demoBattleSetup();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        battleEngineProvider.overrideWithValue(engine),
        battlePaceProvider.overrideWithValue(Duration.zero),
      ],
      child: MaterialApp(theme: RetroTheme.build(), home: BattleScreen(setup: setup)),
    ));
    await tester.pumpAndSettle();

    // El guerrero tocó al enemigo: arranca primero.
    expect(find.text('TURNO: GUERRERO'), findsOneWidget);
    // 4 jugadores → vida ×2.35: Limo 30 × 2.35 = 70.5 → 71
    expect(find.textContaining('71/71'), findsOneWidget);

    await tester.tap(find.text('  ATACAR'));
    await tester.pumpAndSettle();
    expect(find.text('Elegí un enemigo'), findsOneWidget);

    await tester.tap(find.text('  Limo'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(BattleScreen)));
    final slime = container.read(battleControllerProvider(setup)).battle.enemies[0];
    expect(slime.hp, 71 - 15);
  });
}
