// ignore_for_file: avoid_print
// Medición temporal para docs/specs/progression_v2.md. No es un test real.
// flutter test tool/progression_v2_measure_test.dart
import 'dart:collection';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('medir', () {
    final t = kPassiveTree;
    final kinds = <String, int>{};
    for (final n in t.nodes.values) {
      kinds[n.kind] = (kinds[n.kind] ?? 0) + 1;
    }
    print('kinds $kinds total ${t.nodes.length}');
    // pares chico-chico enlazados
    // Dijkstra: costo actual = 1 por nodo; costo v2 = 0.5 por chico, 1 resto.
    Map<String, (int, double, int)> sp(String start) {
      final dist = <String, double>{start: 0};
      final cnt = <String, int>{start: 0};
      final sm = <String, int>{start: 0};
      final q = SplayTreeSet<(double, String)>((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      })..add((0, start));
      while (q.isNotEmpty) {
        final (d, id) = q.first;
        q.remove(q.first);
        for (final l in t.nodes[id]!.links) {
          final n = t.nodes[l]!;
          final w = n.kind == 's' ? 0.5 : 1.0;
          final nd = d + w;
          if (nd < (dist[l] ?? 1e9)) {
            if (dist[l] != null) q.remove((dist[l]!, l));
            dist[l] = nd;
            cnt[l] = cnt[id]! + 1;
            sm[l] = sm[id]! + (n.kind == 's' ? 1 : 0);
            q.add((nd, l));
          }
        }
      }
      return {for (final k in dist.keys) k: (cnt[k]!, dist[k]!, sm[k]!)};
    }

    // BFS de cantidad de nodos (hoy)
    Map<String, int> bfs(String start) {
      final d = <String, int>{start: 0};
      final q = Queue<String>()..add(start);
      while (q.isNotEmpty) {
        final id = q.removeFirst();
        for (final l in t.nodes[id]!.links) {
          if (!d.containsKey(l)) {
            d[l] = d[id]! + 1;
            q.add(l);
          }
        }
      }
      return d;
    }

    // vecinos chicos de cada nodo (para ver si los chicos vienen de a pares)
    var smallRuns = <int, int>{};
    for (final n in t.nodes.values.where((n) => n.kind == 's')) {
      final sn = n.links.where((l) => t.nodes[l]!.kind == 's').length;
      smallRuns[sn] = (smallRuns[sn] ?? 0) + 1;
    }
    print('chicos por cantidad de vecinos chicos: $smallRuns');

    t.startNodeByClass.forEach((cls, st) {
      final b = bfs(st);
      final s = sp(st);
      final ks = t.nodes.values.where((n) => n.kind == 'k').toList()
        ..sort((a, c) => b[a.id]!.compareTo(b[c.id]!));
      final ns = t.nodes.values.where((n) => n.kind == 'n').map((n) => b[n.id]!).toList()..sort();
      print('== $cls start=$st notable más cerca ${ns.first}, notables<=10: ${ns.where((x) => x <= 10).length}, <=20: ${ns.where((x) => x <= 20).length}');
      for (final k in ks.take(12)) {
        final v = s[k.id]!;
        print('  ${k.id} (${k.pathId}) hoy=${b[k.id]} v2w=${v.$2} (nodos ${v.$1} chicos ${v.$3})');
      }
    });

    final maxReq = <Attribute, int>{};
    for (final w in kWeapons.values) {
      w.requirements.forEach((a, v) {
        if (v > (maxReq[a] ?? 0)) maxReq[a] = v;
      });
    }
    print('max req $maxReq');
    for (final w in kWeapons.values.where((w) => w.level >= 40)) {
      print('  ${w.id} L${w.level} ${w.requirements} atk ${w.atk.coefficients} mag ${w.mag?.coefficients}');
    }
  });
}
