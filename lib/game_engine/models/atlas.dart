// Atlas del Tiempo: árbol de endgame compartido por la cuenta. Ver
// docs/specs/ecos_atlas.md § 5.

/// Rama del Atlas (para el color y la ayuda).
enum AtlasBranch {
  origen('Origen'),
  cartografia('Cartografía'),
  tesoro('Tesoro'),
  caza('Caza'),
  dominio('Dominio'),
  grieta('Grietas');

  const AtlasBranch(this.label);
  final String label;
}

/// Un nodo del Atlas (`kAtlasNodes`).
class AtlasNodeDef {
  const AtlasNodeDef({
    required this.id,
    required this.name,
    required this.branch,
    required this.cost,
    required this.text,
    required this.x,
    required this.y,
    this.links = const [],
    this.notable = false,
    this.locked = false,
    this.effects = const {},
  });

  final String id;
  final String name;
  final AtlasBranch branch;
  final int cost;

  /// Efecto en una línea (tooltip).
  final String text;

  /// Posición en la grilla (centro = 0, 0; x a la derecha, y abajo).
  final int x, y;
  final List<String> links;
  final bool notable;

  /// "Próximamente": no se puede tomar.
  final bool locked;

  /// Efectos numéricos (claves de `AtlasEffects`).
  final Map<String, num> effects;
}

/// Lo que guarda la cuenta: nodos tomados y "primeras veces" (`t<n>`,
/// `z<n>`, `b<n>`). Inmutable.
class AtlasProgress {
  AtlasProgress(
      {Iterable<String> nodes = const [], Iterable<String> done = const []})
      : nodes = List.unmodifiable(nodes),
        done = Set.unmodifiable(done);

  static final empty = AtlasProgress();

  /// Nodos tomados, en orden (sin `origen`).
  final List<String> nodes;

  /// Primeras veces de la cuenta.
  final Set<String> done;

  AtlasProgress copyWith({Iterable<String>? nodes, Iterable<String>? done}) =>
      AtlasProgress(nodes: nodes ?? this.nodes, done: done ?? this.done);

  Map<String, Object?> toJson() => {
        'n': nodes,
        'd': (done.toList()..sort()),
      };

  /// Lectura tolerante (lo que no sea lista de textos se ignora).
  factory AtlasProgress.fromJson(Object? raw) {
    if (raw is! Map) return AtlasProgress();
    List<String> strings(Object? v) => v is List
        ? [
            for (final e in v)
              if (e is String) e
          ]
        : const [];
    final seen = <String>{};
    return AtlasProgress(
      nodes: [
        for (final n in strings(raw['n']))
          if (seen.add(n)) n
      ],
      done: strings(raw['d']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AtlasProgress &&
      other.nodes.length == nodes.length &&
      other.done.length == done.length &&
      other.done.containsAll(done) &&
      [for (var i = 0; i < nodes.length; i++) other.nodes[i] == nodes[i]]
          .every((x) => x);

  @override
  int get hashCode => Object.hash(Object.hashAll(nodes), done.length);
}

/// Efectos sumados de los nodos tomados (§ 5.3). Todo en fracciones
/// (0.25 = +25%) salvo los contadores.
class AtlasEffects {
  const AtlasEffects({
    this.ecoDrop = 0,
    this.zones = const {},
    this.quantity = 0,
    this.rarity = 0,
    this.legendary = 0,
    this.bossWeapons = 0,
    this.eliteWeapons = 0,
    this.anchor = 0,
    this.bossUnique = 0,
    this.bossEcos = 0,
    this.freeMods = 0,
    this.modPower = 0,
    this.tempered = 0,
    this.xp = 0,
    this.chests = 0,
    this.extraEco = 0,
    this.tierUp = 0,
  });

  static const none = AtlasEffects();

  /// +% chance de Ecos.
  final double ecoDrop;

  /// Zonas (1–10) con peso ×3.
  final Set<int> zones;
  final double quantity;
  final double rarity;

  /// +% chance de Legendario (multiplica su peso).
  final double legendary;
  final int bossWeapons;
  final int eliteWeapons;

  /// +% chance de Ancla Temporal.
  final double anchor;
  final double bossUnique;
  final int bossEcos;
  final int freeMods;

  /// +% del bonus de loot de los mods.
  final double modPower;

  /// Fracción que se le quita a la dificultad de los mods.
  final double tempered;

  /// +% XP en Ecos.
  final double xp;
  final int chests;

  /// Fin del Eco: chance de un 2.º Eco y +chance de subir de tier.
  final double extraEco;
  final double tierUp;
}
