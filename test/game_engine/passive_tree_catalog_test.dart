import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tree = kPassiveTree;

  test('40 nodos: 4 inicios + 4 clases × 2 ramas × 4 + 4 puentes', () {
    expect(tree.nodes, hasLength(40));
  });

  test('el inicio del guerrero conecta con sus dos ramas y dos puentes', () {
    expect(tree.nodes['s_gue']!.links.toSet(),
        {'gue_a0', 'gue_b0', 'b_ne', 'b_nw'});
  });

  test('las keystones son el final de cada rama', () {
    final furia = tree.nodes['gue_b3']!;
    expect(furia.kind, 'k');
    expect(furia.keystoneId, 'furia');
    expect(furia.links, ['gue_b2']);
  });

  test('posiciones iguales al prototipo', () {
    // gue_a0: r = 1.75, sp = 0.32, dir (0,-1), perp (1,0), signo +1
    final n = tree.nodes['gue_a0']!;
    expect(n.x, closeTo(0.32 * 1.75 * 0.55, 1e-9));
    expect(n.y, closeTo(-1.75, 1e-9));
  });

  test('Creyente e Inherente se excluyen', () {
    final rules = PassiveTreeRules(tree);
    const progress = PlayerPassiveProgress(
        ['pal_a0', 'pal_a1', 'pal_a2', 'pal_a3', 'pal_b0', 'pal_b1', 'pal_b2']);
    expect(rules.canTake('paladin', 20, progress, 'pal_b3'), isFalse);
  });
}
