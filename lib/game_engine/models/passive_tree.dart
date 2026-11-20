/// Un nodo del árbol de pasivas con clusters y keystones. Puerto 1:1 del objeto `TREE`
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

  /// Árbol v7 (progression_v2.md § 3.2): mecánicas de los nodos que se
  /// fusionaron o absorbieron en este.
  final List<String> extraMechanicIds;

  /// Ids del árbol v6 que se fusionaron o absorbieron en este nodo.
  final List<String> mergedIds;

  /// Chico doble (dos chicos v6 fusionados).
  final bool isDouble;

  /// Notable menor (un chico suelto promovido, § 3.4).
  final bool isMinor;

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
    this.extraMechanicIds = const [],
    this.mergedIds = const [],
    this.isDouble = false,
    this.isMinor = false,
  });

  /// Todas sus mecánicas (la propia y las fusionadas).
  List<String> get mechanicIds =>
      [if (mechanicId case final m?) m, ...extraMechanicIds];
}

/// Un cluster temático del árbol (v3: docs/specs/passive_tree_v3.md § 2;
/// en la v2 eran caminos rectos).
class PassivePath {
  final String id;
  final String name;
  final String theme;

  /// Clase dueña; en un puente, las dos (`guerrero+maga`); en un cluster
  /// de grupo, `grupo`.
  final String classId;

  /// `clase`, `puente` o `grupo` (v3).
  final String kind;

  /// Dónde va su etiqueta en el dibujo (unidades de árbol).
  final double labelX, labelY;

  const PassivePath({
    required this.id,
    required this.name,
    required this.theme,
    required this.classId,
    this.kind = 'clase',
    this.labelX = 0,
    this.labelY = 0,
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

  /// Puntos intermedios con que se dibuja una arista (clave `a|b` con
  /// `a < b`). Sin entrada, la arista es una recta. El v7 los usa para
  /// seguir los tallos y arcos del v6 (progression_v2.md § 11).
  final Map<String, List<(double, double)>> edgeRoutes;

  const PassiveTreeCatalog({
    required this.nodes,
    required this.startNodeByClass,
    required this.exclusions,
    this.paths = const {},
    this.edgeRoutes = const {},
    this.extraStrokes = const {},
  });

  /// Tramos sueltos del dibujo (coordenadas del árbol) que no son parte
  /// de ninguna arista: en el v7, los del v6 que quedaron dentro de un
  /// nodo fusionado. Clave: un id, o `a|b`; se pinta como tomado cuando
  /// todos los ids de la clave están tomados.
  final Map<String, List<((double, double), (double, double))>> extraStrokes;

  /// Polilínea completa de la arista `a`–`b` (coordenadas del árbol),
  /// de `a` a `b`.
  List<(double, double)> edgePoints(String a, String b) {
    final na = nodes[a]!, nb = nodes[b]!;
    final flip = a.compareTo(b) > 0;
    final mid = edgeRoutes[flip ? '$b|$a' : '$a|$b'] ?? const [];
    return [
      (na.x, na.y),
      ...(flip ? mid.reversed : mid),
      (nb.x, nb.y),
    ];
  }
}

/// El progreso de UN jugador en el árbol: qué nodos tomó, en orden.
/// El nodo de inicio de su clase se considera siempre tomado y no cuenta
/// contra sus puntos disponibles.
class PlayerPassiveProgress {
  final List<String> takenNodeIds;
  const PlayerPassiveProgress(this.takenNodeIds);

  static const empty = PlayerPassiveProgress([]);
}
