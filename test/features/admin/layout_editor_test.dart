// Editor → LAYOUT (docs/specs/editor_layout.md § 3 y § 4 "Editor"):
// mover `stash.actions` a `header` y `stash.actions.pick` a `right` →
// valida, se guarda, recarga en caliente, deshacer vuelve. Overrides en
// una carpeta temporal (nunca %APPDATA% ni el repo).
import 'dart:io';

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/core/layout/layout_catalog.dart';
import 'package:echos_del_tiempo/core/layout/layout_doc.dart';
import 'package:echos_del_tiempo/core/layout/layout_overrides_io.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/layout_editor_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/layout_page.dart';
import 'package:echos_del_tiempo/features/characters/presentation/stash_layout.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_layout.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import 'fake_admin_host.dart';

void main() {
  late Directory tmp;
  late LocalLayoutOverrides overrides;
  late LayoutCatalog catalog;
  late LayoutEditorController c;

  Future<void> setUpEditor(WidgetTester tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tmp = Directory.systemTemp.createTempSync('ecos_layout_editor_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final repo = '${tmp.path}/repo';
    Directory('$repo/assets/layouts').createSync(recursive: true);
    for (final f in [
      'layout_manifest.yaml',
      'stash.layout.yaml',
      'inventory.layout.yaml'
    ]) {
      File('assets/layouts/$f').copySync('$repo/assets/layouts/$f');
    }
    overrides = LocalLayoutOverrides('${tmp.path}/overrides');
    catalog = LayoutCatalog(overrides: overrides);
    await tester.runAsync(catalog.load);
    c = LayoutEditorController(
        catalog: catalog, overrides: overrides, repoPath: repo);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(
          backgroundColor: DsColors.background, body: LayoutPage(c: c)),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('galería: el ALIJO con datos de ejemplo y el resto sin vista '
      'previa', (tester) async {
    await setUpEditor(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('stash-move-all')), findsOneWidget);
    expect(find.text('sin vista previa'), findsWidgets);
    expect(c.staticIssues, isEmpty);
    expect(c.geometry.where((i) => i.error), isEmpty,
        reason: c.geometry.join('\n'));
    await tester.tap(find.byKey(const ValueKey('layout-screen-craft.fuse')));
    await tester.pump();
    expect(find.textContaining('SIN VISTA PREVIA'), findsOneWidget);
  });

  testWidgets('INVENTARIO: datos de ejemplo; mover un grupo y un botón '
      'suelto valida y se ve', (tester) async {
    await setUpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('layout-screen-inventory')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('inv-clean')), findsOneWidget);
    expect(find.byKey(const ValueKey('inv-cell-0')), findsOneWidget);
    expect(c.staticIssues, isEmpty);
    expect(c.geometry.where((i) => i.error), isEmpty,
        reason: c.geometry.join('\n'));
    // El grupo ORDENAR / LIMPIAR / ALIJO abajo y ALIJO suelto arriba.
    expect(c.move(InventoryTabLayout.tools, 'foot', 0), isTrue);
    expect(c.move(InventoryTabLayout.stash, 'head', 1), isTrue);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    final l = c.doc!.resolve(null);
    expect(l.containerOf(InventoryTabLayout.tools), 'foot');
    expect(l.containerOf(InventoryTabLayout.stash), 'head');
    expect(c.staticIssues.where((i) => i.error), isEmpty);
    expect(c.geometry.where((i) => i.error), isEmpty,
        reason: c.geometry.join('\n'));
    expect(find.byKey(const ValueKey('inv-stash')), findsOneWidget);
    // La grilla es fija.
    expect(c.move(InventoryTabLayout.grid, 'foot', 0), isFalse);
  });

  testWidgets('seleccionar, subir al grupo, mover, validar, guardar, '
      'recargar y deshacer', (tester) async {
    await setUpEditor(tester);
    // Clic = el más interno; clic de nuevo = el grupo; Esc = suelta.
    await tester.tap(find.byKey(const ValueKey('stash-move-all')),
        warnIfMissed: false);
    await tester.pump();
    expect(c.selected, StashLayout.moveAll);
    await tester.tap(find.byKey(const ValueKey('stash-move-all')),
        warnIfMissed: false);
    await tester.pump();
    expect(c.selected, StashLayout.actions);

    // Tab: la fila entera pasa a la siguiente región permitida.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(c.doc!.resolve(null).of('right'), contains(StashLayout.actions));
    // Y se la lleva al encabezado.
    expect(c.move(StashLayout.actions, 'header', 0), isTrue);
    await tester.pump();
    expect(c.doc!.resolve(null).of('header'), [StashLayout.actions]);

    // Arrastrar ELEGIR sobre el buscador del alijo (región right).
    final from = tester.getCenter(find.byKey(const ValueKey('stash-pick')));
    final to = tester.getCenter(find.byKey(const ValueKey('stash-search-stash')));
    final g = await tester.startGesture(from);
    await tester.pump();
    await g.moveBy(const Offset(4, 4));
    await tester.pump();
    await g.moveTo(to + const Offset(0, 6));
    await tester.pump();
    await g.up();
    await tester.pump();
    await tester.pump();
    expect(c.doc!.resolve(null).containerOf(StashLayout.pick), 'right');
    expect(c.doc!.resolve(null).of(StashLayout.actions),
        [StashLayout.moveAll, StashLayout.transfer]);
    expect(tester.takeException(), isNull);
    expect(c.staticIssues.where((i) => i.error), isEmpty);

    // Flechas: reordena dentro de la región.
    final before = c.doc!.resolve(null).of('right').indexOf(StashLayout.pick);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(c.doc!.resolve(null).of('right').indexOf(StashLayout.pick),
        before - 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    // Un fijo no se mueve (candado).
    c.select(StashLayout.stashGrid);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(c.doc!.resolve(null).containerOf(StashLayout.stashGrid), 'right');

    // Propiedades por corte: hereda / sobrescrito.
    c
      ..select(StashLayout.actions)
      ..setEditBreakpoint(LayoutBreakpoint.narrow)
      ..setRule(StashLayout.actions, (r) => r.copyWith(axis: LayoutAxis.column));
    await tester.pump();
    expect(find.text('SOBRESCRITO'), findsWidgets);
    c.setEditBreakpoint(null);

    // Guardar (override) y recarga en caliente.
    final moved = c.doc!;
    await tester.runAsync(c.save);
    await tester.pump();
    expect(File('${tmp.path}/overrides/layouts/stash.layout.yaml').existsSync(),
        isTrue);
    expect(catalog.docFor(StashLayout.spec).sameAs(moved), isTrue);
    expect(catalog.sourceOf('stash'), 'override');

    // Deshacer vuelve atrás; rehacer vuelve a aplicar.
    while (c.canUndo) {
      c.undo();
    }
    expect(c.doc!.sameAs(StashLayout.spec.defaults), isTrue);
    c
      ..redo()
      ..redo();
    expect(c.doc!.resolve(null).of('header'), [StashLayout.actions]);

    // Publicar al repo: copia y borra el override.
    while (c.canRedo) {
      c.redo();
    }
    await tester.runAsync(c.publish);
    expect(File('${tmp.path}/overrides/layouts/stash.layout.yaml').existsSync(),
        isFalse);
    final pub = File('${tmp.path}/repo/assets/layouts/stash.layout.yaml')
        .readAsStringSync();
    expect(LayoutDoc.parse(pub).sameAs(moved), isTrue);
  });

  testWidgets('un layout con errores no se guarda', (tester) async {
    await setUpEditor(tester);
    c.setRule(StashLayout.moveAll, (r) => r.copyWith(hide: true));
    expect(c.hasErrors, isTrue);
    expect(await tester.runAsync(c.save), isFalse);
    expect(File('${tmp.path}/overrides/layouts/stash.layout.yaml').existsSync(),
        isFalse);
  });

  testWidgets('el Editor muestra la pestaña LAYOUT', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ctl = AdminController(host: FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    }));
    await tester.runAsync(ctl.load);
    final l = LayoutEditorController(catalog: LayoutCatalog());
    await tester.pumpWidget(AdminApp(
        controller: ctl, layouts: l, initialArea: EditorArea.layout));
    await tester.pump();
    expect(find.text('LAYOUT'), findsWidgets);
    expect(find.byKey(const ValueKey('layout-validate-all')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
