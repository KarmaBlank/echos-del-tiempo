import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
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
import 'package:flutter/gestures.dart';
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
      String? localId,
      Set<String> companions = const {}}) async {
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
            companions: companions,
            onCommand: onCommand),
      ),
    ));
  }

  Finder act(String id) => find.byKey(ValueKey('battle-act-$id'));

  testWidgets('el guerrero ataca al Limo desde el menú', (tester) async {
    // El guerrero tocó al enemigo: arranca primero.
    expect(state.currentId, 'guerrero');
    BattleCommand? sent;
    await pump(tester, canAct: true, onCommand: (c) {
      sent = c;
      return true;
    });

    // Ventana de comandos: quién actúa, categorías y el objetivo.
    expect(find.textContaining('¡Tu turno! Guerrero'), findsOneWidget);
    expect(find.byKey(const ValueKey('battle-cat-attack')), findsOneWidget);
    expect(find.byKey(const ValueKey('battle-cat-skills')), findsOneWidget);
    expect(find.byKey(const ValueKey('battle-cat-items')), findsOneWidget);
    expect(find.byKey(const ValueKey('battle-cat-defend')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('battle-target')),
            matching: find.textContaining('Limo', findRichText: true)),
        findsOneWidget);
    // 4 jugadores → vida ×1.8 (combo_balance.md § 3.3): Limo 30 × 1.8 = 54
    expect(state.enemies[0].maxHp, 54);

    await tester.tap(act('attack'));
    await tester.pump();
    expect(sent, isA<AttackCommand>());
    // Sin elegir, el objetivo es el primer enemigo vivo.
    expect((sent! as AttackCommand).targetId, 'e0');

    final after = engine.command(state, 'guerrero', sent!)!.state;
    // ATQ 15 × 0.76 (mitigación de grupo, 4 jugadores) = 11.4 → 11.
    expect(after.enemies[0].hp, 54 - 11);
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

  testWidgets('teclado: ←/→ categorías, ↑/↓ acción, Enter confirma',
      (tester) async {
    BattleCommand? sent;
    await pump(tester, canAct: true, onCommand: (c) {
      sent = c;
      return true;
    });
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    expect(menu.category, BattleCategory.attack);
    menu.handleKey(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(menu.category, BattleCategory.skills);
    // Las técnicas del arma, una fila cada una con su costo.
    final cur = state.current!;
    for (final id in cur.skillIds) {
      expect(act('skill-$id'), findsOneWidget);
    }
    menu.handleKey(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(menu.selectedAction, 1);
    // La descripción es la de la acción elegida.
    // En el menú las Instante van primero.
    final shown = [
      ...cur.skillIds.where((id) => kSkills[id]?.instant ?? false),
      ...cur.skillIds.where((id) => !(kSkills[id]?.instant ?? false)),
    ];
    expect(find.byKey(ValueKey('battle-desc-skill-${shown[1]}')),
        findsOneWidget);
    menu.handleKey(LogicalKeyboardKey.enter);
    expect((sent! as SkillCommand).skillId, shown[1]);
  });

  testWidgets('PASAR: última categoría, descripción y clic pasa el turno',
      (tester) async {
    BattleCommand? sent;
    await pump(tester, canAct: true, onCommand: (c) {
      sent = c;
      return true;
    });
    final cat = find.byKey(const ValueKey('battle-cat-pass'));
    expect(cat, findsOneWidget);
    // Después de DEFENDER.
    expect(tester.getTopLeft(cat).dy,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey('battle-cat-defend'))).dy));
    await tester.tap(cat);
    await tester.pump();
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    expect(menu.category, BattleCategory.pass);
    expect(find.byKey(const ValueKey('battle-desc-pass')), findsOneWidget);
    expect(
        find.textContaining('Terminás el turno sin actuar', findRichText: true),
        findsOneWidget);
    await tester.tap(act('pass'));
    await tester.pump();
    expect(sent, isA<PassCommand>());
  });

  // Pulso, precondiciones e Instante (combo_balance.md § 5.2).
  testWidgets('Quebrar sin Fisurado: desactivada con "Necesita: …"',
      (tester) async {
    BattleCommand? sent;
    await pump(tester, canAct: true, onCommand: (c) {
      sent = c;
      return true;
    });
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    menu.selectCategory(BattleCategory.skills);
    await tester.pump();
    // Seleccionarla muestra el motivo y no manda nada.
    final ids = state.current!.skillIds;
    for (var i = 0; i < ids.indexOf('quebrar'); i++) {
      menu.handleKey(LogicalKeyboardKey.arrowDown);
    }
    await tester.pump();
    menu.handleKey(LogicalKeyboardKey.enter);
    expect(sent, isNull);
    expect(
        find.textContaining('Necesita: objetivo Fisurado', findRichText: true),
        findsWidgets);
  });

  testWidgets('pips de Pulso en cada tarjeta; Terminar turno tras Instante',
      (tester) async {
    // El guerrero usa su Instante (Brasa Fugaz): el turno sigue.
    state = engine
        .command(state, 'guerrero', const SkillCommand('brasaEco'))!
        .state;
    expect(state.currentId, 'guerrero');
    BattleCommand? sent;
    // Con compañeros propios (soloParty): una tarjeta por cada uno.
    await pump(tester,
        canAct: true,
        companions: const {'maga', 'tirador', 'paladin'}, onCommand: (c) {
      sent = c;
      return true;
    });
    for (final id in ['guerrero', 'maga', 'tirador', 'paladin']) {
      expect(find.byKey(ValueKey('pulse-$id')), findsOneWidget, reason: id);
    }
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    menu.selectCategory(BattleCategory.pass);
    await tester.pump();
    expect(find.textContaining('Terminar turno', findRichText: true),
        findsWidgets);
    await tester.tap(act('pass'));
    await tester.pump();
    expect(sent, isA<PassCommand>());
  });

  testWidgets('P va a PASAR y otra P pasa el turno', (tester) async {
    BattleCommand? sent;
    await pump(tester, canAct: true, onCommand: (c) {
      sent = c;
      return true;
    });
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    expect(menu.handleKey(LogicalKeyboardKey.keyP), isTrue);
    await tester.pump();
    expect(menu.category, BattleCategory.pass);
    expect(sent, isNull, reason: 'una P sola no pierde el turno');
    expect(menu.handleKey(LogicalKeyboardKey.keyP), isTrue);
    expect(sent, isA<PassCommand>());
    // Enter también confirma desde PASAR.
    sent = null;
    menu.selectCategory(BattleCategory.pass);
    await tester.pump();
    menu.handleKey(LogicalKeyboardKey.enter);
    expect(sent, isA<PassCommand>());
  });

  testWidgets('P sin turno no hace nada', (tester) async {
    BattleCommand? sent;
    await pump(tester, canAct: false, onCommand: (c) {
      sent = c;
      return true;
    });
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    menu.handleKey(LogicalKeyboardKey.keyP);
    menu.handleKey(LogicalKeyboardKey.keyP);
    expect(sent, isNull);
    expect(find.byKey(const ValueKey('battle-cat-pass')), findsNothing);
  });

  testWidgets('poción: submenú para elegir a quién', (tester) async {
    BattleCommand? sent;
    await pump(tester, canAct: true, onCommand: (c) {
      sent = c;
      return true;
    });
    await tester.tap(find.byKey(const ValueKey('battle-cat-items')));
    await tester.pump();
    await tester.tap(act('potion'));
    await tester.pump();
    expect(find.textContaining('¿A quién le das la Poción de vida'),
        findsOneWidget);
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    expect(menu.hasSubmenu, isTrue);
    await tester.tap(act('give-maga'));
    await tester.pump();
    expect(sent, isA<ItemCommand>());
    expect((sent! as ItemCommand).targetPlayerId, 'maga');
    expect(menu.hasSubmenu, isFalse);
  });

  testWidgets(
      'la descripción nunca es la de otra técnica cuando el menú cambia '
      'bajo el mouse', (tester) async {
    await pump(tester, canAct: true, onCommand: (_) => true);
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    menu.selectCategory(BattleCategory.skills);
    await tester.pump();
    final g = state.current!;
    final first = g.skillIds.first;
    // Mouse sobre la primera técnica del guerrero.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(act('skill-$first')));
    await tester.pump();
    expect(find.byKey(ValueKey('battle-desc-skill-$first')), findsOneWidget);
    // Turno de otro jugador (otras técnicas) con el mouse quieto.
    var next = engine.command(state, 'guerrero', const DefendCommand())!.state;
    while (next.currentId == 'guerrero' ||
        !(next.current?.isPlayer ?? false)) {
      next = engine.nextTurn(next).state;
    }
    final other = next.current!;
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(battle: next, canAct: true, onCommand: (_) => true),
      ),
    ));
    await tester.pump();
    // El menú vuelve a ATACAR de quien actúa ahora; ninguna descripción
    // del guerrero queda a la vista.
    expect(menu.category, BattleCategory.attack);
    expect(find.textContaining('¡Tu turno! ${other.name}'), findsOneWidget);
    for (final id in g.skillIds) {
      if (other.skillIds.contains(id)) continue;
      expect(find.byKey(ValueKey('battle-desc-skill-$id')), findsNothing);
    }
    expect(find.byKey(const ValueKey('battle-desc-attack')), findsOneWidget);
  });

  testWidgets('sin turno propio no hay menú: dice de quién es el turno',
      (tester) async {
    await pump(tester,
        canAct: false,
        localId: 'maga',
        onCommand: (_) => fail('no debía mandar'));
    // Como el prototipo: sin menú. El panel dice de quién es el turno y
    // cuándo me toca; su fila de la lista del grupo lo marca (▶).
    expect(find.byKey(const ValueKey('battle-menu')), findsNothing);
    Finder waiting(String text) => find.descendant(
        of: find.byKey(const ValueKey('battle-waiting')),
        matching: find.text(text));
    expect(waiting('Turno de Guerrero'), findsOneWidget);
    expect(waiting('Tu turno en 3'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('ally-row-guerrero')),
            matching: find.textContaining('▶', findRichText: true)),
        findsOneWidget);
  });

  testWidgets('barra del grupo: una tarjeta por jugador, la mía con el detalle',
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
    // Con compañeros propios (soloParty): tarjetas de todos.
    await pump(tester,
        canAct: false,
        localId: 'maga',
        companions: const {'guerrero', 'tirador', 'paladin'},
        onCommand: (_) => true);

    // Mi tarjeta y las del resto del grupo.
    expect(find.byKey(const ValueKey('my-panel-maga')), findsOneWidget);
    for (final id in ['guerrero', 'tirador', 'paladin']) {
      expect(find.byKey(ValueKey('my-panel-$id')), findsNothing);
      expect(find.byKey(ValueKey('member-$id')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('member-maga')), findsNothing);
    // Las stats detalladas, en el tooltip de mi tarjeta.
    expect(
        find.byWidgetPredicate((w) =>
            w is RetroTooltip &&
            w.message.contains('ATQ ') &&
            w.message.contains('Maga')),
        findsOneWidget);

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

  testWidgets('en solitario: una sola tarjeta y el menú', (tester) async {
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
    expect(find.byKey(const ValueKey('my-panel-maga')), findsOneWidget);
    expect(find.byKey(const ValueKey('battle-cat-duos')), findsNothing);
    expect(act('attack'), findsOneWidget);
  });

  testWidgets('DÚOS lista los de clase y los de armas, con los dos nombres '
      'y el par (v0.8.3)', (tester) async {
    state = engine
        .start(
          party: [member('tirador'), member('maga'), member('guerrero')],
          enemyTypes: const ['slime'],
          triggeredBy: 'tirador',
        )
        .state
      ..currentId = 'tirador';
    BattleCommand? sent;
    await pump(tester, canAct: true, localId: 'tirador', onCommand: (c) {
      sent = c;
      return true;
    });
    final bv = tester.state<BattleViewState>(find.byType(BattleView));
    bv.selectCategory(BattleCategory.duos);
    await tester.pump();
    // tirador (arco) + maga (báculo): Lluvia Estelar (clase) y Flecha
    // Arcana Gemela (armas); tirador + guerrero (espada): Cruz Tormenta.
    expect(act('duo-maga'), findsOneWidget);
    expect(act('duo-maga-w_flechaArcana'), findsOneWidget);
    expect(act('duo-guerrero'), findsOneWidget);
    String rowText(String id) => tester
        .widgetList<RichText>(
            find.descendant(of: act(id), matching: find.byType(RichText)))
        .map((t) => t.text.toPlainText())
        .join(' ');
    expect(rowText('duo-maga'), contains('Lluvia Estelar'));
    expect(rowText('duo-maga'), contains('+Maga')); // el par pasó al detalle (v0.13)
    expect(rowText('duo-maga-w_flechaArcana'), contains('Flecha Arcana Gemela'));
    
    expect(rowText('duo-maga-w_flechaArcana'), contains('Maga'));
    await tester.tap(act('duo-maga-w_flechaArcana'));
    await tester.pump();
    expect(sent, isA<DualCommand>());
    expect((sent! as DualCommand).dualId, 'w_flechaArcana');
    expect((sent! as DualCommand).partnerId, 'maga');
    bv.selectCategory(BattleCategory.duos);
    await tester.pump();
    await tester.tap(act('duo-maga'));
    await tester.pump();
    expect((sent! as DualCommand).dualId, isNull);
    expect(tester.takeException(), isNull);
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
