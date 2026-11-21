// INVENTARIO por datos (docs/specs/editor_layout.md § 2.5.2, § 4 "Widget"):
// en toda la matriz de tamaños × textos, con el layout por defecto y con
// un grupo y un botón suelto movidos, sin desbordes, nada fuera de la
// pestaña a lo ancho, sin solapes entre hermanos, objetivos de clic ≥ 32
// y orden de foco = orden visual en cada región.
import 'package:echos_del_tiempo/app/design/ds_layout_host.dart';
import 'package:echos_del_tiempo/core/layout/layout_doc.dart';
import 'package:echos_del_tiempo/core/layout/layout_validator.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_layout.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_tab.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
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

void main() {
  final spec = InventoryTabLayout.spec;
  final docs = {
    'por defecto': spec.defaults,
    'herramientas abajo y ALIJO arriba': spec.defaults
        .move(InventoryTabLayout.tools, 'foot', 0)
        .move(InventoryTabLayout.stash, 'head', 1),
  };
  const sizes = [
    Size(1280, 720),
    Size(1920, 1080),
    Size(2560, 1440),
    Size(800, 600),
    Size(600, 900),
  ];
  const texts = [TextSize.normal, TextSize.huge, TextSize.enormous];
  for (final MapEntry(key: name, value: doc) in docs.entries) {
    test('$name valida (estático)', () {
      expect(LayoutValidator.validateStatic(doc, spec).where((i) => i.error),
          isEmpty);
    });
    for (final size in sizes) {
      testWidgets(
          'inventario $name ${size.width.toInt()}x${size.height.toInt()}: sin '
          'desbordes ni solapes en todos los textos', (tester) async {
        var p = lootWarrior();
        for (final k in StackKind.values) {
          p = InventoryRules.withStack(p, k, 3);
        }
        for (final t in texts) {
          final m = _Measure();
          await pumpPanel(tester,
              profile: p,
              textSize: t,
              build: (v, c) => InventoryTab(
                  key: ValueKey(t),
                  shop: ShopContext(v, c),
                  layout: doc,
                  layoutHooks: m));
          tester.view.physicalSize = size;
          await tester.pump();
          await tester.pump();
          expect(tester.takeException(), isNull, reason: t.name);
          final tab = tester.getRect(find.byType(InventoryTab));
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
            viewport: LayoutRect(tab.left, -1e9, tab.width, 2e9),
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
          // Las claves de test se conservan (§ 4, riesgos).
          for (final k in [
            'inv-clean',
            'inv-stash',
            'inv-search',
            'inv-equipped',
            'inv-summary',
            'inv-cell-0',
          ]) {
            expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
          }
        }
      });
    }
  }
}
