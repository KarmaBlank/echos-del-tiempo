import 'dart:convert';

import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/combat_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Modos de turno en la red (turn_modes.md § 5): el host manda.
void main() {
  test('sala de 3: por defecto Por rondas; la pelea usa porRonda y viaja',
      () {
    const j = SessionJson();
    final e = sessionEngine();
    var s = inField(e, 'm1', classes: ['guerrero', 'maga', 'guerrero'], mode: null);
    expect(s.effectiveCombatMode, CombatMode.rounds);
    s = wait(e, s, 2.6);
    final en = s.mission!.enemies.firstWhere((x) => !x.boss && !x.elite);
    s = moveTo(e, s, 'p0', en.x, en.y);
    s = e.tick(s, 0.05).state;
    expect(s.mode, SessionMode.battle);
    expect(s.battle!.state.turnRule, TurnRule.porRonda);

    // Varias rondas: los comandos llegan como del cable, y lo que ve un
    // cliente (el snapshot) respeta la regla: nadie actúa dos veces.
    final actedBy = <int, List<String>>{};
    for (var i = 0; i < 6000 && s.mode == SessionMode.battle; i++) {
      final b = s.battle!;
      if (b.waitingForPlayer && b.state.awaitingGroup) {
        final who = b.state.pendingGroup.last.id;
        final wire = jsonDecode(jsonEncode(
            ActionJson.toJson(const BattleAction(DefendCommand()))));
        final step = e.apply(s, who, ActionJson.fromJson(asJson(wire)));
        if (step != null) {
          final list = actedBy.putIfAbsent(b.state.round, () => []);
          expect(list, isNot(contains(who)));
          list.add(who);
          s = agreeQueue(e, step.state);
          for (var k = 0; k < 200 && s.battle!.queued(who); k++) {
            s = e.tick(s, 0.05).state;
          }
          // Lo que recibe el cliente.
          final seen = j.fromJson(asJson(jsonDecode(jsonEncode(j.toJson(s)))));
          expect(seen.battle!.state.turnRule, TurnRule.porRonda);
          expect(seen.battle!.state.acted, contains(who));
          // Un segundo comando del mismo jugador se descarta.
          expect(e.apply(s, who, const BattleAction(DefendCommand())), isNull);
          continue;
        }
      }
      s = e.tick(s, 0.05).state;
      if ((s.battle?.state.round ?? 0) > 3) break;
    }
    expect(actedBy.length, greaterThanOrEqualTo(2));
    for (final r in actedBy.entries) {
      if (r.key < (s.battle?.state.round ?? 99)) {
        expect(r.value.toSet().length, r.value.length);
      }
    }
  });

  test('JSON de la sala: `cm` solo si el anfitrión eligió', () {
    const j = SessionJson();
    final e = sessionEngine();
    final base = e.create();
    expect(j.toJson(base).containsKey('cm'), isFalse);
    for (final m in CombatMode.values) {
      final s = e.setCombatMode(base, m).state;
      final back = j.fromJson(asJson(jsonDecode(jsonEncode(j.toJson(s)))));
      expect(back.combatMode, m);
    }
  });

  group('loopback', () {
    final controllers = <SessionController>[];
    tearDown(() async {
      for (final c in controllers) {
        if (c.mounted) c.dispose();
      }
      controllers.clear();
      await pumpEventQueue();
    });

    Future<SessionController> make(NetSession net, {CombatMode? mode,
        ProfileStore? store}) async {
      final c = SessionController(
        engine: sessionEngine(),
        store: store ?? InMemoryProfileStore(newProfile('Ana', 'guerrero')),
        clock: const SessionClock(autoStart: false),
        net: net,
        combatMode: mode,
      );
      controllers.add(c);
      await c.start();
      return c;
    }

    test('host + 2 clientes: todos ven el modo del anfitrión', () async {
      final hub = LoopbackHub();
      final hn = LoopbackNetSession(hub);
      await hn.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
      final host = await make(hn, mode: CombatMode.rounds);
      final clients = <SessionController>[];
      for (final (name, cls) in [('Bea', 'maga'), ('Ciro', 'guerrero')]) {
        final n = LoopbackNetSession(hub);
        await n.connect(SessionConfig(
            profile: newProfile(name, cls), roomCode: hn.roomCode));
        clients.add(await make(n,
            mode: CombatMode.phases, store: InMemoryProfileStore()));
      }
      Future<void> net() async {
        for (final c in clients) {
          c.advance(0.05);
          await pumpEventQueue();
        }
        host.advance(0.05);
        await pumpEventQueue();
      }

      await net();
      await net();
      for (final c in clients) {
        expect(c.session!.effectiveCombatMode, CombatMode.rounds);
      }
      // El cliente no cambia la sala; el anfitrión sí.
      clients.first.setCombatMode(CombatMode.timeline);
      await net();
      expect(host.session!.combatMode, CombatMode.rounds);
      host.setCombatMode(CombatMode.phases);
      await net();
      await net();
      for (final c in clients) {
        expect(c.session!.combatMode, CombatMode.phases);
      }
    });
  });
}
