import 'dart:typed_data';

import 'package:echos_del_tiempo/game_engine/models/fog_of_war.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/dungeon_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Mazmorras de zona persistentes por mundo (persistent_dungeons.md).
PlayerProfile hero() => zoneProgression
    .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 10))
    .copyWith(unlockedZone: 1);

void main() {
  (WorldEngine, SessionWorld) world({TownState? town, String id = 'w1'}) {
    final we = WorldEngine(sessionEngine(freeMovement: true, zones: true));
    final base = we.engine
        .setWorld(we.engine.create(), id, 'Mundo', town: town)
        .state;
    final w = we.create(base);
    we.addPlayer(w, 'p0', hero());
    return (we, w);
  }

  GameSession enter(WorldEngine we, SessionWorld w) {
    expect(we.apply(w, 'p0', const ProposeMissionAction('m1')), isNotNull);
    return w.sessionOf('p0')!;
  }

  void leave(WorldEngine we, SessionWorld w) {
    final d = w.roomOf('p0')!;
    final s = w.rooms[d]!.copy()..mission!.floor = 0;
    final sp = we.engine.mapFor(s).floor(0)!.spawn;
    s.players['p0']!
      ..x = sp.x
      ..y = sp.y;
    w.rooms[d] = s;
    expect(we.apply(w, 'p0', const LeaveDungeonAction()), isNotNull);
    expect(w.rooms.containsKey(d), isFalse);
  }

  void setDay(WorldEngine we, SessionWorld w, int day) => we.setAll(
      w, (s) => s.copy()..town = s.town.copyWith(sky: SkyState(day: day)));

  test('la semilla sale del mundo: fija por mundo, distinta entre mundos', () {
    expect(DungeonRules.seedFor('w1', 'm1'), DungeonRules.seedFor('w1', 'm1'));
    expect(DungeonRules.seedFor('w1', 'm1'),
        isNot(DungeonRules.seedFor('w2', 'm1')));
    final (we, w) = world();
    expect(enter(we, w).mission!.seed, DungeonRules.seedFor('w1', 'm1'));
  });

  test('ida y vuelta: sale el último, se guarda y vuelve igual (y tras reiniciar)',
      () {
    final (we, w) = world();
    final s = enter(we, w);
    final m = s.mission!;
    final normal = m.enemies.firstWhere((e) => !e.boss && !e.elite);
    final elite = m.enemies.firstWhere((e) => e.elite);
    normal.alive = false;
    elite.alive = false;
    m.poiUsed.add(99); // un farol encendido
    m.opened.add(0);
    m.questsDone.add(1);
    m.questsFailed.add(2);
    if (m.items.isNotEmpty) m.items.first.done = true;
    leave(we, w);
    final saved = w.town.town.dungeons['m1'];
    expect(saved, isNotNull);

    // Reinicio del anfitrión: el mundo pasa por JSON.
    final town = TownState.fromJson(w.town.town.toJson());
    expect(town.dungeons.keys, ['m1']);
    final (we2, w2) = world(town: town);
    final back = enter(we2, w2).mission!;
    expect(back.seed, m.seed);
    expect(back.enemy(normal.id)!.alive, isFalse);
    expect(back.enemy(elite.id)!.alive, isFalse);
    expect(back.poiUsed, contains(99));
    expect(back.opened, contains(0));
    expect(back.questsDone, contains(1), reason: 'opcional cumplida no vuelve');
    expect(back.questsFailed, isEmpty, reason: 'la fallada se reintenta');
    if (m.items.isNotEmpty) expect(back.items.first.done, isTrue);
    // No viaja a los clientes.
    expect(town.farmJson().containsKey('dg'), isFalse);
  });

  test('reaparición: solo tras 5 días con la mazmorra vacía; el jefe no', () {
    final (we, w) = world();
    setDay(we, w, 1);
    final m = enter(we, w).mission!;
    for (final e in m.enemies) {
      e.alive = false;
    }
    leave(we, w);
    setDay(we, w, 5); // 4 días vacía
    var back = enter(we, w).mission!;
    expect(back.enemies.every((e) => !e.alive), isTrue);
    leave(we, w); // vuelve a contar desde el día 5
    setDay(we, w, 9);
    back = enter(we, w).mission!;
    expect(back.enemies.any((e) => e.alive), isFalse);
    leave(we, w); // vacía desde el día 9
    setDay(we, w, 14);
    back = enter(we, w).mission!;
    expect(back.enemies.where((e) => !e.boss).every((e) => e.alive), isTrue);
    expect(DungeonRules.boss(back)!.alive, isFalse);
  });

  test('con alguien adentro no reaparece nada', () {
    final (we, w) = world();
    setDay(we, w, 1);
    final d = w.roomOf('p0');
    enter(we, w).mission!.enemies.first.alive = false;
    setDay(we, w, 20);
    for (var i = 0; i < 5; i++) {
      we.tick(w, 0.05);
    }
    expect(w.rooms[w.roomOf('p0')]!.mission!.enemies.first.alive, isFalse);
    expect(d, isNot(w.roomOf('p0')));
  });

  test('Ofrenda: paga materiales de la zona y revive al jefe', () {
    final (we, w) = world();
    final s0 = enter(we, w);
    final key = w.roomOf('p0')!;
    final boss = DungeonRules.boss(s0.mission!)!;
    boss.alive = false;
    final s = s0.copy();
    s.mission!.floor = boss.floor;
    s.players['p0']!
      ..x = boss.homeX
      ..y = boss.homeY;
    w.rooms[key] = s;
    // Sin materiales: no.
    expect(we.apply(w, 'p0', const OfferBossAction()), isNull);
    final cost = DungeonRules.offeringCost(1);
    expect(cost[CraftMaterial.esquirla], greaterThan(0));
    final rich = w.rooms[key]!.copy();
    final p = rich.players['p0']!;
    p.profile = p.profile.copyWith(materials: {
      for (final e in cost.entries) e.key: e.value + 1,
    });
    w.rooms[key] = rich;
    expect(we.engine.canOffer(rich, 'p0'), isTrue);
    expect(we.apply(w, 'p0', const OfferBossAction()), isNotNull);
    final after = w.rooms[key]!;
    expect(DungeonRules.boss(after.mission!)!.alive, isTrue);
    for (final e in cost.entries) {
      expect(after.players['p0']!.profile.material(e.key), 1);
    }
    // Con el jefe vivo, no hay altar.
    expect(we.engine.canOffer(after, 'p0'), isFalse);
  });

  test('Ofrenda del Eco (bosses.md § v0.50): paga el doble y marca el jefe Eco',
      () {
    final (we, w) = world();
    final s0 = enter(we, w);
    final key = w.roomOf('p0')!;
    final boss = DungeonRules.boss(s0.mission!)!;
    boss.alive = false;
    final s = s0.copy();
    s.mission!.floor = boss.floor;
    final cost = DungeonRules.offeringCost(1, eco: true);
    s.players['p0']!
      ..x = boss.homeX
      ..y = boss.homeY
      ..profile = s.players['p0']!.profile.copyWith(materials: {
        for (final e in DungeonRules.offeringCost(1).entries) e.key: e.value,
      });
    w.rooms[key] = s;
    // Alcanza para la normal pero no para la Eco.
    expect(we.apply(w, 'p0', const OfferBossAction(eco: true)), isNull);
    final rich = w.rooms[key]!.copy();
    final p = rich.players['p0']!;
    p.profile = p.profile.copyWith(
        materials: {for (final e in cost.entries) e.key: e.value});
    w.rooms[key] = rich;
    expect(we.apply(w, 'p0', const OfferBossAction(eco: true)), isNotNull);
    final after = w.rooms[key]!;
    expect(after.mission!.bossEco, isTrue);
    expect(DungeonRules.boss(after.mission!)!.alive, isTrue);
    for (final e in cost.entries) {
      expect(after.players['p0']!.profile.material(e.key), 0);
    }
  });

  test('sin mundo (tests viejos) o un Eco: semilla al azar y nada se guarda',
      () {
    final e = sessionEngine(zones: true, seed: 123);
    final s = inField(e, 'm1', profiles: [hero()]);
    expect(s.mission?.seed, 123);
    expect(e.parkDungeon(s).town.dungeons, isEmpty);
  });

  test('niebla: empaquetada compacta y se recupera al volver', () {
    final seen = Uint8List(40)..[3] = 1..[39] = 1;
    final raw = FogOfWar.pack(seen, 8, 5);
    expect(FogOfWar.unpack(raw, 8, 5), seen);
    expect(FogOfWar.unpack(raw, 9, 5), isNull);
    final fog = FogOfWar()..begin('m1:1', 8, 5);
    fog.reveal(0, 0, 2, 1, (_, __) => 1, 0.5);
    fog.begin('z2:1', 8, 5);
    expect(fog.explored(0, 0), isFalse);
    fog.begin('m1:1', 8, 5);
    expect(fog.explored(1, 0), isTrue);
    expect(fog.dirty, isTrue);
  });
}
