import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_loading.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

void main() {
  testWidgets('Cargando el mundo: tapa el mundo hasta precocinarlo',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late GameSprites sprites;
    await tester.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
    });
    await tester.pumpWidget(EcosApp(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore(
            zoneProgression.normalize(
                PlayerProfile(name: 'Ana', classId: 'guerrero')))),
        sessionClockProvider
            .overrideWithValue(const SessionClock(autoStart: false)),
        gameSpritesProvider.overrideWith((ref) => sprites),
        gameSettingsProvider.overrideWith((ref) => GameSettingsController(
            store: InMemoryGameSettingsStore(),
            initial: const GameSettings())),
      ],
      home: const WorldLoadingScreen(warmFrames: 3),
    ));
    expect(find.text('Cargando el mundo…'), findsOneWidget);
    expect(find.byType(WorldScreen), findsNothing);
    for (var i = 0; i < 20 && find.byType(WorldScreen).evaluate().isEmpty;
        i++) {
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(WorldScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('world-loading')), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const ValueKey('world-loading')), findsNothing);
  });
}
