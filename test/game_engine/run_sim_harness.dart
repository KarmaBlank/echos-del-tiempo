import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_tuning.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';

import 'session_test_helpers.dart';

/// Outcome of one simulated Paradoja run (roguelike.md § 12.3).
class RunSimResult {
  /// Floor reached, 1-based.
  int floor = 1;

  /// Floor (1-based) where the run died; null when it was won.
  int? deathFloor;

  /// Node type of the fight that ended the run.
  RunNodeType? deathType;
  RunNodeType? _lastFight;
  bool won = false;
  int fights = 0;

  /// Boss fights started / won, by floor (1-based).
  final bossFought = <int, int>{};
  final bossWon = <int, int>{};

  /// Gold earned in total and gold held when entering each floor.
  int goldEarned = 0;
  final goldAtFloor = <int, int>{};

  /// Simulated combat seconds (run length proxy).
  double battleSeconds = 0;
}

/// One whole solo run with a "reasonable" player: ULT when full, potion
/// at low HP, the strongest affordable damage skill, otherwise attack;
/// takes the first option of each reward row and equips the strongest
/// weapon. [difficulty] is the run difficulty (§ 8.2).
RunSimResult simulateRun(String classId, int seed,
    {int difficulty = 0, void Function(String line)? log, bool trace = false}) {
  var lastLog = '';
  final e = SessionEngine(
    battles: BattleEngine(stats: statsCalc, random: mulberry32(seed * 31 + 7)),
    progression: ProgressionRules(
        stats: statsCalc,
        catalog: GameCatalog.standard,
        ignoreRequirements: true),
    random: mulberry32(seed),
    seeds: () => 1000 + seed,
    achievementsEnabled: false,
    gameMode: GameModeKind.travesia,
  );
  const catalog = GameCatalog.standard;
  const dt = 0.05;
  final out = RunSimResult();
  var s = e.create();
  s = e.addPlayer(s, 'p0', newProfile('Sim', classId))!.state;
  s = e.apply(s, 'p0', RunStartAction(difficulty: difficulty))!.state;
  GameSession tryAct(SessionAction a) => e.apply(s, 'p0', a)?.state ?? s;
  var gold = s.players['p0']!.profile.credits;
  out.goldAtFloor[1] = gold;
  int? bossFloor;

  for (var i = 0; i < 400000; i++) {
    final now = s.players['p0']!.profile.credits;
    if (now > gold) out.goldEarned += now - gold;
    gold = now;
    final r = s.run!;
    final inBattle = s.mode == SessionMode.battle && s.battle != null;
    if (bossFloor != null && !inBattle) {
      if (r.phase != RunPhase.over || r.victory == true) {
        out.bossWon[bossFloor] = (out.bossWon[bossFloor] ?? 0) + 1;
      }
      bossFloor = null;
    }
    if (r.phase == RunPhase.over) {
      out.won = r.victory == true;
      if (!out.won) {
        out.deathFloor = out.floor;
        out.deathType = out._lastFight;
      }
      break;
    }
    if (r.floor + 1 > out.floor) {
      out.floor = r.floor + 1;
      out.goldAtFloor[out.floor] = gold;
    }
    final b = s.battle;
    if (inBattle && b != null) {
      if (trace && b.state.logLine.key != lastLog) {
        lastLog = b.state.logLine.key + b.state.logLine.args.toString();
        log?.call('  r${b.state.round} hp ${b.state.party.first.hp} '
            '${b.state.logLine.key} ${b.state.logLine.args}');
      }
      if (b.waitingForPlayer) {
        final c = b.state.party.first;
        BattleCommand cmd = const AttackCommand();
        if (c.ult >= 100) {
          cmd = const UltimateCommand();
        } else if (c.hp < c.maxHp * 0.35 && c.potions > 0) {
          cmd = const ItemCommand(BattleItem.potion);
        } else if (c.hp < c.maxHp * 0.5 &&
            c.skillIds.any((id) =>
                catalog.skills[id]?.kind == SkillKind.heal &&
                catalog.skills[id]!.mp <= c.mp)) {
          cmd = SkillCommand(c.skillIds.firstWhere((id) =>
              catalog.skills[id]?.kind == SkillKind.heal &&
              catalog.skills[id]!.mp <= c.mp));
        } else {
          SkillDef? best;
          for (final id in c.skillIds) {
            final sk = catalog.skills[id];
            if (sk == null || sk.mp > c.mp) continue;
            if (sk.kind != SkillKind.physical && sk.kind != SkillKind.magical) {
              continue;
            }
            if (best == null || sk.power > best.power) best = sk;
          }
          if (best != null) cmd = SkillCommand(best.id);
        }
        final step = e.apply(s, 'p0', BattleAction(cmd)) ??
            e.apply(s, 'p0', const BattleAction(AttackCommand()));
        if (step != null) {
          s = step.state;
          continue;
        }
      }
      s = e.tick(s, dt).state;
      out.battleSeconds += dt;
      continue;
    }
    switch (r.phase) {
      case RunPhase.map:
        final opts = RunRules.reachable(r);
        final f = RunRules.floorOf(r);
        final p = s.players['p0']!;
        // Low HP prefers resting; otherwise fight.
        int pick = opts.first;
        for (final o in opts) {
          final t = f.node(o).type;
          if (p.hp < p.maxHp * 0.5 && t == RunNodeType.descanso) pick = o;
          if (p.hp >= p.maxHp * 0.5 && t == RunNodeType.combate) {
            pick = o;
            break;
          }
        }
        s = tryAct(RunVoteAction(pick));
        s = e.tick(s, dt).state;
        if (s.mode == SessionMode.battle) {
          out.fights++;
          out._lastFight = f.node(pick).type;
          log?.call('f${r.floor + 1} L${f.node(pick).layer} '
              '${f.node(pick).type.name} hp ${p.hp.round()}/${p.maxHp} '
              'pots ${p.profile.potions} vs ${s.battle!.state.enemies.map((x) => '${x.enemyType}:${x.hp}/${x.attack}').join(' ')}');
          if (f.node(pick).type == RunNodeType.jefe) {
            bossFloor = r.floor + 1;
            out.bossFought[bossFloor] = (out.bossFought[bossFloor] ?? 0) + 1;
          }
        }
      case RunPhase.reward:
        final o = r.offers['p0']!;
        final eq = r.loadout['p0'] ?? const <String>[];
        final drop = o.extras.isNotEmpty &&
                o.extras.first.skill != null &&
                eq.length >= RunTuning.freeSkillSlots
            ? eq.first
            : null;
        s = tryAct(RunRewardAction(
            tree: o.nodes.isEmpty ? null : 0,
            weapon: o.weapons.isEmpty ? null : 0,
            extra: o.extras.isEmpty ? null : 0,
            ult: o.ults.isEmpty ? null : 0,
            drop: drop));
        final prof = s.players['p0']!.profile;
        num power(String id) {
          final w = catalog.weapons[id];
          if (w == null) return 0;
          final a = w.atk.evaluate(prof.attributes);
          final m = w.mag?.evaluate(prof.attributes) ?? 0;
          return a > m ? a : m;
        }
        final best = [...prof.items]
          ..sort((a, b) => power(b.baseId).compareTo(power(a.baseId)));
        if (best.isNotEmpty) s = tryAct(EquipAction(best.first.uid));
        s = e.tick(s, dt).state;
      case RunPhase.stop:
        if (RunRules.floorOf(r).node(r.node!).type == RunNodeType.tienda) {
          for (var k = 0; k < 3; k++) {
            s = tryAct(const BuyItemAction(BattleItem.potion));
          }
        }
        s = tryAct(const RunReadyAction());
        s = e.tick(s, dt).state;
      case RunPhase.battle:
      case RunPhase.over:
        s = e.tick(s, dt).state;
    }
  }
  return out;
}

/// Aggregate of many runs of one class at one difficulty.
class RunSimStats {
  final String classId;
  final int difficulty;
  final List<RunSimResult> runs;
  RunSimStats(this.classId, this.difficulty, this.runs);

  int get n => runs.length;
  double get winRate => runs.where((r) => r.won).length / n;
  double get meanFloor => runs.fold<int>(0, (a, r) => a + r.floor) / n;
  int get medianFloor {
    final f = runs.map((r) => r.floor).toList()..sort();
    return f[f.length ~/ 2];
  }

  int deathsOn(int floor) => runs.where((r) => r.deathFloor == floor).length;

  /// Deaths by fight type, e.g. `combate 3, elite 9`.
  String get deathsByType {
    final m = <String, int>{};
    for (final r in runs) {
      if (r.deathType != null) {
        m[r.deathType!.name] = (m[r.deathType!.name] ?? 0) + 1;
      }
    }
    return m.entries.map((e) => '${e.key} ${e.value}').join(', ');
  }

  /// Boss win rate on [floor] among runs that reached that boss.
  double? bossRate(int floor) {
    final f = runs.fold<int>(0, (a, r) => a + (r.bossFought[floor] ?? 0));
    if (f == 0) return null;
    return runs.fold<int>(0, (a, r) => a + (r.bossWon[floor] ?? 0)) / f;
  }

  double get meanGold => runs.fold<int>(0, (a, r) => a + r.goldEarned) / n;
  double get meanFights => runs.fold<int>(0, (a, r) => a + r.fights) / n;
  double get meanBattleSeconds =>
      runs.fold<double>(0, (a, r) => a + r.battleSeconds) / n;

  String row() {
    String pct(double? v) => v == null ? '-' : '${(v * 100).round()}%';
    return '| $classId | $difficulty | $n | ${pct(winRate)} | '
        '${meanFloor.toStringAsFixed(2)} | '
        '${deathsOn(1)}/${deathsOn(2)}/${deathsOn(3)} | '
        '${pct(bossRate(1))}/${pct(bossRate(2))}/${pct(bossRate(3))} | '
        '${meanGold.round()} | ${meanFights.toStringAsFixed(1)} | '
        '${meanBattleSeconds.round()} |';
  }

  static const header = '| class | diff | runs | win | floor | deaths f1/f2/f3 '
      '| boss f1/f2/f3 | gold | fights | battle s |\n'
      '|---|---|---|---|---|---|---|---|---|---|';
}

RunSimStats simulateMany(String classId, int difficulty, Iterable<int> seeds) =>
    RunSimStats(classId, difficulty,
        [for (final s in seeds) simulateRun(classId, s, difficulty: difficulty)]);
