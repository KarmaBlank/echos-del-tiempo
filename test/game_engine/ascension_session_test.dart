import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/trials_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/ascension_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/trial_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecos_session_test.dart' show lobby, winBattle;
import 'session_test_helpers.dart';

/// Pruebas del Tiempo y ascensión en la sala (docs/specs/ascension.md).

/// Personaje válido de [classId] y [level] con las Pruebas [trials].
PlayerProfile hero(String name,
    {int level = 30,
    String classId = 'guerrero',
    Set<int> trials = const {},
    String? asc,
    List<String> nodes = const []}) {
  final p = zoneProgression
      .normalize(PlayerProfile(name: name, classId: classId, level: level));
  final half = p.points ~/ 2;
  final q = zoneProgression.allocate(p, {
    Attribute.vit: half,
    Attribute.fue: p.points - half,
  })!;
  return zoneProgression.normalize(q.copyWith(
      ascension: AscensionProgress(trials: trials, id: asc, nodes: nodes)));
}

/// p0 propone la Prueba [n], todos votan y se preparan → campo.
GameSession openTrial(SessionEngine e, GameSession s, int n) {
  s = act(e, s, 'p0', ProposeTrialAction(n));
  for (final id in s.players.keys.skip(1)) {
    s = act(e, s, id, const VoteMissionAction(true));
  }
  s = e.tick(s, 0.05).state;
  expect(s.mode, SessionMode.prep);
  for (final id in s.players.keys) {
    s = act(e, s, id, const ReadyAction(true));
  }
  return e.tick(s, 0.05).state;
}

/// Pasa al último piso, pelea con el jefe y gana (reparte los puntos de
/// nivel si alguien sube).
GameSession beatTrial(SessionEngine e, GameSession s, List<SessionEvent> log) {
  final m = s.mission!;
  m.floor = m.floors - 1;
  s = wait(e, s, s.graceLeft + 0.1, log: log);
  final boss = s.mission!.enemies.singleWhere((x) => x.boss);
  s = moveTo(e, s, 'p0', boss.x, boss.y);
  s = e.tick(s, 0.05).state;
  expect(s.mode, SessionMode.battle);
  s = winBattle(e, s,
      until: (x) => x.result != null || x.mode == SessionMode.levelUp,
      log: log);
  for (var i = 0; i < 20 && s.mode == SessionMode.levelUp; i++) {
    for (final p in s.playerList) {
      if (p.levelUpPending && p.profile.points > 0) {
        s = act(e, s, p.id,
            AllocateStatsAction({Attribute.vit: p.profile.points}));
      }
    }
    final st = e.tick(s, 0.05);
    log.addAll(st.events);
    s = st.state;
  }
  expect(s.result, isNotNull);
  return s;
}

int _count(GameMap m, String tile) =>
    m.rows.fold(0, (n, r) => n + tile.allMatches(r).length);

void main() {
  const trials = TrialRules();
  const asc = AscensionRules();

  group('TrialRules', () {
    test('disponibilidad: nivel y la Prueba anterior', () {
      expect(trials.cannotPropose(hero('A', level: 29), 1), 'Requiere nivel 30');
      expect(trials.cannotPropose(hero('A'), 1), isNull);
      expect(trials.cannotPropose(hero('A', level: 40), 2),
          'Superá antes la Prueba I');
      expect(trials.cannotPropose(hero('A', level: 40, trials: {1}), 2), isNull);
      expect(trials.cannotPropose(hero('A', level: 45, trials: {1, 2}), 3),
          'Requiere nivel 50');
      expect(trials.cannotPropose(hero('A', level: 50, trials: {1, 2}), 3), isNull);
      // Repetible, pero sin puntos la segunda vez.
      final done = hero('A', trials: {1});
      expect(trials.cannotPropose(done, 1), isNull);
      expect(trials.earnsPoints(done, 1), isFalse);
      expect(trials.earnsPoints(hero('A'), 1), isTrue);
    });

    test('2 puntos por Prueba, 6 en total; árbol de 10', () {
      expect(const AscensionProgress(trials: {1}).earned, 2);
      expect(const AscensionProgress(trials: {1, 2, 3}).earned, 6);
      expect(kTrials.map((t) => t.level), [30, 40, 50]);
      expect(kTrials.map((t) => t.monsterLevel), [32, 42, 52]);
    });

    test('la mazmorra trae púas y pulsos lejos del spawn y de la arena', () {
      for (final t in kTrials) {
        final m = trials.map(t, 1234);
        expect(m.floors, hasLength(t.floors));
        expect(trials.map(t, 1234).rows, m.rows, reason: 'determinística');
        expect(_count(m, Tile.spikes), greaterThan(0), reason: t.name);
        expect(_count(m, Tile.pulse), greaterThan(0), reason: t.name);
        for (final f in m.floors) {
          final sx = (f.spawn.x / 16).floor(), sy = (f.spawn.y / 16).floor();
          for (var y = sy - 6; y <= sy + 6; y++) {
            for (var x = sx - 6; x <= sx + 6; x++) {
              if (!m.contains(x, y)) continue;
              expect(TrialRules.trapAt(m.tileAt(x, y)), isNull,
                  reason: 'trampa junto al spawn del piso ${f.index}');
            }
          }
          final ar = f.arena!;
          for (var y = ar.y; y < ar.y + ar.h; y++) {
            for (var x = ar.x; x < ar.x + ar.w; x++) {
              expect(TrialRules.trapAt(m.tileAt(x, y)), isNull);
            }
          }
        }
        // Las trampas se pisan (no bloquean caminos).
        expect(Tile.isWalkable(Tile.spikes), isTrue);
        expect(Tile.isWalkable(Tile.pulse), isTrue);
      }
    });

    test('el pulso carga 2 s y está activo 1 s', () {
      expect(TrialRules.pulseActive(0.5), isFalse);
      expect(TrialRules.pulseActive(2.1), isTrue);
      expect(TrialRules.pulseActive(3.2), isFalse);
      expect(TrialRules.pulseCharge(1.0), closeTo(0.5, 1e-9));
      expect(TrialRules.pulseCharge(2.5), 1);
    });

    test('la Estatua del Tiempo está en el pueblo y es sólida', () {
      final w = MapGenerator.town();
      final st = TownLayout.landmark(TownSpot.statue);
      expect(w.tileAt(st.x + 1, st.y), Tile.statue);
      expect(WorldRules.isSolid(w, st.x + 1, st.y), isTrue);
      expect(WorldRules.townSpot(st.center.x, (st.y + 1.5) * 16),
          TownSpot.statue);
      expect(WorldRules.townSpot(w.spawn.x, w.spawn.y), isNull);
    });
  });

  group('en la sala', () {
    test('proponer, jugar y completar: cada uno gana sus puntos (co-op)', () {
      final e = sessionEngine(zones: true);
      var s = lobby(e, [
        hero('Ana'), // gana
        hero('Bo', level: 25), // nivel bajo: acompaña
        hero('Cy', level: 50, trials: {1}), // ya la tenía
      ]);
      expect(e.apply(s, 'p1', const ProposeTrialAction(1)), isNull);
      s = openTrial(e, s, 1);
      expect(s.mode, SessionMode.field);
      expect(s.trial, 1);
      final m = s.mission!;
      expect(m.missionId, TrialRules.missionId);
      expect(m.floors, 2);
      expect(m.zoneLevel, 32);
      final map = e.mapFor(s);
      expect(_count(map, Tile.spikes), greaterThan(0));
      expect(m.enemies.singleWhere((x) => x.boss).group.first, 'golemReloj');
      expect(e.missionOf(s, 'trial')!.name, 'Prueba del Tiempo I · El Umbral');

      final log = <SessionEvent>[];
      s = beatTrial(e, s, log);
      expect(s.result!.success, isTrue);
      expect(s.result!.unlocked, isEmpty, reason: 'una Prueba no desbloquea zonas');
      final done = log.whereType<TrialCompletedEvent>().single;
      expect(done.trial, 1);
      expect(done.playerIds, ['p0']);
      expect(s.players['p0']!.profile.ascension.trials, {1});
      expect(s.players['p1']!.profile.ascension.trials, isEmpty);
      expect(s.players['p2']!.profile.ascension.trials, {1});
      expect(
          log.whereType<SystemMessageEvent>().map((x) => x.text),
          contains('Ana superó la Prueba del Tiempo I · El Umbral: +2 puntos '
              'de ascensión.'));

      // Elegir en el resultado: cinemática para todos.
      final st = e.apply(s, 'p0', const ChooseAscensionAction('berserker'))!;
      expect(st.events.whereType<AscensionChosenEvent>().single.ascensionId,
          'berserker');
      expect(st.state.players['p0']!.profile.ascension.id, 'berserker');
      // Volver al pueblo limpia la Prueba.
      s = backToLobby(e, st.state);
      expect(s.trial, isNull);
    });

    test('rechazar la votación limpia la Prueba', () {
      final e = sessionEngine(zones: true);
      var s = lobby(e, [hero('Ana'), hero('Bo')]);
      s = act(e, s, 'p0', const ProposeTrialAction(1));
      expect(s.vote!.missionId, 'trial');
      s = act(e, s, 'p1', const VoteMissionAction(false));
      expect(s.trial, isNull);
      expect(e.apply(s, 'p0', const ProposeTrialAction(2)), isNull);
      expect(e.apply(s, 'p0', const ProposeTrialAction(9)), isNull);
    });

    test('púas: −8% por segundo sin matar; pulso activo devuelve al spawn', () {
      final e = sessionEngine(zones: true);
      var s = openTrial(e, lobby(e, [hero('Ana')]), 1);
      final map = e.mapFor(s);
      final f = map.floor(0)!;
      (int, int) find(String tile) {
        for (var y = f.bounds.y; y < f.bounds.y + f.bounds.h; y++) {
          for (var x = f.bounds.x; x < f.bounds.x + f.bounds.w; x++) {
            if (map.tileAt(x, y) == tile) return (x, y);
          }
        }
        throw StateError('sin $tile');
      }

      // Púas.
      final (sx, sy) = find(Tile.spikes);
      s = moveTo(e, s, 'p0', sx * 16 + 8.0, sy * 16 + 8.0);
      final log = <SessionEvent>[];
      final max = s.players['p0']!.maxHp;
      s.players['p0']!.hp = max.toDouble();
      s = wait(e, s, 0.1, log: log);
      final hits = log.whereType<TrapTriggeredEvent>().toList();
      expect(hits, hasLength(1), reason: 'una vez por segundo');
      expect(hits.single.kind, TrapKind.spikes);
      expect(hits.single.damage, (max * 0.08).round());
      s.players['p0']!.hp = 2;
      s = wait(e, s, 1.1, log: log);
      expect(s.players['p0']!.hp, greaterThanOrEqualTo(1));
      expect(s.players['p0']!.alive, isTrue);

      // Pulso: inactivo no hace nada; activo devuelve al spawn del piso.
      final (px, py) = find(Tile.pulse);
      while (TrialRules.pulseActive(s.time + 0.05)) {
        s = e.tick(s, 0.05).state;
      }
      s = moveTo(e, s, 'p0', px * 16 + 8.0, py * 16 + 8.0);
      s = e.tick(s, 0.05).state;
      expect(s.players['p0']!.x, px * 16 + 8.0);
      final epoch = s.players['p0']!.epoch;
      final plog = <SessionEvent>[];
      while (!TrialRules.pulseActive(s.time)) {
        final st = e.tick(s, 0.05);
        plog.addAll(st.events);
        s = st.state;
        s = moveTo(e, s, 'p0', px * 16 + 8.0, py * 16 + 8.0);
      }
      s = wait(e, s, 0.1, log: plog);
      expect(plog.whereType<TrapTriggeredEvent>().map((x) => x.kind),
          contains(TrapKind.pulse));
      expect(s.players['p0']!.epoch, greaterThan(epoch));
      expect((s.players['p0']!.x - f.spawn.x).abs(), lessThan(16));
    });

    test('elegir, tomar nodos y reiniciar (gratis)', () {
      final e = sessionEngine(zones: true);
      var s = lobby(e, [hero('Ana', level: 40, trials: {1, 2})]);
      expect(e.apply(s, 'p0', const ChooseAscensionAction('cronomante')), isNull,
          reason: 'de otra clase');
      s = act(e, s, 'p0', const ChooseAscensionAction('senorGuerra'));
      final p = s.players['p0']!.profile;
      expect(p.ascension.id, 'senorGuerra');
      expect(asc.free(p.ascension), 4);
      expect(e.apply(s, 'p0', const ChooseAscensionAction('berserker')), isNull,
          reason: 'ya ascendió');
      // Sin conexión no.
      expect(e.apply(s, 'p0', const TakeAscensionNodeAction('senorGuerra_a2')),
          isNull);
      for (final n in ['senorGuerra_a1', 'senorGuerra_a2', 'senorGuerra_a3']) {
        s = act(e, s, 'p0', TakeAscensionNodeAction(n));
      }
      expect(asc.free(s.players['p0']!.profile.ascension), 0);
      expect(e.apply(s, 'p0', const TakeAscensionNodeAction('senorGuerra_b1')),
          isNull, reason: 'sin puntos');
      // El kit y las mecánicas llegan a los stats.
      final d = e.progression.derivedStats(s.players['p0']!.profile);
      expect(d.mechanics, containsAll(['senorGuerra_r', 'senorGuerra_a3']));
      // Reiniciar nodos: gratis; la ascensión queda.
      s = act(e, s, 'p0', const ResetAscensionAction());
      expect(s.players['p0']!.profile.ascension.nodes, isEmpty);
      expect(s.players['p0']!.profile.ascension.id, 'senorGuerra');
      // Cambiar de ascensión: gratis, en el pueblo.
      s = act(e, s, 'p0', const ResetAscensionAction(full: true));
      expect(s.players['p0']!.profile.ascension.id, isNull);
      expect(s.players['p0']!.profile.ascension.trials, {1, 2});
      s = act(e, s, 'p0', const ChooseAscensionAction('berserker'));
      // Cambiar de clase saca la ascensión.
      s = act(e, s, 'p0', const ChangeClassAction('maga'));
      expect(s.players['p0']!.profile.ascension.id, isNull);
      expect(s.players['p0']!.profile.ascension.trials, {1, 2});
    });

    test('sin la Prueba I no se elige; en batalla no se tocan nodos', () {
      final e = sessionEngine(zones: true);
      final s = lobby(e, [hero('Ana')]);
      expect(e.apply(s, 'p0', const ChooseAscensionAction('berserker')), isNull);
      expect(asc.cannotChoose(s.players['p0']!.profile, 'berserker'),
          'Superá la Prueba del Tiempo I');
    });

    test('DEV: solo con devTools; sube al nivel y marca las Pruebas', () {
      final off = sessionEngine(zones: true);
      final s = lobby(off, [hero('Ana', level: 10)]);
      expect(off.apply(s, 'p0', const DevGrantTrialAction(2)), isNull);
      final on = sessionEngine(zones: true, devTools: true);
      final t = act(on, lobby(on, [hero('Ana', level: 10)]), 'p0',
          const DevGrantTrialAction(2));
      final p = t.players['p0']!.profile;
      expect(p.level, 40);
      expect(p.ascension.trials, {1, 2});
    });
  });

  group('perfil y red', () {
    test('perfil: asc ida y vuelta; normalize descarta lo inválido', () {
      final p = hero('Ana',
          level: 50, trials: {1, 2, 3}, asc: 'berserker', nodes: ['berserker_a1']);
      final j = jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>;
      expect(j['asc'], {'tr': [1, 2, 3], 'id': 'berserker', 'n': ['berserker_a1']});
      final back = PlayerProfile.fromJson(j);
      expect(back.ascension, p.ascension);

      // Prueba 2 sin la 1, ascensión de otra clase, nodo suelto.
      final bad = zoneProgression.normalize(PlayerProfile.fromJson({
        ...j,
        'asc': {'tr': [2, 3], 'id': 'cronomante', 'n': ['x', 'berserker_a2']},
      }));
      expect(bad.ascension.trials, isEmpty);
      expect(bad.ascension.id, isNull);
      final orphan = zoneProgression.normalize(PlayerProfile.fromJson({
        ...j,
        'asc': {'tr': [1], 'id': 'berserker', 'n': ['berserker_a2', 'berserker_a1']},
      }));
      expect(orphan.ascension.nodes, ['berserker_a1'],
          reason: 'a2 antes que a1 no estaba conectado');
    });

    test('migración: un perfil v0.4 (sin asc) carga sin ascensión', () {
      final v04 = {
        'pv': 3,
        'name': 'Vieja',
        'cls': 'paladin',
        'lvl': 50,
        'xp': 0,
        'cr': 10,
        'tree': [],
        'tv': 2,
        'zu': 10,
        'eco': true,
        'ms': 3,
      };
      final p = zoneProgression.normalize(PlayerProfile.fromJson(v04));
      expect(p.ascension.isEmpty, isTrue);
      expect(p.mastery, 3);
      expect(p.toJson().containsKey('asc'), isFalse);
      expect(p.ascension.trials, isEmpty);
    });

    test('sesión, acciones, eventos y combatiente: ida y vuelta', () {
      const sj = SessionJson();
      final e = sessionEngine(zones: true);
      var s = lobby(e, [
        hero('Ana', level: 50, trials: {1}, asc: 'guardian', classId: 'paladin'),
      ]);
      s = act(e, s, 'p0', const ProposeTrialAction(1));
      final back = sj.fromJson(asJson(jsonDecode(jsonEncode(sj.toJson(s)))));
      expect(back.trial, 1);
      expect(back.players['p0']!.profile.ascension.id, 'guardian');

      for (final a in const <SessionAction>[
        ProposeTrialAction(3),
        ChooseAscensionAction('trampero'),
        TakeAscensionNodeAction('trampero_a1'),
        ResetAscensionAction(full: true),
        ResetAscensionAction(),
        DevGrantTrialAction(2),
      ]) {
        final j = ActionJson.toJson(a);
        expect(ActionJson.toJson(ActionJson.fromJson(asJson(jsonDecode(jsonEncode(j))))),
            j);
      }
      const ej = EventJson(sj);
      for (final ev in const <SessionEvent>[
        TrialCompletedEvent(2, ['p0', 'p1']),
        AscensionChosenEvent('p1', 'cronomante'),
        TrapTriggeredEvent('p0', TrapKind.spikes, 7),
        TrapTriggeredEvent('p0', TrapKind.pulse, 0),
      ]) {
        final j = ej.toJson(ev);
        expect(ej.toJson(ej.fromJson(asJson(jsonDecode(jsonEncode(j))))), j);
      }

      // Combatiente con build ascendido y "1 vez por batalla".
      final st = e.battles.start(
          party: [e.partyMember(s.players['p0']!)], enemyTypes: ['slime']);
      final c = st.state.party.single..once.add('guardian_b3');
      final cj = sj.combatantToJson(c);
      final c2 = sj.combatantFromJson(asJson(jsonDecode(jsonEncode(cj))));
      expect(c2.ascensionId, 'guardian');
      expect(c2.once, {'guardian_b3'});
      expect(c2.skillIds, containsAll(['proteccion', 'fortaleza', 'aura']));
      expect(kProtocolVersion, greaterThanOrEqualTo(5)); // 6 desde v0.5.1
    });
  });

  test('los nombres del kit existen en el catálogo de habilidades', () {
    for (final a in kAscensions.values) {
      for (final id in a.skillIds) {
        expect(e0.catalog.skills, contains(id), reason: id);
      }
    }
  });
}

final e0 = sessionEngine(zones: true);
