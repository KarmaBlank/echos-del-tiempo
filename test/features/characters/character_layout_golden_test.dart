// El layout por defecto de PERSONAJE (assets/layouts/character.layout.yaml)
// reproduce exactamente el panel de antes de migrarlo a datos
// (docs/specs/editor_layout.md § 4, "Golden"). Los PNG se generaron con
// el árbol manual previo a la migración; no regenerar salvo cambio
// visual deliberado:
//   flutter test --update-goldens test/features/characters/character_layout_golden_test.dart
@Tags(['golden'])
library;

import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../inventory/loot_fixtures.dart';
import '../panel_test_harness.dart';

void main() {
  const cases = {
    'wide': (Size(1920, 1080), TextSize.normal),
    'medium': (Size(1280, 720), TextSize.large),
    'narrow': (Size(800, 900), TextSize.enormous),
  };
  for (final MapEntry(key: name, value: (size, text)) in cases.entries) {
    testWidgets('PERSONAJE · ATRIBUTOS por defecto == antes de migrar ($name)',
        (tester) async {
      await pumpPanel(tester,
          profile: lootWarrior().copyWith(points: 2),
          textSize: text,
          build: (v, c) => CharacterPanel(view: v, controller: c));
      tester.view.physicalSize = size;
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('inc-fue')));
      await tester.pump();
      await expectLater(find.byType(CharacterPanel),
          matchesGoldenFile('goldens/character_attributes_$name.png'));
    });
  }
}
