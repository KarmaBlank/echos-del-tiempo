// Forma del árbol v7 (progression_v2.md § 11.1): al fusionar nodos de
// paso la figura debe seguir tan prolija como la del v6.
import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:flutter_test/flutter_test.dart';

typedef P = (double, double);
typedef Seg = (P, P);

/// Segmentos dibujados del árbol (cada arista, partida en su recorrido).
List<Seg> segments(PassiveTreeCatalog c) {
  final out = <Seg>[];
  for (final n in c.nodes.values) {
    for (final l in n.links) {
      if (n.id.compareTo(l) >= 0 || !c.nodes.containsKey(l)) continue;
      final pts = c.edgePoints(n.id, l);
      for (var i = 1; i < pts.length; i++) {
        out.add((pts[i - 1], pts[i]));
      }
    }
  }
  for (final segs in c.extraStrokes.values) {
    out.addAll(segs);
  }
  return out;
}

double ringRadius(PassiveTreeCatalog c) {
  final g = c.nodes['p_gue']!;
  return math.sqrt(g.x * g.x + g.y * g.y);
}

double _distToOrigin(Seg s) {
  final ((ax, ay), (bx, by)) = s;
  final dx = bx - ax, dy = by - ay;
  final l2 = dx * dx + dy * dy;
  final t = l2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / l2).clamp(0.0, 1.0);
  final px = ax + t * dx, py = ay + t * dy;
  return math.sqrt(px * px + py * py);
}

/// Segmentos que entran al disco central (más adentro que el 90 % del
/// radio del anillo: las cuerdas del propio anillo no cuentan).
int throughCenter(PassiveTreeCatalog c) {
  final r = ringRadius(c) * 0.9;
  return segments(c).where((s) => _distToOrigin(s) < r).length;
}

bool _same(P a, P b) =>
    (a.$1 - b.$1).abs() < 1e-6 && (a.$2 - b.$2).abs() < 1e-6;

/// Cruces propios (interiores) entre segmentos.
int crossings(PassiveTreeCatalog c) {
  final s = segments(c);
  double cross(P o, P a, P b) =>
      (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);
  const e = 1e-9;
  bool opp(double x, double y) => (x > e && y < -e) || (x < -e && y > e);
  var n = 0;
  for (var i = 0; i < s.length; i++) {
    for (var j = i + 1; j < s.length; j++) {
      final (a, b) = s[i];
      final (p, q) = s[j];
      if (_same(a, p) || _same(a, q) || _same(b, p) || _same(b, q)) continue;
      if (opp(cross(p, q, a), cross(p, q, b)) &&
          opp(cross(a, b, p), cross(a, b, q))) {
        n++;
      }
    }
  }
  return n;
}

/// Asimetría entre los 4 cuadrantes de clase: nodos y segmentos que, al
/// rotar la figura 90°, no caen sobre otro nodo / segmento (a 0.05).
int asymmetry(PassiveTreeCatalog c, {bool nodesToo = true}) {
  String k(P p) =>
      '${(p.$1 * 20).round()},${(p.$2 * 20).round()}'.replaceAll('-0', '0');
  String seg(P a, P b) {
    final x = k(a), y = k(b);
    return x.compareTo(y) < 0 ? '$x/$y' : '$y/$x';
  }

  P rot(P p) => (-p.$2, p.$1);
  final nodes = {for (final n in c.nodes.values) k((n.x, n.y))};
  final segs = {for (final s in segments(c)) seg(s.$1, s.$2)};
  var bad = 0;
  for (final n in nodesToo ? c.nodes.values : const <PassiveNode>[]) {
    if (!nodes.contains(k(rot((n.x, n.y))))) bad++;
  }
  for (final s in segments(c)) {
    if (!segs.contains(seg(rot(s.$1), rot(s.$2)))) bad++;
  }
  return bad;
}

/// El v7 como se dibujaba en v0.10.0 (posición v6 del id que sobrevivía,
/// aristas rectas), para comparar.
PassiveTreeCatalog v7Before() => PassiveTreeCatalog(
      nodes: {
        for (final n in kPassiveTree.nodes.values)
          n.id: PassiveNode(
            id: n.id,
            x: kPassiveTreeV6.nodes[n.id]!.x,
            y: kPassiveTreeV6.nodes[n.id]!.y,
            name: n.name,
            effects: n.effects,
            kind: n.kind,
            links: n.links,
            keystoneId: n.keystoneId,
            pathId: n.pathId,
            mechanicId: n.mechanicId,
            isDouble: n.isDouble,
            isMinor: n.isMinor,
          ),
      },
      startNodeByClass: kPassiveTree.startNodeByClass,
      exclusions: kPassiveTree.exclusions,
      paths: kPassiveTree.paths,
    );

void main() {
  final v6 = kPassiveTreeV6, v7 = kPassiveTree;

  test('medición v6 / v7 antes / v7 ahora', () {
    final before = v7Before();
    // ignore: avoid_print
    print('centro v6=${throughCenter(v6)} antes=${throughCenter(before)} '
        'ahora=${throughCenter(v7)}; cruces v6=${crossings(v6)} '
        'antes=${crossings(before)} ahora=${crossings(v7)}; asimetría '
        'v6=${asymmetry(v6)} antes=${asymmetry(before)} '
        'ahora=${asymmetry(v7)}; líneas v6=${asymmetry(v6, nodesToo: false)} '
        'ahora=${asymmetry(v7, nodesToo: false)}');
  });

  test('ninguna arista nueva atraviesa el anillo central', () {
    expect(throughCenter(v7), lessThanOrEqualTo(throughCenter(v6)));
  });

  test('no hay más cruces de aristas que en el v6', () {
    expect(crossings(v7), lessThanOrEqualTo(crossings(v6)));
  });

  test('las 4 clases son simétricas (rotación de 90°)', () {
    // Las líneas: igual de simétricas que en el v6 (los mismos trazos).
    expect(asymmetry(v7, nodesToo: false),
        lessThanOrEqualTo(asymmetry(v6, nodesToo: false)));
    // Los puntos: solo difieren los nodos que la fusión saca en un
    // cuadrante y no en otro (lo decide el emparejamiento por id).
    expect(asymmetry(v7), lessThan(asymmetry(v7Before())));
  });

  test('cada recorrido pasa solo por puntos del v6', () {
    final pts = {for (final n in v6.nodes.values) (n.x, n.y)};
    for (final w in v7.edgeRoutes.values) {
      for (final p in w) {
        expect(pts.contains(p), isTrue, reason: '$p');
      }
    }
  });
}
