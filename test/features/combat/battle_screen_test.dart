import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
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
import 'package:echos_del_tiempo/game_engine/models/status.dart';
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
      {required bool canAct,
      required bool Function(BattleCommand) onCommand,
      String? localId}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(
            battle: state,
            canAct: canAct,
            localId: localId,
            onCommand: onCommand),
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

    // Cabecera `<b>` del `#menu` y mis datos con el turno.
    expect(find.textContaining('¡Tu turno! (Guerrero)'), findsOneWidget);
    expect(find.textContaining('TU TURNO'), findsOneWidget);
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

  testWidgets('sin turno propio no hay menú: dice de quién es el turno',
      (tester) async {
    await pump(tester,
        canAct: false,
        localId: 'maga',
        onCommand: (_) => fail('no debía mandar'));
    // Como el prototipo: sin menú. El panel del medio dice de quién es el
    // turno y cuándo me toca; la fila del guerrero lo marca.
    expect(find.byKey(const ValueKey('battle-menu')), findsNothing);
    expect(find.textContaining('1. Atacar'), findsNothing);
    Finder waiting(String text) => find.descendant(
        of: find.byKey(const ValueKey('battle-waiting')),
        matching: find.text(text));
    expect(waiting('Turno de Guerrero'), findsOneWidget);
    expect(waiting('Tu turno en 3'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('member-guerrero')),
            matching: find.textContaining('SU TURNO')),
        findsOneWidget);
  });

  testWidgets('solo veo mis datos; el resto del grupo en filas compactas',
      (tester) async {
    Combatant m(String id) => state.party.firstWhere((p) => p.id == id);
    m('tirador')
      ..statuses = {StatusKind.freeze: 2}
      ..defending = true;
    m('paladin')
      ..protecting = true
      ..taunt = 2
      ..bonusDefense = 4
      ..statuses = {StatusKind.regen: 2};
    m('guerrero').hp = 0;
    await pump(tester, canAct: false, localId: 'maga', onCommand: (_) => true);

    // Un solo panel detallado: el mío.
    expect(find.byKey(const ValueKey('my-panel-maga')), findsOneWidget);
    for (final id in ['guerrero', 'tirador', 'paladin']) {
      expect(find.byKey(ValueKey('my-panel-$id')), findsNothing);
      expect(find.byKey(ValueKey('member-$id')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('member-maga')), findsNothing);
    expect(find.textContaining('ATQ '), findsOneWidget);

    Finder inRow(String id, String text) => find.descendant(
        of: find.byKey(ValueKey('member-$id')), matching: find.text(text));
    expect(inRow('tirador', 'C2'), findsOneWidget);
    expect(inRow('tirador', 'Defiende'), findsOneWidget);
    expect(inRow('tirador', '▼VEL'), findsOneWidget);
    expect(inRow('paladin', 'R2'), findsOneWidget);
    expect(inRow('paladin', 'Protege'), findsOneWidget);
    expect(inRow('paladin', 'Provoca 2'), findsOneWidget);
    expect(inRow('paladin', '▲DEF+4'), findsOneWidget);
    expect(inRow('guerrero', 'K.O.'), findsOneWidget);
    // Cada chip explica el efecto en su `#tip`.
    expect(
        find.byWidgetPredicate((w) =>
            w is RetroTooltip &&
            w.message.contains('Congelación') &&
            w.message.contains('pierde su turno')),
        findsOneWidget);
  });

  testWidgets('en solitario la lista del grupo dice Solo', (tester) async {
    state = engine
        .nextTurn(engine
            .start(
              party: [member('maga')],
              enemyTypes: const ['slime'],
              triggeredBy: 'maga',
            )
            .state)
        .state;
    await pump(tester, canAct: true, localId: 'maga', onCommand: (_) => true);
    expect(find.text('Solo'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-panel-maga')), findsOneWidget);
    expect(find.textContaining('1. Atacar'), findsOneWidget);
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
