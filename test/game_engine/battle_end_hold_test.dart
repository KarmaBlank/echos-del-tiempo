import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/fx/cinematic_durations.dart';
import 'package:echos_del_tiempo/game_engine/fx/fx_timeline.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'session_test_helpers.dart';

/// Las duraciones de los datos FXA del release (`assets/fx`), leídas del
/// disco con el parser puro (lo mismo que hace `FxCatalog`).
CinematicDurations releaseDurations() {
  final m = loadYaml(File('assets/fx/fx_manifest.yaml').readAsStringSync())
      as YamlMap;
  return CinematicDurations({
    for (final e in (m['fx'] as YamlMap).entries)
      '${e.key}': FxTimeline.parse(
              File('assets/fx/${e.value}').readAsStringSync())
          .duration,
  });
}

/// Fin de batalla tras una cinemática (battle_presentation.md § "Fin de
/// batalla"): el desenlace no se presenta hasta que termina la ULT / dúo,
/// y lo que dura sale de los datos de la animación (game_editor.md § 4.3).
void main() {
  tearDown(() => CinematicDurations.shared = const CinematicDurations());

  /// Batalla en curso, le toca a p0; queda un solo enemigo, a 1 HP.
  GameSession myTurn(SessionEngine e) {
    var s = wait(e, inField(e, 'm1'), 2.6);
    final en = s.mission!.enemy(0)!;
    s = moveTo(e, s, 'p0', en.x, en.y);
    s = e.tick(s, 0.05).state;
    expect(s.mode, SessionMode.battle);
    s = runBattle(e, s,
        until: (x) =>
            x.battle!.waitingForPlayer && x.battle!.state.currentId == 'p0');
    final foes = s.battle!.state.enemies;
    foes.first.hp = 1;
    for (final c in foes.skip(1)) {
      c.hp = 0;
    }
    s.battle!.state.party.firstWhere((c) => c.id == 'p0').ult = 100;
    return s;
  }

  /// La ULT que usa p0 (la de su arma).
  String ultOf(GameSession s) => kAllUltimates[s.battle!.state.party
          .firstWhere((c) => c.id == 'p0')
          .weaponType]!
      .id;

  test('ULT que mata al último enemigo: el desenlace espera la cinemática',
      () {
    final e = sessionEngine(fieldFallback: 0.0);
    var s = myTurn(e);
    // Una animación de 2.55 s para esa ULT: la espera la sigue.
    CinematicDurations.shared = CinematicDurations({ultOf(s): 2550});
    s = act(e, s, 'p0', const BattleAction(UltimateCommand()));
    final b = s.battle!;
    expect(b.state.outcome?.victory, isTrue, reason: 'el motor ya resolvió');
    expect(b.endHold, 2.55);
    expect(b.outcomeShown, isFalse);
    expect(b.endTimer, closeTo(2.0 + 2.55, 1e-9));
    s = wait(e, s, 2.0);
    expect(s.mode, SessionMode.battle, reason: 'no vuelve en medio');
    expect(s.battle!.outcomeShown, isFalse);
    s = wait(e, s, 0.4);
    expect(s.battle!.outcomeShown, isFalse, reason: 'la cinemática sigue');
    s = wait(e, s, 0.2);
    expect(s.battle!.outcomeShown, isTrue);
    expect(s.mode, SessionMode.battle, reason: 'el cartel tiene su pausa');
    s = wait(e, s, 2.1);
    expect(s.mode, isNot(SessionMode.battle));
  });

  test('la espera es la duración de los datos del release', () {
    final data = releaseDurations();
    CinematicDurations.shared = data;
    final e = sessionEngine(fieldFallback: 0.0);
    var s = myTurn(e);
    final id = ultOf(s);
    s = act(e, s, 'p0', const BattleAction(UltimateCommand()));
    expect(data.ms, contains(id), reason: 'la ULT de arma tiene datos');
    expect(s.battle!.endHold, data.ms[id]! / 1000);
  });

  test('como cliente (loopback): el snapshot lleva la espera', () {
    final e = sessionEngine(fieldFallback: 0.0);
    var s = myTurn(e);
    s = act(e, s, 'p0', const BattleAction(UltimateCommand()));
    const codec = SessionJson();
    final client = codec.fromJson(codec.toJson(s));
    expect(client.battle!.state.outcome, isNotNull);
    expect(client.battle!.endHold, 2.3);
    expect(client.battle!.outcomeShown, isFalse);
    s = wait(e, s, 2.4);
    final later = codec.fromJson(codec.toJson(s));
    expect(later.battle!.outcomeShown, isTrue);
  });

  test('un golpe normal que mata no agrega espera', () {
    final e = sessionEngine(fieldFallback: 0.0);
    var s = myTurn(e);
    s = act(e, s, 'p0', const BattleAction(AttackCommand()));
    final b = s.battle!;
    expect(b.state.outcome?.victory, isTrue);
    expect(b.endHold, 0);
    expect(b.outcomeShown, isTrue);
    expect(b.endTimer, 2.0);
  });

  test('battleCinematicHold: ULT, ULT enemiga, dúo y nada (sin datos)', () {
    expect(
        battleCinematicHold(
            const [ActionEvent('p0', BattleActionKind.ultimate)]),
        2.3);
    expect(
        battleCinematicHold(const [
          ActionEvent('p0', BattleActionKind.dual, partnerId: 'p1'),
        ]),
        1.5);
    expect(battleCinematicHold(const [EnemyUltEvent('e0', 'x', 'X')]),
        2.3);
    expect(
        battleCinematicHold(
            const [ActionEvent('p0', BattleActionKind.attack)]),
        0);
  });

  test('battleCinematicHold con datos: la más larga del paso', () {
    final d = releaseDurations();
    expect(
        battleCinematicHold(const [
          ActionEvent('p0', BattleActionKind.ultimate, skillId: 'ult_espada'),
          ActionEvent('p1', BattleActionKind.ultimate, skillId: 'ult_baculo'),
        ], d),
        2.6);
    expect(
        battleCinematicHold(const [
          ActionEvent('p0', BattleActionKind.dual,
              partnerId: 'p1', skillId: 'guerrero+maga'),
        ], d),
        1.6);
  });
}
