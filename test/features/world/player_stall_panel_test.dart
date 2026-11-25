import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/player_stall_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/stall_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';

// MI PUESTO (player_shop.md § 5). With `PREVIEW=1` it also writes
// docs/preview/player_shop.png.

final _preview = Platform.environment['PREVIEW'] != null;
final _shot = GlobalKey();

const _fish = 'fish:carpa_musgo';

VoidCallback? _onPressed(WidgetTester tester, String key) =>
    tester.widget<DsButton>(find.byKey(ValueKey(key))).onPressed;

void main() {
  testWidgets('poner desde la BOLSA, ver el precio, retirar y el registro',
      (tester) async {
    final base = PlayerProfile(name: 'Ana', classId: 'guerrero', level: 5);
    final me = base.copyWith(
        life: base.life.copyWith(
            bag: {'carpa_musgo': 6},
            ores: {'ingot_copper': 3},
            stall: PlayerStall(log: const [
              StallSale(3, 'ore:ingot_copper', 2, 40, ''),
              StallSale(4, _fish, 1, 9, 'Beto'),
            ], earned: 49)));
    final c = await pumpPanel(tester,
        profile: me,
        build: (v, c) => RepaintBoundary(
              key: _shot,
              child: PlayerStallPanel(view: v, controller: c),
            ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stall-empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stall-filter-bag')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stall-mine-fish-carpa_musgo')).first);
    await tester.pumpAndSettle();
    // Precio ×1.5 y PONER TODO.
    await tester.tap(find.byKey(const ValueKey('stall-step-3-$_fish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stall-putall-fish-carpa_musgo')));
    await tester.pumpAndSettle();
    final l = c.view!.me!.profile.life.stall.listing(_fish)!;
    expect(l.qty, 6);
    expect(l.price, StallRules.stepPrice(_fish, StallRules.priceSteps[3]));
    expect(c.view!.me!.profile.life.count('carpa_musgo'), 0);

    await tester.tap(find.byKey(const ValueKey('stall-filter-sale')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stall-mine-fish-carpa_musgo')).first);
    await tester.pumpAndSettle();
    // Nothing left in the bag: PONER is grey.
    expect(_onPressed(tester, 'stall-put1-fish-carpa_musgo'), isNull);
    expect(_onPressed(tester, 'stall-putall-fish-carpa_musgo'), isNull);
    if (_preview) {
      await tester.runAsync(() async {
        final b = _shot.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory('docs/preview').createSync(recursive: true);
        File('docs/preview/player_shop.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    await tester.tap(find.byKey(const ValueKey('stall-unlist-fish-carpa_musgo')));
    await tester.pumpAndSettle();
    expect(c.view!.me!.profile.life.count('carpa_musgo'), 6);
    expect(c.view!.me!.profile.life.stall.listings, isEmpty);

    // REGISTRO: one cell per sale, total earned.
    await tester.tap(find.byKey(const ValueKey('stall-tab-log')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stall-log-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('stall-log-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('stall-earned')), findsOneWidget);

    // PUESTOS DEL GRUPO solo: empty.
    await tester.tap(find.byKey(const ValueKey('stall-tab-team')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stall-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('E at the MI PUESTO town spot opens the stall', (tester) async {
    final c = await pumpPanel(tester,
        profile: PlayerProfile(name: 'Ana', classId: 'guerrero', level: 5),
        build: (v, c) => const SizedBox());
    final l = TownLayout.byId('@stall')!;
    c.teleport(l.center.x, (l.y + l.h) * 16 + 4.0);
    expect(c.nearStall, isTrue);
    expect(c.view!.prompt, WorldPrompt.stall);
    c.interact();
    expect(c.view!.panel, WorldPanel.stall);
  });
}
