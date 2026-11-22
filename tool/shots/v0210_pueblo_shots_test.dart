// Capturas del pueblo nuevo (v0.21.0, docs/specs/town_loop.md § 11.2):
// el mapa entero, el juego en el pueblo y la cinemática de partida. NO
// es parte de la suite. Correr con
//   flutter test tool/shots/v0210_pueblo_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/game_engine/session_test_helpers.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.21.0';
const _size = Size(1280, 720);

Future<void> _write(String name, ui.Image img) async {
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File('$_out/$name.png');
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes!.buffer.asUint8List());
}

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    await _write(name, await layer.toImage(Offset.zero & _size));
  });
}

void main() {
  testWidgets('mapa entero del pueblo (×3)', (tester) async {
    final m = MapGenerator.town();
    const k = 3.0;
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec)..scale(k);
    final p = TilePainter();
    for (var y = 0; y < m.height; y++) {
      for (var x = 0; x < m.width; x++) {
        p.draw(c, m.tileAt(x, y), x * 16.0, y * 16.0, m.theme, x, y,
            t: 600, gateOpen: false, lobby: m.lobby);
      }
    }
    final pic = rec.endRecording();
    await tester.runAsync(() async {
      await _write(
          'pueblo_mapa',
          await pic.toImage(
              (m.width * 16 * k).round(), (m.height * 16 * k).round()));
    });
  });

  testWidgets('en el pueblo y partida a la zona 1', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late GameSprites sprites;
    await tester.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore(
            zoneProgression.normalize(PlayerProfile(
                name: 'Ana', classId: 'guerrero', unlockedZone: 1)))),
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
    for (var i = 0; i < 10; i++) {
      c.advance(0.05);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _shot(tester, 'pueblo_spawn');
    // Frente al lago (cartel "Pronto").
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(12.5 * 16, 16.4 * 16);
    for (var i = 0; i < 10; i++) {
      c.advance(0.05);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _shot(tester, 'pueblo_lago');
    c.proposeMission(c.zoneStatus(1)!.mission!.id);
    c.advance(0.05);
    await tester.pump();
    c.setReady(true);
    c.advance(0.05);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 1200));
    await _shot(tester, 'partida');
    await tester.pump(const Duration(seconds: 4));
  });
}
