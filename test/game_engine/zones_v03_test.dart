import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/enemy_def.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/zone_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';
import 'zone_mission_test.dart' show strong;

/// Zonas 6–10 de la v0.3.0 (docs/specs/worldgen.md § 8–9).
void main() {
  const cat = GameCatalog.standard;
  const newZones = ['z6', 'z7', 'z8', 'z9', 'z10'];

  group('catálogo v0.3', () {
    test('las 10 zonas jugables con su misión, en orden', () {
      expect(cat.zones.every((z) => z.playable), isTrue);
      expect(cat.missions.map((m) => m.id),
          ['m1', 'z2', 'm2', 'z4', 'z5', ...newZones]);
      expect(cat.zones.skip(5).map((z) => z.theme),
          ['laberinto', 'grieta', 'cementerio', 'abismo', 'corazon']);
      expect(cat.zones.skip(5).map((z) => z.floors), [4, 4, 4, 5, 5]);
      expect(cat.zones.skip(5).map((z) => z.bossId),
          ['hechicera', 'bestiaMagma', 'espectroCoronado', 'centinela', 'devorador']);
    });

    test('enemigos nuevos: existen, nivel nativo = mínimo de la zona; jefes al máximo',
        () {
      const commons = {
        6: ['ecoSombra', 'guardianReloj'],
        7: ['salamandra', 'golemMagma'],
        8: ['necrofago', 'almaErrante'],
        9: ['vigilanteVacio', 'ojoAbismo'],
        10: ['heraldoEras', 'fragmentoTiempo'],
      };
      for (final MapEntry(key: zi, value: ids) in commons.entries) {
        final z = cat.zone(zi)!;
        final m = cat.mission(z.missionId!)!;
        final used = {for (final g in m.floorGroups) ...g.expand((x) => x)};
        for (final id in ids) {
          expect(cat.enemies.containsKey(id), isTrue, reason: id);
          expect(kEnemyBaseLevel[id], z.minLevel, reason: id);
          expect(used.contains(id), isTrue, reason: '$id en ${m.id}');
        }
        expect(cat.enemies.containsKey(z.bossId), isTrue);
        expect(kEnemyBaseLevel[z.bossId], z.maxLevel, reason: z.bossId);
        expect(m.boss.first, z.bossId);
      }
      expect(kEnemyBaseLevel['devorador'], 50);
    });

    test('invocaciones de jefes: nivel nativo y nunca en el campo', () {
      expect(kEnemyBaseLevel['ecoHechicera'], 30);
      expect(kEnemyBaseLevel['siervoEspectral'], 40);
      for (final m in cat.missions) {
        final all = {
          m.elite,
          ...m.boss,
          ...m.groups.expand((x) => x),
          for (final g in m.floorGroups) ...g.expand((x) => x),
        };
        expect(all.intersection({'ecoHechicera', 'siervoEspectral', 'cristalHielo'}),
            isEmpty, reason: m.id);
      }
    });

    test('ritmo: del 1 al ~50 en 2 pasadas por zona (20 misiones)', () {
      // Por pasada: 5 grupos por piso (de los grupos del piso, XP del
      // catálogo), media élite por piso (élite ×3 + 1er enemigo) y el
      // grupo del jefe; todo con la XP escalada por nivel (§ 6.3).
      int raw(List<String> g) =>
          g.fold(0, (a, id) => a + cat.enemies[id]!.xp);
      var level = 1, xp = 0;
      final after = <int>[];
      for (final z in cat.zones) {
        final m = cat.mission(z.missionId!)!;
        for (var run = 0; run < 2; run++) {
          var gained = 0.0;
          for (var f = 0; f < z.floors; f++) {
            final groups = m.groupsFor(f);
            final avg = groups.fold(0, (a, g) => a + raw(g)) / groups.length;
            final elite = 3 * raw([m.elite]) + raw([groups.first.first]);
            gained += 5 * avg * ZoneRules.xpMult(ZoneRules.floorLevel(z, f));
            gained += 0.5 * elite * ZoneRules.xpMult(ZoneRules.eliteLevel(z, f));
          }
          gained += raw(m.boss) * ZoneRules.xpMult(z.maxLevel);
          xp += gained.round();
          while (level < ProgressionRules.maxLevel &&
              xp >= ProgressionRules.xpNeed(level)) {
            xp -= ProgressionRules.xpNeed(level);
            level++;
          }
          after.add(level);
        }
      }
      // ignore: avoid_print
      print('niveles tras cada pasada: $after');
      for (var zi = 5; zi < 10; zi++) {
        final z = cat.zones[zi];
        expect(after[zi * 2 + 1],
            inInclusiveRange(z.minLevel - 3, z.maxLevel + 2),
            reason: 'zona ${zi + 1}: $after');
      }
      expect(after.last, inInclusiveRange(44, 50));
    });
  });

  group('misiones de las zonas 6–10', () {
    for (final id in newZones) {
      test('$id: pisos poblados, sin enemigos sobre el vacío, hasta el jefe', () {
        final e = sessionEngine(zones: true);
        var s = inField(e, id, profiles: [strong('Ana', zone: 10)]);
        final z = cat.zoneOfMission(id)!;
        final map = e.mapFor(s);
        var m = s.mission!;
        expect(m.zone, z.index);
        expect(m.floors, z.floors);
        expect(map.theme, z.theme);
        expect(m.levels,
            [for (var f = 0; f < z.floors; f++) ZoneRules.floorLevel(z, f)]);
        for (var f = 0; f < m.floors; f++) {
          expect(m.floorGoals[f], 4, reason: '$id piso $f');
          expect(m.enemiesOn(f).where((x) => x.elite), isNotEmpty);
        }
        for (final en in m.enemies) {
          expect(map.floorAt(en.x, en.y)!.index, en.floor);
          expect(WorldRules.collides(map, en.x, en.y, blockVoid: true), isFalse,
              reason: '$id enemigo ${en.id}');
          for (final t in en.group) {
            expect(cat.enemies.containsKey(t), isTrue, reason: t);
          }
        }
        for (final it in m.items) {
          expect(WorldRules.overVoid(map, it.x, it.y), isFalse);
        }
        // Los enemigos deambulan sin entrar al vacío.
        s = wait(e, s, 12);
        for (final en in s.mission!.enemiesOn(0)) {
          expect(WorldRules.overVoid(map, en.x, en.y), isFalse);
        }
        // Bajar piso por piso (el host confía en la posición).
        for (var f = 0; f < z.floors - 1; f++) {
          final down = map.floor(f)!.stairsDown!;
          s = moveTo(e, s, 'p0', down.x, down.y);
          s = e.tick(s, 0.05).state;
          if (s.mode == SessionMode.battle) {
            s = runBattle(e, s);
            s = moveTo(e, s, 'p0', down.x, down.y);
            s = e.tick(s, 0.05).state;
          }
          expect(s.mission!.floor, f + 1, reason: '$id piso $f');
        }
        m = s.mission!;
        expect(m.zoneLevel, ZoneRules.floorLevel(z, z.floors - 1));
        final boss = m.enemies.singleWhere((x) => x.boss);
        s = wait(e, s, s.graceLeft + 0.1);
        s = moveTo(e, s, 'p0', boss.x, boss.y);
        s = e.tick(s, 0.05).state;
        expect(s.mode, SessionMode.battle);
        expect(s.battle!.boss, isTrue);
        expect(s.battle!.level, z.maxLevel);
        expect(s.battle!.state.enemies.first.enemyType, z.bossId);
      });
    }

    test('caer al vacío: vuelve al spawn del piso, sin daño, con evento', () {
      final e = sessionEngine(zones: true);
      var s = inField(e, 'z9', profiles: [strong('Ana', zone: 10)]);
      final map = e.mapFor(s);
      final f0 = map.floor(0)!;
      (int, int)? v;
      for (var y = f0.bounds.y + 2; y < f0.bounds.h - 2 && v == null; y++) {
        for (var x = f0.bounds.x + 2; x < f0.bounds.x + f0.bounds.w - 2; x++) {
          if (map.tileAt(x, y) == Tile.voidTile &&
              WorldRules.distance(x * 16.0, y * 16.0, f0.spawn.x, f0.spawn.y) > 80) {
            v = (x, y);
            break;
          }
        }
      }
      expect(v, isNotNull);
      final hp = s.players['p0']!.hp;
      final epoch = s.players['p0']!.epoch;
      s = moveTo(e, s, 'p0', v!.$1 * 16 + 8.0, v.$2 * 16 + 8.0);
      final step = e.tick(s, 0.05);
      s = step.state;
      final p = s.players['p0']!;
      final fall = step.events.whereType<FellIntoVoidEvent>().single;
      expect(fall.playerId, 'p0');
      expect(fall.floor, 0);
      expect(step.events.whereType<SystemMessageEvent>().map((x) => x.text),
          contains('Ana cayó al vacío.'));
      expect(p.epoch, epoch + 1);
      expect(p.hp, hp);
      expect(WorldRules.distance(p.x, p.y, f0.spawn.x, f0.spawn.y),
          lessThanOrEqualTo(10));
      expect(WorldRules.overVoid(map, p.x, p.y), isFalse);
      // Un MoveAction viejo (época anterior) ya no lo devuelve al vacío.
      expect(e.apply(s, 'p0',
          MoveAction(v.$1 * 16 + 8.0, v.$2 * 16 + 8.0, epoch: epoch)), isNull);
      // El evento viaja por red.
      const ej = EventJson();
      final back = ej.fromJson(asJson(jsonDecode(jsonEncode(ej.toJson(fall)))));
      expect(back, isA<FellIntoVoidEvent>());
      expect((back as FellIntoVoidEvent).playerId, 'p0');
      expect(back.floor, 0);
      expect(ej.toJson(fall), {'t': 'fall', 'id': 'p0', 'f': 0});
    });

    test('sin vacío (laberinto) nunca hay caída', () {
      final e = sessionEngine(zones: true);
      var s = inField(e, 'z6', profiles: [strong('Ana', zone: 10)]);
      final log = <SessionEvent>[];
      s = wait(e, s, 3, log: log);
      expect(log.whereType<FellIntoVoidEvent>(), isEmpty);
    });

    test('estado de una misión de abismo: JSON ida y vuelta', () {
      final e = sessionEngine(zones: true);
      final s = inField(e, 'z10', profiles: [strong('Ana', zone: 10)]);
      final j = const SessionJson().toJson(s);
      final back = const SessionJson().fromJson(asJson(jsonDecode(jsonEncode(j))));
      expect(jsonEncode(const SessionJson().toJson(back)), jsonEncode(j));
      expect(back.mission!.zone, 10);
      expect(back.mission!.levels, s.mission!.levels);
      expect(e.mapFor(back).rows, e.mapFor(s).rows);
    });
  });

  group('desbloqueo hasta la zona 10', () {
    test('cada zona pide la anterior; con la 10 desbloqueada se propone todo', () {
      for (var zi = 6; zi <= 10; zi++) {
        final z = cat.zone(zi)!;
        final locked = newProfile('Ana', 'guerrero').copyWith(unlockedZone: zi - 1);
        final open = locked.copyWith(unlockedZone: zi);
        expect(ZoneRules.canPropose(cat, locked, z.missionId!), isFalse);
        expect(ZoneRules.canPropose(cat, open, z.missionId!), isTrue);
        final prev = cat.zone(zi - 1)!;
        expect(ZoneRules.zoneList(cat, locked)[zi - 1].label,
            'Bloqueada: vencé a ${prev.bossName} en ${prev.name}');
        expect(ZoneRules.zoneList(cat, open)[zi - 1].open, isTrue);
      }
    });

    test('vencer al jefe de la zona 9 abre la 10 (y suelta su legendario)', () {
      // Jefe y su grupo debilitados: se prueba el desbloqueo, no la pelea
      // (las mecánicas de jefe tienen sus propios tests).
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
        battles: BattleEngine(stats: statsCalc, catalog: weak, random: () => 0.5),
        progression: ProgressionRules(stats: statsCalc, catalog: weak),
        // 0.05 < bossLegendaryChance: el jefe suelta su legendario.
        random: () => 0.05,
        seeds: () => 777,
      );
      var s = inField(e, 'z9', profiles: [strong('Ana', zone: 9)]);
      final map = e.mapFor(s);
      final log = <SessionEvent>[];
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
      final boss = s.mission!.enemies.singleWhere((x) => x.boss);
      s = wait(e, s, s.graceLeft + 0.1);
      s = moveTo(e, s, 'p0', boss.x, boss.y);
      s = runBattle(e, s, until: (x) => x.mode == SessionMode.result, log: log);
      for (var i = 0; i < 5 && s.mode == SessionMode.levelUp; i++) {
        s = runBattle(e, s, until: (x) => x.mode == SessionMode.result, log: log);
      }
      expect(s.result?.success, isTrue);
      expect(s.result!.zone, 9);
      expect(s.result!.unlocked, {'p0': 10});
      expect(s.players['p0']!.profile.unlockedZone, 10);
      expect(log.whereType<ZoneUnlockedEvent>().single.zone, 10);
      final legend = log.whereType<LootDropEvent>().where(
          (x) => x.source == LootSource.boss && x.drop.item?.uniqueId == 'rompemundos');
      expect(legend, hasLength(1));
      expect(legend.single.drop.item!.itemLevel, greaterThanOrEqualTo(45));
      expect(log.whereType<SystemMessageEvent>().map((x) => x.text).join('\n'),
          isNot(contains('Próximamente')));
      s = act(e, s, 'p0', const BackToLobbyAction());
      expect(e.apply(s, 'p0', const ProposeMissionAction('z10')), isNotNull);
    });
  });

  group('curva por tramos (combo_balance.md § 1)', () {
    test('pisos C: 1 élite cada 3 grupos; pisos A/B como antes', () {
      var cPisos = 0;
      for (final id in const ['z5', 'z6']) {
        final e = sessionEngine(zones: true);
        final s = inField(e, id, profiles: [strong('Ana', zone: 10)]);
        final z = cat.zoneOfMission(id)!;
        final m = s.mission!;
        for (final f in m.enemies.map((x) => x.floor).toSet()) {
          final here = m.enemies.where((x) => x.floor == f && !x.boss);
          final elites = here.where((x) => x.elite).length;
          final commons = here.length - elites;
          if (ZoneRules.isZoneC(ZoneRules.floorLevel(z, f))) {
            cPisos++;
            expect(elites, greaterThanOrEqualTo((commons / 2).ceil()),
                reason: '$id piso $f: $elites élites, $commons comunes');
          } else {
            expect(elites, lessThanOrEqualTo(2), reason: '$id piso $f');
          }
        }
      }
      expect(cPisos, greaterThan(0));
    });
  });
}
