import 'dart:collection';
import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/passive_tree_v2_catalog.dart';

/// Distancias (en nodos) desde [from] por los enlaces.
Map<String, int> _bfs(PassiveTreeCatalog tree, String from) {
  final dist = {from: 0};
  final q = Queue.of([from]);
  while (q.isNotEmpty) {
    final id = q.removeFirst();
    for (final l in tree.nodes[id]!.links) {
      if (dist.containsKey(l)) continue;
      dist[l] = dist[id]! + 1;
      q.add(l);
    }
  }
  return dist;
}

const _classCluster = [
  'e1', 'e2', 'f', 'a1', 'a2', 'na', 'b1', 'b2', 'nb', 'j', 'k', //
];

void main() {
  final tree = kPassiveTree;
  final rules = PassiveTreeRules(tree);

  test('352 nodos: 60 notables, 20 keystones (passive_tree_v3.md § 1)', () {
    expect(tree.nodes, hasLength(352));
    final kinds = <String, int>{};
    for (final n in tree.nodes.values) {
      kinds[n.kind] = (kinds[n.kind] ?? 0) + 1;
    }
    expect(kinds, {'st': 4, 's': 352 - 4 - 60 - 20, 'n': 60, 'k': 20});
    expect(tree.paths, hasLength(28));
    for (final cls in tree.startNodeByClass.keys) {
      expect(tree.paths.values.where((p) => p.classId == cls), hasLength(5),
          reason: cls);
    }
    expect(tree.paths.values.where((p) => p.kind == 'puente'), hasLength(4));
    expect(tree.paths.values.where((p) => p.kind == 'grupo'), hasLength(4));
    // Con el máximo (nivel 50 + 20 de Maestría = 69 puntos) se cubre ~20%.
    expect(69 / tree.nodes.length, inInclusiveRange(0.18, 0.22));
  });

  test('ids únicos y determinísticos; enlaces simétricos y sin repetir', () {
    expect(_bfs(kPassiveTree, 's_gue').length, tree.nodes.length);
    for (final n in tree.nodes.values) {
      expect(n.links.toSet(), hasLength(n.links.length), reason: n.id);
      expect(n.links, isNot(contains(n.id)));
      for (final l in n.links) {
        expect(tree.nodes[l], isNotNull, reason: '${n.id} → $l');
        expect(tree.nodes[l]!.links, contains(n.id), reason: '${n.id} ↔ $l');
      }
    }
  });

  test('coordenadas: ningún par de nodos se pisa', () {
    final list = tree.nodes.values.toList();
    var minD = double.infinity;
    var pair = '';
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final d = math.sqrt(math.pow(list[i].x - list[j].x, 2) +
            math.pow(list[i].y - list[j].y, 2));
        if (d < minD) {
          minD = d;
          pair = '${list[i].id} / ${list[j].id}';
        }
      }
    }
    expect(minD, greaterThanOrEqualTo(0.75), reason: pair);
    // Todo entra en el lienzo de la UI (±18 unidades).
    for (final n in list) {
      expect(math.max(n.x.abs(), n.y.abs()), lessThan(18), reason: n.id);
    }
  });

  test('cada cluster de clase: entrada → bifurcación → 2 notables → keystone',
      () {
    for (final path in tree.paths.values.where((p) => p.kind == 'clase')) {
      final ids = [for (final s in _classCluster) '${path.id}_$s'];
      final kinds = [for (final id in ids) tree.nodes[id]!.kind];
      expect(kinds, ['s', 's', 's', 's', 's', 'n', 's', 's', 'n', 's', 'k'],
          reason: path.id);
      for (final id in ids) {
        expect(tree.nodes[id]!.pathId, path.id);
      }
      expect(tree.nodes['${path.id}_f']!.links,
          containsAll(['${path.id}_a1', '${path.id}_b1']));
      expect(tree.nodes['${path.id}_j']!.links,
          containsAll(['${path.id}_na', '${path.id}_nb', '${path.id}_k']));
      expect(tree.nodes['${path.id}_k']!.links, ['${path.id}_j'],
          reason: 'la keystone es la punta del cluster');
    }
  });

  test('inicios y anillo: mismos ids y efectos que la v2', () {
    final v2 = kPassiveTreeV2;
    expect(kTreeIdsStableSinceV2, hasLength(16));
    for (final id in kTreeIdsStableSinceV2) {
      final a = tree.nodes[id]!, b = v2.nodes[id]!;
      expect(a.name, b.name, reason: id);
      expect(a.kind, b.kind, reason: id);
      expect(a.effects, b.effects, reason: id);
    }
    expect(tree.nodes['s_gue']!.links.toSet(), {'p_gue', 'gue_r1'});
    for (final id in ['p_gue', 'r_gm1', 'r_gm2', 'p_mag', 'r_mt1', 'r_pg2']) {
      final ring = tree.nodes[id]!.links
          .where((l) => l.startsWith('p_') || l.startsWith('r_'));
      expect(ring, hasLength(2), reason: id);
    }
    // Cada cluster de grupo cuelga de los 2 nodos de anillo de su diagonal.
    expect(tree.nodes['estandarte_e1']!.links.toSet(),
        {'r_gm1', 'r_gm2', 'estandarte_e2'});
    expect(tree.nodes['refugio_e1']!.links.toSet(),
        {'r_pg1', 'r_pg2', 'refugio_e2'});
  });

  test('costo de viajar: tu zona barata, las lejanas caras', () {
    for (final start in tree.startNodeByClass.values) {
      expect(_bfs(tree, start).keys.toSet(), tree.nodes.keys.toSet(),
          reason: 'todo se alcanza desde $start');
    }
    // Puntos antes del primer nodo del cluster = distancia − 1.
    final g = _bfs(tree, 's_gue');
    expect(g['quiebre_e1']! - 1, 3, reason: 'cluster central propio');
    expect(g['sangre_e1']! - 1, 4);
    expect(g['muralla_e1']! - 1, 5);
    expect(g['estandarte_e1']! - 1, 2, reason: 'cluster de grupo');
    expect(g['cronos_e1']! - 1, 8, reason: 'zona vecina');
    expect(g['precision_e1']! - 1, 11, reason: 'zona opuesta');
    expect(g['hojaArcana_n1']!, greaterThanOrEqualTo(14));
  });

  test('atajos entre clusters vecinos y puentes entre clases vecinas', () {
    expect(tree.nodes['muralla_b2']!.links, contains('sangre_a2'));
    expect(tree.nodes['filo_b2']!.links, isNot(contains('arcano_a2')),
        reason: 'el atajo es solo dentro de la clase');
    expect(tree.nodes['hojaArcana_a1']!.links, contains('filo_nb'));
    expect(tree.nodes['hojaArcana_b1']!.links, contains('arcano_na'));
    expect(tree.nodes['coloso_a1']!.links, contains('bastion_nb'));
    expect(tree.nodes['coloso_b1']!.links, contains('muralla_na'));
    expect(tree.paths['runas']!.classId, 'maga+tirador');
  });

  test('un guerrero puede tomar nodos de la Maga viajando por el anillo', () {
    var progress = PlayerPassiveProgress.empty;
    for (final id in [
      'p_gue', 'r_gm1', 'r_gm2', 'p_mag', 's_mag', 'mag_r1', 'mag_r2', //
      'mag_f3', 'cronos_e1',
    ]) {
      expect(rules.canTake('guerrero', 30, progress, id), isTrue, reason: id);
      progress = PlayerPassiveProgress([...progress.takenNodeIds, id]);
    }
    final mods = rules.aggregate('guerrero', progress);
    expect(mods['mag'], closeTo(0.04 + 0.04 + 0.03 + 0.02 + 0.03, 1e-9),
        reason: 'umbral + inicio de la maga + Estudio + Sendero + Segundero');
  });

  test('notables y keystones tienen su mecánica en kMechanics', () {
    final mechs = <String>{};
    for (final n in tree.nodes.values) {
      if (n.kind == 'n') expect(n.mechanicId, isNotNull, reason: n.id);
      final m = n.mechanicId;
      if (m != null) {
        expect(kMechanics[m], isNotNull, reason: '${n.id}: $m');
        expect(mechs.add(m), isTrue, reason: 'mecánica repetida: $m');
        expect(kSkills.containsKey(m), isFalse,
            reason: '$m choca con una habilidad');
      }
    }
    expect(mechs, hasLength(60 + 4 + 8));
    final keys = {
      for (final n in tree.nodes.values)
        if (n.kind == 'k') n.keystoneId!,
    };
    expect(keys, {
      'imparable', 'furia', 'danza', 'mente', 'tormenta', 'almaHielo', //
      'halcon', 'toxicidad', 'cadena', 'creyente', 'inherente', 'egida',
      'demoledor', 'caudillo', 'bucle', 'singularidad', 'diluvio',
      'depredador', 'solInterior', 'inamovible',
    });
  });

  test('aggregate junta las mecánicas tomadas', () {
    final p = PlayerPassiveProgress([
      'gue_r1', 'gue_r2', 'gue_f3', 'gue_f4', 'gue_f5', //
      for (final s in _classCluster) 'filo_$s',
    ]);
    final m = rules.aggregate('guerrero', p);
    expect(m.mechanics, {'frenesi', 'corteCadena', 'danza'});
    expect(m.keys, {'danza'});
    expect(m.critCap, 0.40);
    expect(m['crit'], closeTo(0.015 * 6, 1e-9));
    expect(m['spd'], closeTo(0.15 * 3, 1e-9));
  });

  test('contras de las keystones nuevas', () {
    TreeMods only(String classId, String cluster) => rules.aggregate(classId,
        PlayerPassiveProgress([for (final s in _classCluster) '${cluster}_$s']));
    final small = {
      'demoledor': ('guerrero', 'quiebre', 'hp', 0.03 * 3 - 0.15),
      'caudillo': ('guerrero', 'gritos', 'ult', 0.03 * 5 + 0.04 - 0.30),
      'bucle': ('maga', 'cronos', 'spd', 0.15 * 5 - 1.0),
      'singularidad': ('maga', 'prisma', 'mag', 0.02 * 5 - 0.10),
      'diluvio': ('tirador', 'lluvia', 'atk', 0.03 * 6 - 0.15),
      'depredador': ('tirador', 'acecho', 'hp', -0.20),
      'solInterior': ('paladin', 'luz', 'atk', -0.15),
      'inamovible': ('paladin', 'vigilia', 'spd', -1.0),
      'egida': ('paladin', 'bastion', 'atk', -0.20),
    };
    small.forEach((key, v) {
      final (cls, cluster, stat, expected) = v;
      final m = only(cls, cluster);
      expect(m.keys, {key});
      final start = tree.nodes[tree.startNodeByClass[cls]]!.effects[stat] ?? 0;
      expect(m[stat], closeTo(expected + start, 1e-9), reason: key);
    });
  });

  test('Creyente e Inherente se excluyen', () {
    final progress = PlayerPassiveProgress([
      'pal_r1', 'pal_r2', 'pal_f3', //
      for (final s in _classCluster) 'fe_$s',
      'pal_f2',
      for (final s in _classCluster.take(10)) 'juicio_$s',
    ]);
    expect(rules.canTake('paladin', 69, progress, 'juicio_j'), isFalse,
        reason: 'ya lo tiene');
    expect(rules.canTake('paladin', 69, progress, 'juicio_k'), isFalse);
  });

  test('posiciones: el cluster central de cada clase sale en su ángulo', () {
    final n = tree.nodes['quiebre_e1']!; // guerrero (−90°)
    expect(n.x, closeTo(0, 1e-9));
    expect(n.y, closeTo(-kClusterRadius, 1e-9));
    final k = tree.nodes['fe_k']!; // paladín (180°)
    expect(k.x, closeTo(-(kClusterRadius + 5.55), 1e-9));
    expect(k.y, closeTo(0, 1e-9));
  });

  test('pathTo: el camino más corto que falta, con su costo', () {
    const empty = PlayerPassiveProgress.empty;
    expect(rules.pathTo('guerrero', empty, 'quiebre_e1'),
        ['gue_r1', 'gue_r2', 'gue_f3', 'quiebre_e1']);
    expect(rules.pathTo('guerrero', empty, 's_gue'), isEmpty);
    const some = PlayerPassiveProgress(['gue_r1', 'gue_r2']);
    expect(rules.pathTo('guerrero', some, 'gue_f4'), ['gue_f3', 'gue_f4']);
    expect(rules.pathTo('guerrero', some, 'nope'), isNull);
    // La keystone excluida no tiene camino.
    final fe = PlayerPassiveProgress([
      'pal_r1', 'pal_r2', 'pal_f3', for (final s in _classCluster) 'fe_$s',
    ]);
    expect(rules.pathTo('paladin', fe, 'juicio_k'), isNull);
    // Por el atajo fe_a2 ↔ juicio_b2, no por la entrada de Juicio.
    expect(rules.pathTo('paladin', fe, 'juicio_j'),
        ['juicio_b2', 'juicio_nb', 'juicio_j']);
  });
}
