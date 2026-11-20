import 'dart:io';

import 'package:echos_del_tiempo/core/fx/fx_catalog.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_bridge.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Momentos de batalla nuevos en datos (no estaban en el código): se
/// excluyen de la comparación de aspecto con el código de respaldo.
const _improved = {
  'skill_haste',
  'skill_pulse',
  'skill_instant',
  'fissure',
  'convergence',
  'status_apply',
  'stunned',
  'revive',
};

/// El catálogo real del repo (desde el disco), sin [skip].
FxCatalog _catalog({Set<String> skip = const {}}) {
  final raw = File(FxCatalog.manifestPath).readAsStringSync();
  final fx = (loadYaml(raw) as YamlMap)['fx'] as YamlMap;
  final b = StringBuffer('fx:\n');
  final files = <String, String>{};
  for (final MapEntry(:key, :value) in fx.entries) {
    if (skip.contains(key)) continue;
    b.writeln('  $key: $value');
    files['$value'] = File('${FxCatalog.fxRoot}$value').readAsStringSync();
  }
  return FxCatalog.fromFiles(b.toString(), files,
      legacy: const LegacyFxAdapter());
}

BattlePartyMember _member(String id, String classId, String? weapon) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: cls.name,
    ult: 100,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[weapon ?? cls.startWeaponId]!,
    ),
  );
}

Offset Function(String) _positions(BattleState s) {
  final ids = [...s.party.map((p) => p.id), ...s.enemies.map((e) => e.id)];
  return (id) => Offset(100.0 * ids.indexOf(id), 200);
}

/// Lo que se ve de cada efecto (el destino solo cuenta en los que viajan).
List<String> _look(List<BattleFx> fx) => [
      for (final f in fx)
        if (f.kind != FxKind.data)
          '$f el=${f.el} w=${f.weapon} up=${f.up} heavy=${f.heavy} '
              'ghost=${f.ghost} hurt=${f.hurt}'
              '${f.kind == FxKind.proj || f.kind == FxKind.arc ? ' to=(${f.tx}, ${f.ty})' : ''}'
    ]..sort();

void main() {
  tearDown(() => FxCatalog.active = null);

  test('ninguna fx sin datos: momentos, ULT, dúo y todo lo del adaptador', () {
    final cat = _catalog();
    expect(cat.log, isEmpty);
    for (final MapEntry(key: id, value: category) in kBattleFxMoments.entries) {
      expect(cat.sourceOf(id), FxSource.data, reason: id);
      final t = cat.timeline(id)!;
      expect(t.category, category, reason: id);
      expect(
          t.tracks.any((tr) =>
              tr.type == 'prim' || kFxVisualTracks.contains(tr.type)),
          isTrue,
          reason: '$id: sin pistas visuales');
      for (final tr in t.ofType('prim')) {
        for (final f in tr.fires) {
          expect(FxKind.values.map((k) => k.name), contains(f.s('kind')),
              reason: '$id: primitiva ${f.s('kind')}');
          expect(f.t, lessThanOrEqualTo(t.duration), reason: id);
        }
      }
    }
    // Todo lo que el adaptador sabe armar desde el código ya tiene datos
    // (queda solo como respaldo).
    for (final id in const LegacyFxAdapter().ids) {
      expect(cat.sourceOf(id), FxSource.data, reason: '$id sigue legacy');
    }
    for (final id in [...kUltScripts.keys, ...kEnemyUltScripts.keys]) {
      final t = cat.timeline(id)!;
      expect(t.legacy, isFalse, reason: id);
      expect(t.duration, lessThanOrEqualTo(kUltMaxDurationMs), reason: id);
      expect(t.ofType('echo'), isNotEmpty, reason: '$id: firma de ecos');
    }
  });

  test('pubspec registra la carpeta de cada categoría (publicar sin tocarlo)',
      () {
    final pub = File('pubspec.yaml').readAsStringSync();
    for (final c in kFxCategories) {
      expect(pub, contains('- assets/fx/$c/'), reason: c);
      expect(Directory('assets/fx/$c').existsSync(), isTrue, reason: c);
    }
    final cat = _catalog();
    for (final rel in cat.paths.values) {
      expect(kFxCategories, contains(rel.split('/').first), reason: rel);
    }
  });

  test('ULT de ascensión: mismos tiempos de juego que el guion del código', () {
    FxCatalog.active = _catalog();
    for (final id in const [
      'ult_berserker',
      'ult_senorGuerra',
      'ult_cronomante',
      'ult_elementalista',
      'ult_francotirador',
      'ult_trampero',
      'ult_templario',
      'ult_guardian',
    ]) {
      final code = kUltScripts[id]!;
      final data = ultScriptFor(id);
      expect(data.data, isNotNull, reason: id);
      expect(data.totalMs, code.totalMs, reason: id);
      expect(data.buildMs, code.buildMs, reason: id);
      expect(data.impactMs, code.impactMs, reason: id);
      expect(data.staggerMs, code.staggerMs, reason: id);
      expect(data.preHitsMs, code.preHitsMs, reason: id);
      expect(data.hitStopMs, code.hitStopMs, reason: id);
    }
  });

  test('mismo aspecto que el código: batallas enteras con y sin datos', () {
    final cat = _catalog(skip: _improved);
    // Las ULT salen de los datos en los dos; cambian solo los momentos.
    final base = _catalog(skip: kBattleFxMoments.keys.toSet());
    var compared = 0;
    var data = 0;
    for (final (cls, weapon, foes) in const [
      ('guerrero', 'espada_bronce', ['golem', 'slime']),
      ('maga', 'baculo_aprendiz', ['bat', 'ghost', 'slime']),
      ('tirador', 'arco_corto', ['golem']),
      ('paladin', null, ['slime', 'bat']),
      ('guerrero', 'hacha_rompe', ['ghost', 'golem', 'bat']),
      ('tirador', 'rifle_aturdidor', ['slime', 'slime']),
      ('tirador', 'dagas_cobre', ['bat', 'golem']),
      ('maga', 'tomo_tiempo', ['golem', 'ghost']),
      ('maga', 'varita_sauce', ['slime']),
      ('guerrero', 'lanza_hierro', ['bat', 'bat']),
      ('tirador', 'ballesta_pesada', ['ghost']),
    ]) {
      var i = 0;
      final engine = BattleEngine(
        stats: StatsCalculator(
            classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
        random: () => ((i++ * 37) % 100) / 100,
      );
      var state = engine
          .start(
              party: [_member('p1', cls, weapon), _member('p2', 'paladin', null)],
              enemyTypes: foes,
              triggeredBy: 'p1')
          .state;
      for (var turn = 0; turn < 40 && !state.ended; turn++) {
        final steps = [engine.nextTurn(state)];
        state = steps.last.state;
        final cur = state.byId(state.currentId ?? '');
        if (cur != null && cur.alive) {
          final step = cur.isPlayer
              ? (switch (turn % 4) {
                    0 => engine.command(state, cur.id, const UltimateCommand()),
                    1 => cur.skillIds.isEmpty
                        ? null
                        : engine.command(state, cur.id,
                            SkillCommand(cur.skillIds[turn % cur.skillIds.length])),
                    _ => null,
                  } ??
                  engine.command(state, cur.id, const AttackCommand()))
              : engine.enemyTurn(state);
          if (step != null) {
            steps.add(step);
            state = step.state;
          }
        }
        for (final s in steps) {
          FxCatalog.active = base;
          final code = mapBattleEvents(s.events, s.state, _positions(s.state));
          FxCatalog.active = cat;
          final fromData =
              mapBattleEvents(s.events, s.state, _positions(s.state));
          data += fromData.where((f) => f.kind == FxKind.data).length;
          expect(_look(fromData), _look(code), reason: '${s.events}');
          compared++;
        }
      }
    }
    expect(compared, greaterThan(40));
    expect(data, greaterThanOrEqualTo(0));
  });

  test('las mejoras con ecos agregan su efecto de datos', () {
    FxCatalog.active = _catalog();
    final state = BattleState(party: [
      Combatant(id: 'p1', name: 'A', isPlayer: true, hp: 10, maxHp: 10,
          speed: 5, attack: 1, critChance: 0),
    ], enemies: []);
    final fx = mapBattleEvents(const [], state, (_) => Offset.zero);
    expect(fx, isEmpty);
    expect(battleMomentData('convergence')!.ofType('shape'), isNotEmpty);
    expect(battleMomentData('skill_pulse')!.ofType('shape'), isNotEmpty);
    expect(battleMomentData('revive')!.ofType('prim'), isNotEmpty);
  });
}
