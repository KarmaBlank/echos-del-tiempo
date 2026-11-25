import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Hold-to-gather with the mouse (cozy_life.md § 3, v0.49.9).
void main() {
  tearDown(() => BiomeRegions.bind(0));

  Future<(SessionController, int, (int, int))> atBush() async {
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: InMemoryProfileStore(newProfile('Ana', 'guerrero')),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(c.dispose);
    await c.start();
    c.debugTown((t) => t.copyWith(sky: t.sky.copyWith(seed: 3, day: 1)));
    expect(c.travelPlace(kBosque), isTrue);
    BiomeRegions.bind(3);
    final lay = biomeLayout(kBosque)!;
    final f = lay.forage.first;
    c.teleport((f.x + 0.5) * 16 + 14, (f.y + 0.5) * 16);
    c.advance(0.05);
    expect(c.nearForage, 0);
    return (c, 0, (f.x, f.y));
  }

  test('holding the click on a bush gathers it', () async {
    final (c, i, tile) = await atBush();
    expect(c.gatherPress(tile), isTrue);
    expect(c.gatherProgress, isNotNull);
    await Future<void>.delayed(
        Duration(milliseconds: (c.gatherSec * 1000).round() + 250));
    c.advance(0.05);
    expect(c.gatherProgress, isNull);
    expect(BiomeRules.regrowIn(c.town, kBosque, i, c.session!.time),
        greaterThan(0),
        reason: 'the bush was picked');
  });

  test('releasing the click cancels the gather', () async {
    final (c, i, tile) = await atBush();
    expect(c.gatherPress(tile), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    c.gatherHoldEnd();
    expect(c.gatherProgress, isNull);
    await Future<void>.delayed(
        Duration(milliseconds: (c.gatherSec * 1000).round() + 100));
    c.advance(0.05);
    expect(BiomeRules.regrowIn(c.town, kBosque, i, c.session!.time), 0);
  });

  test('a click far from any bush does nothing', () async {
    final (c, _, tile) = await atBush();
    expect(c.gatherPress((tile.$1 + 9, tile.$2 + 9)), isFalse);
    expect(c.gatherProgress, isNull);
  });
}
