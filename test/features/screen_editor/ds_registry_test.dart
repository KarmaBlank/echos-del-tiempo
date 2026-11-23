import 'package:echos_del_tiempo/app/design/registry/ds_registry.dart';
import 'package:echos_del_tiempo/app/design/registry/ds_screen_view.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_bindings.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Registro del sistema de diseño para el editor de pantallas
/// (docs/specs/screen_editor.md § 1).
void main() {
  final reg = DsRegistry.instance;

  test('hay componentes en los cuatro niveles, con ids únicos', () {
    for (final l in DsLevel.values) {
      expect(reg.byLevel(l), isNotEmpty, reason: l.label);
    }
    final ids = reg.all.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(reg['button']!.interactive, isTrue);
    expect(reg['data_grid']!.props, contains(DsProp.dataSource));
  });

  test('registrar un componente nuevo lo suma a la paleta; repetido falla',
      () {
    final r = DsRegistry();
    final spec = DsComponentSpec(
        id: 'nuevo',
        name: 'Nuevo',
        level: DsLevel.molecule,
        build: (_, __) => const SizedBox());
    r.register(spec);
    expect(r.byLevel(DsLevel.molecule).single.id, 'nuevo');
    expect(() => r.register(spec), throwsStateError);
  });

  testWidgets('cada componente se dibuja en cada variante', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final s in reg.all) {
      for (final v in [null, ...s.variants.map((v) => v.id)]) {
        final e = ScreenElement(
            id: 'e',
            component: s.id,
            variant: v,
            text: s.defaultText,
            x: 0,
            y: 0,
            w: s.defaultSize.width,
            h: s.defaultSize.height,
            dataSource: 'inventarioJugador',
            slot: 'personajes');
        await tester.pumpWidget(MaterialApp(
          theme: RetroTheme.build(),
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: s.defaultSize,
                child: Builder(
                    builder: (context) => buildScreenElement(context, e,
                        spec: titleBindings, preview: true)),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull, reason: '${s.id} / $v');
        // La grilla con datos muestra los ítems de ejemplo de la fuente.
        if (s.id == 'data_grid') {
          expect(find.text('Espada de bronce'), findsOneWidget);
        }
      }
    }
  });
}
