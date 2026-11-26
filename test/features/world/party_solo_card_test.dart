import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import '../../game_engine/session_test_helpers.dart';

/// Solo party card (v0.49.22): a long name with its ascension keeps the
/// full text size (the card grows), never shrunk to unreadable.
void main() {
  setUpAll(loadRealFonts);

  for (final size in [const Size(1920, 1080), const Size(1280, 720)]) {
    testWidgets('solo card at full text size ($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = zoneProgression
          .normalize(PlayerProfile(
              name: 'KarmonaPal', classId: 'paladin', level: 50))
          .copyWith(
              ascension:
                  const AscensionProgress(id: 'guardian', trials: {1, 2, 3}));
      final c = SessionController(
          engine: sessionEngine(zones: true),
          store: InMemoryProfileStore(p),
          clock: const SessionClock(autoStart: false));
      addTearDown(c.dispose);
      await tester.runAsync(c.start);
      c.travelPlace(kBosque);
      c.advance(0.05);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
          profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
          sessionClockProvider
              .overrideWithValue(const SessionClock(autoStart: false)),
          gameSettingsProvider.overrideWith((ref) => GameSettingsController(
              store: InMemoryGameSettingsStore(),
              initial: const GameSettings())),
        ],
        child: MaterialApp(
          theme: RetroTheme.build(),
          // The game's real text scaler (VT323 at the window size).
          builder: (context, child) =>
              RetroTextScale(factor: 1, child: child!),
          home: Scaffold(
              body: WorldHud(
                  view: c.view!, controller: c, chatFocus: FocusNode())),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final me = c.view!.session.playerList.single;
      final name = find.byKey(ValueKey('hud-name-${me.id}'));
      final text = tester.renderObject<RenderParagraph>(
          find.descendant(of: name, matching: find.byType(RichText)));
      // Room for the whole line: the FittedBox does not shrink it.
      expect(tester.getSize(name).width,
          greaterThanOrEqualTo(text.size.width - 0.5));
      expect(text.didExceedMaxLines, isFalse);
      expect(text.text.toPlainText(), contains('Guardián'));
      // The row is not scaled down either (one member).
      final card = tester.getSize(find.byKey(ValueKey('hud-party-${me.id}')));
      final box = tester.renderObject<RenderBox>(
          find.byKey(ValueKey('hud-compact-${me.id}')));
      expect(card.width, closeTo(box.size.width, 0.5));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
