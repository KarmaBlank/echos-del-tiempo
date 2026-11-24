import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/renown_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/renown_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecos_session_test.dart' show endgamer, lobby, winBattle, winFight;
import 'session_test_helpers.dart';

// The town tournament (docs/specs/renown_town_growth.md § 6.2): schedule
// it with the resident, sign up on its day, three fights, the prize.

SessionEngine _engine() => SessionEngine(
      battles: BattleEngine(stats: statsCalc, random: rolls(const [])),
      progression: zoneProgression,
      random: rolls(const []),
      seeds: () => 123,
      ecoRandom: () => 0.999,
      abyssRandom: () => 0.5,
    );

final _def = kRenownDefaults.event('tourney_kael')!;

/// Kael lives in town, is a good friend and the world is known.
GameSession _ready(GameSession s, {int day = 3}) {
  s.town = s.town.copyWith(
    sky: SkyState(day: day, clock: 0.3),
    residents: {
      'kael': ResidentState('kael', invited: true, rep: _def.minRep),
    },
    renown: const RenownState(zones: {1, 2, 3}),
  );
  return s;
}

/// The awake fighter comes for the party: wait for its battle (or walk
/// to it) and win it.
GameSession _nextRound(SessionEngine e, GameSession s, int id,
    {bool Function(GameSession)? until}) {
  for (var i = 0; i < 400 && s.mode != SessionMode.battle; i++) {
    s = e.tick(s, 0.05).state;
  }
  if (s.mode != SessionMode.battle) return winFight(e, s, id, until: until);
  expect(s.battle!.fieldEnemyId, id);
  return winBattle(e, s,
      until: until ?? (x) => x.mode != SessionMode.battle);
}

void main() {
  test('aceptar la propuesta lo programa para dentro de unos días', () {
    final e = _engine();
    var s = _ready(lobby(e, [endgamer('Ana')]));
    s = act(e, s, 'p0', ScheduleTownEventAction(_def.id));
    expect(s.town.renown.scheduled[_def.id], 3 + _def.delay);
    // Not twice; and no sign-up before its day.
    expect(e.apply(s, 'p0', ScheduleTownEventAction(_def.id)), isNull);
    expect(e.apply(s, 'p0', ProposeTourneyAction(_def.id)), isNull);
  });

  test('sin amistad no se programa', () {
    final e = _engine();
    final s = _ready(lobby(e, [endgamer('Ana')]));
    s.town = s.town.withResident(s.town.resident('kael').copyWith(rep: 0));
    expect(e.apply(s, 'p0', ScheduleTownEventAction(_def.id)), isNull);
  });

  test('el día del torneo: tres peleas seguidas y el premio', () {
    final e = _engine();
    var s = _ready(lobby(e, [endgamer('Ana'), endgamer('Beto')]));
    s = act(e, s, 'p0', ScheduleTownEventAction(_def.id));
    final day = s.town.renown.scheduled[_def.id]!;
    s.town = s.town.copyWith(sky: SkyState(day: day, clock: 0.3));
    s = act(e, s, 'p0', ProposeTourneyAction(_def.id));
    expect(s.tourney, _def.id);
    // Coop: the friend joins the vote.
    s = act(e, s, 'p1', const VoteMissionAction(true));
    s = e.tick(s, 0.05).state;
    expect(s.mode, SessionMode.prep);
    for (final id in s.players.keys) {
      s = act(e, s, id, const ReadyAction(true));
    }
    s = e.tick(s, 0.05).state;
    // Round 1 starts right away; the other two are asleep.
    expect(s.mode, SessionMode.battle);
    expect(s.mission!.missionId, RenownRules.tourneyMissionId);
    expect([for (final f in s.mission!.enemies) f.alive], [true, false, false]);
    expect(s.mission!.enemies.last.boss, isTrue);
    final gold0 = {for (final p in s.players.values) p.id: p.profile.credits};
    s = winBattle(e, s, until: (x) => x.mode != SessionMode.battle);
    expect(s.mission!.enemies[1].alive, isTrue);
    s = _nextRound(e, s, 1);
    expect(s.mission!.enemies[2].alive, isTrue);
    s = _nextRound(e, s, 2, until: (x) => x.result != null);
    expect(s.result!.success, isTrue);
    for (final p in s.players.values) {
      expect(p.profile.credits - gold0[p.id]!,
          greaterThanOrEqualTo(_def.prize),
          reason: p.id);
    }
    expect(s.town.renown.tourneys, 1);
    expect(s.town.renown.scheduled, isEmpty);
    expect(s.town.renown.held[_def.id], day);
    // Zones are not unlocked by a tournament.
    expect(s.town.renown.zones, {1, 2, 3});
  });

  test('la sesión y las acciones viajan por la red', () {
    final e = _engine();
    final s = lobby(e, [endgamer('Ana')])..tourney = 'x';
    s.town = s.town.copyWith(
        renown: const RenownState(scheduled: {'x': 4}, tourneys: 1));
    const j = SessionJson();
    final back = j.fromJson(jsonDecode(jsonEncode(j.toJson(s))) as Map<String, dynamic>);
    expect(back.tourney, 'x');
    expect(back.town.renown.scheduled['x'], 4);
    final a = ActionJson.fromJson(
        ActionJson.toJson(const ScheduleTownEventAction('x')));
    expect((a as ScheduleTownEventAction).id, 'x');
    final b =
        ActionJson.fromJson(ActionJson.toJson(const ProposeTourneyAction('x')));
    expect((b as ProposeTourneyAction).id, 'x');
  });
}
