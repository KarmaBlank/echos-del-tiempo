// FUSIÓN, FORJA y CONDENSAR por datos (docs/specs/editor_layout.md
// § 2.5.2, § 6): en toda la matriz de tamaños × textos, con el layout por
// defecto y con un grupo y un botón suelto movidos, sin desbordes, nada
// fuera de la pantalla a lo ancho, sin solapes entre hermanos, objetivos
// de clic ≥ 32 y orden de foco = orden visual en cada región.
import 'package:echos_del_tiempo/app/design/ds_layout_host.dart';
import 'package:echos_del_tiempo/core/layout/layout_doc.dart';
import 'package:echos_del_tiempo/core/layout/layout_spec.dart';
import 'package:echos_del_tiempo/core/layout/layout_validator.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/condense_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/craft_bench.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/craft_layout.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

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

typedef _Build = Widget Function(
    ShopContext shop, LayoutDoc doc, DsLayoutHooks hooks, Key key);

void main() {
  final screens = <String, (LayoutScreenSpec, LayoutDoc, _Build, List<String>)>{
    'FUSIÓN': (
      FuseLayout.spec,
      FuseLayout.spec.defaults
          .move(FuseLayout.actions, 'crumbs', 1)
          .move(FuseLayout.next, 'materials', 0),
      (shop, doc, hooks, key) =>
          CraftBench(key: key, shop: shop, layout: doc, layoutHooks: hooks),
      const ['bench-condense', 'bench-next', 'craft-materials'],
    ),
    'FORJA': (
      ForgeLayout.spec,
      ForgeLayout.spec.defaults
          .move(ForgeLayout.actions, 'detail', 0)
          .move(ForgeLayout.equip, 'footer', 0),
      (shop, doc, hooks, key) =>
          ForgeTab(key: key, shop: shop, layout: doc, layoutHooks: hooks),
      const ['forge-cap'],
    ),
    'CONDENSAR': (
      CondenseLayout.spec,
      CondenseLayout.spec.defaults
          .move(CondenseLayout.actions, 'head', 0)
          .move(CondenseLayout.cancel, 'confirm', 0),
      (shop, doc, hooks, key) => CondensePanel(
          key: key,
          shop: shop,
          onBack: () {},
          layout: doc,
          layoutHooks: hooks,
          initialPending: (CraftMaterial.cristal, 1)),
      const ['condense-go', 'condense-cancel', 'condense-back'],
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
                profile: lootWarrior(
                    materials: const {CraftMaterial.esquirla: 25},
                    credits: 1000),
                textSize: t,
                build: (v, c) =>
                    build(ShopContext(v, c), doc, m, ValueKey(t)));
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
