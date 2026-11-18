import 'dart:collection';

import 'package:echos_del_tiempo/features/characters/domain/unused_points.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/passive_tree_v5_catalog.dart';
import 'session_test_helpers.dart';

// Árbol v6 (v0.8, docs/specs/passive_tree_v6.md § 7-8): el doble de
// puntos (2 por nivel y por Maestría) y los perfiles v5 que se quedan con
// sus nodos y ganan los puntos nuevos sin gastar.

/// Los primeros [n] nodos del árbol v5 en orden de búsqueda desde el
/// inicio del guerrero: un build v5 válido (cada uno conecta con uno
/// anterior).
List<String> _v5Build(int n) {
  final tree = kV5PassiveTree;
  final start = tree.startNodeByClass['guerrero']!;
  final seen = {start};
  final out = <String>[];
  final q = Queue.of([start]);
  while (q.isNotEmpty && out.length < n) {
    final id = q.removeFirst();
    for (final l in tree.nodes[id]!.links) {
      if (!seen.add(l)) continue;
      // Sin keystones excluidas entre sí ni nada raro: solo seguir.
      out.add(l);
      q.add(l);
      if (out.length == n) break;
    }
  }
  return out;
}

void main() {
  final rules = PassiveTreeRules(kPassiveTree);

  test('2 puntos por nivel y por Maestría: 138 al máximo', () {
    expect(PassiveTreeRules.pointsPerLevel, 2);
    final lv2 = PlayerProfile(name: 'A', classId: 'maga', level: 2);
    expect(rules.pointsAvailable(lv2.treeLevel, lv2.passiveProgress), 2);
    final lv50 = PlayerProfile(name: 'A', classId: 'maga', level: 50);
    expect(rules.pointsAvailable(lv50.treeLevel, lv50.passiveProgress), 98);
    final m1 = lv50.copyWith(mastery: 1);
    expect(rules.pointsAvailable(m1.treeLevel, m1.passiveProgress), 100,
        reason: 'cada Maestría da 2 más');
    final max = lv50.copyWith(mastery: PlayerProfile.maxMastery);
    expect(PlayerProfile.maxMastery, 20);
    expect(rules.pointsAvailable(max.treeLevel, max.passiveProgress), 138);
  });

  test('un perfil v5 con sus 69 puntos gastados conserva todo y gana 69 '
      'puntos sin gastar (aviso de puntos)', () {
    final build = _v5Build(69);
    expect(build, hasLength(69));
    final json = PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      level: 50,
      mastery: 20,
      tree: build,
    ).toJson()
      ..['tv'] = 5;
    final raw = PlayerProfile.fromJson(json);
    expect(raw.tree, build, reason: 'mismos ids: no hay reinicio');
    expect(raw.treeRefunded, 0);
    final p = progression.normalize(raw);
    expect(p.tree, build);
    expect(rules.pointsAvailable(p.treeLevel, p.passiveProgress), 69);
    final u = UnusedPoints.of(p, progression);
    expect(u.tree, 69);
    expect(u.toastText, contains('69 puntos de árbol sin usar'));
    // Y los puede gastar en el anillo exterior.
    final route = rules.pathTo('guerrero', p.passiveProgress, 'tempestad_n1');
    expect(route, isNotNull);
    expect(route!.length, lessThanOrEqualTo(69));
  });

  test('un perfil viejo de nivel 10 sin gastar ve el doble de puntos', () {
    final p = progression.normalize(PlayerProfile.fromJson({
      'name': 'Leo',
      'cls': 'tirador',
      'lvl': 10,
      'tv': 5,
      'tree': ['tir_r1', 'tir_f3'],
    }));
    expect(p.tree, ['tir_r1', 'tir_f3']);
    expect(rules.pointsAvailable(p.treeLevel, p.passiveProgress), 18 - 2);
  });
}
