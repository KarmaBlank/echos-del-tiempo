import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/domain/skill_text.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/skill_requirements.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Menú de HABILIDADES: Instante arriba con separador, objetivo de cada
/// fila, Pulso en dorado y motivos en rojo de las desactivadas.

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

String firstSkill(bool Function(SkillDef) f) =>
    kSkills.values.firstWhere(f).id;

void main() {
  late BattleState state;
  final instant = firstSkill((s) => s.instant && s.pulse == 0 && s.mp <= 3);
  final oneFoe = firstSkill((s) =>
      s.kind == SkillKind.physical &&
      !s.allTargets &&
      !s.instant &&
      s.pulse == 0 &&
      s.requires.isEmpty);
  final allFoes = firstSkill((s) =>
      (s.kind == SkillKind.physical || s.kind == SkillKind.magical) &&
      s.allTargets &&
      !s.instant);
  final ally = firstSkill(
      (s) => s.kind == SkillKind.heal && s.lowestAlly && !s.instant);
  final pulsed = firstSkill((s) => s.pulse >= 2 && !s.instant);

  setUp(() {
    final engine = BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99,
    );
    final start = engine.start(
      party: [member('guerrero'), member('maga')],
      enemyTypes: const ['slime', 'bat'],
      triggeredBy: 'guerrero',
    );
    state = engine.nextTurn(start.state).state;
    final cur = state.current!;
    cur.skillIds = [oneFoe, allFoes, instant, ally, pulsed];
    cur.mp = 99;
    cur.pulse = 0;
  });

  Future<(BattleViewState, List<BattleCommand>)> pump(
      WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sent = <BattleCommand>[];
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(
            battle: state,
            canAct: true,
            onCommand: (c) {
              sent.add(c);
              return true;
            }),
      ),
    ));
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    menu.selectCategory(BattleCategory.skills);
    await tester.pump();
    return (menu, sent);
  }

  Finder row(String id) => find.byKey(ValueKey('battle-act-skill-$id'));

  /// Los TextSpan con color de [text] dentro de [of].
  List<Color?> spanColors(WidgetTester tester, Finder of, String text) {
    final out = <Color?>[];
    for (final w in tester.widgetList<RichText>(
        find.descendant(of: of, matching: find.byType(RichText)))) {
      // El color va en el span padre: se hereda.
      void walk(InlineSpan s, Color? inherited) {
        if (s is! TextSpan) return;
        final c = s.style?.color ?? inherited;
        if ((s.text ?? '').contains(text)) out.add(c);
        for (final k in s.children ?? const <InlineSpan>[]) {
          walk(k, c);
        }
      }

      walk(w.text, null);
    }
    return out;
  }

  test('objetivo de cada habilidad', () {
    expect(skillReach(kSkills[oneFoe]!), SkillReach.oneFoe);
    expect(skillReach(kSkills[allFoes]!), SkillReach.allFoes);
    expect(skillReach(kSkills[ally]!), SkillReach.ally);
    expect(skillReachMarkup(kSkills[allFoes]!), contains('[TODOS]'));
  });

  testWidgets('Instante primero, con marca y separador; teclas en orden',
      (tester) async {
    final (menu, sent) = await pump(tester);
    expect(tester.getTopLeft(row(instant)).dy,
        lessThan(tester.getTopLeft(row(oneFoe)).dy));
    // Sin banner arriba de la lista.
    expect(find.byKey(ValueKey('battle-sep-skill-$instant')), findsNothing);
    expect(find.textContaining('no terminan tu turno'), findsNothing);
    expect(
        find.descendant(
            of: row(instant),
            matching: find.textContaining('INSTANTE', findRichText: true)),
        findsOneWidget);
    // La tecla 1 es la primera fila que se ve: la Instante.
    menu.handleKey(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect((sent.single as SkillCommand).skillId, instant);
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('panel derecho: INSTANTE solo con una Instante (x$scale)',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      // Solo los desbordes del panel de detalle (la barra de objetivo es
      // de otro componente).
      final errs = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => errs.add(d.toString());
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (menu, _) = await pump(tester);
      final note = find.byKey(const ValueKey('battle-instant-note'));
      // Foco de teclado: la primera fila es la Instante.
      expect(note, findsOneWidget);
      expect(
          find.descendant(
              of: note, matching: find.textContaining('no termina tu turno')),
          findsOneWidget);
      expect(find.descendant(of: note, matching: find.byType(DsTag)),
          findsOneWidget);
      menu.handleKey(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(note, findsNothing);
      // Hover vuelve a la Instante.
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.addPointer(location: Offset.zero);
      addTearDown(g.removePointer);
      await g.moveTo(tester.getCenter(row(instant)));
      await tester.pump();
      expect(note, findsOneWidget);
      FlutterError.onError = prev;
      expect(errs.where((e) => e.contains('battle-desc')), isEmpty);
    });
  }

  testWidgets('deshabilitada: tooltip solo con motivo especial',
      (tester) async {
    final special = kSkills.values.firstWhere((s) =>
        s.requires.isNotEmpty &&
        s.id != pulsed &&
        !s.instant &&
        SkillRequirements.missingLines(s, state.current!, state.enemies.first,
                foes: state.enemies)
            .any((l) => l.startsWith('Necesita')));
    state.current!
      ..skillIds = [oneFoe, special.id, ally]
      ..mp = 0
      ..pulse = 0;
    await pump(tester);
    expect(find.byKey(ValueKey('battle-hint-skill-${special.id}')),
        findsOneWidget);
    expect(
        tester
            .widget<Tooltip>(
                find.byKey(ValueKey('battle-hint-skill-${special.id}')))
            .message,
        contains('Necesita'));
    // Básico (falta MP, se ve en rojo): gris sin tooltip.
    expect(kSkills[ally]!.mp, greaterThan(0));
    expect(find.byKey(ValueKey('battle-hint-skill-$ally')), findsNothing);
  });

  testWidgets('dúo sin MP: gris, sin texto extra ni tooltip', (tester) async {
    for (final q in state.party) {
      q.mp = 0;
    }
    final (menu, _) = await pump(tester);
    menu.selectCategory(BattleCategory.duos);
    await tester.pump();
    final rows = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('battle-act-duo-'));
    if (rows.evaluate().isEmpty) return; // sin dúo para este par
    final r = tester.widget<DsListRow>(
        find.descendant(of: rows.first, matching: find.byType(DsListRow)));
    expect(r.enabled, isFalse);
    expect(find.textContaining('sin compañ', findRichText: true), findsNothing);
    expect(
        find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('battle-hint-duo')),
        findsNothing);
  });

  testWidgets('encadenada: el encabezado avisa la acción que queda',
      (tester) async {
    state.current!.chained = true;
    await pump(tester);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('battle-header')),
            matching: find.textContaining('te queda una acción',
                findRichText: true)),
        findsOneWidget);
  });

  testWidgets('etiquetas de objetivo y resaltado en la escena',
      (tester) async {
    final (menu, _) = await pump(tester);
    for (final (id, label) in [
      (oneFoe, '1 ENEMIGO'),
      (allFoes, 'TODOS'),
      (ally, 'ALIADO'),
    ]) {
      expect(
          find.descendant(
              of: row(id),
              matching: find.textContaining(label, findRichText: true)),
          findsOneWidget,
          reason: id);
    }
    // Hover sobre la de a TODOS: se marcan todos los enemigos vivos.
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(tester.getCenter(row(allFoes)));
    await tester.pump();
    expect(menu.highlightedTargets,
        {for (final e in state.enemies) if (e.alive) e.id});
    await g.moveTo(tester.getCenter(row(oneFoe)));
    await tester.pump();
    expect(menu.highlightedTargets, {menu.target});
    await g.moveTo(tester.getCenter(row(ally)));
    await tester.pump();
    expect(menu.highlightedTargets, isEmpty);
    // Resumen de una línea arriba del detalle.
    expect(
        find.descendant(
            of: find.byKey(ValueKey('battle-desc-skill-$ally')),
            matching: find.textContaining('A un aliado', findRichText: true)),
        findsOneWidget);
  });

  testWidgets('Pulso en dorado en la fila normal y elegida (DsCost)',
      (tester) async {
    state.current!.pulse = BattleEngine.pulseMax;
    final (menu, _) = await pump(tester);
    final p = '${kSkills[pulsed]!.pulse} P';
    const idx = 4; // la última fila (la Instante subió)
    expect(menu.selectedAction, isNot(idx));
    expect(spanColors(tester, row(pulsed), p), [DsColors.pulse]);
    for (var i = 0; i < idx; i++) {
      menu.handleKey(LogicalKeyboardKey.arrowDown);
    }
    await tester.pump();
    expect(menu.selectedAction, idx);
    expect(spanColors(tester, row(pulsed), p), [DsColors.pulse]);
  });

  testWidgets('costo que no alcanza: en rojo', (tester) async {
    final (_, _) = await pump(tester);
    final p = '${kSkills[pulsed]!.pulse} P';
    expect(spanColors(tester, row(pulsed), p), [DsColors.danger]);
  });

  testWidgets('desactivada: atenuada, motivos en rojo arriba, no actúa',
      (tester) async {
    state.current!
      ..mp = 1
      ..pulse = 1;
    final (menu, sent) = await pump(tester);
    final sk = kSkills[pulsed]!;
    // Desactivada: el nombre en el color de texto desactivado.
    final title = tester.widget<Text>(find.descendant(
        of: row(pulsed), matching: find.text(kSkills[pulsed]!.name)));
    expect(title.style?.color, DsColors.textDisabled);
    for (var i = 0; i < 4; i++) {
      menu.handleKey(LogicalKeyboardKey.arrowDown);
    }
    await tester.pump();
    final lines = [
      if (sk.mp > 1) 'Falta: ${sk.mp} MP (tenés 1)',
      'Falta: Pulso ${sk.pulse} (tenés 1)',
    ];
    for (final (i, l) in lines.indexed) {
      final f = find.byKey(ValueKey('battle-reason-$i'));
      expect(spanColors(tester, f, l), [DsColors.danger], reason: l);
    }
    menu.handleKey(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, isEmpty);
    expect(state.current!.chained, isFalse);
  });
}
