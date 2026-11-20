import '../data/passive_tree_v6.dart' show kTreeV6Drawbacks;
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

  /// Puntos de árbol disponibles: [earned] (`PlayerProfile.treePoints`,
  /// ver [pointsEarned]) menos los ya gastados.
  int pointsAvailable(int earned, PlayerPassiveProgress progress) {
    final spent = progress.takenNodeIds.length;
    return (earned - spent).clamp(0, 1 << 30);
  }

  /// Puntos de árbol por nivel ganado después del 1 y por nivel de
  /// Maestría (progresión v2: 1; árbol v6: 2; progression_v2.md § 3.3).
  static const pointsPerLevel = 1;

  /// Puntos por Prueba del Tiempo superada (ascensión 30 / 40 / 50).
  static const pointsPerTrial = 2;

  /// Puntos de hito (progression_v2.md § 5): nivel → puntos.
  static const milestonePoints = {10: 7, 20: 10};

  /// Puntos de árbol ganados con [treeLevel] (nivel + Maestría), las
  /// Pruebas superadas y los hitos elegidos: nivel 50 + 20 de Maestría +
  /// 3 Pruebas + hitos = 49 + 20 + 6 + 17 = 92.
  static int pointsEarned(int treeLevel,
          {int trials = 0, bool ms10 = false, bool ms20 = false}) =>
      (treeLevel - 1) * pointsPerLevel +
      trials * pointsPerTrial +
      (ms10 ? milestonePoints[10]! : 0) +
      (ms20 ? milestonePoints[20]! : 0);

  /// Keystones elegibles en el hito [milestone] (10 o 20) para [classId]
  /// (progression_v2.md § 5): las 5 de los clusters v4 de su clase por
  /// costo desde el inicio; el 10 ofrece las 3 más cercanas y el 20 las
  /// otras 2 más la del puente más cercano.
  List<String> milestoneOptions(String classId, int milestone) {
    final start = catalog.startNodeByClass[classId];
    if (start == null) return const [];
    final dist = <String, int>{start: 0};
    var f = [start];
    while (f.isNotEmpty) {
      final n = <String>[];
      for (final id in f) {
        for (final l in catalog.nodes[id]!.links) {
          if (dist.containsKey(l)) continue;
          dist[l] = dist[id]! + 1;
          n.add(l);
        }
      }
      f = n;
    }
    int cmp(String a, String b) {
      final c = (dist[a] ?? 1 << 20).compareTo(dist[b] ?? 1 << 20);
      return c != 0 ? c : a.compareTo(b);
    }

    final own = [
      for (final n in catalog.nodes.values)
        if (n.kind == 'k' &&
            catalog.paths[n.pathId]?.kind == 'clase' &&
            catalog.paths[n.pathId]?.classId == classId)
          n.id
    ]..sort(cmp);
    final inner = own.take(5).toList();
    if (milestone == 10) return inner.take(3).toList();
    final bridge = [
      for (final n in catalog.nodes.values)
        if (n.kind == 'k' &&
            catalog.paths[n.pathId]?.kind == 'puente' &&
            (catalog.paths[n.pathId]?.classId.split('+').contains(classId) ??
                false))
          n.id
    ]..sort(cmp);
    return [...inner.skip(3), ...bridge.take(1)];
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
  /// trade-offs (furia, mente, halcón, toxicidad; v2: égida), y junta las
  /// mecánicas de notables y keystones v2.
  TreeMods aggregate(String classId, PlayerPassiveProgress progress) {
    final startId = catalog.startNodeByClass[classId];
    final ids = [if (startId != null) startId, ...progress.takenNodeIds];

    final m = TreeMods.zero();
    final keys = <String>{};
    final mechanics = <String>{};

    for (final id in ids) {
      final node = catalog.nodes[id];
      if (node == null) continue;
      mechanics.addAll(node.mechanicIds);
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
    // Keystones v2 (passive_tree_v2.md § 4).
    if (keys.contains('egida')) {
      m.add('atk', -0.20);
      m.add('mag', -0.20);
    }
    // Contras de las keystones v3 (passive_tree_v3.md § 6).
    for (final (key, stat, v) in _drawbacks) {
      if (keys.contains(key)) m.add(stat, v);
    }
    // Contras de las keystones v6 (passive_tree_v6.md § 6).
    for (final (key, stat, v) in kTreeV6Drawbacks) {
      if (keys.contains(key)) m.add(stat, v);
    }

    return m.withKeys(keys, mechanics);
  }

  static const _drawbacks = [
    ('demoledor', 'hp', -0.15),
    ('caudillo', 'ult', -0.30),
    ('bucle', 'spd', -1.0),
    ('singularidad', 'mag', -0.10),
    ('diluvio', 'atk', -0.15),
    ('depredador', 'hp', -0.20),
    ('solInterior', 'atk', -0.15),
    ('inamovible', 'spd', -1.0),
  ];

  /// Nodos que faltan tomar para llegar a [nodeId], en orden (el camino
  /// más corto desde lo que ya tiene, sin pasar por una keystone
  /// excluida). Vacío si ya lo tiene; `null` si no existe o no se puede
  /// llegar (passive_tree_v3.md § 13). No mira los puntos.
  List<String>? pathTo(
      String classId, PlayerPassiveProgress progress, String nodeId) {
    if (!catalog.nodes.containsKey(nodeId)) return null;
    if (hasNode(classId, progress, nodeId)) return const [];
    final taken = {
      if (catalog.startNodeByClass[classId] case final s?) s,
      ...progress.takenNodeIds,
    };
    bool blocked(String id) {
      final ex = catalog.exclusions[id];
      return ex != null && taken.contains(ex);
    }

    if (blocked(nodeId)) return null;
    final prev = <String, String?>{for (final t in taken) t: null};
    var frontier = [
      for (final t in taken)
        if (catalog.nodes.containsKey(t)) t
    ];
    while (frontier.isNotEmpty) {
      final next = <String>[];
      for (final id in frontier) {
        for (final l in catalog.nodes[id]!.links) {
          if (prev.containsKey(l) || blocked(l)) continue;
          prev[l] = id;
          if (l == nodeId) {
            final out = <String>[];
            String? at = l;
            while (at != null && !taken.contains(at)) {
              out.add(at);
              at = prev[at];
            }
            return out.reversed.toList();
          }
          next.add(l);
        }
      }
      frontier = next;
    }
    return null;
  }
}

/// Resultado agregado de `treeMods`: igual forma que en el prototipo JS,
/// más la lista de mecánicas v2 (notables y keystones nuevas, ids de
/// `kMechanics`).
class TreeMods {
  final Map<String, double> _values;
  final Set<String> keys;
  final Set<String> mechanics;

  TreeMods._(this._values, this.keys, [this.mechanics = const {}]);

  /// Tope de crítico: 40% con Danza de Cuchillas, si no 75%.
  double get critCap => keys.contains('danza') ? 0.40 : 0.75;

  factory TreeMods.zero() => TreeMods._({
        'hp': 0,
        'mp': 0,
        'atk': 0,
        'mag': 0,
        'crit': 0,
        'spd': 0,
        'def': 0,
        'ult': 0,
        'heal': 0,
        'burn': 0,
        'poi': 0,
        'frz': 0,
      }, {}, {});

  double operator [](String k) => _values[k] ?? 0;

  void add(String k, double v) => _values[k] = (_values[k] ?? 0) + v;

  TreeMods withKeys(Set<String> k, [Set<String> mechanics = const {}]) =>
      TreeMods._(_values, k, mechanics);

  bool hasKey(String k) => keys.contains(k);
}
