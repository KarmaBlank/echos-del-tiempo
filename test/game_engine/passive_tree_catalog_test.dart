import 'dart:collection';

import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  final tree = kPassiveTree;
  final rules = PassiveTreeRules(tree);

  test('112 nodos: 4 inicios + anillo de 12 + 12 caminos × 8', () {
    expect(tree.nodes, hasLength(112));
    final kinds = <String, int>{};
    for (final n in tree.nodes.values) {
      kinds[n.kind] = (kinds[n.kind] ?? 0) + 1;
    }
    expect(kinds, {'st': 4, 's': 12 + 12 * 5, 'n': 24, 'k': 12});
    expect(tree.paths, hasLength(12));
    for (final cls in tree.startNodeByClass.keys) {
      expect(tree.paths.values.where((p) => p.classId == cls), hasLength(3));
    }
  });

  test('los enlaces son simétricos y apuntan a nodos que existen', () {
    for (final n in tree.nodes.values) {
      for (final l in n.links) {
        expect(tree.nodes[l], isNotNull, reason: '${n.id} → $l');
        expect(tree.nodes[l]!.links, contains(n.id), reason: '${n.id} ↔ $l');
      }
    }
  });

  test(
      'cada camino: inicio → 3 chicos → notable → 2 chicos → notable → keystone',
      () {
    for (final path in tree.paths.values) {
      final ids = [
        for (final s in ['1', '2', '3', 'n1', '4', '5', 'n2', 'k'])
          '${path.id}_$s',
      ];
      final kinds = [for (final id in ids) tree.nodes[id]!.kind];
      expect(kinds, ['s', 's', 's', 'n', 's', 's', 'n', 'k'], reason: path.id);
      final start = tree.startNodeByClass[path.classId]!;
      expect(tree.nodes[ids.first]!.links, contains(start));
      for (var i = 1; i < ids.length; i++) {
        expect(tree.nodes[ids[i]]!.links, contains(ids[i - 1]));
        expect(tree.nodes[ids[i]]!.pathId, path.id);
      }
      expect(tree.nodes['${path.id}_k']!.links, ['${path.id}_n2'],
          reason: 'la keystone es el final del camino');
    }
  });

  test('anillo central: ciclo de 12 y cada inicio entra por su umbral', () {
    expect(tree.nodes['s_gue']!.links.toSet(),
        {'p_gue', 'muralla_1', 'sangre_1', 'filo_1'});
    for (final id in ['p_gue', 'r_gm1', 'r_gm2', 'p_mag', 'r_mt1', 'r_pg2']) {
      final ring = tree.nodes[id]!.links
          .where((l) => l.startsWith('p_') || l.startsWith('r_'));
      expect(ring, hasLength(2), reason: id);
    }
  });

  test('todo camino se alcanza desde el inicio de cualquier clase', () {
    for (final start in tree.startNodeByClass.values) {
      final dist = _bfs(tree, start);
      expect(dist.keys.toSet(), tree.nodes.keys.toSet(), reason: start);
    }
    // Zona vecina: umbral propio + 2 de anillo + umbral vecino + inicio
    // vecino = 5 puntos antes del primer nodo de un camino; opuesta: 8.
    final fromWarrior = _bfs(tree, 's_gue');
    expect(fromWarrior['brasa_1'], 6);
    expect(fromWarrior['toxina_1'], 9);
  });

  test('un guerrero puede tomar nodos de la Maga viajando por el anillo', () {
    var progress = PlayerPassiveProgress.empty;
    for (final id in ['p_gue', 'r_gm1', 'r_gm2', 'p_mag', 's_mag', 'brasa_1']) {
      expect(rules.canTake('guerrero', 30, progress, id), isTrue, reason: id);
      progress = PlayerPassiveProgress([...progress.takenNodeIds, id]);
    }
    final mods = rules.aggregate('guerrero', progress);
    expect(mods['mag'], closeTo(0.04 + 0.04 + 0.06, 1e-9),
        reason: 'umbral arcano + inicio de la maga + Ascua');
  });

  test('notables y keystones nuevas tienen su mecánica en kMechanics', () {
    final mechs = <String>{};
    for (final n in tree.nodes.values) {
      if (n.kind == 'n') {
        expect(n.mechanicId, isNotNull, reason: n.id);
      }
      final m = n.mechanicId;
      if (m != null) {
        expect(kMechanics[m], isNotNull, reason: '${n.id}: $m');
        mechs.add(m);
      }
    }
    expect(mechs, hasLength(24 + 4));
    final keys = {
      for (final n in tree.nodes.values)
        if (n.kind == 'k') n.keystoneId!,
    };
    expect(keys, {
      'imparable', 'furia', 'danza', 'mente', 'tormenta', 'almaHielo', //
      'halcon', 'toxicidad', 'cadena', 'creyente', 'inherente', 'egida',
    });
  });

  test('aggregate junta las mecánicas tomadas', () {
    const p = PlayerPassiveProgress([
      'filo_1',
      'filo_2',
      'filo_3',
      'filo_n1',
      'filo_4',
      'filo_5',
      'filo_n2',
      'filo_k'
    ]);
    final m = rules.aggregate('guerrero', p);
    expect(m.mechanics, {'frenesi', 'corteCadena', 'danza'});
    expect(m.keys, {'danza'});
    expect(m.critCap, 0.40);
    expect(m['crit'], closeTo(0.03 * 4, 1e-9));
    expect(m['spd'], closeTo(0.6, 1e-9));
  });

  test('Égida Eterna: −20% ATQ y MAG', () {
    const p = PlayerPassiveProgress([
      'bastion_1', 'bastion_2', 'bastion_3', 'bastion_n1', 'bastion_4', //
      'bastion_5', 'bastion_n2', 'bastion_k',
    ]);
    final m = rules.aggregate('paladin', p);
    expect(m['atk'], closeTo(-0.20, 1e-9));
    expect(m['mag'], closeTo(-0.20, 1e-9));
  });

  test('Creyente e Inherente se excluyen', () {
    final fe = [
      for (final s in ['1', '2', '3', 'n1', '4', '5', 'n2', 'k']) 'fe_$s'
    ];
    final juicio = [
      for (final s in ['1', '2', '3', 'n1', '4', '5', 'n2']) 'juicio_$s'
    ];
    final progress = PlayerPassiveProgress([...fe, ...juicio]);
    expect(rules.canTake('paladin', 40, progress, 'juicio_k'), isFalse);
  });

  test('posiciones: caminos rectos desde el centro', () {
    final n = tree.nodes['sangre_1']!; // guerrero (−90°), camino del medio
    expect(n.x, closeTo(0, 1e-9));
    expect(n.y, closeTo(-kPathFirstRadius, 1e-9));
    final k = tree.nodes['sangre_k']!;
    expect(k.y, closeTo(-(kPathFirstRadius + 7 * kPathStep), 1e-9));
  });
}
