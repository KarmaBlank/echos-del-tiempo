import 'package:echos_del_tiempo/features/world/presentation/panels/town_edit_overlay.dart';
import 'package:echos_del_tiempo/features/world/presentation/town_edit.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/town_build.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';

// EDITAR PUEBLO → lago → AGREGAR ESPECIES lists the fish of the life bag
// (fishing.md § 2.4: fish only ever live in the bag).

void main() {
  testWidgets('AGREGAR ESPECIES lists every species in the life bag',
      (tester) async {
    final base = PlayerProfile(name: 'Ana', classId: 'guerrero', level: 5);
    final me = base.copyWith(
        life: base.life.copyWith(bag: {
      'bagre_raiz': 1,
      'mojarra_sombra': 2,
      'lenguado_cristal': 1,
    }));
    final c = await pumpPanel(tester,
        profile: me,
        build: (v, c) => SizedBox(
            width: 1280, height: 720, child: TownEditOverlay(controller: c)));
    await tester.pump();
    expect(c.enterTownEdit(), isTrue);
    final lake = c.town.builds.firstWhere((b) => b.kind == BuildKind.lago);
    final r = lake.bounds;
    c.editClick(r.x + r.w ~/ 2, r.y + r.h ~/ 2);
    expect(c.editSelected?.id, lake.id);
    c.editStep(TownEditStep.stocking);
    await tester.pumpAndSettle();
    for (final id in ['bagre_raiz', 'mojarra_sombra', 'lenguado_cristal']) {
      expect(find.byKey(ValueKey('town-edit-release-cell-l-$id')), findsOneWidget,
          reason: id);
    }
  });
}
