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

PassiveTreePainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.descendant(
        of: find.byKey(const ValueKey('tree-canvas')),
        matching: find.byType(CustomPaint)))
    .painter! as PassiveTreePainter;

const _cluster = ['n1', 'm1', 'm2', 'na', 'ma', 'nb', 'mb', 'nc', 'k'];

List<String> _c(String id, [int upTo = 9]) =>
    [for (final s in _cluster.take(upTo)) '${id}_$s'];

Future<dynamic> _pumpTree(WidgetTester tester, PlayerProfile profile) =>
    pumpPanel(tester,
        profile: progression.normalize(profile),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.tree));

Future<TestGesture> _mouse(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('tree-viewport')));
  await tester.pump();
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  return mouse;
}

void main() {
  test('fxTxt: efectos, notables y keystones (con su contra)', () {
    expect(passiveEffectsText(kPassiveTree.nodes['s_gue']!),
        ['+5% vida máx.', '+4% ATQ']);
    expect(passiveEffectsText(kPassiveTree.nodes['viento_m1']!),
        ['+0.2 velocidad']);
    expect(passiveEffectsText(kPassiveTree.nodes['juicio_k']!).single,
        startsWith('Paladín Inherente:'));
    expect(passiveEffectsText(kPassiveTree.nodes['filo_na']!), [
      '+1.5% crítico',
      startsWith('Al hacer crítico: +20% velocidad por 2 turnos'),
    ]);
    expect(passiveEffectsText(kPassiveTree.nodes['filo_k']!).single,
        startsWith('Danza de Cuchillas:'));
    final demoledor = passiveEffectsText(kPassiveTree.nodes['quiebre_k']!);
    expect(demoledor.single, startsWith('Demoledor: Cuando vos o un aliado'));
    expect(demoledor.single, contains('Pero −15% vida máx.'));
  });

  test('buscador: sin tildes ni mayúsculas, por nombre, cluster o efecto', () {
    expect(foldSearch('DAÑO Ensañamiento'), 'dano ensanamiento');
    final t = passiveSearchText(kPassiveTree, kPassiveTree.nodes['quiebre_nb']!);
    expect(t, contains('ensanamiento'));
    expect(t, contains('quiebre'));
    expect(t, contains('quebrados'));
  });

  testWidgets('árbol: Creyente/Inherente excluidos, bloqueos y reiniciar',
      (tester) async {
    // Paladín Lv15 (14 puntos): ruta + Fe completo (Creyente) + Juicio
    // por el atajo hasta antes de Inherente: le queda 1 punto.
    final c = await _pumpTree(
        tester,
        PlayerProfile(
          name: 'Ana',
          classId: 'paladin',
          level: 15,
          tree: [
            'pal_r1', 'pal_f3', ..._c('fe'), //
            'juicio_mb', 'juicio_nc',
          ],
        ));
    expect(c.view!.me!.profile.tree, hasLength(13));
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
    await tapNode(tester, 'bastion_m1');
    expect(find.text('Necesita un nodo conectado'), findsWidgets);
    expect(c.view!.me!.profile.tree, isNot(contains('bastion_m1')));

    // El umbral del anillo, conectado al inicio: se toma con un clic.
    await tapNode(tester, 'p_pal');
    expect(c.view!.me!.profile.tree.last, 'p_pal');
    expect(
        find.textContaining('Puntos de árbol disponibles: 0'), findsOneWidget);
    expect(find.text('Tomado'), findsWidgets);

    // Sin puntos, todo lo demás queda bloqueado.
    await tapNode(tester, 'pal_f2');
    expect(find.text('Sin puntos de árbol'), findsWidgets);

    // Reiniciar (gratis).
    expect(find.text('REINICIAR ARBOL (GRATIS)'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('tree-reset')));
    expect(c.view!.me!.profile.tree, isEmpty);
    expect(
        find.textContaining('Puntos de árbol disponibles: 14'), findsOneWidget);
    expect(
        tester
            .widget<PanelButton>(find.byKey(const ValueKey('tree-reset')))
            .reason,
        'No hay nodos tomados');
  });

  testWidgets('árbol: tooltip con costo, camino resaltado y tomar con un clic',
      (tester) async {
    final c = await _pumpTree(
        tester,
        PlayerProfile(
          name: 'Leo',
          classId: 'tirador',
          level: 10,
          tree: ['tir_r1', 'tir_f3', ..._c('precision', 5)],
        ));
    expect(
        find.textContaining('Puntos de árbol disponibles: 2'), findsOneWidget);

    // Pasar el mouse por un nodo lejano: camino dorado y su costo.
    final mouse = await _mouse(tester);
    await mouse.moveTo(nodeOnScreen(tester, 'precision_k'));
    await tester.pump();
    final tip = find.byKey(const ValueKey('tree-tooltip'));
    expect(find.descendant(of: tip, matching: find.text('Costo: 2 puntos')),
        findsOneWidget);
    expect(_painter(tester).route, {'precision_nc', 'precision_k'});

    // El notable de unión (v4): tooltip con nombre, cluster y la mecánica.
    await mouse.moveTo(nodeOnScreen(tester, 'precision_nc'));
    await tester.pump();
    expect(find.descendant(of: tip, matching: find.text('Grieta Expuesta')),
        findsOneWidget);
    expect(
        find.descendant(
            of: tip,
            matching: find.textContaining('NOTABLE · Cluster Precisión')),
        findsOneWidget);
    expect(
        find.descendant(
            of: tip, matching: find.textContaining('barra de quiebre un 40%')),
        findsOneWidget);
    expect(find.descendant(of: tip, matching: find.text('Costo: 1 punto')),
        findsOneWidget);
    expect(
        find.descendant(
            of: tip, matching: find.text('Disponible: clic para tomar')),
        findsOneWidget);

    // Clic: lo toma.
    await tester.tapAt(nodeOnScreen(tester, 'precision_nc'));
    await tester.pump();
    expect(c.view!.me!.profile.tree.last, 'precision_nc');
    expect(
        find.textContaining('Puntos de árbol disponibles: 1'), findsOneWidget);
    expect(find.descendant(of: tip, matching: find.text('Tomado')),
        findsOneWidget);
    expect(_painter(tester).route, isEmpty);

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

  testWidgets('zoom: botones +/−, rueda y TODO encuadra el árbol entero',
      (tester) async {
    await _pumpTree(tester, PlayerProfile(name: 'Leo', classId: 'guerrero'));
    await tester.ensureVisible(find.byKey(const ValueKey('tree-viewport')));
    await tester.pump();
    double gap() =>
        (nodeOnScreen(tester, 'quiebre_n1') - nodeOnScreen(tester, 'quiebre_k'))
            .distance;
    final g0 = gap();
    await tapVisible(tester, find.byKey(const ValueKey('tree-zoom-in')));
    expect(gap(), closeTo(g0 * 1.25, 0.5));
    await tapVisible(tester, find.byKey(const ValueKey('tree-zoom-out')));
    await tapVisible(tester, find.byKey(const ValueKey('tree-zoom-out')));
    expect(gap(), closeTo(g0 / 1.25, 0.5));

    // Rueda del mouse: acerca.
    final g1 = gap();
    final center =
        tester.getCenter(find.byKey(const ValueKey('tree-viewport')));
    await tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, -200)));
    await tester.pump();
    expect(gap(), greaterThan(g1));

    // TODO: todos los nodos dentro del visor.
    await tapVisible(tester, find.byKey(const ValueKey('tree-fit')));
    final rect = tester.getRect(find.byKey(const ValueKey('tree-viewport')));
    for (final id in kPassiveTree.nodes.keys) {
      expect(rect.contains(nodeOnScreen(tester, id)), isTrue, reason: id);
    }
    // MI CLASE: vuelve a la zona del guerrero.
    await tapVisible(tester, find.byKey(const ValueKey('tree-home')));
    expect(rect.contains(nodeOnScreen(tester, 'quiebre_k')), isTrue);
    expect(gap(), greaterThan(g1 * 0.9));
  });

  testWidgets('buscador: resalta coincidencias y Enter centra la primera',
      (tester) async {
    await _pumpTree(tester, PlayerProfile(name: 'Leo', classId: 'paladin'));
    await tester.ensureVisible(find.byKey(const ValueKey('tree-search')));
    await tester.enterText(find.byKey(const ValueKey('tree-search')), 'DANZA');
    await tester.pump();
    final hits = _painter(tester).hits;
    expect(hits, contains('filo_k'));
    expect(find.byKey(const ValueKey('tree-search-count')), findsOneWidget);
    expect(find.text('${hits.length} coincidencia${hits.length == 1 ? '' : 's'}'),
        findsOneWidget);

    // Enter: centra el visor en la primera (que está lejos del paladín).
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final rect = tester.getRect(find.byKey(const ValueKey('tree-viewport')));
    final at = nodeOnScreen(tester, hits.first);
    expect((at - rect.center).distance, lessThan(2));

    await tester.enterText(
        find.byKey(const ValueKey('tree-search')), 'zzzz nada');
    await tester.pump();
    expect(_painter(tester).hits, isEmpty);
    expect(find.text('Sin coincidencias'), findsOneWidget);
  });
}
