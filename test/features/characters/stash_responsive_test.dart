// ALIJO responsivo (characters.md § 3, "Responsivo"): en todas las
// resoluciones y tamaños de texto, dentro de la partida (StashPanel) y
// fuera (StashScreen), nada se sale del panel a lo ancho (el alto puede
// desplazarse) y no hay desbordes.
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
}

void main() {
  test('stashLayout: lado a lado o apilado, nunca más ancho', () {
    expect(stashLayout(1000).wide, isTrue);
    expect(stashLayout(600).wide, isFalse);
    for (final w in [300.0, 500.0, 800.0, 1000.0, 1300.0]) {
      final l = stashLayout(w, sideMin: 300);
      final need = l.wide
          ? 2 * StashBoard.gridWidth * l.scale + StashBoard.sideGap
          : StashBoard.gridWidth * l.scale;
      expect(need, lessThanOrEqualTo(w + 0.01), reason: '$w');
    }
  });

  const sizes = [
    Size(1024, 600),
    Size(1280, 720),
    Size(1366, 768),
    Size(1750, 1040),
    Size(1920, 1080),
  ];
  const texts = [TextSize.normal, TextSize.large, TextSize.enormous];
  for (final inSession in [true, false]) {
    for (final size in sizes) {
      for (final t in texts) {
        testWidgets(
            'alijo ${inSession ? 'en partida' : 'fuera'}: nada fuera del '
            'panel ${size.width.toInt()}x${size.height.toInt()} texto '
            '${t.name}', (tester) async {
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
          // Igual que StashPanel / StashScreen: PanelFrame de 1000.
          final frame = PanelFrame(
            key: const ValueKey('panel'),
            title: inSession ? 'ALIJO' : 'ALIJO COMPARTIDO',
            width: 1000,
            onClose: () {},
            actions: [PanelButton('CERRAR', onPressed: () {})],
            child: StashBoard(
                host: host, title: 'Ana · Guerrero · Nv ${p.level}'),
          );
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: RetroTheme.build(),
            builder: (context, child) =>
                RetroTextScale(factor: t.factor, child: child!),
            home: Scaffold(
                body: inSession ? Stack(children: [Center(child: frame)]) : frame),
          ));
          await tester.pump();
          await tester.pump();
          expect(tester.takeException(), isNull);
          final panel = tester.getRect(find.byType(StashBoard));
          final screen = Offset.zero & size;
          expect(panel.right <= screen.right + 0.5 && panel.left >= -0.5,
              isTrue);
          final keys = <String>[
            for (var i = 0; i < InventoryRules.cells; i++) 'stash-char-$i',
            for (var i = 0; i < Stash.perTab; i++) 'stash-cell-$i',
            for (final k in StackKind.values) 'inv-stack-${k.token}',
            'stash-char-equipped',
            'stash-search-char',
            'stash-search-stash',
            'stash-used',
            'stash-deposit',
            'stash-move-all',
            'stash-pick',
            for (var t = 0; t < Stash.tabs; t++) 'tab-$t',
          ];
          for (final k in keys) {
            final f = find.byKey(ValueKey(k));
            expect(f, findsWidgets, reason: k);
            final r = tester.getRect(f.first);
            expect(r.left >= panel.left - 0.5 && r.right <= panel.right + 0.5,
                isTrue,
                reason: '$k $r fuera de $panel');
          }
          final c0 = tester.getRect(find.byKey(const ValueKey('stash-cell-0')));
          expect(c0.width, greaterThan(20));
        });
      }
    }
  }
}
