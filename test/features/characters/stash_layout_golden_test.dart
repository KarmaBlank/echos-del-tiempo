// El layout por defecto del ALIJO (assets/layouts/stash.layout.yaml)
// reproduce exactamente la pantalla de antes de migrarla a datos
// (docs/specs/editor_layout.md § 4, "Golden"). Los PNG se generaron con
// el árbol manual previo a la migración; no regenerar salvo cambio
// visual deliberado:
//   flutter test --update-goldens test/features/characters/stash_layout_golden_test.dart
@Tags(['golden'])
library;

import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/features/characters/presentation/stash_board.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';
import '../inventory/loot_fixtures.dart';

class _Host implements StashBoardHost {
  _Host(this.profile, this.stash);
  @override
  ProgressionRules get rules => progression;
  @override
  PlayerProfile profile;
  @override
  Stash stash;
  @override
  bool get busy => false;
  @override
  String? get notice => null;
  @override
  String? put(List<String> tokens, int tab) => null;
  @override
  String? take(List<int> cells) => null;
  @override
  bool moveStash(int from, int to) => false;
  @override
  bool moveCharacter(int from, int to) => false;
  @override
  void achievement(String id) {}
}

void main() {
  const cases = {
    'wide': (Size(1280, 900), TextSize.normal),
    'narrow': (Size(800, 1300), TextSize.large),
  };
  for (final MapEntry(key: name, value: (size, text)) in cases.entries) {
    testWidgets('alijo por defecto == antes de migrar ($name)', (tester) async {
      await loadRealFonts(tester);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var p = lootWarrior();
      for (final k in StackKind.values) {
        p = InventoryRules.withStack(p, k, 3);
      }
      final host =
          _Host(p, Stash.empty().put(0, const StashEntry.item(epicSword)));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RetroTheme.build(),
        builder: (context, child) =>
            RetroTextScale(factor: text.factor, child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
          child: PanelFrame(
            title: 'ALIJO',
            width: 1000,
            onClose: () {},
            child: StashBoard(host: host, title: 'Ana · Guerrero · Nv 5'),
          ),
        )),
      ));
      await tester.pump();
      await tester.pump();
      await expectLater(find.byType(StashBoard),
          matchesGoldenFile('goldens/stash_default_$name.png'));
    });
  }
}
