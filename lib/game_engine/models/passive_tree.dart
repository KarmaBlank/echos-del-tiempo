/// Un nodo del árbol de pasivas tipo PoE. Puerto 1:1 del objeto `TREE`
/// del prototipo (ver docs/specs/passive_tree.md para el detalle de reglas).
class PassiveNode {
  final String id;
  final double x, y;
  final String name;
  final Map<String, num> effects; // 'hp','mp','atk','mag','crit','spd','def','ult','heal','burn','poi','frz','key'(ignorado numéricamente)
  final String? keystoneId; // si effects contiene 'key', el valor simbólico va acá
  final String kind; // 'st' (inicio) | 's' (normal) | 'n' (notable) | 'k' (keystone)
  final List<String> links;

  /// Camino temático al que pertenece (v2, `PassiveTreeCatalog.paths`);
  /// `null` en inicios y anillo.
  final String? pathId;

  /// Mecánica del notable o keystone v2 (`kMechanics`).
  final String? mechanicId;

  const PassiveNode({
    required this.id,
    required this.x,
    required this.y,
    required this.name,
    required this.effects,
    required this.kind,
    required this.links,
    this.keystoneId,
    this.pathId,
    this.mechanicId,
  });
}

/// Un camino temático del árbol v2 (docs/specs/passive_tree_v2.md § 2).
class PassivePath {
  final String id;
  final String name;
  final String theme;
  final String classId;

  const PassivePath({
    required this.id,
    required this.name,
    required this.theme,
    required this.classId,
  });
}

/// Catálogo completo del árbol: todos los nodos + qué nodo es el inicio
/// de cada clase + qué keystones se excluyen entre sí.
class PassiveTreeCatalog {
  final Map<String, PassiveNode> nodes;
  final Map<String, String> startNodeByClass; // classId -> nodeId
  final Map<String, String> exclusions; // nodeId -> nodeId mutuamente excluyente

  /// Caminos temáticos por id (v2).
  final Map<String, PassivePath> paths;

  const PassiveTreeCatalog({
    required this.nodes,
    required this.startNodeByClass,
    required this.exclusions,
    this.paths = const {},
  });
}

/// El progreso de UN jugador en el árbol: qué nodos tomó, en orden.
/// El nodo de inicio de su clase se considera siempre tomado y no cuenta
/// contra sus puntos disponibles.
class PlayerPassiveProgress {
  final List<String> takenNodeIds;
  const PlayerPassiveProgress(this.takenNodeIds);

  static const empty = PlayerPassiveProgress([]);
}
