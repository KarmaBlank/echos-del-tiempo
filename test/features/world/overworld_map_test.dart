import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/full_map.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/minimap.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

/// Overworld map and minimap (docs/specs/biome_exploration.md § 11):
/// own legend, goals vs optional, smaller minimap, discovery.
GameSprites? _sprites;

Future<SessionController> _biome(WidgetTester tester) async {
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
          progression.normalize(PlayerProfile(
              name: 'Ana', classId: 'guerrero', level: 40, unlockedZone: 10)))),
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
  final id = kBiomeBases.keys
      .firstWhere((id) => (biomeLayout(id)?.waystones.length ?? 0) >= 3);
  expect(c.travelPlace(id), isTrue);
  for (var k = 0; k < 200 && c.place != id; k++) {
    c.advance(0.05);
  }
  expect(c.place, id);
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

  test('each mode lists only what it draws', () {
    final dungeon = FullMap.legendKeys(FullMapMode.dungeon);
    final over = FullMap.legendKeys(FullMapMode.overworld);
    expect(dungeon, contains('ui.world.map.legend.stairs'));
    expect(dungeon, contains('ui.world.map.legend.boss'));
    for (final k in const [
      'ui.world.map.legend.stairs',
      'ui.world.map.legend.boss',
      'ui.world.map.legend.secret',
      'ui.world.map.legend.enemy',
    ]) {
      expect(over, isNot(contains(k)));
    }
    expect(over, containsAll(const [
      'ui.world.map.legend.portal',
      'ui.world.map.legend.echo',
      'ui.world.map.legend.waystone',
      'ui.world.map.legend.me',
    ]));
    // Goals come first, in their own group.
    expect(FullMap.overworldLegendMarks.first.$1,
        'ui.world.map.legend.group_goals');
    expect([for (final (_, _, g) in FullMap.overworldLegendMarks.first.$2) g],
        everyElement(isTrue));
  });

  testWidgets('overworld map: own legend, goals group, discovery layer',
      (tester) async {
    final c = await _biome(tester);
    await _openMap(tester, c);
    expect(find.byKey(const ValueKey('panel-map')), findsOneWidget);
    final map = tester.widget<FullMap>(find.byKey(const ValueKey('panel-map')));
    expect(map.mode, FullMapMode.overworld);
    expect(map.overworld, isNotNull);
    expect(
        find.byKey(const ValueKey(
            'full-map-legend-ui.world.map.legend.group_goals')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey(
            'full-map-legend-ui.world.map.legend.group_optional')),
        findsOneWidget);
    expect(find.text('Portal de mazmorra'), findsOneWidget);
    expect(find.text('Escalera'), findsNothing);
    expect(find.text('Jefe'), findsNothing);
    // Minimap and big map share the overworld layer.
    final mm = tester.widget<Minimap>(find.byKey(const ValueKey('full-map')));
    expect(mm.overworld, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('minimap fits the smaller window at every zoom',
      (tester) async {
    final c = await _biome(tester);
    expect(c.view, isNotNull);
    for (final zoom in const [3, 2, 1]) {
      final container =
          ProviderScope.containerOf(tester.element(find.byType(WorldScreen)));
      final s = container.read(gameSettingsProvider);
      await container
          .read(gameSettingsProvider.notifier)
          .update(s.copyWith(minimapZoom: zoom));
      await tester.pump();
      final size = tester.getSize(find.byKey(const ValueKey('hud-minimap')));
      expect(size.width, lessThanOrEqualTo(kMinimapWindow.width + 0.01),
          reason: 'zoom $zoom');
      expect(size.height, lessThanOrEqualTo(kMinimapWindow.height + 0.01),
          reason: 'zoom $zoom');
    }
    expect(kMinimapWindow.width, lessThan(200));
    expect(kMinimapWindow.height, lessThan(140));
  });

  // `OVERWORLD_MAP_PREVIEW=1 flutter test <this file>` writes
  // docs/preview/overworld_map_fog.png (1280×720, real UI).
  testWidgets('preview: overworld map with partial discovery', (tester) async {
    if (Platform.environment['OVERWORLD_MAP_PREVIEW'] == null) return;
    final c = await _biome(tester);
    // Walk a winding route from the arrival to draw part of the map.
    final lay = biomeLayout(c.place)!;
    final sx = lay.spawn.x / 16, sy = lay.spawn.y / 16;
    for (var k = 0; k < 40; k++) {
      final t = k / 39;
      c.teleport((sx - 30 * t + 6 * (k % 5)) * 16, (sy - 50 * t) * 16);
      c.advance(0.05);
    }
    await _openMap(tester, c);
    await tester.pump(const Duration(milliseconds: 700));
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final img = await layer.toImage(const Rect.fromLTWH(0, 0, 1280, 720));
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/preview').createSync(recursive: true);
      File('docs/preview/overworld_map_fog.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
