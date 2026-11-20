import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Fin de batalla tras una cinemática (battle_presentation.md § "Fin de
/// batalla"): el desenlace no se presenta hasta que termina la ULT / dúo.
void main() {
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

  test('ULT que mata al último enemigo: el desenlace espera la cinemática',
      () {
    final e = sessionEngine(fieldFallback: 0.0);
    var s = myTurn(e);
    s = act(e, s, 'p0', const BattleAction(UltimateCommand()));
    final b = s.battle!;
    expect(b.state.outcome?.victory, isTrue, reason: 'el motor ya resolvió');
    expect(b.endHold, 2.3);
    expect(b.outcomeShown, isFalse);
    expect(b.endTimer, closeTo(2.0 + 2.3, 1e-9));
    s = wait(e, s, 2.0);
    expect(s.mode, SessionMode.battle, reason: 'no vuelve en medio');
    expect(s.battle!.outcomeShown, isFalse);
    s = wait(e, s, 0.4);
    expect(s.battle!.outcomeShown, isTrue);
    expect(s.mode, SessionMode.battle, reason: 'el cartel tiene su pausa');
    s = wait(e, s, 2.1);
    expect(s.mode, isNot(SessionMode.battle));
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

  test('battleCinematicHold: ULT, ULT enemiga, dúo y nada', () {
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
}
