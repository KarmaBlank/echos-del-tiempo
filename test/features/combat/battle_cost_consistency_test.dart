import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Costos del menú de batalla: HABILIDADES, DÚOS, ULTIMATE y OBJETOS los
/// muestran con el mismo `DsCost` (mismo tamaño, a la derecha), nunca
/// dentro del título, y todas tienen resumen de una línea.

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
  late BattleState state;

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
    for (final p in state.party) {
      p.mp = 99;
    }
    final cur = state.current!;
    cur.skillIds = [kSkills.values.firstWhere((s) => s.mp > 0).id];
    cur.ult = 45;
  });

  testWidgets('una acción por categoría: DsCost del mismo tamaño, fuera '
      'del título, con resumen', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(battle: state, canAct: true, onCommand: (_) => true),
      ),
    ));
    final menu = tester.state<BattleViewState>(find.byType(BattleView));

    double? skillSize;
    double? skillHeight;
    for (final cat in [
      BattleCategory.skills,
      BattleCategory.duos,
      BattleCategory.ultimate,
      BattleCategory.items,
    ]) {
      menu.selectCategory(cat);
      await tester.pump();
      final window =
          tester.widget<BattleCommandWindow>(find.byType(BattleCommandWindow));
      expect(window.visible, isNotEmpty, reason: cat.label);
      final a = window.visible.first;
      final row = find.byKey(ValueKey('battle-act-${a.id}'));
      final cost = find.descendant(of: row, matching: find.byType(DsCost));
      expect(cost, findsOneWidget, reason: cat.label);
      final dc = tester.widget<DsCost>(cost);
      final textF = find.descendant(of: cost, matching: find.byType(Text));
      final size = tester.widget<Text>(textF).style!.fontSize!;
      final height = tester.getSize(textF).height;
      skillSize ??= size;
      skillHeight ??= height;
      expect(size, skillSize, reason: cat.label);
      // Mismo tamaño en pantalla (ningún FittedBox lo achica distinto).
      expect(height, closeTo(skillHeight, 0.5), reason: cat.label);
      // El costo nunca va dentro del título.
      final title = tester
          .widget<DsListRow>(
              find.descendant(of: row, matching: find.byType(DsListRow)))
          .title;
      expect(title, isNot(contains(dc.label)), reason: cat.label);
      expect(title, isNot(contains(' MP')), reason: cat.label);
      // Resumen de una línea en el detalle.
      expect(a.summary, isNotNull, reason: cat.label);
      expect(a.summary, isNot(contains('<br')), reason: cat.label);
    }
  });
}
