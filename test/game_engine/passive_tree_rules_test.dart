import 'package:flutter_test/flutter_test.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';

void main() {
  // Árbol mínimo: inicio -> a0 -> a1(keystone) para una sola clase,
  // suficiente para probar las reglas sin cargar el árbol completo.
  final catalog = PassiveTreeCatalog(
    nodes: {
      's_gue': const PassiveNode(
        id: 's_gue', x: 0, y: -1.1, name: 'Inicio', kind: 'st',
        effects: {'hp': 0.05, 'atk': 0.04}, links: ['gue_a0'],
      ),
      'gue_a0': const PassiveNode(
        id: 'gue_a0', x: 0, y: -1.75, name: 'Fuerza', kind: 's',
        effects: {'atk': 0.08}, links: ['s_gue', 'gue_a1'],
      ),
      'gue_a1': const PassiveNode(
        id: 'gue_a1', x: 0, y: -2.3, name: 'Furia de Sangre', kind: 'k',
        effects: {'key': 1}, keystoneId: 'furia', links: ['gue_a0'],
      ),
    },
    startNodeByClass: const {'guerrero': 's_gue'},
    exclusions: const {},
  );
  final rules = PassiveTreeRules(catalog);

  test('el nodo de inicio siempre cuenta como tomado', () {
    expect(rules.hasNode('guerrero', PlayerPassiveProgress.empty, 's_gue'), isTrue);
  });

  test('no se puede tomar un nodo sin conexión a uno ya tomado', () {
    expect(
      rules.canTake('guerrero', 5, PlayerPassiveProgress.empty, 'gue_a1'),
      isFalse,
      reason: 'gue_a1 solo conecta con gue_a0, que todavía no se tomó',
    );
  });

  test('se puede tomar un nodo conectado al inicio si hay puntos', () {
    expect(rules.canTake('guerrero', 5, PlayerPassiveProgress.empty, 'gue_a0'), isTrue);
  });

  test('sin puntos disponibles no se puede tomar nada', () {
    final progress = PlayerPassiveProgress(List.generate(4, (i) => 'gue_a0'));
    // nivel 5 -> 4 puntos disponibles (lvl-1); si ya "gastó" 4, quedan 0
    expect(rules.pointsAvailable(5, progress), 0);
  });

  test('la keystone furia aplica su trade-off (+atk, -def)', () {
    final progress = const PlayerPassiveProgress(['gue_a0', 'gue_a1']);
    final mods = rules.aggregate('guerrero', progress);
    expect(mods.hasKey('furia'), isTrue);
    expect(mods['def'], -4);
    // 0 (base) + 0.35 (trade-off) = 0.35, sin contar el +0.04 del inicio
    expect(mods['atk'], closeTo(0.04 + 0.35, 1e-9));
  });
}
