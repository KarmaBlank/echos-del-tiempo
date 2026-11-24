import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The battle menu keeps its state when someone else's action resolves
/// (turn_modes.md § 3.1, combat.md § "Menú de batalla").
void main() {
  late BattleState state;

  setUp(() {
    final engine = BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99,
    );
    final cls = kClasses['guerrero']!;
    final start = engine.start(
      party: [
        BattlePartyMember(
          id: 'g',
          name: 'Gua',
          potions: 2,
          ethers: 1,
          build: PlayerBuild(
            classId: 'guerrero',
            level: 10,
            attributes: PlayerAttributes.base(cls.baseAttributes),
            equippedWeapon: kWeapons.values.first,
          ),
        ),
      ],
      enemyTypes: const ['slime', 'slime'],
      triggeredBy: 'g',
    );
    state = engine.nextTurn(start.state).state;
  });

  Widget app(BattleState b, bool canAct, int seq) => MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(
          body: BattleView(
              battle: b,
              canAct: canAct,
              eventSeq: seq,
              onCommand: (_) => true),
        ),
      );

  testWidgets('another update (blinking canAct, new log) keeps the menu',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    expect(state.current?.isPlayer, isTrue);
    await tester.pumpWidget(app(state, true, 0));
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    menu.selectCategory(BattleCategory.items);
    await tester.pump();
    // Another player's action resolves: new state, canAct off for a moment.
    final other = state.copy()
      ..logLine = const LogLine('ui.battle_log.end_turn', {'a': 'X'});
    await tester.pumpWidget(app(other, false, 1));
    await tester.pumpWidget(app(other.copy(), true, 2));
    expect(menu.category, BattleCategory.items);
  });
}
