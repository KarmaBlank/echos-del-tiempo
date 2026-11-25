import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/full_map.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/minimap.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_discovery_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

/// Dungeon map and minimap with discovery (docs/specs/biome_exploration.md
/// § 11.8): fog, goals always, legend trimmed to what is drawn.
GameSprites? _sprites;

Future<SessionController> _field(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (_sprites == null) {
    await tester.runAsync(() async {
      _sprites = await GameSprites.load(await SpriteCatalog.load());
    });
  }
  final g = GameSettingsController(
      store: InMemoryGameSettingsStore(), initial: const GameSettings());
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
      profileStoreProvider.overrideWithValue(InMemoryProfileStore(
          zoneProgression.normalize(PlayerProfile(
              name: 'Ana', classId: 'guerrero', unlockedZone: 1)))),
      sessionClockProvider
          .overrideWithValue(const SessionClock(autoStart: false)),
      gameSpritesProvider.overrideWith((ref) => _sprites!),
      gameSettingsProvider.overrideWith((ref) => g),
    ],
    child: MaterialApp(theme: RetroTheme.build(), home: const WorldScreen()),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final c = ProviderScope.containerOf(tester.element(find.byType(WorldScreen)))
      .read(sessionControllerProvider.notifier);
  c.proposeMission(c.zoneStatus(1)!.mission!.id);
  c.advance(0.05);
  c.setReady(true);
  c.advance(0.05);
  c.advance(0.05);
  expect(c.view!.mode, SessionMode.field);
  await tester.pump();
  return c;
}

Future<void> _openMap(WidgetTester tester, SessionController c) async {
  c.openPanel(WorldPanel.map);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('dungeon map: fog layer, goals and a trimmed legend',
      (tester) async {
    final c = await _field(tester);
    // HUD minimap carries the dungeon layer.
    final hud =
        tester.widget<Minimap>(find.byKey(const ValueKey('hud-minimap')));
    expect(hud.dungeon, isNotNull);
    expect(hud.overworld, isNull);
    await _openMap(tester, c);
    final map = tester.widget<FullMap>(find.byKey(const ValueKey('panel-map')));
    expect(map.mode, FullMapMode.dungeon);
    final dg = map.dungeon!;
    expect(dg.goals, isNotEmpty);
    for (final gl in dg.goals) {
      expect(dg.mask.knownTile(gl.x, gl.y), isTrue);
    }
    final big = tester.widget<Minimap>(find.byKey(const ValueKey('full-map')));
    expect(big.dungeon, isNotNull);
    // Legend: still the dungeon one (no overworld groups), trimmed.
    expect(find.text('Portal de mazmorra'), findsNothing);
    expect(find.text('Aliados'), findsNothing);
    final shown =
        FullMap.dungeonLegendFor(map.session, map.map, dg, allies: false);
    expect(shown.length, lessThan(FullMap.legendMarks.length));
    expect(
        [for (final (l, _, _) in shown) l], contains('ui.world.map.legend.me'));
    // Goals are framed in gold in the legend.
    for (final (l, _, goal) in shown) {
      if (l.endsWith('.stairs') || l.endsWith('.boss')) expect(goal, isTrue);
    }
    // Without the layer, the whole legend (old callers, world map).
    expect(FullMap.dungeonLegendFor(map.session, map.map, null).length,
        FullMap.legendMarks.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('walking redraws the minimap fog (cached by revision)',
      (tester) async {
    final c = await _field(tester);
    final before =
        tester.widget<Minimap>(find.byKey(const ValueKey('hud-minimap')));
    final key0 = before.dungeon!.mask.cacheKey;
    final map = c.view!.map;
    final f = map.floor(c.view!.session.mission!.floor)!;
    // Walk to some far walkable tile of the floor.
    (int, int)? far;
    for (var y = f.bounds.y + 2;
        y < f.bounds.y + f.bounds.h - 2 && far == null;
        y++) {
      for (var x = f.bounds.x + 2; x < f.bounds.x + f.bounds.w - 2; x++) {
        if (before.dungeon!.mask.knownTile(x, y)) continue;
        if (WorldRules.collides(map, x * 16 + 8.0, y * 16 + 8.0,
            blockVoid: true)) {
          continue;
        }
        far = (x, y);
        break;
      }
    }
    expect(far, isNotNull);
    c.teleport(far!.$1 * 16 + 8.0, far.$2 * 16 + 8.0);
    c.advance(0.05);
    c.advance(0.05);
    await tester.pump();
    final after =
        tester.widget<Minimap>(find.byKey(const ValueKey('hud-minimap')));
    expect(after.dungeon!.mask.cacheKey, isNot(key0));
    expect(after.dungeon!.mask.knownTile(far.$1, far.$2), isTrue);
    expect(
        DungeonDiscoveryRules.knownTile(
            c.view!.session.mission!, map, far.$1, far.$2),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  // `DUNGEON_MAP_PREVIEW=1 flutter test <this file>` writes
  // docs/preview/dungeon_map_fog.png (1280×720, real UI).
  testWidgets('preview: dungeon map with partial discovery', (tester) async {
    if (Platform.environment['DUNGEON_MAP_PREVIEW'] == null) return;
    final c = await _field(tester);
    final map = c.view!.map;
    final f = map.floor(c.view!.session.mission!.floor)!;
    // Walk a route from the arrival across part of the floor.
    final sx = f.spawn.x / 16, sy = f.spawn.y / 16;
    final cx = f.bounds.x + f.bounds.w / 2, cy = f.bounds.y + f.bounds.h / 2;
    for (var k = 0; k <= 30; k++) {
      final t = k / 30 * 0.8;
      final x = sx + (cx - sx) * t, y = sy + (cy - sy) * t;
      if (WorldRules.collides(map, x * 16, y * 16, blockVoid: true)) continue;
      c.teleport(x * 16, y * 16);
      c.advance(0.05);
    }
    await _openMap(tester, c);
    await tester.pump(const Duration(milliseconds: 700));
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final img = await layer.toImage(const Rect.fromLTWH(0, 0, 1280, 720));
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/preview').createSync(recursive: true);
      File('docs/preview/dungeon_map_fog.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
