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

  const PassiveNode({
    required this.id,
    required this.x,
    required this.y,
    required this.name,
    required this.effects,
    required this.kind,
    required this.links,
    this.keystoneId,
  });
}

/// Catálogo completo del árbol: todos los nodos + qué nodo es el inicio
/// de cada clase + qué keystones se excluyen entre sí.
class PassiveTreeCatalog {
  final Map<String, PassiveNode> nodes;
  final Map<String, String> startNodeByClass; // classId -> nodeId
  final Map<String, String> exclusions; // nodeId -> nodeId mutuamente excluyente

  const PassiveTreeCatalog({
    required this.nodes,
    required this.startNodeByClass,
    required this.exclusions,
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
