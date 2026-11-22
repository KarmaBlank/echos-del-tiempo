import 'dart:convert';

import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/enemy_def.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';
import 'zone_mission_test.dart' show strong;

/// El loot propio nunca se pierde (loot.md § 4b, § 14.3).
void main() {
  LootDrop sword(String uid, [Rarity r = Rarity.raro]) => LootDrop.item(
      ItemInstance(uid: uid, baseId: 'espada_ignea', rarity: r, itemLevel: 2));

  List<LootDrop> recovered(GameSession s, String id) => [
        for (final MapEntry(key: k, value: a)
            in s.players[id]!.stashAcks.entries)
          if (StashAck.isRecover(k)) ...a.drops.whereType<LootDrop>(),
      ];

  PlayerProfile full(PlayerProfile p) {
    var i = 0;
    while (InventoryRules.freeCells(p) > 0) {
      p = InventoryRules.receive(p, sword('relleno${i++}'))!;
    }
    return p;
  }

  group('motor', () {
    test('al volver al pueblo lo propio del piso va al alijo; lo oculto, no',
        () {
      final e = sessionEngine();
      var s = inField(e, 'm3');
      s.ground
        ..add(GroundLoot(id: 1, drop: sword('a'), x: 0, y: 0, ownerId: 'p0'))
        ..add(GroundLoot(id: 2, drop: sword('b'), x: 0, y: 0, floor: 1,
            ownerId: 'p0'))
        ..add(GroundLoot(id: 3, drop: sword('c'), x: 0, y: 0, byId: 'p0'))
        ..add(GroundLoot(id: 4, drop: sword('d'), x: 0, y: 0, ownerId: 'nadie'));
      s.mode = SessionMode.result;
      s = act(e, s, 'p0', const BackToLobbyAction());
      expect(s.ground, isEmpty);
      expect(recovered(s, 'p0').map((d) => d.item!.uid), ['a', 'b', 'c']);
    });

    test('lo que el filtro oculta vuelve, a Objetos sin recoger', () {
      final e = sessionEngine();
      var s = inField(e, 'm3');
      s = act(e, s, 'p0',
          const SetLootFilterAction('Ocultar\n  Rareza Común\n'));
      s.ground.add(GroundLoot(
          id: 1, drop: sword('a', Rarity.comun), x: 0, y: 0, ownerId: 'p0'));
      s.mode = SessionMode.result;
      s = act(e, s, 'p0', const BackToLobbyAction());
      expect(recovered(s, 'p0').single.item!.uid, 'a');
      expect(s.players['p0']!.stashAcks.values.single.box, isTrue);
    });

    test('co-op: cada uno recibe lo suyo', () {
      final e = sessionEngine();
      var s = inField(e, 'm3', profiles: [
        newProfile('Ana', 'guerrero'),
        newProfile('Beto', 'guerrero'),
      ]);
      s.ground
        ..add(GroundLoot(id: 1, drop: sword('a'), x: 0, y: 0, ownerId: 'p0'))
        ..add(GroundLoot(id: 2, drop: sword('b'), x: 0, y: 0, ownerId: 'p1'));
      s.mode = SessionMode.result;
      s = act(e, s, 'p0', const BackToLobbyAction());
      expect(recovered(s, 'p0').single.item!.uid, 'a');
      expect(recovered(s, 'p1').single.item!.uid, 'b');
      // Viaja en el snapshot (host autoritativo; el cliente lo guarda).
      const codec = SessionJson();
      final back = codec.fromJson(
          asJson(jsonDecode(jsonEncode(codec.toJson(s)))));
      expect(recovered(back, 'p1').single.item!.uid, 'b');
    });

    test('quien sale de la sala: el host saca lo suyo del piso', () {
      final e = sessionEngine();
      var s = inField(e, 'm3', profiles: [
        newProfile('Ana', 'guerrero'),
        newProfile('Beto', 'guerrero'),
      ]);
      s.ground.add(GroundLoot(id: 1, drop: sword('b'), x: 0, y: 0, ownerId: 'p1'));
      s = e.removePlayer(s, 'p1')!.state;
      expect(s.ground, isEmpty);
    });

    test('el piso de un objeto compartido viaja con quien lo soltó', () {
      const codec = SessionJson();
      final g = GroundLoot(id: 1, drop: sword('a'), x: 1, y: 2, byId: 'p0');
      expect(codec.groundFromJson(asJson(codec.groundToJson(g))).byId, 'p0');
    });

    test('jefe con el inventario lleno: el legendario va al alijo, no al piso',
        () {
      const cat = GameCatalog.standard;
      final weak = GameCatalog(
        classes: cat.classes,
        weapons: cat.weapons,
        skills: cat.skills,
        ultimates: cat.ultimates,
        duals: cat.duals,
        enemies: {
          ...cat.enemies,
          for (final id in ['centinela', 'ojoAbismo'])
            id: EnemyDef(id: id, name: id, hp: 5, attack: 1, speed: 1, xp: 1,
                credits: 1, boss: id == 'centinela',
                legendaryId: id == 'centinela' ? 'rompemundos' : null),
        },
      );
      final e = SessionEngine(
        battles:
            BattleEngine(stats: statsCalc, catalog: weak, random: () => 0.5),
        progression: ProgressionRules(stats: statsCalc, catalog: weak),
        random: () => 0.05,
        seeds: () => 777,
      );
      var s = inField(e, 'z9', profiles: [strong('Ana', zone: 9)]);
      final map = e.mapFor(s);
      for (var f = 0; f < 4; f++) {
        final down = map.floor(f)!.stairsDown!;
        s = moveTo(e, s, 'p0', down.x, down.y);
        s = e.tick(s, 0.05).state;
        if (s.mode == SessionMode.battle) {
          s = runBattle(e, s);
          s = moveTo(e, s, 'p0', down.x, down.y);
          s = e.tick(s, 0.05).state;
        }
      }
      expect(s.mission!.floor, 4);
      s.players['p0']!.profile = full(s.players['p0']!.profile);
      final boss = s.mission!.enemies.singleWhere((x) => x.boss);
      s = wait(e, s, s.graceLeft + 0.1);
      s = moveTo(e, s, 'p0', boss.x, boss.y);
      final log = <SessionEvent>[];
      s = runBattle(e, s, until: (x) => x.mode == SessionMode.result, log: log);
      for (var i = 0; i < 5 && s.mode == SessionMode.levelUp; i++) {
        s = runBattle(e, s,
            until: (x) => x.mode == SessionMode.result, log: log);
      }
      bool legend(LootDrop d) => d.item?.uniqueId == 'rompemundos';
      expect(s.ground.where((g) => legend(g.drop)), isEmpty);
      expect(recovered(s, 'p0').where(legend), hasLength(1));
      expect(
          log.whereType<SystemMessageEvent>().map((m) => m.text).join('\n'),
          contains('se guardó en el alijo'));
    });
  });

  group('alijo y Objetos sin recoger', () {
    test('entra al alijo; lleno, a la caja; un uid repetido no se pierde',
        () {
      var st = Stash.empty();
      final r1 = StashRules.recover(st, sword('nuevo'));
      expect(r1.toBox, isFalse);
      st = r1.stash;
      // Otra arma recién tirada (mismo uid provisorio): se renombra.
      st = StashRules.recover(st, sword('nuevo')).stash;
      final uids = [for (final c in st.cells) if (c?.item != null) c!.item!.uid];
      expect(uids, hasLength(2));
      expect(uids.toSet(), hasLength(2));
      expect(StashRules.recover(Stash.empty(), sword('a'), box: true).toBox,
          isTrue);
      // Alijo lleno.
      var fullSt = Stash.empty();
      for (var i = 0; i < Stash.size; i++) {
        if (Stash.accepts(i, StashEntry.item(sword('x$i').item!))) {
          fullSt = fullSt.put(i, StashEntry.item(sword('x$i').item!));
        }
      }
      final r2 = StashRules.recover(fullSt, sword('b'));
      expect(r2.toBox, isTrue);
      expect(r2.stash.unclaimed.single.item!.uid, 'b');
    });

    test('TOMAR y DESCARTAR', () {
      final st = Stash.empty().withUnclaimed([
        StashEntry.item(sword('a').item!),
        const StashEntry.material(CraftMaterial.cristal, 3),
      ]);
      final p = newProfile('Ana', 'guerrero');
      final m = const StashRules().claim(p, st, 0);
      expect(m.ok, isTrue);
      expect(m.profile!.items.length, p.items.length + 1);
      expect(m.stash!.unclaimed, hasLength(1));
      final d = StashRules.dropUnclaimed(m.stash!, 0)!;
      expect(d.unclaimed, isEmpty);
      // Inventario lleno: TOMAR se rechaza y queda en la caja.
      final no = const StashRules().claim(full(p), st, 0);
      expect(no.ok, isFalse);
      // Confirmación del host (en partida).
      expect(StashRules.untakeBox(st, 0, sword('a'))!.unclaimed, hasLength(1));
      expect(
          StashRules.untakeBox(
                  st, 1, const LootDrop.stack(StackKind.cristal, 2))!
              .unclaimed
              .last
              .count,
          1);
    });

    test('persistencia: ida y vuelta, y un alijo viejo sin caja', () {
      final st = Stash.empty().withUnclaimed([
        StashEntry.item(sword('a').item!),
        const StashEntry.material(CraftMaterial.cristal, 3),
      ]);
      final back = Stash.fromJson(st.toJson());
      expect(back.unclaimed.map((e) => e.item?.uid ?? e.material!.name),
          ['a', 'cristal']);
      expect(Stash.fromJson({'cells': []}).unclaimed, isEmpty);
      expect(Stash.empty().toJson().containsKey('uncl'), isFalse);
    });
  });
}
