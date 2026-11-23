// Editor de animaciones: qué se está animando (docs/specs/game_editor.md
// § 7.7): filas por elemento y propiedad, dónde cae un key nuevo, antes
// y después en el inspector, recuadro de selección y arrastre.
import 'dart:ui';

import 'package:echos_del_tiempo/core/fx/fx_catalog.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/fx_editor_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/fx_editor_selection.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_bridge.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_player.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/animations_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _yaml = '''
schema: 1
id: test_fx
category: skill
name: Prueba
duration: 1000
targets: single
tracks:
  - type: sprite
    keys:
      - { t: 0, scale: 1, dx: 0, anchor: target }
      - { t: 400, scale: 2, dx: 10, ease: linear }
  - type: shake
    fire:
      - { t: 300, amp: 3, ms: 120 }
  - type: dim
    keys:
      - { t: 0, v: 0 }
      - { t: 500, v: 0.6 }
''';

FxEditorController _controller() {
  final cat = FxCatalog.fromFiles(
      'fx:\n  test_fx: fx/test_fx.fx.yaml\n', const {'fx/test_fx.fx.yaml': _yaml},
      legacy: const LegacyFxAdapter());
  final c = FxEditorController(catalog: cat, overrides: null);
  c.select('test_fx');
  return c;
}

void main() {
  test('una fila por elemento y propiedad, con nombre legible', () {
    final c = _controller();
    final t = c.edit!;
    final rows = fxRowsOf(t);
    expect([for (final r in rows) fxRowLabel(t, r)], [
      'Sprite · Escala',
      'Sprite · Posición X',
      'Sprite · Ancla',
      'Sacudida · Disparos',
      'Oscurecido · Valor',
    ]);
    final scale = rows.first;
    expect(fxRowShows(scale, t.tracks[0].keys[1], fire: false), isTrue);
    expect(fxRowShows(rows[3], t.tracks[1].fires[0], fire: true), isTrue);
    expect(fxRowShows(scale, t.tracks[1].fires[0], fire: true), isFalse);
  });

  test('agregar un key dice dónde cae', () {
    final c = _controller();
    // Editable: los datos en memoria no son legacy.
    expect(c.readOnly, isFalse);
    c.addKey(0, 703, field: 'scale');
    expect(c.addedLabel, 'Key en 0.70 s · Sprite · Escala');
    expect(c.selectedField, 'scale');
    c.addKey(1, 801);
    expect(c.addedLabel, 'Disparo en 0.80 s · Sacudida · Disparos');
  });

  test('inspector: antes y después, qué está keyeado y qué cambia', () {
    final c = _controller();
    final ch = fxKeyChanges(c.edit!, (track: 0, fire: false, index: 1));
    final by = {for (final x in ch) x.field: x};
    expect(by['scale']!.before, 1);
    expect(by['scale']!.after, 2);
    expect(by['scale']!.changed, isTrue);
    expect(by['anchor']!.keyed, isFalse, reason: 'sigue del key anterior');
    expect(by['anchor']!.changed, isFalse);
    // Editar un valor se ve al instante en el antes/después.
    c.selectKey((track: 0, fire: false, index: 1));
    c.setKeyField(c.selectedKey!, 'scale', 1);
    final again = fxKeyChanges(c.edit!, c.selectedKey!);
    expect(again.firstWhere((x) => x.field == 'scale').changed, isFalse);
  });

  test('recuadro de selección: lugar, manijas y pantalla completa', () {
    final c = _controller();
    final t = c.edit!;
    const st = FxStage(
        caster: Offset(62, 104),
        targets: [Offset(176, 94)],
        color: Color(0xFFFFFFFF),
        element: FxElement.arcane);
    const world = Rect.fromLTWH(0, 0, 240, 135);
    final at0 = fxSelectionBox(t, 0, 0, st, world);
    expect(at0.screen, isFalse);
    expect(at0.canMove, isTrue);
    expect(at0.canScale, isTrue);
    expect(at0.rect.width, kFxSelectionBase);
    expect(at0.rect.center.dx, 176);
    final at400 = fxSelectionBox(t, 0, 400, st, world);
    expect(at400.rect.width, kFxSelectionBase * 2);
    expect(at400.rect.center.dx, 186);
    final dim = fxSelectionBox(t, 2, 0, st, world);
    expect(dim.screen, isTrue);
    expect(dim.canMove, isFalse);
  });

  test('arrastrar en la vista previa mueve el key: un solo deshacer', () {
    final c = _controller();
    c.selectKey((track: 0, fire: false, index: 1));
    c.moveSelected(3, 0);
    c.moveSelected(2, -4, record: false);
    final k = c.keyOf(c.selectedKey!)!;
    expect(k.n('dx'), 15);
    expect(k.n('dy'), -4);
    c.undo();
    expect(c.keyOf((track: 0, fire: false, index: 1))!.n('dx'), 10);
  });

  test('piel de cebolla: keys vecinos del elemento elegido', () {
    final c = _controller();
    expect(fxNeighborKeys(c.edit!, 0, 200), (0, 400));
    expect(fxNeighborKeys(c.edit!, 0, 400), (0, null));
    c.setOnion(true);
    expect(c.onion, isTrue);
  });

  testWidgets('la página muestra qué se edita y el antes/después', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _controller();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AnimationsPage(c: c, ticking: false))));
    c.selectKey((track: 0, fire: false, index: 1), field: 'scale');
    await tester.pump();
    expect(find.text('Key en 0.40 s · Sprite · Escala'), findsOneWidget);
    expect(find.byKey(const ValueKey('fx-change-scale')), findsOneWidget);
    expect(find.textContaining('Editando: Sprite · Escala'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fx-add-key')));
    await tester.pump();
    expect(find.byKey(const ValueKey('fx-added')), findsOneWidget);
  });
}
