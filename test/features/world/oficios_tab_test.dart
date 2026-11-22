import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// PERSONAJE → OFICIOS (life_skill_trees.md § 1) y PESCA Y CULTIVO
/// (farming.md § 11).
void main() {
  PlayerProfile fisher() {
    var xp = 0;
    for (var l = 1; l < 4; l++) {
      xp += FishingRules.xpNeed(l);
    }
    return progression.normalize(PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        life: LifeSkills(fishXp: xp, farm: FarmSkills.initial)));
  }

  testWidgets('OFICIOS: nivel, barra, tomar un nodo y reiniciar',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: fisher(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.oficios));
    await tester.pump();
    expect(find.byKey(const ValueKey('life-row-pesca')), findsOneWidget);
    expect(find.byKey(const ValueKey('life-row-cultivo')), findsOneWidget);
    expect(find.byKey(const ValueKey('life-xp-pesca')), findsOneWidget);
    // 3 puntos libres: en la fila y en la insignia de la pestaña.
    expect(find.byKey(const ValueKey('life-free-pesca')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(ValueKey('tab-badge-${CharacterTab.oficios.index}')),
            matching: find.text('3')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('life-node-p_a1')));
    await tester.pump();
    expect(find.text('MUÑECA FIRME'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('life-take')));
    await tester.pump(const Duration(milliseconds: 100));
    var me = c.view!.me!.profile;
    expect(LifeTreeRules.has(me, LifeSkillKind.pesca, 'p_a1'), isTrue);
    expect(LifeTreeRules.free(me, LifeSkillKind.pesca), 2);
    await tester.tap(find.byKey(const ValueKey('life-reset')));
    await tester.pump(const Duration(milliseconds: 100));
    me = c.view!.me!.profile;
    expect(LifeTreeRules.taken(me, LifeSkillKind.pesca), isEmpty);
  });

  testWidgets('PESCA Y CULTIVO: herramientas y semillas iniciales',
      (tester) async {
    await pumpPanel(tester,
        profile: fisher(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.lifeItems));
    await tester.pump();
    expect(find.textContaining('Azada de rama'), findsWidgets);
    final seed = find.byKey(const ValueKey('life-seed-nabo_claro'));
    await tester.scrollUntilVisible(seed, 80,
        scrollable: find.byType(Scrollable).last);
    expect(seed, findsOneWidget);
    expect(find.text('PARA PLANTAR'), findsOneWidget);
  });
}
