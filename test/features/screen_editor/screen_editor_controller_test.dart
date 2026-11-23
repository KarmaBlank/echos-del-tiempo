import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_layout.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_layout_catalog.dart';
import 'package:echos_del_tiempo/features/screen_editor/presentation/screen_editor_controller.dart';
import 'package:echos_del_tiempo/features/screen_editor/presentation/screen_editor_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Editor de pantallas (docs/specs/screen_editor.md § 5).
void main() {
  ScreenEditorController make(Map<String, String> written) {
    final cat = ScreenLayoutCatalog()
      ..put(
          'title',
          const ScreenLayout(screen: 'title', elements: [
            ScreenElement(
                id: 'fondo', component: 'panel', x: 0, y: 0, w: 640, h: 360),
          ]));
    return ScreenEditorController(
        catalog: cat, writer: (s, json) async => written[s] = json);
  }

  test('agregar, mover con imán, orden Z, duplicar, borrar y deshacer', () {
    final c = make({});
    c.add('button');
    final id = c.selectedId!;
    final b = c.layout.byId(id)!;
    expect(b.action, isNull);
    expect(b.focusOrder, 1);
    c.setRect(id, const Rect.fromLTWH(13, 21, 203, 37));
    final m = c.layout.byId(id)!;
    expect([m.x, m.y, m.w, m.h], [16, 24, 200, 40]);
    c.reorder(id, -1);
    expect(c.layout.elements.first.id, id);
    c.duplicate(id);
    expect(c.layout.elements, hasLength(3));
    c.delete(c.selectedId!);
    expect(c.layout.elements, hasLength(2));
    c.undo();
    expect(c.layout.elements, hasLength(3));
    expect(c.dirty, isTrue);
  });

  test('grilla de datos: toma la primera fuente y muestra el ejemplo', () {
    final c = make({});
    c.add('data_grid');
    final g = c.selected!;
    expect(g.dataSource, 'personajes');
    c.update(g.copyWith(dataSource: 'semillasAyudante'));
    expect(c.sampleFor(c.selected!).map((e) => e.label),
        contains('Semilla de trigo'));
  });

  test('VERIFICAR + APLICAR, GUARDAR escribe el JSON', () async {
    final written = <String, String>{};
    final c = make(written);
    c.add('button'); // sin acción → deshabilitado
    c.verify();
    expect(c.issues, isNotEmpty);
    await c.save();
    expect(ScreenLayout.parse(written['title']!), c.layout);
    expect(c.catalog.get('title'), c.layout);
    expect(c.dirty, isFalse);
  });

  testWidgets('la página dibuja paleta, lienzo e inspector', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = make({});
    await tester.pumpWidget(MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(body: ScreenEditorPage(c: c))));
    await tester.tap(find.byKey(const ValueKey('screen-palette-text')));
    await tester.pump();
    expect(c.selected?.component, 'text');
    expect(find.byKey(const ValueKey('screen-text-field')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('screen-text-field')), 'Hola');
    await tester.pump();
    expect(c.selected!.text, 'Hola');
    // Arrastrar mueve con imán a la grilla.
    final before = c.selected!.x;
    await tester.drag(
        find.byKey(ValueKey('screen-el-${c.selectedId}')), const Offset(60, 0));
    await tester.pump();
    expect(c.selected!.x, isNot(before));
    expect(c.selected!.x % 8, 0);
    await tester.tap(find.byKey(const ValueKey('screen-editor-verify')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
