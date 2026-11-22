import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_minigame.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_fishing.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

/// El pueblo en pantalla con el jugador en la orilla del lago, para la
/// pesca en el mapa (fishing.md § 4): lo usan el test de la barra y las
/// capturas de v0.22.2.
class FishingMapHarness {
  FishingMapHarness(this.tester, this.c, this.game);
  final WidgetTester tester;
  final SessionController c;
  final MapGame game;

  static Future<FishingMapHarness> pump(WidgetTester tester,
      {PlayerProfile? profile}) async {
    late GameSprites sprites;
    await tester.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore(
            zoneProgression.normalize(profile ??
                PlayerProfile(
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
    final game = tester.widget<GameWidget<MapGame>>(
            find.byType(GameWidget<MapGame>))
        .game!;
    final h = FishingMapHarness(tester, c, game);
    // Orilla este del lago, mirando al agua (oeste).
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(11.5 * 16, 16.5 * 16);
    await h.frames(10);
    return h;
  }

  Future<void> frames(int n) async {
    for (var i = 0; i < n; i++) {
      c.advance(0.033);
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  MapFishing get f => c.mapFishing!;

  /// Saca la caña, carga [chargeFrames] cuadros y tira.
  Future<void> cast({int chargeFrames = 14}) async {
    expect(c.startFishing(), isTrue);
    c.fishPress();
    await frames(chargeFrames);
    c.fishRelease();
    await frames(20);
  }

  /// Fuerza la picada real (sin esperar el azar).
  Future<void> forceBite() async {
    while (f.phase == FishPhase.waiting) {
      f.game.biteAt = 0;
      await frames(1);
    }
  }

  /// Clava y arranca la barra con [fish] (lo que mandaría el host).
  Future<void> forceReel(FishCatch fish) async {
    await forceBite();
    c.fishPress();
    await frames(1);
    f.game.hook(fish);
    await frames(8);
  }

  static FishCatch get sample => const FishCatch('trucha_cobre', 41);
  static String get sampleName => kFish['trucha_cobre']!.name;
}
