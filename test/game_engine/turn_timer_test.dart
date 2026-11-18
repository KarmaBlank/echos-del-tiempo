import 'dart:convert';

import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Tiempo de turno (docs/specs/accessibility.md § 7): NORMAL 30 s,
/// LARGO 60 s, SIN LÍMITE; solo vale el local, en co-op el del anfitrión.
void main() {
  /// En batalla, esperando a p0, con la sala en [timer].
  GameSession waitingTurn(SessionEngine e, TurnTimer timer) {
    var s = e.setTurnTimer(inField(e, 'm1'), timer).state;
    s = wait(e, s, 2.6); // fin de la gracia
    final en = s.mission!.enemies.firstWhere((x) => !x.boss && !x.elite);
    s = moveTo(e, s, 'p0', en.x, en.y);
    s = e.tick(s, 0.05).state;
    expect(s.mode, SessionMode.battle);
    for (var i = 0; i < 2000 && !s.battle!.waitingForPlayer; i++) {
      s = e.tick(s, 0.05).state;
    }
    expect(s.battle!.waitingForPlayer, isTrue);
    expect(s.battle!.state.currentId, 'p0');
    return s;
  }

  /// Espera [seconds] y dice si el turno de p0 se pasó solo (el reloj
  /// del turno volvió a cero en algún momento).
  bool timesOut(SessionEngine e, GameSession s, double seconds) {
    var last = s.battle!.turnTime;
    for (var t = 0.0; t < seconds; t += 0.05) {
      s = e.tick(s, 0.05).state;
      final b = s.battle;
      if (b == null) return true;
      if (b.turnTime < last) return true;
      last = b.turnTime;
    }
    return false;
  }

  test('NORMAL: el turno se pasa a los 30 s', () {
    final e = sessionEngine();
    final s = waitingTurn(e, TurnTimer.normal);
    expect(s.turnLimit, 30);
    expect(timesOut(e, s, 29), isFalse);
    expect(timesOut(e, s, 31), isTrue);
  });

  test('LARGO: el doble (60 s)', () {
    final e = sessionEngine();
    final s = waitingTurn(e, TurnTimer.long);
    expect(s.turnLimit, 60);
    expect(timesOut(e, s, 45), isFalse);
    expect(timesOut(e, s, 61), isTrue);
  });

  test('SIN LÍMITE: el turno espera para siempre', () {
    final e = sessionEngine();
    var s = waitingTurn(e, TurnTimer.unlimited);
    expect(s.turnLimit, isNull);
    expect(timesOut(e, s, 300), isFalse);
    s = wait(e, s, 120);
    expect(s.battle!.waitingForPlayer, isTrue);
    expect(s.battle!.turnTime, greaterThan(120));
  });

  test('cambiarlo a mitad de turno vale para ese mismo turno', () {
    final e = sessionEngine();
    var s = waitingTurn(e, TurnTimer.normal);
    s = wait(e, s, 20);
    s = e.setTurnTimer(s, TurnTimer.unlimited).state;
    expect(timesOut(e, s, 60), isFalse);
  });

  test('JSON: `tt` solo si no es el normal; ida y vuelta', () {
    const j = SessionJson();
    final e = sessionEngine();
    final base = e.create();
    expect(j.toJson(base).containsKey('tt'), isFalse);
    for (final t in TurnTimer.values) {
      final s = e.setTurnTimer(base, t).state;
      final wire = asJson(jsonDecode(jsonEncode(j.toJson(s))));
      expect(j.fromJson(wire).turnTimer, t);
    }
    // Un snapshot viejo (sin `tt`) o con un valor desconocido: normal.
    final odd = j.toJson(base)..['tt'] = 'eterno';
    expect(j.fromJson(asJson(jsonDecode(jsonEncode(odd)))).turnTimer,
        TurnTimer.normal);
  });

  group('controlador', () {
    final controllers = <SessionController>[];
    tearDown(() async {
      for (final c in controllers) {
        if (c.mounted) c.dispose();
      }
      controllers.clear();
      await pumpEventQueue();
    });

    Future<SessionController> make(
        {NetSession? net, TurnTimer timer = TurnTimer.normal,
        ProfileStore? store}) async {
      final c = SessionController(
        engine: sessionEngine(),
        store: store ?? InMemoryProfileStore(newProfile('Ana', 'guerrero')),
        clock: const SessionClock(autoStart: false),
        net: net,
        turnTimer: timer,
      );
      controllers.add(c);
      await c.start();
      return c;
    }

    test('solo: vale el ajuste local, al crear y al cambiarlo', () async {
      final c = await make(timer: TurnTimer.long);
      expect(c.session!.turnTimer, TurnTimer.long);
      c.setTurnTimer(TurnTimer.unlimited);
      expect(c.session!.turnTimer, TurnTimer.unlimited);
      expect(c.view!.session.turnTimer, TurnTimer.unlimited);
    });

    test('co-op: la sala usa el del anfitrión; el del cliente no cuenta',
        () async {
      final hub = LoopbackHub();
      final hn = LoopbackNetSession(hub);
      await hn.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
      final host = await make(net: hn, timer: TurnTimer.unlimited);
      final an = LoopbackNetSession(hub);
      await an.connect(SessionConfig(
          profile: newProfile('Bea', 'maga'), roomCode: hn.roomCode));
      final bea = await make(
          net: an, timer: TurnTimer.normal, store: InMemoryProfileStore());

      Future<void> net() async {
        bea.advance(0.05);
        await pumpEventQueue();
        host.advance(0.05);
        await pumpEventQueue();
      }

      await net();
      await net();
      expect(host.session!.turnTimer, TurnTimer.unlimited);
      expect(bea.session!.turnTimer, TurnTimer.unlimited,
          reason: 'el cliente ve el del anfitrión');

      // El cliente cambia su ajuste: la sala no cambia.
      bea.setTurnTimer(TurnTimer.long);
      await net();
      expect(host.session!.turnTimer, TurnTimer.unlimited);
      expect(bea.session!.turnTimer, TurnTimer.unlimited);

      // El anfitrión cambia el suyo: les llega a todos.
      host.setTurnTimer(TurnTimer.long);
      await net();
      await net();
      expect(bea.session!.turnTimer, TurnTimer.long);
    });
  });
}
