// INVENTARIO grid migration previews (design_system.md § "Grilla de
// ítems"): workshop, mission results, lost loot, raft decoration, town
// build palette and houses, with the real sprites. With PREVIEW=1 writes
// docs/preview/ui_grid/<screen>.png at 1280×720:
//   $env:PREVIEW = "1"; flutter test test/features/ui_grid_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_grid.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/workshop_panel.dart';
import 'package:echos_del_tiempo/features/missions/presentation/results_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/house_assign_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_item_grid.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/lost_loot_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/raft_deco_cells.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'inventory/armory_panel_test.dart' show richWarrior;
import 'panel_test_harness.dart';
import 'world/fishing_map_harness.dart';

final _shots = Platform.environment['PREVIEW'] != null;

Future<GameSprites?> _sprites(WidgetTester tester) => tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      return GameSprites.load(cat);
    });

/// The whole 1280×720 screen.
Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  await tester.runAsync(() async {
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final img = await layer.toImage(const Rect.fromLTWH(0, 0, 1280, 720));
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview/ui_grid').createSync(recursive: true);
    File('docs/preview/ui_grid/$name.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}

PlayerProfile _player() => richWarrior(credits: 3000).copyWith(
    materials: const {CraftMaterial.esquirla: 30},
    life: LifeSkills(
      fishXp: 400,
      bag: const {'mojarra_claro': 4},
      rods: const [kStarterRod],
      raftDecos: const {'lantern'},
      raftOn: const {'lantern'},
      farm: FarmSkills(
        xp: 300,
        hoes: const [kStarterHoe],
        cans: const [kStarterCan],
        crops: const {'nabo_claro@0': 7, 'papa_piedra@0': 3},
      ),
    ));

LootDrop _sword(String uid, String base, Rarity r) => LootDrop.item(
    ItemInstance(uid: uid, baseId: base, rarity: r, itemLevel: 4));

void main() {
  testWidgets('workshop', (tester) async {
    await pumpPanel(tester,
        profile: _player(),
        sprites: await _sprites(tester),
        build: (v, c) => WorkshopPanel(view: v, controller: c));
    expect(find.byKey(const ValueKey('workshop-grid')), findsOneWidget);
    await _shot(tester, 'workshop');
    expect(tester.takeException(), isNull);
  });

  testWidgets('battle results: loot tab', (tester) async {
    final drops = [
      _sword('a', 'espada_ignea', Rarity.raro),
      _sword('b', 'espada_bronce', Rarity.comun),
      _sword('c', 'filo_alba', Rarity.epico),
      const LootDrop.stack(StackKind.potion, 2),
    ];
    await pumpPanel(tester,
        profile: _player(),
        sprites: await _sprites(tester),
        build: (v, c) => Center(
              child: ResultsPanel(
                result: MissionResult(
                  id: 1,
                  missionId: 'm1',
                  missionName: 'Pradera Esmeralda',
                  success: true,
                  rank: MissionRank.a,
                  time: 184,
                  xp: 120,
                  credits: 340,
                  bonus: 85,
                  bonusPercent: 0.25,
                  kos: 0,
                  elites: 0,
                  eliteDrops: const [],
                  drops: const {},
                ),
                localId: 'p0',
                playerName: (_) => 'Ana',
                weaponName: (id) => id,
                onBack: () {},
                unlocked: '¡Zona 2 desbloqueada! Bosque Hondo',
                loot: [
                  for (final d in drops)
                    ResultDrop(
                      d.item?.baseId ?? 'Pociones ×2',
                      FilterVerdict(true, LootFilterRules.defaultStyle(d)),
                      cell: (size, sel) => ItemSlot(
                          rules: c.engine.progression,
                          size: size,
                          data: ItemSlotData(
                              content: dropCellContent(d), selected: sel)),
                    ),
                ],
              ),
            ));
    await _shot(tester, 'results_summary');
    await tester.tap(find.byKey(const ValueKey('results-tab-loot')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('results-grid')), findsOneWidget);
    await _shot(tester, 'results_loot');
    expect(tester.takeException(), isNull);
  });

  testWidgets('lost loot', (tester) async {
    final c = await pumpPanel(tester,
        profile: _player(),
        sprites: await _sprites(tester),
        build: (v, c) => LostLootPanel(view: v, controller: c));
    var id = 0;
    for (final d in [
      _sword('a', 'espada_ignea', Rarity.raro),
      _sword('b', 'espada_bronce', Rarity.comun),
      _sword('c', 'espada_ignea', Rarity.epico),
      const LootDrop.stack(StackKind.potion, 3),
    ]) {
      c.session!.lostLoot.add(GroundLoot(id: ++id, drop: d, x: 0, y: 0));
    }
    c.openPanel(WorldPanel.lostLoot);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lost-grid')), findsOneWidget);
    await _shot(tester, 'lost_loot');
    expect(tester.takeException(), isNull);
  });

  testWidgets('raft decoration', (tester) async {
    await pumpPanel(tester,
        profile: _player(),
        sprites: await _sprites(tester),
        build: (v, c) => PanelFrame(
              key: const ValueKey('panel-raft-decor'),
              title: 'BALSA',
              width: 1000,
              fill: true,
              onClose: () {},
              child: Builder(
                  builder: (ctx) => LifeItemGrid(
                        groups: [
                          LifeItemGroup(null,
                              raftDecoCells(ctx, v.me!.profile, c.raftDeco))
                        ],
                        empty: '',
                      )),
            ));
    await _shot(tester, 'raft_decoration');
    expect(tester.takeException(), isNull);
  });

  testWidgets('houses', (tester) async {
    await pumpPanel(tester,
        profile: _player(),
        sprites: await _sprites(tester),
        build: (v, c) => Center(
              child: PanelFrame(
                title: 'ASIGNAR CASAS',
                width: 1000,
                onClose: () {},
                child: SizedBox(
                  height: 420,
                  child: HouseAssignView(
                    houses: [
                      for (var i = 1; i <= 5; i++)
                        HouseCellData('h$i', 'CASA $i', 'Nivel ${(i % 3) + 1}',
                            level: (i % 3) + 1),
                    ],
                    candidates: const [
                      HouseCandidateData('brann', 'Brann', 'Beneficio: forja'),
                      HouseCandidateData('ilda', 'Ilda', 'Beneficio: huerta'),
                    ],
                    onAssign: (_, __) {},
                  ),
                ),
              ),
            ));
    expect(find.byKey(const ValueKey('houses-grid')), findsOneWidget);
    await _shot(tester, 'houses');
    expect(tester.takeException(), isNull);
  });

  testWidgets('town build palette', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester,
        profile: PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 60000));
    expect(h.c.enterTownEdit(), isTrue);
    await h.frames(3);
    expect(find.byKey(const ValueKey('town-build-grid')), findsOneWidget);
    await _shot(tester, 'town_build_palette');
    h.c.exitTownEdit();
    await h.frames(2);
  });
}
