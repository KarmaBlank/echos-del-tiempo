import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Regresión v0.20.17 (loot.md § 4b.1): en una sala de 3, las armas que
/// quedaron en el piso con el inventario lleno vuelven, al salir de la
/// sala, al alijo (o a
/// Objetos sin recoger) de cada jugador, y sobreviven a guardar/cargar.
/// Antes el loot tirado traía el uid provisorio `nuevo` y el alijo
/// descartaba la segunda como "duplicada".
void main() {
  LootDrop sword(Rarity r) => LootDrop.item(ItemInstance(
      uid: LootRules.newUid, baseId: 'espada_ignea', rarity: r, itemLevel: 2));

  PlayerProfile full(PlayerProfile p) {
    var i = 0;
    while (InventoryRules.freeCells(p) > 0) {
      p = InventoryRules.receive(
          p,
          LootDrop.item(ItemInstance(
              uid: 'x${i++}',
              baseId: 'espada_ignea',
              rarity: Rarity.comun,
              itemLevel: 1)))!;
    }
    return p;
  }

  test('host y cliente con inventario lleno: nada del piso se pierde',
      () async {
    final hub = LoopbackHub();
    final all = <SessionController>[];
    final stores = <InMemoryAccountStore>[];
    Future<SessionController> make(NetSession net, PlayerProfile p) async {
      final st = InMemoryAccountStore(Account().add(p)!);
      stores.add(st);
      final repo = AccountRepository(st);
      final c = SessionController(
        engine: sessionEngine(),
        store: SelectedCharacterProfileStore(repo),
        stashStore: AccountStashStore(repo),
        clock: const SessionClock(autoStart: false),
        net: net,
      );
      all.add(c);
      await c.start();
      return c;
    }

    final hp = full(progression.normalize(newProfile('Ana', 'guerrero')));
    final hn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: hp));
    final host = await make(hn, hp);
    for (final (n, f) in [('Leo', true), ('Mia', false)]) {
      var p = progression.normalize(newProfile(n, 'guerrero'));
      if (f) p = full(p);
      final cn = LoopbackNetSession(hub);
      await cn.connect(SessionConfig(profile: p, roomCode: hn.roomCode));
      await make(cn, p);
    }
    Future<void> tick([double s = 0.05]) async {
      for (final c in all.skip(1)) {
        c.advance(0.05);
      }
      await pumpEventQueue();
      host.advance(s);
      await pumpEventQueue();
    }

    await tick();
    await tick();
    expect(host.session!.players, hasLength(3));
    expect(host.proposeMission('m1'), isTrue);
    await tick();
    for (final c in all.skip(1)) {
      c.vote(true);
    }
    await tick(0.1);
    await tick(0.1);
    for (final c in all) {
      c.setReady(true);
    }
    await tick(0.1);
    await tick(0.1);
    expect(host.session!.mode, SessionMode.field);

    // Host (Ana) y Leo con el inventario lleno: lo suyo quedó en el piso.
    final ids = [for (final c in all) c.localId];
    final s = host.session!;
    var gid = 900;
    for (final id in [ids[0], ids[1]]) {
      for (final r in [Rarity.raro, Rarity.epico, Rarity.magico]) {
        s.ground.add(GroundLoot(
            id: gid++, drop: sword(r), x: 0, y: 0, ownerId: id));
      }
    }
    // Lo que Mia soltó (compartido) y nadie levantó vuelve a ella.
    s.ground.add(GroundLoot(
        id: gid++, drop: sword(Rarity.raro), x: 0, y: 0, byId: ids[2]));
    await tick();
    expect(host.session!.ground, hasLength(7));
    // v0.20.22: volver al pueblo manda el piso al Loot perdido; lo que
    // sigue recuperándose al alijo es lo propio al salir de la sala.
    for (final c in all) {
      c.dispose();
    }
    await pumpEventQueue();

    // Recargado desde el JSON guardado (como en disco).
    for (final (i, want) in [(0, 3), (1, 3), (2, 1)]) {
      final stash = (await AccountRepository(stores[i]).load()).stash;
      final got = [...stash.cells.whereType<StashEntry>(), ...stash.unclaimed]
          .where((e) => e.item?.baseId == 'espada_ignea')
          .toList();
      expect(got, hasLength(want), reason: 'jugador $i');
      // Uids distintos dentro del alijo.
      expect({for (final e in got) e.item!.uid}, hasLength(want));
    }
  });
}
