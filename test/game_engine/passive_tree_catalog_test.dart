import 'dart:collection';
import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/passive_tree_v2_catalog.dart';
import 'fixtures/passive_tree_v3_catalog.dart';

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

/// Plantilla de un cluster de clase v4 (passive_tree_v4.md § 2).
const _classCluster = ['n1', 'm1', 'm2', 'na', 'nb', 'ma', 'mb', 'nc', 'k'];

void main() {
  final tree = kPassiveTree;
  final rules = PassiveTreeRules(tree);

  test('308 nodos: 104 notables, 20 keystones (passive_tree_v4.md § 1)', () {
    expect(tree.nodes, hasLength(308));
    final kinds = <String, int>{};
    for (final n in tree.nodes.values) {
      kinds[n.kind] = (kinds[n.kind] ?? 0) + 1;
    }
    expect(kinds, {'st': 4, 's': 308 - 4 - 104 - 20, 'n': 104, 'k': 20});
    expect(tree.paths, hasLength(28));
    for (final cls in tree.startNodeByClass.keys) {
      expect(tree.paths.values.where((p) => p.classId == cls), hasLength(5),
          reason: cls);
    }
    expect(tree.paths.values.where((p) => p.kind == 'puente'), hasLength(4));
    expect(tree.paths.values.where((p) => p.kind == 'grupo'), hasLength(4));
    // Con el máximo (nivel 50 + 20 de Maestría = 69 puntos) se cubre
    // ~22%: un poco más que la v3 (19.6%) porque hay menos relleno.
    expect(69 / tree.nodes.length, inInclusiveRange(0.20, 0.23));
  });

  test('cada cluster de clase tiene 4 notables y menos chicos que notables+1',
      () {
    for (final path in tree.paths.values.where((p) => p.kind == 'clase')) {
      final nodes = tree.nodes.values.where((n) => n.pathId == path.id);
      expect(nodes.where((n) => n.kind == 'n'), hasLength(4), reason: path.id);
      expect(nodes.where((n) => n.kind == 's'), hasLength(4), reason: path.id);
      expect(nodes.where((n) => n.kind == 'k'), hasLength(1), reason: path.id);
    }
    for (final path in tree.paths.values.where((p) => p.kind == 'grupo')) {
      final nodes = tree.nodes.values.where((n) => n.pathId == path.id);
      expect(nodes.where((n) => n.kind == 'n'), hasLength(3), reason: path.id);
    }
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

  test('cluster de clase: notable → 2 chicos → bifurcación de notables → '
      'unión notable → keystone', () {
    for (final path in tree.paths.values.where((p) => p.kind == 'clase')) {
      String id(String s) => '${path.id}_$s';
      final kinds = [for (final s in _classCluster) tree.nodes[id(s)]!.kind];
      expect(kinds, ['n', 's', 's', 'n', 'n', 's', 's', 'n', 'k'],
          reason: path.id);
      for (final s in _classCluster) {
        expect(tree.nodes[id(s)]!.pathId, path.id);
      }
      expect(tree.nodes[id('m2')]!.links, containsAll([id('na'), id('nb')]));
      expect(tree.nodes[id('nc')]!.links,
          containsAll([id('ma'), id('mb'), id('k')]));
      expect(tree.nodes[id('k')]!.links, [id('nc')],
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

  test('ids estables desde la v3: iguales en todo (lo demás se devuelve)', () {
    final v3 = kPassiveTreeV3;
    // 16 + 4 × (r1 + 5 abanico) + 20 × 3 + 4 × 12 + 4 × 9.
    expect(kTreeIdsStableSinceV3, hasLength(16 + 24 + 60 + 48 + 36));
    for (final id in kTreeIdsStableSinceV3) {
      final a = tree.nodes[id], b = v3.nodes[id];
      expect(a, isNotNull, reason: id);
      expect(b, isNotNull, reason: id);
      expect(a!.name, b!.name, reason: id);
      expect(a.kind, b.kind, reason: id);
      expect(a.effects, b.effects, reason: id);
      expect(a.mechanicId, b.mechanicId, reason: id);
      expect(a.keystoneId, b.keystoneId, reason: id);
    }
    // Y ningún otro id de la v3 que siga existiendo cambió de sentido sin
    // estar en la lista: los que siguen iguales están todos.
    for (final id in v3.nodes.keys) {
      final a = tree.nodes[id], b = v3.nodes[id]!;
      if (a == null) continue;
      final same = a.name == b.name &&
          a.kind == b.kind &&
          a.mechanicId == b.mechanicId &&
          '${a.effects}' == '${b.effects}';
      expect(kTreeIdsStableSinceV3.contains(id), same, reason: id);
    }
  });

  test('costo de viajar: el primer notable de tu clase a 3 puntos', () {
    for (final start in tree.startNodeByClass.values) {
      expect(_bfs(tree, start).keys.toSet(), tree.nodes.keys.toSet(),
          reason: 'todo se alcanza desde $start');
    }
    // Puntos para tomar un nodo = su distancia al inicio.
    for (final (cls, start) in [
      ('guerrero', 's_gue'),
      ('maga', 's_mag'),
      ('tirador', 's_tir'),
      ('paladin', 's_pal'),
    ]) {
      final d = _bfs(tree, start);
      final mine = tree.paths.values.where((p) => p.classId == cls).toList();
      final costs = [for (final p in mine) d['${p.id}_n1']!];
      expect(costs, [4, 3, 3, 3, 4], reason: cls);
      // Toda la keystone de tu clase a 9-10 puntos (v3: 9-11).
      for (final p in mine) {
        expect(d['${p.id}_k']!, inInclusiveRange(9, 10), reason: p.id);
      }
    }
    final g = _bfs(tree, 's_gue');
    expect(g['estandarte_e1']!, 3, reason: 'cluster de grupo');
    expect(g['cronos_n1']!, 8, reason: 'zona vecina');
    expect(g['precision_n1']!, 11, reason: 'zona opuesta');
    expect(g['hojaArcana_n1']!, greaterThanOrEqualTo(11));
  });

  test('atajos entre clusters vecinos y puentes entre clases vecinas', () {
    expect(tree.nodes['muralla_mb']!.links, contains('sangre_ma'));
    expect(tree.nodes['filo_mb']!.links, isNot(contains('arcano_ma')),
        reason: 'el atajo es solo dentro de la clase');
    expect(tree.nodes['hojaArcana_a1']!.links, contains('filo_nb'));
    expect(tree.nodes['hojaArcana_b1']!.links, contains('arcano_na'));
    expect(tree.nodes['coloso_a1']!.links, contains('bastion_nb'));
    expect(tree.nodes['coloso_b1']!.links, contains('muralla_na'));
    expect(tree.paths['runas']!.classId, 'maga+tirador');
    expect(tree.nodes['gue_r1']!.links.toSet(),
        {'s_gue', 'gue_f2', 'gue_f3', 'gue_f4'});
  });

  test('un guerrero puede tomar nodos de la Maga viajando por el anillo', () {
    var progress = PlayerPassiveProgress.empty;
    for (final id in [
      'p_gue', 'r_gm1', 'r_gm2', 'p_mag', 's_mag', 'mag_r1', 'mag_f3', //
      'cronos_n1', 'cronos_m1',
    ]) {
      expect(rules.canTake('guerrero', 30, progress, id), isTrue, reason: id);
      progress = PlayerPassiveProgress([...progress.takenNodeIds, id]);
    }
    final mods = rules.aggregate('guerrero', progress);
    expect(mods['mag'], closeTo(0.04 + 0.04 + 0.03 + 0.02 + 0.045, 1e-9),
        reason: 'umbral + inicio de la maga + Estudio + Sendero + Segundero');
    expect(mods.mechanics, {'arenaTiempo'});
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
    // 104 notables + 12 keystones con mecánica propia.
    expect(mechs, hasLength(104 + 12));
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
      'gue_r1', 'gue_f4', 'gue_f5', //
      for (final s in _classCluster) 'filo_$s',
    ]);
    final m = rules.aggregate('guerrero', p);
    expect(m.mechanics,
        {'estocadaPrecisa', 'frenesi', 'corteCadena', 'desarme', 'danza'});
    expect(m.keys, {'danza'});
    expect(m.critCap, 0.40);
    expect(m['crit'], closeTo(0.02 * 2 + 0.015 * 2, 1e-9));
    expect(m['spd'], closeTo(0.2 * 2 + 0.15, 1e-9));
  });

  test('contras de las keystones nuevas', () {
    TreeMods only(String classId, String cluster) => rules.aggregate(classId,
        PlayerPassiveProgress([for (final s in _classCluster) '${cluster}_$s']));
    final small = {
      'demoledor': ('guerrero', 'quiebre', 'hp', 0.04 * 2 - 0.15),
      'caudillo': ('guerrero', 'gritos', 'ult', 0.05 * 2 + 0.03 + 0.04 + 0.03 - 0.30),
      'bucle': ('maga', 'cronos', 'spd', 0.2 * 2 + 0.15 * 4 - 1.0),
      'singularidad': ('maga', 'prisma', 'mag', 0.03 * 3 - 0.10),
      'diluvio': ('tirador', 'lluvia', 'atk', 0.05 * 2 + 0.03 * 2 - 0.15),
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
      'pal_r1', 'pal_f3', //
      for (final s in _classCluster) 'fe_$s',
      'pal_f2',
      for (final s in _classCluster.take(8)) 'juicio_$s',
    ]);
    expect(rules.canTake('paladin', 69, progress, 'juicio_nc'), isFalse,
        reason: 'ya lo tiene');
    expect(rules.canTake('paladin', 69, progress, 'juicio_k'), isFalse);
  });

  test('posiciones: el cluster central de cada clase sale en su ángulo', () {
    final n = tree.nodes['quiebre_n1']!; // guerrero (−90°)
    expect(n.x, closeTo(0, 1e-9));
    expect(n.y, closeTo(-kClusterRadius, 1e-9));
    final k = tree.nodes['fe_k']!; // paladín (180°)
    expect(k.x, closeTo(-(kClusterRadius + kKeystoneOffset), 1e-9));
    expect(k.y, closeTo(0, 1e-9));
  });

  test('pathTo: el camino más corto que falta, con su costo', () {
    const empty = PlayerPassiveProgress.empty;
    expect(rules.pathTo('guerrero', empty, 'quiebre_n1'),
        ['gue_r1', 'gue_f3', 'quiebre_n1']);
    expect(rules.pathTo('guerrero', empty, 's_gue'), isEmpty);
    const some = PlayerPassiveProgress(['gue_r1']);
    expect(rules.pathTo('guerrero', some, 'gue_f5'), ['gue_f4', 'gue_f5']);
    expect(rules.pathTo('guerrero', some, 'nope'), isNull);
    // La keystone excluida no tiene camino.
    final fe = PlayerPassiveProgress([
      'pal_r1', 'pal_f3', for (final s in _classCluster) 'fe_$s',
    ]);
    expect(rules.pathTo('paladin', fe, 'juicio_k'), isNull);
    // Por el atajo fe_ma ↔ juicio_mb, no por la entrada de Juicio.
    expect(rules.pathTo('paladin', fe, 'juicio_nc'),
        ['juicio_mb', 'juicio_nc']);
  });
}
