// TUTORIAL: Ecos de práctica (docs/specs/combat_tutorial.md).
//
// El estado del guion lo lleva el host y viaja en el snapshot (`tut` de
// la sesión, § 4.1): todos ven el mismo paso, el mismo cartel y el mismo
// resaltado. Mutable como el resto de `GameSession` (el motor trabaja
// sobre una copia).

/// Versión vigente del tutorial: el máximo de las `desde` de
/// `kTutorialStages` (combat_tutorial.md § 2). Solo se sube cuando cambia
/// el combate básico (un ajuste de números no la cambia).
const kTutorialVersion = 1;

/// Qué se puede hacer en un paso del guion (§ 4.2).
enum TutorialMove { attack, skill, defend, pass }

/// Hacia dónde apunta la flecha del cartel de efecto (§ 4.1).
enum TutorialArrow { timeline, hp, mp, pulse, status, breakBar, ult }

/// Los 4 roles del guion (§ 4.3). Con menos jugadores, uno hace varios.
enum TutorialRole {
  acumula('acumulás'),
  detona('detonás'),
  barra('llenás la barra'),
  quiebra('quebrás');

  const TutorialRole(this.verb);

  /// "Intento 2: esta vez quebrás vos".
  final String verb;
}

/// Un paso del guion.
sealed class TutorialStep {
  const TutorialStep();
}

/// Actúa el jugador que tiene [role]: solo [move] (y [skillId]) está
/// habilitado.
class TutorialPlayerStep extends TutorialStep {
  const TutorialPlayerStep(this.role, this.move,
      {this.skillId, this.untilFissured = false, this.maxReps = 1});
  final TutorialRole role;
  final TutorialMove move;

  /// Con [TutorialMove.skill]: la habilidad. [kTutorialQuebrar] = la
  /// Quebrar base del arma del que actúa.
  final String? skillId;

  /// Se repite (hasta [maxReps]) mientras el autómata no esté Fisurado.
  final bool untilFissured;
  final int maxReps;
}

/// Actúa el autómata (tick de estados, aviso o ULT).
class TutorialEnemyStep extends TutorialStep {
  const TutorialEnemyStep();
}

/// Turnos libres, sin guion: termina después de [actions] acciones de
/// jugadores.
class TutorialFreeStep extends TutorialStep {
  const TutorialFreeStep(this.actions);
  final int actions;
}

/// Id de paso que pide "la Quebrar base del arma del que actúa".
const kTutorialQuebrar = '@quebrar';

/// Preparación de la escena al empezar una etapa.
enum TutorialSetup { fresh, poisonPrimed, enemyUlt, adds }

/// Una etapa del guion (§ 4.2).
class TutorialStage {
  const TutorialStage({
    required this.number,
    required this.title,
    required this.teaches,
    required this.desde,
    required this.steps,
    this.setup = TutorialSetup.fresh,
  });

  final int number;
  final String title;

  /// Qué enseña (texto mecánico, sin lore).
  final String teaches;

  /// Versión del combate en la que apareció o cambió de verdad (§ 2).
  final int desde;
  final List<TutorialStep> steps;
  final TutorialSetup setup;
}

/// El cartel de efecto (2-3 líneas) o el de inicio de etapa.
class TutorialCard {
  const TutorialCard(this.lines,
      {this.arrow, this.targetId, this.actorId, this.effect = false});

  /// Cartel de efecto (al cerrarse avanza el paso); `false` = cartel de
  /// inicio de etapa.
  final bool effect;

  final List<String> lines;
  final TutorialArrow? arrow;

  /// A quién apunta la flecha (combatiente).
  final String? targetId;

  /// Quién actuó: el paso avanza cuando él lo cierra (o a los 6 s). `null`
  /// = cualquiera de la sala.
  final String? actorId;

  Map<String, Object?> toJson() => {
        'l': lines,
        if (arrow != null) 'a': arrow!.name,
        if (targetId != null) 'tg': targetId,
        if (actorId != null) 'by': actorId,
        if (effect) 'e': true,
      };

  static TutorialCard fromJson(Map<String, Object?> j) => TutorialCard(
        [for (final x in (j['l'] as List? ?? const [])) '$x'],
        arrow: _enum(j['a'], TutorialArrow.values),
        targetId: j['tg'] as String?,
        actorId: j['by'] as String?,
        effect: j['e'] == true,
      );
}

/// `TutorialState { paso, rol por jugador, intento }` (§ 4.1).
class TutorialState {
  TutorialState({
    required this.attempt,
    required List<int> stages,
    required List<String> order,
    this.stage = 0,
    this.step = 0,
    this.reps = 0,
    this.freeLeft = 0,
    this.card,
    this.cardLeft = 0,
    this.fromVersion = 0,
    this.prepared = false,
  })  : stages = List.unmodifiable(stages),
        order = List.unmodifiable(order);

  /// Intento (1, 2...): rota los roles (§ 4.3).
  final int attempt;

  /// Números de etapa que se juegan (completo o solo las de cambios + la
  /// libre, § 2).
  final List<int> stages;

  /// Jugadores del tutorial en orden (humanos y compañeros). El rol de
  /// cada uno sale de su índice y del [attempt].
  final List<String> order;

  /// Índice en [stages] y paso dentro de la etapa.
  int stage;
  int step;

  /// Veces que se repitió el paso actual (`untilFissured`).
  int reps;

  /// Acciones que quedan en la etapa libre.
  int freeLeft;

  /// Cartel abierto (el paso no avanza hasta que se cierra).
  TutorialCard? card;

  /// Segundos que le quedan al cartel (se cierra solo a los 6 s).
  double cardLeft;

  /// La menor `tutV` del grupo al empezar: > 0 = tutorial de cambios.
  final int fromVersion;

  /// El paso actual ya se preparó (turno acomodado, recursos repuestos).
  bool prepared;

  /// Seguimos en la etapa [stage] (`false` = terminó todo).
  bool get running => stage < stages.length;

  TutorialState copy() => TutorialState(
        attempt: attempt,
        stages: stages,
        order: order,
        stage: stage,
        step: step,
        reps: reps,
        freeLeft: freeLeft,
        card: card,
        cardLeft: cardLeft,
        fromVersion: fromVersion,
        prepared: prepared,
      );

  Map<String, Object?> toJson() => {
        'a': attempt,
        'st': stages,
        'o': order,
        'i': stage,
        's': step,
        if (reps != 0) 'r': reps,
        if (freeLeft != 0) 'f': freeLeft,
        if (card != null) 'c': card!.toJson(),
        if (cardLeft != 0) 'cl': cardLeft,
        if (fromVersion != 0) 'fv': fromVersion,
        if (prepared) 'p': true,
      };

  static TutorialState fromJson(Map<String, Object?> j) => TutorialState(
        attempt: (j['a'] as num?)?.toInt() ?? 1,
        stages: [
          for (final x in (j['st'] as List? ?? const [])) (x as num).toInt()
        ],
        order: [for (final x in (j['o'] as List? ?? const [])) '$x'],
        stage: (j['i'] as num?)?.toInt() ?? 0,
        step: (j['s'] as num?)?.toInt() ?? 0,
        reps: (j['r'] as num?)?.toInt() ?? 0,
        freeLeft: (j['f'] as num?)?.toInt() ?? 0,
        card: j['c'] is Map
            ? TutorialCard.fromJson(Map<String, Object?>.from(j['c'] as Map))
            : null,
        cardLeft: (j['cl'] as num?)?.toDouble() ?? 0,
        fromVersion: (j['fv'] as num?)?.toInt() ?? 0,
        prepared: j['p'] == true,
      );
}

T? _enum<T extends Enum>(Object? name, List<T> values) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
