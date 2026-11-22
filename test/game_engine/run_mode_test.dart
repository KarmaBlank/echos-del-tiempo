import 'package:echos_del_tiempo/game_engine/data/branch_ults_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/run_json.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/reward_offer_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_tuning.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Modo Travesía (docs/specs/roguelike.md, "MVP implementado").
void main() {
  const gen = RunMapGenerator();

  group('mapa', () {
    test('3 pisos, 3 líneas, jefe al final, aristas solo a la capa siguiente',
        () {
      for (final seed in [1, 42, 777, 123456, 99999999]) {
        final map = gen.generate(seed);
        expect(map.floors, hasLength(RunTuning.floors));
        for (final f in map.floors) {
          expect(f.boss.type, RunNodeType.jefe);
          expect(f.boss.layer, RunTuning.layers);
          expect(f.entry, hasLength(RunTuning.lanes));
          for (var l = 0; l < RunTuning.layers; l++) {
            final lanes = {for (final n in f.layer(l)) n.lane};
            expect(lanes, {0, 1, 2}, reason: 'capa $l');
          }
          for (final n in f.nodes) {
            if (n.type != RunNodeType.jefe) expect(n.next, isNotEmpty);
            for (final t in n.next) {
              expect(f.node(t).layer, n.layer + 1);
            }
            // Todo nodo (salvo la entrada) tiene de dónde llegar.
            if (n.layer > 0) expect(f.before(n.id), isNotEmpty);
          }
        }
      }
    });

    test('restricciones: élite tardía, sin descansos seguidos, descanso '
        'antes del jefe, tienda y armería por línea', () {
      for (var seed = 1; seed <= 60; seed++) {
        for (final f in gen.generate(seed * 7919).floors) {
          for (final n in f.nodes) {
            if (n.type == RunNodeType.elite) {
              expect(n.layer, greaterThanOrEqualTo(RunTuning.firstEliteLayer));
            }
            if (n.type == RunNodeType.descanso) {
              for (final t in n.next) {
                expect(f.node(t).type, isNot(RunNodeType.descanso));
              }
            }
          }
          for (final n in f.layer(0)) {
            expect(n.type, RunNodeType.combate);
          }
          for (final n in f.layer(RunTuning.layers - 1)) {
            expect(n.type, RunNodeType.descanso);
            expect(n.next, [f.boss.id]);
          }
          for (var lane = 0; lane < RunTuning.lanes; lane++) {
            final types = {
              for (final n in f.nodes)
                if (n.lane == lane && n.type != RunNodeType.jefe) n.type
            };
            expect(types, contains(RunNodeType.tienda), reason: 'línea $lane');
            expect(types, contains(RunNodeType.armeria), reason: 'línea $lane');
          }
        }
      }
    });

    test('misma semilla, mismo mapa; otra semilla, otro', () {
      String sig(int seed) => [
            for (final f in gen.generate(seed).floors)
              for (final n in f.nodes) '${n.id}${n.type.name}${n.next}'
          ].join('|');
      expect(sig(31337), sig(31337));
      expect(sig(31337), isNot(sig(31338)));
    });
  });

  group('votación', () {
    test('gana la mayoría', () {
      expect(
          RunRules.resolveVote({'a': 3, 'b': 3, 'c': 5}, seed: 9, floor: 0),
          3);
    });

    test('empate: sorteo con la semilla, igual siempre y entre los empatados',
        () {
      final votes = {'a': 1, 'b': 2};
      final first = RunRules.resolveVote(votes, seed: 77, floor: 1, from: 4);
      expect([1, 2], contains(first));
      for (var i = 0; i < 5; i++) {
        expect(RunRules.resolveVote({'b': 2, 'a': 1}, seed: 77, floor: 1, from: 4),
            first);
      }
      // Con distintas semillas salen los dos alguna vez.
      final seen = {
        for (var s = 0; s < 40; s++)
          RunRules.resolveVote(votes, seed: s, floor: 0)
      };
      expect(seen, {1, 2});
    });
  });

  group('ofertas', () {
    final offers =
        RewardOfferRules(tree: kPassiveTree, catalog: GameCatalog.standard);

    PlayerProfile fresh(String cls) =>
        zoneProgression.normalize(PlayerProfile(name: 'X', classId: cls));

    test('solo ramas de la clase, sin repetidos ni lo ya tomado', () {
      for (final cls in GameCatalog.standard.classes.keys) {
        final paths = offers.classPaths(cls).toSet();
        expect(paths, isNotEmpty, reason: cls);
        var p = fresh(cls);
        final rnd = mulberry32(cls.hashCode);
        for (var i = 0; i < 12; i++) {
          final (o, _) = offers.offer(p, floor: 0, rnd: rnd);
          expect(o.nodes.toSet(), hasLength(o.nodes.length));
          expect(o.nodes, hasLength(RunTuning.offerSize));
          for (final id in o.nodes) {
            expect(paths, contains(kPassiveTree.nodes[id]!.pathId));
            expect(p.tree, isNot(contains(id)));
          }
          final cdef = GameCatalog.standard.classes[cls]!;
          for (final w in o.weapons) {
            expect(cdef.allowedWeaponTypes,
                contains(GameCatalog.standard.weapons[w]!.type));
          }
          expect(o.extras.toSet(), hasLength(o.extras.length));
          p = RunRules.grantNode(zoneProgression, p, o.nodes.first)!;
        }
      }
    });

    test('respeta las exclusiones entre keystones', () {
      final ex = kPassiveTree.exclusions.entries.first;
      final cls = kPassiveTree.paths[kPassiveTree.nodes[ex.key]!.pathId]!
          .classId
          .split('+')
          .first;
      final p = fresh(cls).copyWith(tree: [ex.key]);
      expect(offers.candidates(p), isNot(contains(ex.value)));
      final q = fresh(cls).copyWith(tree: [ex.value]);
      expect(offers.candidates(q), isNot(contains(ex.key)));
    });

    test('racha: tras N ofertas sin la rama principal, la garantiza', () {
      final cls = GameCatalog.standard.classes.keys.first;
      final main = offers.classPaths(cls).first;
      final mainNode = kPassiveTree.nodes.values
          .firstWhere((n) => n.pathId == main && n.kind != 'st');
      final p = fresh(cls).copyWith(tree: [mainNode.id]);
      expect(offers.mainPath(p), main);
      // Azar que nunca sigue la tendencia (0.99 > trendChance).
      double never() => 0.99;
      final (_, hitFree) = offers.treeOffer(p, never, 0);
      final (o, hit) = offers.treeOffer(p, never, RunTuning.pityAfter);
      expect(hit, isTrue);
      expect(o.any((id) => kPassiveTree.nodes[id]!.pathId == main), isTrue);
      // Sin racha puede no salir (no se exige).
      expect(hitFree, isA<bool>());
    });
  });

  group('sesión', () {
    SessionEngine engine() => SessionEngine(
          battles: BattleEngine(stats: statsCalc, random: () => 0.5),
          progression: zoneProgression,
          random: mulberry32(5),
          seeds: () => 4242,
          achievementsEnabled: false,
          gameMode: GameModeKind.travesia,
        );

    test('el Mundo rechaza las acciones de la Travesía', () {
      final e = sessionEngine(zones: true);
      var s = e.create();
      s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
      expect(e.apply(s, 'p0', const RunStartAction()), isNull);
    });

    test('Condensar: rechazado en la Travesía, aun en la armería', () {
      final e = engine();
      var s = e.create();
      s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
      s = act(e, s, 'p0', const RunStartAction());
      final r = s.run!;
      final armory = RunRules.floorOf(r)
          .nodes
          .firstWhere((n) => n.type == RunNodeType.armeria);
      r
        ..node = armory.id
        ..phase = RunPhase.stop;
      final p = s.players['p0']!;
      p.profile = p.profile.copyWith(
          credits: 99999,
          materials: {CraftMaterial.esquirla: 99, CraftMaterial.cristal: 50});
      expect(
          e.apply(s, 'p0',
              const CraftAction(CraftOp.condense, 'cristal', index: 1)),
          isNull);
      expect(
          e.apply(s, 'p0',
              const CraftAction(CraftOp.condense, 'prisma', index: 1)),
          isNull);
    });

    test('empezar → votar → pelea ganada → recompensa elegida', () {
      final e = engine();
      var s = e.create();
      final real = zoneProgression.normalize(PlayerProfile(
          name: 'Ana', classId: 'guerrero', level: 30, credits: 9999));
      s = e.addPlayer(s, 'p0', real)!.state;
      // Personaje de run: nivel 1, árbol vacío, oro inicial.
      expect(s.players['p0']!.profile.level, 1);
      expect(s.players['p0']!.profile.credits, RunTuning.startGold);
      expect(s.players['p0']!.profile.tree, isEmpty);

      s = act(e, s, 'p0', const RunStartAction());
      expect(s.mode, SessionMode.run);
      final r = s.run!;
      expect(r.phase, RunPhase.map);
      final target = RunRules.reachable(r).first;
      // No alcanzable: rechazado.
      expect(e.apply(s, 'p0', const RunVoteAction(99999)), isNull);
      s = act(e, s, 'p0', RunVoteAction(target));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.battle);
      expect(s.run!.node, target);

      // La ida y vuelta por la red conserva la run.
      final json = const SessionJson().toJson(s);
      final back = const SessionJson().fromJson(json);
      expect(back.run!.node, target);
      expect(back.run!.phase, RunPhase.battle);

      for (final en in s.battle!.state.enemies) {
        en.hp = 1;
      }
      final gold = s.players['p0']!.profile.credits;
      s = runBattle(e, s, until: (x) => x.mode == SessionMode.run);
      expect(s.run!.phase, RunPhase.reward);
      expect(s.players['p0']!.profile.xp, 0);
      expect(s.players['p0']!.profile.credits, gold + RunTuning.goldCombate);
      final offer = s.run!.offers['p0']!;
      expect(offer.nodes, hasLength(RunTuning.offerSize));

      const a = RunRewardAction(tree: 0, weapon: 0);
      expect(ActionJson.fromJson(ActionJson.toJson(a)), isA<RunRewardAction>());
      final items = s.players['p0']!.profile.items.length;
      s = act(e, s, 'p0', a);
      expect(s.players['p0']!.profile.tree, [offer.nodes.first]);
      expect(s.players['p0']!.profile.items.length, items + 1);
      s = e.tick(s, 0.05).state;
      expect(s.run!.phase, RunPhase.map);
      expect(RunRules.reachable(s.run!),
          RunRules.floorOf(s.run!).node(target).next);
    });

    test('derrota: fin de la run', () {
      final e = engine();
      var s = e.create();
      s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
      s = act(e, s, 'p0', const RunStartAction());
      s = act(e, s, 'p0', RunVoteAction(RunRules.reachable(s.run!).first));
      s = e.tick(s, 0.05).state;
      for (final c in s.battle!.state.party) {
        c.hp = 0;
      }
      s.battle!.state.currentId = null;
      s = wait(e, s, 6);
      expect(s.mode, SessionMode.run);
      expect(s.run!.phase, RunPhase.over);
      expect(s.run!.victory, isFalse);
    });

    test('dos jugadores: la ruta espera a todos los votos', () {
      final e = engine();
      var s = e.create();
      s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
      s = e.addPlayer(s, 'p1', newProfile('B', 'maga'))!.state;
      s = act(e, s, 'p0', const RunStartAction());
      final opts = RunRules.reachable(s.run!);
      s = act(e, s, 'p0', RunVoteAction(opts[0]));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.run);
      s = act(e, s, 'p1', RunVoteAction(opts[0]));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.battle);
    });

    test('v0.1.1: la pelea de la run usa turnos porBando', () {
      final e = engine();
      var s = e.create();
      s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
      s = act(e, s, 'p0', const RunStartAction());
      s = act(e, s, 'p0', RunVoteAction(RunRules.reachable(s.run!).first));
      s = e.tick(s, 0.05).state;
      expect(s.battle!.state.turnRule, TurnRule.porBando);
      for (var k = 0; k < 200 && !s.battle!.waitingForPlayer; k++) {
        s = e.tick(s, 0.05).state;
      }
      expect(s.battle!.state.awaitingGroup, isTrue);
      expect(s.battle!.waitingForPlayer, isTrue);
    });
  });

  group('v0.1.1', () {
    final offers =
        RewardOfferRules(tree: kPassiveTree, catalog: GameCatalog.standard);

    test('equipar en la run no pide nivel ni atributos', () {
      final run = ProgressionRules(
          stats: statsCalc,
          catalog: GameCatalog.standard,
          ignoreRequirements: true);
      final p = run.normalize(PlayerProfile(name: 'X', classId: 'guerrero'));
      final types = GameCatalog.standard.classes['guerrero']!
          .allowedWeaponTypes
          .toSet();
      final w = GameCatalog.standard.weapons.values.firstWhere(
          (w) => types.contains(w.type) && w.level > 9 && w.price > 0);
      final got = RunRules.applyReward(
          run, p, RunOffer(weapons: [w.id]),
          weapon: 0)!;
      final uid = got.items.firstWhere((i) => i.baseId == w.id).uid;
      expect(zoneProgression.equip(got, uid), isNull);
      expect(run.equip(got, uid)?.equippedUid, uid);
    });

    test('ULT de rama: de las ramas de la clase, se aprende y queda activa',
        () {
      final p = zoneProgression
          .normalize(PlayerProfile(name: 'X', classId: 'guerrero'));
      final ids = offers.ultOffer(p, mulberry32(3));
      expect(ids, hasLength(RunTuning.ultOfferSize));
      final paths = offers.classPaths('guerrero').toSet();
      for (final id in ids) {
        expect(
            kBranchUltList.any((u) => u.$2.id == id && paths.contains(u.$1)),
            isTrue);
      }
      final o = RunOffer(ults: ids);
      final got = RunRules.applyReward(zoneProgression, p, o, ult: 1)!;
      expect(got.ultKnown, contains(ids[1]));
      expect(got.ultSel, ids[1]);
      expect(offers.ultCandidates(got), isNot(contains(ids[1])));
      // Viaja por la red (protocolo de Travesía 2).
      final back = RunJson.offerFromJson(RunJson.offerToJson(o));
      expect(back.ults, ids);
      final a = ActionJson.fromJson(
          ActionJson.toJson(const RunRewardAction(ult: 2))) as RunRewardAction;
      expect(a.ult, 2);
    });
  });
}
