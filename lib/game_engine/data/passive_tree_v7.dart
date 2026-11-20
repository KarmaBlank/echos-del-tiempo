import 'dart:math' as math;

import '../models/passive_mechanic.dart';
import '../models/passive_tree.dart';
import 'passive_tree_v6.dart';

/// Árbol v7 (progresión v2, docs/specs/progression_v2.md § 3): el árbol
/// v6 con los nodos de paso fusionados. Se arma desde el v6 con reglas
/// determinísticas:
///
/// 1. Pares de chicos seguidos → un chico doble con el id del primero
///    (el más cercano a un inicio), la suma de efectos y las dos
///    mecánicas.
/// 2. Chicos sueltos (sin chicos vecinos): el más cercano a la keystone
///    en cada cluster de clase y el de eje (`_i1`) de cada puente
///    elemental se promueven a notable menor (efecto × 2: números
///    dobles y la mecánica repetida con id `<id>_x2`). El cluster
///    Invocador no promueve (sus mecánicas se suman por id).
/// 3. El resto de los sueltos los absorbe el notable vecino.
class TreeV7 {
  TreeV7(this.catalog, this.merged, this.promoted, this.extraMechanics);

  final PassiveTreeCatalog catalog;

  /// Id v6 que dejó de existir → id v7 que lo contiene.
  final Map<String, String> merged;

  /// Ids promovidos a notable menor.
  final Set<String> promoted;

  /// Copias `_x2` de las mecánicas de los notables menores.
  final List<PassiveMechanic> extraMechanics;
}

class _N {
  _N(PassiveNode n)
      : id = n.id,
        x = n.x,
        y = n.y,
        name = n.name,
        fx = {...n.effects},
        kind = n.kind,
        key = n.keystoneId,
        path = n.pathId,
        mech = n.mechanicId,
        links = {...n.links};
  final String id;
  double x, y;
  final String name;
  final Map<String, num> fx;
  String kind;
  final String? key, path, mech;
  final Set<String> links;
  final extra = <String>[];
  final mergedIds = <String>[];
  var isDouble = false, isMinor = false;

  void absorb(_N o) {
    o.fx.forEach((k, v) => fx[k] = (fx[k] ?? 0) + v);
    if (o.mech != null) extra.add(o.mech!);
    extra.addAll(o.extra);
    mergedIds
      ..add(o.id)
      ..addAll(o.mergedIds);
  }

  PassiveNode freeze() => PassiveNode(
        id: id,
        x: x,
        y: y,
        name: name,
        effects: Map.unmodifiable(fx),
        kind: kind,
        links: List.unmodifiable(links.toList()..sort()),
        keystoneId: key,
        pathId: path,
        mechanicId: mech,
        extraMechanicIds: List.unmodifiable(extra),
        mergedIds: List.unmodifiable(mergedIds),
        isDouble: isDouble,
        isMinor: isMinor,
      );
}

TreeV7 buildTreeV7(PassiveTreeCatalog v6,
    PassiveMechanic? Function(String id) mechanicOf) {
  final nodes = {for (final n in v6.nodes.values) n.id: _N(n)};
  bool small(String id) => v6.nodes[id]!.kind == 's';

  // Distancia (en nodos) al inicio más cercano, en el v6.
  final dist = <String, int>{};
  var frontier = [...v6.startNodeByClass.values];
  for (final s in frontier) {
    dist[s] = 0;
  }
  while (frontier.isNotEmpty) {
    final next = <String>[];
    for (final id in frontier) {
      for (final l in v6.nodes[id]!.links) {
        if (dist.containsKey(l)) continue;
        dist[l] = dist[id]! + 1;
        next.add(l);
      }
    }
    frontier = next;
  }
  int d(String id) => dist[id] ?? 1 << 20;
  int byDist(String a, String b) {
    final c = d(a).compareTo(d(b));
    return c != 0 ? c : a.compareTo(b);
  }

  final merged = <String, String>{};
  void contract(String keep, String gone) {
    final k = nodes[keep]!, g = nodes.remove(gone)!;
    k.absorb(g);
    for (final l in g.links) {
      if (l == keep) continue;
      k.links.add(l);
      nodes[l]!.links
        ..remove(gone)
        ..add(keep);
    }
    k.links.remove(gone);
    merged[gone] = keep;
  }

  // 1. Pares.
  final sueltos = <String>[];
  final smalls = [for (final n in v6.nodes.values) if (n.kind == 's') n.id]
    ..sort(byDist);
  final matched = <String>{};
  for (final a in smalls) {
    final sn = v6.nodes[a]!.links.where(small).toList();
    if (sn.isEmpty) {
      sueltos.add(a);
      continue;
    }
    if (matched.contains(a)) continue;
    final free = sn.where((b) => !matched.contains(b)).toList()
      ..sort((x, y) {
        // Primero el que sigue el tallo (más lejos del inicio).
        final fx = d(x) > d(a) ? 0 : 1, fy = d(y) > d(a) ? 0 : 1;
        return fx != fy ? fx - fy : byDist(x, y);
      });
    if (free.isEmpty) continue;
    final b = free.first;
    matched
      ..add(a)
      ..add(b);
    contract(a, b);
    // El doble queda en el punto v6 del que sobrevive; sus aristas pasan
    // por el punto del absorbido (§ 4 abajo, progression_v2.md § 11.1).
    nodes[a]!.isDouble = true;
  }

  // 2. Promociones.
  final promoted = <String>{};
  final byPath = <String, List<String>>{};
  for (final s in sueltos) {
    final p = v6.nodes[s]!.pathId;
    if (p != null) (byPath[p] ??= []).add(s);
  }
  int distTo(String from, String to) {
    final seen = {from: 0};
    var f = [from];
    while (f.isNotEmpty) {
      final n = <String>[];
      for (final id in f) {
        if (id == to) return seen[id]!;
        for (final l in v6.nodes[id]!.links) {
          if (seen.containsKey(l)) continue;
          seen[l] = seen[id]! + 1;
          n.add(l);
        }
      }
      f = n;
    }
    return 1 << 20;
  }

  byPath.forEach((pid, list) {
    final path = v6.paths[pid];
    if (path == null || pid == 'invocador') return;
    if (path.kind == 'clase') {
      final ks = v6.nodes.values
          .where((n) => n.kind == 'k' && n.pathId == pid)
          .map((n) => n.id)
          .toList();
      if (ks.isEmpty) return;
      final best = [...list]..sort((a, b) {
          final c = distTo(a, ks.first).compareTo(distTo(b, ks.first));
          return c != 0 ? c : a.compareTo(b);
        });
      promoted.add(best.first);
    } else if (path.kind == 'puente') {
      for (final s in list) {
        if (s.endsWith('_i1')) promoted.add(s);
      }
    }
  });
  final extraMechanics = <PassiveMechanic>[];
  for (final id in promoted) {
    final n = nodes[id]!
      ..kind = 'n'
      ..isMinor = true;
    n.fx.updateAll((k, v) => v * 2);
    if (n.mech case final m?) {
      final def = mechanicOf(m);
      if (def != null) {
        extraMechanics.add(_double(def, '${m}_x2'));
        n.extra.add('${m}_x2');
      }
    }
  }

  // 3. Absorción del resto en el notable vecino.
  for (final s in sueltos) {
    if (promoted.contains(s)) continue;
    final me = v6.nodes[s]!;
    final cand = me.links
        .where((l) => v6.nodes[l]!.kind == 'n' && !promoted.contains(l))
        .toList();
    final same = cand.where((l) => v6.nodes[l]!.pathId == me.pathId).toList();
    final pool = same.isNotEmpty ? same : cand;
    if (pool.isEmpty) continue;
    pool.sort((a, b) => -byDist(a, b));
    contract(pool.first, s);
  }

  // 4. Recorridos: cada arista v7 se dibuja por los puntos v6 de la
  //    arista original que la generó (la más corta si hay varias), así
  //    la figura no gana diagonales ni cruces (progression_v2.md § 11).
  String owner(String id) {
    var o = id;
    while (merged.containsKey(o)) {
      o = merged[o]!;
    }
    return o;
  }

  final routes = <String, List<(double, double)>>{};
  final routeLen = <String, double>{};
  for (final p in v6.nodes.values) {
    for (final qId in p.links) {
      final q = v6.nodes[qId]!;
      final u = owner(p.id), v = owner(qId);
      if (u == v || u.compareTo(v) > 0) continue;
      final a = nodes[u]!, b = nodes[v]!;
      final pts = <(double, double)>[(a.x, a.y)];
      for (final w in [(p.x, p.y), (q.x, q.y), (b.x, b.y)]) {
        if (w != pts.last) pts.add(w);
      }
      var len = 0.0;
      for (var i = 1; i < pts.length; i++) {
        final dx = pts[i].$1 - pts[i - 1].$1, dy = pts[i].$2 - pts[i - 1].$2;
        len += math.sqrt(dx * dx + dy * dy);
      }
      final key = '$u|$v';
      if (routeLen[key] case final l? when l <= len) continue;
      routeLen[key] = len;
      routes[key] = pts.sublist(1, pts.length - 1);
    }
  }
  // Tramos v6 que ningún recorrido dibuja (dentro de un nodo fusionado,
  // o de la arista v6 que no se eligió): quedan como trazo fijo del
  // nodo o arista dueño, para no dejar huecos en la figura.
  String pk((double, double) a, (double, double) b) =>
      a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 < b.$2) ? '$a$b' : '$b$a';
  final drawn = <String>{};
  routes.forEach((key, mid) {
    final [u, v] = key.split('|');
    final pts = [(nodes[u]!.x, nodes[u]!.y), ...mid, (nodes[v]!.x, nodes[v]!.y)];
    for (var i = 1; i < pts.length; i++) {
      drawn.add(pk(pts[i - 1], pts[i]));
    }
  });
  for (final n in nodes.values) {
    for (final l in n.links) {
      drawn.add(pk((n.x, n.y), (nodes[l]!.x, nodes[l]!.y)));
    }
  }
  final strokes = <String, List<((double, double), (double, double))>>{};
  for (final p in v6.nodes.values) {
    for (final qId in p.links) {
      if (p.id.compareTo(qId) >= 0) continue;
      final q = v6.nodes[qId]!;
      if (!drawn.add(pk((p.x, p.y), (q.x, q.y)))) continue;
      final u = owner(p.id), v = owner(qId);
      final key = u == v ? u : (u.compareTo(v) < 0 ? '$u|$v' : '$v|$u');
      (strokes[key] ??= []).add(((p.x, p.y), (q.x, q.y)));
    }
  }
  routes.removeWhere((_, w) => w.isEmpty);

  return TreeV7(
    PassiveTreeCatalog(
      nodes: {for (final n in nodes.values) n.id: n.freeze()},
      startNodeByClass: v6.startNodeByClass,
      exclusions: v6.exclusions,
      paths: v6.paths,
      edgeRoutes: Map.unmodifiable(routes),
      extraStrokes: Map.unmodifiable(strokes),
    ),
    Map.unmodifiable(merged),
    Set.unmodifiable(promoted),
    List.unmodifiable(extraMechanics),
  );
}

/// Mecánicas v6 de chicos por id (para copiar las de los notables
/// menores).
PassiveMechanic? v6SmallMechanic(String id) {
  for (final m in kTreeV6SmallMechanics) {
    if (m.id == id) return m;
  }
  return null;
}

/// La copia del × 2 de un notable menor. Crítico contra un estado pasa a
/// quiebre contra ese estado (progression_v2.md § 3.4: tres menores de
/// crítico contra Mojado empujaban la condición a +80%, arriba del tope
/// de +75%).
PassiveMechanic _double(PassiveMechanic m, String id) {
  final critVs = m.trigger == ProcTrigger.vsStatus &&
      m.effects.every((e) =>
          e.kind == ProcEffectKind.statBonus && e.stat == BuffStat.crit);
  if (!critVs) return m.withId(id);
  final v = m.effects.first.value;
  return PassiveMechanic(
    id: id,
    name: m.name,
    trigger: m.trigger,
    status: m.status,
    effects: [ProcEffect(ProcEffectKind.breakBonus, value: v)],
    description: 'Contra ${m.description.split('contra ').last.replaceAll('.', '')} tus '
        'golpes llenan la barra de quiebre un ${(v * 100).round()}% más.',
  );
}
