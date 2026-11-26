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

  /// PROPONER: straight in (v0.49.20, no gathering).
  WorldStep? enter(WorldEngine we, SessionWorld w, String id, String m) =>
      we.apply(w, id, ProposeMissionAction(m));

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

  // v0.49.20: no gathering. PROPONER enters at once, even with friends
  // around; the others join with UNIRSE on the player's card.
  group('straight in (free_movement.md § 2.1)', () {
    test('with friends around PROPONER enters at once; UNIRSE joins', () {
      final (we, w) = world();
      expect(we.apply(w, 'p0', const ProposeMissionAction('m1')), isNotNull);
      final d = w.roomOf('p0')!;
      expect(SessionWorld.isDungeon(d), isTrue);
      expect(w.rooms[d]!.mode, SessionMode.field);
      expect(w.roomOf('p1'), kTownRoom);
      final card = w.town.away.firstWhere((a) => a.id == 'p0');
      expect(card.busy, isFalse);
      expect(we.apply(w, 'p1', const JoinPlayerAction('p0')), isNotNull);
      expect(w.roomOf('p1'), d);
      // Proposing the same mission also joins the running one.
      expect(we.apply(w, 'p2', const ProposeMissionAction('m1')), isNotNull);
      expect(w.roomOf('p2'), d);
    });

    test('solo: PROPONER goes straight in', () {
      final we = WorldEngine(sessionEngine(freeMovement: true));
      final w = we.create(we.engine.create());
      we.addPlayer(w, 'p0', newProfile('Ana', 'guerrero'));
      expect(we.apply(w, 'p0', const ProposeMissionAction('m1')), isNotNull);
      expect(SessionWorld.isDungeon(w.roomOf('p0')!), isTrue);
    });

    test('the arrival grace runs out: enemies engage again', () {
      final (we, w) = world();
      we.apply(w, 'p0', const ProposeMissionAction('m1'));
      final d = w.roomOf('p0')!;
      expect(w.rooms[d]!.graceLeft, greaterThan(0));
      for (var i = 0; i < 80; i++) {
        we.tick(w, 0.05);
      }
      expect(w.rooms[d]!.graceLeft, 0);
    });
  });
}
