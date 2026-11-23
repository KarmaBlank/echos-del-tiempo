import 'package:echos_del_tiempo/features/combat/presentation/combat_strings.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
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
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Menú ARMA (docs/specs/battle_attack_menu.md § 6): Atacar, Defender,
/// filas contextuales e Instante; HABILIDADES sin Instante; Defender con
/// la tecla 2.

BattlePartyMember _member(String classId) {
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
  late BattleState state;
  final instants = kSkills.values
      .where((s) => s.instant && s.pulse == 0)
      .take(2)
      .map((s) => s.id)
      .toList();
  final normal = kSkills.values
      .firstWhere((s) => !s.instant && s.pulse == 0 && s.requires.isEmpty)
      .id;

  setUp(() {
    final engine = BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99,
    );
    final start = engine.start(
      party: [_member('guerrero'), _member('maga')],
      enemyTypes: const ['slime', 'bat'],
      triggeredBy: 'guerrero',
    );
    state = engine.nextTurn(start.state).state;
    final cur = state.current!;
    cur.skillIds = [normal, ...instants];
    cur.mp = 99;
  });

  Future<(BattleViewState, List<BattleCommand>)> pump(WidgetTester tester,
      {Size size = const Size(1280, 720)}) async {
    tester.view.physicalSize = size;
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
    return (tester.state<BattleViewState>(find.byType(BattleView)), sent);
  }

  Finder row(String id) => find.byKey(ValueKey('battle-act-$id'));

  testWidgets('ARMA es la primera: Atacar, Defender y las Instante',
      (tester) async {
    final (menu, _) = await pump(tester);
    expect(menu.category, BattleCategory.weapon);
    expect(BattleCategory.weapon.labelKey, 'ui.combat.cat.weapon');
    expect(BattleCategory.values.map((c) => fallbackCombatStrings().t(c.labelKey)), isNot(contains('DEFENDER')));
    expect(find.text('ARMA'), findsOneWidget);
    expect(row('attack'), findsOneWidget);
    expect(row('defend'), findsOneWidget);
    for (final id in instants) {
      expect(row('skill-$id'), findsOneWidget);
    }
    // Orden: Atacar, Defender, Instante.
    final y = [
      tester.getTopLeft(row('attack')).dy,
      tester.getTopLeft(row('defend')).dy,
      tester.getTopLeft(row('skill-${instants.first}')).dy,
    ];
    expect(y[0] < y[1] && y[1] < y[2], isTrue);
    expect(row('skill-$normal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HABILIDADES ya no muestra Instante', (tester) async {
    final (menu, _) = await pump(tester);
    menu.selectCategory(BattleCategory.skills);
    await tester.pump();
    expect(row('skill-$normal'), findsOneWidget);
    for (final id in instants) {
      expect(row('skill-$id'), findsNothing);
    }
  });

  testWidgets('Defender: tecla 2 al empezar el turno', (tester) async {
    final (menu, sent) = await pump(tester);
    expect(menu.handleKey(LogicalKeyboardKey.digit2), isTrue);
    await tester.pump();
    expect(sent.single, isA<DefendCommand>());
  });

  testWidgets('Atacar sigue en 1 / Enter; la Instante va con su tecla',
      (tester) async {
    final (menu, sent) = await pump(tester);
    menu.handleKey(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent.single, isA<AttackCommand>());
    menu.handleKey(LogicalKeyboardKey.digit3);
    await tester.pump();
    expect((sent.last as SkillCommand).skillId, instants.first);
  });

  testWidgets('panel derecho de Defender: Pulso y ULT', (tester) async {
    final (menu, _) = await pump(tester);
    menu.handleKey(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(menu.selectedAction, 1);
    expect(find.textContaining('+2 Pulso', findRichText: true), findsWidgets);
    expect(find.textContaining('+6 ULT', findRichText: true), findsWidgets);
  });

  testWidgets('racha de Defender: la fila dice +1 Pulso', (tester) async {
    state.current!.guardStreak = true;
    await pump(tester);
    expect(find.textContaining('+1 Pulso', findRichText: true), findsWidgets);
  });

  testWidgets('co-op: sin poder actuar, la tecla 2 no manda nada',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sent = <BattleCommand>[];
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(
            battle: state,
            canAct: false,
            onCommand: (c) {
              sent.add(c);
              return true;
            }),
      ),
    ));
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    menu.handleKey(LogicalKeyboardKey.digit2);
    await tester.pump();
    expect(sent, isEmpty);
  });

  for (final size in const [Size(1280, 720), Size(960, 540), Size(800, 600)]) {
    testWidgets('ARMA sin desbordes a ${size.width.toInt()}×'
        '${size.height.toInt()}', (tester) async {
      await pump(tester, size: size);
      expect(tester.takeException(), isNull);
      menuDown(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

void menuDown(WidgetTester tester) =>
    tester.state<BattleViewState>(find.byType(BattleView))
      ..handleKey(LogicalKeyboardKey.arrowDown)
      ..handleKey(LogicalKeyboardKey.arrowDown);
