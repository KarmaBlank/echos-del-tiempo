import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/tracked_quests_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_item_grid.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_strings.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';

// Orders / quest menus (quest_audit.md § 8): NPC order detail, a quest
// step detail and the tracked list of the HUD, on real widgets at
// 1280×720. With `ORDERS_PREVIEW=before|after` it writes
// docs/preview/orders_<value>.png.

final _preview = Platform.environment['ORDERS_PREVIEW'];
final _shot = GlobalKey();

void main() {
  testWidgets('orders menus: order, quest step and tracked list',
      (tester) async {
    final brann = biomeNpc('brann')!;
    const r = ResidentState('brann',
        rep: 6,
        quest: 1,
        progress: 1,
        invited: true,
        order: 'chile_volcan',
        orderN: 3,
        orders: 4);
    final town = const TownState().withResident(r);
    final base = PlayerProfile(name: 'Ana', classId: 'guerrero', level: 12);
    final p = base.copyWith(
        tracked: const ['orden:brann', 'encargo:brann'],
        npcSeen: const {'brann': 'q1|r-0|ochile_volcan0'});
    await pumpPanel(tester,
        profile: p,
        build: (v, c) => RepaintBoundary(
              key: _shot,
              child: Container(
                color: DsColors.background,
                padding: const EdgeInsets.all(16),
                child: Builder(builder: (context) {
                  final s = worldStrings(context);
                  final order = orderCell(s, c, brann, r, p, home: true)!;
                  final quests = questCells(s, c, brann, r, p);
                  Widget box(List<LifeItemCellData> cells) => Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: DsColors.surface,
                              border: Border.all(color: DsColors.border)),
                          child: LifeItemGrid(
                              groups: [LifeItemGroup(null, cells)],
                              empty: '-'),
                        ),
                      );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      box([order, ...quests]),
                      const SizedBox(width: 12),
                      box(quests.reversed.toList()),
                      const SizedBox(width: 12),
                      TrackedQuestsHud(
                          profile: p, town: town, onOpen: () {}),
                    ],
                  );
                }),
              ),
            ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('order-brann')), findsWidgets);
    expect(find.byKey(const ValueKey('hud-tracked')), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (_preview == null) return;
    await tester.runAsync(() async {
      final b =
          _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage();
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/preview').createSync(recursive: true);
      File('docs/preview/orders_$_preview.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
