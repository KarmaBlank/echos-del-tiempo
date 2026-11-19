import 'status.dart';

// Elementos y reacciones v0.7 (docs/specs/elemental_reactions.md). Puro
// Dart: el motor, el contenido y la presentación comparten estos nombres
// (contrato § 8).

/// Elemento de un golpe, habilidad, ULT, ataque enemigo o estado.
/// [fisico] también es "sin elemento" (golpes neutros y magia arcana).
///
/// Se llama `GameElement` (no `Element`, como decía el contrato) para no
/// chocar con la clase `Element` de los widgets de Flutter.
enum GameElement {
  fisico('Físico'),
  fuego('Fuego'),
  hielo('Hielo'),
  veneno('Veneno'),
  sagrado('Sagrado'),
  agua('Agua'),
  electro('Electro');

  const GameElement(this.label);
  final String label;

  /// Estado que deja el elemento (Quemadura, Mojado...). `null`: físico.
  StatusKind? get status => switch (this) {
        GameElement.fisico => null,
        GameElement.fuego => StatusKind.burn,
        GameElement.hielo => StatusKind.freeze,
        GameElement.veneno => StatusKind.poison,
        GameElement.sagrado => StatusKind.holy,
        GameElement.agua => StatusKind.wet,
        GameElement.electro => StatusKind.charged,
      };
}

/// Elemento de un estado (Quemadura = fuego...). `null`: aturdido y
/// regeneración no tienen elemento.
GameElement? statusElement(StatusKind k) => switch (k) {
      StatusKind.burn => GameElement.fuego,
      StatusKind.poison => GameElement.veneno,
      StatusKind.freeze => GameElement.hielo,
      StatusKind.holy => GameElement.sagrado,
      StatusKind.wet => GameElement.agua,
      StatusKind.charged => GameElement.electro,
      StatusKind.stun || StatusKind.regen => null,
    };

/// Las 5 reacciones (§ 2). El orden es la prioridad cuando un golpe
/// podría detonar dos (un golpe de fuego sobre Veneno + Congelación hace
/// Explosión tóxica).
enum ReactionKind {
  electrocucion('Electrocución'),
  explosionToxica('Explosión tóxica'),
  congelacionSubita('Congelación súbita'),
  derretir('Derretir'),
  cortocircuito('Cortocircuito'),

  /// Convergencia v0.9 (combo_balance.md § 4): Quemadura + golpe de
  /// Veneno. Al final del enum: byssSeal guarda el índice.
  combustion('Combustión');

  /// Convergencia (combo_balance.md § 4): consume stacks y pega por % de
  /// la vida máxima. Las demás son reacciones de golpe.
  bool get convergence =>
      this == ReactionKind.explosionToxica || this == ReactionKind.combustion;

  const ReactionKind(this.label);
  final String label;

  /// Id del sonido (`sfx.reaction.<kind>`, contrato § 8).
  String get sfxId => 'sfx.reaction.$name';

  /// Estado del objetivo que la reacción consume.
  StatusKind get primer => kReactionTable
      .firstWhere((r) => r.kind == this)
      .primer;

  /// Elemento del golpe que la detona.
  GameElement get detonator => kReactionTable
      .firstWhere((r) => r.kind == this)
      .detonator;
}

/// Una fila de la tabla de reacciones: estado en el objetivo + elemento
/// del golpe → reacción.
class ReactionRule {
  const ReactionRule(this.primer, this.detonator, this.kind);
  final StatusKind primer;
  final GameElement detonator;
  final ReactionKind kind;
}

/// La tabla de § 2, en orden de prioridad. Los pares que no están (Fuego +
/// Agua, Fuego + Electro, Hielo + Electro...) no reaccionan (pedido del
/// dueño).
const List<ReactionRule> kReactionTable = [
  ReactionRule(StatusKind.wet, GameElement.electro, ReactionKind.electrocucion),
  ReactionRule(StatusKind.poison, GameElement.fuego, ReactionKind.explosionToxica),
  ReactionRule(StatusKind.wet, GameElement.hielo, ReactionKind.congelacionSubita),
  ReactionRule(StatusKind.freeze, GameElement.fuego, ReactionKind.derretir),
  ReactionRule(StatusKind.charged, GameElement.agua, ReactionKind.cortocircuito),
  ReactionRule(StatusKind.burn, GameElement.veneno, ReactionKind.combustion),
];

/// Reacción de un par (estado, elemento), o `null`.
ReactionKind? reactionOf(StatusKind primer, GameElement detonator) {
  for (final r in kReactionTable) {
    if (r.primer == primer && r.detonator == detonator) return r.kind;
  }
  return null;
}

/// Reacciones que un golpe de [e] detona (para el tooltip: "reacciona con
/// Mojado (Electrocución)").
List<ReactionRule> reactionsDetonatedBy(GameElement e) =>
    [for (final r in kReactionTable) if (r.detonator == e) r];

/// Reacciones que prepara el estado que deja [e] (Agua: Mojado lo
/// detonan Electro y Hielo).
List<ReactionRule> reactionsPrimedBy(GameElement e) {
  final st = e.status;
  return st == null
      ? const []
      : [for (final r in kReactionTable) if (r.primer == st) r];
}

/// Números de una reacción (catálogo, editables desde el admin de
/// balance: docs/specs/balance_admin.md). Los campos que no usa una
/// reacción quedan en su neutro.
class ReactionDef {
  const ReactionDef({
    required this.kind,
    this.damageMult = 1,
    this.perStack = 0,
    this.splash = 0,
    this.commonCap = 0,
    this.eliteCap = 0,
    this.bossCap = 0,
    this.stunTurns = 0,
  });

  final ReactionKind kind;

  String get id => kind.name;
  String get name => kind.label;

  /// Multiplicador del golpe que la detona (Electrocución, Derretir ×1.5).
  final double damageMult;

  /// Convergencias (combo_balance.md § 4): daño = vida máx. del objetivo
  /// × [perStack] × stacks consumidos (0.025 = 2.5% por stack).
  final double perStack;

  /// Fracción que salpica a los demás del bando del objetivo
  /// (Convergencias 0.3) o que salta a 1 más (Cortocircuito 0.5).
  final double splash;

  /// Convergencias: tope del daño contra un común / élite / jefe, en
  /// fracción de su vida máxima. 0 = sin tope.
  final double commonCap, eliteCap, bossCap;

  /// El tope de una Convergencia contra [c] (0 = sin tope).
  double capFor({required bool elite, required bool boss}) =>
      boss ? bossCap : (elite ? eliteCap : commonCap);

  /// Turnos de Aturdido que deja (Electrocución 1).
  final int stunTurns;
}

/// Reglas de un estado elemental (Mojado, Cargado, Congelación), también
/// editables desde el admin. Cada estado usa sus campos.
class ElementStatusDef {
  const ElementStatusDef({
    required this.kind,
    this.turns = 0,
    this.slowPerStack = 0,
    this.breakPerStack = 0,
    this.brittleMult = 1,
  });

  final StatusKind kind;

  String get id => kind.name;
  String get name => kind.label;

  /// Mojado / Cargado: duración en turnos propios del afectado.
  /// Congelación: turnos de resistencia después de descongelarse.
  final int turns;

  /// Congelación: −velocidad por stack (0.06).
  final double slowPerStack;

  /// Congelación: +llenado de quiebre por stack (0.10).
  final double breakPerStack;

  /// Congelación: multiplicador del golpe físico a un Quebradizo (1.5).
  final double brittleMult;
}
