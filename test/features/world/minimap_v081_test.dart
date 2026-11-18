import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/full_map.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/minimap.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

/// Minimapa con zoom y mapa en grande (tecla M), v0.8.1
/// (docs/specs/exploration.md § "HUD").

GameSprites? _sprites;

/// `WorldScreen` en la zona 1 (dos pisos), con el texto [text].
Future<(ProviderContainer, SessionController)> _field(WidgetTester tester,
    {TextSize text = TextSize.normal}) async {
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
      initial: GameSettings(textSize: text));
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
    child: MaterialApp(
      theme: RetroTheme.build(),
      builder: (context, child) =>
          RetroTextScale(factor: text.factor, child: child!),
      home: const WorldScreen(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final container =
      ProviderScope.containerOf(tester.element(find.byType(WorldScreen)));
  final c = container.read(sessionControllerProvider.notifier);
  final e = c.view!.map.entrances.firstWhere((e) => e.zone == 1);
  c.teleport(e.front.x, e.front.y);
  c.advance(0.05);
  c.handleKey(LogicalKeyboardKey.keyE);
  c.advance(0.05);
  c.setReady(true);
  c.advance(0.05);
  expect(c.view!.mode, SessionMode.field);
  await tester.pump();
  return (container, c);
}

void main() {
  setUpAll(loadRealFonts);

  group('ventana del minimapa', () {
    const b = TileRect(10, 20, 100, 60);
    test('centrada en el jugador', () {
      final r = Minimap.viewRect(b, const Size(40, 28), const Offset(60, 50));
      expect(r, const Rect.fromLTWH(40, 36, 40, 28));
    });
    test('recortada a los bordes del piso', () {
      expect(Minimap.viewRect(b, const Size(40, 28), const Offset(11, 21)),
          const Rect.fromLTWH(10, 20, 40, 28));
      expect(Minimap.viewRect(b, const Size(40, 28), const Offset(200, 200)),
          const Rect.fromLTWH(70, 52, 40, 28));
    });
    test('piso más chico que la ventana: entero', () {
      expect(
          Minimap.viewRect(
              const TileRect(0, 0, 30, 20), const Size(40, 28), Offset.zero),
          const Rect.fromLTWH(0, 0, 30, 20));
      expect(Minimap.viewRect(b, null, Offset.zero),
          const Rect.fromLTWH(10, 20, 100, 60));
    });
  });

  testWidgets('PdI: solo los descubiertos', (tester) async {
    final (_, c) = await _field(tester);
    final m = c.view!.session.mission!;
    MapFloor? withPois;
    for (var i = 0; i < m.floors; i++) {
      final f = c.view!.map.floor(i);
      if (f != null && f.pois.isNotEmpty) withPois = f;
    }
    expect(withPois, isNotNull);
    final seen = Set.of(m.poiSeen);
    m.poiSeen.clear();
    expect(minimapPois(withPois, m), isEmpty);
    final poi = withPois!.pois.firstWhere((p) => p.kind != PoiKind.relic);
    m.poiSeen.add(poi.id);
    expect(minimapPois(withPois, m).map((e) => e.$1.id), [poi.id]);
    m.poiSeen
      ..clear()
      ..addAll(seen);
  });

  testWidgets('HUD: zoom 3 por defecto, rueda y botones cambian el zoom',
      (tester) async {
    final (container, c) = await _field(tester);
    expect(container.read(gameSettingsProvider).minimapZoom, 3);
    final mm =
        tester.widget<Minimap>(find.byKey(const ValueKey('hud-minimap')));
    expect(mm.cell, Minimap.baseCell * 3);
    final v = mm.visible;
    // 40×28 tiles (o el piso entero si es más chico), alrededor del
    // jugador.
    expect(v.width, lessThanOrEqualTo(40.001));
    expect(v.height, lessThanOrEqualTo(28.001));
    final p = Offset(c.local.x / 16, c.local.y / 16);
    expect(v.inflate(0.01).contains(p), isTrue);
    final area = mm.area;
    expect(v.left, greaterThanOrEqualTo(area.x));
    expect(v.right, lessThanOrEqualTo(area.x + area.w + 0.001));
    expect(tester.getSize(find.byKey(const ValueKey('hud-minimap'))).width,
        lessThanOrEqualTo(kMinimapWindow.width + 0.01));

    // Rueda hacia abajo: menos zoom; botón +: vuelve.
    final center = tester.getCenter(find.byKey(const ValueKey('hud-minimap')));
    tester.binding.handlePointerEvent(
        PointerScrollEvent(position: center, scrollDelta: const Offset(0, 40)));
    await tester.pump();
    expect(container.read(gameSettingsProvider).minimapZoom, 2);
    await tester.tap(find.byKey(const ValueKey('minimap-zoom-out')));
    await tester.pump();
    expect(container.read(gameSettingsProvider).minimapZoom, 1);
    final whole =
        tester.widget<Minimap>(find.byKey(const ValueKey('hud-minimap')));
    expect(whole.view, isNull);
    await tester.tap(find.byKey(const ValueKey('minimap-zoom-in')));
    await tester.pump();
    expect(container.read(gameSettingsProvider).minimapZoom, 2);
  });

  testWidgets('M abre y cierra el mapa; el jugador no se mueve; Esc no pausa',
      (tester) async {
    final (_, c) = await _field(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(c.view!.panel, WorldPanel.map);
    expect(find.byKey(const ValueKey('panel-map')), findsOneWidget);
    expect(find.byKey(const ValueKey('full-map-legend')), findsOneWidget);
    expect(find.textContaining('Piedra de paso'), findsOneWidget);

    // Con el mapa abierto las flechas y WASD mueven el mapa, no al
    // jugador.
    final x0 = c.local.x, y0 = c.local.y;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(c.local.x, x0);
    expect(c.local.y, y0);

    // + acerca el mapa.
    final st = tester.state<FullMapState>(find.byType(FullMap));
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    expect(st.zoom, greaterThan(1));

    // M lo cierra.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(c.view!.panel, isNull);
    expect(find.byKey(const ValueKey('panel-map')), findsNothing);

    // Botón MAPA [M] lo abre; Esc lo cierra sin abrir la pausa.
    await tester.tap(find.byKey(const ValueKey('minimap-open-map')));
    await tester.pump();
    expect(c.view!.panel, WorldPanel.map);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.view!.panel, isNull);
    expect(c.menuOpen, isFalse);
  });

  for (final text in [TextSize.normal, TextSize.huge]) {
    testWidgets('mapa en grande sin desbordes (${text.name})', (tester) async {
      await _field(tester, text: text);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(tester.takeException(), isNull);
      final r = tester.getRect(find.byKey(const ValueKey('full-map')));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(1280));
      expect(r.bottom, lessThanOrEqualTo(720));
      final legend =
          tester.getRect(find.byKey(const ValueKey('full-map-legend')));
      expect(legend.bottom, lessThanOrEqualTo(720));
      expect(r.overlaps(legend), isFalse);
      // HUD: los botones del minimapa entran en pantalla.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      final open =
          tester.getRect(find.byKey(const ValueKey('minimap-open-map')));
      expect(open.right, lessThanOrEqualTo(1280));
      expect(tester.takeException(), isNull);
    });
  }
}
