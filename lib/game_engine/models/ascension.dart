/// Ascensión (subclase) y su mini-árbol. Ver docs/specs/ascension.md.
library;

/// Tipo de trampa de la Prueba del Tiempo (ascension.md § 1.1).
enum TrapKind { spikes, pulse }

/// Un nodo del mini-árbol de una ascensión (§ 3).
class AscensionNode {
  const AscensionNode({
    required this.id,
    required this.name,
    required this.cost,
    required this.x,
    required this.y,
    required this.links,
    required this.text,
    this.mechanicId,
    this.stats = const {},
    this.major = false,
  });

  final String id;
  final String name;

  /// Puntos que cuesta (la raíz, 0: la da elegir la ascensión).
  final int cost;

  /// Celda del lienzo (raíz en (0, 0)).
  final int x, y;
  final List<String> links;

  /// Texto para la ficha.
  final String text;

  /// Mecánica (`kAscensionMechanics`), si el nodo es una mecánica.
  final String? mechanicId;

  /// Stats como los del árbol de pasivas (`burn`, `frz`, `poi`...).
  final Map<String, num> stats;

  /// Nodo mayor (costo 2 de una rama).
  final bool major;

  bool get root => cost == 0;
}

/// Una ascensión de una clase (§ 2).
class AscensionDef {
  const AscensionDef({
    required this.id,
    required this.classId,
    required this.name,
    required this.theme,
    required this.motto,
    required this.color,
    required this.skillIds,
    required this.ultId,
    required this.nodes,
  });

  /// Id fijo (contrato con el arte: sprite `<clase>_<id>`).
  final String id;
  final String classId;
  final String name;

  /// Tema corto (`vida baja = más daño, robo de vida`).
  final String theme;

  /// Lema de la cinemática.
  final String motto;

  /// Color ARGB del aura, el cartel y los nodos.
  final int color;

  /// Las 2 habilidades del kit.
  final List<String> skillIds;

  /// La ULT de la ascensión (`kAscensionUltimates`), reemplaza la del arma.
  final String ultId;
  final List<AscensionNode> nodes;

  String get rootId => '${id}_r';

  /// Id del sprite del héroe ascendido.
  String get spriteId => '${classId}_$id';

  AscensionNode? node(String nodeId) {
    for (final n in nodes) {
      if (n.id == nodeId) return n;
    }
    return null;
  }
}

/// El progreso de ascensión de UN personaje (perfil, JSON `asc`).
class AscensionProgress {
  const AscensionProgress({
    this.trials = const {},
    this.id,
    this.nodes = const [],
  });

  /// Pruebas del Tiempo superadas (1..3).
  final Set<int> trials;

  /// Ascensión elegida (`null` = todavía no).
  final String? id;

  /// Nodos tomados (sin la raíz), en orden.
  final List<String> nodes;

  static const empty = AscensionProgress();

  /// Puntos por Prueba (§ 1.2).
  static const pointsPerTrial = 2;

  int get earned => trials.length * pointsPerTrial;

  bool get isEmpty => trials.isEmpty && id == null && nodes.isEmpty;

  AscensionProgress copyWith({
    Set<int>? trials,
    String? Function()? id,
    List<String>? nodes,
  }) =>
      AscensionProgress(
        trials: trials ?? this.trials,
        id: id != null ? id() : this.id,
        nodes: nodes ?? this.nodes,
      );

  Map<String, Object?> toJson() => {
        if (trials.isNotEmpty) 'tr': (trials.toList()..sort()),
        if (id != null) 'id': id,
        if (nodes.isNotEmpty) 'n': nodes,
      };

  /// Lectura tolerante (lo inválido lo descarta `ProgressionRules.normalize`).
  static AscensionProgress fromJson(Object? json) {
    if (json is! Map) return empty;
    final tr = json['tr'];
    final n = json['n'];
    return AscensionProgress(
      trials: tr is List
          ? {
              for (final t in tr)
                if (t is num && t.isFinite) t.toInt()
            }
          : const {},
      id: json['id'] is String ? json['id'] as String : null,
      nodes: n is List ? [for (final e in n) if (e is String) e] : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AscensionProgress &&
      other.id == id &&
      other.trials.length == trials.length &&
      other.trials.containsAll(trials) &&
      other.nodes.length == nodes.length &&
      [for (var i = 0; i < nodes.length; i++) other.nodes[i] == nodes[i]]
          .every((b) => b);

  @override
  int get hashCode => Object.hash(id, trials.length, nodes.length);
}
