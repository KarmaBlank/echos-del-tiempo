import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/passive_tree/domain/passive_text.dart';
import 'package:echos_del_tiempo/features/passive_tree/presentation/passive_tree_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/app/theme/retro_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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


Future<dynamic> _pumpTree(WidgetTester tester, PlayerProfile profile) =>
    pumpPanel(tester,
        profile: progression.normalize(profile),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.tree));

/// Los puntos libres en la barra de arriba (número grande en dorado).
Finder _points(int n) => find.byWidgetPredicate((w) =>
    w is Text &&
    w.key == const ValueKey('tree-points') &&
    (w.data ?? w.textSpan!.toPlainText()).startsWith('$n punto'));

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
        ['+0.4 velocidad']);
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
    // Paladín con Fe completo (Creyente) y Juicio hasta antes de
    // Inherente (progresión v2: 1 punto por nivel).
    final r = treeRules;
    final fe = r.pathTo('paladin', PlayerPassiveProgress.empty, 'fe_k')!;
    final ju = r.pathTo('paladin', PlayerPassiveProgress(fe),
        kPassiveTree.nodes['juicio_k']!.links.first)!;
    final tree = [...fe, ...ju];
    final level = tree.length + 2;
    final c = await _pumpTree(
        tester,
        PlayerProfile(
          name: 'Ana',
          classId: 'paladin',
          level: level,
          tree: tree,
          // Hito ya elegido (sin cartel de hito).
          milestone10: level >= 10 ? 'fe_k' : null,
        ));
    expect(c.view!.me!.profile.tree, hasLength(tree.length));
    final free = c.view!.me!.profile.treePoints - tree.length;
    expect(_points(free),
        findsOneWidget);

    // Inherente: conectada y con puntos, pero excluida por Creyente.
    await tapNode(tester, 'juicio_k');
    expect(c.view!.me!.profile.tree, isNot(contains('juicio_k')));
    expect(find.text('Excluye Paladín Creyente'), findsWidgets);
    final take =
        tester.widget<DsButton>(find.byKey(const ValueKey('tree-take')));
    expect(take.tooltip, 'Excluye Paladín Creyente');

    // Un chico sin conexión: bloqueado con su motivo.
    final far = kPassiveTree.nodes.values.firstWhere((n) =>
        n.kind == 's' &&
        n.pathId == 'bastion' &&
        !n.links.any((l) => tree.contains(l)));
    await tapNode(tester, far.id);
    expect(find.text('Necesita un nodo conectado'), findsWidgets);
    expect(c.view!.me!.profile.tree, isNot(contains(far.id)));

    // Un nodo conectado al inicio: se toma con un clic.
    final near = kPassiveTree.nodes['s_pal']!.links
        .firstWhere((l) => !tree.contains(l));
    await tapNode(tester, near);
    expect(c.view!.me!.profile.tree.last, near);
    expect(find.text('Tomado'), findsWidgets);

    // Reiniciar (gratis); con hitos elegidos pide confirmar y lo dice.
    expect(find.text('REINICIAR ARBOL (GRATIS)'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('tree-reset')));
    await tester.pumpAndSettle();
    if (find.byKey(const ValueKey('pick-tree-reset-yes')).evaluate().isNotEmpty) {
      expect(find.textContaining('volver a elegir tus hitos'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pick-tree-reset-yes')));
      await tester.pumpAndSettle();
    }
    expect(c.view!.me!.profile.tree, isEmpty);
    expect(
        tester
            .widget<DsButton>(find.byKey(const ValueKey('tree-reset')))
            .tooltip,
        'No hay nodos tomados');
  });

  testWidgets('árbol: sin puntos, todo bloqueado', (tester) async {
    final first = kPassiveTree.nodes['s_pal']!.links.first;
    await _pumpTree(tester,
        PlayerProfile(name: 'Ana', classId: 'paladin', level: 2,
            tree: [first]));
    final other =
        kPassiveTree.nodes['s_pal']!.links.firstWhere((l) => l != first);
    await tapNode(tester, other);
    expect(find.text('Sin puntos de árbol'), findsWidgets);
  });

  testWidgets('árbol: tooltip con costo, camino resaltado y tomar con un clic',
      (tester) async {
    final full = treeRules.pathTo(
        'tirador', PlayerPassiveProgress.empty, 'precision_k')!;
    final tree = full.sublist(0, full.length - 2);
    final nc = full[full.length - 2];
    final c = await _pumpTree(
        tester,
        PlayerProfile(
          name: 'Leo',
          classId: 'tirador',
          level: tree.length + 3,
          tree: tree,
        ));
    expect(
        _points(2), findsOneWidget);

    // Pasar el mouse por un nodo lejano: camino dorado y su costo.
    final mouse = await _mouse(tester);
    await mouse.moveTo(nodeOnScreen(tester, 'precision_k'));
    await tester.pump();
    final tip = find.byKey(const ValueKey('tree-tooltip'));
    expect(find.descendant(of: tip, matching: find.text('Costo: 2 puntos')),
        findsOneWidget);
    expect(_painter(tester).route, {nc, 'precision_k'});

    // El nodo anterior: costo 1 y disponible.
    await mouse.moveTo(nodeOnScreen(tester, nc));
    await tester.pump();
    expect(find.descendant(of: tip, matching: find.text('Costo: 1 punto')),
        findsOneWidget);
    expect(
        find.descendant(
            of: tip, matching: find.text('Disponible: clic para tomar')),
        findsOneWidget);

    // Clic: lo toma.
    await tester.tapAt(nodeOnScreen(tester, nc));
    await tester.pump();
    expect(c.view!.me!.profile.tree.last, nc);
    expect(
        _points(1), findsOneWidget);
    expect(find.descendant(of: tip, matching: find.text('Tomado')),
        findsOneWidget);
    expect(_painter(tester).route, isEmpty);

    // Salir del lienzo: se va el tooltip.
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.byKey(const ValueKey('tree-tooltip')), findsNothing);
  });

  testWidgets('camino en un clic: confirmar "Tomar N nodos por N puntos"',
      (tester) async {
    final c = await _pumpTree(
        tester, PlayerProfile(name: 'Leo', classId: 'tirador', level: 9));
    final route = treeRules.pathTo(
        'tirador', PlayerPassiveProgress.empty, 'precision_k')!;
    expect(route.length, 7);
    // Clic en un nodo lejano: fija el tooltip con TOMAR CAMINO (sin
    // TOMAR NODO, que no conecta).
    await tapNode(tester, 'precision_k');
    expect(find.byKey(const ValueKey('tree-take')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tree-take-path')));
    await tester.pumpAndSettle();
    expect(find.text('Tomar 7 nodos por 7 puntos'), findsWidgets);
    expect(find.byKey(const ValueKey('pick-path-mark')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pick-path-take')));
    await tester.pumpAndSettle();
    expect(c.view!.me!.profile.tree, route);
  });

  testWidgets('hito del nivel 10: keystones marcadas, puntos aparte, elegir',
      (tester) async {
    final c = await _pumpTree(
        tester, PlayerProfile(name: 'Ana', classId: 'maga', level: 10));
    final options = treeRules.milestoneOptions('maga', 10);
    expect(find.byKey(const ValueKey('milestone-banner-10')), findsOneWidget);
    expect(find.text('HITO DEL NIVEL 10'), findsOneWidget);
    expect(
        find.text('Elegí una keystone. El camino hasta ella se toma solo '
            'y es gratis.'),
        findsOneWidget);
    expect(find.textContaining('puntos de hito'), findsNothing);
    expect(find.textContaining('te damos'), findsNothing);
    expect(find.textContaining('ELEGIR'), findsNothing);
    final name = kPassiveTree.nodes[options[1]]!.name;
    final card = find.byKey(ValueKey('milestone-pick-${options[1]}'));
    expect(find.descendant(of: card, matching: find.text(name)),
        findsOneWidget);
    // Efecto completo, sin cortar.
    for (final e in passiveEffectsText(kPassiveTree.nodes[options[1]]!)) {
      final body =
          e.startsWith('$name: ') ? e.substring(name.length + 2) : e;
      final t = tester.widget<Text>(
          find.descendant(of: card, matching: find.text(retroText(body))));
      expect(t.maxLines, isNull);
      expect(t.overflow, isNot(TextOverflow.ellipsis));
    }
    // Las keystones elegibles se resaltan en el árbol.
    expect(_painter(tester).hits, containsAll(options));
    // Pasar el mouse por la tarjeta: resalta su camino y centra el visor.
    final mouse = await _mouse(tester);
    final before = nodeOnScreen(tester, options[2]);
    await mouse.moveTo(tester.getCenter(find.byKey(
        ValueKey('milestone-pick-${options[2]}'))));
    await tester.pump();
    expect(_painter(tester).route, contains(options[2]));
    final vp = tester.getRect(find.byKey(const ValueKey('tree-viewport')));
    final after = nodeOnScreen(tester, options[2]);
    expect(vp.contains(after), isTrue);
    expect(after, isNot(before));
    // La columna del hito va DENTRO del visor, pegada a la derecha.
    final col =
        tester.getRect(find.byKey(const ValueKey('milestone-banner-10')));
    expect(vp.inflate(1).contains(col.topLeft), isTrue);
    expect(vp.inflate(1).contains(col.bottomRight), isTrue);
    expect((vp.right - col.right).abs(), lessThan(3));
    expect(col.width, lessThan(vp.width / 2));
    // Todo el camino resaltado (y la keystone) cae a la izquierda de la
    // columna, nunca debajo.
    for (final id in _painter(tester).route) {
      final o = nodeOnScreen(tester, id);
      expect(o.dx, lessThan(col.left), reason: id);
      expect(vp.contains(o), isTrue, reason: id);
    }
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    // Primer clic: se ve el camino; segundo: se elige.
    await tapVisible(tester, card);
    expect(_painter(tester).route, hasLength(7));
    expect(find.text('Clic de nuevo para confirmar'), findsOneWidget);
    await tapVisible(tester, card);
    await tester.pump();
    final p = c.view!.me!.profile;
    expect(p.milestone10, options[1]);
    expect(p.tree.last, options[1]);
    // Gratis: los 7 nodos del camino no gastan los puntos libres.
    expect(p.tree, hasLength(7));
    expect(_points(9), findsOneWidget);
    expect(find.byKey(const ValueKey('milestone-banner-10')), findsNothing);
    expect(find.byKey(const ValueKey('tree-locked')), findsNothing);
    // La keystone queda marcada como hito.
    await tapNode(tester, options[1]);
    expect(find.byKey(const ValueKey('tree-milestone-mark')), findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 1.6]) {
    testWidgets('hito: opciones como botones, PENDIENTE, sin desbordes '
        '(texto x$scale)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final handle = tester.ensureSemantics();
      await _pumpTree(
          tester,
          PlayerProfile(
              name: 'Ana',
              classId: 'maga',
              level: 20,
              milestone10: treeRules.milestoneOptions('maga', 10).first));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('milestone-pending')), findsOneWidget);
      for (final id in treeRules.milestoneOptions('maga', 20)) {
        final pick = find.byKey(ValueKey('milestone-pick-$id'));
        expect(tester.widget(pick), isA<DsButton>());
        expect(
            tester.getSemantics(find
                .descendant(of: pick, matching: find.byType(OutlinedButton))
                .first),
            isSemantics(isButton: true, isEnabled: true, hasTapAction: true));
      }
      handle.dispose();
    });
  }

  testWidgets('hito pendiente: no se toman nodos hasta elegirlo',
      (tester) async {
    final c = await _pumpTree(
        tester, PlayerProfile(name: 'Ana', classId: 'maga', level: 10));
    expect(find.text('Primero elegí tu hito'), findsOneWidget);
    final near = kPassiveTree.nodes['s_mag']!.links.first;
    await tapNode(tester, near);
    expect(c.view!.me!.profile.tree, isEmpty);
    final take =
        tester.widget<DsButton>(find.byKey(const ValueKey('tree-take')));
    expect(take.onPressed, isNull);
    expect(take.tooltip, 'Primero elegí tu hito');
    // Elegir el hito libera el árbol.
    final options = treeRules.milestoneOptions('maga', 10);
    final card = find.byKey(ValueKey('milestone-pick-${options.first}'));
    await tapVisible(tester, card);
    await tapVisible(tester, card);
    await tester.pump();
    expect(c.view!.me!.profile.milestone10, options.first);
    expect(find.text('Primero elegí tu hito'), findsNothing);
    final free = kPassiveTree.nodes['s_mag']!.links
        .firstWhere((l) => !c.view!.me!.profile.tree.contains(l));
    await tapNode(tester, free);
    expect(c.view!.me!.profile.tree.last, free);
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

  testWidgets('árbol v6: tooltip de un notable del anillo exterior',
      (tester) async {
    await _pumpTree(
        tester,
        PlayerProfile(
            name: 'Ana', classId: 'maga', level: 50, mastery: 20));
    expect(_points(69),
        findsOneWidget);
    final mouse = await _mouse(tester);
    await mouse.moveTo(nodeOnScreen(tester, 'marea_nb'));
    await tester.pump();
    final tip = find.byKey(const ValueKey('tree-tooltip'));
    expect(find.descendant(of: tip, matching: find.text('Ahogo')),
        findsOneWidget);
    expect(
        find.descendant(
            of: tip, matching: find.textContaining('NOTABLE · Cluster Marea')),
        findsOneWidget);
    expect(
        find.descendant(
            of: tip, matching: find.textContaining('+20% de daño contra')),
        findsOneWidget);
    // Un chico nuevo también dice su efecto (no es un stat pelado).
    await mouse.moveTo(nodeOnScreen(tester, 'marea_m1'));
    await tester.pump();
    expect(
        find.descendant(
            of: tip, matching: find.textContaining('contra enemigos Mojados')),
        findsOneWidget);
  });

  testWidgets('rendimiento: mover el mouse no vuelve a grabar la capa fija',
      (tester) async {
    await _pumpTree(
        tester, PlayerProfile(name: 'Leo', classId: 'tirador', level: 30));
    await tester.tap(find.byKey(const ValueKey('tree-fit')));
    await tester.pump();
    final builds = PassiveTreePainter.baseBuilds;
    final mouse = await _mouse(tester);
    final ids = kPassiveTree.nodes.keys.toList();
    for (var i = 0; i < ids.length; i += 20) {
      await mouse.moveTo(nodeOnScreen(tester, ids[i]));
      await tester.pump();
    }
    expect(PassiveTreePainter.baseBuilds, builds,
        reason: 'el hover solo redibuja el resaltado');
    // Buscar tampoco.
    await tester.enterText(find.byKey(const ValueKey('tree-search')), 'mojad');
    await tester.pump();
    expect(_painter(tester).hits.length, greaterThan(10));
    expect(PassiveTreePainter.baseBuilds, builds);

    // Pintar el árbol entero (~600 nodos) con la capa ya grabada es
    // barato: 200 cuadros con resaltado en menos de 1 s (holgado).
    final painter = _painter(tester);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 200; i++) {
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), const Size.square(PassiveTreeView.size));
      rec.endRecording().dispose();
    }
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(PassiveTreePainter.baseBuilds, builds);
  });

  testWidgets('TODO: cada nodo (con su radio) entra en el visor visible',
      (tester) async {
    await _pumpTree(tester,
        PlayerProfile(name: 'Ana', classId: 'maga', level: 50, mastery: 20,
            milestone10: treeRules.milestoneOptions('maga', 10).first,
            milestone20: treeRules.milestoneOptions('maga', 20).first));
    await tapVisible(tester, find.byKey(const ValueKey('tree-fit')));
    final rect = tester.getRect(find.byKey(const ValueKey('tree-viewport')));
    // El visor entero se ve dentro del panel: termina antes del botón de
    // cerrar y dentro de la ventana de 1280×720.
    expect(rect.bottom,
        lessThanOrEqualTo(tester.getRect(find.text('CERRAR [ESC]')).top));
    expect(rect.top, greaterThan(0));
    expect(rect.height, greaterThan(330), reason: 'más alto que antes');
    final box = tester
        .renderObject<RenderBox>(find.byKey(const ValueKey('tree-canvas')));
    for (final n in kPassiveTree.nodes.values) {
      final c = box.localToGlobal(PassiveTreeView.nodeCenter(n));
      final r = (box.localToGlobal(PassiveTreeView.nodeCenter(n) +
                  Offset(PassiveTreeView.nodeRadius(n, start: false), 0)) -
              c)
          .dx;
      final node = Rect.fromCircle(center: c, radius: r);
      expect(rect.contains(node.topLeft) && rect.contains(node.bottomRight),
          isTrue,
          reason: n.id);
    }
  });

  testWidgets('disposición: barra de una fila, leyenda en una línea, sin '
      'panel fijo; tooltip fijado con Esc', (tester) async {
    await _pumpTree(
        tester, PlayerProfile(name: 'Leo', classId: 'tirador', level: 5));
    // Sin el párrafo general ni la leyenda grande.
    expect(find.textContaining('Pasa el mouse'), findsNothing);
    expect(find.textContaining('Cada cluster se bifurca'), findsNothing);
    expect(find.textContaining('Borde dorado'), findsNothing);
    // La leyenda: una fila de una línea abajo del visor.
    final legend = find.byKey(const ValueKey('tree-legend'));
    final vp = tester.getRect(find.byKey(const ValueKey('tree-viewport')));
    final lr = tester.getRect(legend);
    expect(lr.top, greaterThanOrEqualTo(vp.bottom));
    expect(lr.height, lessThan(24));
    for (final w in ['Inicio', 'Tomado', 'Keystone', 'Disponible', 'Bloqueado',
      'Búsqueda']) {
      expect(find.descendant(of: legend, matching: find.text(retroText(w))),
          findsOneWidget, reason: w);
    }
    // Barra de arriba: puntos y botones en la misma fila.
    final pts = tester.getRect(find.byKey(const ValueKey('tree-points')));
    final fit = tester.getRect(find.byKey(const ValueKey('tree-fit')));
    expect((pts.center.dy - fit.center.dy).abs(), lessThan(12));
    expect(pts.bottom, lessThanOrEqualTo(vp.top));
    // El visor ocupa casi todo el ancho del panel.
    expect(vp.width, greaterThan(900));

    // Un nodo que no conecta: sin TOMAR NODO, con TOMAR CAMINO; Esc
    // suelta el tooltip.
    await tapNode(tester, 'precision_k');
    expect(find.byKey(const ValueKey('tree-info')), findsOneWidget);
    expect(find.byKey(const ValueKey('tree-take')), findsNothing);
    expect(find.byKey(const ValueKey('tree-take-path')), findsOneWidget);
    // El tooltip no tapa el nodo.
    final tip = tester.getRect(find.byKey(const ValueKey('tree-tooltip')));
    expect(tip.contains(nodeOnScreen(tester, 'precision_k')), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('tree-info')), findsNothing);
  });

  testWidgets('quitar nodo: clic en tomado pide confirmar, QUITAR y DESHACER',
      (tester) async {
    final full = treeRules.pathTo(
        'tirador', PlayerPassiveProgress.empty, 'precision_k')!;
    final tree = full.sublist(0, 3);
    final c = await _pumpTree(
        tester,
        PlayerProfile(
            name: 'Leo', classId: 'tirador', level: 6, tree: tree));
    List<String> now() => c.view!.me!.profile.tree;
    // Intermedio: el motivo y solo Cancelar.
    await tapNode(tester, tree[1]);
    expect(find.text(retroText('Otros nodos dependen de este')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('tree-untake')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tree-untake-cancel')));
    await tester.pump();
    expect(now(), tree);
    // Hoja: Cancelar no cambia nada; QUITAR reembolsa.
    final leaf = tree.last;
    final name = kPassiveTree.nodes[leaf]!.name;
    await tapNode(tester, leaf);
    expect(find.text(retroText('¿Quitar $name? Te devuelve 1 punto')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tree-untake-cancel')));
    await tester.pump();
    expect(now(), tree);
    expect(find.byKey(const ValueKey('tree-info')), findsNothing);
    await tapNode(tester, leaf);
    await tester.tap(find.byKey(const ValueKey('tree-untake')));
    await tester.pump();
    expect(now(), tree.take(2));
    // DESHACER lo vuelve a tomar.
    await tester.tap(find.byKey(const ValueKey('tree-undo')));
    await tester.pump();
    expect(now(), tree);
    // Clic derecho: atajo directo.
    await tester.tapAt(nodeOnScreen(tester, leaf),
        buttons: kSecondaryButton);
    await tester.pump();
    expect(now(), tree.take(2));
  });
}
