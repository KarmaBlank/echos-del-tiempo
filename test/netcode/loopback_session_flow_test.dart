import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/protocol_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Host + 2 clientes en un proceso (docs/specs/netcode.md): los mismos
/// `SessionController` que usa la UI, hablando por el protocolo real
/// (JSON) sobre enlaces en memoria.
void main() {
  late LoopbackHub hub;
  late SessionController host, ana, bea;
  late InMemoryProfileStore anaStore;
  final controllers = <SessionController>[];

  Future<SessionController> make(NetSession net, ProfileStore store) async {
    final c = SessionController(
      engine: sessionEngine(),
      store: store,
      clock: const SessionClock(autoStart: false),
      net: net,
    );
    controllers.add(c);
    await c.start();
    return c;
  }

  Future<SessionController> joinAs(String name, String cls, ProfileStore store) async {
    final n = LoopbackNetSession(hub);
    await n.connect(SessionConfig(
        profile: newProfile(name, cls), roomCode: host.net!.roomCode));
    return make(n, store);
  }

  List<SessionController> clients() =>
      [ana, bea].where((c) => c.mounted).toList();

  /// Un "frame" de red: los clientes mandan su posición, el host recibe,
  /// avanza [seconds] (difundiendo cada 50 ms) y los clientes reciben.
  Future<void> net([double seconds = 0.05]) async {
    for (final c in clients()) {
      c.advance(0.05);
    }
    await pumpEventQueue();
    host.advance(seconds);
    await pumpEventQueue();
  }

  setUp(() async {
    hub = LoopbackHub();
    final hn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    host = await make(hn, InMemoryProfileStore(newProfile('Host', 'guerrero')));
    anaStore = InMemoryProfileStore();
    ana = await joinAs('Ana', 'maga', anaStore);
    bea = await joinAs('Bea', 'tirador', InMemoryProfileStore());
    await net();
  });

  tearDown(() async {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
    await pumpEventQueue();
  });

  test('unirse: ids de la red, la misma sala en todos', () async {
    expect(host.role, SessionRole.host);
    expect(ana.role, SessionRole.client);
    expect([host.localId, ana.localId, bea.localId], ['h', 'p1', 'p2']);
    for (final c in [host, ana, bea]) {
      expect(c.view!.session.players.keys, ['h', 'p1', 'p2']);
      expect(c.view!.roomCode, host.net!.roomCode);
    }
    expect(ana.view!.me!.name, 'Ana');
    expect(bea.view!.me!.profile.classId, 'tirador');
    expect(host.view!.messages,
        contains('Sala creada. Comparte el código LOOP1 con tus amigos.'));
    expect(host.view!.messages, contains('Bea se unió a la sala.'));
    // Bea ya estaba cuando entró; ve los mensajes que siguen.
    expect(bea.view!.messages, contains('Bea se unió a la sala.'));
    // El cliente adoptó su posición de spawn (época nueva).
    expect(ana.local.x, host.session!.players['p1']!.x);
  });

  test('flujo completo: votar, mover, batalla por turnos, alguien se va, '
      'resultado y el host cierra', () async {
    // ---- votación desde un cliente ----
    expect(ana.proposeMission('m1'), isTrue); // enviada
    await net();
    expect(host.session!.vote!.proposedBy, 'Ana');
    expect(bea.view!.session.vote!.yes, {'p1'});
    host.vote(true);
    bea.vote(true);
    await net(0.1);
    for (final c in [host, ana, bea]) {
      expect(c.view!.mode, SessionMode.prep);
    }
    host.setReady(true);
    ana.setReady(true);
    bea.setReady(true);
    await net(0.1);
    for (final c in [host, ana, bea]) {
      expect(c.view!.mode, SessionMode.field);
      expect(c.view!.session.mission!.seed, host.session!.mission!.seed);
      // El mapa sale de la semilla (no viaja).
      expect(c.view!.map.width, host.view!.map.width);
    }
    // Época nueva: el cliente adoptó el spawn de la misión.
    expect(ana.local.x, host.session!.players['p1']!.x);
    expect(ana.local.epoch, host.session!.players['p1']!.epoch);

    // ---- movimiento: el host confía en la posición del cliente ----
    final sx = ana.local.x + 6, sy = ana.local.y;
    ana.teleport(sx, sy);
    await net();
    expect(host.session!.players['p1']!.x, closeTo(sx, 0.05));
    expect(bea.view!.session.players['p1']!.x, closeTo(sx, 0.05));
    // El snapshot no pisa la predicción local (misma época).
    ana.updateLocal(0.05, 1, 0);
    final predicted = ana.local.x;
    await net();
    expect(ana.local.x, predicted);

    // ---- batalla: la toca Ana ----
    await net(host.session!.graceLeft + 0.1);
    final en = host.session!.mission!.enemies
        .firstWhere((e) => e.alive && !e.boss && !e.elite);
    ana.teleport(en.x, en.y);
    await net();
    await net();
    expect(host.session!.mode, SessionMode.battle);
    expect(ana.view!.mode, SessionMode.battle);
    expect(ana.view!.session.battle!.state.party.map((c) => c.id),
        containsAll(['h', 'p1', 'p2']));

    final anaEvents = <BattleEvent>[];
    ana.events.listen((e) {
      if (e is BattleStepEvent) anaEvents.addAll(e.events);
    });

    var anaActed = false, offTurnRejected = false, beaLeft = false;
    for (var i = 0; i < 4000 && host.session!.mode == SessionMode.battle; i++) {
      final b = host.session!.battle!;
      final cur = b.state.currentId;
      if (b.waitingForPlayer) {
        if (cur == 'h') {
          if (!offTurnRejected) {
            // Comando fuera de turno: el host lo ignora.
            ana.battleCommand(const AttackCommand());
            await net(0.05);
            expect(host.session!.battle?.state.currentId, 'h');
            offTurnRejected = true;
          }
          host.battleCommand(const AttackCommand());
        } else if (cur == 'p1' && ana.view!.myTurn) {
          expect(ana.battleCommand(const DefendCommand()), isTrue);
          anaActed = true;
        } else if (cur == 'p2' && !beaLeft && bea.view!.myTurn) {
          bea.battleCommand(const AttackCommand());
        }
      }
      // Bea se cae a mitad de la batalla, después de que Ana actuó.
      if (anaActed && !beaLeft) {
        beaLeft = true;
        bea.dispose();
        await pumpEventQueue();
      }
      await net(0.1);
    }
    expect(anaActed, isTrue);
    expect(offTurnRejected, isTrue);
    expect(beaLeft, isTrue);
    expect(host.session!.players.keys, ['h', 'p1']);
    expect(host.view!.messages, contains('Bea salió de la sala.'));
    expect(ana.view!.messages, contains('Bea salió de la sala.'));
    // Ana vio su propio comando animado (llegó en los eventos del host).
    expect(
        anaEvents.whereType<ActionEvent>().any(
            (e) => e.actorId == 'p1' && e.kind == BattleActionKind.defend),
        isTrue);

    // ---- hasta el resultado: el host va al jefe ----
    for (var i = 0; i < 6000 && host.session!.result == null; i++) {
      final v = host.view!;
      switch (v.mode) {
        case SessionMode.battle:
          if (v.myTurn) host.battleCommand(const AttackCommand());
          if (ana.view!.myTurn) ana.battleCommand(const AttackCommand());
        case SessionMode.levelUp:
          if (v.mustAllocate) {
            host.allocate({Attribute.vit: v.me!.profile.points});
          }
          final av = ana.view!;
          if (av.mustAllocate) {
            ana.allocate({Attribute.vit: av.me!.profile.points});
          }
        case SessionMode.field when v.session.graceLeft <= 0:
          final boss = v.session.mission!.enemies.firstWhere((e) => e.boss);
          host.teleport(boss.x, boss.y);
        default:
          break;
      }
      await net(0.1);
    }
    expect(host.session!.result, isNotNull);
    expect(ana.view!.session.result, isNotNull);
    expect(ana.view!.session.result!.id, host.session!.result!.id);
    expect(ana.view!.session.result!.rank, host.session!.result!.rank);
    // El cliente guardó el perfil que le mandó el host (con su XP).
    await pumpEventQueue();
    final saved = await anaStore.load();
    expect(saved!.name, 'Ana');
    expect(saved.xp, host.session!.players['p1']!.profile.xp);
    expect(saved.xp, greaterThan(0));

    // ---- el host se va: el cliente vuelve al título con el motivo ----
    host.dispose();
    await pumpEventQueue();
    expect(ana.view!.disconnected, ProtocolNetSession.lostMessage);
  });

  test('chat de un cliente llega a todos', () async {
    bea.sendChat('  hola equipo  ');
    await net();
    for (final c in [host, ana, bea]) {
      expect(c.view!.chat.last.from, 'Bea');
      expect(c.view!.chat.last.text, 'hola equipo');
    }
  });

  test('el cliente nunca corre reglas: sin snapshot no cambia nada', () async {
    final before = ana.session!;
    ana.proposeMission('m2');
    // Sin que el host procese, el estado del cliente es el mismo objeto.
    expect(identical(ana.session, before), isTrue);
    expect(ana.view!.session.vote, isNull);
  });

  test('pausa de grupo: un cliente pausa, todos la ven, otro reanuda',
      () async {
    final t0 = host.session!.time;
    expect(bea.pauseGroup(true), isTrue); // enviada
    await net();
    for (final c in [host, ana, bea]) {
      expect(c.view!.session.paused, isTrue);
      expect(c.view!.session.pausedName, 'Bea');
    }
    expect(ana.view!.chat.last.text, 'Bea pausó el juego');
    // El host no avanza mientras tanto.
    await net(2);
    expect(host.session!.time, t0);
    // Bea se va: sigue pausada para el resto.
    bea.dispose();
    await pumpEventQueue();
    await net(1);
    expect(host.session!.players.keys, ['h', 'p1']);
    expect(ana.view!.session.paused, isTrue);
    expect(host.session!.time, t0);
    // Ana reanuda.
    ana.pauseGroup(false);
    await net(0.5);
    expect(host.session!.paused, isFalse);
    expect(ana.view!.session.paused, isFalse);
    expect(host.session!.time, greaterThan(t0));
    expect(host.view!.chat.last.text, 'Ana reanudó el juego');
  });
}
