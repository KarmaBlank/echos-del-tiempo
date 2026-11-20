import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Quitar un nodo del árbol (progression_v2.md § 6.1).

PlayerProfile _fresh(String cls, int level) =>
    zoneProgression.resetBuild(zoneProgression.normalize(PlayerProfile(
        name: 'Ana', classId: cls, level: level, inventory: const [])));

void main() {
  final rules = PassiveTreeRules(kPassiveTree);

  List<String> pathTo(PlayerProfile p, String k) =>
      rules.pathTo(p.classId, p.passiveProgress, k)!;

  test('quitar una hoja reembolsa 1 punto', () {
    final p = _fresh('guerrero', 5);
    final path = pathTo(p, rules.milestoneOptions('guerrero', 10).first);
    final q = zoneProgression.takeNodes(p, path.take(3).toList())!.$1;
    final free = q.treePoints - q.tree.length;
    final r = zoneProgression.untakeNode(q, path[2])!;
    expect(r.tree, path.take(2));
    expect(r.treePoints - r.tree.length, free + 1);
  });

  test('quitar un nodo intermedio está bloqueado', () {
    final p = _fresh('guerrero', 5);
    final path = pathTo(p, rules.milestoneOptions('guerrero', 10).first);
    final q = zoneProgression.takeNodes(p, path.take(3).toList())!.$1;
    expect(zoneProgression.untakeReason(q, path[1]),
        'Otros nodos dependen de este');
    expect(zoneProgression.untakeNode(q, path[1]), isNull);
    expect(zoneProgression.untakeReason(q, 'nada'), 'No está tomado');
  });

  test('quitar un nodo del camino del hito devuelve el punto al pool', () {
    final p = _fresh('maga', 10);
    final k = rules.milestoneOptions('maga', 10)[1];
    final q = zoneProgression.chooseMilestone(p, 10, k)!;
    // La keystone es la punta del camino; el anterior depende de ella
    // solo si no hay otra salida: se quita primero la keystone.
    expect(zoneProgression.untakeReason(q, q.tree.first),
        'Otros nodos dependen de este');
    final free = q.treePoints - q.tree.length;
    final r = zoneProgression.untakeNode(q, k)!;
    expect(r.milestone10, isNull, reason: 'el hito queda pendiente');
    expect(r.pendingMilestones, [10]);
    expect(r.tree, q.tree.take(6));
    // Sin el hito se pierden sus 7 puntos y vuelve 1: nada se duplica.
    expect(r.treePoints - r.tree.length, free - 7 + 1);
    // Volver a elegir el hito completa el camino con sus puntos.
    final again = zoneProgression.chooseMilestone(r, 10, k)!;
    expect(again.tree.toSet(), q.tree.toSet());
    expect(again.treePoints - again.tree.length, free);
  });

  test('quitar la keystone del hito se bloquea si sus puntos están en uso',
      () {
    final p = _fresh('maga', 10);
    final k = rules.milestoneOptions('maga', 10)[1];
    var q = zoneProgression.chooseMilestone(p, 10, k)!;
    // Gasta todos los puntos libres en otros nodos.
    for (var more = true; more;) {
      more = false;
      for (final id in kPassiveTree.nodes.keys) {
        final t = zoneProgression.takeNode(q, id);
        if (t != null) {
          q = t;
          more = true;
          break;
        }
      }
    }
    expect(q.treePoints - q.tree.length, 0, reason: 'sin puntos libres');
    expect(zoneProgression.untakeReason(q, k), contains('puntos del hito'));
  });

  test('el host valida y rechaza quitar inválido', () {
    final e = sessionEngine();
    var p = _fresh('guerrero', 5);
    final path = pathTo(p, rules.milestoneOptions('guerrero', 10).first);
    p = zoneProgression.takeNodes(p, path.take(3).toList())!.$1;
    final s = e.addPlayer(e.create(), 'a', p)!.state;
    expect(e.apply(s, 'a', UntakeNodeAction(path[1])), isNull);
    expect(e.apply(s, 'a', const UntakeNodeAction('nada')), isNull);
    final ok = e.apply(s, 'a', UntakeNodeAction(path[2]))!;
    expect(ok.state.players['a']!.profile.tree, path.take(2));
  });

  test('serialización de UntakeNodeAction', () {
    const a = UntakeNodeAction('g1');
    final j = ActionJson.toJson(a);
    expect(j, {'t': 'untake', 'id': 'g1'});
    final b = ActionJson.fromJson(j) as UntakeNodeAction;
    expect(b.nodeId, 'g1');
    expect(PlayerPassiveProgress.empty.takenNodeIds, isEmpty);
  });
}
