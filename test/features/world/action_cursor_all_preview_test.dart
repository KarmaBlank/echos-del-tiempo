// Action cursor over every interactable (docs/specs/controls.md § Cursor
// de acción). With PREVIEW_SHOTS=1 writes, with the real sprites,
// docs/preview/action_cursor_all/{a_two_npcs,b_chest_selected,
// b_tree_selected,c_waystone,c_eco_portal,c_mission_portal,d_miner,
// d_mine_track}.png:
//   $env:PREVIEW_SHOTS = "1"; flutter test test/features/world/action_cursor_all_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/mine_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/custom_npc.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/localized_text.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/action_targeting.dart';
import 'package:echos_del_tiempo/game_engine/rules/cozy_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_portal_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

final _shots = Platform.environment['PREVIEW_SHOTS'] != null;
const _dir = 'docs/preview/action_cursor_all';

void main() {
  tearDown(() {
    BiomeRegions.bind(0);
    kCustomNpcs
      ..remove('prev_npc_a')
      ..remove('prev_npc_b');
  });

  Future<(SessionController, MapGame)> pump(WidgetTester tester) async {
    late GameSprites sprites;
    await tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      sprites = await GameSprites.load(cat);
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore(
            progression.normalize(PlayerProfile(
                name: 'Ana',
                classId: 'guerrero',
                level: 40,
                unlockedZone: 10)))),
        sessionClockProvider
            .overrideWithValue(const SessionClock(autoStart: false)),
        gameSpritesProvider.overrideWith((ref) => sprites),
        gameSettingsProvider.overrideWith((ref) => GameSettingsController(
            store: InMemoryGameSettingsStore(), initial: const GameSettings())),
      ],
      child: MaterialApp(theme: RetroTheme.build(), home: const WorldScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final c =
        ProviderScope.containerOf(tester.element(find.byType(WorldScreen)))
            .read(sessionControllerProvider.notifier);
    final game = tester
        .widget<GameWidget<MapGame>>(find.byType(GameWidget<MapGame>))
        .game!;
    c.debugTown((t) => t.copyWith(sky: t.sky.copyWith(seed: 3, day: 1)));
    return (c, game);
  }

  /// Stand on [at], mouse on [aim], let the camera settle.
  Future<void> settle(WidgetTester tester, SessionController c, MapGame game,
      (int, int) at, (int, int)? aim) async {
    c.teleport((at.$1 + 0.5) * 16, (at.$2 + 0.5) * 16);
    for (var i = 0; i < 40; i++) {
      c.advance(0.033);
      game.update(0.033);
      await tester.pump(const Duration(milliseconds: 33));
    }
    c.aimHover(aim);
    c.advance(0.01);
  }

  /// The map around the player, 4x (crop of the virtual frame).
  Future<void> shot(WidgetTester tester, SessionController c, MapGame game,
      String name) async {
    // A first frame starts the outline of a painted object; wait for it.
    await tester.runAsync(() async {
      game.outlines.clear();
      game.drawWorld(ui.Canvas(ui.PictureRecorder()), c.view!);
      await game.outlines.pending;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    final rec = ui.PictureRecorder();
    game.drawWorld(
        Canvas(rec,
            Rect.fromLTWH(0, 0, MapGame.vw.toDouble(), MapGame.vh.toDouble())),
        c.view!);
    final pic = rec.endRecording();
    if (!_shots) {
      pic.dispose();
      return;
    }
    await tester.runAsync(() async {
      final frame = await pic.toImage(MapGame.vw, MapGame.vh);
      // Crop 160 x 96 around the local player.
      const cw = 160.0, ch = 96.0, k = 4.0;
      final z = game.zoom;
      final px = ((c.local.x - game.camDrawX) / z)
          .clamp(cw / 2, MapGame.vw - cw / 2);
      final py = ((c.local.y - game.camDrawY) / z)
          .clamp(ch / 2, MapGame.vh - ch / 2);
      final src = Rect.fromCenter(
          center: Offset(px.toDouble(), py.toDouble()), width: cw, height: ch);
      final r2 = ui.PictureRecorder();
      Canvas(r2).drawImageRect(frame, src,
          const Rect.fromLTWH(0, 0, cw * k, ch * k), SpriteCatalog.pixelPaint());
      final img = await r2.endRecording().toImage((cw * k).round(), (ch * k).round());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$_dir/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  bool walk(List<String> rows, int x, int y) =>
      y >= 0 &&
      y < rows.length &&
      x >= 0 &&
      x < rows[y].length &&
      Tile.isWalkable(rows[y][x]);

  testWidgets('a: two NPCs side by side, the hovered one outlined',
      (tester) async {
    if (!_shots) return;
    final (c, game) = await pump(tester);
    expect(c.travelPlace(kBosque), isTrue);
    final lay = biomeLayout(kBosque)!;
    final rows = lay.rows(const {});
    final sp = lay.spawn;
    final sx = (sp.x / 16).floor(), sy = (sp.y / 16).floor();
    (int, int)? stand;
    for (var r = 0; r < 12 && stand == null; r++) {
      for (var dy = -r; dy <= r && stand == null; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          final x = sx + dx, y = sy + dy;
          if (walk(rows, x, y) &&
              walk(rows, x - 1, y - 1) &&
              walk(rows, x + 1, y - 1) &&
              walk(rows, x, y - 1)) {
            stand = (x, y);
            break;
          }
        }
      }
    }
    expect(stand, isNotNull);
    final (x, y) = stand!;
    final sprites = [for (final n in kBiomeNpcs.take(2)) n.sprite];
    kCustomNpcs['prev_npc_a'] = CustomNpcDef(
        id: 'prev_npc_a',
        name: const LocalizedText('Viajera'),
        sprite: sprites[0],
        spawn: CustomNpcSpawn.biome,
        place: kBosque,
        x: x - 1,
        y: y - 1);
    kCustomNpcs['prev_npc_b'] = CustomNpcDef(
        id: 'prev_npc_b',
        name: const LocalizedText('Cronista'),
        sprite: sprites[1],
        spawn: CustomNpcSpawn.biome,
        place: kBosque,
        x: x + 1,
        y: y - 1);
    await settle(tester, c, game, stand, (x + 1, y - 1));
    expect(c.actionTarget?.key, 'custom:prev_npc_b');
    await shot(tester, c, game, 'a_two_npcs');
    c.aimHover((x - 1, y - 1));
    c.advance(0.01);
    expect(c.actionTarget?.key, 'custom:prev_npc_a');
    await shot(tester, c, game, 'a_two_npcs_other');
  });

  testWidgets('b: a wilds chest next to a tree', (tester) async {
    if (!_shots) return;
    final (c, game) = await pump(tester);
    (String, (int, int), (int, int), (int, int))? pick;
    for (final id in kBiomeBases.keys) {
      expect(c.travelPlace(id), isTrue);
      final lay = biomeLayout(id)!;
      final rows = lay.rows(const {});
      final map = c.map;
      for (final ch in lay.chestSpots) {
        for (var dy = -1; dy <= 1 && pick == null; dy++) {
          for (var dx = -1; dx <= 1 && pick == null; dx++) {
            final s = (ch.$1 + dx, ch.$2 + dy);
            if (!walk(rows, s.$1, s.$2) || s == ch) continue;
            for (var ty = -1; ty <= 1 && pick == null; ty++) {
              for (var tx = -1; tx <= 1; tx++) {
                final t = (s.$1 + tx, s.$2 + ty);
                if (t == ch || t == s) continue;
                if (CozyRules.searchable(map, lay.id, 1, t.$1, t.$2)) {
                  pick = (id, ch, s, t);
                  break;
                }
              }
            }
          }
        }
        if (pick != null) break;
      }
      if (pick != null) break;
      c.closePanel();
    }
    expect(pick, isNotNull, reason: 'no chest next to a tree');
    final (_, ch, stand, tree) = pick!;
    await settle(tester, c, game, stand, ch);
    expect(c.actionTarget?.tile, ch);
    expect(c.actionTarget?.outline, isTrue);
    await shot(tester, c, game, 'b_chest_selected');
    c.aimHover(tree);
    c.advance(0.01);
    expect(c.actionTarget?.kind, ActionTargetKind.tree);
    await shot(tester, c, game, 'b_tree_selected');
  });

  testWidgets('c: a waystone and an eco portal selected', (tester) async {
    if (!_shots) return;
    final (c, game) = await pump(tester);
    expect(c.travelPlace(kBosque), isTrue);
    final lay = biomeLayout(kBosque)!;
    final w = lay.waystones.first;
    await settle(tester, c, game, (w.ax, w.ay), (w.x, w.y));
    expect(c.actionTarget?.kind, ActionTargetKind.waystone);
    await shot(tester, c, game, 'c_waystone');
    final p = EcoPortalRules.all.firstOrNull;
    if (p != null) {
      c.closePanel();
      if (c.place != p.biome) expect(c.travelPlace(p.biome), isTrue);
      await settle(tester, c, game, (p.x, p.y + 1), (p.x, p.y));
      expect(c.actionTarget?.kind, ActionTargetKind.portal);
      await shot(tester, c, game, 'c_eco_portal');
    }
  });

  testWidgets('c: a mission portal (zone arch) selected',
      (tester) async {
    if (!_shots) return;
    final (c, game) = await pump(tester);
    if (c.map.entrances.isEmpty) {
      for (final id in kBiomeBases.keys) {
        c.closePanel();
        expect(c.travelPlace(id), isTrue);
        if (c.map.entrances.isNotEmpty) break;
      }
    }
    final e = c.map.entrances.first;
    final f = e.front;
    c.local
      ..fx = 0
      ..fy = -1;
    await settle(tester, c, game, ((f.x / 16).floor(), (f.y / 16).floor()),
        null);
    expect(c.actionTarget?.key, 'zone:${e.zone}');
    await shot(tester, c, game, 'c_mission_portal');
  });

  testWidgets('d: the miner selected in a mine', (tester) async {
    if (!_shots) return;
    final (c, game) = await pump(tester);
    String? biome;
    for (final id in kBiomeBases.keys) {
      final lay = biomeLayout(id)!;
      if (MiningRules.entrances(lay).isEmpty) continue;
      if (MiningRules.level(MiningRules.placeOf(id, 0))?.npc != null) {
        biome = id;
        break;
      }
    }
    expect(c.travelPlace(biome!), isTrue);
    expect(c.travelMine(0), isTrue);
    final lvl = c.mineLevel!;
    final (_, nx, ny) = lvl.npc!;
    (int, int)? stand;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final code = MiningRules.tileAt(lvl, c.mineState, nx + dx, ny + dy);
      if (code == Tile.floor || code == MineTile.torch) {
        stand = (nx + dx, ny + dy);
        break;
      }
    }
    await settle(tester, c, game, stand!, (nx, ny));
    expect(c.actionTarget?.key, startsWith('minenpc:'));
    await shot(tester, c, game, 'd_miner');
    // The station room: the cart track as rail tiles on the floor.
    final track = MiningRules.track(lvl, c.mineState);
    expect(track, isNotEmpty);
    final (tx, ty) = track[track.length ~/ 2];
    await settle(tester, c, game, (tx, ty - 1), null);
    await shot(tester, c, game, 'd_mine_track');
  });
}
