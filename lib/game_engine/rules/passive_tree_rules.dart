import '../models/passive_tree.dart';

/// Reglas puras del árbol de pasivas — puerto 1:1 de `treeHas` / `treeCan`
/// / `treePts` / `treeMods` del prototipo HTML. Sin Flutter, sin red:
/// 100% testeable con `dart test` solo.
class PassiveTreeRules {
  final PassiveTreeCatalog catalog;
  const PassiveTreeRules(this.catalog);

  bool hasNode(String classId, PlayerPassiveProgress progress, String nodeId) {
    return nodeId == catalog.startNodeByClass[classId] ||
        progress.takenNodeIds.contains(nodeId);
  }

  /// Puntos de árbol disponibles: 1 por nivel ganado después del 1,
  /// menos los ya gastados.
  int pointsAvailable(int level, PlayerPassiveProgress progress) {
    final spent = progress.takenNodeIds.length;
    return (level - 1 - spent).clamp(0, 1 << 30);
  }

  bool canTake(
    String classId,
    int level,
    PlayerPassiveProgress progress,
    String nodeId,
  ) {
    final node = catalog.nodes[nodeId];
    if (node == null) return false;
    if (hasNode(classId, progress, nodeId)) return false;
    if (pointsAvailable(level, progress) <= 0) return false;

    final excluded = catalog.exclusions[nodeId];
    if (excluded != null && hasNode(classId, progress, excluded)) return false;

    return node.links.any((l) => hasNode(classId, progress, l));
  }

  /// Agrega los efectos de todos los nodos tomados (+ el nodo de inicio).
  /// Replica `treeMods` del prototipo, incluidas las keystones con
  /// trade-offs (furia, mente, halcón, toxicidad).
  TreeMods aggregate(String classId, PlayerPassiveProgress progress) {
    final startId = catalog.startNodeByClass[classId];
    final ids = [if (startId != null) startId, ...progress.takenNodeIds];

    final m = TreeMods.zero();
    final keys = <String>{};

    for (final id in ids) {
      final node = catalog.nodes[id];
      if (node == null) continue;
      node.effects.forEach((k, v) {
        if (k == 'key' && node.keystoneId != null) {
          keys.add(node.keystoneId!);
        } else {
          m.add(k, v.toDouble());
        }
      });
    }

    if (keys.contains('furia')) {
      m.add('atk', 0.35);
      m.add('def', -4);
    }
    if (keys.contains('mente')) {
      m.add('mag', 0.30);
      m.add('hp', -0.20);
    }
    if (keys.contains('halcon')) {
      m.add('atk', -0.15);
    }
    if (keys.contains('toxicidad')) {
      m.add('poi', 2);
      m.add('atk', -0.10);
    }

    return m.withKeys(keys);
  }
}

/// Resultado agregado de `treeMods`: igual forma que en el prototipo JS.
class TreeMods {
  final Map<String, double> _values;
  final Set<String> keys;

  TreeMods._(this._values, this.keys);

  factory TreeMods.zero() => TreeMods._({
        'hp': 0, 'mp': 0, 'atk': 0, 'mag': 0, 'crit': 0, 'spd': 0,
        'def': 0, 'ult': 0, 'heal': 0, 'burn': 0, 'poi': 0, 'frz': 0,
      }, {});

  double operator [](String k) => _values[k] ?? 0;

  void add(String k, double v) => _values[k] = (_values[k] ?? 0) + v;

  TreeMods withKeys(Set<String> k) => TreeMods._(_values, k);

  bool hasKey(String k) => keys.contains(k);
}
