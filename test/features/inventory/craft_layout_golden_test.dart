// El layout por defecto de FUSIÓN, FORJA y CONDENSAR
// (assets/layouts/craft.*.layout.yaml) reproduce exactamente las
// pantallas de antes de migrarlas a datos (docs/specs/editor_layout.md
// § 4, "Golden"). Los PNG se generaron con el árbol manual previo a la
// migración; no regenerar salvo cambio visual deliberado:
//   flutter test --update-goldens test/features/inventory/craft_layout_golden_test.dart
@Tags(['golden'])
library;

import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

void main() {
  const cases = {
    'wide': (Size(1920, 1080), TextSize.normal),
    'medium': (Size(1280, 720), TextSize.large),
    'narrow': (Size(800, 900), TextSize.enormous),
  };
  final screens = <String, (ArmoryTab, List<String>)>{
    'fuse': (ArmoryTab.fuse, const []),
    'forge': (ArmoryTab.forge, const []),
    'condense': (ArmoryTab.fuse, const ['bench-condense', 'condense-cristal-1']),
  };
  for (final MapEntry(key: screen, value: (tab, taps)) in screens.entries) {
    for (final MapEntry(key: name, value: (size, text)) in cases.entries) {
      testWidgets('$screen por defecto == antes de migrar ($name)',
          (tester) async {
        await pumpPanel(tester,
            profile: lootWarrior(
                materials: const {CraftMaterial.esquirla: 25},
                credits: 1000),
            textSize: text,
            build: (v, c) =>
                ArmoryPanel(view: v, controller: c, initialTab: tab));
        tester.view.physicalSize = size;
        await tester.pump();
        for (final k in taps) {
          await tapVisible(tester, find.byKey(ValueKey(k)));
        }
        await tester.pump();
        await expectLater(find.byType(ArmoryPanel),
            matchesGoldenFile('goldens/craft_${screen}_default_$name.png'));
      });
    }
  }
}
