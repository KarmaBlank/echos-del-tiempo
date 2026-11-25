import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/world_events_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_event_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// A roaming elite does not talk: E near it starts its fight
/// (biome_exploration.md § 6).
void main() {
  const elite =
      ActiveWorldEvent('explore_elite', biome: kBosque, start: 1, end: 9);

  test('talks: elite no, visitor yes, explicit flag wins', () {
    expect(WorldEventRules.talks(kWorldEvents.def('explore_elite')!), isFalse);
    expect(WorldEventRules.talks(kWorldEvents.def('explore_merchant')!),
        isTrue);
    final d = WorldEventDef.fromJson(
        {...kWorldEvents.def('explore_elite')!.toJson(), 'talks': true});
    expect(d.talks, isTrue);
    expect(WorldEventRules.talks(d), isTrue);
  });

  test('E near the elite: fight vote, no dialogue; prompt', () async {
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: InMemoryProfileStore(newProfile('Ana', 'guerrero')),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(c.dispose);
    await c.start();
    expect(c.travelPlace(kBosque), isTrue);
    c.debugTown((t) => t.copyWith(
        events: const WorldEventsState(seed: 1, last: 1, active: [elite])));
    final (x, y) = WorldEventRules.spot(c.town, elite)!;
    c.teleport(x, y);
    c.advance(0.05);
    expect(c.nearWorldEvent?.uid, elite.uid);
    expect(
        c.view!.promptText,
        c.strings.t('ui.town.events.prompt_fight',
            {'name': kWorldEvents.def('explore_elite')!.title.text}));
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    c.advance(0.05);
    expect(c.view!.panel, isNot(WorldPanel.worldEvent));
    expect(c.session!.rift, elite.uid);
    c.advance(0.05);
    expect(c.session!.mode, SessionMode.prep);
  });
}
