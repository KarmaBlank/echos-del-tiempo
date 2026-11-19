import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/skill_requirements.dart';
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// TUTORIAL: Ecos de práctica (docs/specs/combat_tutorial.md § 7).

const _classes = ['guerrero', 'maga', 'tirador', 'paladin'];

/// Sala con [humans] humanos (h, p1, p2...) con `tutV` = [tutV], y
/// [companions] compañeros del primero.
GameSession _room(SessionEngine e,
    {int humans = 1, int companions = 0, int tutV = 0}) {
  var s = e.create();
  for (var i = 0; i < humans; i++) {
    s = e
        .addPlayer(s, i == 0 ? 'h' : 'p$i', newProfile('J$i', _classes[i]),
            tutorialVersion: tutV)!
        .state;
  }
  for (var i = 0; i < companions; i++) {
    s = e
        .addCompanion(s, 'h-c$i', newProfile('C$i', _classes[i + 1]),
            leaderId: 'h')!
        .state;
  }
  return s;
}

/// Lo que pasó al correr el guion entero.
class _Run {
  _Run(this.state, this.events, this.humanActions, this.rejected,
      this.actedIn);
  final GameSession state;
  final List<SessionEvent> events;

  /// Comandos que mandó cada humano.
  final Map<String, int> humanActions;

  /// Comandos fuera de paso que el host rechazó.
  final int rejected;

  /// Etapas (número) en las que actuó cada humano.
  final Map<String, Set<int>> actedIn;
}

/// Juega el tutorial como lo harían los jugadores: cada humano hace lo que
/// dice su cartel y cierra los carteles; además, en cada turno de un
/// humano, prueba primero algo fuera de paso (tiene que rechazarse). Al
/// terminar el guion todos votan [atEnd] (`exit` por defecto; `null` =
/// se queda en la votación).
_Run _play(SessionEngine e, GameSession s,
    {int maxTicks = 40000, String? atEnd = 'exit'}) {
  final rules = e.tutorials;
  final events = <SessionEvent>[];
  final acts = <String, int>{};
  final actedIn = <String, Set<int>>{};
  var rejected = 0;
  for (var i = 0; i < maxTicks && s.tutorial != null; i++) {
    if (s.tutorial!.phase == TutorialPhase.menu) {
      if (atEnd == null) break;
      for (final p in rules.voters(s)) {
        final r = e.apply(s, p.id, TutorialChoiceAction(atEnd));
        if (r != null) {
          s = r.state;
          events.addAll(r.events);
        }
      }
      continue;
    }
    final step = e.tick(s, 0.05);
    s = step.state;
    events.addAll(step.events);
    final t = s.tutorial;
    final b = s.battle;
    if (t == null || b == null) break;
    if (t.card != null) {
      s = _voteAll(e, s, events);
      continue;
    }
    if (!b.waitingForPlayer) continue;
    final cur = b.state.current!;
    final p = s.players[cur.id];
    if (p == null || p.isCompanion) continue;
    final st = rules.currentStep(t);
    BattleCommand? cmd;
    if (st is TutorialPlayerStep && t.prepared) {
      // Fuera de paso: Pasar cuando se pide otra cosa (y viceversa).
      final wrong = st.move == TutorialMove.pass
          ? const DefendCommand()
          : const PassCommand();
      if (e.apply(s, cur.id, BattleAction(wrong)) == null) {
        rejected++;
      }
      cmd = rules.scripted(st, cur);
    }
    if (cmd == null) continue;
    final r = e.apply(s, cur.id, BattleAction(cmd));
    if (r != null) {
      s = r.state;
      events.addAll(r.events);
      acts[cur.id] = (acts[cur.id] ?? 0) + 1;
      actedIn
          .putIfAbsent(cur.id, () => {})
          .add(rules.currentStage(t)?.number ?? 0);
    }
  }
  return _Run(s, events, acts, rejected, actedIn);
}

/// SIGUIENTE de cada humano de la sala que todavía no votó.
GameSession _voteAll(SessionEngine e, GameSession s,
    [List<SessionEvent>? events]) {
  for (final p in e.tutorials.waiting(s)) {
    final r = e.apply(s, p.id, const TutorialAckAction());
    if (r == null) continue;
    s = r.state;
    events?.addAll(r.events);
  }
  return s;
}

GameSession _start(SessionEngine e, GameSession s,
        {String by = 'h', bool companions = true}) =>
    act(e, s, by, StartTutorialAction(companions: companions));

void main() {
  test('kTutorialVersion es el máximo de las desde', () {
    expect(kTutorialVersion,
        kTutorialStages.map((s) => s.desde).reduce((a, b) => a > b ? a : b));
    expect(kTutorialStages.map((s) => s.number),
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(kTutorialVersion, 3, reason: 'v0.9.7: sin roles');
  });

  group('guion completo: todos terminan con tutV', () {
    for (final (humans, companions) in [(1, 0), (2, 0), (4, 0), (1, 1), (1, 3)]) {
      test('$humans humano(s) y $companions compañero(s)', () {
        final e = sessionEngine();
        var s = _room(e, humans: humans, companions: companions);
        expect(e.tutorials.lockText(s), contains('Falta: J0'));
        s = _start(e, s);
        expect(s.mode, SessionMode.battle);
        expect(s.tutorial!.order.length, humans + companions);
        final run = _play(e, s);
        expect(run.state.tutorial, isNull, reason: 'el guion terminó');
        expect(run.state.mode, SessionMode.lobby);
        final done = run.events.whereType<TutorialDoneEvent>().single;
        expect(done.playerIds.toSet(),
            {for (final p in run.state.playerList) if (!p.isCompanion) p.id});
        expect(done.version, kTutorialVersion);
        for (final p in run.state.playerList.where((p) => !p.isCompanion)) {
          expect(p.tutorialVersion, kTutorialVersion);
          // Nadie se queda mirando: cada humano actúa en cada etapa.
          expect(run.humanActions[p.id], greaterThan(0), reason: p.id);
          expect(run.actedIn[p.id], {for (final st in kTutorialStages) st.number},
              reason: p.id);
        }
        expect(e.tutorials.lockText(run.state), isNull,
            reason: 'el sello se desbloquea');
        expect(run.rejected, greaterThan(0),
            reason: 'las acciones fuera de paso se rechazan');
      });
    }
  });

  // § 3: kit de práctica en reemplazo total de la build.
  group('kit de práctica', () {
    for (final (humans, companions) in [(1, 0), (2, 0), (4, 0), (1, 3)]) {
      {
        test('$humans humano(s) + $companions IA: cada paso tiene su '
            'habilidad en el kit y habilitada', () {
          final e = sessionEngine();
          final rules = e.tutorials;
          var s = _room(e, humans: humans, companions: companions);
          s = _start(e, s);
          final t0 = s.tutorial!;
          final present = t0.order.toSet();
          // Kit: stats, arma y habilidades iguales para todos.
          for (final c in s.battle!.state.party) {
            expect(c.build, isNull, reason: 'sin build en el tutorial');
            expect([c.maxHp, c.maxMp, c.attack, c.magic, c.weaponType], [
              kTutorialKit.hp,
              kTutorialKit.mp,
              kTutorialKit.attack,
              kTutorialKit.magic,
              kTutorialKit.weaponType
            ]);
            expect(c.skillIds, rules.kitSkills());
          }
          final checked = <String>{};
          for (var i = 0; i < 40000 && s.tutorial != null; i++) {
            s = e.tick(s, 0.05).state;
            final t = s.tutorial;
            final b = s.battle;
            if (t == null || b == null) break;
            if (t.card != null) {
              s = _voteAll(e, s);
              continue;
            }
            if (t.phase == TutorialPhase.menu) {
              s = act(e, s, 'h', const TutorialChoiceAction('exit'));
              for (final p in rules.voters(s)) {
                if (s.tutorial == null) break;
                final r = e.apply(s, p.id, const TutorialChoiceAction('exit'));
                if (r != null) s = r.state;
              }
              continue;
            }
            final st = rules.currentStep(t);
            if (st is! TutorialPlayerStep || !t.prepared) continue;
            final id = rules.currentActor(t, present)!;
            if (b.state.currentId != id) continue;
            final actor = b.state.byId(id)!;
            final key = '${t.stage}/${t.step}/${t.reps}';
            if (st.move == TutorialMove.skill && checked.add(key)) {
              final sk = rules.skillFor(st, actor)!;
              expect(actor.skillIds, contains(sk), reason: '$key $id');
              final def = e.catalog.skills[sk]!;
              expect(
                  SkillRequirements.missing(
                      def, actor, b.state.byId(TutorialRules.bossId),
                      foes: b.state.enemies),
                  isEmpty,
                  reason: '$key $id ${def.name}');
              if (s.players[id]?.isCompanion != true) {
                expect(rules.banner(s, {id})!.text,
                    startsWith('TE TOCA: usar ${def.name}'));
              }
            }
            if (s.players[id]?.isCompanion == true) continue;
            final r = e.apply(s, id, BattleAction(rules.scripted(st, actor)!));
            expect(r, isNotNull, reason: 'el paso $key de $id se rechazó');
            s = r!.state;
          }
          expect(s.tutorial, isNull, reason: 'terminó el guion');
          expect(checked, isNotEmpty);
        });
      }
    }

    test('al salir la build vuelve intacta', () {
      final e = sessionEngine();
      final s = _room(e, companions: 1);
      final before = {for (final p in s.playerList) p.id: p.profile.toJson()};
      var t = _start(e, s);
      t = act(e, t, 'h', const TutorialControlAction(TutorialControl.exit));
      for (final p in t.playerList) {
        expect(p.profile.toJson(), before[p.id]);
      }
    });
  });

  test('solo sin compañeros: la party no entra', () {
    final e = sessionEngine();
    var s = _room(e, companions: 2);
    s = _start(e, s, companions: false);
    expect(s.tutorial!.order, ['h']);
    expect(s.battle!.state.party.map((c) => c.id), ['h']);
  });

  test('en grupo solo el host lo inicia y entran todos', () {
    final e = sessionEngine();
    final s = _room(e, humans: 3);
    expect(e.apply(s, 'p1', const StartTutorialAction()), isNull);
    final t = _start(e, s);
    expect(t.battle!.state.party.map((c) => c.id), ['h', 'p1', 'p2']);
  });

  test('el sello bloquea las misiones si alguien no tiene tutV vigente', () {
    final e = sessionEngine(zones: true);
    var s = e.create();
    s = e.addPlayer(s, 'h', newProfile('Ana', 'guerrero'))!.state;
    s = e
        .addPlayer(s, 'p1', newProfile('Beto', 'maga'), tutorialVersion: 0)!
        .state;
    final mission = e.catalog.missions.first.id;
    expect(e.apply(s, 'h', ProposeMissionAction(mission)), isNull);
    expect(e.tutorials.lockText(s),
        'Primero, todos tienen que hacer el TUTORIAL. Falta: Beto');
    // Con todos al día, se puede.
    final ok = e.addPlayer(e.create(), 'h', newProfile('Ana', 'guerrero'))!;
    expect(e.apply(ok.state, 'h', ProposeMissionAction(mission)), isNotNull);
  });

  test('repetir etapa vuelve al principio de la etapa', () {
    final e = sessionEngine();
    var s = _start(e, _room(e));
    s.tutorial!
      ..stage = 2
      ..step = 1;
    s = act(e, s, 'h', const TutorialControlAction(TutorialControl.repeatStage));
    expect(s.tutorial!.stage, 2);
    expect(s.tutorial!.step, 0);
    expect(s.tutorial!.card, isNotNull);
  });

  test('salir corta sin completar y no deja nada en el perfil', () {
    final e = sessionEngine();
    var s = _room(e);
    final before = s.players['h']!;
    final profile = before.profile;
    s = _start(e, s);
    // Juega un rato (gasta MP, Pulso, recibe golpes).
    final run = _play(e, s, maxTicks: 200);
    s = run.state;
    expect(s.tutorial, isNotNull);
    s = act(e, s, 'h', const TutorialControlAction(TutorialControl.exit));
    expect(s.tutorial, isNull);
    expect(s.mode, SessionMode.lobby);
    final p = s.players['h']!;
    expect(p.tutorialVersion, 0, reason: 'no lo completó');
    expect(p.profile.toJson(), profile.toJson(),
        reason: 'ni XP, ni loot, ni pociones, ni habilidades prestadas');
    expect(p.hp, p.maxHp);
    expect(p.mp, p.maxMp);
  });

  test('al completarlo nada del tutorial queda en el perfil', () {
    final e = sessionEngine();
    var s = _room(e, humans: 2);
    final profiles = {
      for (final p in s.playerList) p.id: p.profile.toJson(),
    };
    final run = _play(e, _start(e, s));
    for (final p in run.state.playerList) {
      expect(p.profile.toJson(), profiles[p.id]);
      expect(p.hp, p.maxHp);
      expect(p.mp, p.maxMp);
    }
  });

  test('el autómata nunca muere y la ULT de práctica nunca mata', () {
    final e = sessionEngine();
    var s = _start(e, _room(e));
    final b = s.battle!.state;
    final boss = b.byId(TutorialRules.bossId)!;
    expect(boss.practice, isTrue);
    // Un golpe enorme: queda en 1, sin K.O. ni victoria.
    boss.hp = 3;
    final me = b.byId('h')!..attack = 99999;
    b.currentId = 'h';
    final step = e.battles.command(b, 'h', const AttackCommand(targetId: 'e0'));
    expect(step, isNotNull);
    final after = step!.state.byId(TutorialRules.bossId)!;
    expect(after.hp, 1);
    expect(step.state.outcome, isNull);
    expect(step.state.log, contains('se recompone'));
    // ULT de práctica sobre un jugador con 1 de vida: queda en 1.
    final b2 = s.battle!.state.copy();
    final e0 = b2.byId('e0')!
      ..ult = 100
      ..ultPending = true
      ..attack = 99999;
    b2.byId('h')!.hp = 1;
    b2.currentId = e0.id;
    final ult = e.battles.enemyTurn(b2)!;
    expect(ult.state.byId('h')!.hp, greaterThanOrEqualTo(1));
    expect(ult.state.outcome, isNull);
    expect(me.practice, isTrue);
    // En el guion completo nadie cayó nunca.
    final run = _play(e, s);
    expect(
        run.events
            .whereType<BattleStepEvent>()
            .expand((ev) => ev.events)
            .any((ev) => ev.runtimeType.toString() == 'KnockedOutEvent'),
        isFalse);
  });

  test('las acciones fuera de paso se rechazan', () {
    final e = sessionEngine();
    var s = _start(e, _room(e, humans: 2));
    // Avanza hasta el primer turno de un humano.
    for (var i = 0; i < 400; i++) {
      s = e.tick(s, 0.05).state;
      if (s.tutorial!.card != null) {
        s = _voteAll(e, s);
        continue;
      }
      if (s.battle!.waitingForPlayer && s.tutorial!.prepared) break;
    }
    final t = s.tutorial!;
    final st = e.tutorials.currentStep(t) as TutorialPlayerStep;
    final cur = s.battle!.state.currentId!;
    final other = cur == 'h' ? 'p1' : 'h';
    expect(st.move, TutorialMove.defend, reason: 'etapa 1: Defender');
    // Otra acción del que tiene el turno, o la correcta de otro jugador.
    expect(e.apply(s, cur, const BattleAction(PassCommand())), isNull);
    expect(e.apply(s, cur, const BattleAction(AttackCommand(targetId: 'e0'))),
        isNull);
    expect(e.apply(s, other, const BattleAction(DefendCommand())), isNull);
    // El botón dice por qué.
    expect(e.tutorials.gate(t, s.battle!.state, cur, 'attack'),
        startsWith('Ahora no: el paso es'));
    expect(e.tutorials.gate(t, s.battle!.state, cur, 'defend'), isNull);
    expect(e.apply(s, cur, const BattleAction(DefendCommand())), isNotNull);
  });

  test('cartel del paso: TE TOCA para quien actúa, MIRÁ para el resto', () {
    final e = sessionEngine();
    var s = _start(e, _room(e, humans: 2));
    for (var i = 0; i < 400; i++) {
      s = e.tick(s, 0.05).state;
      if (s.tutorial!.card != null) {
        s = _voteAll(e, s);
        continue;
      }
      if (s.battle!.waitingForPlayer && s.tutorial!.prepared) break;
    }
    final cur = s.battle!.state.currentId!;
    final other = cur == 'h' ? 'p1' : 'h';
    expect(e.tutorials.banner(s, {cur})!.text, startsWith('TE TOCA: '));
    expect(e.tutorials.banner(s, {other})!.text, startsWith('MIRÁ: '));
  });

  test('versión de cambios: solo las etapas nuevas', () {
    const stages = [
      TutorialStage(
          number: 1,
          title: 'Vieja',
          teaches: 'x',
          desde: 1,
          steps: [TutorialPlayerStep(TutorialMove.defend)]),
      TutorialStage(
          number: 2,
          title: 'Nueva',
          teaches: 'y',
          desde: 2,
          steps: [TutorialPlayerStep(TutorialMove.pass)]),
    ];
    const rules = TutorialRules(stages: stages, version: 2);
    expect(rules.stagesFor(0), [1, 2], reason: 'cuenta nueva: completo');
    expect(rules.stagesFor(1), [2], reason: 'tutV viejo: solo los cambios');
    expect(rules.stagesFor(2), [1, 2], reason: 'Repetir: completo');
    final e = SessionEngine(
      battles: BattleEngine(stats: statsCalc),
      progression: progression,
      tutorials: rules,
    );
    var s = e.create();
    s = e.addPlayer(s, 'h', newProfile('Ana', 'guerrero'), tutorialVersion: 1)!
        .state;
    s = e.addPlayer(s, 'p1', newProfile('Beto', 'maga'), tutorialVersion: 2)!
        .state;
    s = _start(e, s);
    expect(s.tutorial!.stages, [2]);
    expect(s.tutorial!.card!.lines.first,
        startsWith('Ya hiciste el tutorial. Esta pelea de prueba muestra lo '
            'que cambió en v2: Nueva'));
    final run = _play(e, s);
    final done = run.events.whereType<TutorialDoneEvent>().single;
    expect(done.version, 2);
    expect(run.state.players['h']!.tutorialVersion, 2);
  });

  test('el estado del tutorial viaja en el snapshot', () {
    final e = sessionEngine();
    var s = _start(e, _room(e, humans: 2));
    s = e.tick(s, 0.05).state;
    final json = SessionJson(e.catalog);
    final back = json.fromJson(json.toJson(s));
    expect(back.tutorial!.toJson(), s.tutorial!.toJson());
    expect(back.players['p1']!.tutorialVersion, 0);
    expect(back.battle!.state.byId('e0')!.practice, isTrue);
  });

  test('glosario: una entrada por concepto con los números del combate', () {
    final g = const TutorialRules().glossary();
    final titles = g.map((x) => x.title).toList();
    for (final t in [
      'Línea de tiempo',
      'MP (maná)',
      'Pulso',
      'Precondición',
      'Instante',
      'Afinidades',
      'Quemadura',
      'Veneno',
      'Congelación',
      'Aturdido',
      'Sagrado',
      'Mojado',
      'Cargado',
      'Marca',
      'Reacciones',
      'Convergencias',
      'Quiebre, Fisurado y Quebrar',
      'ULT propia y enemiga',
      'Dúo',
    ]) {
      expect(titles, contains(t));
    }
    final pulso = g.firstWhere((x) => x.title == 'Pulso').text;
    expect(pulso, contains('pips 0-${BattleEngine.pulseMax}'));
    expect(pulso, contains('MP y Pulso a la vez'));
    final mp = g.firstWhere((x) => x.title == 'MP (maná)').text;
    expect(mp, contains('Dura toda la misión'));
    final inst = g.firstWhere((x) => x.title == 'Instante').text;
    expect(inst, startsWith('No es un recurso'));
  });

  // § 4.1: cada cartel espera el SIGUIENTE de todos los humanos.
  group('votación SIGUIENTE', () {
    for (final humans in [1, 2, 4]) {
      test('$humans humano(s): se cierra con el último voto', () {
        final e = sessionEngine();
        var s = _start(e, _room(e, humans: humans));
        final card = s.tutorial!.card;
        expect(card, isNotNull, reason: 'cartel de inicio de etapa');
        final ids = [for (final p in s.playerList) p.id];
        for (var i = 0; i < ids.length; i++) {
          expect(s.tutorial!.card, same(card), reason: 'faltan votos');
          final names = [for (final id in ids.skip(i)) s.players[id]!.name];
          expect(e.tutorials.waitingText(s), 'Esperando: ${names.join(', ')}');
          s = act(e, s, ids[i], const TutorialAckAction());
          if (i < ids.length - 1) {
            expect(e.apply(s, ids[i], const TutorialAckAction()), isNull,
                reason: 'votar dos veces no cuenta');
          }
        }
        expect(s.tutorial!.card, isNull);
        expect(s.tutorial!.votes, isEmpty);
      });
    }

    test('los compañeros IA no votan', () {
      final e = sessionEngine();
      var s = _start(e, _room(e, companions: 3));
      expect(e.apply(s, 'h-c0', const TutorialAckAction()), isNull);
      expect(e.tutorials.waitingText(s), 'Esperando: J0');
      s = act(e, s, 'h', const TutorialAckAction());
      expect(s.tutorial!.card, isNull);
    });

    test('si alguien se desconecta deja de contarse', () {
      final e = sessionEngine();
      var s = _start(e, _room(e, humans: 3));
      s = act(e, s, 'h', const TutorialAckAction());
      s = act(e, s, 'p1', const TutorialAckAction());
      expect(e.tutorials.waitingText(s), 'Esperando: J2');
      s = e.removePlayer(s, 'p2')!.state;
      s = e.tick(s, 0.05).state;
      expect(s.tutorial!.card, isNull);
    });

    test('no hay avance por tiempo', () {
      final e = sessionEngine();
      var s = _start(e, _room(e, humans: 2));
      final card = s.tutorial!.card;
      final stage = s.tutorial!.stage;
      for (var i = 0; i < 600; i++) {
        s = e.tick(s, 1).state;
      }
      expect(s.tutorial!.card?.lines, card!.lines,
          reason: '10 minutos después sigue el mismo cartel');
      expect([s.tutorial!.stage, s.tutorial!.step], [stage, 0]);
      // Lo mismo con el cartel de efecto.
      s = _voteAll(e, s);
      for (var i = 0; i < 400 && s.tutorial!.card == null; i++) {
        s = e.tick(s, 0.05).state;
        final b = s.battle!;
        final st = e.tutorials.currentStep(s.tutorial!);
        if (st is TutorialPlayerStep &&
            s.tutorial!.prepared &&
            b.waitingForPlayer) {
          final cur = b.state.current!;
          s = act(e, s, cur.id,
              BattleAction(e.tutorials.scripted(st, cur)!));
        }
      }
      final effect = s.tutorial!.card!;
      expect(effect.effect, isTrue);
      for (var i = 0; i < 600; i++) {
        s = e.tick(s, 1).state;
      }
      expect(s.tutorial!.card?.lines, effect.lines);
    });

    test('textos: la etapa no repite su título y el efecto explica una vez',
        () {
      const r = TutorialRules();
      for (final st in kTutorialStages) {
        final intro = r.stageIntro(st.number);
        expect(intro, isNotEmpty, reason: 'etapa ${st.number}');
        for (final l in intro) {
          expect(l.contains('Etapa'), isFalse);
        }
      }
      final two = r.stageIntro(2).join(' ');
      expect(two, contains('dura toda la misión'));
      expect(two, isNot(contains('expedición')));
      expect(r.stageIntro(3).join(' '), contains('Pulso'));
      expect(r.stageIntro(4).first, startsWith('Instante no es un recurso'));
      // Defender: la explicación sale la primera vez, después solo el dato.
      final e = sessionEngine();
      final s = _start(e, _room(e));
      final b = s.battle!.state;
      final said = <String>{};
      final a = r.effectCard(b, b, const [], 'h',
          cmd: const DefendCommand(), said: said);
      final again = r.effectCard(b, b, const [], 'h',
          cmd: const DefendCommand(), said: said);
      expect(a.lines.single, contains('próximo turno'));
      expect(again.lines.single, 'Defender: mitad del daño.');
    });
  });
}