import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/features/passive_tree/domain/passive_text.dart';
import 'package:echos_del_tiempo/features/passive_tree/presentation/passive_tree_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// Toca el centro del nodo [id] en el lienzo del árbol.
Future<void> tapNode(WidgetTester tester, String id) async {
  final canvas = find.byKey(const ValueKey('tree-canvas'));
  await tester.ensureVisible(canvas);
  await tester.pump();
  final origin = tester.getTopLeft(canvas);
  await tester.tapAt(
      origin + PassiveTreeView.nodeCenter(kPassiveTree.nodes[id]!));
  await tester.pump();
}

void main() {
  test('fxTxt: efectos y keystones', () {
    expect(passiveEffectsText(kPassiveTree.nodes['s_gue']!),
        ['+5% vida máx.', '+4% ATQ']);
    expect(passiveEffectsText(kPassiveTree.nodes['tir_b0']!),
        ['+0.5 velocidad']);
    expect(passiveEffectsText(kPassiveTree.nodes['pal_b3']!).single,
        startsWith('Paladín Inherente:'));
  });

  testWidgets('árbol: tomar, Creyente/Inherente excluidos y reiniciar',
      (tester) async {
    // Paladín Lv9 (8 puntos) con la rama A completa (Creyente) y la B
    // hasta antes de Inherente: le queda 1 punto.
    final c = await pumpPanel(tester,
        profile: progression.normalize(PlayerProfile(
          name: 'Ana',
          classId: 'paladin',
          level: 9,
          tree: const [
            'pal_a0', 'pal_a1', 'pal_a2', 'pal_a3', //
            'pal_b0', 'pal_b1', 'pal_b2',
          ],
        )),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.tree));
    expect(c.view!.me!.profile.tree, hasLength(7));
    expect(find.textContaining('Puntos de árbol disponibles: 1'), findsOneWidget);

    // Inherente: conectada y con puntos, pero excluida por Creyente.
    await tapNode(tester, 'pal_b3');
    expect(c.view!.me!.profile.tree, isNot(contains('pal_b3')));
    expect(find.text('Excluye Paladín Creyente'), findsWidgets);
    final take = tester
        .widget<PanelButton>(find.byKey(const ValueKey('tree-take')));
    expect(take.reason, 'Excluye Paladín Creyente');

    // Un nodo sin conexión: bloqueado con su motivo.
    await tapNode(tester, 'gue_a0');
    expect(find.text('Necesita un nodo conectado'), findsWidgets);
    expect(c.view!.me!.profile.tree, isNot(contains('gue_a0')));

    // Un puente conectado al inicio: se toma con un clic.
    await tapNode(tester, 'b_sw');
    expect(c.view!.me!.profile.tree.last, 'b_sw');
    expect(find.textContaining('Puntos de árbol disponibles: 0'), findsOneWidget);
    expect(find.text('Tomado'), findsWidgets);

    // Sin puntos, todo lo demás queda bloqueado.
    await tapNode(tester, 'b_nw');
    expect(find.text('Sin puntos de árbol'), findsWidgets);

    // Reiniciar (en el lobby).
    await tapVisible(tester, find.byKey(const ValueKey('tree-reset')));
    expect(c.view!.me!.profile.tree, isEmpty);
    expect(find.textContaining('Puntos de árbol disponibles: 8'), findsOneWidget);
    expect(
        tester
            .widget<PanelButton>(find.byKey(const ValueKey('tree-reset')))
            .reason,
        'No hay nodos tomados');
  });
}
