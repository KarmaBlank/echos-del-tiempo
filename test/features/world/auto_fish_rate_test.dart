import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_minigame.dart';

/// Solo auto-fishing at the town lake catches at the expected rate
/// (fishing.md § 6): standing still with the game calling `updateLocal`
/// every frame, as the map does.
void main() {
  setUp(() => kTuning[TuningId.fishing] = TuningDef('Pesca', {
        ...kTuningDefaults[TuningId.fishing]!.values,
        'lootChance': 0,
        'lootPityAfter': 0,
      }));
  tearDown(
      () => kTuning[TuningId.fishing] = kTuningDefaults[TuningId.fishing]!);

  test('solo: auto-fishing catches fish every few seconds', () async {
    final p =
        progression.normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'));
    final c = SessionController(
      engine: sessionEngine(),
      store: InMemoryProfileStore(p),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(() {
      if (c.mounted) c.dispose();
    });
    await c.start();
    final stops = <FishAutoStoppedEvent>[];
    c.events.listen((e) {
      if (e is FishAutoStoppedEvent) stops.add(e);
    });
    c.advance(0.2);
    final spot = TownLayout.fishingSpots.first;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((spot.$1 + 1) * 16.0 + 4, (spot.$2 + 0.5) * 16.0);
    c.advance(0.1);
    expect(c.startFishing(), isTrue);
    c.updateLocal(1 / 60, 0, 0);
    c.advance(1 / 60);
    expect(c.handleKey(LogicalKeyboardKey.keyR), isTrue);
    expect(c.autoFishing, isTrue);
    const sec = 180;
    for (var i = 0; i < sec * 60; i++) {
      c.updateLocal(1 / 60, 0, 0);
      c.advance(1 / 60);
      await pumpEventQueue(times: 1);
    }
    expect(stops, isEmpty, reason: 'nothing should stop it');
    expect(c.autoFishing, isTrue);
    // Expected ~one catch per 10-20 s (autoWaitMult × bite delay / chance).
    expect(c.autoFishCaught, greaterThanOrEqualTo(sec ~/ 30));
  });

  test('R right after a miss (lost) still turns auto-fishing on', () async {
    final p =
        progression.normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'));
    final c = SessionController(
      engine: sessionEngine(),
      store: InMemoryProfileStore(p),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(() {
      if (c.mounted) c.dispose();
    });
    await c.start();
    c.advance(0.2);
    final spot = TownLayout.fishingSpots.first;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((spot.$1 + 1) * 16.0 + 4, (spot.$2 + 0.5) * 16.0);
    c.advance(0.1);
    expect(c.startFishing(), isTrue);
    c.mapFishing!.game.phase = FishPhase.lost;
    expect(c.handleKey(LogicalKeyboardKey.keyR), isTrue);
    expect(c.autoFishing, isTrue);
  });

  test('R at the shore with the rod away starts auto-fishing', () async {
    final p =
        progression.normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'));
    final c = SessionController(
      engine: sessionEngine(),
      store: InMemoryProfileStore(p),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(() {
      if (c.mounted) c.dispose();
    });
    await c.start();
    c.advance(0.2);
    final spot = TownLayout.fishingSpots.first;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((spot.$1 + 1) * 16.0 + 4, (spot.$2 + 0.5) * 16.0);
    c.advance(0.1);
    expect(c.canFish, isTrue);
    expect(c.handleKey(LogicalKeyboardKey.keyR), isTrue);
    expect(c.mapFishing, isNotNull);
    expect(c.autoFishing, isTrue);
  });
}