import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
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
  _Run(this.state, this.events, this.humanActions, this.rejected);
  final GameSession state;
  final List<SessionEvent> events;

  /// Comandos que mandó cada humano.
  final Map<String, int> humanActions;

  /// Comandos fuera de paso que el host rechazó.
  final int rejected;
}

/// Juega el tutorial como lo harían los jugadores: cada humano hace lo que
/// dice su cartel y cierra los carteles; además, en cada turno de un
/// humano, prueba primero algo fuera de paso (tiene que rechazarse).
_Run _play(SessionEngine e, GameSession s, {int maxTicks = 40000}) {
  final rules = e.tutorials;
  final events = <SessionEvent>[];
  final acts = <String, int>{};
  var rejected = 0;
  for (var i = 0; i < maxTicks && s.tutorial != null; i++) {
    final step = e.tick(s, 0.05);
    s = step.state;
    events.addAll(step.events);
    final t = s.tutorial;
    final b = s.battle;
    if (t == null || b == null) break;
    final card = t.card;
    if (card != null) {
      var by = card.actorId ?? s.playerList.first.id;
      by = s.players[by]?.leaderId ?? by;
      if (!s.players.containsKey(by)) by = s.playerList.first.id;
      final ack = e.apply(s, by, const TutorialAckAction());
      if (ack != null) {
        s = ack.state;
        events.addAll(ack.events);
      }
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
    } else if (st is TutorialFreeStep) {
      cmd = const DefendCommand();
    }
    if (cmd == null) continue;
    final r = e.apply(s, cur.id, BattleAction(cmd));
    if (r != null) {
      s = r.state;
      events.addAll(r.events);
      acts[cur.id] = (acts[cur.id] ?? 0) + 1;
    }
  }
  return _Run(s, events, acts, rejected);
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
          // Con varios humanos, cada uno hizo su parte.
          expect(run.humanActions[p.id], greaterThan(0), reason: p.id);
        }
        expect(e.tutorials.lockText(run.state), isNull,
            reason: 'el sello se desbloquea');
        expect(run.rejected, greaterThan(0),
            reason: 'las acciones fuera de paso se rechazan');
      });
    }
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

  test('rotar roles: en el intento 2 cada uno tiene otro rol', () {
    final e = sessionEngine();
    var s = _room(e, humans: 4, tutV: 0);
    s = _start(e, s);
    final rules = e.tutorials;
    final present = s.tutorial!.order.toSet();
    final first = {
      for (final id in present) id: rules.rolesOf(s.tutorial!, id, present),
    };
    s = act(e, s, 'h', const TutorialControlAction(TutorialControl.repeat));
    expect(s.tutorial!.attempt, 2);
    for (final id in present) {
      final second = rules.rolesOf(s.tutorial!, id, present);
      expect(second, isNot(first[id]), reason: id);
    }
    expect(rules.attemptText(s.tutorial!, 'h', present),
        startsWith('Intento 2: esta vez'));
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
      final card = s.tutorial!.card;
      if (card != null) {
        s = e.apply(s, 'h', const TutorialAckAction())?.state ?? s;
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
    expect(e.apply(s, cur, const BattleAction(AttackCommand())), isNull);
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
        s = e.apply(s, 'h', const TutorialAckAction())?.state ?? s;
        continue;
      }
      if (s.battle!.waitingForPlayer && s.tutorial!.prepared) break;
    }
    final cur = s.battle!.state.currentId!;
    final other = cur == 'h' ? 'p1' : 'h';
    expect(e.tutorials.banner(s, {cur})!.text, startsWith('TE TOCA: '));
    expect(e.tutorials.banner(s, {other})!.text, startsWith('MIRÁ: '));
  });

  test('versión de cambios: solo las etapas nuevas y la libre', () {
    const stages = [
      TutorialStage(
          number: 1,
          title: 'Vieja',
          teaches: 'x',
          desde: 1,
          steps: [TutorialPlayerStep(TutorialRole.acumula, TutorialMove.defend)]),
      TutorialStage(
          number: 2,
          title: 'Nueva',
          teaches: 'y',
          desde: 2,
          steps: [TutorialPlayerStep(TutorialRole.acumula, TutorialMove.pass)]),
      TutorialStage(
          number: 3,
          title: 'Libre',
          teaches: 'z',
          desde: 1,
          steps: [TutorialFreeStep(1)]),
    ];
    const rules = TutorialRules(stages: stages, version: 2);
    expect(rules.stagesFor(0), [1, 2, 3], reason: 'cuenta nueva: completo');
    expect(rules.stagesFor(1), [2, 3], reason: 'tutV viejo: cambios + libre');
    expect(rules.stagesFor(2), [1, 2, 3], reason: 'Repetir: completo');
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
    expect(s.tutorial!.stages, [2, 3]);
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
      'MP',
      'Pulso',
      'Precondición',
      'Instante y encadenar',
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
    expect(pulso, contains('tope ${BattleEngine.pulseMax}'));
  });
}
