// El layout por defecto del INVENTARIO (assets/layouts/inventory.layout.yaml)
// reproduce exactamente la pestaña de antes de migrarla a datos
// (docs/specs/editor_layout.md § 4, "Golden"). Los PNG se generaron con
// el árbol manual previo a la migración; no regenerar salvo cambio
// visual deliberado:
//   flutter test --update-goldens test/features/inventory/inventory_layout_golden_test.dart
@Tags(['golden'])
library;

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
  const cases = {
    // Ancho: grilla a la izquierda, EQUIPADA y pilas al lado.
    'wide': (Size(1920, 1080), TextSize.normal),
    // Medio: EQUIPADA arriba, pilas abajo.
    'medium': (Size(1280, 720), TextSize.large),
    // Angosto: la franja arriba.
    'narrow': (Size(800, 900), TextSize.enormous),
  };
  for (final MapEntry(key: name, value: (size, text)) in cases.entries) {
    testWidgets('inventario por defecto == antes de migrar ($name)',
        (tester) async {
      var p = lootWarrior();
      for (final k in StackKind.values) {
        p = InventoryRules.withStack(p, k, 3);
      }
      await pumpPanel(tester,
          profile: p,
          textSize: text,
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.inventory));
      tester.view.physicalSize = size;
      await tester.pump();
      await tester.pump();
      await expectLater(find.byType(InventoryTab),
          matchesGoldenFile('goldens/inventory_default_$name.png'));
    });
  }
}
