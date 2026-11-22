import 'package:echos_del_tiempo/game_engine/data/run_boons.dart';
import 'package:echos_del_tiempo/game_engine/models/game_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/run_save.dart';
import 'package:echos_del_tiempo/game_engine/models/travesia_meta.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/meta_progress_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_tuning.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/run_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Travesía v0.2.0 (docs/specs/roguelike.md § 4, § 8.5, § 8).
void main() {
  SessionEngine engine() => SessionEngine(
        battles: BattleEngine(stats: statsCalc, random: () => 0.5),
        progression: zoneProgression,
        random: mulberry32(5),
        seeds: () => 4242,
        achievementsEnabled: false,
        gameMode: GameModeKind.travesia,
      );

  group('mejoras directas', () {
    test('mods y Pulso apilan; las de élite solo en élites', () {
      expect(RunRules.boonMods(['hechizos', 'hechizos'], eliteFight: false), const
          [ItemMod(ModStat.magPct, 10), ItemMod(ModStat.magPct, 10)]);
      expect(RunRules.boonMods(['elites'], eliteFight: false), isEmpty);
      expect(RunRules.boonMods(['elites'], eliteFight: true), hasLength(2));
      expect(RunRules.boonPulse(['pulso', 'ataque', 'pulso']), 2);
      for (final b in RunBoon.values) {
        expect(b.text, isNotEmpty);
      }
    });

    test('elegida en la recompensa, queda en la run y viaja por la red', () {
      final e = engine();
      var s = e.create();
      s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
      s = act(e, s, 'p0', const RunStartAction());
      s.run!
        ..phase = RunPhase.reward
        ..offers['p0'] = const RunOffer(extras: [
          RunExtra(RunExtraKind.mejora, 1, boon: 'pulso'),
        ]);
      s = act(e, s, 'p0', const RunRewardAction(extra: 0));
      expect(s.run!.boons['p0'], ['pulso']);
      final back = RunJson.fromJson(RunJson.toJson(s.run!));
      expect(back.boons['p0'], ['pulso']);
      s = e.tick(s, 0.05).state;
      s = act(e, s, 'p0', RunVoteAction(RunRules.reachable(s.run!).first));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.battle);
      expect(s.battle!.state.party.first.pulse,
          BattleEngine.pulseStart + RunBoon.pulso.value);
    });
  });

  group('guardado de la run', () {
    test('se guarda, viaja a JSON y se retoma en otra sala', () {
      final e = engine();
      var s = e.create();
      s = e.addPlayer(s, 'p0', newProfile('Ana', 'guerrero'))!.state;
      s = e.addPlayer(s, 'p1', newProfile('Beto', 'maga'))!.state;
      s = act(e, s, 'p0', const RunStartAction());
      s.run!.boons['p0'] = ['ataque'];
      s.players['p0']!.profile =
          s.players['p0']!.profile.copyWith(credits: 777);
      final target = RunRules.reachable(s.run!).first;
      s = act(e, s, 'p0', RunVoteAction(target));
      s = act(e, s, 'p1', RunVoteAction(target));
      s = e.tick(s, 0.05).state;
      expect(s.mode, SessionMode.battle);
      final save = RunSave.tryParse(e.runSaveOf(s)!.toJson())!;
      expect(save.players, hasLength(2));
      expect(save.run.node, target);

      // Sala nueva, solo vuelve el anfitrión (con otro id).
      final e2 = engine();
      var s2 = e2.create();
      s2 = e2.addPlayer(s2, 'h', newProfile('Ana', 'guerrero'))!.state;
      s2 = e2.resumeRun(s2, save)!.state;
      expect(s2.mode, SessionMode.battle);
      expect(s2.run!.node, target);
      expect(s2.players['h']!.profile.credits, 777);
      expect(s2.run!.boons['h'], ['ataque']);
      // El que falta queda esperando y sigue en el guardado.
      expect(e2.runParked.keys, ['Beto|maga']);
      expect(e2.runSaveOf(s2)!.players, hasLength(2));
      // Vuelve: recupera su personaje.
      s2 = e2.addPlayer(s2, 'p9', newProfile('Beto', 'maga'))!.state;
      expect(e2.runParked, isEmpty);
    });

    test('el Mundo no retoma runs', () {
      final e = sessionEngine(zones: true);
      final s = e.create();
      expect(e.runSaveOf(s), isNull);
      expect(
          e.resumeRun(
              s, RunSave(run: RunState(seed: 1, zones: [0, 0, 0]), players: const [])),
          isNull);
    });

    test('un archivo roto o de otra versión se ignora', () {
      expect(RunSave.tryParse({'v': 99}), isNull);
      expect(RunSave.tryParse('x'), isNull);
    });
  });

  group('progreso entre runs', () {
    const meta = MetaProgressRules(catalog: GameCatalog.standard);
    List<String> start(String cls) => zoneProgression.weaponSkills(
        RunRules.runProfile(zoneProgression, PlayerProfile(name: 'x', classId: cls)));

    test('pool de loadout: 5 por clase, distintas, fuera del arma inicial', () {
      for (final cls in GameCatalog.standard.classes.keys) {
        final pool = meta.loadoutPool(cls, start(cls));
        expect(pool, hasLength(MetaProgressRules.poolSize), reason: cls);
        expect(pool.toSet(), hasLength(pool.length));
        expect(pool.where(start(cls).contains), isEmpty);
        expect(MetaProgressRules.poolOpen, greaterThanOrEqualTo(3));
      }
    });

    test('comprar, loadout y sinergia de pares', () {
      const key = 'Ana|guerrero';
      var m = const TravesiaMeta(coins: 100);
      expect(MetaProgressRules.buy(m, key, 'bolsa_honda'), isNull,
          reason: 'pide Bolsa de viaje');
      m = MetaProgressRules.buy(m, key, 'bolsa')!;
      m = MetaProgressRules.buy(m, key, 'doble_filo')!;
      expect(m.coins, 100 - 10 - 25);
      final pool = meta.loadoutPool('guerrero', start('guerrero'));
      // Cerradas: la 4.ª y la 5.ª.
      expect(meta.setLoadout(m, key, 'guerrero', start('guerrero'), [pool[3]]),
          isNull);
      m = meta.setLoadout(
          m, key, 'guerrero', start('guerrero'), [pool[0], pool[1]])!;
      final prep = meta.prepOf(m, key, 'guerrero', start('guerrero'));
      expect(prep.skills, [pool[0], pool[1]]);
      expect(prep.gold, 30);
      // Las del guerrero son físicas: Doble filo da la mejora Ataque.
      expect(prep.boons, ['ataque']);
      final back = TravesiaMeta.fromJson(m.toJson());
      expect(back.coins, m.coins);
      expect(back.charOf(key).loadout, [pool[0], pool[1]]);
    });

    test('cobrar la run: moneda, zona, élites, dificultad; una sola vez', () {
      final r = RunState(seed: 9, zones: const [0, 0, 0], floor: 2)
        ..phase = RunPhase.over
        ..victory = true
        ..bossesBeaten = 3
        ..elitesBeaten.addAll(['golem', 'golem']);
      final m = MetaProgressRules.settle(TravesiaMeta.empty, r, playableZones: 10);
      expect(m.coins, MetaProgressRules.coinsOf(r));
      expect(m.coins, greaterThan(0));
      expect(m.zones, 1);
      expect(m.eliteWins['golem'], 2);
      expect(m.difficultyUnlocked, 1);
      expect(m.wins, 1);
      expect(MetaProgressRules.settle(m, r, playableZones: 10), same(m));
    });

    test('la sala aplica loadout, bonos, dificultad y élites del anfitrión', () {
      final e = engine();
      var s = e.create();
      s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
      final pool = meta.loadoutPool('guerrero', start('guerrero'));
      final prep = RunPrep(skills: [pool[0]], gold: 30, boons: const ['pulso']);
      final a = RunPrepAction(prep);
      final wire = ActionJson.fromJson(ActionJson.toJson(a)) as RunPrepAction;
      expect(wire.prep.skills, [pool[0]]);
      s = act(e, s, 'p0', a);
      const start0 = RunStartAction(difficulty: 2, eliteWins: {'golem': 1});
      expect((ActionJson.fromJson(ActionJson.toJson(start0)) as RunStartAction)
          .eliteWins, {'golem': 1});
      s = act(e, s, 'p0', start0);
      expect(s.players['p0']!.profile.credits, RunTuning.startGold + 30);
      expect(s.run!.difficulty, 2);
      expect(s.run!.loadout['p0'], [pool[0]]);
      expect(s.run!.boons['p0'], ['pulso']);
      s = act(e, s, 'p0', RunVoteAction(RunRules.reachable(s.run!).first));
      s = e.tick(s, 0.05).state;
      expect(s.battle!.state.party.first.skillIds, contains(pool[0]));
    });

    test('pool de élites: la de la zona y las ya vencidas', () {
      const rules = RunRules(catalog: GameCatalog.standard);
      final z = rules.playableZones().first;
      final seen = <String>{};
      var k = 0;
      double rnd() => (k++ % 10) / 10;
      for (var i = 0; i < 40; i++) {
        seen.add(rules.eliteOf(z, const {'golem': 1}, rnd));
      }
      expect(seen, contains('golem'));
      expect(seen.length, greaterThanOrEqualTo(2));
      expect(RunRules.eliteRepeatLevels(2), greaterThan(0));
    });

    test('zonas: arranca con un subconjunto', () {
      const rules = RunRules(catalog: GameCatalog.standard);
      final all = rules.playableZones();
      final few = rules.floorZones(unlocked: 0);
      expect(few.every(all.take(3).contains), isTrue);
    });
  });
}
