import '../serialization/json_read.dart';

/// Progreso de un personaje entre runs (docs/specs/roguelike.md § 8.1):
/// nodos del árbol de afuera comprados y el loadout elegido.
class TravesiaCharMeta {
  const TravesiaCharMeta({this.nodes = const {}, this.loadout = const []});

  final Set<String> nodes;

  /// Habilidades de arranque elegidas (ids).
  final List<String> loadout;

  TravesiaCharMeta copyWith({Set<String>? nodes, List<String>? loadout}) =>
      TravesiaCharMeta(
          nodes: nodes ?? this.nodes, loadout: loadout ?? this.loadout);

  Json toJson() => {
        if (nodes.isNotEmpty) 'n': (nodes.toList()..sort()),
        if (loadout.isNotEmpty) 'l': loadout,
      };

  static TravesiaCharMeta fromJson(Object? raw) {
    final j = raw is Map ? asJson(raw) : const <String, Object?>{};
    List<String> strs(Object? v) =>
        v is List ? [for (final x in v) if (x is String) x] : const [];
    return TravesiaCharMeta(nodes: strs(j['n']).toSet(), loadout: strs(j['l']));
  }
}

/// Progreso permanente de la Travesía (§ 8), por cuenta del dispositivo:
/// moneda, árbol de afuera y loadout por personaje, zonas, élites vencidas
/// y dificultad. Archivo propio (`travesia_meta.json`), nunca el del Mundo.
class TravesiaMeta {
  const TravesiaMeta({
    this.coins = 0,
    this.chars = const {},
    this.zones = 0,
    this.eliteWins = const {},
    this.difficultyUnlocked = 0,
    this.difficulty = 0,
    this.runs = 0,
    this.wins = 0,
    this.lastSeed,
  });

  static const empty = TravesiaMeta();

  /// Moneda para el árbol de afuera.
  final int coins;

  /// Por personaje (`nombre|clase`).
  final Map<String, TravesiaCharMeta> chars;

  /// Zonas desbloqueadas además de las del arranque.
  final int zones;

  /// Veces que se venció a cada élite (tipo de enemigo).
  final Map<String, int> eliteWins;

  /// Dificultad más alta desbloqueada y la elegida (0 = normal).
  final int difficultyUnlocked;
  final int difficulty;

  final int runs;
  final int wins;

  /// Semilla de la última run cobrada (no se cobra dos veces).
  final int? lastSeed;

  static String keyOf(String name, String classId) => '$name|$classId';

  TravesiaCharMeta charOf(String key) => chars[key] ?? const TravesiaCharMeta();

  TravesiaMeta copyWith({
    int? coins,
    Map<String, TravesiaCharMeta>? chars,
    int? zones,
    Map<String, int>? eliteWins,
    int? difficultyUnlocked,
    int? difficulty,
    int? runs,
    int? wins,
    int? lastSeed,
  }) =>
      TravesiaMeta(
        coins: coins ?? this.coins,
        chars: chars ?? this.chars,
        zones: zones ?? this.zones,
        eliteWins: eliteWins ?? this.eliteWins,
        difficultyUnlocked: difficultyUnlocked ?? this.difficultyUnlocked,
        difficulty: difficulty ?? this.difficulty,
        runs: runs ?? this.runs,
        wins: wins ?? this.wins,
        lastSeed: lastSeed ?? this.lastSeed,
      );

  TravesiaMeta withChar(String key, TravesiaCharMeta c) =>
      copyWith(chars: {...chars, key: c});

  Json toJson() => {
        'v': 1,
        'coins': coins,
        if (chars.isNotEmpty)
          'chars': {for (final e in chars.entries) e.key: e.value.toJson()},
        'zones': zones,
        if (eliteWins.isNotEmpty) 'elites': eliteWins,
        'diffU': difficultyUnlocked,
        'diff': difficulty,
        'runs': runs,
        'wins': wins,
        if (lastSeed != null) 'last': lastSeed,
      };

  /// Tolerante: lo que falta o está roto vuelve al valor de arranque.
  static TravesiaMeta fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final j = asJson(raw);
    int n(String k) => j[k] is num ? (j[k] as num).toInt() : 0;
    final cs = j['chars'] is Map ? asJson(j['chars']) : const <String, Object?>{};
    final es = j['elites'] is Map ? asJson(j['elites']) : const <String, Object?>{};
    return TravesiaMeta(
      coins: n('coins'),
      chars: {for (final e in cs.entries) e.key: TravesiaCharMeta.fromJson(e.value)},
      zones: n('zones'),
      eliteWins: {
        for (final e in es.entries)
          if (e.value is num) e.key: (e.value as num).toInt(),
      },
      difficultyUnlocked: n('diffU'),
      difficulty: n('diff'),
      runs: n('runs'),
      wins: n('wins'),
      lastSeed: j['last'] is num ? (j['last'] as num).toInt() : null,
    );
  }
}

abstract interface class TravesiaMetaStore {
  Future<TravesiaMeta> load();
  Future<void> save(TravesiaMeta meta);
}

class InMemoryTravesiaMetaStore implements TravesiaMetaStore {
  InMemoryTravesiaMetaStore([this.value = TravesiaMeta.empty]);
  TravesiaMeta value;

  @override
  Future<TravesiaMeta> load() async => value;

  @override
  Future<void> save(TravesiaMeta meta) async => value = meta;
}
