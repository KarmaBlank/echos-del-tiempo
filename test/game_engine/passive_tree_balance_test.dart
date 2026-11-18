import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/passive_tree_v2_catalog.dart';

// Chequeo de balance del árbol v3 contra el v2 de la v0.4 con los mismos
// puntos (docs/specs/passive_tree_v3.md § 10): el árbol más grande da más
// opciones, no builds absurdamente más fuertes.

/// Puntos máximos: nivel 50 (49) + 20 de Maestría.
const _points = 69;

/// Peso de cada stat para el "bono agregado" de un build (≈ cuánto vale
/// un +1 de ese stat comparado con +100% de ATQ).
const _weights = {
  'hp': 1.0, 'mp': 0.5, 'atk': 1.0, 'mag': 1.0, 'crit': 2.0, //
  'spd': 0.1, 'def': 0.03, 'ult': 0.5, 'heal': 0.5,
  'burn': 0.05, 'poi': 0.05, 'frz': 0.05,
};

/// Build codicioso con [points] puntos que maximiza `score` por punto:
/// en cada paso, el camino más corto (desde lo tomado) con mejor
/// ganancia por punto.
List<String> _greedy(PassiveTreeRules rules, String cls, int points,
    double Function(TreeMods) score) {
  final tree = rules.catalog;
  final start = tree.startNodeByClass[cls]!;
  // Lo que da cada nodo solo (con las contras fijas de su keystone).
  final base = rules.aggregate(cls, PlayerPassiveProgress.empty);
  final value = {
    for (final id in tree.nodes.keys)
      id: score(rules.aggregate(cls, PlayerPassiveProgress([id]))) - score(base),
  };
  final taken = <String>[];
  final have = {start};
  while (taken.length < points) {
    // BFS desde todo lo tomado.
    final prev = <String, String?>{for (final h in have) h: null};
    var frontier = [...have];
    while (frontier.isNotEmpty) {
      final next = <String>[];
      for (final id in frontier) {
        for (final l in tree.nodes[id]!.links) {
          if (prev.containsKey(l)) continue;
          final ex = tree.exclusions[l];
          if (ex != null && have.contains(ex)) continue;
          prev[l] = id;
          next.add(l);
        }
      }
      frontier = next;
    }
    List<String>? best;
    var bestRate = 0.0;
    for (final id in prev.keys) {
      if (have.contains(id)) continue;
      final path = <String>[];
      String? at = id;
      while (at != null && !have.contains(at)) {
        path.add(at);
        at = prev[at];
      }
      if (path.length > points - taken.length) continue;
      var gain = 0.0;
      for (final p in path) {
        gain += value[p]!;
      }
      final rate = gain / path.length;
      if (rate > bestRate + 1e-12) {
        bestRate = rate;
        best = path.reversed.toList();
      }
    }
    if (best == null) break;
    taken.addAll(best);
    have.addAll(best);
  }
  return taken;
}


double _weighted(TreeMods m) {
  var t = 0.0;
  _weights.forEach((k, w) => t += m[k] * w);
  return t;
}

void main() {
  final v2 = PassiveTreeRules(kPassiveTreeV2);
  final v3 = PassiveTreeRules(kPassiveTree);
  const classes = ['guerrero', 'maga', 'tirador', 'paladin'];

  // Especializarse rinde más que en la v2 (hay más nodos de cada stat),
  // pero con tope: ≤ 1.6× en un solo stat. La DEF se compara ya con su
  // tope de reducción (3% por punto, máx. 60%).
  test('69 puntos, un stat: la v3 no supera a la v2 en más de 60%', () {
    for (final cls in classes) {
      for (final k in ['hp', 'atk', 'mag', 'crit', 'spd', 'def', 'mp']) {
        double best(PassiveTreeRules r) {
          final b = _greedy(r, cls, _points, (m) => m[k]);
          expect(b.length, lessThanOrEqualTo(_points));
          final v = r.aggregate(cls, PlayerPassiveProgress(b))[k];
          return k == 'def' ? (v * 0.03).clamp(0.0, 0.6) : v;
        }

        final a = best(v2), b = best(v3);
        expect(b, lessThanOrEqualTo(a * 1.6 + 1e-9),
            reason: '$cls $k: v2 ${a.toStringAsFixed(2)} → v3 '
                '${b.toStringAsFixed(2)}');
      }
    }
  });

  test('69 puntos, build mixto de la clase: bono agregado ≤ 1.25 × v2', () {
    for (final cls in classes) {
      double total(PassiveTreeRules r) {
        final b = _greedy(r, cls, _points, _weighted);
        return _weighted(r.aggregate(cls, PlayerPassiveProgress(b)));
      }

      final a = total(v2), b = total(v3);
      expect(b, lessThanOrEqualTo(a * 1.25),
          reason: '$cls: v2 ${a.toStringAsFixed(2)} → v3 ${b.toStringAsFixed(2)}');
      // Y tampoco es mucho más débil (el árbol nuevo no es un nerf).
      expect(b, greaterThanOrEqualTo(a * 0.7), reason: cls);
    }
  });

  test('build representativo: los 3 caminos v2 vs 3 clusters v3 de la clase',
      () {
    // Guerrero: Muralla + Sangre + Filo (v2) contra lo mismo en la v3
    // (ruta de clase + los 3 clusters completos).
    const v2Ids = ['1', '2', '3', 'n1', '4', '5', 'n2', 'k'];
    const v3Ids = ['e1', 'e2', 'f', 'a1', 'a2', 'na', 'b1', 'b2', 'nb', 'j', 'k'];
    final old = PlayerPassiveProgress([
      for (final p in ['muralla', 'sangre', 'filo'])
        for (final s in v2Ids) '${p}_$s',
    ]);
    final now = PlayerPassiveProgress([
      'gue_r1', 'gue_r2', 'gue_f3', 'gue_f2', 'gue_f1', 'gue_f4', 'gue_f5', //
      for (final p in ['muralla', 'sangre', 'filo'])
        for (final s in v3Ids) '${p}_$s',
    ]);
    expect(now.takenNodeIds.length, lessThanOrEqualTo(_points));
    final a = v2.aggregate('guerrero', old), b = v3.aggregate('guerrero', now);
    expect(b.mechanics, a.mechanics, reason: 'mismas mecánicas');
    expect(b.keys, a.keys);
    // Cuesta más puntos (40 vs 24) y da un bono parecido.
    expect(_weighted(b), lessThanOrEqualTo(_weighted(a) * 1.25));
  });
}
