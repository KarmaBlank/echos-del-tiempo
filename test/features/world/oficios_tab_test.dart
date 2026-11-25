import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:flutter/rendering.dart';
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
    // Tarjetas enteras (v0.24.4): el nivel a la vista, nada con "…".
    expect(find.text('Nivel 4'), findsOneWidget);
    for (final k in ['pesca', 'cultivo']) {
      for (final p in tester.renderObjectList<RenderParagraph>(find.descendant(
          of: find.byKey(ValueKey('life-row-$k')),
          matching: find.byType(RichText)))) {
        expect(p.didExceedMaxLines, isFalse);
      }
    }
    // 3 puntos libres: en la fila y en la insignia de la pestaña.
    expect(find.byKey(const ValueKey('life-free-pesca')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(ValueKey('tab-badge-${CharacterTab.oficios.index}')),
            matching: find.text('3')),
        findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('life-node-fish_a1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('life-node-fish_a1')));
    await tester.pump();
    expect(find.text('MUÑECA FIRME'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('life-take')));
    await tester.pump(const Duration(milliseconds: 100));
    var me = c.view!.me!.profile;
    expect(LifeTreeRules.has(me, LifeSkillKind.pesca, 'fish_a1'), isTrue);
    expect(LifeTreeRules.free(me, LifeSkillKind.pesca), 2);
    await tester.tap(find.byKey(const ValueKey('life-reset')));
    await tester.pump(const Duration(milliseconds: 100));
    me = c.view!.me!.profile;
    expect(LifeTreeRules.taken(me, LifeSkillKind.pesca), isEmpty);
  });

  testWidgets('OFICIOS → INVENTARIO: bolsas, herramientas y semillas',
      (tester) async {
    await pumpPanel(tester,
        profile: fisher(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.oficios));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('oficios-sub-inventario')));
    await tester.pump();
    // PESCA primero: la caña de rama; la azada va en CULTIVO.
    expect(find.byKey(const ValueKey('life-tool-cana_rama')), findsOneWidget);
    expect(find.byKey(const ValueKey('life-tool-azada_rama')), findsNothing);
    expect(find.textContaining('/40'), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('oficio-bag-cultivo')));
    await tester.pump();
    // Grilla de casillas (v0.24.4): el nombre va en el detalle al elegirla.
    await tester.tap(find.byKey(const ValueKey('life-tool-azada_rama')));
    await tester.pump();
    expect(find.textContaining('Azada de rama'), findsWidgets);
    // Filtros por tipo: HERRAMIENTAS esconde las semillas.
    await tester.tap(find.byKey(const ValueKey('oficio-filter-herramientas')));
    await tester.pump();
    expect(find.byKey(const ValueKey('life-seed-nabo_claro')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('oficio-filter-semillas')));
    await tester.pump();
    final seed = find.byKey(const ValueKey('life-seed-nabo_claro'));
    expect(seed, findsOneWidget);
    // El buscador filtra.
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('life-search')),
            matching: find.byType(EditableText)),
        'zzz');
    await tester.pump();
    expect(find.byKey(const ValueKey('life-items-empty')), findsOneWidget);
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('life-search')),
            matching: find.byType(EditableText)),
        '');
    await tester.pump();
    expect(find.text('PARA PLANTAR'), findsOneWidget);
  });
}
