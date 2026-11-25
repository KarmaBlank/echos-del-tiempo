import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_panel.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/minimap.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

// exploration.md § "HUD" / free_movement.md § 2.4-2.5: no mission banner, the exit
// button on top without overlaps, time under the minimap, exit portal,
// and the card of a player elsewhere with UNIRSE.
void main() {
  testWidgets('dungeon HUD: exit button clear, time under the minimap',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final engine = sessionEngine(zones: true, freeMovement: true);
    final c = SessionController(
      engine: engine,
      store: InMemoryProfileStore(zoneProgression.normalize(PlayerProfile(
          name: 'Ana', classId: 'guerrero', level: 5, unlockedZone: 1))),
      clock: const SessionClock(autoStart: false),
    );
    await c.start();
    addTearDown(c.dispose);
    c.proposeMission(c.zoneStatus(1)!.mission!.id);
    c.advance(0.05);
    c.setReady(true);
    c.advance(0.05);
    expect(c.view!.mode, SessionMode.field);
    expect(c.canLeaveDungeon, isTrue);
    expect(
        MapGame.dungeonExitAt(c.view!, freeMovement: true, run: false),
        isNotNull);
    c.view!.session.away = const [
      AwayPlayer('p9', 'Beto', 'Bosque', 'bosque'),
      AwayPlayer('p8', 'Caro', 'Cripta', 'm:x', true),
    ];
    final g = GameSettingsController(
        store: InMemoryGameSettingsStore(), initial: const GameSettings());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(engine),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
        sessionClockProvider
            .overrideWithValue(const SessionClock(autoStart: false)),
        gameSettingsProvider.overrideWith((ref) => g),
      ],
      child: MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(
          body: WorldHud(
              view: c.view!,
              controller: c,
              chatFocus: FocusNode(),
              onExit: () {},
              onMenu: () {}),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('hud-mission-bar')), findsNothing);
    final exit = tester.getRect(find.byKey(const ValueKey('hud-leave-dungeon')));
    final mini = tester.getRect(find
        .ancestor(of: find.byType(Minimap), matching: find.byType(RetroPanel))
        .first);
    final obj = tester.getRect(find.byKey(const ValueKey('hud-objectives')));
    expect(exit.overlaps(mini), isFalse);
    expect(exit.overlaps(obj), isFalse);
    final time = tester.getRect(find.byKey(const ValueKey('hud-mission-time')));
    expect(time.top, greaterThanOrEqualTo(mini.bottom));
    // Players elsewhere: dimmed card with where + UNIRSE (grey if busy).
    expect(find.byKey(const ValueKey('hud-away-where-p9')), findsOneWidget);
    expect(tester.widget<DsButton>(find.byKey(const ValueKey('hud-join-p9')))
        .onPressed, isNotNull);
    expect(tester.widget<DsButton>(find.byKey(const ValueKey('hud-join-p8')))
        .onPressed, isNull);
    // Late join (free_movement.md § 2.1.1): UNIRSE, grey with the reason.
    final busy = tester.widget<DsButton>(find.byKey(const ValueKey('hud-join-p8')));
    expect(busy.label, 'UNIRSE');
    expect(busy.tooltip, contains('Caro'));
    expect(tester.widget<DsButton>(find.byKey(const ValueKey('hud-join-p9')))
        .tooltip, isNull);
    expect(tester.takeException(), isNull);
  });
}
