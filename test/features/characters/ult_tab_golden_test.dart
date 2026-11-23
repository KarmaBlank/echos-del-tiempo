// Pestaña ULT de PERSONAJE con la tabla de 4 columnas (v0.32.5,
// docs/specs/panels.md § Pestaña ULT). Regenerar solo ante un cambio
// visual deliberado:
//   flutter test --update-goldens test/features/characters/ult_tab_golden_test.dart
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
  };
  for (final MapEntry(key: name, value: (size, text)) in cases.entries) {
    testWidgets('PERSONAJE · ULT en columnas ($name)', (tester) async {
      await pumpPanel(tester,
          profile: lootWarrior(),
          textSize: text,
          build: (v, c) => CharacterPanel(view: v, controller: c));
      tester.view.physicalSize = size;
      await tester.pump();
      final tab = CharacterTab.values.indexOf(CharacterTab.ults);
      await tester.ensureVisible(find.byKey(ValueKey('tab-$tab')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('tab-$tab')));
      await tester.pump(const Duration(milliseconds: 600));
      // Pausada: la imagen no depende del momento de la animación.
      await tester.tap(find.byKey(const ValueKey('ult-preview-play')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(CharacterPanel),
          matchesGoldenFile('goldens/ult_tab_$name.png'));
    });
  }
}
