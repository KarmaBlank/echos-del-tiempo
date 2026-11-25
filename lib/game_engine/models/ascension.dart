/// Ascensión (subclase) y su mini-árbol. Ver docs/specs/ascension.md.
library;

import '../data/tuning_catalog.dart';

/// Tipo de trampa de la Prueba del Tiempo (ascension.md § 1.1).
enum TrapKind { spikes, pulse }

/// Kind of a node of the ascension tree v2 (ascension.md § 3.0).
enum AscNodeKind { root, minor, notable, major, capstone }

/// Condition of a Trades-branch node (ascension.md § 3.5): the node only
/// gives its stats while it holds. [town] counts how many of the other
/// four hold.
enum AscCondition { none, meal, forged, trade, mastery, town }

/// A node of an ascension tree (§ 3).
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
    this.statMults = const {},
    this.fixedStats = const {},
    this.kind = AscNodeKind.minor,
    this.condition = AscCondition.none,
  });

  final String id;

  /// Source name (es-AR). Empty for minor / major nodes: their name is
  /// built from the stat or branch (`ui.ascension.minor.<stat>`).
  final String name;

  /// Points it costs (the root, 0: choosing the ascension gives it).
  final int cost;

  /// Canvas cell: `x` = branch (0–4), `y` = tier (0–10).
  final int x, y;
  final List<String> links;

  /// Source text (es-AR) for mechanic nodes; empty for stat nodes (their
  /// text is built from [stats], so it always shows the tuned value).
  final String text;

  /// Mechanic (`kAscensionMechanics`), if the node is a mechanic.
  final String? mechanicId;

  /// Tree stats (`hp`, `atk`, `crit`...) as multiples of the tuned
  /// `minor<Stat>` value (Settings → Ascension).
  final Map<String, double> statMults;

  /// Stats given as-is (Overload: `burn` / `frz` / `poi` stacks); the
  /// value multiplies the `overloadStacks` setting.
  final Map<String, num> fixedStats;

  final AscNodeKind kind;
  final AscCondition condition;

  /// Branch index (0–4) and tier (0–10).
  int get branch => x;
  int get tier => y;

  /// Notable, major or capstone (bigger node in the canvas).
  bool get major =>
      kind == AscNodeKind.notable ||
      kind == AscNodeKind.major ||
      kind == AscNodeKind.capstone;

  bool get capstone => kind == AscNodeKind.capstone;

  bool get root => cost == 0;

  /// The node's tree stats with the current settings (unconditional:
  /// conditions are checked by `StatsCalculator`).
  Map<String, double> get stats {
    final t = kTuning[TuningId.ascension];
    double base(String k) {
      final key = 'minor${k[0].toUpperCase()}${k.substring(1)}';
      return t?.values[key]?.toDouble() ?? 0;
    }

    final over = t?.values['overloadStacks']?.toDouble() ?? 1;
    return {
      for (final e in statMults.entries) e.key: base(e.key) * e.value,
      for (final e in fixedStats.entries) e.key: e.value * over,
    };
  }
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

  /// Points per Trial (§ 1.2, Settings → Ascension).
  static int get pointsPerTrial =>
      kTuning[TuningId.ascension]?.i('pointsPerTrial') ?? 7;

  /// Version of the saved tree (§ 3.1b): progress without it is the v0.5
  /// 8-node tree and gets its points back.
  static const treeVersion = 2;

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
        if (nodes.isNotEmpty) 'v': treeVersion,
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
      // Migration (§ 3.1b): the old tree refunds every point.
      nodes: n is List && json['v'] == treeVersion
          ? [for (final e in n) if (e is String) e]
          : const [],
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
