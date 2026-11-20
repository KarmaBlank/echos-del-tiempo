import 'dart:math' as math;

import '../data/enemy_families.dart';
import '../data/game_catalog.dart';
import '../data/skills_catalog.dart';
import '../models/battle_command.dart';
import '../models/battle_event.dart';
import '../models/battle_state.dart';
import '../models/elements.dart';
import '../models/game_session.dart';
import '../models/skill.dart';
import '../models/status.dart';
import '../models/tutorial.dart';
import 'battle_engine.dart';
import 'skill_requirements.dart';

export '../models/tutorial.dart';

// Habilidades del catálogo que el guion presta (§ 3): las mismas que usa
// el combate, así sus números y textos salen de los datos.
const _fuego = 'bola'; // Bola de Fuego: Fuego + Quemadura
const _fisico = 'embestida'; // Embestida: física, mucho quiebre
const _instante = 'puaEco'; // Púa Fugaz: Instante + Veneno
const _detonaVeneno = 'ignicionEco'; // Ignición Convergente (pide Veneno)
const _detonaQuemadura = 'ponzonaEco'; // Ponzoña Convergente (pide Quemadura)
const _area = 'llamarada'; // Llamarada: a todos + Quemadura
const _hielo = 'lanzaH'; // Lanza de Hielo: Hielo + Congelación
const _pulso = 'rompearmaduras'; // Rompearmaduras: cuesta 1 de Pulso
const _quiebra = 'estocada'; // Estocada Firme: "puede quebrar"

/// El kit de tutorial (§ 3, v0.9.7): igual para todos, con todo lo que
/// piden las etapas. Quebrar (la del arma) va al final.
const List<String> kTutorialSkills = [
  _fuego,
  _instante,
  _pulso,
  _fisico,
  _quiebra,
  _detonaQuemadura,
  _detonaVeneno,
  _area,
];

/// Stats y arma del kit de práctica (§ 3): iguales para todos, sea cual
/// sea la clase, el arma, el árbol o el equipo del personaje.
class TutorialKit {
  const TutorialKit({
    required this.hp,
    required this.mp,
    required this.speed,
    required this.attack,
    required this.magic,
    required this.defense,
    required this.weaponType,
  });

  final int hp;
  final int mp;
  final double speed;
  final int attack;
  final int magic;
  final int defense;

  /// Tipo de arma (física: la Quebrar es la física).
  final String weaponType;
}

const kTutorialKit = TutorialKit(
  hp: 150,
  mp: 40,
  speed: 10,
  attack: 18,
  magic: 18,
  defense: 4,
  weaponType: 'espada',
);

const _defend = TutorialPlayerStep(TutorialMove.defend,
    why: 'tu próximo turno llega antes en la barra de turnos');

/// Las 10 etapas del § 4.2 (después, la votación del § 4.4). Cada
/// jugador hace él mismo lo que enseña la etapa, en su turno.
const List<TutorialStage> kTutorialStages = [
  TutorialStage(
    number: 1,
    title: 'Línea de tiempo',
    teaches: 'turnos, velocidad, Defender y Pasar',
    desde: 3,
    steps: [_defend],
  ),
  TutorialStage(
    number: 2,
    title: 'MP',
    teaches: 'MP (de toda la misión)',
    desde: 3,
    steps: [
      TutorialPlayerStep(TutorialMove.skill,
          skillId: _fuego, why: 'una habilidad gasta MP'),
    ],
  ),
  TutorialStage(
    number: 3,
    title: 'Pulso',
    teaches: 'ganar Pulso y gastarlo',
    desde: 3,
    steps: [
      TutorialPlayerStep(TutorialMove.attack,
          why: 'el ataque básico da +1 Pulso'),
      TutorialPlayerStep(TutorialMove.skill,
          skillId: _pulso, why: 'cuesta Pulso: mirá cómo bajan los pips'),
    ],
  ),
  TutorialStage(
    number: 4,
    title: 'Instante',
    teaches: 'habilidades Instante',
    desde: 3,
    steps: [
      TutorialPlayerStep(TutorialMove.skill,
          skillId: _instante, why: 'Instante: no termina tu turno'),
      TutorialPlayerStep(TutorialMove.attack,
          why: 'seguís en tu turno: otra acción'),
    ],
  ),
  TutorialStage(
    number: 5,
    title: 'Afinidades',
    teaches: 'debilidad y resistencia',
    desde: 3,
    steps: [
      TutorialPlayerStep(TutorialMove.attack,
          why: 'golpe físico: el autómata lo resiste'),
      TutorialPlayerStep(TutorialMove.skill,
          skillId: _fuego, why: 'Fuego: su debilidad (+1 Pulso)'),
    ],
  ),
  TutorialStage(
    number: 6,
    title: 'Estados',
    teaches: 'estados, stacks y duración',
    desde: 3,
    steps: [
      TutorialPlayerStep(TutorialMove.skill,
          skillId: _fuego, why: 'pone Quemadura: los stacks se suman'),
    ],
    tail: [TutorialEnemyStep()],
  ),
  TutorialStage(
    number: 7,
    title: 'Convergencia en parejas',
    teaches: 'uno pone el estado y otro lo detona',
    desde: 3,
    kind: TutorialStageKind.pairs,
    steps: [],
  ),
  TutorialStage(
    number: 8,
    title: 'Quiebre',
    teaches: 'barra de quiebre, Fisurado, Quebrar y quebrado',
    desde: 3,
    kind: TutorialStageKind.breakEach,
    steps: [
      TutorialPlayerStep(TutorialMove.skill,
          skillId: _fisico, why: 'Embestida llena la barra de quiebre'),
    ],
    tail: [TutorialFillStep()],
  ),
  TutorialStage(
    number: 9,
    title: 'ULT enemiga',
    teaches: 'aviso, cancelar y defender',
    desde: 3,
    setup: TutorialSetup.enemyUlt,
    head: [TutorialEnemyStep()],
    steps: [
      TutorialPlayerStep(TutorialMove.defend,
          why: 'viene la ULT avisada: Defender baja el daño a la mitad'),
    ],
    tail: [TutorialEnemyStep()],
  ),
  TutorialStage(
    number: 10,
    title: 'Área',
    teaches: 'área para preparar y salpicadura',
    desde: 3,
    setup: TutorialSetup.adds,
    steps: [
      TutorialPlayerStep(TutorialMove.skill,
          skillId: _area, why: 'un área pone Quemadura a todos'),
      TutorialPlayerStep(TutorialMove.skill,
          skillId: _detonaQuemadura,
          why: 'la Convergencia salpica a los demás'),
    ],
  ),
];

/// Los pasos de la pareja [i] de la Convergencia (§ 4.3): [primer]
/// pone, [detonator] detona. Las pares usan Quemadura; las impares,
/// Veneno. Antes se reinicia el autómata con lo justo para que el que
/// pone complete lo que pide la detonación.
List<TutorialTurn> convergencePair(int i, int primer, int detonator) {
  final burn = i.isEven;
  return [
    TutorialTurn(TutorialResetStep(
        burn ? TutorialSetup.burnPrimed : TutorialSetup.poisonPrimed)),
    TutorialTurn(
        TutorialPlayerStep(TutorialMove.skill,
            skillId: burn ? _fuego : _instante,
            why: burn
                ? 'poné Quemadura para que detone tu pareja'
                : 'poné Veneno para que detone tu pareja'),
        primer),
    TutorialTurn(
        TutorialPlayerStep(TutorialMove.skill,
            skillId: burn ? _detonaQuemadura : _detonaVeneno,
            why: burn
                ? 'Veneno sobre Quemadura: detonás la Convergencia'
                : 'Fuego sobre Veneno: detonás la Convergencia'),
        detonator),
  ];
}

/// El paso de quiebre de cada jugador: Quebrar o una habilidad que
/// "puede quebrar".
const kTutorialBreakStep = TutorialPlayerStep(TutorialMove.skill,
    skillId: kTutorialQuebrar,
    alt: _quiebra,
    why: 'está Fisurado: Quebrar o una que "puede quebrar"');

/// Un kit básico de ENTRENAR (§ 4.4): no es de rol. Entre los 4 está todo
/// lo que hay que probar: Quebrar, Quemadura y Veneno (Combustión y
/// Explosión tóxica entre jugadores distintos), un Instante, algo que
/// congela y la ULT cargada.
class TrainingKit {
  const TrainingKit(this.skills, {this.ult = false});
  final List<String> skills;

  /// Arranca con la ULT cargada.
  final bool ult;
}

const List<TrainingKit> kTrainingKits = [
  TrainingKit([_fuego, _area]), // Quemadura (y área)
  TrainingKit([_instante, _detonaVeneno]), // Instante + Veneno; Explosión tóxica
  TrainingKit([_hielo, _fisico], ult: true), // Congelación; ULT
  TrainingKit([_detonaQuemadura, kQuebrarId]), // Combustión; Quebrar
];

/// Una entrada del glosario (§ 5).
class GlossaryEntry {
  const GlossaryEntry(this.icon, this.title, this.text);

  /// Sigla corta para el ícono (las fuentes pixel no tienen símbolos).
  final String icon;
  final String title;
  final String text;
}

/// Qué muestra el cartel de arriba para un jugador (§ 4.1).
class TutorialBanner {
  const TutorialBanner(this.text, {this.yourTurn = false, this.stage = ''});

  /// "TE TOCA: …" / "MIRÁ: …".
  final String text;
  final bool yourTurn;

  /// "Etapa 3/10 · Afinidades".
  final String stage;
}

/// Reglas del TUTORIAL: Ecos de práctica (docs/specs/combat_tutorial.md).
/// Dart puro: el host las usa para llevar el guion; la UI, para el
/// cartel, los botones desactivados y el glosario.
class TutorialRules {
  const TutorialRules({
    this.catalog = GameCatalog.standard,
    this.stages = kTutorialStages,
    this.version = kTutorialVersion,
  });

  final GameCatalog catalog;
  final List<TutorialStage> stages;
  final int version;

  /// Id de la misión en el sello (no está en el catálogo de misiones).
  static const missionId = 'tutorial';
  static const name = 'TUTORIAL: Ecos de práctica';


  /// Lo que espera un compañero (IA) antes de hacer su rol.
  static const companionDelay = 0.8;

  /// Ids de los autómatas.
  static const bossId = 'e0';

  /// Tipo de enemigo cuyo dibujo usan los autómatas.
  static const spriteType = 'golem';

  // ---------------------------------------------------------------
  // Bandera y sello (§ 2)
  // ---------------------------------------------------------------

  bool upToDate(int tutV) => tutV >= version;

  // ---------------------------------------------------------------
  // Votación SIGUIENTE (§ 4.1)
  // ---------------------------------------------------------------

  /// Los que votan: los humanos de la sala (los compañeros IA no votan;
  /// quien se desconecta sale de la sala y deja de contarse).
  List<SessionPlayer> voters(GameSession s) =>
      [for (final p in s.playerList) if (!p.isCompanion) p];

  /// Los humanos que todavía no tocaron SIGUIENTE en el cartel abierto.
  List<SessionPlayer> waiting(GameSession s) {
    final t = s.tutorial;
    if (t == null || t.card == null) return const [];
    return [
      for (final p in voters(s))
        if (!t.votes.contains(p.id)) p
    ];
  }

  /// "Esperando: Beto", o `null` si no hay cartel abierto.
  String? waitingText(GameSession s) {
    if (s.tutorial?.card == null) return null;
    final w = waiting(s);
    if (w.isEmpty) return null;
    return 'Esperando: ${w.map((p) => p.name).join(', ')}';
  }

  /// Qué resaltar en el HUD del grupo (§ 4.1): la barra de MP y los pips
  /// de Pulso en la etapa que los explica y cuando la acción los cambió.
  Set<TutorialArrow> hudFocus(TutorialState t) {
    final out = <TutorialArrow>{};
    final a = t.card?.arrow;
    if (a == TutorialArrow.mp || a == TutorialArrow.pulse) out.add(a!);
    for (final l in t.card?.lines ?? const <String>[]) {
      if (l.contains('MP')) out.add(TutorialArrow.mp);
      if (l.contains('Pulso')) out.add(TutorialArrow.pulse);
    }
    final st = currentStage(t);
    if (st?.number == 2) out.add(TutorialArrow.mp);
    if (st?.number == 3 || st?.number == 7 || st?.number == 8) {
      out.add(TutorialArrow.pulse);
    }
    return out;
  }

  /// Los humanos de la sala sin el tutorial vigente.
  List<SessionPlayer> missing(GameSession s) => [
        for (final p in s.playerList)
          if (!p.isCompanion && !upToDate(p.tutorialVersion)) p,
      ];

  /// "Primero, todos tienen que hacer el TUTORIAL. Falta: Ana, Beto", o
  /// `null` si todos lo tienen.
  String? lockText(GameSession s) {
    final m = missing(s);
    if (m.isEmpty) return null;
    return 'Primero, todos tienen que hacer el TUTORIAL. '
        'Falta: ${m.map((p) => p.name).join(', ')}';
  }

  /// Las etapas que se juegan si la menor `tutV` del grupo es [minTutV]:
  /// completo con 0 (o si todos lo tienen: Repetir); si no, solo las
  /// etapas nuevas (después vienen la votación y ENTRENAR, § 4.4).
  List<int> stagesFor(int minTutV) {
    final changed = [
      for (final s in stages)
        if (s.desde > minTutV) s.number,
    ];
    if (minTutV <= 0 || minTutV >= version || changed.isEmpty) {
      return [for (final s in stages) s.number];
    }
    return changed;
  }

  TutorialStage stageDef(int number) =>
      stages.firstWhere((s) => s.number == number);

  TutorialStage? currentStage(TutorialState t) =>
      t.running ? stageDef(t.stages[t.stage]) : null;

  /// Los pasos de [st] repartidos entre los [players] jugadores de
  /// `order` (§ 4.2 y § 4.3).
  List<TutorialTurn> turnsOf(TutorialStage st, int players) {
    final n = math.max(1, players);
    final out = <TutorialTurn>[
      for (final x in st.head) TutorialTurn(x),
    ];
    for (var i = 0; i < n; i++) {
      for (final x in st.steps) {
        out.add(TutorialTurn(x, i));
      }
    }
    for (final x in st.tail) {
      out.add(TutorialTurn(x));
    }
    switch (st.kind) {
      case TutorialStageKind.each:
        break;
      case TutorialStageKind.pairs:
        // Rueda: i pone, i+1 detona; así todos ponen y todos detonan (con
        // 1 solo, él pone y él detona).
        for (var i = 0; i < n; i++) {
          out.addAll(convergencePair(i, i, (i + 1) % n));
        }
      case TutorialStageKind.breakEach:
        for (var i = 0; i < n; i++) {
          out
            ..add(const TutorialTurn(TutorialFillStep(reset: true)))
            ..add(TutorialTurn(kTutorialBreakStep, i));
        }
    }
    return out;
  }

  List<TutorialTurn> currentTurns(TutorialState t) {
    final st = currentStage(t);
    return st == null ? const [] : turnsOf(st, t.order.length);
  }

  TutorialTurn? currentTurn(TutorialState t) {
    final ts = currentTurns(t);
    return t.step < ts.length ? ts[t.step] : null;
  }

  TutorialStep? currentStep(TutorialState t) => currentTurn(t)?.step;

  /// Quién hace el paso actual (`null` = el autómata, un paso automático
  /// o alguien que ya no está en [present]).
  String? currentActor(TutorialState t, [Set<String>? present]) {
    final i = currentTurn(t)?.actor;
    if (i == null || i >= t.order.length) return null;
    final id = t.order[i];
    return present == null || present.contains(id) ? id : null;
  }

  // ---------------------------------------------------------------
  // Batalla de práctica (§ 3)
  // ---------------------------------------------------------------

  /// La habilidad real de un paso para [actor] (Quebrar según su arma).
  String? skillFor(TutorialPlayerStep st, Combatant actor) =>
      st.skillId == kTutorialQuebrar
          ? quebrarSkillFor(actor.weaponType)
          : st.skillId;

  /// El kit de tutorial (§ 3): el mismo para todos.
  List<String> kitSkills() =>
      [...kTutorialSkills, quebrarSkillFor(kTutorialKit.weaponType)];

  /// Cambia a [c] por su kit de práctica (§ 3): la build del jugador
  /// (clase, arma, árbol, equipo, ascensión) no existe en el tutorial.
  /// Solo se conserva quién es y su dibujo. La build real no se toca:
  /// la batalla se descarta al salir.
  Combatant kitOf(Combatant c, TutorialState t, Set<String> present) {
    const k = kTutorialKit;
    final train = t.phase == TutorialPhase.train ||
        t.phase == TutorialPhase.trainOver;
    final kit = train ? trainingKitFor(t, c.id, present) : null;
    return Combatant(
      id: c.id,
      name: c.name,
      isPlayer: true,
      hp: k.hp,
      maxHp: k.hp,
      mp: k.mp.toDouble(),
      maxMp: k.mp,
      speed: k.speed,
      attack: k.attack,
      magic: k.magic,
      defense: k.defense,
      critChance: 0,
      classId: c.classId, // solo el dibujo
      level: c.build?.level ?? c.level, // solo el cartel
      weaponType: k.weaponType,
      skillIds: kit?.skills ?? kitSkills(),
      nextTurn: c.nextTurn,
      pulse: BattleEngine.pulseStart,
      practice: true,
    )..ult = kit?.ult == true ? 100 : 0;
  }

  /// El kit de ENTRENAR de [id] (§ 4.4): el jugador i de n suma los kits
  /// j con j mod n = i, así entre todos (o uno solo) está todo.
  TrainingKit trainingKitFor(TutorialState t, String id, Set<String> present) {
    final order = [
      for (final x in t.order)
        if (present.contains(x)) x
    ];
    for (final x in present) {
      if (!order.contains(x)) order.add(x);
    }
    final n = math.max(1, order.length);
    final i = math.max(0, order.indexOf(id));
    final skills = <String>[];
    var ult = false;
    for (var j = 0; j < kTrainingKits.length; j++) {
      if (j % n != i) continue;
      for (final sk in kTrainingKits[j].skills) {
        final real = sk == kQuebrarId ? quebrarSkillFor(kTutorialKit.weaponType) : sk;
        if (!skills.contains(real)) skills.add(real);
      }
      ult = ult || kTrainingKits[j].ult;
    }
    // Más de 4: los que sobran reciben lo básico.
    return skills.isEmpty
        ? const TrainingKit([_fuego, _fisico])
        : TrainingKit(skills, ult: ult);
  }

  /// Pone el kit a [id] dentro de [b] (al armar la pelea o si alguien se
  /// une a la mitad).
  void applyKit(BattleState b, TutorialState t, String id) {
    final present = {for (final c in b.party) c.id};
    final i = b.party.indexWhere((c) => c.id == id);
    if (i >= 0) b.party[i] = kitOf(b.party[i], t, present);
  }

  /// Arma la pelea de práctica sobre [started] (`BattleEngine.start` con
  /// el grupo): cambia los enemigos por el Autómata de entrenamiento y a
  /// cada personaje (humano o compañero) por su kit de práctica.
  void setUpBattle(BattleState started, TutorialState t) {
    for (final id in [for (final c in started.party) c.id]) {
      applyKit(started, t, id);
    }
    final n = math.max(1, started.party.length);
    started.enemies
      ..clear()
      ..add(automaton(n));
    started.log = '$name: un autómata de entrenamiento, reliquia de una '
        'magia tecnológica del pasado.';
  }

  /// El Autómata de entrenamiento: mucha vida, débil al Fuego, resiste lo
  /// físico, con barra de quiebre y una ULT de práctica.
  Combatant automaton(int players) {
    final d = catalog.enemies[spriteType]!;
    final hp = 400 + 200 * players;
    return Combatant(
      id: bossId,
      name: 'Autómata de entrenamiento',
      isPlayer: false,
      hp: hp,
      maxHp: hp,
      speed: d.speed,
      attack: 6,
      critChance: 0,
      enemyType: spriteType,
      boss: true,
      family: EnemyFamily.training,
      breakBase: d.breakMax * catalog.combo.groupBreak(players),
      ultId:
          catalog.enemyUlts.containsKey('eult_diluvio') ? 'eult_diluvio' : null,
      nextTurn: 100 / d.speed,
      practice: true,
    );
  }

  /// Un Autómata chico (etapa 9): se repone solo.
  Combatant smallAutomaton(String id, BattleState b) {
    final d = catalog.enemies[spriteType]!;
    return Combatant(
      id: id,
      name: 'Autómata chico',
      isPlayer: false,
      hp: 120,
      maxHp: 120,
      speed: d.speed * 0.8,
      attack: 3,
      critChance: 0,
      enemyType: spriteType,
      family: EnemyFamily.training,
      nextTurn: b.clock + 200 / d.speed,
      practice: true,
    );
  }

  /// Prepara la escena de la etapa [st]: los autómatas se reponen, la
  /// barra y los estados vuelven a cero, y lo propio de la etapa.
  void setUpStage(BattleState b, TutorialStage st) {
    // Cada etapa arranca limpia (v0.9.6, § 4.2): el autómata, la línea de
    // tiempo y los recursos vuelven a cero, así el caso siempre es claro.
    b.enemies.removeWhere(
        (e) => e.id != bossId && st.setup != TutorialSetup.adds);
    final hasAdds = b.enemies.length > 1;
    resetCombatants(b);
    applySetup(b, st.setup, hasAdds: hasAdds);
  }

  /// Lo propio de [setup] sobre la escena recién reiniciada.
  void applySetup(BattleState b, TutorialSetup setup, {bool hasAdds = true}) {
    final boss = b.byId(bossId)!;
    switch (setup) {
      case TutorialSetup.fresh:
        break;
      case TutorialSetup.poisonPrimed:
        // Detonar sale desactivado ("Necesita: 5 de Veneno") hasta que el
        // que pone sume lo que falta.
        final need = _requiredStacks(_detonaVeneno, StatusKind.poison);
        final adds = catalog.skills[_instante]?.status?.stacks ?? 0;
        boss.statuses[StatusKind.poison] = math.max(1, need - adds);
      case TutorialSetup.burnPrimed:
        final need = _requiredStacks(_detonaQuemadura, StatusKind.burn);
        final adds = catalog.skills[_fuego]?.status?.stacks ?? 0;
        boss.statuses[StatusKind.burn] = math.max(1, need - adds);
      case TutorialSetup.enemyUlt:
        boss.ult = 100;
      case TutorialSetup.adds:
        if (!hasAdds) {
          b.enemies
            ..add(smallAutomaton('e1', b))
            ..add(smallAutomaton('e2', b));
        }
    }
  }

  /// Vida, MP, Pulso, estados, barra de quiebre, ULT y línea de tiempo
  /// de todos a como al empezar.
  void resetCombatants(BattleState b) {
    for (final e in b.enemies) {
      e
        ..hp = e.maxHp
        ..statuses = {}
        ..breakGauge = 0
        ..fissured = false
        ..breakSkip = false
        ..vulnerable = 0
        ..ultPending = false
        ..ult = 0
        ..nextTurn = b.clock + 100 / e.speed;
    }
    for (final p in b.party) {
      p
        ..hp = p.maxHp
        ..mp = p.maxMp.toDouble()
        ..pulse = BattleEngine.pulseStart
        ..statuses = {}
        ..defending = false
        ..chained = false
        ..ult = 0
        ..nextTurn = b.clock + 100 / p.speed;
    }
    b.currentId = null;
  }

  int _requiredStacks(String skillId, StatusKind k) {
    for (final r in catalog.skills[skillId]?.requires ?? const <SkillReq>[]) {
      if (r.status == k) return r.amount;
    }
    return 0;
  }

  /// Antes de que [actor] haga [st]: le repone MP y Pulso, y cumple la
  /// precondición si el guion la necesita (si no, "me toca pero no me
  /// sale nada").
  void prepare(TutorialPlayerStep st, BattleState b, Combatant actor) {
    final id = skillFor(st, actor);
    final sk = id == null ? null : catalog.skills[id];
    if (sk == null) return;
    if (actor.mp < sk.mp) actor.mp = sk.mp.toDouble();
    if (actor.pulse < sk.pulse) actor.pulse = sk.pulse;
    final target = b.byId(bossId)!;
    for (final r in sk.requires) {
      switch (r.kind) {
        case SkillReqKind.targetStacks:
          if (target.stacks(r.status!) < r.amount) {
            target.statuses[r.status!] = r.amount;
          }
        case SkillReqKind.targetFissured:
          if (!target.fissured) {
            target
              ..fissured = true
              ..breakGauge = target.breakMax;
          }
        case SkillReqKind.targetMarked:
        case SkillReqKind.selfHpBelow:
          break;
      }
    }
  }

  // ---------------------------------------------------------------
  // Validación (§ 6) y botones (§ 4.1)
  // ---------------------------------------------------------------

  /// Si [cmd] de [playerId] es lo que pide el paso. Fuera de la etapa
  /// libre, cualquier otra cosa se rechaza.
  bool allows(
      TutorialState t, BattleState b, String playerId, BattleCommand cmd) {
    if (t.phase != TutorialPhase.script) return t.phase == TutorialPhase.train;
    final step = currentStep(t);
    if (step is! TutorialPlayerStep || t.card != null) return false;
    final present = {for (final c in b.party) c.id};
    if (currentActor(t, present) != playerId) return false;
    final actor = b.byId(playerId);
    if (actor == null) return false;
    final targetOk = switch (cmd) {
      AttackCommand(:final targetId) ||
      SkillCommand(:final targetId) =>
        targetId == null || targetId == bossId,
      _ => true,
    };
    return targetOk &&
        switch (step.move) {
          TutorialMove.attack => cmd is AttackCommand,
          TutorialMove.defend => cmd is DefendCommand,
          TutorialMove.pass => cmd is PassCommand,
          TutorialMove.skill =>
            cmd is SkillCommand &&
                (cmd.skillId == skillFor(step, actor) ||
                    (step.alt != null && cmd.skillId == step.alt)),
        };
  }

  /// El comando que pide el paso para [actor] (la IA de los compañeros y
  /// los tests lo usan).
  BattleCommand? scripted(TutorialPlayerStep st, Combatant actor) =>
      switch (st.move) {
        TutorialMove.attack => const AttackCommand(targetId: bossId),
        TutorialMove.defend => const DefendCommand(),
        TutorialMove.pass => const PassCommand(),
        TutorialMove.skill => SkillCommand(skillFor(st, actor)!,
            targetId: catalog.skills[skillFor(st, actor)]?.allTargets ?? false
                ? null
                : bossId),
      };

  /// Por qué la acción [actionId] del menú (`attack`, `skill-<id>`,
  /// `defend`, `pass`...) está desactivada en el tutorial, o `null` si es
  /// la del paso.
  String? gate(
      TutorialState t, BattleState b, String playerId, String actionId) {
    if (t.phase == TutorialPhase.train) return null;
    if (t.phase != TutorialPhase.script) return 'Ahora no: votá en el panel.';
    final step = currentStep(t);
    if (step is! TutorialPlayerStep) return 'Ahora no: mirá al autómata.';
    final actor = b.byId(playerId);
    if (actor == null) return 'Ahora no.';
    final want = switch (step.move) {
      TutorialMove.attack => 'attack',
      TutorialMove.defend => 'defend',
      TutorialMove.pass => 'pass',
      TutorialMove.skill => 'skill-${skillFor(step, actor)}',
    };
    return actionId == want ||
            (step.move == TutorialMove.skill &&
                step.alt != null &&
                actionId == 'skill-${step.alt}')
        ? null
        : 'Ahora no: el paso es ${doText(step, actor)}.';
  }

  /// "usá Bola de Fuego sobre el autómata".
  String doText(TutorialPlayerStep st, Combatant? actor) => switch (st.move) {
        TutorialMove.attack => 'Atacar al autómata',
        TutorialMove.defend => 'Defender',
        TutorialMove.pass => 'Pasar turno',
        TutorialMove.skill => () {
            final id = actor == null ? st.skillId : skillFor(st, actor);
            final sk = catalog.skills[id];
            final n = sk?.name ?? 'Quebrar';
            final alt = st.alt == null ? null : catalog.skills[st.alt]?.name;
            return sk?.allTargets ?? false
                ? 'usar $n (a todos)'
                : 'usar $n${alt == null ? '' : ' o $alt'} sobre el autómata';
          }(),
      };

  /// El cartel de arriba para quien controla [mine] (§ 4.1).
  TutorialBanner? banner(GameSession s, Set<String> mine) {
    final t = s.tutorial;
    final b = s.battle?.state;
    if (t == null || b == null) return null;
    switch (t.phase) {
      case TutorialPhase.menu:
        return const TutorialBanner(
            '¡Guion completo! Votá cómo seguir en el panel.',
            stage: 'Fin del guion');
      case TutorialPhase.train:
        return TutorialBanner(
            'ENTRENAR: probá lo que quieras; el autómata puede caer.',
            yourTurn: mine.contains(b.currentId),
            stage: 'ENTRENAR');
      case TutorialPhase.trainOver:
        return const TutorialBanner('¡El autómata cayó! Votá: Reiniciar o Salir.',
            stage: 'ENTRENAR');
      case TutorialPhase.script:
        break;
    }
    final st = currentStage(t);
    if (st == null) return const TutorialBanner('¡Guion completo!');
    final idx = t.stages.indexOf(st.number) + 1;
    final head = 'Etapa $idx/${t.stages.length} · ${st.title}';
    final step = currentStep(t);
    final present = {for (final c in b.party) c.id};
    switch (step) {
      case TutorialEnemyStep():
        return TutorialBanner('MIRÁ: actúa el autómata.', stage: head);
      case TutorialFillStep():
        return TutorialBanner('MIRÁ: la barra de quiebre se llena sola.',
            stage: head);
      case TutorialResetStep():
        return TutorialBanner('', stage: head);
      case TutorialPlayerStep():
        final id = currentActor(t, present);
        final actor = id == null ? null : b.byId(id);
        final what = doText(step, actor);
        final companion = id != null && s.players[id]?.isCompanion == true;
        if (id != null && mine.contains(id) && !companion) {
          return TutorialBanner(
              'TE TOCA: ${what[0].toLowerCase()}${what.substring(1)}'
              '${step.why == null ? '' : ' · ${step.why}'}',
              yourTurn: true,
              stage: head);
        }
        final who = actor?.name ?? '?';
        return TutorialBanner(
            'MIRÁ: $who${companion ? ' (IA)' : ''} va a '
            '${what[0].toLowerCase()}${what.substring(1)}'
            '${step.why == null ? '' : ' · ${step.why}'}',
            stage: head);
      case null:
        return TutorialBanner('', stage: head);
    }
  }

  // ---------------------------------------------------------------
  // Carteles (§ 4.1)
  // ---------------------------------------------------------------

  /// Las habilidades que gastan Pulso, leídas del catálogo (§ 5):
  /// "Quebrar (2), Ignición Convergente (2), …". Las de la misma
  /// familia de nombre (Quebrar / Quebrar arcano) van una vez.
  List<SkillDef> pulseSkills() {
    final seen = <String>{};
    return [
      for (final sk in catalog.skills.values)
        if (sk.pulse > 0 && seen.add(sk.name)) sk,
    ];
  }

  String pulseUsesText() =>
      pulseSkills().map((sk) => '${sk.name} (${sk.pulse})').join(', ');

  /// El cartel de inicio de una etapa.
  TutorialCard stageCard(TutorialState t, TutorialStage st,
      {required Map<String, String> names, required Set<String> present}) {
    final idx = t.stages.indexOf(st.number) + 1;
    final lines = <String>[];
    if (idx == 1 && t.fromVersion > 0 && t.fromVersion < version) {
      lines.add('Ya hiciste el tutorial. Esta pelea de prueba muestra lo que '
          'cambió en v$version: '
          '${[
        for (final n in t.stages) stageDef(n).title
      ].join(', ')}.');
    }
    lines.addAll(stageIntro(st.number));
    if (st.kind == TutorialStageKind.pairs) {
      final ids = [for (final id in t.order) names[id] ?? id];
      final n = ids.length;
      lines.add(n == 1
          ? 'Ponés vos y detonás vos.'
          : 'Parejas: ${[
              for (var i = 0; i < n; i++)
                '${ids[i]} pone, ${ids[(i + 1) % n]} detona'
            ].join('; ')}.');
    }
    return TutorialCard(lines, arrow: _introArrow(st.number));
  }

  TutorialArrow? _introArrow(int stage) => switch (stage) {
        1 => TutorialArrow.timeline,
        2 => TutorialArrow.mp,
        3 => TutorialArrow.pulse,
        4 => TutorialArrow.timeline,
        6 => TutorialArrow.status,
        8 => TutorialArrow.breakBar,
        9 => TutorialArrow.ult,
        _ => null,
      };

  String _skillName(String id) => catalog.skills[id]?.name ?? id;

  /// Lo que explica el cartel de inicio de cada etapa (§ 4.2): corto, sin
  /// repetir el título (el panel ya lo muestra) y con los números de los
  /// datos.
  List<String> stageIntro(int stage) {
    final quebrar = catalog.skills[kQuebrarId];
    return switch (stage) {
      1 => [
          'La barra de turnos (arriba) muestra quién sigue: con más '
              'velocidad, turnos más seguidos.',
          'Defender y Pasar adelantan tu próximo turno. Cada uno lo prueba '
              'en su turno.',
        ],
      2 => [
          'MP (barra azul): dura toda la misión. Lo gastan casi todas las '
              'habilidades y no vuelve solo entre peleas: se recupera con '
              'pociones o al volver al lobby.',
        ],
      3 => [
          'Pulso: puntos de cada pelea, de 0 a ${BattleEngine.pulseMax}; las '
              'habilidades fuertes lo piden.',
          '+1 al empezar tu turno, con ataque básico, golpe a la debilidad o '
              'reacción, y al defender.',
        ],
      4 => [
          'Instante no es un recurso: es un tipo de habilidad que no '
              'termina tu turno. Después hacés otra acción (una Instante '
              'por turno).',
        ],
      5 => [
          'El autómata resiste lo físico y es débil al Fuego: mirá el '
              'número de daño de cada golpe.',
        ],
      6 => [
          'Los estados se acumulan (stacks) y le hacen daño al empezar su '
              'turno.',
        ],
      7 => [
          'Uno pone un estado y su pareja lo detona: Veneno sobre '
              'Quemadura o Fuego sobre Veneno. Cuantos más stacks, más daño.',
          'Las detonaciones piden stacks (si faltan, el botón sale '
              'desactivado): el autómata ya tiene algunos y el que pone '
              'completa lo que falta.',
        ],
      8 => [
          'Los golpes llenan la barra de quiebre; llena, queda Fisurado. '
              'Primero la llenan entre todos.',
          'Después, cada uno quiebra: Quebrar viene de base (Pulso '
              '${quebrar?.pulse ?? 0}) y algunas habilidades también quiebran '
              '(dicen "puede quebrar", como ${_skillName(_quiebra)}).',
        ],
      9 => [
          'Los jefes avisan su ULT un turno antes. Quebrarlos la cancela; '
              'Defender baja el daño.',
        ],
      10 => [
          'Un área pone estados a todos; la Convergencia salpica a los '
              'demás.',
        ],
      _ => const [],
    };
  }

  /// El cartel de cuando la barra se llena sola (§ 4.2, etapa 8): la
  /// primera vez explica; después, solo el dato. [next]: quién quiebra
  /// (`null` = la barra la llenaron entre todos).
  TutorialCard fillCard(String? next, {Set<String>? said}) {
    final first = next != null && (said?.add('fill') ?? true);
    final lines = <String>[
      if (next == null)
        'La barra de quiebre se llenó: FISURADO. Un golpe que quiebra lo '
            'deja QUEBRADO.'
      else if (first)
        'Autómata reiniciado y barra llena sola: FISURADO. Ahora quiebra '
            '$next con Quebrar (viene de base) o con '
            '${_skillName(_quiebra)} ("puede quebrar").'
      else
        'Barra llena: FISURADO. Quiebra $next.',
    ];
    return TutorialCard(lines,
        arrow: TutorialArrow.breakBar, targetId: bossId, effect: true);
  }

  /// El cartel de efecto (2-3 líneas) de lo que pasó entre [before] y
  /// [after] con [events], con la flecha a lo que cambió.
  TutorialCard effectCard(BattleState before, BattleState after,
      List<BattleEvent> events, String? actorId,
      {BattleCommand? cmd, Set<String>? said}) {
    final lines = <String>[];
    TutorialArrow? arrow;
    String? target;
    void add(String line, TutorialArrow a, String? tg) {
      lines.add(line);
      arrow ??= a;
      target ??= tg;
    }

    final actor = actorId == null ? null : after.byId(actorId);
    final was = actorId == null ? null : before.byId(actorId);

    for (final ev in events) {
      switch (ev) {
        case ReactionEvent():
          final def = catalog.reaction(ev.kind);
          if (ev.kind.convergence && def.perStack > 0) {
            final pct = ev.consumedStacks * def.perStack * 100;
            add(
                '${ev.kind.label}: ${ev.consumedStacks} × '
                '${_fmt(def.perStack * 100)}% = ${_fmt(pct)}% de su vida '
                'máxima (${ev.amount} de daño)'
                '${ev.splash.isEmpty ? '' : '; salpica a ${ev.splash.length} más'}.',
                TutorialArrow.hp,
                ev.targetId);
          } else {
            add('Reacción: ${ev.kind.label} (${ev.amount} de daño).',
                TutorialArrow.hp, ev.targetId);
          }
        case EnemyUltWarningEvent():
          add(
              'El autómata avisa su ULT (${ev.name}): la lanza en su próximo '
              'turno. Quebrarlo antes la cancela; Defender baja el daño.',
              TutorialArrow.ult,
              ev.actorId);
        case EnemyUltEvent():
          add(
              'ULT de práctica: ${ev.name}. Pega poco y nunca deja a nadie '
              'por debajo de 1 de vida.',
              TutorialArrow.hp,
              null);
        case BreakEvent(cancelledUlt: true):
          add('¡El quiebre canceló la ULT avisada!', TutorialArrow.ult,
              ev.targetId);
        default:
          break;
      }
    }

    for (final e in after.enemies) {
      final o = before.byId(e.id);
      if (o == null) continue;
      if (e.vulnerable > o.vulnerable || (e.breakSkip && !o.breakSkip)) {
        add(
            said?.add('broken') ?? true
                ? '¡QUEBRADO! Pierde su turno y recibe '
                    '+${_fmt(BattleEngine.vulnerableBonus * 100)}% de daño por '
                    '${BattleEngine.vulnerableTurns} turnos del grupo.'
                : '¡QUEBRADO! +${_fmt(BattleEngine.vulnerableBonus * 100)}%, '
                    'pierde su turno.',
            TutorialArrow.breakBar,
            e.id);
      } else if (e.fissured && !o.fissured) {
        add('La barra de quiebre se llenó: FISURADO. Ahora Quebrar lo quiebra.',
            TutorialArrow.breakBar, e.id);
      } else if (e.breakGauge > o.breakGauge + 0.01) {
        add(
            'La barra de quiebre subió ${_fmt(e.breakGauge - o.breakGauge)} '
            '(${e.breakGauge.round()}/${e.breakMax.round()}).',
            TutorialArrow.breakBar,
            e.id);
      }
    }

    for (final ev in events) {
      if (ev is DamageEvent &&
          !ev.fromStatus &&
          ev.sourceId == null &&
          ev.affinity != 1 &&
          after.byId(ev.targetId)?.isPlayer == false) {
        add(
            ev.affinity > 1
                ? 'Golpe a la debilidad: DÉBIL ×${_fmt(ev.affinity)} '
                    '(${ev.amount} de daño).'
                : 'RESISTE ×${_fmt(ev.affinity)}: el autómata resiste lo '
                    'físico (${ev.amount} de daño).',
            TutorialArrow.hp,
            ev.targetId);
        break;
      }
    }

    for (final ev in events) {
      if (ev is DamageEvent && ev.fromStatus) {
        final k = ev.statusSource;
        add(
            'Al empezar su turno, ${k?.label ?? 'el estado'} le hizo '
            '${ev.amount} de daño.',
            TutorialArrow.status,
            ev.targetId);
        break;
      }
    }

    // La primera vez se explica el concepto; después, solo el dato.
    bool first(String key) => said?.add(key) ?? true;

    for (final e in after.enemies) {
      final o = before.byId(e.id);
      for (final k in StatusKind.values) {
        final d = e.stacks(k) - (o?.stacks(k) ?? 0);
        if (d > 0) {
          add(
              '${k.label} +$d (tiene ${e.stacks(k)})'
              '${first('st-${k.name}') ? ': ${statusHint(k)}' : '.'}',
              TutorialArrow.status,
              e.id);
        }
      }
    }

    if (actor != null && was != null) {
      if (actor.chained && !was.chained) {
        add(
            first('instant')
                ? 'Instante: no terminó tu turno, hacés otra acción.'
                : 'Instante: otra acción.',
            TutorialArrow.timeline,
            actor.id);
      }
      final dp = actor.pulse - was.pulse;
      if (dp > 0) {
        add(
            '${actor.name}: Pulso +$dp (${actor.pulse}/${BattleEngine.pulseMax})'
            '${first('pulse+') ? ', se gana jugando.' : '.'}',
            TutorialArrow.pulse,
            actor.id);
      } else if (dp < 0) {
        add(
            '${actor.name}: Pulso −${-dp} (le queda ${actor.pulse})'
            '${first('pulse-') ? '; lo piden las habilidades fuertes.' : '.'}',
            TutorialArrow.pulse,
            actor.id);
      }
      final dm = (was.mp - actor.mp).round();
      if (dm > 0) {
        add(
            '${actor.name}: −$dm MP (quedan ${actor.mp.floor()})'
            '${first('mp-') ? '; no vuelve por turno.' : '.'}',
            TutorialArrow.mp,
            actor.id);
      }
    }

    if (cmd is DefendCommand) {
      add(
          first('defend')
              ? 'Defender (en ARMA): mitad del daño hasta tu próximo turno, '
                  'que llega antes. Da +${BattleEngine.defendPulse} de Pulso y '
                  'carga la ULT.'
              : 'Defender: mitad del daño.',
          TutorialArrow.timeline,
          actorId);
    } else if (cmd is PassCommand) {
      add(
          'Pasar: tu próximo turno llega a '
          '×${_fmt(BattleEngine.passTurnFactor)} del intervalo, sin cargar '
          'ULT.',
          TutorialArrow.timeline,
          actorId);
    }
    if (lines.isEmpty) lines.add(after.log.isEmpty ? 'Listo.' : after.log);
    return TutorialCard(lines.take(3).toList(),
        arrow: arrow, targetId: target, actorId: actorId, effect: true);
  }

  /// Una línea mecánica por estado (sin números a mano: los que hay salen
  /// del catálogo).
  String statusHint(StatusKind k) => switch (k) {
        StatusKind.burn =>
          'cada turno le hace daño; si se acumula, se puede detonar.',
        StatusKind.poison =>
          'cada turno le hace daño; las Convergencias lo consumen.',
        StatusKind.freeze =>
          'lo frena (−${_fmt(catalog.elementStatus(k).slowPerStack * 100)}% '
              'de velocidad por stack); al máximo pierde un turno.',
        StatusKind.stun => 'pierde su próximo turno.',
        StatusKind.holy => 'daño sagrado al empezar su turno.',
        StatusKind.regen => 'recupera vida cada turno.',
        StatusKind.wet =>
          'dura ${catalog.elementStatus(k).turns} turnos; lo detonan Electro '
              'y Hielo.',
        StatusKind.charged =>
          'dura ${catalog.elementStatus(k).turns} turno; lo detona Agua.',
      };

  // ---------------------------------------------------------------
  // Glosario (§ 5)
  // ---------------------------------------------------------------

  /// Una entrada por concepto, con los números del combate.
  List<GlossaryEntry> glossary() {
    final quebrar = catalog.skills[kQuebrarId];
    final fam = kFamilyRules[EnemyFamily.training]!;
    final weak = fam.damage.values.where((v) => v > 1).fold(1.0, math.max);
    final resist = fam.damage.values.where((v) => v < 1).fold(1.0, math.min);
    final cap = catalog.hitCap;
    final instant = catalog.skills[_instante];
    final detona = catalog.skills[_detonaVeneno];
    final reacciones = [
      for (final r in kReactionTable)
        if (!r.kind.convergence)
          '${r.primer.label} + golpe de ${r.detonator.label} = ${r.kind.label}',
    ];
    final convergencias = [
      for (final r in kReactionTable)
        if (r.kind.convergence)
          '${r.primer.label} + golpe de ${r.detonator.label} = '
              '${r.kind.label} (${_fmt(catalog.reaction(r.kind).perStack * 100)}% '
              'de la vida máx. por stack consumido; salpica '
              '${_fmt(catalog.reaction(r.kind).splash * 100)}%)',
    ];
    final marca = catalog.skills['selloInstante']?.debuffs.firstOrNull;
    return [
      const GlossaryEntry(
          'LT',
          'Línea de tiempo',
          'Cada uno actúa cuando le llega su turno: más velocidad, turnos '
              'más seguidos (intervalo = 100 / velocidad). La barra de turnos '
              'muestra quién sigue.'),
      GlossaryEntry(
          'DF',
          'Defender y Pasar',
          'Defender (en ARMA): la mitad del daño hasta tu próximo turno, '
              'que llega antes; +${BattleEngine.defendPulse} de Pulso '
              '(+${BattleEngine.defendPulseRepeat} si repetís) y carga la ULT. '
              'Pasar: tu próximo turno llega a '
              '×${_fmt(BattleEngine.passTurnFactor)} del intervalo.'),
      const GlossaryEntry(
          'MP',
          'MP (maná)',
          'Dura toda la misión: lo gastan casi todas las habilidades. '
              'No vuelve solo entre peleas: se recupera con pociones (Poción '
              'de maná) o al volver al lobby. El Pulso, en cambio, es de cada '
              'pelea.'),
      const GlossaryEntry(
          'PU',
          'Pulso',
          'Puntos de cada pelea, de 0 a ${BattleEngine.pulseMax}; las '
              'habilidades fuertes lo piden. +1 al empezar tu turno, con '
              'ataque básico, golpe a la debilidad o reacción, y al '
              'defender.'),
      GlossaryEntry(
          'PR',
          'Precondición',
          'Algunas habilidades piden algo del objetivo; si falta, el botón '
              'sale desactivado. Ejemplo: ${detona?.name ?? 'Detonar'} → '
              '${SkillRequirements.needsText([
                        for (final r in detona?.requires ?? const <SkillReq>[])
                          r.label
                      ]) ?? '-'}.'),
      GlossaryEntry(
          'IN',
          'Instante',
          'No es un recurso: es un tipo de habilidad (por ejemplo '
              '${instant?.name ?? '-'}). No termina tu turno: después hacés '
              'otra acción, pero no otra Instante (una por turno).'),
      GlossaryEntry(
          'AF',
          'Afinidades',
          'DÉBIL: el golpe pega ×${_fmt(weak)}. RESISTE: ×${_fmt(resist)}. '
              'INMUNE: el estado no le entra. Sin golpe a la debilidad hay '
              'un tope por golpe: ${_fmt(cap.common * 100)}% de la vida de '
              'un común, ${_fmt(cap.boss * 100)}-${_fmt(cap.bossSolo * 100)}% '
              'de un jefe (resiste el golpe).'),
      for (final k in StatusKind.values)
        if (k != StatusKind.regen)
          GlossaryEntry(k.label.substring(0, 2).toUpperCase(), k.label,
              '${statusHint(k)[0].toUpperCase()}${statusHint(k).substring(1)}'),
      GlossaryEntry(
          'MA',
          'Marca',
          'El objetivo recibe más daño'
              '${marca == null ? '' : ' (+${_fmt(marca.value * 100)}% por ${marca.turns} turnos con ${catalog.skills['selloInstante']!.name})'}.'),
      GlossaryEntry('RE', 'Reacciones', '${reacciones.join('. ')}.'),
      GlossaryEntry('CV', 'Convergencias', '${convergencias.join('. ')}.'),
      GlossaryEntry(
          'QB',
          'Quiebre, Fisurado y Quebrar',
          'Los golpes llenan la barra (más con debilidad). Llena: Fisurado. '
              'Quebrar (Pulso ${quebrar?.pulse ?? 0}) lo quiebra: pierde su '
              'turno y recibe +${_fmt(BattleEngine.vulnerableBonus * 100)}% '
              'de daño por ${BattleEngine.vulnerableTurns} turnos del grupo.'),
      const GlossaryEntry(
          'UL',
          'ULT propia y enemiga',
          'Tu ULT se carga actuando y recibiendo daño; al 100% se usa. Los '
              'jefes avisan la suya un turno antes: quebrarlos la cancela y '
              'Defender baja el daño.'),
      const GlossaryEntry(
          'DU',
          'Dúo',
          'Dos aliados juntos: cuesta ${BattleEngine.dualMpCost} MP a cada '
              'uno, pega a todos y el compañero pierde su próximo turno.'),
    ];
  }

  // ---------------------------------------------------------------
  // Antes de que actúe el autómata (§ 4.1)
  // ---------------------------------------------------------------

  /// El cartel que anuncia lo que va a hacer el autómata: espera el
  /// SIGUIENTE de todos antes de que actúe.
  TutorialCard enemyAnnounce(BattleState b) {
    final boss = b.byId(bossId);
    final ult = boss?.ultId == null ? null : catalog.enemyUlts[boss!.ultId];
    final lines = <String>[
      if (boss != null && boss.ultPending)
        'Ahora el autómata lanza la ULT que avisó'
            '${ult == null ? '' : ' (${ult.name})'}. Todos defendieron: mirá '
            'cuánto baja el daño.'
      else if (boss != null && boss.ult >= 100)
        'Ahora actúa el autómata: tiene la ULT cargada y la va a avisar un '
            'turno antes de lanzarla.'
      else
        'Ahora actúa el autómata: al empezar su turno le hacen daño sus '
            'estados y después ataca.',
    ];
    return TutorialCard(lines,
        arrow: TutorialArrow.ult, targetId: bossId, heading: 'ATENCIÓN');
  }

  // ---------------------------------------------------------------
  // Votaciones del final y ENTRENAR (§ 4.4)
  // ---------------------------------------------------------------

  /// Opciones de la votación abierta (id, rótulo), o vacío.
  List<(String, String)> options(TutorialState t) => switch (t.phase) {
        TutorialPhase.menu => const [
            ('repeat', 'REPETIR TUTORIAL'),
            ('train', 'IR A ENTRENAR'),
            ('exit', 'SALIR'),
          ],
        TutorialPhase.trainOver => const [
            ('restart', 'REINICIAR'),
            ('exit', 'SALIR'),
          ],
        _ => const [],
      };

  /// Si [choice] vale en la votación abierta.
  bool validChoice(TutorialState t, String choice) =>
      options(t).any((o) => o.$1 == choice);

  /// Lo que se decidió, o `null` si todavía no hay acuerdo. Regla (la más
  /// simple): todos los humanos de la sala eligieron lo mismo.
  String? decided(GameSession s) {
    final t = s.tutorial;
    if (t == null) return null;
    final vs = voters(s);
    if (vs.isEmpty || vs.any((p) => !t.picks.containsKey(p.id))) return null;
    final picks = [for (final p in vs) t.picks[p.id]!];
    return picks.toSet().length == 1 ? picks.first : null;
  }

  /// Quién eligió qué ("Ana: SALIR", "Beto: eligiendo…") y el motivo si
  /// no hay acuerdo.
  List<String> pickLines(GameSession s) {
    final t = s.tutorial;
    if (t == null) return const [];
    final labels = {for (final o in options(t)) o.$1: o.$2};
    final out = [
      for (final p in voters(s))
        '${p.name}: ${labels[t.picks[p.id]] ?? 'eligiendo…'}',
    ];
    final vs = voters(s);
    final picked = [
      for (final p in vs)
        if (t.picks[p.id] case final c?) c
    ];
    if (picked.length == vs.length && decided(s) == null) {
      out.add('Falta acuerdo: hace falta que todos elijan lo mismo.');
    }
    return out;
  }

  /// El autómata de ENTRENAR: el mismo, pero puede caer.
  Combatant trainingBoss(int players) =>
      automaton(players)..practice = false;

  // ---------------------------------------------------------------
  // Narrador de ENTRENAR (§ 4.4)
  // ---------------------------------------------------------------

  /// Máximo de líneas que guarda el narrador.
  static const narrationMax = 8;

  /// Las líneas del narrador para lo que pasó entre [before] y [after]
  /// con [events] (acción de [actorId], o del autómata si es `null`).
  /// [primers]: quién puso cada estado (para las Convergencias).
  List<String> narrate(BattleState before, BattleState after,
      List<BattleEvent> events, String? actorId,
      {BattleCommand? cmd, Map<String, String> primers = const {}}) {
    final out = <String>[];
    final actor = actorId == null ? null : after.byId(actorId);
    final was = actorId == null ? null : before.byId(actorId);
    String nameOf(String? id) =>
        (id == null ? null : after.byId(id)?.name) ?? 'alguien';
    var weak = false;
    var reacted = false;
    for (final ev in events) {
      switch (ev) {
        case ReactionEvent():
          reacted = true;
          final def = catalog.reaction(ev.kind);
          final rule =
              kReactionTable.where((r) => r.kind == ev.kind).firstOrNull;
          if (ev.kind.convergence && def.perStack > 0 && rule != null) {
            final primer = primers[rule.primer.name];
            final by = nameOf(ev.sourceId ?? actorId);
            final who = primer == null || primer == (ev.sourceId ?? actorId)
                ? '$by puso ${ev.consumedStacks} de ${rule.primer.label} y '
                    'detonó con ${rule.detonator.label}'
                : '${nameOf(primer)} puso ${ev.consumedStacks} de '
                    '${rule.primer.label} y $by detonó con '
                    '${rule.detonator.label}';
            out.add('¡${ev.kind.label}! ($who: ${ev.consumedStacks} × '
                '${_fmt(def.perStack * 100)}% de la vida = ${ev.amount} de '
                'daño)');
          } else {
            out.add('Reacción: ${ev.kind.label} (${ev.amount} de daño).');
          }
        case UltimateUsedEvent():
          out.add('ULT: ${nameOf(ev.actorId)} usó ${ev.name}.');
        case EnemyUltWarningEvent():
          out.add('El autómata avisa su ULT (${ev.name}): quebralo antes o '
              'defendé.');
        case EnemyUltEvent():
          out.add('El autómata lanzó su ULT (${ev.name}).');
        case BreakEvent(cancelledUlt: true):
          out.add('¡El quiebre canceló la ULT avisada!');
        case DamageEvent()
            when !ev.fromStatus &&
                ev.sourceId == null &&
                ev.affinity > 1 &&
                after.byId(ev.targetId)?.isPlayer == false &&
                !weak:
          weak = true;
          out.add('Golpe a la debilidad (×${_fmt(ev.affinity)}, ${ev.amount} '
              'de daño).');
        case DamageEvent() when ev.fromStatus:
          out.add('${ev.statusSource?.label ?? 'Un estado'} le hizo '
              '${ev.amount} al empezar el turno.');
        default:
          break;
      }
    }
    for (final e in after.enemies) {
      final o = before.byId(e.id);
      if (o == null) continue;
      if (e.vulnerable > o.vulnerable || (e.breakSkip && !o.breakSkip)) {
        out.add('Fisurado → Quebraste: pierde el turno y recibe '
            '+${_fmt(BattleEngine.vulnerableBonus * 100)}%.');
      } else if (e.fissured && !o.fissured) {
        out.add('¡Fisurado! La barra de quiebre se llenó: ahora Quebrar lo '
            'quiebra.');
      }
      for (final k in StatusKind.values) {
        final d = e.stacks(k) - o.stacks(k);
        if (d > 0) out.add('${k.label} +$d (tiene ${e.stacks(k)}).');
      }
      if (o.alive && !e.alive) out.add('¡${e.name} cayó!');
    }
    if (actor != null && was != null) {
      if (actor.chained && !was.chained) {
        out.add('Encadenaste un Instante: otra acción en el mismo turno.');
      }
      final dp = actor.pulse - was.pulse;
      if (dp > 0) {
        final why = [
          if (cmd is AttackCommand) 'ataque básico',
          if (cmd is DefendCommand) 'defender',
          if (weak) 'golpe a la debilidad',
          if (reacted && !weak) 'reacción',
        ];
        out.add('+$dp Pulso${why.isEmpty ? '' : ' (${why.join(' y ')})'}.');
      } else if (dp < 0 && cmd is SkillCommand) {
        out.add('−${-dp} Pulso (${catalog.skills[cmd.skillId]?.name ?? ''}).');
      }
    }
    return [
      for (final l in out)
        actor == null ? l : '${actor.name}: $l',
    ];
  }

  /// Quién puso cada estado después de la acción de [actorId].
  void trackPrimers(BattleState before, BattleState after, String? actorId,
      Map<String, String> primers) {
    if (actorId == null) return;
    for (final e in after.enemies) {
      final o = before.byId(e.id);
      for (final k in StatusKind.values) {
        if (e.stacks(k) > (o?.stacks(k) ?? 0)) primers[k.name] = actorId;
      }
    }
  }

  static String _fmt(num v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? '${r.round()}' : '$r';
  }
}
