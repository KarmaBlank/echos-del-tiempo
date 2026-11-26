// Previews of the NPC menus (design_system.md § 6.2 and § 6.3). Only
// runs with PREVIEW_SHOTS=1:
//   $env:PREVIEW_SHOTS = "1"; flutter test test/design/npc_menus_preview_test.dart
// Writes docs/preview/npc_menus/{shop_one_item,shop_many_items,quest_checklist}.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/design/gallery/ds_examples.dart';
import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';

final _on = Platform.environment['PREVIEW_SHOTS'] != null;

Future<void> _save(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final b = tester.renderObjectList(find.byType(RepaintBoundary)).first
        as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path).parent.createSync(recursive: true);
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
    img.dispose();
  });
}

Future<void> _openShop(WidgetTester tester, PlayerProfile profile,
    {String? npc, bool invited = false}) async {
  final c = await pumpPanel(tester,
      profile: progression.normalize(profile),
      build: (v, c) =>
          RepaintBoundary(child: BiomeNpcPanel(view: v, controller: c)));
  tester.view.physicalSize = const Size(1280, 720);
  if (invited) {
    c.session!.town = c.session!.town
        .withResident(ResidentState(npc!, invited: true, house: 1));
  }
  c.openResident(npc == null
      ? kBiomeNpcs.first
      : kBiomeNpcs.firstWhere((n) => n.id == npc));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('ds-dialogue-text')),
      warnIfMissed: false);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('npc-choice-comprar')));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shop with one item', (tester) async {
    await _openShop(
        tester,
        PlayerProfile(
            name: 'Ana',
            classId: 'guerrero',
            credits: 900,
            life: LifeSkills(
                farm: FarmSkills(xp: 300, seeds: const {'nabo_claro': 6}))));
    await _save(tester, 'docs/preview/npc_menus/shop_one_item.png');
  }, skip: !_on);

  testWidgets('shop with many items', (tester) async {
    await _openShop(
        tester,
        PlayerProfile(
            name: 'Ana',
            classId: 'guerrero',
            level: 20,
            credits: 5000,
            life: LifeSkills(ores: const {'ingot_copper': 10})),
        npc: 'brann',
        invited: true);
    await _save(tester, 'docs/preview/npc_menus/shop_many_items.png');
  }, skip: !_on);

  testWidgets('quest list with checklist partly done', (tester) async {
    await pumpPanel(tester,
        profile: progression.normalize(
            PlayerProfile(name: 'Ana', classId: 'guerrero')),
        build: (v, c) => RepaintBoundary(
            child: PanelFrame(
                title: 'DIARIO',
                width: 1000,
                fill: true,
                onClose: () {},
                child: DsQuestTemplate(
                    entries: QuestTemplateMockup.entries(),
                    empty: '-',
                    itemsLabel: 'PIDE',
                    rewardsLabel: 'RECOMPENSA'))));
    tester.view.physicalSize = const Size(1280, 720);
    await tester.pump();
    await tester.pump();
    await _save(tester, 'docs/preview/npc_menus/quest_checklist.png');
  }, skip: !_on);
}
