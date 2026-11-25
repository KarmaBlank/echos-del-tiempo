import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

/// PIEDRAS DE PASO of a biome (biome_regions.md § 4): the region map in
/// pick mode — the same big map the dungeon waystones use — with hover
/// tooltip, detail on the right and TRAVEL.
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

/// Stand at waystone [i] and press E (activates it and opens the panel; E would enter a mine beside it).
Future<void> _use(WidgetTester tester, SessionController c, int i) async {
  final w = biomeLayout(c.place)!.waystones[i];
  c.closePanel();
  c.teleport((w.ax + 0.5) * 16, (w.ay + 0.5) * 16);
  c.advance(0.05);
  expect(c.nearWaystone, i);
  c.useWaystone(i);
  c.advance(0.05);
  await tester.pump();
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('opens the region map: marks, hover, detail, TRAVEL',
      (tester) async {
    final c = await _biome(tester);
    final lay = biomeLayout(c.place)!;
    final n = lay.waystones.length;
    // Activate every stone except the last one.
    for (var i = 0; i < n - 1; i++) {
      await _use(tester, c, i);
    }
    await _use(tester, c, 0);
    expect(c.view!.panel, WorldPanel.waystone);
    expect(find.byKey(const ValueKey('panel-waystone')), findsOneWidget);
    // It is the big map, with every stone marked (found or not).
    expect(find.byKey(const ValueKey('full-map')), findsOneWidget);
    for (var i = 0; i < n; i++) {
      expect(find.byKey(ValueKey('full-map-stone-$i')), findsOneWidget);
    }
    // The undiscovered one is grey.
    final grey = tester.widget<Container>(find.descendant(
        of: find.byKey(ValueKey('full-map-stone-${n - 1}')),
        matching: find.byType(Container)));
    expect((grey.decoration! as BoxDecoration).color, DsColors.textDisabled);

    // Opens on the stone you stand at: HERE, TRAVEL grey.
    expect(find.byKey(const ValueKey('way-here')), findsOneWidget);
    expect(
        tester
            .widget<DsButton>(find.byKey(const ValueKey('way-go-0')))
            .onPressed,
        isNull);

    // Hover names the stone.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('full-map-stone-1'))));
    await tester.pump();
    expect(find.byKey(const ValueKey('full-map-stone-tip')), findsOneWidget);

    // The undiscovered one: selectable, explained, no TRAVEL.
    await tester.tap(find.byKey(ValueKey('full-map-stone-${n - 1}')));
    await tester.pump();
    expect(
        tester
            .widget<DsButton>(find.byKey(ValueKey('way-go-${n - 1}')))
            .onPressed,
        isNull);

    // Click stone 1 selects it (does not travel yet); TRAVEL goes.
    await tester.tap(find.byKey(const ValueKey('full-map-stone-1')));
    await tester.pump();
    expect(c.view!.panel, WorldPanel.waystone);
    expect(find.byKey(const ValueKey('way-here')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('way-go-1')));
    c.advance(0.05);
    await tester.pump();
    expect(c.view!.panel, isNull);
    expect(c.nearWaystone, 1);
    expect(tester.takeException(), isNull);
  });

  // `WAYSTONE_MAP_PREVIEW=1 flutter test <this file>` writes
  // docs/preview/waystone_map.png (1280×720, real UI).
  testWidgets('preview: waystone map', (tester) async {
    if (Platform.environment['WAYSTONE_MAP_PREVIEW'] == null) return;
    final c = await _biome(tester);
    final n = biomeLayout(c.place)!.waystones.length;
    for (var i = 0; i < n - 1; i++) {
      await _use(tester, c, i);
    }
    await _use(tester, c, 0);
    await tester.tap(find.byKey(const ValueKey('full-map-stone-1')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('full-map-stone-1'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final img = await layer.toImage(const Rect.fromLTWH(0, 0, 1280, 720));
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/preview').createSync(recursive: true);
      File('docs/preview/waystone_map.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
