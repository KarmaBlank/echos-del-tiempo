import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

final treeRules = PassiveTreeRules(kPassiveTree);
final statsCalc = StatsCalculator(classes: kClasses, treeRules: treeRules);
final progression = ProgressionRules(stats: statsCalc);

/// Azar fijo: devuelve [rolls] en orden y después [fallback].
RandomSource rolls(List<double> rolls, {double fallback = 0.99}) {
  var i = 0;
  return () => i < rolls.length ? rolls[i++] : fallback;
}

SessionEngine sessionEngine({
  List<double> fieldRolls = const [],
  double fieldFallback = 0.99,
  List<double> battleRolls = const [],
  int seed = 500000000,
}) =>
    SessionEngine(
      battles: BattleEngine(stats: statsCalc, random: rolls(battleRolls)),
      progression: progression,
      random: rolls(fieldRolls, fallback: fieldFallback),
      seeds: () => seed,
    );

/// Perfil válido de [classId] (nivel 1, recién creado).
PlayerProfile newProfile(String name, String classId) =>
    progression.normalize(PlayerProfile(name: name, classId: classId));

/// Aplica una acción que debe ser válida.
GameSession act(SessionEngine e, GameSession s, String id, SessionAction a) {
  final step = e.apply(s, id, a);
  expect(step, isNotNull, reason: 'acción rechazada: $a');
  return step!.state;
}

/// Sala con [classes] (ids p0, p1...) ya en el campo de [missionId].
GameSession inField(SessionEngine e, String missionId,
    {List<String> classes = const ['guerrero'], List<PlayerProfile>? profiles}) {
  profiles ??= [
    for (var i = 0; i < classes.length; i++) newProfile('J$i', classes[i]),
  ];
  classes = [for (final p in profiles) p.classId];
  var s = e.create();
  for (var i = 0; i < profiles.length; i++) {
    s = e.addPlayer(s, 'p$i', profiles[i])!.state;
  }
  s = act(e, s, 'p0', ProposeMissionAction(missionId));
  for (var i = 1; i < classes.length; i++) {
    s = act(e, s, 'p$i', const VoteMissionAction(true));
  }
  s = e.tick(s, 0.05).state;
  expect(s.mode, SessionMode.prep);
  for (var i = 0; i < classes.length; i++) {
    s = act(e, s, 'p$i', const ReadyAction(true));
  }
  s = e.tick(s, 0.05).state;
  expect(s.mode, SessionMode.field);
  return s;
}

/// Avanza la sesión de a 50 ms hasta que [until] sea cierto, atacando
/// al primer enemigo cada vez que le toca a un jugador.
GameSession runBattle(SessionEngine e, GameSession s,
    {bool Function(GameSession)? until,
    int maxTicks = 20000,
    List<SessionEvent>? log}) {
  until ??= (x) => x.mode != SessionMode.battle;
  for (var i = 0; i < maxTicks && !until(s); i++) {
    final b = s.battle;
    if (b != null && b.waitingForPlayer) {
      final step = e.apply(s, b.state.currentId!, const BattleAction(AttackCommand()));
      if (step != null) {
        log?.addAll(step.events);
        s = step.state;
        continue;
      }
    }
    final step = e.tick(s, 0.05);
    log?.addAll(step.events);
    s = step.state;
  }
  return s;
}

/// Avanza [seconds] de a 50 ms.
GameSession wait(SessionEngine e, GameSession s, double seconds,
    {List<SessionEvent>? log}) {
  for (var t = 0.0; t < seconds; t += 0.05) {
    final step = e.tick(s, 0.05);
    log?.addAll(step.events);
    s = step.state;
  }
  return s;
}

/// Teletransporta al jugador (como lo haría el cliente con su MoveAction).
GameSession moveTo(SessionEngine e, GameSession s, String id, double x, double y) =>
    act(e, s, id, MoveAction(x, y, epoch: s.players[id]!.epoch));

