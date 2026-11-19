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

const _r0 = TutorialRole.acumula;
const _r1 = TutorialRole.detona;
const _r2 = TutorialRole.barra;
const _r3 = TutorialRole.quiebra;

// Habilidades del catálogo que el guion presta (§ 3): las mismas que usa
// el combate, así sus números y textos salen de los datos.
const _fuego = 'bola'; // Bola de Fuego: Fuego + Quemadura
const _fisico = 'embestida'; // Embestida: física, mucho quiebre
const _instante = 'puaEco'; // Púa Fugaz: Instante + Veneno
const _detonaVeneno = 'ignicionEco'; // Ignición Convergente (pide Veneno)
const _detonaQuemadura = 'ponzonaEco'; // Ponzoña Convergente (pide Quemadura)
const _area = 'llamarada'; // Llamarada: a todos + Quemadura

/// Las 10 etapas del § 4.2.
const List<TutorialStage> kTutorialStages = [
  TutorialStage(
    number: 1,
    title: 'Línea de tiempo',
    teaches: 'turnos, velocidad, Defender y Pasar',
    desde: 1,
    steps: [
      TutorialPlayerStep(_r0, TutorialMove.defend),
      TutorialPlayerStep(_r1, TutorialMove.pass),
    ],
  ),
  TutorialStage(
    number: 2,
    title: 'Maná y Pulso',
    teaches: 'qué es cada recurso y cómo se recupera',
    desde: 1,
    steps: [
      TutorialPlayerStep(_r0, TutorialMove.attack),
      TutorialPlayerStep(_r1, TutorialMove.skill, skillId: _fisico),
    ],
  ),
  TutorialStage(
    number: 3,
    title: 'Afinidades',
    teaches: 'debilidad, resistencia y tope sin debilidad',
    desde: 1,
    steps: [
      TutorialPlayerStep(_r2, TutorialMove.skill, skillId: _fisico),
      TutorialPlayerStep(_r0, TutorialMove.skill, skillId: _fuego),
    ],
  ),
  TutorialStage(
    number: 4,
    title: 'Estados',
    teaches: 'estados, stacks y duración',
    desde: 1,
    steps: [
      TutorialPlayerStep(_r0, TutorialMove.skill, skillId: _fuego),
      // Otra Quemadura: los stacks se suman (un golpe de Veneno acá la
      // detonaría; el Veneno se ve en la etapa 5).
      TutorialPlayerStep(_r2, TutorialMove.skill, skillId: _fuego),
      TutorialEnemyStep(),
    ],
  ),
  TutorialStage(
    number: 5,
    title: 'Precondición y encadenar',
    teaches: 'precondiciones, Instante y encadenar',
    desde: 1,
    setup: TutorialSetup.poisonPrimed,
    steps: [
      TutorialPlayerStep(_r1, TutorialMove.skill, skillId: _instante),
      TutorialPlayerStep(_r1, TutorialMove.skill, skillId: _detonaVeneno),
    ],
  ),
  TutorialStage(
    number: 6,
    title: 'Convergencia en equipo',
    teaches: 'combos entre jugadores',
    desde: 1,
    steps: [
      TutorialPlayerStep(_r0, TutorialMove.skill, skillId: _fuego),
      TutorialPlayerStep(_r1, TutorialMove.skill, skillId: _detonaQuemadura),
    ],
  ),
  TutorialStage(
    number: 7,
    title: 'Quiebre',
    teaches: 'puntos de quiebre, Fisurado, Quebrar y el daño de más',
    desde: 1,
    steps: [
      TutorialPlayerStep(_r0, TutorialMove.skill, skillId: _fuego),
      TutorialPlayerStep(_r2, TutorialMove.skill,
          skillId: _fisico, untilFissured: true, maxReps: 3),
      TutorialPlayerStep(_r3, TutorialMove.skill, skillId: kTutorialQuebrar),
    ],
  ),
  TutorialStage(
    number: 8,
    title: 'ULT enemiga',
    teaches: 'aviso, cancelar y defender',
    desde: 1,
    setup: TutorialSetup.enemyUlt,
    steps: [
      TutorialEnemyStep(),
      TutorialPlayerStep(_r0, TutorialMove.defend),
      TutorialPlayerStep(_r1, TutorialMove.defend),
      TutorialEnemyStep(),
    ],
  ),
  TutorialStage(
    number: 9,
    title: 'Área',
    teaches: 'área para preparar y salpicadura',
    desde: 1,
    setup: TutorialSetup.adds,
    steps: [
      TutorialPlayerStep(_r0, TutorialMove.skill, skillId: _area),
      TutorialPlayerStep(_r1, TutorialMove.skill, skillId: _detonaQuemadura),
    ],
  ),
  TutorialStage(
    number: 10,
    title: 'Libre',
    teaches: 'probar sin guion',
    desde: 1,
    steps: [TutorialFreeStep(3)],
  ),
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

  /// El cartel de efecto se cierra solo (§ 4.1).
  static const cardSeconds = 6.0;

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
  /// etapas nuevas más la libre.
  List<int> stagesFor(int minTutV) {
    if (minTutV <= 0 || minTutV >= version) {
      return [for (final s in stages) s.number];
    }
    final last = stages.last;
    return [
      for (final s in stages)
        if (s.desde > minTutV && s != last) s.number,
      last.number,
    ];
  }

  TutorialStage stageDef(int number) =>
      stages.firstWhere((s) => s.number == number);

  TutorialStage? currentStage(TutorialState t) =>
      t.running ? stageDef(t.stages[t.stage]) : null;

  TutorialStep? currentStep(TutorialState t) {
    final st = currentStage(t);
    if (st == null || t.step >= st.steps.length) return null;
    return st.steps[t.step];
  }

  // ---------------------------------------------------------------
  // Roles (§ 4.3)
  // ---------------------------------------------------------------

  /// Índice en `order` de quien hace [role] en el intento de [t].
  static int actorIndex(TutorialRole role, int attempt, int players) =>
      players <= 0 ? 0 : (role.index + attempt - 1) % players;

  /// Quién hace [role] entre los que siguen ([present]).
  String? actorOf(TutorialState t, TutorialRole role, Set<String> present) {
    final order = [
      for (final id in t.order)
        if (present.contains(id)) id
    ];
    if (order.isEmpty) return null;
    return order[actorIndex(role, t.attempt, order.length)];
  }

  /// Los roles de [id] en este intento.
  List<TutorialRole> rolesOf(TutorialState t, String id, Set<String> present) =>
      [
        for (final r in TutorialRole.values)
          if (actorOf(t, r, present) == id) r,
      ];

  // ---------------------------------------------------------------
  // Batalla de práctica (§ 3)
  // ---------------------------------------------------------------

  /// La habilidad real de un paso para [actor] (Quebrar según su arma).
  String? skillFor(TutorialPlayerStep st, Combatant actor) =>
      st.skillId == kTutorialQuebrar
          ? quebrarSkillFor(actor.weaponType)
          : st.skillId;

  /// Las habilidades del guion que se le prestan a [id] (las de sus
  /// roles).
  List<String> lentSkills(TutorialState t, String id, Set<String> present) {
    final roles = rolesOf(t, id, present).toSet();
    final out = <String>[];
    for (final n in t.stages) {
      for (final st in stageDef(n).steps) {
        if (st is TutorialPlayerStep &&
            roles.contains(st.role) &&
            st.skillId != null &&
            st.skillId != kTutorialQuebrar &&
            !out.contains(st.skillId)) {
          out.add(st.skillId!);
        }
      }
    }
    return out;
  }

  /// Arma la pelea de práctica sobre [started] (`BattleEngine.start` con
  /// el grupo): cambia los enemigos por el Autómata de entrenamiento,
  /// presta las habilidades y marca a todos como de práctica.
  void setUpBattle(BattleState started, TutorialState t) {
    final present = {for (final c in started.party) c.id};
    for (final c in started.party) {
      final lent = lentSkills(t, c.id, present);
      c
        ..practice = true
        ..skillIds = [
          for (final id in lent)
            if (!c.skillIds.contains(id)) id,
          ...c.skillIds,
        ];
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
    final hasAdds = b.enemies.length > 1;
    for (final e in b.enemies) {
      e
        ..hp = e.maxHp
        ..statuses = {}
        ..breakGauge = 0
        ..fissured = false
        ..breakSkip = false
        ..vulnerable = 0
        ..ultPending = false
        ..ult = 0;
    }
    for (final p in b.party) {
      p
        ..hp = math.max(p.hp, (p.maxHp * 0.6).round())
        ..mp = math.max(p.mp, p.maxMp.toDouble())
        ..statuses = {};
    }
    final boss = b.byId(bossId)!;
    switch (st.setup) {
      case TutorialSetup.fresh:
        break;
      case TutorialSetup.poisonPrimed:
        // Detonar sale desactivado ("Necesita: 5 de Veneno") hasta que la
        // Instante sume lo que falta.
        final need = _requiredStacks(_detonaVeneno, StatusKind.poison);
        final adds = catalog.skills[_instante]?.status?.stacks ?? 0;
        boss.statuses[StatusKind.poison] = math.max(1, need - adds);
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
    final step = currentStep(t);
    if (step is TutorialFreeStep) return true;
    if (step is! TutorialPlayerStep || t.card != null) return false;
    final present = {for (final c in b.party) c.id};
    if (actorOf(t, step.role, present) != playerId) return false;
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
            cmd is SkillCommand && cmd.skillId == skillFor(step, actor),
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
    final step = currentStep(t);
    if (step is TutorialFreeStep) return null;
    if (step is! TutorialPlayerStep) return 'Ahora no: mirá al autómata.';
    final actor = b.byId(playerId);
    if (actor == null) return 'Ahora no.';
    final want = switch (step.move) {
      TutorialMove.attack => 'attack',
      TutorialMove.defend => 'defend',
      TutorialMove.pass => 'pass',
      TutorialMove.skill => 'skill-${skillFor(step, actor)}',
    };
    return actionId == want
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
            return sk?.allTargets ?? false
                ? 'usar $n (a todos)'
                : 'usar $n sobre el autómata';
          }(),
      };

  /// El cartel de arriba para quien controla [mine] (§ 4.1).
  TutorialBanner? banner(GameSession s, Set<String> mine) {
    final t = s.tutorial;
    final b = s.battle?.state;
    if (t == null || b == null) return null;
    final st = currentStage(t);
    if (st == null) return const TutorialBanner('¡Entrenamiento completo!');
    final idx = t.stages.indexOf(st.number) + 1;
    final head = 'Etapa $idx/${t.stages.length} · ${st.title}';
    final step = currentStep(t);
    final present = {for (final c in b.party) c.id};
    switch (step) {
      case TutorialFreeStep():
        return TutorialBanner(
            'LIBRE: probá lo que quieras (${t.freeLeft} '
            '${t.freeLeft == 1 ? 'acción' : 'acciones'}).',
            yourTurn: mine.contains(b.currentId),
            stage: head);
      case TutorialEnemyStep():
        return TutorialBanner('MIRÁ: actúa el autómata.', stage: head);
      case TutorialPlayerStep():
        final id = actorOf(t, step.role, present);
        final actor = id == null ? null : b.byId(id);
        final what = doText(step, actor);
        final companion = id != null && s.players[id]?.isCompanion == true;
        if (id != null && mine.contains(id) && !companion) {
          final known = (s.players[id]?.tutorialVersion ?? 0) >= version &&
              t.fromVersion > 0;
          return TutorialBanner(
              'TE TOCA: ${what[0].toLowerCase()}${what.substring(1)}'
              '${known ? ' · Ya lo conocés: ayudá al grupo' : ''}',
              yourTurn: true,
              stage: head);
        }
        final who = actor?.name ?? '?';
        return TutorialBanner(
            'MIRÁ: $who${companion ? ' (IA)' : ''} va a '
            '${what[0].toLowerCase()}${what.substring(1)}',
            stage: head);
      case null:
        return TutorialBanner('', stage: head);
    }
  }

  // ---------------------------------------------------------------
  // Carteles (§ 4.1)
  // ---------------------------------------------------------------

  /// El cartel de inicio de una etapa.
  TutorialCard stageCard(TutorialState t, TutorialStage st,
      {required Map<String, String> names, required Set<String> present}) {
    final idx = t.stages.indexOf(st.number) + 1;
    final lines = <String>[];
    if (idx == 1 && t.fromVersion > 0 && t.fromVersion < version) {
      lines.add('Ya hiciste el tutorial. Esta pelea de prueba muestra lo que '
          'cambió en v$version: '
          '${[
        for (final n in t.stages)
          if (n != stages.last.number) stageDef(n).title
      ].join(', ')}.');
    } else if (idx == 1 && t.attempt > 1) {
      final parts = <String>[];
      for (final id in t.order) {
        if (!present.contains(id)) continue;
        final r = rolesOf(t, id, present);
        if (r.isNotEmpty) parts.add('${names[id] ?? id} ${r.first.verb}');
      }
      lines.add('Intento ${t.attempt}: roles rotados (${parts.join(', ')}).');
    }
    lines.add('Etapa $idx/${t.stages.length}: ${st.title}.');
    lines.add('Enseña: ${st.teaches}.');
    return TutorialCard(lines, arrow: TutorialArrow.timeline);
  }

  /// "Intento 2: esta vez quebrás vos" para [id].
  String? attemptText(TutorialState t, String id, Set<String> present) {
    if (t.attempt <= 1) return null;
    final r = rolesOf(t, id, present);
    if (r.isEmpty) return null;
    return 'Intento ${t.attempt}: esta vez ${r.first.verb} vos.';
  }

  /// El cartel de efecto (2-3 líneas) de lo que pasó entre [before] y
  /// [after] con [events], con la flecha a lo que cambió.
  TutorialCard effectCard(BattleState before, BattleState after,
      List<BattleEvent> events, String? actorId,
      {BattleCommand? cmd}) {
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
            '¡QUEBRADO! Pierde su turno y recibe '
            '+${_fmt(BattleEngine.vulnerableBonus * 100)}% de daño por '
            '${BattleEngine.vulnerableTurns} turnos del grupo.',
            TutorialArrow.breakBar,
            e.id);
      } else if (e.fissured && !o.fissured) {
        add('La barra de quiebre se llenó: FISURADO. Ahora Quebrar lo quiebra.',
            TutorialArrow.breakBar, e.id);
      } else if (e.breakGauge > o.breakGauge + 0.01) {
        add(
            'La barra de quiebre subió ${_fmt(e.breakGauge - o.breakGauge)} '
            '(${_fmt(e.breakGauge)}/${_fmt(e.breakMax)}).',
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

    for (final e in after.enemies) {
      final o = before.byId(e.id);
      for (final k in StatusKind.values) {
        final d = e.stacks(k) - (o?.stacks(k) ?? 0);
        if (d > 0) {
          add('${k.label} +$d (tiene ${e.stacks(k)}): ${statusHint(k)}',
              TutorialArrow.status, e.id);
        }
      }
    }

    if (actor != null && was != null) {
      if (actor.chained && !was.chained) {
        add('Instante: no termina el turno, te queda una acción.',
            TutorialArrow.timeline, actor.id);
      }
      final dp = actor.pulse - was.pulse;
      if (dp > 0) {
        add('${actor.name} ganó $dp de Pulso (${actor.pulse}/${BattleEngine.pulseMax}).',
            TutorialArrow.pulse, actor.id);
      } else if (dp < 0) {
        add('${actor.name} gastó ${-dp} de Pulso (le queda ${actor.pulse}).',
            TutorialArrow.pulse, actor.id);
      }
      final dm = (was.mp - actor.mp).round();
      if (dm > 0) {
        add('${actor.name} gastó $dm MP (le quedan ${actor.mp.floor()}).',
            TutorialArrow.mp, actor.id);
      }
    }

    if (cmd is DefendCommand) {
      add(
          'Defender: recibís la mitad del daño hasta tu próximo turno, que '
          'llega antes en la barra de turnos.',
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
          'Defender: la mitad del daño hasta tu próximo turno, que llega '
              'antes. Pasar: tu próximo turno llega a '
              '×${_fmt(BattleEngine.passTurnFactor)} del intervalo.'),
      const GlossaryEntry(
          'MP',
          'MP',
          'Las habilidades gastan MP. Se repone con la Poción de maná y, '
              'fuera de batalla, con el tiempo.'),
      GlossaryEntry(
          'PU',
          'Pulso',
          'Arrancás la pelea con ${BattleEngine.pulseStart} y sumás 1 al '
              'empezar cada turno (tope ${BattleEngine.pulseMax}). Lo gastan '
              'Quebrar (${quebrar?.pulse ?? 0}) y las habilidades que '
              'detonan.'),
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
          'Instante y encadenar',
          'Una habilidad Instante (por ejemplo ${instant?.name ?? '-'}) no '
              'termina el turno: te queda una acción más, pero no otra '
              'Instante.'),
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

  static String _fmt(num v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? '${r.round()}' : '$r';
  }
}
