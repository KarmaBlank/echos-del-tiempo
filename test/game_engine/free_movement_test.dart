import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Movimiento libre por jugador (docs/specs/free_movement.md).
void main() {
  (WorldEngine, SessionWorld) world() {
    final we = WorldEngine(sessionEngine(freeMovement: true));
    final w = we.create(we.engine.create());
    we.addPlayer(w, 'p0', newProfile('Ana', 'guerrero'));
    we.addPlayer(w, 'p1', newProfile('Beto', 'mago').copyWith(unlockedZone: 2));
    we.addPlayer(w, 'p2', newProfile('Caro', 'mago'));
    return (we, w);
  }

  /// PROPONER and, if a gathering opened (friends around), IR alone.
  WorldStep? enter(WorldEngine we, SessionWorld w, String id, String m) {
    final s = we.apply(w, id, ProposeMissionAction(m));
    if (s == null || w.gather?.byId != id) return s;
    return we.apply(w, id, const GatherAction(GatherOp.go));
  }

  test('cada uno viaja solo, sin anfitrión ni votación', () {
    final (we, w) = world();
    expect(we.apply(w, 'p1', const TravelAction(kBosque)), isNotNull);
    expect(w.roomOf('p1'), kBosque);
    expect(w.roomOf('p0'), kTownRoom);
    expect(w.rooms[kBosque]!.place, kBosque);
    expect(w.town.away.map((a) => a.id), ['p1']);
    // Vuelve: el exterior vacío se cierra.
    expect(we.apply(w, 'p1', const TravelAction(kPueblo)), isNotNull);
    expect(w.rooms.keys, [kTownRoom]);
    expect(w.town.away, isEmpty);
  });

  test('ENTRAR mete solo a uno; otro amigo se suma a su instancia', () {
    final (we, w) = world();
    expect(enter(we, w, 'p0', 'm1'), isNotNull);
    final d = w.roomOf('p0')!;
    expect(SessionWorld.isDungeon(d), isTrue);
    expect(w.rooms[d]!.mode, SessionMode.field);
    expect(w.rooms[d]!.players.keys, ['p0']);
    expect(w.town.players.keys, ['p1', 'p2']);
    expect(w.town.mode, SessionMode.lobby);
    // El que pesca sigue en el pueblo mientras el otro se suma.
    expect(we.apply(w, 'p1', const ProposeMissionAction('m1')), isNotNull);
    expect(w.roomOf('p1'), d);
    expect(w.town.players.keys, ['p2']);
    // Corre: el pueblo no entra en ninguna pelea.
    for (var i = 0; i < 40; i++) {
      we.tick(w, 0.05);
    }
    expect(w.town.battle, isNull);
    expect(w.town.mode, SessionMode.lobby);
  });

  test('dos mazmorras distintas a la vez', () {
    final (we, w) = world();
    enter(we, w, 'p0', 'm1');
    enter(we, w, 'p1', 'm2');
    final a = w.roomOf('p0'), b = w.roomOf('p1');
    expect(a, isNot(b));
    expect(SessionWorld.isDungeon(b!), isTrue);
    expect(w.rooms[b]!.players.keys, ['p1']);
  });

  test('away lleva la clave del destino (protocolo 63)', () {
    final (we, w) = world();
    we.apply(w, 'p1', const TravelAction(kBosque));
    enter(we, w, 'p0', 'm1');
    final ids = {for (final a in w.town.away) a.id: a.placeId};
    expect(ids, {'p1': kBosque, 'p0': 'm:m1'});
  });

  test('IR CON: va a la instancia del otro, a su posición', () {
    final (we, w) = world();
    enter(we, w, 'p0', 'm1');
    final d = w.roomOf('p0')!;
    final target = w.rooms[d]!.players['p0']!;
    expect(we.apply(w, 'p2', const JoinPlayerAction('p0')), isNotNull);
    expect(w.roomOf('p2'), d);
    final me = w.rooms[d]!.players['p2']!;
    expect((me.x, me.y), (target.x, target.y));
    // Ya juntos: no hace nada.
    expect(we.apply(w, 'p2', const JoinPlayerAction('p0')), isNull);
  });

  test('IR CON: no a una instancia en batalla', () {
    final (we, w) = world();
    enter(we, w, 'p0', 'm1');
    final d = w.roomOf('p0')!;
    w.rooms[d] = w.rooms[d]!.copy()..mode = SessionMode.battle;
    expect(we.apply(w, 'p2', const JoinPlayerAction('p0')), isNull);
    expect(w.roomOf('p2'), kTownRoom);
  });

  test('away viaja en el snapshot', () {
    final (we, w) = world();
    we.apply(w, 'p1', const TravelAction(kBosque));
    final codec = SessionJson(we.engine.catalog);
    final back = codec.fromJson(codec.toJson(w.town));
    expect(back.away.single.where, biomeDef(kBosque)!.name);
  });

  test('salir solo: los demás siguen; el último cierra la instancia', () {
    final (we, w) = world();
    enter(we, w, 'p0', 'm1');
    we.apply(w, 'p1', const ProposeMissionAction('m1'));
    final d = w.roomOf('p0')!;
    // Lejos de la entrada no se puede.
    final far = w.rooms[d]!.copy();
    far.players['p0']!.x += 200;
    w.rooms[d] = far;
    expect(we.apply(w, 'p0', const LeaveDungeonAction()), isNull);
    w.rooms[d] = w.rooms[d]!.copy()..players['p0']!.x -= 200;
    final loot = w.rooms[d]!.players['p0']!.profile;
    expect(we.apply(w, 'p0', const LeaveDungeonAction()), isNotNull);
    expect(w.roomOf('p0'), kTownRoom);
    expect(identical(w.town.players['p0']!.profile, loot), isTrue,
        reason: 'se lleva lo suyo');
    expect(w.rooms[d]!.players.keys, ['p1']);
    expect(w.rooms[d]!.mode, SessionMode.field);
    // En batalla no se sale.
    w.rooms[d] = w.rooms[d]!.copy()..mode = SessionMode.battle;
    expect(we.apply(w, 'p1', const LeaveDungeonAction()), isNull);
    w.rooms[d] = w.rooms[d]!.copy()..mode = SessionMode.field;
    expect(we.apply(w, 'p1', const LeaveDungeonAction()), isNotNull);
    expect(w.rooms.containsKey(d), isFalse);
  });

  group('gathering (free_movement.md § 2.1.1)', () {
    test('PROPONER with friends opens a gathering; IR takes the joined', () {
      final (we, w) = world();
      expect(we.apply(w, 'p0', const ProposeMissionAction('m1')), isNotNull);
      expect(w.roomOf('p0'), kTownRoom, reason: 'waits for IR');
      final g = w.town.gather!;
      expect((g.byId, g.target, g.kind), ('p0', 'm1', GatherKind.mission));
      // Every instance carries it (p1 is in the forest).
      we.apply(w, 'p1', const TravelAction(kBosque));
      expect(w.rooms[kBosque]!.gather?.byId, 'p0');
      expect(we.apply(w, 'p1', const GatherAction(GatherOp.join)), isNotNull);
      expect(w.town.gather!.joined.map((j) => j.id), ['p1']);
      // Only the proposer goes / cancels.
      expect(we.apply(w, 'p1', const GatherAction(GatherOp.go)), isNull);
      final step = we.apply(w, 'p0', const GatherAction(GatherOp.go))!;
      final d = w.roomOf('p0')!;
      expect(SessionWorld.isDungeon(d), isTrue);
      expect(w.roomOf('p1'), d, reason: 'same instance at once');
      expect(w.roomOf('p2'), kTownRoom);
      expect(w.rooms[d]!.mode, SessionMode.field);
      expect(w.town.gather, isNull);
      expect(step.eventsFor('p2'), isNotNull);
      // Who did not join can still enter later.
      expect(we.apply(w, 'p2', const ProposeMissionAction('m1')), isNotNull);
      expect(w.roomOf('p2'), d);
    });

    test('IR with nobody joined enters alone; cancel closes it', () {
      final (we, w) = world();
      we.apply(w, 'p0', const ProposeMissionAction('m1'));
      expect(we.apply(w, 'p1', const GatherAction(GatherOp.cancel)), isNull);
      expect(we.apply(w, 'p0', const GatherAction(GatherOp.cancel)), isNotNull);
      expect(w.town.gather, isNull);
      we.apply(w, 'p0', const ProposeMissionAction('m1'));
      expect(we.apply(w, 'p0', const GatherAction(GatherOp.go)), isNotNull);
      expect(SessionWorld.isDungeon(w.roomOf('p0')!), isTrue);
      expect(w.town.players.keys, ['p1', 'p2']);
    });

    test('proposing the gathered mission joins; the proposer leaving drops it',
        () {
      final (we, w) = world();
      we.apply(w, 'p0', const ProposeMissionAction('m1'));
      expect(we.apply(w, 'p2', const ProposeMissionAction('m1')), isNotNull);
      expect(w.roomOf('p2'), kTownRoom);
      expect(w.town.gather!.has('p2'), isTrue);
      we.removePlayer(w, 'p0');
      expect(w.town.gather, isNull);
    });

    test('solo: PROPONER goes straight in', () {
      final we = WorldEngine(sessionEngine(freeMovement: true));
      final w = we.create(we.engine.create());
      we.addPlayer(w, 'p0', newProfile('Ana', 'guerrero'));
      expect(we.apply(w, 'p0', const ProposeMissionAction('m1')), isNotNull);
      expect(SessionWorld.isDungeon(w.roomOf('p0')!), isTrue);
      expect(w.town.gather, isNull);
    });

    test('gat travels in the snapshot', () {
      final (we, w) = world();
      we.apply(w, 'p0', const ProposeMissionAction('m1'));
      we.apply(w, 'p1', const GatherAction(GatherOp.join));
      final codec = SessionJson(we.engine.catalog);
      final back = codec.fromJson(codec.toJson(w.town)).gather!;
      expect(back.signature, w.town.gather!.signature);
    });

    test('the gathering counts down and enters on its own with the joined', () {
      final (we, w) = world();
      we.apply(w, 'p0', const ProposeMissionAction('m1'));
      final g = w.town.gather!;
      expect(g.left, WorldEngine.gatherSeconds);
      expect(g.leftSeconds, 20, reason: 'tuning default');
      we.apply(w, 'p1', const GatherAction(GatherOp.join));
      // Half way: still waiting, the countdown reached every instance.
      for (var i = 0; i < 10; i++) {
        we.tick(w, 1);
      }
      expect(w.roomOf('p0'), kTownRoom);
      expect(w.town.gather!.leftSeconds, 10);
      for (var i = 0; i < 11; i++) {
        we.tick(w, 1);
      }
      final d = w.roomOf('p0')!;
      expect(SessionWorld.isDungeon(d), isTrue);
      expect(w.roomOf('p1'), d);
      expect(w.roomOf('p2'), kTownRoom, reason: 'did not join');
      expect(w.town.gather, isNull);
    });

    test('late join: UNIRSE on the card goes into the running mission', () {
      final (we, w) = world();
      we.apply(w, 'p0', const ProposeMissionAction('m1'));
      we.apply(w, 'p0', const GatherAction(GatherOp.go));
      final d = w.roomOf('p0')!;
      final card = w.town.away.firstWhere((a) => a.id == 'p0');
      expect(card.busy, isFalse);
      expect(we.apply(w, 'p2', const JoinPlayerAction('p0')), isNotNull);
      expect(w.roomOf('p2'), d);
    });
  });
}
