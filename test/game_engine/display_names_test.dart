import 'package:echos_del_tiempo/game_engine/data/affixes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ascension_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/branch_ults_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/elements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/summoner_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapon_passives.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/display_names.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Ids de mecánica de todas las pasivas de arma, a todos los niveles.
List<String> _weaponPassiveMechanicIds() => [
      for (final id in kWeaponPassives.keys)
        for (var lv = 1; lv <= 5; lv++) ...weaponPassiveMechanicIds(id, lv),
    ];

void _expectReadable(String id, {String where = ''}) {
  final n = displayName(id);
  final why = '$where«$id» se muestra como «$n»';
  expect(n, isNot(contains('_')), reason: why);
  // «Inicio: Guerrero» es texto; «wp:x» / «x:3» es un id.
  expect(n, isNot(contains(RegExp(r':\S'))), reason: why);
  expect(n, isNot(id), reason: why);
  expect(n.trim(), isNotEmpty, reason: why);
}

void main() {
  test('humanizeId nunca deja prefijos ni guiones bajos', () {
    expect(humanizeId('wp:filoResonante:3'), 'Filo Resonante');
    expect(humanizeId('ult2_loQueSera'), 'Lo Que Sera');
    expect(humanizeId('mod:x_y'), 'X Y');
    expect(displayName('wp:noExiste:2'), 'No Existe');
  });

  test('todo id del catálogo se muestra con nombre legible', () {
    final ids = <String>{
      ...kMechanics.keys,
      ...kAscensionMechanics.keys,
      ..._weaponPassiveMechanicIds(),
      ...kWeaponPassives.keys,
      ...kAffixes.keys,
      for (final a in kAffixes.keys) 'mod:$a',
      ...kPassiveTree.nodes.keys,
      for (final n in kPassiveTree.nodes.keys) 'node:$n',
      ...kBranchUltSkills.keys,
      ...kUltV2.keys,
      ...kWeaponUltSkills.keys,
      ...kAscensionUltimatesById.keys,
      ...kSummonerUltimates.keys,
      ...kAllUltimates.keys,
      ...kSkills.keys,
      ...kUniques.keys,
      ...kBossMechanics.keys,
      ...kEnemyUlts.keys,
      ...kReactions.keys,
      ...kElementStatuses.keys,
      for (final s in StatusKind.values) s.name,
      for (final r in ReactionKind.values) r.name,
    };
    for (final id in ids) {
      _expectReadable(id);
    }
  });

  test('batalla simulada: los procs disparados tienen nombre legible', () {
    final mechIds = [
      ...kMechanics.keys,
      ...kAscensionMechanics.keys,
      ..._weaponPassiveMechanicIds(),
    ];
    final seen = <String>{};
    final logs = <String>[];
    for (final id in mechIds) {
      final engine = BattleEngine(stats: statsCalc, random: () => 0.01);
      final hero = Combatant(
        id: 'p1',
        name: 'Ana',
        isPlayer: true,
        hp: 30,
        maxHp: 100,
        speed: 10,
        attack: 20,
        magic: 20,
        critChance: 1,
        mp: 50,
        maxMp: 50,
        mechanics: {id},
        classId: 'guerrero',
        weaponType: 'espada',
      );
      Combatant foe(String fid) => Combatant(
            id: fid,
            name: 'Limo $fid',
            isPlayer: false,
            hp: 100,
            maxHp: 100,
            speed: 5,
            attack: 10,
            critChance: 0,
            enemyType: 'slime',
            nextTurn: 50,
          );
      final r = engine.command(
          BattleState(party: [hero], enemies: [foe('e0'), foe('e1')], currentId: 'p1'),
          'p1',
          const AttackCommand(targetId: 'e0'));
      if (r == null) continue;
      for (final e in r.events) {
        if (e is ProcEvent) seen.add(e.sourceId);
        if (e is BuffAppliedEvent) seen.add(e.sourceId);
      }
      logs.add(r.state.log);
    }
    expect(seen.where((s) => s.startsWith('wp:')), isNotEmpty,
        reason: 'la simulación debe disparar pasivas de arma');
    for (final s in seen) {
      _expectReadable(s, where: 'proc: ');
    }
    for (final l in logs) {
      expect(l, isNot(contains(RegExp(r'\b(wp|mod|node|ult):'))), reason: l);
    }
  });
}
