// Capturas de v0.13.0: sala de 8 jugadores (HUD del mundo y batalla) a
// 1920×1080. NO es parte de la suite. Correr con
//   flutter test tool/shots/v0130_8_jugadores_shots_test.dart
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
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/game_engine/session_test_helpers.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.13.0';
const _size = Size(1920, 1080);
const _classes = ['guerrero', 'maga', 'tirador', 'paladin'];
const _names = ['Ana', 'Leo', 'Mia', 'Cid', 'Bea', 'Tomás', 'Uma', 'Rocío'];

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & _size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('8 jugadores: HUD y batalla', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late GameSprites sprites;
    final hub = LoopbackHub();
    final hostNet = LoopbackNetSession(hub);
    final hp = newProfile(_names[0], _classes[0]);
    await tester.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
      await CrtShaders.load();
      await hostNet.connect(SessionConfig(profile: hp));
    });
    await tester.pumpWidget(EcosApp(
      overrides: [
        gameSettingsProvider.overrideWith((ref) => GameSettingsController(
            store: InMemoryGameSettingsStore(),
            initial: const GameSettings())),
        sessionEngineProvider.overrideWithValue(sessionEngine()),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore(hp)),
        sessionClockProvider
            .overrideWithValue(const SessionClock(autoStart: false)),
        gameSpritesProvider.overrideWith((ref) => sprites),
        activeNetSessionProvider.overrideWith((ref) => hostNet),
      ],
      home: const WorldScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final host =
        ProviderScope.containerOf(tester.element(find.byType(WorldScreen)))
            .read(sessionControllerProvider.notifier);
    final clients = <SessionController>[];
    await tester.runAsync(() async {
      for (var i = 1; i < 8; i++) {
        final n = LoopbackNetSession(hub);
        final p = newProfile(_names[i], _classes[i % 4]);
        await n.connect(SessionConfig(profile: p, roomCode: hostNet.roomCode));
        final c = SessionController(
          engine: sessionEngine(),
          store: InMemoryProfileStore(p),
          clock: const SessionClock(autoStart: false),
          net: n,
        );
        await c.start();
        clients.add(c);
      }
    });
    Future<void> net([double s = 0.05]) async {
      await tester.runAsync(() async {
        for (final c in clients) {
          c.advance(0.05);
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
        host.advance(s);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      await tester.pump(const Duration(milliseconds: 50));
    }

    await net();
    host.proposeMission('m1');
    await net();
    for (final c in [host, ...clients]) {
      c.vote(true);
    }
    await net(0.1);
    for (final c in [host, ...clients]) {
      c.setReady(true);
    }
    await net(0.1);
    expect(host.view!.mode, SessionMode.field);
    for (var i = 0; i < 6; i++) {
      await net();
    }
    await _shot(tester, '01_hud_8_jugadores');

    await net(host.session!.graceLeft + 0.1);
    final en = host.session!.mission!.enemies
        .firstWhere((e) => e.alive && !e.boss && !e.elite);
    // ignore: invalid_use_of_visible_for_testing_member
    host.teleport(en.x, en.y);
    for (var i = 0; i < 4; i++) {
      await net();
    }
    expect(host.view!.mode, SessionMode.battle);
    for (var i = 0; i < 40; i++) {
      await net();
    }
    await _shot(tester, '02_batalla_8_jugadores');
    for (final c in clients) {
      c.dispose();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
