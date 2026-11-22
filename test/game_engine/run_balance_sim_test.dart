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
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Resultado de una run simulada.
class _Sim {
  int floor = 0;
  bool bossFloor3 = false;
  bool won = false;
  int fights = 0;
}

/// Una run entera, sola, con un jugador "razonable": ULT cuando está
/// llena, poción con poca vida, la habilidad de daño más fuerte que pueda
/// pagar y si no ataque; recompensas promedio (la primera de cada fila) y
/// equipa el arma de nivel más alto que tenga.
_Sim _simulate(String classId, int seed) {
  final e = SessionEngine(
    battles: BattleEngine(stats: statsCalc, random: mulberry32(seed * 31 + 7)),
    // Como el composition root de la Travesía: armas sin requisitos.
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
  final out = _Sim();
  var s = e.create();
  s = e.addPlayer(s, 'p0', newProfile('Sim', classId))!.state;
  s = act(e, s, 'p0', const RunStartAction());
  GameSession tryAct(SessionAction a) => e.apply(s, 'p0', a)?.state ?? s;

  for (var i = 0; i < 400000; i++) {
    final r = s.run!;
    if (r.phase == RunPhase.over) {
      out.won = r.victory == true;
      break;
    }
    out.floor = r.floor;
    if (r.floor == 2 && r.node != null &&
        RunRules.floorOf(r).node(r.node!).type == RunNodeType.jefe) {
      out.bossFloor3 = true;
    }
    final b = s.battle;
    if (s.mode == SessionMode.battle && b != null) {
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
      s = e.tick(s, 0.05).state;
      continue;
    }
    switch (r.phase) {
      case RunPhase.map:
        final opts = RunRules.reachable(r);
        final f = RunRules.floorOf(r);
        final p = s.players['p0']!;
        // Con poca vida prefiere descansar; si no, pelear.
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
        s = e.tick(s, 0.05).state;
        if (s.mode == SessionMode.battle) {
          out.fights++;
        }
      case RunPhase.reward:
        final o = r.offers['p0']!;
        // Habilidad nueva sin lugar: sacrifica la primera libre.
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
        // Equipa el arma más fuerte (ATQ o MAG base).
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
        s = e.tick(s, 0.05).state;
      case RunPhase.stop:
        // Tienda: pociones con lo que sobre.
        if (RunRules.floorOf(r).node(r.node!).type == RunNodeType.tienda) {
          for (var k = 0; k < 3; k++) {
            s = tryAct(const BuyItemAction(BattleItem.potion));
          }
        }
        s = tryAct(const RunReadyAction());
        s = e.tick(s, 0.05).state;
      case RunPhase.battle:
      case RunPhase.over:
        s = e.tick(s, 0.05).state;
    }
  }
  return out;
}

/// Pasada de balance de la Travesía v0.2.0 (roguelike.md § 12, "Balance"):
/// un jugador razonable de cada clase llega al jefe del piso 3 en la
/// mayoría de las semillas (cota floja: al menos la mitad de 10; con los
/// valores de v0.2.0 dio guerrero 9, maga 7, paladín 6, tirador 7).
void main() {
  test('cada clase llega al jefe del piso 3 y lo vence en la mayoría de las semillas',
      () {
    const seeds = 10;
    final report = StringBuffer();
    final results = <String, int>{};
    for (final cls in GameCatalog.standard.classes.keys) {
      var reach = 0, wins = 0, floors = 0;
      for (var seed = 1; seed <= seeds; seed++) {
        final r = _simulate(cls, seed);
        if (r.bossFloor3) reach++;
        if (r.won) wins++;
        floors += r.floor + 1;
        report.write(' [s$seed piso ${r.floor + 1} peleas ${r.fights}]');
      }
      report.writeln('$cls: jefe del piso 3 $reach/$seeds, '
          'ganadas $wins/$seeds, piso medio ${floors / seeds}');
      results[cls] = wins;
    }
    // ignore: avoid_print
    print(report);
    for (final e in results.entries) {
      expect(e.value, greaterThanOrEqualTo(seeds ~/ 2),
          reason: '${e.key}: $report');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

