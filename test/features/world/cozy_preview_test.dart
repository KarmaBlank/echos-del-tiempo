// Cozy life previews (docs/specs/cozy_life.md). With PREVIEW_SHOTS=1
// writes docs/preview/cozy_{fishing_night,farm_decor,hold_gather}.png
// (map art) and cozy_{journal,raft_decor}.png (panels):
//   $env:PREVIEW_SHOTS = "1"; flutter test test/features/world/cozy_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/cozy_hud_dim.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/actor_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/cozy_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_themes.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_target.dart';
import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_item_grid.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/raft_deco_cells.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/quest_log_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/cozy_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/cozy_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../inventory/armory_panel_test.dart' show richWarrior;
import '../panel_test_harness.dart';

final _shots = Platform.environment['PREVIEW_SHOTS'] != null;

Future<GameSprites?> _sprites(WidgetTester tester) => tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      return GameSprites.load(cat);
    });

Future<void> _panelShot(WidgetTester tester, String key, String name) async {
  if (!_shots) return;
  await tester.runAsync(() async {
    final b = tester.renderObject<RenderRepaintBoundary>(find
        .ancestor(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(RepaintBoundary))
        .last);
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('docs/preview/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _picShot(
    WidgetTester tester, ui.Picture pic, int w, int h, String name) async {
  if (!_shots) {
    pic.dispose();
    return;
  }
  await tester.runAsync(() async {
    final img = await pic.toImage(w, h);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('docs/preview/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Tiles of [map] inside [view] (px), like the map does.
void _tiles(Canvas c, GameMap map, Rect view) {
  final tiles = TilePainter();
  for (var y = (view.top / 16).floor(); y <= (view.bottom / 16).ceil(); y++) {
    for (var x = (view.left / 16).floor(); x <= (view.right / 16).ceil(); x++) {
      if (!map.contains(x, y)) continue;
      tiles.draw(c, map.tileAt(x, y), x * 16.0, y * 16.0, map.theme, x, y,
          t: 1000, gateOpen: false, lobby: true);
    }
  }
}

PlayerProfile _cozyPlayer() => richWarrior(credits: 400).copyWith(
      life: LifeSkills(
        fishXp: 300,
        log: const {'trucha_cobre': 31, 'mojarra_claro': 12},
        smithXp: 40,
        oreLog: {
          for (final id in kSmithMaterials.keys.take(3))
            id: const OreFind(3, 'mine:bosque', 7),
        },
        raftDecos: const {'lantern'},
        raftOn: const {'lantern'},
        farm: FarmSkills(
          xp: 120,
          seeds: const {'nabo_claro': 4},
          crops: const {'moras_bosque@0': 4, 'nabo_claro@1': 2},
          recipes: const {'leaf_mulch', 'mushroom_compost'},
        ),
      )
          .logFishFind('trucha_cobre', kBosque, 5)
          .logFishFind('mojarra_claro', 'pueblo', 2),
    );

void main() {
  tearDown(() => BiomeRegions.bind(0));

  testWidgets('map: night fishing on a decorated raft, fireflies',
      (tester) async {
    final sprites = await _sprites(tester);
    final cozy = CozyLayer((id) => sprites?.lifeIcon(id, ''));
    late BiomeLayout lay;
    for (var seed = 0; seed < 200; seed++) {
      BiomeRegions.bind(seed);
      lay = biomeLayout(kBosque)!;
      if (lay.raftDocks.isNotEmpty) break;
    }
    final map = MapGenerator.biome(lay);
    final d = lay.raftDocks.first;
    // Out on the water a few tiles from the dock (cozyFishZoom framing).
    final cx = (d.wx + 0.5) * 16, cy = (d.wy + 0.5) * 16;
    const w = 320.0, h = 180.0, scale = 3.0;
    final z = CozyRules.fishZoom;
    final view =
        Rect.fromCenter(center: Offset(cx, cy), width: w * z, height: h * z);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale / z)
      ..translate(-view.left, -view.top);
    _tiles(c, map, view);
    final life = LifeSkills(
        raftDecos: const {'lantern', 'roof', 'paint_blue'},
        raftOn: const {'lantern', 'roof', 'paint_blue'});
    final raft = sprites?.lifeIcon('balsa', '');
    if (raft != null) cozy.drawRaft(c, raft, cx, cy, 0, life);
    cozy.drawRaftRoof(c, cx, cy, 0, life);
    // Night tint, then the fireflies glow over it.
    c.drawRect(view, Paint()..color = SkyPalette.night.withValues(alpha: 0.5));
    cozy.drawFireflies(c, cx, cy, 4200, count: 12);
    await _picShot(tester, rec.endRecording(), (w * scale).round(),
        (h * scale).round(), 'cozy_fishing_night');
    expect(CozyRules.hasRoof(life), isTrue);
  });

  testWidgets('map: wide raft, awning, seated rider fishing', (tester) async {
    final sprites = await _sprites(tester);
    if (sprites == null) return;
    final cozy = CozyLayer((id) => sprites.lifeIcon(id, ''));
    final actors = ActorPainter(sprites);
    final raft = sprites.lifeIcon('balsa', '')!;
    // Two tiles wide, one tall: a raft, not a stall.
    expect((raft.width, raft.height), (32, 16));
    expect(sprites.lifeIcon('raft_roof', '')!.width, 32);
    expect(sprites.lifeIcon('raft_posts', ''), isNotNull);
    // Water strip, then: bare, docked (awning + lantern + blue paint),
    // rider seated fishing under the awning, rider sailing.
    const w = 200.0, h = 56.0, scale = 5.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(scale);
    c.drawRect(const Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF2B5D8A));
    final life = LifeSkills(
        raftDecos: const {'lantern', 'roof', 'paint_blue'},
        raftOn: const {'lantern', 'roof', 'paint_blue'});
    const y = 40.0;
    void hero(double x, {required bool seated, required bool moving}) =>
        actors.hero(c,
            classId: 'guerrero', weaponType: null, x: x, y: y - 3, t: 140,
            dir: 1, moving: moving, dead: false, blink: false,
            showWeapon: false, seated: seated);
    void raftAt(double x, {bool? seated}) {
      cozy.drawRaft(c, raft, x, y, 0, life);
      cozy.drawRaftPosts(c, x, y, 0, life);
      if (seated == true) cozy.drawRaftSeat(c, x, y - 3);
      if (seated != null) hero(x, seated: seated, moving: !seated);
      cozy.drawRaftRoof(c, x, y, 0, life);
    }
    cozy.drawRaft(c, raft, 25, y, 0, null);
    raftAt(75);
    raftAt(125, seated: true);
    raftAt(175, seated: false);
    await _picShot(tester, rec.endRecording(), (w * scale).round(),
        (h * scale).round(), 'cozy_raft_decor');
    // 4x crop of the seated rider for review.
    if (_shots) {
      await tester.runAsync(() async {
        final rec2 = ui.PictureRecorder();
        final c2 = Canvas(rec2)
          ..scale(4)
          ..translate(-105, -8);
        c2.drawRect(const Rect.fromLTWH(105, 8, 40, 40),
            Paint()..color = const Color(0xFF2B5D8A));
        final lone = LifeSkills(
            raftDecos: const {'lantern', 'roof', 'paint_blue'},
            raftOn: const {'lantern', 'roof', 'paint_blue'});
        cozy.drawRaft(c2, raft, 125, y, 0, lone);
        cozy.drawRaftPosts(c2, 125, y, 0, lone);
        cozy.drawRaftSeat(c2, 125, y - 3);
        actors.hero(c2,
            classId: 'guerrero', weaponType: null, x: 125, y: y - 3, t: 0,
            dir: 1, moving: false, dead: false, blink: false,
            showWeapon: false, seated: true);
        cozy.drawRaftRoof(c2, 125, y, 0, lone);
        final img = await rec2.endRecording().toImage(160, 160);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('docs/preview/cozy_raft_seated_4x.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        // 4-up, 4x: the seated pose works for every class sprite.
        const classes = ['guerrero', 'maga', 'paladin', 'tirador'];
        final rec3 = ui.PictureRecorder();
        final c3 = Canvas(rec3)..scale(4);
        c3.drawRect(const Rect.fromLTWH(0, 0, 160, 40),
            Paint()..color = const Color(0xFF2B5D8A));
        for (var i = 0; i < classes.length; i++) {
          final x = 20.0 + 40 * i;
          cozy.drawRaft(c3, raft, x, 32, 0, null);
          cozy.drawRaftSeat(c3, x, 29);
          actors.hero(c3,
              classId: classes[i], weaponType: null, x: x, y: 29, t: 0,
              dir: 1, moving: false, dead: false, blink: false,
              showWeapon: false, seated: true);
        }
        final img3 = await rec3.endRecording().toImage(640, 160);
        final png3 = await img3.toByteData(format: ui.ImageByteFormat.png);
        File('docs/preview/cozy_seated_classes_4x.png')
            .writeAsBytesSync(png3!.buffer.asUint8List());
      });
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('map: farm decorations around the base farm', (tester) async {
    final sprites = await _sprites(tester);
    final cozy = CozyLayer((id) => sprites?.lifeIcon(id, ''));
    final f = kBaseFarm.parts.first;
    final town = TownState(decor: [
      for (var x = f.x - 1; x <= f.x + f.w; x++) ('fence', x, f.y - 1),
      ('scarecrow', f.x + f.w, f.y + 1),
      ('pot', f.x - 1, f.y + 1),
      ('lamp', f.x + f.w + 1, f.y - 1),
      for (var y = f.y; y < f.y + f.h; y++) ('stone_path', f.x + f.w + 1, y),
    ]);
    final map = MapGenerator.town(town);
    final (ox, oy) = map.townOrigin;
    final view = Rect.fromLTWH((f.x + ox - 3) * 16.0, (f.y + oy - 3) * 16.0,
        (f.w + 6) * 16.0, (f.h + 6) * 16.0);
    const scale = 4.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale)
      ..translate(-view.left, -view.top);
    _tiles(c, map, view);
    cozy.drawDecor(c, town, ox, oy);
    await _picShot(tester, rec.endRecording(), (view.width * scale).round(),
        (view.height * scale).round(), 'cozy_farm_decor');
    expect(town.decor.length, greaterThan(5));
    expect(kFarmDecos.length, 6);
  });

  testWidgets('map: hold-to-gather bar on a forage bush', (tester) async {
    BiomeRegions.bind(0);
    final lay = biomeLayout(kBosque)!;
    final map = MapGenerator.biome(lay);
    final s = lay.forage.first;
    final view = Rect.fromCenter(
        center: Offset((s.x + 0.5) * 16, (s.y + 0.5) * 16),
        width: 112,
        height: 64);
    const scale = 5.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale)
      ..translate(-view.left, -view.top);
    _tiles(c, map, view);
    drawTileTarget(c, [(s.x, s.y)], true, progress: 0.6);
    await _picShot(tester, rec.endRecording(), (view.width * scale).round(),
        (view.height * scale).round(), 'cozy_hold_gather');
  });

  testWidgets('DIARIO: OFICIOS journals, grid with detail, compost',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: _cozyPlayer(),
        sprites: await _sprites(tester),
        build: (v, c) => QuestLogPanel(view: v, controller: c));
    await tapVisible(
        tester, find.byKey(const ValueKey('quest-log-tab-oficios')));
    expect(
        find.byKey(const ValueKey('prof-journal-tab-fishing')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('prof-journal-tab-mining')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('prof-journal-tab-farming')), findsOneWidget);
    expect(find.byKey(const ValueKey('journal-fish-trucha_cobre')),
        findsOneWidget);
    await tapVisible(
        tester, find.byKey(const ValueKey('journal-fish-trucha_cobre')));
    await _panelShot(tester, 'panel-quest-log', 'cozy_journal');
    await tapVisible(
        tester, find.byKey(const ValueKey('prof-journal-tab-farming')));
    await tapVisible(
        tester, find.byKey(const ValueKey('journal-recipe-leaf_mulch')));
    final make = find.byKey(const ValueKey('journal-compost-leaf_mulch'));
    expect(tester.widget<DsButton>(make).onPressed, isNotNull);
    await tapVisible(tester, make);
    expect(c.view!.me!.profile.life.farm.fertCount('abono'),
        kCompostRecipes['leaf_mulch']!.makes);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BALSA: raft decorations grid, buy and toggle', (tester) async {
    final c = await pumpPanel(tester,
        profile: _cozyPlayer(),
        sprites: await _sprites(tester),
        build: (v, c) => PanelFrame(
              key: const ValueKey('panel-raft-decor'),
              title: 'BALSA',
              width: 1000,
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
    expect(find.byKey(const ValueKey('raft-deco-roof')), findsOneWidget);
    expect(c.view!.me!.profile.life.raftOn, {'lantern'});
    await tapVisible(tester, find.byKey(const ValueKey('raft-deco-roof')));
    await _panelShot(tester, 'panel-raft-decor', 'cozy_raft_decor_panel');
    await tapVisible(tester, find.byKey(const ValueKey('raft-deco-act-roof')));
    expect(c.view!.me!.profile.life.raftOn, {'lantern', 'roof'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('HUD steps back while fishing', (tester) async {
    Widget hud(bool calm) =>
        MaterialApp(home: CozyHudDim(calm: calm, child: const Text('HUD')));
    await tester.pumpWidget(hud(false));
    final hudSize = tester.getSize(find.text('HUD'));
    final hudAt = tester.getTopLeft(find.text('HUD'));
    await tester.pumpWidget(hud(true));
    await tester.pump(CozyHudDim.duration ~/ 2);
    expect(tester.getSize(find.text('HUD')), hudSize);
    expect(tester.getTopLeft(find.text('HUD')), hudAt);
    await tester.pumpAndSettle();
    final o = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(o.opacity, CozyRules.hudOpacity);
    // Only the world zooms: the HUD keeps its size and place.
    expect(find.byType(AnimatedScale), findsNothing);
    expect(tester.getSize(find.text('HUD')), hudSize);
  });

  test('fish ids of the preview exist', () {
    expect(kFish.containsKey('trucha_cobre'), isTrue);
    expect(kFish.containsKey('mojarra_claro'), isTrue);
  });
}
