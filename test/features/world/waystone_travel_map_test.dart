import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/full_map.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

/// Mapa en grande en modo "elegir destino" de las piedras de paso
/// (docs/specs/worldgen.md § 11.4, exploration.md § "Mapa en grande").

GameSprites? _sprites;

const _zone = 1;

/// Semilla con 3 piedras de paso en el piso 1 de la zona [_zone].
int _seed() {
  for (var seed = 1; seed < 6000; seed++) {
    final f = MapGenerator.zone(kZones[_zone - 1], seed).floors.first;
    if (f.pois.where((p) => p.kind == PoiKind.waystone).length >= 3) {
      return seed;
    }
  }
  throw StateError('sin semilla');
}

Future<SessionController> _field(WidgetTester tester,
    {bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (_sprites == null) {
    await tester.runAsync(() async {
      _sprites = await GameSprites.load(await SpriteCatalog.load());
    });
  }
  final g = GameSettingsController(
      store: InMemoryGameSettingsStore(),
      initial: GameSettings(reduceMotion: reduceMotion));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider
          .overrideWithValue(sessionEngine(zones: true, seed: _seed())),
      profileStoreProvider.overrideWithValue(InMemoryProfileStore(
          zoneProgression.normalize(PlayerProfile(
              name: 'Ana', classId: 'guerrero', unlockedZone: 1)))),
      sessionClockProvider
          .overrideWithValue(const SessionClock(autoStart: false)),
      gameSpritesProvider.overrideWith((ref) => _sprites!),
      gameSettingsProvider.overrideWith((ref) => g),
    ],
    child: MaterialApp(
      theme: RetroTheme.build(),
      home: const WorldScreen(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final container =
      ProviderScope.containerOf(tester.element(find.byType(WorldScreen)));
  final c = container.read(sessionControllerProvider.notifier);
  // v0.21.0: sin overworld, la zona sale del tablero.
  c.proposeMission(c.zoneStatus(_zone)!.mission!.id);
  c.advance(0.05);
  c.setReady(true);
  c.advance(0.05);
  expect(c.view!.mode, SessionMode.field);
  await tester.pump();
  return c;
}

List<MapPoi> _stones(SessionController c) => c.view!.map
    .floor(c.view!.session.mission!.floor)!
    .pois
    .where((p) => p.kind == PoiKind.waystone)
    .toList();

/// Párese junto a [p] y apriete E.
Future<void> _useStone(
    WidgetTester tester, SessionController c, MapPoi p) async {
  for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
    final x = (p.tx + dx) * 16 + 8.0, y = (p.ty + dy) * 16 + 8.0;
    if (!WorldRules.collides(c.view!.map, x, y, blockVoid: true)) {
      c.teleport(x, y);
      break;
    }
  }
  c.advance(0.05);
  c.handleKey(LogicalKeyboardKey.keyE);
  c.advance(0.05);
  await tester.pump();
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('E en una piedra activada abre el mapa para elegir destino',
      (tester) async {
    final c = await _field(tester);
    final st = _stones(c);
    for (final p in st) {
      await _useStone(tester, c, p);
    }
    expect(c.view!.panel, isNull, reason: 'activar no abre el mapa');
    // Ahora junto a la última: E abre el mapa en modo elegir destino.
    await _useStone(tester, c, st.last);
    expect(c.view!.panel, WorldPanel.map);
    expect(find.byKey(const ValueKey('full-map-choose-hint')), findsOneWidget);
    for (final p in st) {
      expect(find.byKey(ValueKey('full-map-stone-${p.id}')), findsOneWidget);
    }
    expect(find.byKey(ValueKey('full-map-travel-${st[0].id}')), findsOneWidget);
    expect(find.byKey(ValueKey('full-map-travel-${st[1].id}')), findsOneWidget);
    expect(find.byKey(ValueKey('full-map-travel-${st.last.id}')), findsNothing);

    // Clic en la piedra 1 (no es "la siguiente"): viaja y cierra.
    await tester.tap(find.byKey(ValueKey('full-map-stone-${st[0].id}')));
    c.advance(0.05);
    await tester.pump();
    expect(c.view!.panel, isNull);
    expect(
        WorldRules.distance(
            c.local.x, c.local.y, st[0].center.x, st[0].center.y),
        lessThan(20));

    // Teclado: M junto a una piedra activada también elige; tecla 2.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(find.byKey(const ValueKey('full-map-choose-hint')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    c.advance(0.05);
    await tester.pump();
    expect(c.view!.panel, isNull);
    expect(
        WorldRules.distance(
            c.local.x, c.local.y, st[1].center.x, st[1].center.y),
        lessThan(20));

    // Tab + Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    c.advance(0.05);
    await tester.pump();
    expect(c.view!.panel, isNull);
    expect(
        WorldRules.distance(
            c.local.x, c.local.y, st[2].center.x, st[2].center.y),
        lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('M lejos de una piedra: se ven, pero no se elige destino',
      (tester) async {
    final c = await _field(tester);
    final st = _stones(c);
    await _useStone(tester, c, st[0]);
    await _useStone(tester, c, st[1]);
    c.teleport(c.view!.map.spawn.x, c.view!.map.spawn.y);
    c.advance(0.05);
    if (c.travelOrigin != null) return; // spawn pegado a una piedra
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(c.view!.panel, WorldPanel.map);
    expect(find.byKey(const ValueKey('full-map-choose-hint')), findsNothing);
    expect(find.byKey(ValueKey('full-map-stone-${st[0].id}')), findsOneWidget);
    expect(find.byKey(ValueKey('full-map-travel-${st[1].id}')), findsNothing);
    final x = c.local.x;
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(c.local.x, x);
  });

  for (final reduce in [false, true]) {
    testWidgets('parpadeo (reducir movimiento: $reduce)', (tester) async {
      final c = await _field(tester, reduceMotion: reduce);
      final st = _stones(c);
      await _useStone(tester, c, st[0]);
      await _useStone(tester, c, st[1]);
      // Standing at st[1]: M opens the map choosing from it.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      FadeTransition fadeOf(MapPoi p) => tester.widget<FadeTransition>(
          find.descendant(
              of: find.byKey(ValueKey('full-map-stone-${p.id}')),
              matching: find.byType(FadeTransition)));
      final other = fadeOf(st[0]);
      final here = fadeOf(st[1]);
      final a = other.opacity.value;
      await tester.pump(FullMap.blinkPeriod ~/ 2);
      final b = other.opacity.value;
      if (reduce) {
        expect((a, b), (1.0, 1.0));
      } else {
        expect(a, isNot(b));
      }
      // The stone you stand at never pulses and wears the gold frame.
      expect(here.opacity.value, 1.0);
      final box = tester.widget<Container>(find
          .descendant(
              of: find.byKey(ValueKey('full-map-stone-${st[1].id}')),
              matching: find.byType(Container))
          .last);
      final border = (box.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, DsColors.reward);
      // No numbers on the markers.
      for (final p in st) {
        expect(
            find.descendant(
                of: find.byKey(ValueKey('full-map-stone-${p.id}')),
                matching: find.byType(Text)),
            findsNothing);
      }
      // Hover names the stone.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester
          .getCenter(find.byKey(ValueKey('full-map-stone-${st[0].id}'))));
      await tester.pump();
      expect(find.byKey(const ValueKey('full-map-stone-tip')), findsOneWidget);
    });
  }
}
