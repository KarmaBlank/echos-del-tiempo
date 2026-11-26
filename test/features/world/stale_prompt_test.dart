import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_portal_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// The `[E] ...` prompt follows the hero every tick: it shows in front of
/// the spot and goes away when walking off (v0.49.22 stale prompt).
void main() {
  tearDown(() => BiomeRegions.bind(0));

  Future<SessionController> boot() async {
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: InMemoryProfileStore(newProfile('Ana', 'guerrero')),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(c.dispose);
    await c.start();
    return c;
  }

  /// Walks with the real input path (updateLocal + ticks).
  void walk(SessionController c, double ix, double iy, double seconds) {
    for (var t = 0.0; t < seconds; t += 0.05) {
      c.updateLocal(0.05, ix, iy);
      c.advance(0.05);
    }
  }

  test('Eco portal prompt shows in front and clears when walking away',
      () async {
    final c = await boot();
    final spot = EcoPortalRules.all.first;
    expect(c.travelPlace(spot.biome), isTrue);
    c.advance(0.05);
    c.teleport(spot.front.x, spot.front.y);
    c.advance(0.05);
    expect(c.nearEcoPortal, spot.zone);
    expect(c.view!.prompt, WorldPrompt.ecoZone);
    walk(c, 0, 1, 3);
    expect(c.nearEcoPortal, isNull);
    expect(c.view!.prompt, isNot(WorldPrompt.ecoZone));
  });

  test('waystone prompt shows in front and clears when walking away',
      () async {
    final c = await boot();
    final lay = kBiomeLayouts.values.firstWhere((l) => l.waystones.isNotEmpty);
    expect(c.travelPlace(lay.id), isTrue);
    c.advance(0.05);
    final w = lay.waystones.first;
    c.teleport((w.x + 0.5) * 16, (w.y + 1.5) * 16);
    c.advance(0.05);
    if (c.nearWaystone == null) return; // layout without a free front tile
    expect(c.view!.promptText, isNotNull);
    final shown = c.view!.promptText;
    walk(c, 0, 1, 3);
    expect(c.nearWaystone, isNull);
    expect(c.view!.promptText, isNot(shown));
  });
}
