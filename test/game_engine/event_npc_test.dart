import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/world_events_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/localized_text.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_event_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecos_session_test.dart' show endgamer, lobby, winBattle;
import 'session_test_helpers.dart';

// Event NPCs (docs/specs/world_events.md § 3.6): gift, rumor, duel and
// the pending mark, host-authoritative.

SessionEngine _engine() => SessionEngine(
      battles: BattleEngine(stats: statsCalc, random: rolls(const [])),
      progression: zoneProgression,
      random: rolls(const []),
      seeds: () => 123,
      ecoRandom: () => 0.999,
      abyssRandom: () => 0.5,
    );

const _auto =
    ActiveWorldEvent('wanderer_automaton', biome: kRuinas, start: 10, end: 13);
const _pilgrim =
    ActiveWorldEvent('wanderer_forest', biome: kBosque, start: 10, end: 13);
const _rift = ActiveWorldEvent('echo_rift', biome: kCavernas, start: 10, end: 13);

GameSession _setup(SessionEngine e, List<ActiveWorldEvent> active,
    ActiveWorldEvent at, {int players = 1}) {
  final s = lobby(e, [
    for (var i = 0; i < players; i++) endgamer(['Ana', 'Beto'][i])
  ]);
  s.town = s.town.copyWith(
      events: WorldEventsState(seed: 1, last: 10, active: active));
  s.place = at.biome;
  final (x, y) = WorldEventRules.spot(s.town, at)!;
  for (final p in s.players.values) {
    p
      ..x = x
      ..y = y;
  }
  return s;
}

int _idx(String def, EventActionKind k) =>
    kWorldEvents.def(def)!.actions.indexWhere((a) => a.kind == k);

void main() {
  tearDown(() => kWorldEvents = kWorldEventsDefaults);

  test('catalog defaults: every event NPC has 1–2 valid actions', () {
    for (final d in kWorldEventsDefaults.events.where((d) => d.isNpc)) {
      expect(d.actions.length, inInclusiveRange(1, 2), reason: d.id);
      expect(d.greeting.source, isNotEmpty, reason: d.id);
    }
    expect(
        kWorldEventsDefaults.validate(const ['es-AR', 'en', 'zh-Hans'],
            biomes: {for (final b in kBiomes) b.id},
            items: WorldEventRules.giftItems),
        isEmpty);
  });

  group('regalo', () {
    test('se da una sola vez por jugador', () {
      final e = _engine();
      var s = _setup(e, [_auto], _auto, players: 2);
      final i = _idx('wanderer_automaton', EventActionKind.gift);
      final cog0 = s.players['p0']!.profile.life.ore('rare_cog');
      s = act(e, s, 'p0', EventNpcActAction(_auto.uid, i));
      expect(s.players['p0']!.profile.life.ore('rare_cog'), cog0 + 1);
      expect(s.town.events.doneBy(_auto.uid, i, 'p0'), isTrue);
      // A second time is refused for p0 …
      expect(e.apply(s, 'p0', EventNpcActAction(_auto.uid, i)), isNull);
      // … but p1 still gets theirs.
      s = act(e, s, 'p1', EventNpcActAction(_auto.uid, i));
      expect(s.town.events.doneBy(_auto.uid, i, 'p1'), isTrue);
    });

    test('lejos del NPC no se da', () {
      final e = _engine();
      final s = _setup(e, [_auto], _auto);
      s.players['p0']!
        ..x = 0
        ..y = 0;
      expect(e.apply(s, 'p0', EventNpcActAction(_auto.uid, 0)), isNull);
    });

    test('cebo y oro', () {
      final p = endgamer('Ana');
      final g = WorldEventRules.gift(
          p,
          const EventNpcAction(EventActionKind.gift,
              item: 'lombriz', params: {'qty': 2, 'gold': 30}))!;
      expect(g.life.baitCount('lombriz'), p.life.baitCount('lombriz') + 2);
      expect(g.credits, p.credits + 30);
      expect(
          WorldEventRules.gift(
              p, const EventNpcAction(EventActionKind.gift, item: 'nada')),
          isNull);
    });
  });

  group('rumor', () {
    test('marca la grieta activa en el mapa de quien lo oyó', () {
      final e = _engine();
      var s = _setup(e, [_pilgrim, _rift], _pilgrim);
      final i = _idx('wanderer_forest', EventActionKind.rumor);
      expect(WorldEventRules.rumorMarks(s.town.events, 'p0'), isEmpty);
      s = act(e, s, 'p0', EventNpcActAction(_pilgrim.uid, i));
      expect(WorldEventRules.rumorMarks(s.town.events, 'p0'), {kCavernas});
      expect(WorldEventRules.rumorMarks(s.town.events, 'p1'), isEmpty);
    });

    test('a un bioma fijo', () {
      const caravan =
          ActiveWorldEvent('caravan_relics', biome: kPueblo, start: 10, end: 13);
      final st = const WorldEventsState(active: [caravan])
          .markDone(caravan.uid, _idx('caravan_relics', EventActionKind.rumor), 'p0');
      expect(WorldEventRules.rumorMarks(st, 'p0'), {kRuinas});
    });
  });

  group('duelo', () {
    test('empieza, se gana, paga y suma renombre', () {
      final e = _engine();
      var s = _setup(e, [_auto], _auto);
      final r = WorldEventRules.riftOf(s.town.events, _auto.uid)!.$2;
      expect(r.bossId, 'guardianReloj');
      s = act(e, s, 'p0', ProposeRiftAction(_auto.uid));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.prep);
      s = act(e, s, 'p0', const ReadyAction(true));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.battle);
      expect(s.battle!.state.enemies.map((x) => x.enemyType),
          contains('guardianReloj'));
      final gold0 = s.players['p0']!.profile.credits;
      final rifts0 = s.town.renown.rifts;
      s = winBattle(e, s, until: (x) => x.result != null);
      expect(s.result!.success, isTrue);
      expect(s.players['p0']!.profile.credits - gold0,
          greaterThanOrEqualTo(WorldEventRules.riftGold(r)));
      expect(s.town.renown.rifts, rifts0 + 1);
      final d = kWorldEvents.def(_auto.def)!;
      expect(
          WorldEventRules.actionDone(s.town.events, _auto, d,
              _idx(_auto.def, EventActionKind.duel), 'p0'),
          isTrue);
      // Won: cannot duel again.
      s = backToLobby(e, s);
      s.place = kRuinas;
      final (x, y) = WorldEventRules.spot(s.town, _auto)!;
      s.players['p0']!
        ..x = x
        ..y = y;
      expect(e.apply(s, 'p0', ProposeRiftAction(_auto.uid)), isNull);
    });
  });

  test('la marca ! solo mientras queda algo pendiente', () {
    final d = kWorldEvents.def('wanderer_forest')!;
    var st = const WorldEventsState(active: [_pilgrim]);
    expect(WorldEventRules.mark(st, _pilgrim, d, 'p0'), NpcMark.news);
    st = st.markDone(_pilgrim.uid, 0, 'p0');
    expect(WorldEventRules.mark(st, _pilgrim, d, 'p0'), NpcMark.news);
    st = st.markDone(_pilgrim.uid, 1, 'p0');
    expect(WorldEventRules.mark(st, _pilgrim, d, 'p0'), NpcMark.none);
    expect(WorldEventRules.mark(st, _pilgrim, d, 'p1'), NpcMark.news);
    // Trade alone never asks for attention.
    const v = WorldEventDef(
        id: 'v',
        category: WorldEventCategory.visitor,
        actions: [EventNpcAction(EventActionKind.trade)]);
    expect(
        WorldEventRules.mark(const WorldEventsState(),
            const ActiveWorldEvent('v', biome: kPueblo, start: 1, end: 2), v, 'p0'),
        NpcMark.none);
  });

  group('validación', () {
    const tags = ['es-AR', 'en', 'zh-Hans'];
    List<String> check(WorldEventDef d) => WorldEventsConfig(events: [d])
        .validate(tags,
            biomes: {for (final b in kBiomes) b.id},
            enemies: {'slime'},
            items: WorldEventRules.giftItems);

    test('máximo 2 acciones, duelo solo en el campo, idiomas', () {
      final full = kWorldEventsDefaults.def('wanderer_automaton')!;
      final three = WorldEventDef(
          id: 'z',
          category: WorldEventCategory.overworldNpc,
          title: full.title,
          notice: full.notice,
          body: full.body,
          greeting: full.greeting,
          actions: [...full.actions, full.actions.first]);
      expect(check(three).any((m) => m.contains('máximo 2')), isTrue);
      final duelInTown = WorldEventDef(
          id: 'x',
          category: WorldEventCategory.visitor,
          greeting: full.greeting,
          title: full.title,
          notice: full.notice,
          body: full.body,
          actions: [
            EventNpcAction(EventActionKind.duel,
                label: full.title, line: full.title, target: 'slime')
          ]);
      expect(check(duelInTown).any((m) => m.contains('duelo')), isTrue);
      final noEn = WorldEventDef(
          id: 'y',
          category: WorldEventCategory.overworldNpc,
          title: full.title,
          notice: full.notice,
          body: full.body,
          greeting: const LocalizedText('Hola'),
          actions: [
            EventNpcAction(EventActionKind.gift,
                label: full.title, line: full.title, item: 'nada'),
          ]);
      final p = check(noEn);
      expect(p.any((m) => m.contains('y.greeting:en')), isTrue);
      expect(p.any((m) => m.contains('objeto desconocido')), isTrue);
    });
  });

  test('ida y vuelta JSON: catálogo, estado y acción', () {
    final j = jsonDecode(jsonEncode(kWorldEventsDefaults.toJson()));
    final back = WorldEventsConfig.fromJson(j);
    expect(jsonEncode(back.toJson()), jsonEncode(kWorldEventsDefaults.toJson()));
    expect(back.def('wanderer_automaton')!.actions[1].target, 'guardianReloj');
    final st = const WorldEventsState(seed: 3, active: [_auto])
        .markDone(_auto.uid, 0, 'p0');
    final st2 = WorldEventsState.fromJson(jsonDecode(jsonEncode(st.toJson())));
    expect(st2, st);
    expect(st2.doneBy(_auto.uid, 0, 'p0'), isTrue);
    expect(st.without(_auto.uid).done, isEmpty);
    final a = ActionJson.fromJson(
        ActionJson.toJson(const EventNpcActAction('u@1', 1)));
    expect((a as EventNpcActAction).uid, 'u@1');
    expect(a.index, 1);
  });
}
