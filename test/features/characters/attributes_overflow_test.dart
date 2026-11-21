// ATRIBUTOS no desborda en ningún tamaño de ventana × texto (antes, a
// 800 de ancho con texto ENORME las filas de atributo desbordaban por
// sus anchos fijos).
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../inventory/loot_fixtures.dart';
import '../panel_test_harness.dart';

void main() {
  const sizes = [
    Size(1280, 720),
    Size(1920, 1080),
    Size(2560, 1440),
    Size(800, 600),
    Size(600, 900),
  ];
  for (final size in sizes) {
    testWidgets(
        'ATRIBUTOS ${size.width.toInt()}x${size.height.toInt()} sin desbordes',
        (tester) async {
      for (final t in [
        TextSize.normal,
        TextSize.large,
        TextSize.huge,
        TextSize.enormous
      ]) {
        tester.view.physicalSize = size;
        await pumpPanel(tester,
            profile: lootWarrior(),
            textSize: t,
            build: (v, c) =>
                CharacterPanel(key: ValueKey(t), view: v, controller: c));
        tester.view.physicalSize = size;
        await tester.pump();
        await tester.pump();
        final ex = tester.takeException();
        // Si algo desborda, dice qué (cadena de widgets).
        final over = [
          for (final r in tester.allRenderObjects)
            if (r.toStringShallow().contains('OVERFLOWING'))
              '${r.debugCreator}'.split('←').take(10).join('←'),
        ];
        expect(ex, isNull, reason: '${t.name} ${over.join('\n')}');
        expect(find.byKey(const ValueKey('inc-fue')), findsOneWidget);
      }
    });
  }
}
