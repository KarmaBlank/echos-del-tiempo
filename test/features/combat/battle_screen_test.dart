import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
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

    // Cabecera `<b>` del `#menu` y la caja del grupo con su turno.
    expect(find.textContaining('¡Tu turno! (Guerrero)'), findsOneWidget);
    expect(find.textContaining('SU TURNO'), findsOneWidget);
    // 4 jugadores → vida ×2.35: Limo 30 × 2.35 = 70.5 → 71
    expect(state.enemies[0].maxHp, 71);

    await tester.tap(find.textContaining('1. Atacar'));
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
    expect(find.textContaining('¿A quién le das la Poción de vida'),
        findsOneWidget);
    await tester.tap(find.textContaining('. Maga'));
    await tester.pump();
    expect(sent, isA<ItemCommand>());
    expect((sent! as ItemCommand).targetPlayerId, 'maga');
  });

  testWidgets('sin turno propio no hay menú', (tester) async {
    await pump(tester, canAct: false, onCommand: (_) => fail('no debía mandar'));
    // Como el prototipo: sin menú; la caja del guerrero dice que es su
    // turno.
    expect(find.textContaining('SU TURNO'), findsOneWidget);
    expect(find.textContaining('1. Atacar'), findsNothing);
  });

  testWidgets('un paso nuevo (eventSeq) crea los efectos una sola vez',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget view(BattleState b, List<BattleEvent> ev, int seq) => MaterialApp(
          theme: RetroTheme.build(),
          home: Scaffold(
            body: BattleView(
                battle: b,
                events: ev,
                eventSeq: seq,
                battleId: 1,
                onCommand: (_) => true),
          ),
        );
    await tester.pumpWidget(view(state, const [], 0));
    final step = engine.command(state, 'guerrero', const AttackCommand())!;
    await tester.pumpWidget(view(step.state, step.events, 1));
    await tester.pump(const Duration(milliseconds: 16));
    final scene = tester.state<BattleViewState>(find.byType(BattleView)).scene;
    final kinds = scene.fx.map((f) => f.fx.kind).toList();
    expect(kinds, containsAll([FxKind.act, FxKind.num, FxKind.slash]));
    final n = scene.fx.length;
    // Reconstruir con el mismo eventSeq no repite.
    await tester.pumpWidget(view(step.state, step.events, 1));
    expect(scene.fx.length, n);
    // Los efectos caducan solos (no frenan nada).
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 16));
    expect(scene.fx, isEmpty);
  });
}
