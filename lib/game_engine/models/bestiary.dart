import 'battle_state.dart';

/// Bestiario de la cuenta (docs/specs/bestiary.md § 2): cuántas veces se
/// mató a cada tipo de enemigo. La primera muerte desbloquea la ficha.
/// Compartido por todos los personajes, como el Atlas. Inmutable.
class BestiaryProgress {
  BestiaryProgress([Map<String, int> kills = const {}])
      : kills = Map.unmodifiable(kills);

  static final empty = BestiaryProgress();

  /// Muertes por id de enemigo (`EnemyDef.id`).
  final Map<String, int> kills;

  /// Ya lo mató alguna vez: se ve su ficha.
  bool knows(String? enemyType) =>
      enemyType != null && (kills[enemyType] ?? 0) > 0;

  int killsOf(String enemyType) => kills[enemyType] ?? 0;

  /// Tipos descubiertos.
  int get discovered => kills.values.where((n) => n > 0).length;

  bool get isEmpty => discovered == 0;

  /// Suma una muerte por cada id de [enemyTypes] (repetidos cuentan
  /// todos). Devuelve `this` si no hay nada.
  BestiaryProgress record(Iterable<String> enemyTypes) {
    final next = Map.of(kills);
    var any = false;
    for (final t in enemyTypes) {
      if (t.isEmpty) continue;
      next[t] = (next[t] ?? 0) + 1;
      any = true;
    }
    return any ? BestiaryProgress(next) : this;
  }

  /// Los tipos que [record] desbloquearía por primera vez.
  Set<String> newIn(Iterable<String> enemyTypes) =>
      {for (final t in enemyTypes) if (t.isNotEmpty && !knows(t)) t};

  Map<String, Object?> toJson() => {
        'k': {
          for (final e in kills.entries)
            if (e.value > 0) e.key: e.value,
        },
      };

  /// Lectura tolerante: lo que no es un conteo positivo se descarta.
  factory BestiaryProgress.fromJson(Object? raw) {
    if (raw is! Map) return BestiaryProgress();
    final k = raw['k'];
    if (k is! Map) return BestiaryProgress();
    return BestiaryProgress({
      for (final e in k.entries)
        if (e.key is String && e.value is num && (e.value as num) >= 1)
          e.key as String: (e.value as num).toInt(),
    });
  }
}

/// Los enemigos que cuentan como muertos al ganar [battle]: todos los
/// enemigos de la batalla (al ganar, ninguno queda en pie; las
/// invocaciones pasivas caen con su jefe).
List<String> bestiaryKills(BattleState battle) => [
      for (final e in battle.enemies)
        if (e.enemyType != null && e.enemyType!.isNotEmpty) e.enemyType!,
    ];

/// Dónde vive el bestiario de la cuenta. `game_engine` solo define el
/// contrato; `account.json` lo implementa en `features/characters/data`.
abstract interface class BestiaryStore {
  Future<BestiaryProgress> load();

  Future<void> save(BestiaryProgress bestiary);
}

/// En memoria (tests, builds sin carpeta de datos).
class InMemoryBestiaryStore implements BestiaryStore {
  InMemoryBestiaryStore([BestiaryProgress? initial])
      : _json = initial?.toJson();

  Map<String, Object?>? _json;
  int saves = 0;

  @override
  Future<BestiaryProgress> load() async => BestiaryProgress.fromJson(_json);

  @override
  Future<void> save(BestiaryProgress bestiary) async {
    saves++;
    _json = bestiary.toJson();
  }
}
