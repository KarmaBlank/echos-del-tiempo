import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/world_events_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_event_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecos_session_test.dart' show endgamer, lobby, normalEnemy, winBattle, winFight;
import 'session_test_helpers.dart';

// World events in the room (docs/specs/world_events.md Â§ 3): the rift
// fight, the visitor's sale and lore quests completed by the host.

SessionEngine _engine() => SessionEngine(
      battles: BattleEngine(stats: statsCalc, random: rolls(const [])),
      progression: zoneProgression,
      random: rolls(const []),
      seeds: () => 123,
      ecoRandom: () => 0.999,
      abyssRandom: () => 0.5,
    );

GameSession _with(GameSession s, List<ActiveWorldEvent> active,
    {String? place}) {
  s.town = s.town.copyWith(
      events: WorldEventsState(seed: 1, last: 5, active: active));
  s.place = place;
  return s;
}

GameSession _at(GameSession s, ActiveWorldEvent a) {
  final (x, y) = WorldEventRules.spot(s.town, a)!;
  for (final p in s.players.values) {
    p
      ..x = x
      ..y = y;
  }
  return s;
}

/// p0 opens the rift and everyone readies â†’ battle.
GameSession _enterRift(SessionEngine e, GameSession s, String uid) {
  s = act(e, s, 'p0', ProposeRiftAction(uid));
  s = e.tick(s, 0.05).state;
  expect(s.mode, SessionMode.prep);
  for (final id in s.players.keys) {
    s = act(e, s, id, const ReadyAction(true));
  }
  return e.tick(s, 0.05).state;
}

void main() {
  tearDown(() => kWorldEvents = kWorldEventsDefaults);

  const rift = ActiveWorldEvent('echo_rift', biome: kBosque, start: 5, end: 8);

  group('grieta de eco', () {
    test('entra a la pelea con el jefe del bioma escalado', () {
      final e = _engine();
      int bossHp(double mult) {
        kWorldEvents = WorldEventsConfig(events: [
          WorldEventDef(
              id: 'echo_rift',
              category: WorldEventCategory.echoPortal,
              params: {'hpMult': mult, 'atkMult': 1, 'rewardMult': 2}),
        ]);
        var s = _at(_with(lobby(e, [endgamer('Ana')]), [rift], place: kBosque),
            rift);
        s = _enterRift(e, s, rift.uid);
        expect(s.mode, SessionMode.battle);
        expect(s.mission!.missionId, WorldEventRules.riftMissionId);
        final boss = s.battle!.state.enemies.singleWhere((x) => x.boss);
        expect(boss.enemyType, 'matriarca');
        return boss.maxHp;
      }

      final base = bossHp(1);
      expect(bossHp(2) / base, closeTo(2, 0.02));
    });

    test('ganar paga Ã—premio y cierra el portal para quien peleÃ³', () {
      final e = _engine();
      var s = _at(_with(lobby(e, [endgamer('Ana')]), [rift], place: kBosque),
          rift);
      expect(WorldEventRules.near(s.town, kBosque, s.players['p0']!.x,
              s.players['p0']!.y, player: 'p0'),
          rift);
      s = _enterRift(e, s, rift.uid);
      final gold0 = s.players['p0']!.profile.credits;
      s = winBattle(e, s, until: (x) => x.result != null);
      expect(s.result!.success, isTrue);
      final r = WorldEventRules.riftOf(s.town.events, rift.uid)!.$2;
      expect(WorldEventRules.riftGold(r), greaterThan(0));
      expect(s.players['p0']!.profile.credits - gold0,
          greaterThanOrEqualTo(WorldEventRules.riftGold(r)));
      expect(s.town.events.clearedBy(rift.uid, 'p0'), isTrue);
      final p = s.players['p0']!;
      expect(
          WorldEventRules.near(s.town, kBosque, p.x, p.y, player: 'p0'), isNull);
      // A closed portal cannot be opened again.
      s = backToLobby(e, s);
      s.place = kBosque;
      s = _at(s, rift);
      expect(e.apply(s, 'p0', const ProposeRiftAction('echo_rift@5')), isNull);
    });

    test('lejos del portal no se abre', () {
      final e = _engine();
      final s = _with(lobby(e, [endgamer('Ana')]), [rift], place: kBosque);
      expect(e.apply(s, 'p0', ProposeRiftAction(rift.uid)), isNull);
    });

    test('la acciÃ³n viaja por la red', () {
      final j = ActionJson.toJson(const ProposeRiftAction('echo_rift@5'));
      expect((ActionJson.fromJson(j) as ProposeRiftAction).uid, 'echo_rift@5');
    });
  });

  group('visitante', () {
    const v = ActiveWorldEvent('visitor_clockmaker',
        biome: kPueblo, start: 5, end: 8);

    test('aparece en el pueblo y se puede hablar', () {
      final e = _engine();
      final s = _at(_with(lobby(e, [endgamer('Ana')]), [v]), v);
      final p = s.players['p0']!;
      expect(WorldEventRules.spot(s.town, v), isNotNull);
      expect(WorldEventRules.near(s.town, kPueblo, p.x, p.y), v);
      // Gone when the event ends.
      final gone = WorldEventRules.expire(s.town.events, 8);
      expect(gone.at(kPueblo), isEmpty);
    });

    test('el puesto aplica el descuento', () {
      final e = _engine();
      var s = _with(lobby(e, [endgamer('Ana')]), [v]);
      s.players['p0']!.profile =
          s.players['p0']!.profile.copyWith(credits: 1000);
      expect(WorldEventRules.townDiscount(s.town.events, kWorldEvents), 0.1);
      s = act(e, s, 'p0', const BuyRodAction('cana_roble'));
      expect(s.players['p0']!.profile.credits, 1000 - 400 + 40);
    });

    test('sin evento, precio normal', () {
      final e = _engine();
      var s = lobby(e, [endgamer('Ana')]);
      s.players['p0']!.profile =
          s.players['p0']!.profile.copyWith(credits: 1000);
      s = act(e, s, 'p0', const BuyRodAction('cana_roble'));
      expect(s.players['p0']!.profile.credits, 600);
    });
  });

  group('historias', () {
    test('explorar: llegar al bioma la cumple y paga', () {
      final e = _engine();
      const a = ActiveWorldEvent('lore_brann_forge',
          biome: kGrieta, start: 5, end: 11);
      var s = _with(lobby(e, [endgamer('Ana')]), [a], place: kGrieta);
      final gold0 = s.players['p0']!.profile.credits;
      final rep0 = s.town.resident('brann').rep;
      s = e.tick(s, 0.05).state;
      expect(s.town.events.active, isEmpty);
      expect(s.players['p0']!.profile.credits - gold0, 200);
      expect(s.town.resident('brann').rep - rep0, 2);
    });

    test('explorar: en otro lugar no avanza', () {
      final e = _engine();
      const a = ActiveWorldEvent('lore_brann_forge',
          biome: kGrieta, start: 5, end: 11);
      var s = _with(lobby(e, [endgamer('Ana')]), [a], place: kBosque);
      s = e.tick(s, 0.05).state;
      expect(s.town.events.active, [a]);
    });

    test('vencer: cuenta enemigos del tipo pedido hasta n', () {
      final d = kWorldEventsDefaults.def('lore_ilda_roots')!;
      expect(d.objective, LoreObjective.defeat);
      expect(d.target, 'arana');
      const a = ActiveWorldEvent('lore_ilda_roots',
          biome: kBosque, start: 5, end: 11);
      var st = const WorldEventsState(active: [a]);
      var (n, done) = WorldEventRules.advance(st, a, d, 2);
      expect(done, isFalse);
      expect(WorldEventRules.progressOf(n, a), 2);
      (n, done) = WorldEventRules.advance(n, a, d, 5);
      expect(done, isTrue);
      expect(n.active, isEmpty);
      expect(n.progress, isEmpty);
    });

    test('vencer en una batalla real avanza la historia y la cumple', () {
      final e = _engine();
      const a = ActiveWorldEvent('lore_ilda_roots',
          biome: kBosque, start: 5, end: 11);
      var s = inField(e, 'z2',
          profiles: [newProfile('J0', 'guerrero').copyWith(unlockedZone: 2)]);
      final en = s.mission!.enemy(normalEnemy(s))!;
      final type = en.group.first;
      final count = en.group.where((g) => g == type).length;
      // The quest asks for exactly the enemies of this fight.
      final d = kWorldEventsDefaults.def('lore_ilda_roots')!;
      kWorldEvents = WorldEventsConfig(events: [
        WorldEventDef(
            id: d.id,
            category: d.category,
            resident: d.resident,
            objective: LoreObjective.defeat,
            target: type,
            n: count,
            params: d.params,
            title: d.title,
            notice: d.notice,
            body: d.body),
      ]);
      s.town = s.town.copyWith(
          events: const WorldEventsState(seed: 1, last: 5, active: [a]));
      final gold0 = s.players['p0']!.profile.credits;
      final rep0 = s.town.resident('ilda').rep;
      s = winFight(e, s, en.id);
      expect(s.town.events.active, isEmpty);
      expect(s.town.resident('ilda').rep - rep0, 2);
      expect(s.players['p0']!.profile.credits - gold0, greaterThanOrEqualTo(120));
    });
  });
}
