import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Las 4 clases en nivel 1 con su arma inicial.
BattlePartyMember member(String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: classId,
    name: cls.name,
    potions: 2,
    ethers: 1,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

void main() {
  late BattleEngine engine;
  late BattleState state;

  setUp(() {
    engine = BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99, // nunca crítico
    );
    final start = engine.start(
      party: [
        for (final c in ['guerrero', 'maga', 'tirador', 'paladin']) member(c),
      ],
      enemyTypes: const ['slime', 'bat', 'golem'],
      triggeredBy: 'guerrero',
    );
    state = engine.nextTurn(start.state).state;
  });

  Future<void> pump(WidgetTester tester,
      {required bool canAct, required bool Function(BattleCommand) onCommand}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(battle: state, canAct: canAct, onCommand: onCommand),
      ),
    ));
  }

  testWidgets('el guerrero ataca al Limo desde el menú', (tester) async {
    // El guerrero tocó al enemigo: arranca primero.
    expect(state.currentId, 'guerrero');
    BattleCommand? sent;
    await pump(tester, canAct: true, onCommand: (c) {
      sent = c;
      return true;
    });

    expect(find.text('¡TU TURNO! GUERRERO'), findsOneWidget);
    // 4 jugadores → vida ×2.35: Limo 30 × 2.35 = 70.5 → 71
    expect(find.textContaining('71/71'), findsOneWidget);

    await tester.tap(find.text('  1. Atacar'));
    await tester.pump();
    expect(sent, isA<AttackCommand>());
    // Sin elegir, el objetivo es el primer enemigo vivo.
    expect((sent! as AttackCommand).targetId, 'e0');

    final after = engine.command(state, 'guerrero', sent!)!.state;
    expect(after.enemies[0].hp, 71 - 15);
  });

  testWidgets('Q cambia de objetivo y 1 ataca al elegido', (tester) async {
    BattleCommand? sent;
    await pump(tester, canAct: true, onCommand: (c) {
      sent = c;
      return true;
    });
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    expect(menu.target, 'e0');
    expect(menu.handleKey(LogicalKeyboardKey.keyQ), isTrue);
    expect(menu.target, 'e1');
    expect(menu.handleKey(LogicalKeyboardKey.digit1), isTrue);
    expect((sent! as AttackCommand).targetId, 'e1');
  });

  testWidgets('poción: submenú para elegir a quién', (tester) async {
    BattleCommand? sent;
    await pump(tester, canAct: true, onCommand: (c) {
      sent = c;
      return true;
    });
    await tester.tap(find.textContaining('Poción de vida x2'));
    await tester.pump();
    expect(find.text('¿A QUIEN?'), findsOneWidget);
    await tester.tap(find.textContaining('. Maga'));
    await tester.pump();
    expect(sent, isA<ItemCommand>());
    expect((sent! as ItemCommand).targetPlayerId, 'maga');
  });

  testWidgets('sin turno propio no hay menú', (tester) async {
    await pump(tester, canAct: false, onCommand: (_) => fail('no debía mandar'));
    expect(find.text('TURNO DE GUERRERO'), findsOneWidget);
    expect(find.text('  1. Atacar'), findsNothing);
  });
}
