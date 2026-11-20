// Capturas antes / despuÃ©s del HUD, el tÃ­tulo, el sello de misiones, la
// pausa y ATRIBUTOS â€º VISTA PREVIA migrados al sistema de diseÃ±o
// (v0.12.0, docs/specs/design_system.md Â§ 10.3). NO es parte de la suite.
// Correr con
//   $env:SHOT_SUFFIX="antes"; flutter test tool/shots/ds_hud_shots_test.dart
// (antes de migrar) o con "despues" (por defecto) en la rama.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/core/settings/crt_filter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/lobby/title_screen_test.dart' show threeCharacters;
import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.12.0';
final _suffix = Platform.environment['SHOT_SUFFIX'] ?? 'despues';
const _size = Size(1280, 720);
const _dpr = 1.5;

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & (_size * _dpr));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/${name}_$_suffix.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _setup(WidgetTester tester) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = _size * _dpr;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    _sprites = await GameSprites.load(await SpriteCatalog.load());
    await CrtShaders.load();
  });
}

late GameSprites _sprites;

List<Override> _settings() => [
      gameSettingsProvider.overrideWith((ref) => GameSettingsController(
          store: InMemoryGameSettingsStore(), initial: const GameSettings())),
    ];

/// La app real en el pueblo con Ana (nivel 30, zona 1 abierta).
Future<SessionController> _world(WidgetTester tester) async {
  await tester.pumpWidget(EcosApp(
    overrides: [
      ..._settings(),
      sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
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
  return ProviderScope.containerOf(tester.element(find.byType(WorldScreen)))
      .read(sessionControllerProvider.notifier);
}

void main() {
  testWidgets('01 HUD en el pueblo', (tester) async {
    await _setup(tester);
    await _world(tester);
    await _settle(tester, 300);
    await _shot(tester, '01_hud_pueblo');
  });

  testWidgets('02 HUD en misiÃ³n', (tester) async {
    await _setup(tester);
    final c = await _world(tester);
    final e = c.view!.map.entrances.firstWhere((e) => e.zone == 1);
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(e.front.x, e.front.y);
    c.advance(0.05);
    c.handleKey(LogicalKeyboardKey.keyE);
    c.advance(0.05);
    c.setReady(true);
    c.advance(0.05);
    expect(c.view!.mode, SessionMode.field);
    await _settle(tester, 300);
    await _shot(tester, '02_hud_mision');
  });

  testWidgets('03 tÃ­tulo', (tester) async {
    await _setup(tester);
    final repo = AccountRepository(InMemoryAccountStore(threeCharacters()));
    await tester.pumpWidget(EcosApp(
      overrides: [
        ..._settings(),
        sessionEngineProvider.overrideWithValue(sessionEngine()),
        profileStoreProvider
            .overrideWithValue(SelectedCharacterProfileStore(repo)),
        accountRepositoryProvider.overrideWithValue(repo),
        gameSpritesProvider
            .overrideWith((ref) => Completer<GameSprites>().future),
      ],
      home: TitleScreen(onStart: () {}),
    ));
    await _settle(tester, 300);
    await _shot(tester, '03_titulo');
  });

  testWidgets('04 sello de misiones', (tester) async {
    await _setup(tester);
    final c = await _world(tester);
    c.openPanel(WorldPanel.missionBoard);
    await _settle(tester, 300);
    await _shot(tester, '04_sello_misiones');
  });

  testWidgets('05 pausa', (tester) async {
    await _setup(tester);
    await _world(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester, 300);
    await _shot(tester, '05_pausa');
  });

  testWidgets('06 ATRIBUTOS vista previa', (tester) async {
    await pumpPanel(tester,
        devicePixelRatio: _dpr,
        profile: progression.normalize(
            PlayerProfile(name: 'Ana', classId: 'maga', level: 8, points: 3)),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.attributes));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('inc-vit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('inc-esp')));
    await tester.pump();
    await _shot(tester, '06_atributos_vista_previa');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
