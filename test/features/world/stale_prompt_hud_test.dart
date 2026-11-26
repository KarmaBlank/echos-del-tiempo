import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_portal_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import '../../game_engine/session_test_helpers.dart';

void main() {
  setUpAll(loadRealFonts);
  tearDown(() => BiomeRegions.bind(0));

  for (final expanded in [false, true]) {
    testWidgets('HUD prompt follows the hero (expanded: $expanded)',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = SessionController(
        engine: sessionEngine(zones: true),
        store: InMemoryProfileStore(newProfile('KarmonaPal', 'guerrero')),
        clock: const SessionClock(autoStart: false),
      );
      addTearDown(c.dispose);
      await tester.runAsync(c.start);
      final g = GameSettingsController(
          store: InMemoryGameSettingsStore(),
          initial: GameSettings(partyExpanded: expanded));
      Future<void> pump() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
            profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
            sessionClockProvider
                .overrideWithValue(const SessionClock(autoStart: false)),
            gameSettingsProvider.overrideWith((ref) => g),
          ],
          child: MaterialApp(
            theme: RetroTheme.build(),
            builder: (context, child) =>
                RetroTextScale(factor: 1, child: child!),
            home: Scaffold(
                body: WorldHud(
                    view: c.view!, controller: c, chatFocus: FocusNode())),
          ),
        ));
        expect(tester.takeException(), isNull);
      }

      final spot = EcoPortalRules.all.first;
      expect(c.travelPlace(spot.biome), isTrue);
      c.advance(0.05);
      await pump();
      expect(find.byKey(const ValueKey('hud-prompt')), findsNothing);
      c.teleport(spot.front.x, spot.front.y);
      c.advance(0.05);
      await pump();
      expect(find.text('[E] Portal de Ecos', findRichText: true),
          findsOneWidget);
      for (var t = 0.0; t < 3; t += 0.05) {
        c.updateLocal(0.05, 0, 1);
        c.advance(0.05);
        await pump();
      }
      expect(find.text('[E] Portal de Ecos', findRichText: true),
          findsNothing);

      // Solo: the party card keeps its natural size (never scaled down).
      final me = c.view!.session.playerList.single;
      final card = tester.getSize(find.byKey(ValueKey('hud-party-${me.id}')));
      expect(card.width, greaterThanOrEqualTo(200));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
