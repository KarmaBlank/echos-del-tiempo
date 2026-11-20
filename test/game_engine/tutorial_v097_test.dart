import 'package:echos_del_tiempo/features/combat/domain/skill_text.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart' show kQuebrarId;
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// TUTORIAL v0.9.7 (docs/specs/combat_tutorial.md § 4): sin roles, cada
/// jugador prueba todo él mismo, Convergencia en parejas, quiebre uno por
/// uno, votación del final sin roles, ENTRENAR y su narrador.

const _classes = ['guerrero', 'maga', 'tirador', 'paladin'];

GameSession _room(SessionEngine e, {int humans = 1, int companions = 0}) {
  var s = e.create();
  for (var i = 0; i < humans; i++) {
    s = e
        .addPlayer(s, i == 0 ? 'h' : 'p$i', newProfile('J$i', _classes[i]),
            tutorialVersion: 0)!
        .state;
  }
  for (var i = 0; i < companions; i++) {
    s = e
        .addCompanion(s, 'h-c$i', newProfile('C$i', _classes[(i + 1) % 4]),
            leaderId: 'h')!
        .state;
  }
  return s;
}

GameSession _voteAll(SessionEngine e, GameSession s) {
  for (final p in e.tutorials.voters(s)) {
    if (s.tutorial?.card == null) break;
    final r = e.apply(s, p.id, const TutorialAckAction());
    if (r != null) s = r.state;
  }
  return s;
}

GameSession _pickAll(SessionEngine e, GameSession s, String choice) {
  for (final p in e.tutorials.voters(s)) {
    if (s.tutorial == null) break;
    s = act(e, s, p.id, TutorialChoiceAction(choice));
  }
  return s;
}

GameSession _start(SessionEngine e, GameSession s) =>
    act(e, s, 'h', const StartTutorialAction());

/// Lo que hizo cada jugador (humano o IA) en el guion.
class _Log {
  final did = <String, Set<String>>{};
  final actedIn = <int, Set<String>>{};
  final breakSkills = <String>{};

  void add(String id, String what) => did.putIfAbsent(id, () => {}).add(what);

  /// Mira lo que pasó entre [before] y [after] con [events] (de un
  /// comando o de un tick) en la etapa [stage].
  void look(int stage, BattleState before, BattleState after,
      List<BattleEvent> events, {BattleCommand? cmd, String? by}) {
    final actor = by ??
        events
            .whereType<ActionEvent>()
            .map((a) => a.actorId)
            .where((id) => after.byId(id)?.isPlayer == true)
            .firstOrNull;
    if (actor == null) return;
    actedIn.putIfAbsent(stage, () => {}).add(actor);
    final a = after.byId(actor)!;
    final w = before.byId(actor)!;
    final kinds = events.whereType<ActionEvent>().map((x) => x.kind.name);
    if (cmd is DefendCommand || kinds.contains('defend')) add(actor, 'defend');
    if (cmd is AttackCommand || kinds.contains('attack')) add(actor, 'attack');
    if (a.mp < w.mp - 0.5) add(actor, 'mp');
    if (a.pulse > w.pulse) add(actor, 'pulse+');
    final sk = events
        .whereType<ActionEvent>()
        .map((x) => x.skillId)
        .whereType<String>()
        .firstOrNull;
    if (sk != null && (const TutorialRules().catalog.skills[sk]?.pulse ?? 0) > 0) {
      add(actor, 'pulse-');
    }
    if (a.chained && !w.chained) add(actor, 'instant');
    for (final ev in events.whereType<DamageEvent>()) {
      if (ev.fromStatus || ev.sourceId != null) continue;
      if (after.byId(ev.targetId)?.isPlayer != false) continue;
      if (ev.affinity < 1) add(actor, 'resist');
      if (ev.affinity > 1) add(actor, 'weak');
    }
    final boss = after.byId(TutorialRules.bossId)!;
    final was = before.byId(TutorialRules.bossId)!;
    for (final k in StatusKind.values) {
      if (boss.stacks(k) > was.stacks(k)) {
        add(actor, 'status');
        if (stage == 7) add(actor, 'prime');
      }
    }
    if (events.any((ev) => ev is ReactionEvent && ev.kind.convergence)) {
      add(actor, stage == 7 ? 'detonate' : 'reaction');
    }
    if ((boss.breakSkip && !was.breakSkip) || boss.vulnerable > was.vulnerable) {
      add(actor, 'break');
      if (sk != null && stage == 8) breakSkills.add(sk);
    }
  }
}

/// Juega el guion hasta la votación del final como lo harían los
/// jugadores; en el quiebre, los de índice impar usan la habilidad que
/// "puede quebrar" en vez de Quebrar.
(GameSession, _Log) _play(SessionEngine e, GameSession s,
    {void Function(GameSession s)? onCard,
    void Function(GameSession s)? onTick}) {
  final rules = e.tutorials;
  final log = _Log();
  for (var i = 0; i < 60000; i++) {
    if (s.tutorial?.phase != TutorialPhase.script) break;
    final stage = rules.currentStage(s.tutorial!)?.number ?? 0;
    final before = s.battle!.state.copy();
    final r = e.tick(s, 0.05);
    s = r.state;
    for (final ev in r.events.whereType<BattleStepEvent>()) {
      log.look(stage, before, s.battle!.state, ev.events);
    }
    onTick?.call(s);
    final t = s.tutorial!;
    if (t.card != null) {
      onCard?.call(s);
      s = _voteAll(e, s);
      continue;
    }
    final b = s.battle!;
    if (!b.waitingForPlayer) continue;
    final cur = b.state.current!;
    if (s.players[cur.id]?.isCompanion != false) continue;
    final st = rules.currentStep(t);
    if (st is! TutorialPlayerStep || !t.prepared) continue;
    var cmd = rules.scripted(st, cur)!;
    if (st.alt != null && t.order.indexOf(cur.id).isOdd) {
      cmd = SkillCommand(st.alt!, targetId: TutorialRules.bossId);
    }
    final pre = b.state.copy();
    final rr = e.apply(s, cur.id, BattleAction(cmd));
    expect(rr, isNotNull, reason: 'etapa $stage: ${cur.id} $cmd');
    s = rr!.state;
    log.look(
        stage,
        pre,
        s.battle!.state,
        [
          for (final ev in rr.events.whereType<BattleStepEvent>()) ...ev.events
        ],
        cmd: cmd,
        by: cur.id);
  }
  expect(s.tutorial!.phase, TutorialPhase.menu);
  return (s, log);
}

void main() {
  test('costo de Pulso como el MP: "P2" en la fila, "2 Pulso" en el detalle',
      () {
    final cat = sessionEngine().catalog;
    final ign = cat.skills['ignicionEco']!;
    final quebrar = cat.skills[kQuebrarId]!;
    final bola = cat.skills['bola']!;
    String plain(String m) => m.replaceAll(RegExp('<[^>]*>'), '');
    expect(plain(skillCostMarkup(ign)), '${ign.mp} MP  P${ign.pulse}');
    expect(plain(skillCostMarkup(quebrar)), 'P${quebrar.pulse}');
    expect(plain(skillCostMarkup(bola)), '${bola.mp} MP');
    expect(skillCostMarkup(quebrar), contains(kPulseHex));
  });

  test('kit de tutorial igual para todos, con lo que pide cada etapa', () {
    final e = sessionEngine();
    final s = _start(e, _room(e, humans: 2, companions: 0));
    final cat = e.catalog;
    final kits = {for (final c in s.battle!.state.party) c.skillIds.join(',')};
    expect(kits.length, 1, reason: 'el mismo kit para todos');
    final kit = s.battle!.state.party.first.skillIds;
    StatusKind? st(String id) => cat.skills[id]?.status?.kind;
    expect(kit.any((id) => st(id) == StatusKind.burn), isTrue);
    expect(kit.any((id) => st(id) == StatusKind.poison), isTrue);
    expect(kit.any((id) => cat.skills[id]!.instant), isTrue);
    expect(
        kit.any((id) =>
            cat.skills[id]!.pulse > 0 && cat.skills[id]!.requires.isEmpty),
        isTrue,
        reason: 'algo que cueste Pulso sin precondición');
    expect(kit, contains(kQuebrarId));
    expect(kit.any((id) => cat.skills[id]!.breaks && !cat.skills[id]!.pureBreak),
        isTrue,
        reason: 'una habilidad que "puede quebrar"');
    // Todas las habilidades del guion están en el kit.
    const rules = TutorialRules();
    for (final stg in kTutorialStages) {
      for (final n in [1, 2, 3, 4]) {
        for (final tu in rules.turnsOf(stg, n)) {
          final x = tu.step;
          if (x is TutorialPlayerStep && x.skillId != null) {
            final id = x.skillId == kTutorialQuebrar ? kQuebrarId : x.skillId;
            expect(kit, contains(id), reason: 'etapa ${stg.number}');
            if (x.alt != null) expect(kit, contains(x.alt));
          }
        }
      }
    }
  });

  test('parejas: con N jugadores, todos ponen y todos detonan', () {
    const rules = TutorialRules();
    final conv = kTutorialStages.firstWhere(
        (s) => s.kind == TutorialStageKind.pairs);
    for (var n = 1; n <= 5; n++) {
      final turns = rules.turnsOf(conv, n);
      final players = [
        for (final t in turns)
          if (t.step is TutorialPlayerStep) t.actor!
      ];
      final primers = {for (var i = 0; i < players.length; i += 2) players[i]};
      final detonators = {
        for (var i = 1; i < players.length; i += 2) players[i]
      };
      final all = {for (var i = 0; i < n; i++) i};
      expect(primers, all, reason: '$n: todos ponen');
      expect(detonators, all, reason: '$n: todos detonan');
      expect(turns.whereType<TutorialTurn>().where(
              (t) => t.step is TutorialResetStep),
          hasLength(n),
          reason: 'reinicio entre parejas');
      if (n > 1) {
        for (var i = 0; i < players.length; i += 2) {
          expect(players[i], isNot(players[i + 1]),
              reason: 'con más de uno, pone uno y detona otro');
        }
      }
    }
  });

  group('guion completo: cada humano hace cada cosa', () {
    for (final (humans, companions) in [
      (1, 0),
      (2, 0),
      (3, 0),
      (4, 0),
      (1, 1),
      (1, 3),
      (2, 2),
    ]) {
      test('$humans humano(s) + $companions IA', () {
        final e = sessionEngine();
        final (s, log) =
            _play(e, _start(e, _room(e, humans: humans, companions: companions)));
        final order = s.tutorial!.order;
        // En grupo, los compañeros IA no entran (§ 3).
        expect(order.length, humans + (humans == 1 ? companions : 0));
        for (final id in order) {
          final did = log.did[id] ?? const {};
          final human = s.players[id]?.isCompanion == false;
          const basics = [
            'defend', 'attack', 'mp', 'pulse+', 'pulse-', 'instant', //
            'resist', 'weak', 'status', 'prime', 'detonate', 'break',
          ];
          for (final k in basics) {
            expect(did, contains(k), reason: '$id ($human): $k');
          }
          for (final st in kTutorialStages) {
            expect(log.actedIn[st.number], contains(id),
                reason: 'etapa ${st.number}: $id no se queda mirando');
          }
        }
        if (humans > 1) {
          expect(log.breakSkills, {kQuebrarId, 'estocada'},
              reason: 'quiebran con Quebrar y con "puede quebrar"');
        }
        for (final p in s.playerList.where((p) => !p.isCompanion)) {
          expect(p.tutorialVersion, kTutorialVersion);
        }
      });
    }
  });

  test('quiebre: reinicio y barra llena sola antes de cada jugador', () {
    final e = sessionEngine();
    var fills = 0;
    var demo = 0;
    var sawEmpty = 0;
    final rules = e.tutorials;
    _play(e, _start(e, _room(e, humans: 3)), onTick: (s) {
      final t = s.tutorial!;
      final st = rules.currentStep(t);
      final boss = s.battle!.state.byId(TutorialRules.bossId)!;
      if (st is TutorialFillStep && st.reset && t.prepared && t.card == null) {
        // Reiniciado, todavía vacía.
        expect([boss.breakGauge, boss.fissured, boss.hp], [0, false, boss.maxHp]);
        sawEmpty++;
      }
    }, onCard: (s) {
      final t = s.tutorial!;
      final st = rules.currentStep(t);
      if (st is! TutorialFillStep) return;
      final boss = s.battle!.state.byId(TutorialRules.bossId)!;
      expect(boss.fissured, isTrue);
      expect(boss.breakGauge, boss.breakMax);
      if (!st.reset) {
        demo++;
        return;
      }
      fills++;
      expect(boss.hp, boss.maxHp, reason: 'autómata reiniciado');
      expect(boss.statuses, isEmpty);
      final line = t.card!.lines.single;
      expect(line, fills == 1 ? contains('puede quebrar') : startsWith('Barra llena'),
          reason: 'explica la primera vez; después, el dato');
      // Nadie pegó: solo el paso automático.
      final next = rules.currentTurns(t)[t.step + 1];
      expect(next.step, same(kTutorialBreakStep));
    });
    expect(demo, 1, reason: 'una vez se llena entre todos');
    expect(fills, 3, reason: 'una por jugador');
    expect(sawEmpty, greaterThan(0));
  });

  test('quebrado: se explica la primera vez y después solo el dato', () {
    final e = sessionEngine();
    final broken = <String>[];
    _play(e, _start(e, _room(e, humans: 2)), onCard: (s) {
      for (final l in s.tutorial!.card!.lines) {
        if (l.startsWith('¡QUEBRADO!')) broken.add(l);
      }
    });
    expect(broken.length, greaterThanOrEqualTo(2));
    expect(broken.first, contains('Pierde su turno'));
    expect(broken.last, contains('pierde su turno.'));
    expect(broken.last.length, lessThan(broken.first.length));
  });

  test('cada etapa arranca limpia: autómata, línea de tiempo y recursos', () {
    final e = sessionEngine();
    var checked = 0;
    _play(e, _start(e, _room(e, humans: 2)), onCard: (x) {
      final t = x.tutorial!;
      if (t.card!.effect || t.card!.heading != null) return;
      final b = x.battle!.state;
      final boss = b.byId(TutorialRules.bossId)!;
      final st = e.tutorials.currentStage(t)!;
      expect(t.step, 0);
      expect(boss.hp, boss.maxHp, reason: 'etapa ${st.number}');
      expect(boss.breakGauge, 0);
      expect(boss.fissured, isFalse);
      expect(boss.statuses, isEmpty, reason: 'etapa ${st.number}');
      expect(b.enemies.length, st.setup == TutorialSetup.adds ? 3 : 1);
      for (final p in b.party) {
        expect([p.hp, p.mp.round(), p.pulse],
            [p.maxHp, p.maxMp, BattleEngine.pulseStart],
            reason: 'etapa ${st.number} ${p.id}');
      }
      expect(b.currentId, isNull);
      checked++;
    });
    expect(checked, kTutorialStages.length);
  });

  test('el autómata espera la votación antes de actuar', () {
    final e = sessionEngine();
    var s = _start(e, _room(e, humans: 2));
    GameSession? found;
    for (var i = 0; i < 40000 && found == null; i++) {
      s = e.tick(s, 0.05).state;
      final t = s.tutorial!;
      if (t.card?.heading == 'ATENCIÓN') {
        found = s;
        break;
      }
      if (t.card != null) {
        s = _voteAll(e, s);
        continue;
      }
      final b = s.battle!;
      final st = e.tutorials.currentStep(t);
      if (b.waitingForPlayer && st is TutorialPlayerStep && t.prepared) {
        final cur = b.state.current!;
        s = act(e, s, cur.id, BattleAction(e.tutorials.scripted(st, cur)!));
      }
    }
    s = found!;
    expect(e.tutorials.currentStep(s.tutorial!), isA<TutorialEnemyStep>());
    final clock = s.battle!.state.clock;
    for (var i = 0; i < 200; i++) {
      s = e.tick(s, 0.5).state;
    }
    expect(s.tutorial!.card!.heading, 'ATENCIÓN', reason: 'sigue esperando');
    expect(s.battle!.state.clock, clock);
    s = act(e, s, 'h', const TutorialAckAction());
    s = e.tick(s, 0.05).state;
    expect(s.tutorial!.card!.heading, 'ATENCIÓN', reason: 'falta Beto');
    s = act(e, s, 'p1', const TutorialAckAction());
    s = e.tick(s, 0.05).state;
    expect(s.tutorial!.card!.effect, isTrue, reason: 'lo que hizo');
  });

  group('votación del final (sin roles)', () {
    test('Repetir tutorial, Ir a ENTRENAR o Salir; todos lo mismo', () {
      final e = sessionEngine();
      var (s, _) = _play(e, _start(e, _room(e, humans: 2)));
      expect(s.players['h']!.tutorialVersion, kTutorialVersion,
          reason: 'el guion completo ya cuenta');
      expect(e.tutorials.options(s.tutorial!).map((o) => o.$1),
          ['repeat', 'train', 'exit']);
      expect(e.apply(s, 'h', const TutorialChoiceAction('roles')), isNull);
      expect(e.apply(s, 'h', const TutorialChoiceAction('role:quiebra')),
          isNull);
      s = act(e, s, 'h', const TutorialChoiceAction('train'));
      s = act(e, s, 'p1', const TutorialChoiceAction('exit'));
      expect(s.tutorial!.phase, TutorialPhase.menu);
      expect(e.tutorials.pickLines(s),
          ['J0: IR A ENTRENAR', 'J1: SALIR', startsWith('Falta acuerdo')]);
      s = act(e, s, 'p1', const TutorialChoiceAction('train'));
      expect(s.tutorial!.phase, TutorialPhase.train);
    });

    test('Repetir tutorial: el guion entero otra vez', () {
      final e = sessionEngine();
      var (s, _) = _play(e, _start(e, _room(e, humans: 2)));
      final attempt = s.tutorial!.attempt;
      s = _pickAll(e, s, 'repeat');
      final t = s.tutorial!;
      expect(t.phase, TutorialPhase.script);
      expect(t.attempt, attempt + 1);
      expect(t.stages, [for (final st in kTutorialStages) st.number]);
      expect([t.stage, t.step], [0, 0]);
      expect(t.card!.lines.first, isNot(startsWith('Ya hiciste')));
      // Y viaja en el snapshot.
      final json = SessionJson(e.catalog);
      expect(json.fromJson(json.toJson(s)).tutorial!.toJson(), t.toJson());
      expect(t.toJson().containsKey('as'), isFalse);
    });

    test('Salir vuelve al lobby', () {
      final e = sessionEngine();
      var (s, _) = _play(e, _start(e, _room(e)));
      s = _pickAll(e, s, 'exit');
      expect(s.tutorial, isNull);
      expect(s.mode, SessionMode.lobby);
    });
  });

  group('ENTRENAR', () {
    for (final (humans, companions) in [(1, 0), (2, 0), (4, 0), (1, 3)]) {
      test('$humans humano(s) + $companions IA: el kit cubre todas las '
          'mecánicas', () {
        final e = sessionEngine();
        var (s, _) =
            _play(e, _start(e, _room(e, humans: humans, companions: companions)));
        s = _pickAll(e, s, 'train');
        final b = s.battle!.state;
        final cat = e.catalog;
        final all = [for (final c in b.party) ...c.skillIds];
        bool has(bool Function(String id) f) => all.any(f);
        StatusKind? st(String id) => cat.skills[id]?.status?.kind;
        expect(has((id) => cat.skills[id]!.pureBreak), isTrue, reason: 'Quebrar');
        expect(has((id) => st(id) == StatusKind.burn), isTrue);
        expect(has((id) => st(id) == StatusKind.poison), isTrue);
        expect(has((id) => cat.skills[id]!.instant), isTrue);
        expect(b.party.any((c) => c.ult >= 100), isTrue, reason: 'ULT');
        final boss = b.byId(TutorialRules.bossId)!;
        expect([boss.hp, boss.practice, b.enemies.length],
            [boss.maxHp, false, 1]);
        expect(s.tutorial!.narration, isNotEmpty);
      });
    }

    test('el autómata cae solo en ENTRENAR; después Reiniciar o Salir', () {
      final e = sessionEngine();
      var (s, _) = _play(e, _start(e, _room(e)));
      s = _pickAll(e, s, 'train');
      for (var i = 0; i < 400 && !s.battle!.waitingForPlayer; i++) {
        s = e.tick(s, 0.05).state;
      }
      s.battle!.state.byId('e0')!.hp = 1;
      s = act(e, s, 'h', const BattleAction(AttackCommand(targetId: 'e0')));
      expect(s.tutorial!.phase, TutorialPhase.trainOver);
      expect(e.tutorials.options(s.tutorial!).map((o) => o.$1),
          ['restart', 'exit']);
      s = _pickAll(e, s, 'restart');
      expect(s.tutorial!.phase, TutorialPhase.train);
      expect(s.battle!.state.byId('e0')!.alive, isTrue);
    });

    test('narrador: Convergencia entre jugadores y quiebre', () {
      const rules = TutorialRules();
      final e = sessionEngine();
      final s = _start(e, _room(e, humans: 2));
      final b0 = s.battle!.state;
      final lines = rules.narrate(b0.copy(), b0.copy(), [
        const ReactionEvent('e0', ReactionKind.combustion, 99,
            sourceId: 'p1', consumedStacks: 6),
      ], 'p1', primers: {'burn': 'h'});
      expect(lines.first, contains('J0 puso 6 de Quemadura y J1 detonó'));
      final broke = b0.copy();
      broke.byId('e0')!.breakSkip = true;
      expect(rules.narrate(b0, broke, const [], null),
          contains(startsWith('Fisurado → Quebraste')));
    });
  });

  test('Pulso: sus usos salen del catálogo (etapa 3 y glosario)', () {
    const rules = TutorialRules();
    final uses = rules.pulseSkills().map((s) => s.name).toList();
    expect(uses, containsAll(['Quebrar', 'Ignición Convergente',
        'Ponzoña Convergente', 'Rompearmaduras']));
    // Pedido del dueño: Pulso corto, solo qué es y cómo se gana; sin la
    // lista de habilidades y en ≤ 2 líneas.
    final introLines = rules.stageIntro(3);
    final intro = introLines.join(' ');
    final glos = rules.glossary().firstWhere((g) => g.title == 'Pulso').text;
    expect(introLines.length, lessThanOrEqualTo(2));
    expect(intro, contains('las habilidades fuertes lo piden'));
    expect(intro, contains('+1 al empezar tu turno'));
    expect(glos, contains('de 0 a ${BattleEngine.pulseMax}'));
    for (final n in uses) {
      expect(intro, isNot(contains(n)));
      expect(glos, isNot(contains(n)));
    }
  });
}
