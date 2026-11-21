// Capturas de las piedras de paso en el mapa grande y del modo "elegir
// destino" (v0.20.6, docs/specs/worldgen.md § 11.4). NO es parte de la
// suite. Correr con
//   flutter test tool/shots/v0206_estatuas_shots_test.dart
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/core/settings/crt_filter.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/game_engine/session_test_helpers.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.20.6/estatuas';
const _size = Size(1280, 720);
const _dpr = 1.5;

late GameSprites _sprites;

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & (_size * _dpr));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

int _seed() {
  for (var seed = 1; seed < 6000; seed++) {
    final f = MapGenerator.zone(kZones[0], seed).floors.first;
    if (f.pois.where((p) => p.kind == PoiKind.waystone).length >= 3) {
      return seed;
    }
  }
  throw StateError('sin semilla');
}

Future<SessionController> _field(WidgetTester tester) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = _size * _dpr;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    _sprites = await GameSprites.load(await SpriteCatalog.load());
    await CrtShaders.load();
  });
  await tester.pumpWidget(EcosApp(
    overrides: [
      gameSettingsProvider.overrideWith((ref) => GameSettingsController(
          store: InMemoryGameSettingsStore(), initial: const GameSettings())),
      sessionEngineProvider
          .overrideWithValue(sessionEngine(zones: true, seed: _seed())),
      profileStoreProvider.overrideWithValue(InMemoryProfileStore(
          zoneProgression.normalize(PlayerProfile(
              name: 'Ana', classId: 'guerrero', level: 30, unlockedZone: 1)))),
      sessionClockProvider
          .overrideWithValue(const SessionClock(autoStart: false)),
      gameSpritesProvider.overrideWith((ref) => _sprites),
    ],
    home: const WorldScreen(),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final c = ProviderScope.containerOf(tester.element(find.byType(WorldScreen)))
      .read(sessionControllerProvider.notifier);
  final e = c.view!.map.entrances.firstWhere((e) => e.zone == 1);
  c.teleport(e.front.x, e.front.y);
  c.advance(0.05);
  c.handleKey(LogicalKeyboardKey.keyE);
  c.advance(0.05);
  c.setReady(true);
  c.advance(0.05);
  await tester.pump();
  return c;
}

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
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('piedras de paso en el mapa grande', (tester) async {
    final c = await _field(tester);
    final st = c.view!.map
        .floor(0)!
        .pois
        .where((p) => p.kind == PoiKind.waystone)
        .toList();
    // Base: el mapa recién entrado, sin piedras descubiertas.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump(const Duration(milliseconds: 360));
    await _shot(tester, '01_base_mapa');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    for (final p in st) {
      await _useStone(tester, c, p);
    }
    // Cartel de E junto a una piedra activada.
    await tester.pump(const Duration(milliseconds: 100));
    await _shot(tester, '02_cartel_elegir_destino');
    // M lejos de una piedra: se ven las piedras, sin elegir destino.
    c.teleport(c.view!.map.spawn.x, c.view!.map.spawn.y);
    c.advance(0.05);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump(const Duration(milliseconds: 700));
    await _shot(tester, '03_mapa_piedras_marcadas');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    // E en una piedra: modo elegir destino.
    await _useStone(tester, c, st.last);
    await tester.pump(const Duration(milliseconds: 700));
    await _shot(tester, '04_elegir_destino');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 700));
    await _shot(tester, '05_elegir_destino_tab');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    c.advance(0.05);
    await tester.pump(const Duration(milliseconds: 100));
    await _shot(tester, '06_despues_del_viaje');
  });
}
