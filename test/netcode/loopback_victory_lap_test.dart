import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// v0.20.22 (missions.md § "Fin de misión" y § "Loot perdido"): host + 2
/// clientes por el protocolo real. Tras vencer al jefe el grupo sigue en
/// el área; LISTO 2/3 no vuelve, 3/3 sí; lo del piso va al pozo Loot
/// perdido que ven todos, un cliente toma algo y la misión siguiente lo
/// borra.
void main() {
  late LoopbackHub hub;
  late SessionController host, ana, bea;
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

  Future<SessionController> joinAs(String name, String cls) async {
    final n = LoopbackNetSession(hub);
    await n.connect(SessionConfig(
        profile: newProfile(name, cls), roomCode: host.net!.roomCode));
    return make(n, InMemoryProfileStore());
  }

  Future<void> net([double seconds = 0.05]) async {
    for (final c in [ana, bea]) {
      if (c.mounted) c.advance(0.05);
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
    ana = await joinAs('Ana', 'maga');
    bea = await joinAs('Bea', 'tirador');
    await net();
  });

  tearDown(() async {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
    await pumpEventQueue();
  });

  Future<void> startM1() async {
    expect(host.proposeMission('m1'), isTrue);
    await net();
    ana.vote(true);
    bea.vote(true);
    await net(0.1);
    for (final c in [host, ana, bea]) {
      c.setReady(true);
    }
    await net(0.1);
    await net(0.1);
    expect(host.session!.mode, SessionMode.field);
  }

  test('victoria: sigue en el área, LISTO 2/3 no vuelve, 3/3 sí; el '
      'botín del piso va al Loot perdido de todos y se borra en la '
      'misión siguiente', () async {
    await startM1();
    // Enemigos con 1 de vida: se gana sí o sí.
    for (var i = 0; i < 8000 && host.session!.result == null; i++) {
      final v = host.view!;
      switch (v.mode) {
        case SessionMode.battle:
          for (final en in host.session!.battle?.state.enemies ?? const []) {
            if (en.hp > 1) en.hp = 1;
          }
          for (final c in [host, ana, bea]) {
            if (c.view!.myTurn) c.battleCommand(const AttackCommand());
          }
        case SessionMode.levelUp:
          for (final c in [host, ana, bea]) {
            final cv = c.view!;
            if (cv.mustAllocate) {
              c.allocate({Attribute.vit: cv.me!.profile.points});
            }
          }
        case SessionMode.field when v.session.graceLeft <= 0:
          final boss = v.session.mission!.enemies.firstWhere((e) => e.boss);
          host.teleport(boss.x, boss.y);
        default:
          break;
      }
      await net(0.1);
    }
    final r = host.session!.result!;
    expect(r.success, isTrue);
    // Sigue en el mapa de la misión, en el campo, con la ventana.
    for (final c in [host, ana, bea]) {
      expect(c.view!.mode, SessionMode.field);
      expect(c.view!.session.victoryLap, isTrue);
      expect(c.view!.session.mission, isNotNull);
      expect(c.resultClosed, isFalse);
    }
    // Cerrar la ventana es local: el grupo sigue ahí.
    ana.closeResult();
    expect(ana.resultClosed, isTrue);
    await net(0.5);
    expect(host.session!.victoryLap, isTrue);

    // Algo queda en el piso (además de lo que haya caído).
    final s = host.session!;
    s.ground.add(const GroundLoot(
        id: 9001,
        drop: LootDrop.stack(StackKind.potion, 2),
        x: 0,
        y: 0,
        ownerId: 'p2'));
    s.ground.add(const GroundLoot(
        id: 9002,
        drop: LootDrop.stack(StackKind.ether, 1),
        x: 0,
        y: 0,
        byId: 'h'));
    final onGround = s.ground.length;
    await net();

    // LISTO 2/3: no vuelve.
    expect(host.setLeaveReady(true), isTrue);
    expect(ana.setLeaveReady(true), isTrue);
    for (var i = 0; i < 20; i++) {
      await net(0.1);
    }
    expect(host.session!.victoryLap, isTrue);
    expect(bea.view!.session.leaveReady, {'h', 'p1'});
    // 3/3: al pueblo.
    expect(bea.setLeaveReady(true), isTrue);
    await net();
    await net();
    for (final c in [host, ana, bea]) {
      expect(c.view!.mode, SessionMode.lobby);
      expect(c.view!.session.ground, isEmpty);
      expect(c.view!.session.lostLoot, hasLength(onGround));
    }

    // Ana toma la poción que era de Bea.
    final potions = ana.view!.me!.profile.potions;
    expect(ana.takeLostLoot(9001), isTrue);
    await net();
    await net();
    expect(ana.view!.me!.profile.potions, potions + 2);
    for (final c in [host, ana, bea]) {
      expect(c.view!.session.lostLoot.any((g) => g.id == 9001), isFalse);
      expect(c.view!.session.lostLoot, hasLength(onGround - 1));
    }

    // La misión siguiente borra el pozo.
    expect(host.session!.lostLoot, isNotEmpty);
    await startM1();
    for (final c in [host, ana, bea]) {
      expect(c.view!.session.lostLoot, isEmpty);
    }
  });

  test('quien se desconecta no bloquea el LISTO', () async {
    await startM1();
    // Victoria forzada en el host (el flujo de pelea lo cubre el otro test).
    for (var i = 0; i < 8000 && host.session!.result == null; i++) {
      final v = host.view!;
      final b = host.session!.battle;
      if (v.mode == SessionMode.battle && b != null) {
        for (final en in b.state.enemies) {
          if (en.hp > 1) en.hp = 1;
        }
        for (final c in [host, ana, bea]) {
          if (c.view!.myTurn) c.battleCommand(const AttackCommand());
        }
      } else if (v.mode == SessionMode.levelUp) {
        for (final c in [host, ana, bea]) {
          final cv = c.view!;
          if (cv.mustAllocate) {
            c.allocate({Attribute.vit: cv.me!.profile.points});
          }
        }
      } else if (v.mode == SessionMode.field && v.session.graceLeft <= 0) {
        final boss = v.session.mission!.enemies.firstWhere((e) => e.boss);
        host.teleport(boss.x, boss.y);
      }
      await net(0.1);
    }
    expect(host.session!.victoryLap, isTrue);
    host.setLeaveReady(true);
    ana.setLeaveReady(true);
    await net();
    expect(host.session!.victoryLap, isTrue);
    bea.dispose();
    await pumpEventQueue();
    await net();
    await net();
    expect(host.session!.mode, SessionMode.lobby);
  });
}
