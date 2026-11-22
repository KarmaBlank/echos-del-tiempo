import 'attributes.dart';

/// Tipo de nodo del mapa de la Travesía (docs/specs/roguelike.md § 2).
/// Solo estos: no hay eventos ni cofres.
enum RunNodeType {
  combate('COMBATE'),
  elite('ÉLITE'),
  jefe('JEFE'),
  tienda('TIENDA'),
  armeria('ARMERÍA'),
  descanso('DESCANSO');

  const RunNodeType(this.label);
  final String label;

  bool get isFight =>
      this == combate || this == elite || this == jefe;

  /// Tienda, armería o descanso: cada uno resuelve lo suyo y da LISTO.
  bool get isStop => !isFight;
}

/// Un nodo del piso. [lane] es la línea principal (0..2); [x] la
/// posición horizontal para dibujarlo (en unidades de línea).
class RunNode {
  const RunNode({
    required this.id,
    required this.layer,
    required this.lane,
    required this.x,
    required this.type,
    required this.next,
  });

  final int id;
  final int layer;
  final int lane;
  final double x;
  final RunNodeType type;

  /// Ids de los nodos de la capa siguiente a los que lleva.
  final List<int> next;
}

/// Un piso: capas de nodos y el jefe al final.
class RunFloor {
  RunFloor(this.index, this.nodes);

  final int index;

  /// En orden de id (el id es la posición en la lista).
  final List<RunNode> nodes;

  RunNode node(int id) => nodes[id];

  /// El jefe (último nodo).
  RunNode get boss => nodes.last;

  int get layers => boss.layer + 1;

  /// Los de la primera capa (a los que lleva la entrada del piso).
  Iterable<RunNode> get entry => nodes.where((n) => n.layer == 0);

  Iterable<RunNode> layer(int l) => nodes.where((n) => n.layer == l);

  /// Predecesores de [id].
  Iterable<RunNode> before(int id) => nodes.where((n) => n.next.contains(id));
}

/// El mapa entero de una run (3 pisos), derivado de la semilla.
class RunMap {
  RunMap(this.seed, this.floors);
  final int seed;
  final List<RunFloor> floors;
}

/// Fase de la run dentro de `SessionMode.run`.
enum RunPhase {
  /// Votando el próximo nodo.
  map,

  /// Peleando (la sesión está en `SessionMode.battle`).
  battle,

  /// Cada jugador elige su recompensa.
  reward,

  /// Tienda / armería / descanso: cada uno da LISTO.
  stop,

  /// Terminó (jefe del último piso vencido o grupo entero caído).
  over,
}

/// Tipo de recompensa de la fila «Extra».
enum RunExtraKind { oro, pocion, eter, atributo }

class RunExtra {
  const RunExtra(this.kind, this.amount, {this.attribute});
  final RunExtraKind kind;
  final int amount;
  final Attribute? attribute;

  @override
  bool operator ==(Object other) =>
      other is RunExtra &&
      other.kind == kind &&
      other.amount == amount &&
      other.attribute == attribute;

  @override
  int get hashCode => Object.hash(kind, amount, attribute);
}

/// La oferta de recompensa de un jugador tras una pelea ganada (§ 4).
class RunOffer {
  const RunOffer(
      {this.nodes = const [], this.weapons = const [], this.extras = const []});

  /// Nodos del árbol (ids).
  final List<String> nodes;

  /// Bases de arma (ids).
  final List<String> weapons;
  final List<RunExtra> extras;
}

/// Estado autoritativo de la Travesía en curso. Mutable como el resto de
/// `GameSession` (el motor trabaja sobre copias).
class RunState {
  RunState({
    required this.seed,
    required this.zones,
    this.floor = 0,
    this.node,
    this.phase = RunPhase.map,
    Map<String, int>? votes,
    Map<String, RunOffer>? offers,
    Set<String>? ready,
    Map<String, int>? missStreak,
    this.victory,
    this.wins = 0,
  })  : votes = {...?votes},
        offers = {...?offers},
        ready = {...?ready},
        missStreak = {...?missStreak};

  final int seed;

  /// Índice de zona (catálogo) de cada piso.
  final List<int> zones;
  int floor;

  /// Nodo actual en el piso; `null` = en la entrada.
  int? node;
  RunPhase phase;

  /// Voto de cada jugador (id de nodo alcanzable).
  final Map<String, int> votes;

  /// Ofertas pendientes (las que todavía no se eligieron).
  final Map<String, RunOffer> offers;

  /// Quiénes dieron LISTO en tienda / armería / descanso.
  final Set<String> ready;

  /// Ofertas seguidas sin un nodo de la rama principal (racha).
  final Map<String, int> missStreak;

  /// Al terminar: `true` = venció al último jefe.
  bool? victory;

  /// Peleas ganadas.
  int wins;

  RunState copy() => RunState(
        seed: seed,
        zones: zones,
        floor: floor,
        node: node,
        phase: phase,
        votes: votes,
        offers: offers,
        ready: ready,
        missStreak: missStreak,
        victory: victory,
        wins: wins,
      );
}
