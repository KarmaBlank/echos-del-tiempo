import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

Json _wire(Json j) => asJson(jsonDecode(jsonEncode(j)));

/// Pausa de grupo (docs/specs/settings.md § "Pausa").
void main() {
  test('cualquier jugador pausa y cualquiera reanuda; eventos con nombre', () {
    final e = sessionEngine();
    var s = e.create();
    s = e.addPlayer(s, 'p0', newProfile('Ana', 'guerrero'))!.state;
    s = e.addPlayer(s, 'p1', newProfile('Bea', 'maga'))!.state;
    final step = e.apply(s, 'p1', const PauseAction(true))!;
    s = step.state;
    expect(s.paused, isTrue);
    expect(s.pausedBy, 'p1');
    expect(s.pausedName, 'Bea');
    expect(step.events.single, isA<PausedEvent>());
    // Pausar dos veces no hace nada.
    expect(e.apply(s, 'p0', const PauseAction(true)), isNull);
    // Mientras tanto, solo reanudar, chatear y lo que no toca el mundo.
    expect(e.apply(s, 'p0', const ProposeMissionAction('m1')), isNull);
    expect(e.apply(s, 'p0',
        MoveAction(10, 10, epoch: s.players['p0']!.epoch)), isNull);
    expect(e.apply(s, 'p0', const ChatAction('hola')), isNotNull);
    // Otro jugador reanuda.
    final res = e.apply(s, 'p0', const PauseAction(false))!;
    s = res.state;
    expect(s.paused, isFalse);
    expect((res.events.single as ResumedEvent).name, 'Ana');
  });

  test('pausada en el campo: no avanza reloj, misión, gracia ni enemigos',
      () {
    final e = sessionEngine();
    var s = inField(e, 'm1', classes: ['guerrero', 'maga']);
    // Con gracia pendiente y enemigos quietos/patrullando.
    s = act(e, s, 'p0', const PauseAction(true));
    final t0 = s.time, el0 = s.mission!.elapsed, grace0 = s.graceLeft;
    final pos0 = [for (final en in s.mission!.enemies) (en.x, en.y)];
    s = wait(e, s, 5);
    expect(s.time, t0);
    expect(s.mission!.elapsed, el0);
    expect(s.graceLeft, grace0);
    expect([for (final en in s.mission!.enemies) (en.x, en.y)], pos0);
    // Si quien pausó se va, sigue pausada; el otro reanuda.
    s = e.removePlayer(s, 'p0')!.state;
    expect(s.paused, isTrue);
    s = wait(e, s, 1);
    expect(s.time, t0);
    s = act(e, s, 'p1', const PauseAction(false));
    s = wait(e, s, 1);
    expect(s.time, greaterThan(t0));
    expect(s.mission!.elapsed, greaterThan(el0));
  });

  test('pausada en batalla: el tiempo de turno no corre ni se actúa', () {
    final e = sessionEngine();
    var s = inField(e, 'm1');
    s = wait(e, s, 2.6); // fin de la gracia
    final en = s.mission!.enemies.firstWhere((x) => !x.boss && !x.elite);
    s = moveTo(e, s, 'p0', en.x, en.y);
    s = e.tick(s, 0.05).state;
    expect(s.mode, SessionMode.battle);
    // Hasta que le toque al jugador.
    for (var i = 0; i < 2000 && !s.battle!.waitingForPlayer; i++) {
      s = e.tick(s, 0.05).state;
    }
    expect(s.battle!.waitingForPlayer, isTrue);
    s = wait(e, s, 1);
    s = act(e, s, 'p0', const PauseAction(true));
    final turn0 = s.battle!.turnTime;
    // Mucho más que el límite de turno: nada se mueve (no auto-defiende).
    s = wait(e, s, 60);
    expect(s.battle!.turnTime, turn0);
    expect(s.battle!.waitingForPlayer, isTrue);
    expect(e.apply(s, 'p0', const BattleAction(AttackCommand())), isNull);
    s = act(e, s, 'p0', const PauseAction(false));
    s = wait(e, s, 0.5);
    expect(s.battle!.turnTime, greaterThan(turn0));
  });

  test('JSON: estado pausado, acción y eventos ida y vuelta', () {
    const sj = SessionJson();
    const ej = EventJson();
    final e = sessionEngine();
    var s = e.create();
    s = e.addPlayer(s, 'p0', newProfile('Ana', 'guerrero'))!.state;
    // Sin pausa no se manda la clave (opcional).
    expect(sj.toJson(s).containsKey('pause'), isFalse);
    expect(sj.fromJson(_wire(sj.toJson(s))).paused, isFalse);
    s = act(e, s, 'p0', const PauseAction(true));
    final back = sj.fromJson(_wire(sj.toJson(s)));
    expect(back.pausedBy, 'p0');
    expect(back.pausedName, 'Ana');

    for (final on in [true, false]) {
      final a = ActionJson.fromJson(_wire(ActionJson.toJson(PauseAction(on))));
      expect((a as PauseAction).paused, on);
    }
    final p = ej.fromJson(_wire(ej.toJson(const PausedEvent('p0', 'Ana'))));
    expect((p as PausedEvent).name, 'Ana');
    final r = ej.fromJson(_wire(ej.toJson(const ResumedEvent('p1', 'Bea'))));
    expect((r as ResumedEvent).playerId, 'p1');
  });
}
