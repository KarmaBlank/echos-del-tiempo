import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/features/passive_tree/domain/passive_text.dart';
import 'package:echos_del_tiempo/features/passive_tree/presentation/passive_tree_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// Centro del nodo [id] en pantalla (el lienzo está dentro del visor con
/// arrastre y zoom: se pasa por su transformación).
Offset nodeOnScreen(WidgetTester tester, String id) {
  final box =
      tester.renderObject<RenderBox>(find.byKey(const ValueKey('tree-canvas')));
  return box.localToGlobal(PassiveTreeView.nodeCenter(kPassiveTree.nodes[id]!));
}

/// Toca el centro del nodo [id] en el lienzo del árbol.
Future<void> tapNode(WidgetTester tester, String id) async {
  await tester.ensureVisible(find.byKey(const ValueKey('tree-viewport')));
  await tester.pump();
  await tester.tapAt(nodeOnScreen(tester, id));
  await tester.pump();
}

List<String> _path(String id, [int upTo = 8]) => [
      for (final s in ['1', '2', '3', 'n1', '4', '5', 'n2', 'k'].take(upTo))
        '${id}_$s',
    ];

Future<dynamic> _pumpTree(WidgetTester tester, PlayerProfile profile) =>
    pumpPanel(tester,
        profile: progression.normalize(profile),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.tree));

void main() {
  test('fxTxt: efectos, notables y keystones', () {
    expect(passiveEffectsText(kPassiveTree.nodes['s_gue']!),
        ['+5% vida máx.', '+4% ATQ']);
    expect(passiveEffectsText(kPassiveTree.nodes['viento_1']!),
        ['+0.3 velocidad']);
    expect(passiveEffectsText(kPassiveTree.nodes['juicio_k']!).single,
        startsWith('Paladín Inherente:'));
    expect(passiveEffectsText(kPassiveTree.nodes['filo_n1']!), [
      '+3% crítico',
      startsWith('Al hacer crítico: +20% velocidad por 2 turnos'),
    ]);
    expect(passiveEffectsText(kPassiveTree.nodes['filo_k']!).single,
        startsWith('Danza de Cuchillas:'));
  });

  testWidgets('árbol: Creyente/Inherente excluidos, bloqueos y reiniciar',
      (tester) async {
    // Paladín Lv17 (16 puntos) con Fe completo (Creyente) y Juicio hasta
    // antes de Inherente: le queda 1 punto.
    final c = await _pumpTree(
        tester,
        PlayerProfile(
          name: 'Ana',
          classId: 'paladin',
          level: 17,
          tree: [..._path('fe'), ..._path('juicio', 7)],
        ));
    expect(c.view!.me!.profile.tree, hasLength(15));
    expect(
        find.textContaining('Puntos de árbol disponibles: 1'), findsOneWidget);

    // Inherente: conectada y con puntos, pero excluida por Creyente.
    await tapNode(tester, 'juicio_k');
    expect(c.view!.me!.profile.tree, isNot(contains('juicio_k')));
    expect(find.text('Excluye Paladín Creyente'), findsWidgets);
    final take =
        tester.widget<PanelButton>(find.byKey(const ValueKey('tree-take')));
    expect(take.reason, 'Excluye Paladín Creyente');

    // Un nodo sin conexión: bloqueado con su motivo.
    await tapNode(tester, 'bastion_2');
    expect(find.text('Necesita un nodo conectado'), findsWidgets);
    expect(c.view!.me!.profile.tree, isNot(contains('bastion_2')));

    // El umbral del anillo, conectado al inicio: se toma con un clic.
    await tapNode(tester, 'p_pal');
    expect(c.view!.me!.profile.tree.last, 'p_pal');
    expect(
        find.textContaining('Puntos de árbol disponibles: 0'), findsOneWidget);
    expect(find.text('Tomado'), findsWidgets);

    // Sin puntos, todo lo demás queda bloqueado.
    await tapNode(tester, 'bastion_1');
    expect(find.text('Sin puntos de árbol'), findsWidgets);

    // Reiniciar (gratis).
    expect(find.text('REINICIAR ARBOL (GRATIS)'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('tree-reset')));
    expect(c.view!.me!.profile.tree, isEmpty);
    expect(
        find.textContaining('Puntos de árbol disponibles: 16'), findsOneWidget);
    expect(
        tester
            .widget<PanelButton>(find.byKey(const ValueKey('tree-reset')))
            .reason,
        'No hay nodos tomados');
  });

  testWidgets('árbol: tomar un notable con un clic y ver su tooltip',
      (tester) async {
    final c = await _pumpTree(
        tester,
        PlayerProfile(
          name: 'Leo',
          classId: 'tirador',
          level: 6,
          tree: _path('precision', 3),
        ));
    expect(
        find.textContaining('Puntos de árbol disponibles: 2'), findsOneWidget);

    // Pasar el mouse: tooltip con nombre, camino y la mecánica completa.
    await tester.ensureVisible(find.byKey(const ValueKey('tree-viewport')));
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(nodeOnScreen(tester, 'precision_n1'));
    await tester.pump();
    final tip = find.byKey(const ValueKey('tree-tooltip'));
    expect(tip, findsOneWidget);
    expect(find.descendant(of: tip, matching: find.text('Marca del Cazador')),
        findsOneWidget);
    expect(
        find.descendant(
            of: tip,
            matching: find.textContaining('NOTABLE · Camino Precisión')),
        findsOneWidget);
    expect(
        find.descendant(
            of: tip, matching: find.textContaining('+15% de daño de todos')),
        findsOneWidget);
    expect(
        find.descendant(
            of: tip, matching: find.text('Disponible: clic para tomar')),
        findsOneWidget);

    // Clic: lo toma.
    await tester.tapAt(nodeOnScreen(tester, 'precision_n1'));
    await tester.pump();
    expect(c.view!.me!.profile.tree.last, 'precision_n1');
    expect(
        find.textContaining('Puntos de árbol disponibles: 1'), findsOneWidget);
    expect(find.descendant(of: tip, matching: find.text('Tomado')),
        findsOneWidget);

    // Salir del lienzo: se va el tooltip.
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.byKey(const ValueKey('tree-tooltip')), findsNothing);
  });

  testWidgets('el visor se mueve arrastrando', (tester) async {
    await _pumpTree(tester, PlayerProfile(name: 'Leo', classId: 'maga'));
    await tester.ensureVisible(find.byKey(const ValueKey('tree-viewport')));
    await tester.pump();
    final before = nodeOnScreen(tester, 's_mag');
    final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('tree-viewport'))));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    final after = nodeOnScreen(tester, 's_mag');
    expect(after.dx, lessThan(before.dx - 20));
  });
}
