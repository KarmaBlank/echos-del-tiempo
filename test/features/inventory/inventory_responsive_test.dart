// INVENTARIO responsivo (v0.12.0, panels.md § "Inventario"): en todas
// las resoluciones y tamaños de texto, nada se sale del panel a lo
// ancho (el alto puede desplazarse) y no hay desbordes.
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_tab.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

void main() {
  const sizes = [
    Size(1024, 600),
    Size(1280, 720),
    Size(1366, 768),
    Size(1750, 1040),
    Size(1920, 1080),
    Size(2560, 1440),
  ];
  const texts = [TextSize.normal, TextSize.large, TextSize.enormous];
  for (final size in sizes) {
    for (final t in texts) {
      testWidgets(
          'nada fuera del panel: ${size.width.toInt()}x'
          '${size.height.toInt()} texto ${t.name}', (tester) async {
        // Muchos materiales: todas las pilas, también las del Abismo.
        var p = lootWarrior();
        for (final k in StackKind.values) {
          p = InventoryRules.withStack(p, k, 3);
        }
        await pumpPanel(tester,
            profile: p,
            textSize: t,
            build: (v, c) => CharacterPanel(
                view: v, controller: c, initialTab: CharacterTab.inventory));
        tester.view.physicalSize = size;
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        final panel = tester.getRect(find.byType(InventoryTab));
        final keys = <String>[
          for (var i = 0; i < InventoryRules.cells; i++) 'inv-cell-$i',
          for (final k in StackKind.values) 'inv-stack-${k.token}',
          'inv-equipped',
          'inv-summary',
          'inv-clean',
          'inv-search',
        ];
        for (final k in keys) {
          final f = find.byKey(ValueKey(k));
          expect(f, findsOneWidget, reason: k);
          final r = tester.getRect(f);
          expect(r.left >= panel.left - 0.5 && r.right <= panel.right + 0.5,
              isTrue,
              reason: '$k $r fuera de $panel');
        }
        // Las casillas se ven enteras (no se recortan por el ancho).
        final c0 = tester.getRect(find.byKey(const ValueKey('inv-cell-0')));
        final cm = tester
            .getRect(find.byKey(const ValueKey('inv-stack-mat:esquirla')));
        expect(c0.width, greaterThan(10));
        expect(cm.width, greaterThan(10));
      });
    }
  }

  test('puntos de quiebre: ancho, medio y angosto', () {
    expect(inventoryLayout(1600, 800, stripWidth: 200).mode,
        InventoryLayoutMode.wide);
    expect(inventoryLayout(700, 800, stripWidth: 200).mode,
        InventoryLayoutMode.medium);
    expect(inventoryLayout(450, 800, stripWidth: 200).mode,
        InventoryLayoutMode.narrow);
    for (final w in <double>[300, 450, 700, 1000, 1600, 2500]) {
      final l = inventoryLayout(w, 900, stripWidth: 200);
      expect(InventoryTab.gridWidth * l.scale <= w, isTrue);
      expect(l.mainWidth <= w, isTrue);
    }
  });
}
