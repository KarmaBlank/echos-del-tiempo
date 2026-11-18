import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/passive_tree_v2_catalog.dart';
import 'fixtures/passive_tree_v3_catalog.dart';
import 'fixtures/passive_tree_v5_catalog.dart';

// Chequeo de balance del árbol v4 contra el v2 de la v0.4 (y el v3 de la
// v0.5) con los mismos puntos (docs/specs/passive_tree_v3.md § 10 y
// passive_tree_v4.md § 5): más notables a elegir, no builds absurdamente
// más fuertes.

/// Puntos máximos del árbol v5: nivel 50 (49) + 20 de Maestría.
const _points = 69;

/// Puntos máximos del árbol v6 (v0.8): el doble.
const _pointsV6 = 138;

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
  final v4 = PassiveTreeRules(kPassiveTree);
  final v3 = PassiveTreeRules(kPassiveTreeV3);
  const classes = ['guerrero', 'maga', 'tirador', 'paladin'];

  // Especializarse rinde más que en la v2 (hay más nodos de cada stat),
  // pero con tope: ≤ 1.6× en un solo stat. La DEF se compara ya con su
  // tope de reducción (3% por punto, máx. 60%).
  test('69 puntos, un stat: la v4 no supera a la v2 en más de 60%', () {
    final over = <String>[];
    for (final cls in classes) {
      for (final k in ['hp', 'atk', 'mag', 'crit', 'spd', 'def', 'mp']) {
        double best(PassiveTreeRules r) {
          final b = _greedy(r, cls, _points, (m) => m[k]);
          expect(b.length, lessThanOrEqualTo(_points));
          final v = r.aggregate(cls, PlayerPassiveProgress(b))[k];
          return k == 'def' ? (v * 0.03).clamp(0.0, 0.6) : v;
        }

        final a = best(v2), b = best(v4);
        if (b > a * 1.6 + 1e-9) {
          over.add('$cls $k: v2 ${a.toStringAsFixed(2)} → v4 '
              '${b.toStringAsFixed(2)}');
        }
      }
    }
    expect(over, isEmpty);
  });

  test('69 puntos, build mixto de la clase: bono agregado ≤ 1.25 × v2', () {
    for (final cls in classes) {
      double total(PassiveTreeRules r) {
        final b = _greedy(r, cls, _points, _weighted);
        return _weighted(r.aggregate(cls, PlayerPassiveProgress(b)));
      }

      final a = total(v2), b = total(v4), c = total(v3);
      // Con menos relleno y chicos un poco más fuertes, la v4 no queda
      // por debajo de la v3 (hoy ≈ 0.87× de la v2; la v3 daba ≈ 0.78×).
      expect(b, greaterThanOrEqualTo(c), reason: '$cls vs v3');
      expect(b, lessThanOrEqualTo(a * 1.25),
          reason: '$cls: v2 ${a.toStringAsFixed(2)} → v4 ${b.toStringAsFixed(2)}');
      // Y tampoco es mucho más débil (el árbol nuevo no es un nerf).
      expect(b, greaterThanOrEqualTo(a * 0.7), reason: cls);
    }
  });

  test('build representativo: los 3 caminos v2 vs 3 clusters v4 de la clase',
      () {
    // Guerrero: Muralla + Sangre + Filo (v2) contra lo mismo en la v4
    // (ruta de clase + los 3 clusters completos).
    const v2Ids = ['1', '2', '3', 'n1', '4', '5', 'n2', 'k'];
    const v4Ids = ['n1', 'm1', 'm2', 'na', 'nb', 'ma', 'mb', 'nc', 'k'];
    final old = PlayerPassiveProgress([
      for (final p in ['muralla', 'sangre', 'filo'])
        for (final s in v2Ids) '${p}_$s',
    ]);
    final now = PlayerPassiveProgress([
      'gue_r1', 'gue_f3', 'gue_f2', 'gue_f1', 'gue_f4', 'gue_f5', //
      for (final p in ['muralla', 'sangre', 'filo'])
        for (final s in v4Ids) '${p}_$s',
    ]);
    expect(now.takenNodeIds.length, lessThanOrEqualTo(_points));
    final a = v2.aggregate('guerrero', old), b = v4.aggregate('guerrero', now);
    // Las mismas mecánicas de la v2 y 2 notables más por cluster.
    expect(b.mechanics, containsAll(a.mechanics));
    expect(b.mechanics.length, a.mechanics.length + 6);
    expect(b.keys, a.keys);
    // Cuesta más puntos (33 vs 24) y da un bono parecido.
    expect(_weighted(b), lessThanOrEqualTo(_weighted(a) * 1.25));
  });

  // ---- Árbol v6 (v0.8, passive_tree_v6.md § 7): el doble de puntos ----
  //
  // Topes: con 138 puntos el árbol v6 rinde más que el v5 con 69 (es el
  // pedido), pero acotado:
  // 1. Un stat: ≤ 1.35× el v5 (los nodos nuevos no dan stats: el techo
  //    es el mismo pozo de stats del v5). Medido: vida 1.21-1.30, ATQ
  //    1.15-1.19, el resto 1.00.
  // 2. Build mixto: entre 1.4× y 1.9× el v5 (medido 1.75×).
  // 3. Mecánicas por condición: lo que se puede juntar contra un mismo
  //    estado ≤ +80% de daño y ≤ +75% de crítico (medido: Cargado +69% /
  //    +66%, Mojado +44% / +68%, Sagrado +74% / +12%).
  test('138 puntos v6 contra 69 v5: un stat ≤ 1.35×', () {
    final v5 = PassiveTreeRules(kV5PassiveTree);
    final over = <String>[];
    for (final cls in classes) {
      for (final k in ['hp', 'atk', 'mag', 'crit', 'spd', 'def', 'mp']) {
        double best(PassiveTreeRules r, int pts) {
          final b = _greedy(r, cls, pts, (m) => m[k]);
          expect(b.length, lessThanOrEqualTo(pts));
          final v = r.aggregate(cls, PlayerPassiveProgress(b))[k];
          return k == 'def' ? (v * 0.03).clamp(0.0, 0.6) : v;
        }

        final a = best(v5, _points), b = best(v4, _pointsV6);
        expect(b, greaterThanOrEqualTo(a - 1e-9), reason: '$cls $k');
        if (b > a * 1.35 + 1e-9) {
          over.add('$cls $k: v5 ${a.toStringAsFixed(2)} → v6 '
              '${b.toStringAsFixed(2)}');
        }
      }
    }
    expect(over, isEmpty);
  });

  test('138 puntos v6 contra 69 v5: build mixto entre 1.4× y 1.9×', () {
    final v5 = PassiveTreeRules(kV5PassiveTree);
    for (final cls in classes) {
      double total(PassiveTreeRules r, int pts) {
        final b = _greedy(r, cls, pts, _weighted);
        return _weighted(r.aggregate(cls, PlayerPassiveProgress(b)));
      }

      final a = total(v5, _points), b = total(v4, _pointsV6);
      expect(b, inInclusiveRange(a * 1.4, a * 1.9),
          reason: '$cls: v5 ${a.toStringAsFixed(2)} → v6 '
              '${b.toStringAsFixed(2)}');
    }
  });

  test('138 puntos v6: lo que se junta contra un mismo estado tiene tope', () {
    double cond(TreeMods m, StatusKind st, BuffStat stat) {
      var t = 0.0;
      for (final id in m.mechanics) {
        final mm = kMechanics[id];
        if (mm == null) continue;
        final ok = (mm.trigger == ProcTrigger.always &&
                mm.filter == ProcFilter.any) ||
            (mm.trigger == ProcTrigger.vsStatus && mm.status == st);
        if (!ok) continue;
        for (final fx in mm.effects) {
          if (fx.kind == ProcEffectKind.statBonus && fx.stat == stat) {
            t += fx.value;
          }
        }
      }
      return t;
    }

    for (final st in StatusKind.values) {
      for (final (stat, cap) in [(BuffStat.damage, 0.80), (BuffStat.crit, 0.75)]) {
        final b = _greedy(v4, 'maga', _pointsV6, (m) => cond(m, st, stat));
        final v = cond(v4.aggregate('maga', PlayerPassiveProgress(b)), st, stat);
        expect(v, lessThanOrEqualTo(cap + 1e-9), reason: '${st.name} $stat');
      }
    }
  });

  test('el build v5 de 69 puntos sigue entero en el v6 y suma mecánicas', () {
    final v5 = PassiveTreeRules(kV5PassiveTree);
    for (final cls in classes) {
      final old = _greedy(v5, cls, _points, _weighted);
      // Mismos nodos, mismos stats: el v6 solo agrega.
      final a = v5.aggregate(cls, PlayerPassiveProgress(old));
      final b = v4.aggregate(cls, PlayerPassiveProgress(old));
      for (final k in _weights.keys) {
        expect(b[k], closeTo(a[k], 1e-9), reason: '$cls $k');
      }
      expect(b.mechanics, a.mechanics);
      // Con los 69 puntos nuevos se toma el v5 entero y además notables
      // del anillo exterior.
      for (var i = 0; i < old.length; i++) {
        expect(
            v4.canTake(cls, 1 << 20,
                PlayerPassiveProgress(old.sublist(0, i)), old[i]),
            isTrue,
            reason: '$cls ${old[i]}');
      }
      expect(v4.pointsAvailable(70, PlayerPassiveProgress(old)),
          _pointsV6 - old.length);
    }
  });
}
