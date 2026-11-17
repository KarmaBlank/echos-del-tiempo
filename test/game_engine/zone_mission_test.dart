import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/zone_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Guerrero de nivel [level] con los puntos en VIT y FUE (gana sus
/// batallas solo atacando).
PlayerProfile strong(String name, {int level = 50, int zone = 1}) {
  final p = zoneProgression.normalize(
      PlayerProfile(name: name, classId: 'guerrero', level: level));
  final half = p.points ~/ 2;
  return zoneProgression
      .allocate(p, {Attribute.vit: half, Attribute.fue: p.points - half})!
      .copyWith(unlockedZone: zone);
}

/// Pelea contra el grupo [enemyId] (teletransporta al jugador encima) y
/// reparte puntos si sube de nivel. Vuelve al campo.
GameSession fight(SessionEngine e, GameSession s, int enemyId,
    {List<SessionEvent>? log}) {
  s = wait(e, s, s.graceLeft + 0.1, log: log);
  final en = s.mission!.enemy(enemyId)!;
  s = moveTo(e, s, 'p0', en.x, en.y);
  final step = e.tick(s, 0.05);
  log?.addAll(step.events);
  s = step.state;
  expect(s.mode, SessionMode.battle, reason: 'no empezó la batalla');
  s = runBattle(e, s,
      until: (x) => x.mode != SessionMode.battle, log: log);
  for (var i = 0; i < 5 && s.mode == SessionMode.levelUp; i++) {
    for (final p in s.playerList) {
      if (p.profile.points > 0) {
        s = act(e, s, p.id, AllocateStatsAction({Attribute.vit: p.profile.points}));
      }
    }
    s = e.tick(s, 0.05).state;
  }
  return s;
}

void main() {
  test('zona bloqueada: no se propone; m1 sí', () {
    final e = sessionEngine(zones: true);
    var s = e.create();
    s = e.addPlayer(s, 'p0', newProfile('Ana', 'guerrero'))!.state;
    expect(e.mapFor(s).entrances, hasLength(10), reason: 'lobby = mundo');
    expect(e.apply(s, 'p0', const ProposeMissionAction('z2')), isNull);
    expect(e.apply(s, 'p0', const ProposeMissionAction('m1')), isNotNull);
  });

  test('misión de zona: pisos, escaleras, jefe, resultado y desbloqueo', () {
    final e = sessionEngine(zones: true);
    var s = inField(e, 'm1', profiles: [strong('Ana')]);
    final log = <SessionEvent>[];
    var m = s.mission!;
    final map = e.mapFor(s);

    // ---- arranque ----
    expect(m.zone, 1);
    expect(m.floors, 2);
    expect(m.floor, 0);
    expect(m.levels, [2, 3]);
    expect(m.zoneLevel, 2);
    expect(map.floors, hasLength(2));
    expect(m.floorGoals, [4, 4]);
    expect(m.goal, 8);
    expect(m.objective(ObjectiveKind.kills)!.goal, 8);
    final p0 = s.players['p0']!;
    expect(map.floorAt(p0.x, p0.y)!.index, 0);
    expect(s.gateOpen, isFalse);
    // Enemigos de los dos pisos, cada uno dentro de su piso; jefe al final.
    for (final en in m.enemies) {
      expect(map.floorAt(en.x, en.y)!.index, en.floor);
    }
    final boss = m.enemies.singleWhere((x) => x.boss);
    expect(boss.floor, 1);
    expect(boss.group.first, 'reyLimo');
    expect(m.enemiesOn(0).where((x) => !x.boss && !x.elite).length,
        greaterThanOrEqualTo(4));
    expect(m.enemiesOn(0).where((x) => x.elite), hasLength(1));
    expect(m.itemsOn(0).where((i) => i.kind == MissionItemKind.chest),
        isNotEmpty);

    // ---- batalla de piso 1: nivel 2, XP escalada ----
    final first = m.enemiesOn(0).firstWhere((x) => !x.elite);
    final raw = first.group
        .map((id) => zoneProgression.catalog.enemies[id]!.xp)
        .fold(0, (a, b) => a + b);
    s = fight(e, s, first.id, log: log);
    m = s.mission!;
    expect(m.kills, 1);
    expect(m.xp, ZoneRules.battleXp(raw, 2));
    final ended = log
        .whereType<BattleStepEvent>()
        .expand((b) => b.events)
        .whereType<BattleEndedEvent>()
        .single;
    expect(ended.xp, ZoneRules.battleXp(raw, 2));

    // ---- despejar el piso 1 (cuota + fragmentos/sellos del piso) ----
    for (final it in m.itemsOn(0).where((i) => i.kind != MissionItemKind.chest)) {
      s = wait(e, s, s.graceLeft + 0.1);
      s = moveTo(e, s, 'p0', it.x, it.y);
      if (it.kind == MissionItemKind.seal) {
        s = act(e, s, 'p0', ActivateSealAction(it.id));
      } else {
        final st = e.tick(s, 0.05);
        log.addAll(st.events);
        s = st.state;
      }
      if (s.mode == SessionMode.battle) s = runBattle(e, s);
    }
    for (var guard = 0; guard < 12 && !s.gateOpen; guard++) {
      final next = s.mission!
          .enemiesOn(0)
          .where((x) => x.alive && !x.elite && !x.boss)
          .first;
      s = fight(e, s, next.id, log: log);
    }
    expect(s.mode, SessionMode.field);
    expect(s.mission!.floorCleared(0), isTrue);
    expect(s.gateOpen, isTrue);
    expect(log.whereType<StairsOpenedEvent>().single.floor, 0);

    // ---- bajar tocando la escalera ----
    final f0 = map.floor(0)!, f1 = map.floor(1)!;
    log.clear();
    s = wait(e, s, s.graceLeft + 0.1);
    final epoch = s.players['p0']!.epoch;
    s = moveTo(e, s, 'p0', f0.stairsDown!.x, f0.stairsDown!.y);
    var st = e.tick(s, 0.05);
    s = st.state;
    expect(st.events.whereType<FloorChangedEvent>().single.down, isTrue);
    expect(s.mission!.floor, 1);
    expect(s.mission!.zoneLevel, 3);
    expect(s.players['p0']!.epoch, epoch + 1);
    expect(map.floorAt(s.players['p0']!.x, s.players['p0']!.y), same(f1));
    expect(s.graceLeft, closeTo(SessionEngine.missionStartGrace, 1e-9));
    expect(s.gateOpen, isFalse, reason: 'barrera del jefe cerrada');

    // ---- subir con E y volver a bajar con E ----
    expect(e.apply(s, 'p0', const UseStairsAction(down: true)), isNull,
        reason: 'no hay escalera de bajada en el último piso');
    expect(e.apply(s, 'p0', const UseStairsAction(down: false)), isNull,
        reason: 'lejos de la escalera');
    s = moveTo(e, s, 'p0', f1.stairsUp!.x, f1.stairsUp!.y);
    s = act(e, s, 'p0', const UseStairsAction(down: false));
    expect(s.mission!.floor, 0);
    final p = s.players['p0']!;
    expect((p.x - f0.returnPoint!.x).abs(), lessThanOrEqualTo(7));
    s = moveTo(e, s, 'p0', f0.stairsDown!.x, f0.stairsDown!.y - 8);
    s = act(e, s, 'p0', const UseStairsAction(down: true));
    expect(s.mission!.floor, 1);

    // ---- el jefe: batalla de nivel 5, victoria y desbloqueo ----
    final mid = const SessionJson().toJson(s);
    final back = const SessionJson().fromJson(asJson(jsonDecode(jsonEncode(mid))));
    expect(jsonEncode(const SessionJson().toJson(back)), jsonEncode(mid));
    expect(back.mission!.floor, 1);
    expect(back.mission!.opened, {0});
    expect(back.mission!.enemies.map((x) => x.floor), m.enemies.map((x) => x.floor));

    s = wait(e, s, s.graceLeft + 0.1);
    s = moveTo(e, s, 'p0', boss.x, boss.y);
    st = e.tick(s, 0.05);
    s = st.state;
    expect(s.mode, SessionMode.battle);
    expect(s.battle!.boss, isTrue);
    expect(s.battle!.level, 5);
    final bossHp = s.battle!.state.enemies.first.maxHp;
    expect(bossHp, greaterThan(zoneProgression.catalog.enemies['reyLimo']!.hp));
    final bj = const SessionJson().toJson(s);
    expect(const SessionJson().fromJson(asJson(jsonDecode(jsonEncode(bj)))).battle!.level, 5);
    log.clear();
    s = runBattle(e, s, until: (x) => x.mode == SessionMode.result, log: log);
    for (var i = 0; i < 5 && s.mode == SessionMode.levelUp; i++) {
      s = act(e, s, 'p0',
          AllocateStatsAction({Attribute.vit: s.players['p0']!.profile.points}));
      s = runBattle(e, s, until: (x) => x.mode == SessionMode.result, log: log);
    }
    expect(s.mode, SessionMode.result);
    final r = s.result!;
    expect(r.success, isTrue);
    expect(r.zone, 1);
    expect(r.unlocked, {'p0': 2});
    expect(s.players['p0']!.profile.unlockedZone, 2);
    expect(log.whereType<ZoneUnlockedEvent>().single.zone, 2);
    final rj = const SessionJson().toJson(s);
    final rb = const SessionJson().fromJson(asJson(jsonDecode(jsonEncode(rj))));
    expect(rb.result!.unlocked, {'p0': 2});
    expect(rb.result!.zone, 1);

    // ---- vuelta al mundo: ahora puede proponer la zona 2 ----
    s = act(e, s, 'p0', const BackToLobbyAction());
    expect(e.mapFor(s).entrances, hasLength(10));
    expect(s.gateOpen, isFalse);
    expect(e.apply(s, 'p0', const ProposeMissionAction('z2')), isNotNull);
  });

  test('ganarla otra vez no vuelve a desbloquear; un amigo sí', () {
    final e = sessionEngine(zones: true);
    var s = inField(e, 'm1',
        profiles: [strong('Ana', zone: 3), strong('Beto')]);
    final boss = s.mission!.enemies.singleWhere((x) => x.boss);
    s = e.tick(s, 0.05).state;
    // Directo al jefe (el host confía en la posición, como el prototipo).
    final map = e.mapFor(s);
    s = act(e, s, 'p0', MoveAction(map.floor(0)!.stairsDown!.x,
        map.floor(0)!.stairsDown!.y, epoch: s.players['p0']!.epoch));
    s = e.tick(s, 0.05).state;
    expect(s.mission!.floor, 1);
    s = wait(e, s, s.graceLeft + 0.1);
    s = moveTo(e, s, 'p0', boss.x, boss.y);
    s = runBattle(e, s, until: (x) => x.mode == SessionMode.result);
    for (var i = 0; i < 5 && s.mode == SessionMode.levelUp; i++) {
      for (final p in s.playerList) {
        if (p.profile.points > 0) {
          s = act(e, s, p.id, AllocateStatsAction({Attribute.vit: p.profile.points}));
        }
      }
      s = runBattle(e, s, until: (x) => x.mode == SessionMode.result);
    }
    expect(s.result!.success, isTrue);
    expect(s.result!.unlocked, {'p1': 2});
    expect(s.players['p0']!.profile.unlockedZone, 3);
    expect(s.players['p1']!.profile.unlockedZone, 2);
  });

  test('todas las misiones de zona arrancan y pueblan cada piso', () {
    for (final id in ['m1', 'z2', 'm2', 'z4', 'z5']) {
      final e = sessionEngine(zones: true);
      final s = inField(e, id, profiles: [strong('Ana', zone: 5)]);
      final m = s.mission!;
      final z = zoneProgression.catalog.zoneOfMission(id)!;
      expect(m.floors, z.floors, reason: id);
      for (var f = 0; f < m.floors; f++) {
        expect(m.floorGoals[f], 4, reason: '$id piso $f');
        expect(m.enemiesOn(f).where((x) => x.elite), isNotEmpty);
        for (final en in m.enemiesOn(f)) {
          for (final t in en.group) {
            expect(zoneProgression.catalog.enemies.containsKey(t), isTrue,
                reason: '$id: $t');
          }
        }
      }
      expect(m.levels, [
        for (var f = 0; f < z.floors; f++) ZoneRules.floorLevel(z, f),
      ]);
    }
  });
}
