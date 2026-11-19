import 'package:echos_del_tiempo/features/combat/domain/skill_text.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart' show kQuebrarId;
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// TUTORIAL v0.9.6 (docs/specs/combat_tutorial.md § 4.2 y § 4.4): todos
/// actúan, cada etapa arranca limpia, el autómata espera la votación, las
/// votaciones del final, ENTRENAR y su narrador, y el costo "P2".

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
        .addCompanion(s, 'h-c$i', newProfile('C$i', _classes[i + 1]),
            leaderId: 'h')!
        .state;
  }
  return s;
}

GameSession _voteAll(SessionEngine e, GameSession s) {
  for (final p in e.tutorials.waiting(s)) {
    final r = e.apply(s, p.id, const TutorialAckAction());
    if (r != null) s = r.state;
  }
  return s;
}

/// Un tick del guion: vota los carteles y cada humano hace su paso.
/// [onCard] ve cada cartel antes de votarlo.
GameSession _step(SessionEngine e, GameSession s,
    {void Function(GameSession s)? onCard}) {
  s = e.tick(s, 0.05).state;
  final t = s.tutorial;
  final b = s.battle;
  if (t == null || b == null) return s;
  if (t.card != null) {
    onCard?.call(s);
    return _voteAll(e, s);
  }
  if (!b.waitingForPlayer) return s;
  final cur = b.state.current!;
  if (s.players[cur.id]?.isCompanion != false) return s;
  final st = e.tutorials.currentStep(t);
  if (st is TutorialPlayerStep && t.prepared) {
    final r = e.apply(s, cur.id, BattleAction(e.tutorials.scripted(st, cur)!));
    if (r != null) s = r.state;
  }
  return s;
}

/// Juega el guion hasta la votación del final.
GameSession _toMenu(SessionEngine e, GameSession s,
    {void Function(GameSession s)? onCard}) {
  for (var i = 0; i < 40000; i++) {
    if (s.tutorial?.phase != TutorialPhase.script) break;
    s = _step(e, s, onCard: onCard);
  }
  expect(s.tutorial!.phase, TutorialPhase.menu);
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
    expect(plain(describeSkillMarkup(ign, null)),
        contains('${ign.mp} MP · ${ign.pulse} Pulso'));
  });

  test('cada etapa tiene un paso para cada rol y la clave va al final', () {
    for (final st in kTutorialStages) {
      final roles = {
        for (final x in st.steps)
          if (x is TutorialPlayerStep) x.role
      };
      expect(roles, TutorialRole.values.toSet(), reason: 'etapa ${st.number}');
      for (final x in st.steps.whereType<TutorialPlayerStep>()) {
        expect(x.why, isNotNull, reason: 'etapa ${st.number}: para qué');
      }
    }
  });

  group('todos actúan en cada etapa', () {
    for (final (humans, companions) in [(1, 0), (2, 0), (4, 0), (1, 3)]) {
      test('$humans humano(s) + $companions IA', () {
        final e = sessionEngine();
        var s = _start(e, _room(e, humans: humans, companions: companions));
        // Quién actuó en cada etapa (por los eventos de acción).
        final acted = <int, Set<String>>{};
        var last = s;
        for (var i = 0; i < 40000; i++) {
          if (s.tutorial?.phase != TutorialPhase.script) break;
          final stage = e.tutorials.currentStage(s.tutorial!)?.number;
          final r = e.tick(s, 0.05);
          for (final ev in r.events.whereType<BattleStepEvent>()) {
            for (final a in ev.events.whereType<ActionEvent>()) {
              if (stage != null) acted.putIfAbsent(stage, () => {}).add(a.actorId);
            }
          }
          s = r.state;
          final t = s.tutorial!;
          if (t.card != null) {
            s = _voteAll(e, s);
            continue;
          }
          final b = s.battle!;
          if (!b.waitingForPlayer) continue;
          final cur = b.state.current!;
          if (s.players[cur.id]?.isCompanion != false) continue;
          final st = e.tutorials.currentStep(t);
          if (st is TutorialPlayerStep && t.prepared) {
            final stg = e.tutorials.currentStage(t)!.number;
            final rr =
                e.apply(s, cur.id, BattleAction(e.tutorials.scripted(st, cur)!));
            if (rr != null) {
              s = rr.state;
              acted.putIfAbsent(stg, () => {}).add(cur.id);
            }
          }
          last = s;
        }
        expect(last, isNotNull);
        final everyone = s.tutorial!.order.toSet();
        for (final st in kTutorialStages) {
          expect(acted[st.number], containsAll(everyone),
              reason: 'etapa ${st.number}: nadie se queda mirando');
        }
      });
    }
  });

  test('cada etapa arranca limpia: autómata, línea de tiempo y recursos', () {
    final e = sessionEngine();
    var s = _start(e, _room(e, humans: 2));
    var checked = 0;
    _toMenu(e, s, onCard: (x) {
      final t = x.tutorial!;
      if (t.card!.effect || t.card!.heading != null) return;
      final b = x.battle!.state;
      final boss = b.byId(TutorialRules.bossId)!;
      final st = e.tutorials.currentStage(t)!;
      expect(boss.hp, boss.maxHp, reason: 'etapa ${st.number}');
      expect(boss.breakGauge, 0);
      expect(boss.fissured, isFalse);
      if (st.setup != TutorialSetup.poisonPrimed) {
        expect(boss.statuses, isEmpty, reason: 'etapa ${st.number}');
      }
      expect(b.enemies.length, st.setup == TutorialSetup.adds ? 3 : 1);
      for (final p in b.party) {
        expect([p.hp, p.mp.round(), p.pulse],
            [p.maxHp, p.maxMp, BattleEngine.pulseStart],
            reason: 'etapa ${st.number} ${p.id}');
      }
      expect(b.currentId, isNull, reason: 'la línea de tiempo vuelve a armarse');
      checked++;
    });
    expect(checked, kTutorialStages.length);
  });

  test('el autómata espera la votación antes de actuar', () {
    final e = sessionEngine();
    var s = _start(e, _room(e, humans: 2));
    // Hasta el cartel que anuncia al autómata (etapa 4).
    GameSession? found;
    for (var i = 0; i < 40000 && found == null; i++) {
      s = _step(e, s, onCard: (x) {
        if (x.tutorial!.card!.heading == 'ATENCIÓN') found = x;
      });
    }
    s = found!;
    final t = s.tutorial!;
    expect(e.tutorials.currentStep(t), isA<TutorialEnemyStep>());
    expect(t.card!.lines.single, startsWith('Ahora actúa el autómata'));
    final clock = s.battle!.state.clock;
    final hp = {for (final c in s.battle!.state.party) c.id: c.hp};
    for (var i = 0; i < 200; i++) {
      s = e.tick(s, 0.5).state;
    }
    expect(s.tutorial!.card!.heading, 'ATENCIÓN', reason: 'sigue esperando');
    expect(s.battle!.state.clock, clock);
    expect({for (final c in s.battle!.state.party) c.id: c.hp}, hp);
    // Votan todos: actúa y explica lo que hizo.
    s = act(e, s, 'h', const TutorialAckAction());
    s = e.tick(s, 0.05).state;
    expect(s.tutorial!.card!.heading, 'ATENCIÓN', reason: 'falta Beto');
    s = act(e, s, 'p1', const TutorialAckAction());
    s = e.tick(s, 0.05).state;
    expect(s.tutorial!.card!.effect, isTrue, reason: 'lo que hizo');
  });

  group('votaciones del final', () {
    test('menú: hace falta que todos elijan lo mismo', () {
      final e = sessionEngine();
      var s = _toMenu(e, _start(e, _room(e, humans: 2)));
      expect(s.players['h']!.tutorialVersion, kTutorialVersion,
          reason: 'el guion completo ya cuenta');
      expect(e.tutorials.options(s.tutorial!).map((o) => o.$1),
          ['roles', 'train', 'exit']);
      expect(e.apply(s, 'h', const TutorialChoiceAction('restart')), isNull,
          reason: 'opción que no está');
      s = act(e, s, 'h', const TutorialChoiceAction('train'));
      s = act(e, s, 'p1', const TutorialChoiceAction('exit'));
      expect(s.tutorial!.phase, TutorialPhase.menu);
      expect(e.tutorials.pickLines(s),
          ['J0: IR A ENTRENAR', 'J1: SALIR', startsWith('Falta acuerdo')]);
      s = act(e, s, 'p1', const TutorialChoiceAction('train'));
      expect(s.tutorial!.phase, TutorialPhase.train);
      expect(s.mode, SessionMode.battle, reason: 'sin salir de la misión');
    });

    test('roles: cada uno elige, sin repetir, y se repite con esos roles',
        () {
      final e = sessionEngine();
      var s = _toMenu(e, _start(e, _room(e, humans: 2)));
      final attempt = s.tutorial!.attempt;
      s = _pickAll(e, s, 'roles');
      expect(s.tutorial!.phase, TutorialPhase.roles);
      s = act(e, s, 'h', const TutorialChoiceAction('role:quiebra'));
      s = act(e, s, 'p1', const TutorialChoiceAction('role:quiebra'));
      expect(s.tutorial!.phase, TutorialPhase.roles);
      expect(e.tutorials.pickLines(s).last, startsWith('Hay un rol repetido'));
      s = act(e, s, 'p1', const TutorialChoiceAction('role:acumula'));
      final t = s.tutorial!;
      expect(t.phase, TutorialPhase.script);
      expect(t.attempt, attempt + 1);
      final present = {'h', 'p1'};
      final rules = e.tutorials;
      expect(rules.actorOf(t, TutorialRole.quiebra, present), 'h');
      expect(rules.actorOf(t, TutorialRole.acumula, present), 'p1');
      expect(rules.rolesOf(t, 'h', present), contains(TutorialRole.quiebra));
      // El kit sigue a los roles elegidos.
      expect(s.battle!.state.byId('p1')!.skillIds, contains('bola'));
      // Y viaja en el snapshot.
      final json = SessionJson(e.catalog);
      expect(json.fromJson(json.toJson(s)).tutorial!.toJson(), t.toJson());
    });

    test('roles con un humano y compañeros: el resto va a la IA', () {
      const rules = TutorialRules();
      final a = rules.assignRoles({'h': 'role:detona'}, ['h', 'c0', 'c1', 'c2']);
      expect(a[TutorialRole.detona], 'h');
      expect({a[TutorialRole.acumula], a[TutorialRole.barra], a[TutorialRole.quiebra]},
          {'c0', 'c1', 'c2'});
      final solo = rules.assignRoles({'h': 'role:barra'}, ['h']);
      expect(solo.values.toSet(), {'h'});
    });
  });

  group('ENTRENAR', () {
    for (final (humans, companions) in [(1, 0), (2, 0), (4, 0), (1, 3)]) {
      test('$humans humano(s) + $companions IA: el kit cubre todas las '
          'mecánicas', () {
        final e = sessionEngine();
        var s = _toMenu(e, _start(e, _room(e, humans: humans, companions: companions)));
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
        expect(has((id) => st(id) == StatusKind.freeze || st(id) == StatusKind.stun),
            isTrue);
        expect(b.party.any((c) => c.ult >= 100), isTrue, reason: 'ULT');
        // Combustión y Explosión tóxica entre jugadores distintos.
        if (b.party.length > 1) {
          final burner = b.party.firstWhere(
              (c) => c.skillIds.any((id) => st(id) == StatusKind.burn));
          final poisoner = b.party.firstWhere(
              (c) => c.skillIds.any((id) => st(id) == StatusKind.poison));
          expect(burner.id, isNot(poisoner.id));
        }
        // Todo reseteado.
        final boss = b.byId(TutorialRules.bossId)!;
        expect([boss.hp, boss.practice, b.enemies.length],
            [boss.maxHp, false, 1]);
        expect(s.tutorial!.narration, isNotEmpty);
      });
    }

    test('el autómata cae solo en ENTRENAR; después Reiniciar o Salir', () {
      final e = sessionEngine();
      var s = _start(e, _room(e));
      expect(s.battle!.state.byId('e0')!.practice, isTrue,
          reason: 'en el guion no muere');
      s = _pickAll(e, _toMenu(e, s), 'train');
      // Hasta el turno de Ana.
      for (var i = 0; i < 400 && !s.battle!.waitingForPlayer; i++) {
        s = e.tick(s, 0.05).state;
      }
      s.battle!.state.byId('e0')!.hp = 1;
      s = act(e, s, 'h', const BattleAction(AttackCommand(targetId: 'e0')));
      expect(s.tutorial!.phase, TutorialPhase.trainOver);
      expect(s.tutorial!.narration.join(' '), contains('cayó'));
      expect(e.tutorials.options(s.tutorial!).map((o) => o.$1),
          ['restart', 'exit']);
      s = _pickAll(e, s, 'restart');
      expect(s.tutorial!.phase, TutorialPhase.train);
      expect(s.battle!.state.byId('e0')!.alive, isTrue);
      s = e.tick(s, 0.05).state;
      expect(e.apply(s, 'h', const TutorialChoiceAction('exit')), isNull,
          reason: 'Salir solo se vota con el autómata caído o en el menú');
      s.battle!.state.byId('e0')!.hp = 0;
      s = e.tick(s, 0.05).state;
      expect(s.tutorial!.phase, TutorialPhase.trainOver);
      s = _pickAll(e, s, 'exit');
      expect(s.tutorial, isNull);
      expect(s.mode, SessionMode.lobby);
    });

    test('narrador: líneas desde los eventos reales', () {
      final e = sessionEngine();
      var s = _pickAll(e, _toMenu(e, _start(e, _room(e, humans: 2))), 'train');
      // Ana pega con Fuego (su debilidad).
      for (var i = 0; i < 400; i++) {
        s = e.tick(s, 0.05).state;
        final b = s.battle!;
        if (b.waitingForPlayer &&
            b.state.current!.skillIds.contains('bola')) {
          break;
        }
      }
      final who = s.battle!.state.currentId!;
      s = act(e, s, who,
          const BattleAction(SkillCommand('bola', targetId: 'e0')));
      final text = s.tutorial!.narration.join('\n');
      expect(text, contains('Golpe a la debilidad'));
      expect(text, contains('Quemadura +'));
      expect(text, contains('+1 Pulso (golpe a la debilidad)'));
      expect(s.tutorial!.primers['burn'], who);

      // Convergencia entre jugadores, Quebrar, Instante y ULT.
      const rules = TutorialRules();
      final b0 = s.battle!.state;
      final other = b0.party.firstWhere((c) => c.id != who);
      final before = b0.copy();
      final after = b0.copy();
      final def = rules.catalog.reaction(ReactionKind.combustion);
      final lines = rules.narrate(before, after, [
        ReactionEvent('e0', ReactionKind.combustion, 99,
            sourceId: other.id, consumedStacks: 6),
        UltimateUsedEvent(other.id, 'Tajo'),
      ], other.id, primers: {'burn': who});
      final whoName = b0.byId(who)!.name;
      expect(
          lines.first,
          '${other.name}: ¡Combustión! ($whoName puso 6 de Quemadura y '
          '${other.name} detonó con Veneno: 6 × '
          '${(def.perStack * 100).toStringAsFixed(1).replaceAll('.0', '')}% '
          'de la vida = 99 de daño)');
      expect(lines, contains('${other.name}: ULT: ${other.name} usó Tajo.'));
      final fis = b0.copy();
      fis.byId('e0')!
        ..fissured = true
        ..breakSkip = false;
      final broke = b0.copy();
      broke.byId('e0')!.breakSkip = true;
      final chain = b0.copy()..byId(other.id)!.chained = true;
      expect(rules.narrate(fis, broke, const [], null),
          contains(startsWith('Fisurado → Quebraste: pierde el turno')));
      expect(rules.narrate(b0, chain, const [], other.id),
          contains('${other.name}: Encadenaste un Instante: otra acción en '
              'el mismo turno.'));
    });
  });

  test('Pulso: sus usos salen del catálogo (etapa 2 y glosario)', () {
    const rules = TutorialRules();
    final uses = rules.pulseSkills().map((s) => s.name).toList();
    expect(uses, containsAll(['Quebrar', 'Ignición Convergente',
        'Ponzoña Convergente', 'Rompearmaduras']));
    final intro = rules.stageIntro(2).join(' ');
    final glos = rules.glossary().firstWhere((g) => g.title == 'Pulso').text;
    for (final n in uses) {
      expect(intro, contains(n));
      expect(glos, contains(n));
    }
    expect(glos, contains('reacción'));
  });
}
