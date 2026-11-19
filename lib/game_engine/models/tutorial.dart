// TUTORIAL: Ecos de práctica (docs/specs/combat_tutorial.md).
//
// El estado del guion lo lleva el host y viaja en el snapshot (`tut` de
// la sesión, § 4.1): todos ven el mismo paso, el mismo cartel y el mismo
// resaltado. Mutable como el resto de `GameSession` (el motor trabaja
// sobre una copia).

/// Versión vigente del tutorial: el máximo de las `desde` de
/// `kTutorialStages` (combat_tutorial.md § 2). Solo se sube cuando cambia
/// el combate básico (un ajuste de números no la cambia). 2 desde v0.9.6:
/// etapas rehechas (todos actúan en cada etapa, reinicio por etapa). 3
/// desde v0.9.7: sin roles; cada jugador prueba todo él mismo.
const kTutorialVersion = 3;

/// En qué parte del tutorial está la sala (§ 4.4).
enum TutorialPhase {
  /// Etapas con guion.
  script,

  /// Terminó el guion: votación "Repetir tutorial" / "ENTRENAR" /
  /// "Salir".
  menu,

  /// ENTRENAR: libre, kit de entrenamiento, el autómata puede caer.
  train,

  /// El autómata cayó en ENTRENAR: votación "Reiniciar" / "Salir".
  trainOver,
}

/// Qué se puede hacer en un paso del guion (§ 4.2).
enum TutorialMove { attack, skill, defend, pass }

/// Hacia dónde apunta la flecha del cartel de efecto (§ 4.1).
enum TutorialArrow { timeline, hp, mp, pulse, status, breakBar, ult }

/// Cómo se reparten los pasos de una etapa entre los jugadores (§ 4.2).
enum TutorialStageKind {
  /// `head` una vez, `steps` cada jugador en orden, `tail` una vez.
  each,

  /// Convergencia en parejas: el jugador i pone, el i+1 detona (§ 4.3).
  pairs,

  /// Quiebre: `steps` cada jugador y `tail` (barra llena, Fisurado);
  /// después, por jugador, reinicio, barra llena sola y quiebra él.
  breakEach,
}

/// Un paso del guion.
sealed class TutorialStep {
  const TutorialStep();
}

/// Actúa un jugador (el que le toca según la etapa): solo [move] (y
/// [skillId] o [alt]) está habilitado.
class TutorialPlayerStep extends TutorialStep {
  const TutorialPlayerStep(this.move, {this.skillId, this.alt, this.why});
  final TutorialMove move;

  /// Otra habilidad que también vale (quebrar con una habilidad que
  /// "puede quebrar" en vez de Quebrar).
  final String? alt;

  /// Para qué sirve el paso ("el ataque básico da +1 Pulso"): todos
  /// actúan en cada etapa y cada uno sabe por qué (§ 4.2).
  final String? why;

  /// Con [TutorialMove.skill]: la habilidad. [kTutorialQuebrar] = la
  /// Quebrar base del arma del que actúa.
  final String? skillId;
}

/// Actúa el autómata (tick de estados, aviso o ULT).
class TutorialEnemyStep extends TutorialStep {
  const TutorialEnemyStep();
}

/// El autómata vuelve a como al empezar y se prepara [setup] (entre
/// parejas de Convergencia). Automático, sin cartel.
class TutorialResetStep extends TutorialStep {
  const TutorialResetStep(this.setup);
  final TutorialSetup setup;
}

/// La barra de quiebre se llena sola hasta Fisurado (con [reset], antes
/// se reinicia el autómata). Automático, con cartel.
class TutorialFillStep extends TutorialStep {
  const TutorialFillStep({this.reset = false});
  final bool reset;
}

/// Un paso de la etapa ya repartido: [actor] es el índice en
/// `TutorialState.order` (`null` = nadie: autómata o paso automático).
class TutorialTurn {
  const TutorialTurn(this.step, [this.actor]);
  final TutorialStep step;
  final int? actor;
}

/// Id de paso que pide "la Quebrar base del arma del que actúa".
const kTutorialQuebrar = '@quebrar';

/// Preparación de la escena al empezar una etapa.
enum TutorialSetup { fresh, poisonPrimed, burnPrimed, enemyUlt, adds }

/// Una etapa del guion (§ 4.2).
class TutorialStage {
  const TutorialStage({
    required this.number,
    required this.title,
    required this.teaches,
    required this.desde,
    required this.steps,
    this.head = const [],
    this.tail = const [],
    this.kind = TutorialStageKind.each,
    this.setup = TutorialSetup.fresh,
  });

  final int number;
  final String title;

  /// Qué enseña (texto mecánico, sin lore).
  final String teaches;

  /// Versión del combate en la que apareció o cambió de verdad (§ 2).
  final int desde;

  /// Lo que hace cada jugador, en su turno (todos lo prueban).
  final List<TutorialStep> steps;

  /// Una vez antes y una vez después de la ronda de [steps].
  final List<TutorialStep> head;
  final List<TutorialStep> tail;
  final TutorialStageKind kind;
  final TutorialSetup setup;
}

/// El cartel de efecto (2-3 líneas) o el de inicio de etapa.
class TutorialCard {
  const TutorialCard(this.lines,
      {this.arrow,
      this.targetId,
      this.actorId,
      this.effect = false,
      this.heading});

  /// Rótulo del cartel en el panel ("ATENCIÓN" antes de que actúe el
  /// autómata); `null` = el de siempre.
  final String? heading;

  /// Cartel de efecto (al cerrarse avanza el paso); `false` = cartel de
  /// inicio de etapa.
  final bool effect;

  final List<String> lines;
  final TutorialArrow? arrow;

  /// A quién apunta la flecha (combatiente).
  final String? targetId;

  /// Quién actuó (`null` = el autómata o un cartel de etapa). El cartel
  /// se cierra por votación de todos los humanos, no por quien actuó.
  final String? actorId;

  Map<String, Object?> toJson() => {
        'l': lines,
        if (arrow != null) 'a': arrow!.name,
        if (targetId != null) 'tg': targetId,
        if (actorId != null) 'by': actorId,
        if (effect) 'e': true,
        if (heading != null) 'h': heading,
      };

  static TutorialCard fromJson(Map<String, Object?> j) => TutorialCard(
        [for (final x in (j['l'] as List? ?? const [])) '$x'],
        arrow: _enum(j['a'], TutorialArrow.values),
        targetId: j['tg'] as String?,
        actorId: j['by'] as String?,
        effect: j['e'] == true,
        heading: j['h'] as String?,
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
    this.phase = TutorialPhase.script,
    this.card,
    this.last,
    Set<String>? votes,
    Set<String>? said,
    this.fromVersion = 0,
    this.prepared = false,
    Map<String, String>? picks,
    List<String>? narration,
    Map<String, String>? primers,
  })  : stages = List.unmodifiable(stages),
        order = List.unmodifiable(order),
        votes = votes ?? <String>{},
        said = said ?? <String>{},
        picks = picks ?? <String, String>{},
        narration = narration ?? <String>[],
        primers = primers ?? <String, String>{};

  /// Intento (1, 2...).
  final int attempt;

  /// Números de etapa que se juegan (completo o solo las de cambios + la
  /// libre, § 2).
  final List<int> stages;

  /// Jugadores del tutorial en orden (humanos y compañeros): en cada
  /// etapa actúan en este orden y arman las parejas (§ 4.3).
  final List<String> order;

  /// Índice en [stages] y paso dentro de la etapa.
  int stage;
  int step;

  /// Reservado (antes: repeticiones de un paso); siempre 0.
  int reps;

  /// Guion, votaciones del final o ENTRENAR (§ 4.4).
  TutorialPhase phase;

  /// Lo que eligió cada humano en la votación abierta (`repeat`,
  /// `train`, `exit` o `restart`).
  final Map<String, String> picks;

  /// ENTRENAR: lo que narra el panel (las últimas líneas).
  final List<String> narration;

  /// ENTRENAR: quién puso por última vez cada estado (por nombre del
  /// estado), para narrar las Convergencias entre jugadores.
  final Map<String, String> primers;

  /// Cartel abierto (el paso no avanza hasta que todos los humanos de la
  /// sala tocan SIGUIENTE, § 4.1). No se cierra por tiempo.
  TutorialCard? card;

  /// El último cartel de efecto (el panel lo sigue mostrando como "lo que
  /// pasó" después de cerrarse).
  TutorialCard? last;

  /// Humanos que ya tocaron SIGUIENTE en el cartel abierto.
  final Set<String> votes;

  /// Conceptos que el cartel de efecto ya explicó en este intento (la
  /// segunda vez dice solo el dato, sin la explicación).
  final Set<String> said;

  /// La menor `tutV` del grupo al empezar: > 0 = tutorial de cambios.
  final int fromVersion;

  /// El paso actual ya se preparó (turno acomodado, recursos repuestos).
  bool prepared;

  /// Seguimos en la etapa [stage] (`false` = terminó todo).
  bool get running => phase == TutorialPhase.script && stage < stages.length;

  TutorialState copy() => TutorialState(
        attempt: attempt,
        stages: stages,
        order: order,
        stage: stage,
        step: step,
        reps: reps,
        phase: phase,
        card: card,
        last: last,
        votes: {...votes},
        said: {...said},
        fromVersion: fromVersion,
        prepared: prepared,
        picks: {...picks},
        narration: [...narration],
        primers: {...primers},
      );

  Map<String, Object?> toJson() => {
        'a': attempt,
        'st': stages,
        'o': order,
        'i': stage,
        's': step,
        if (reps != 0) 'r': reps,
        if (phase != TutorialPhase.script) 'ph': phase.name,
        if (picks.isNotEmpty) 'pk': picks,
        if (narration.isNotEmpty) 'nr': narration,
        if (primers.isNotEmpty) 'pr': primers,
        if (card != null) 'c': card!.toJson(),
        if (last != null) 'la': last!.toJson(),
        if (votes.isNotEmpty) 'v': votes.toList(),
        if (said.isNotEmpty) 'sd': said.toList(),
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
        phase: _enum(j['ph'], TutorialPhase.values) ?? TutorialPhase.script,
        picks: _strMap(j['pk']),
        narration: [for (final x in (j['nr'] as List? ?? const [])) '$x'],
        primers: _strMap(j['pr']),
        card: j['c'] is Map
            ? TutorialCard.fromJson(Map<String, Object?>.from(j['c'] as Map))
            : null,
        last: j['la'] is Map
            ? TutorialCard.fromJson(Map<String, Object?>.from(j['la'] as Map))
            : null,
        votes: {for (final x in (j['v'] as List? ?? const [])) '$x'},
        said: {for (final x in (j['sd'] as List? ?? const [])) '$x'},
        fromVersion: (j['fv'] as num?)?.toInt() ?? 0,
        prepared: j['p'] == true,
      );
}

Map<String, String> _strMap(Object? m) => m is Map
    ? {for (final e in m.entries) '${e.key}': '${e.value}'}
    : <String, String>{};

T? _enum<T extends Enum>(Object? name, List<T> values) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
