// PERSONAJE por datos (docs/specs/editor_layout.md
// § 2.5.2, § 6): en toda la matriz de tamaños × textos, con el layout por
// defecto y con un grupo y un botón suelto movidos, sin desbordes, nada
// fuera de la pantalla a lo ancho, sin solapes entre hermanos, objetivos
// de clic ≥ 32 y orden de foco = orden visual en cada región.
import 'package:echos_del_tiempo/app/design/ds_layout_host.dart';
import 'package:echos_del_tiempo/core/layout/layout_doc.dart';
import 'package:echos_del_tiempo/core/layout/layout_spec.dart';
import 'package:echos_del_tiempo/core/layout/layout_validator.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_layout.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../inventory/loot_fixtures.dart';
import '../panel_test_harness.dart';

/// Solo mide: una clave por slot.
class _Measure extends DsLayoutHooks {
  final keys = <String, GlobalKey>{};
  final bps = <LayoutBreakpoint>[];
  @override
  void breakpoint(LayoutBreakpoint b) => bps.add(b);
  @override
  Widget slot(BuildContext context, String id, String container, int index,
          Widget child) =>
      KeyedSubtree(key: keys.putIfAbsent(id, GlobalKey.new), child: child);
  @override
  Widget container(BuildContext context, String id, LayoutAxis axis,
          List<String> children, Widget child) =>
      child;
}

typedef _Build = Widget Function(SessionView v, SessionController c,
    LayoutDoc doc, DsLayoutHooks hooks, Key key);

void main() {
  final screens = <String, (LayoutScreenSpec, LayoutDoc, _Build, List<String>)>{
    'PERSONAJE': (
      CharacterLayout.spec,
      CharacterLayout.spec.defaults
          .move(CharacterLayout.attrActions, 'actions', 0)
          .move(CharacterLayout.confirm, 'toolbar', 0),
      (v, c, doc, hooks, key) => CharacterPanel(
          key: key, view: v, controller: c, layout: doc, layoutHooks: hooks),
      const ['respec', 'undo-points', 'confirm-points', 'attr-points'],
    ),
  };
  const sizes = [
    Size(1280, 720),
    Size(1920, 1080),
    Size(2560, 1440),
    Size(800, 600),
    Size(600, 900),
  ];
  const texts = [TextSize.normal, TextSize.huge, TextSize.enormous];
  // Siempre en ATRIBUTOS (la barra) con 1 punto repartido.
  for (final MapEntry(key: screen, value: (spec, moved, build, keys))
      in screens.entries) {
    final docs = {'por defecto': spec.defaults, 'grupo y botón movidos': moved};
    for (final MapEntry(key: name, value: doc) in docs.entries) {
      test('$screen $name valida (estático)', () {
        expect(
            LayoutValidator.validateStatic(doc, spec).where((i) => i.error),
            isEmpty);
      });
      for (final size in sizes) {
        testWidgets(
            '$screen $name ${size.width.toInt()}x${size.height.toInt()}: '
            'sin desbordes ni solapes en todos los textos', (tester) async {
          for (final t in texts) {
            final m = _Measure();
            await pumpPanel(tester,
                profile: lootWarrior().copyWith(points: 2),
                textSize: t,
                build: (v, c) =>
                    build(v, c, doc, m, ValueKey(t)));
            tester.view.physicalSize = size;
            await tester.pump();
            await tester.pump();
            final ex = tester.takeException();
            // Si algo desborda, dice qué (cadena de widgets).
            final over = [
              for (final r in tester.allRenderObjects)
                if (r.toStringShallow().contains('OVERFLOWING'))
                  '${r.debugCreator}'.split('←').take(12).join('←'),
            ];
            expect(ex, isNull, reason: '${t.name} ${over.join('\n')}');
            final root = tester.getRect(find.byKey(ValueKey(t)));
            LayoutRect rect(Rect r) =>
                LayoutRect(r.left, r.top, r.width, r.height);
            final rects = <String, LayoutRect>{
              for (final MapEntry(:key, :value) in m.keys.entries)
                if (value.currentContext != null)
                  key: rect(tester.getRect(find.byKey(value))),
            };
            final res = doc.resolve(m.bps.isEmpty ? null : m.bps.last);
            final siblings = [
              for (final ids in res.children.values)
                [for (final id in ids) if (rects.containsKey(id)) id],
            ];
            final issues = LayoutValidator.validateGeometry(
              where: '${size.width.toInt()}x${size.height.toInt()} ${t.name}',
              viewport: LayoutRect(root.left, -1e9, root.width, 2e9),
              slots: rects,
              siblings: siblings,
              targets: {
                for (final MapEntry(:key, :value) in rects.entries)
                  if ((spec.slots[key]?.interactive ?? false) &&
                      !(spec.slots[key]?.group ?? false))
                    key: [value],
              },
              focusGroups: siblings,
            );
            expect(issues, isEmpty, reason: issues.join('\n'));
            for (final k in keys) {
              expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
            }
          }
        });
      }
    }
  }
}
