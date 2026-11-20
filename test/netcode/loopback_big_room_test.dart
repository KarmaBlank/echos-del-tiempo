import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/party_limits.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/protocol_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Salas grandes (v0.13, docs/specs/netcode.md § "Máximo de jugadores"):
/// host + clientes por el protocolo real, con el máximo por defecto (8) y
/// con uno configurado mayor (12) para ver que nada asume un número fijo.
void main() {
  const classes = ['guerrero', 'maga', 'tirador', 'paladin'];

  for (final (n, max) in const [(2, kDefaultMaxPlayers), (6, kDefaultMaxPlayers),
      (8, kDefaultMaxPlayers), (12, 12)]) {
    test('sala de $n (máximo $max): unirse, misión, batalla y snapshot',
        () async {
      final hub = LoopbackHub();
      final all = <SessionController>[];
      Future<SessionController> make(NetSession net, ProfileStore store) async {
        final c = SessionController(
          engine: sessionEngine(maxPlayers: max),
          store: store,
          clock: const SessionClock(autoStart: false),
          net: net,
        );
        all.add(c);
        await c.start();
        return c;
      }

      final hn = LoopbackNetSession(hub, maxPlayers: max);
      await hn.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
      final host = await make(
          hn, InMemoryProfileStore(newProfile('Host', 'guerrero')));
      for (var i = 1; i < n; i++) {
        final cn = LoopbackNetSession(hub, maxPlayers: max);
        final p = newProfile('J$i', classes[i % classes.length]);
        await cn.connect(SessionConfig(profile: p, roomCode: hn.roomCode));
        expect(cn.roomMaxPlayers, max);
        all.add(await make(cn, InMemoryProfileStore()));
      }
      Future<void> net([double seconds = 0.05]) async {
        for (final c in all.skip(1)) {
          c.advance(0.05);
        }
        await pumpEventQueue();
        host.advance(seconds);
        await pumpEventQueue();
      }

      await net();
      expect(host.session!.players.length, n);
      for (final c in all) {
        expect(c.view!.session.players.length, n);
      }
      final ids = {for (final c in all) c.localId};
      expect(ids.length, n, reason: 'ids únicos');

      // Votación: propone el último, votan todos.
      expect(all.last.proposeMission('m1'), isTrue);
      await net();
      for (final c in all) {
        c.vote(true);
      }
      await net(0.1);
      for (final c in all) {
        expect(c.view!.mode, SessionMode.prep);
        c.setReady(true);
      }
      await net(0.1);
      expect(host.session!.mode, SessionMode.field);
      // Lugares de aparición distintos.
      final spots = {
        for (final p in host.session!.playerList) (p.x.round(), p.y.round())
      };
      expect(spots.length, n);

      await net(host.session!.graceLeft + 0.1);
      final en = host.session!.mission!.enemies
          .firstWhere((e) => e.alive && !e.boss && !e.elite);
      all[1].teleport(en.x, en.y);
      await net();
      await net();
      expect(host.session!.mode, SessionMode.battle);
      final party = host.session!.battle!.state.party;
      expect(party.length, n);
      for (final c in all) {
        expect(c.view!.session.battle!.state.party.length, n);
      }
      // Ancho de banda: el state más grande del tick con n jugadores.
      // ignore: avoid_print
      print('state con $n jugadores en batalla: ${hn.lastStateBytes} bytes');
      expect(hn.lastStateBytes, lessThan(64 * 1024));

      // Unos turnos: cada uno ataca en el suyo.
      for (var i = 0; i < 200 && host.session!.mode == SessionMode.battle; i++) {
        final b = host.session!.battle!;
        if (b.waitingForPlayer) {
          for (final c in all) {
            if (c.view!.myTurn) c.battleCommand(const AttackCommand());
          }
        }
        await net(0.1);
      }

      // El siguiente al máximo es rechazado (solo si la sala está llena).
      if (n == max) {
        final extra = LoopbackNetSession(hub, maxPlayers: max);
        await expectLater(
            extra.connect(SessionConfig(
                profile: newProfile('Otro', 'maga'), roomCode: hn.roomCode)),
            throwsA(isA<NetException>().having((e) => e.message, 'm',
                contains('máx. $max jugadores'))));
      }
      for (final c in all.reversed) {
        if (c.mounted) c.dispose();
      }
      await pumpEventQueue();
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  test('el host anuncia su máximo; un cliente con otro máximo igual entra',
      () async {
    final hub = LoopbackHub();
    final h = LoopbackNetSession(hub, maxPlayers: 3);
    await h.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    expect(h.roomMaxPlayers, 3);
    final a = LoopbackNetSession(hub);
    await a.connect(
        SessionConfig(profile: newProfile('Ana', 'maga'), roomCode: h.roomCode));
    expect(a.roomMaxPlayers, 3);
    final b = LoopbackNetSession(hub);
    await b.connect(
        SessionConfig(profile: newProfile('Bea', 'maga'), roomCode: h.roomCode));
    await expectLater(
        LoopbackNetSession(hub).connect(SessionConfig(
            profile: newProfile('Cid', 'maga'), roomCode: h.roomCode)),
        throwsA(isA<NetException>()
            .having((e) => e.message, 'm', contains('máx. 3 jugadores'))));
    for (final s in [b, a, h]) {
      await s.disconnect();
    }
    expect(ProtocolNetSession.hostId, 'h');
  });
}
