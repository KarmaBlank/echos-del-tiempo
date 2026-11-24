import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/world_event_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/world_events_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_event_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/ds_harness.dart';
import '../../game_engine/session_test_helpers.dart';

/// Event NPCs talk through the real dialogue box (world_events.md § 3.6,
/// ui_minimal.md § 10.1): greeting, topics with VOLVER and actions.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 300; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  const visitor =
      ActiveWorldEvent('visitor_clockmaker', biome: kPueblo, start: 1, end: 9);
  const rift = ActiveWorldEvent('echo_rift', biome: kBosque, start: 1, end: 9);

  Future<SessionController> controller() async {
    final c = SessionController(
      engine: sessionEngine(),
      store: InMemoryProfileStore(
          PlayerProfile(name: 'Ana', classId: 'guerrero')),
      clock: const SessionClock(autoStart: false),
    );
    await c.start();
    c.debugTown((t) => t.copyWith(
        events: const WorldEventsState(
            seed: 1, last: 1, active: [visitor, rift])));
    final (x, y) = WorldEventRules.spot(c.town, visitor)!;
    c.teleport(x, y);
    c.openWorldEvent(visitor);
    return c;
  }

  testWidgets('saludo, tema con VOLVER y rumor que marca el mapa', (t) async {
    final c = await controller();
    addTearDown(c.dispose);
    final d = kWorldEvents.def(visitor.def)!;
    await pumpDs(t, ProviderScope(child: EventNpcDialogue(c: c)));
    await settle(t);
    expect(find.byType(DsDialogueBox), findsOneWidget);
    expect(find.text(d.greeting.text), findsOneWidget);
    // Topic → its answer, then VOLVER back to the menu.
    await t.tap(find.byKey(const ValueKey('event-npc-topic-trade')));
    await settle(t);
    expect(find.text(d.topics.first.line.text), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('event-npc-back')));
    await settle(t);
    expect(find.text(d.greeting.text), findsOneWidget);
    // Rumor: host marks it and the map gets the rift's place.
    await t.tap(find.byKey(const ValueKey('event-npc-action-rumor')));
    await settle(t);
    expect(WorldEventRules.rumorMarks(c.town.events, c.localId), {kBosque});
    expect(find.byKey(const ValueKey('event-npc-action-trade')), findsNothing);
    await t.tap(find.byKey(const ValueKey('event-npc-back')));
    await settle(t);
    expect(find.byKey(const ValueKey('event-npc-action-trade')), findsOneWidget);
  });
}
