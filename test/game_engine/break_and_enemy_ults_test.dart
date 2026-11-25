import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/battle_log_helper.dart';

// Barra de quiebre y ULT enemigas: docs/specs/break_and_enemy_ults.md.

const _startNodes = PassiveTreeCatalog(
  nodes: {
    's_gue': PassiveNode(id: 's_gue', x: 0, y: -1.1, name: 'Inicio: Guerrero', kind: 'st', effects: {'hp': 0.05, 'atk': 0.04}, links: []),
    's_mag': PassiveNode(id: 's_mag', x: 1.1, y: 0, name: 'Inicio: Maga', kind: 'st', effects: {'mp': 0.08, 'mag': 0.04}, links: []),
    's_tir': PassiveNode(id: 's_tir', x: 0, y: 1.1, name: 'Inicio: Tirador', kind: 'st', effects: {'crit': 0.03, 'spd': 0.3}, links: []),
    's_pal': PassiveNode(id: 's_pal', x: -1.1, y: 0, name: 'Inicio: Paladín', kind: 'st', effects: {'hp': 0.06, 'def': 1}, links: []),
  },
  startNodeByClass: {'guerrero': 's_gue', 'maga': 's_mag', 'tirador': 's_tir', 'paladin': 's_pal'},
  exclusions: {},
);

const _stats = StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(_startNodes));

/// Azar con valores fijos; cuando se acaban, 0.99 (nunca crítico).
BattleEngine _engine([List<double> rolls = const [], bool on = true]) {
  var i = 0;
  return BattleEngine(
    stats: _stats,
    random: () => i < rolls.length ? rolls[i++] : 0.99,
    breakEnabled: on,
    enemyUltsEnabled: on,
    // Las fórmulas de quiebre sin el ×1.5 de los constructos (el gólem):
    // las familias tienen sus propios tests (enemy_families_test.dart).
    familiesEnabled: false,
  );
}

BattlePartyMember _member(String id, String classId, {double ult = 0}) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: cls.name,
    ult: ult,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

/// [classId] (p1) solo contra [enemies], con el turno de p1 empezado.
BattleState _myTurn(BattleEngine engine, List<String> enemies,
    {String classId = 'guerrero', double ult = 0, bool elite = false}) {
  final start = engine.start(
    party: [_member('p1', classId, ult: ult)],
    enemyTypes: enemies,
    triggeredBy: 'p1',
    elite: elite,
  );
  final turn = engine.nextTurn(start.state).state;
  expect(turn.currentId, 'p1');
  return turn;
}

/// El grupo contra [enemy], con el turno del enemigo empezado (el
/// enemigo arranca primero con azar 0).
BattleState _enemyTurn(BattleEngine engine, String enemy,
    {List<String> classes = const ['guerrero'], bool elite = false}) {
  final start = engine.start(
    party: [for (var i = 0; i < classes.length; i++) _member('p${i + 1}', classes[i])],
    enemyTypes: [enemy],
    elite: elite,
  );
  final turn = engine.nextTurn(start.state).state;
  expect(turn.currentId, 'e0');
  return turn;
}

Iterable<BreakEvent> _breaks(BattleStep s) => s.events.whereType<BreakEvent>();

void main() {
  group('inicio', () {
    test('umbral en puntos: tipo × grupo (0.6 + 0.3 × jugadores) × élite; '
        'ULT solo jefes y élites', () {
      final s = _engine().start(
          party: [_member('p1', 'guerrero'), _member('p2', 'maga')],
          enemyTypes: ['golem', 'slime'],
          elite: true).state;
      // Común 12 × 1.2 (2 jugadores) × 2.5 (élite) = 36.
      expect(s.enemies[0].breakBase, closeTo(12 * 1.2 * 2.5, 1e-9));
      // ULT v2 (ultimates_v2.md § 4.3): cada élite trae la suya.
      expect(s.enemies[0].ultId, 'eult_e_golem');
      expect(s.enemies[1].breakBase, closeTo(12 * 1.2, 1e-9));
      expect(s.enemies[1].ultId, isNull);
      final boss = _engine()
          .start(party: [_member('p1', 'guerrero')], enemyTypes: ['devorador'])
          .state
          .enemies
          .single;
      expect(boss.breakBase, closeTo(95 * 0.9, 1e-9));
      expect(boss.ultId, 'eult_finEras');
      expect(s.party.every((p) => !p.hasBreak), isTrue);
    });

    test('se pueden apagar (tests angostos)', () {
      final e = _engine();
      final off = _engine(const [], false);
      final boss = off
          .start(party: [_member('p1', 'guerrero')], enemyTypes: ['reyLimo'])
          .state
          .enemies
          .single;
      expect([boss.hasBreak, boss.ultId], [false, null]);
      final step = off.command(
          _myTurn(off, ['reyLimo']), 'p1', const AttackCommand())!;
      expect(_breaks(step), isEmpty);
      expect(step.state.enemies.single.ult, 0);
      expect(e.breakEnabled && e.enemyUltsEnabled, isTrue);
    });

    test('toda arma trae la Quebrar base al final del kit', () {
      final g = _myTurn(_engine(), ['golem']).party.single;
      expect(g.skillIds.last, 'quebrar');
      final m = _myTurn(_engine(), ['golem'], classId: 'maga').party.single;
      expect(m.skillIds.last, 'quebrarArcano');
    });
  });

  group('puntos por tipo de acción (combo_balance.md § 5)', () {
    test('ataque básico: 4, sin mirar el daño', () {
      final engine = _engine();
      final step =
          engine.command(_myTurn(engine, ['golem']), 'p1', const AttackCommand())!;
      expect(step.state.enemies.single.breakGauge, 4);
      final b = _breaks(step).single;
      expect([b.phase, b.gauge, b.max], [BreakPhase.fill, 4, closeTo(10.8, 1e-9)]);
      // Va después del golpe.
      expect(step.events.indexOf(b),
          greaterThan(step.events.indexWhere((e) => e is DamageEvent)));
    });

    test('habilidad física: 6', () {
      final engine = _engine();
      final step = engine.command(
          _myTurn(engine, ['golem']), 'p1', const SkillCommand('embestida'))!;
      expect(step.state.enemies.single.breakGauge, 6);
    });

    test('habilidad mágica: 4', () {
      final engine = _engine();
      final step = engine.command(_myTurn(engine, ['golem'], classId: 'maga'),
          'p1', const SkillCommand('chispa'))!;
      expect(step.state.enemies.single.breakGauge, 4);
    });

    test('el crítico no suma', () {
      final engine = _engine([0.99, 0.0]);
      final step =
          engine.command(_myTurn(engine, ['golem']), 'p1', const AttackCommand())!;
      expect(step.events.whereType<DamageEvent>().single.critical, isTrue);
      expect(step.state.enemies.single.breakGauge, 4);
    });

    test('ULT: 12', () {
      final engine = _engine();
      final step = engine.command(
          _myTurn(engine, ['devorador'], ult: 100), 'p1', const UltimateCommand())!;
      expect(step.state.enemies.single.breakGauge, 12);
    });

    test('dúo: 10', () {
      final engine = _engine();
      final start = engine.start(
          party: [_member('p1', 'guerrero'), _member('p2', 'maga')],
          enemyTypes: ['devorador'],
          triggeredBy: 'p1');
      final step = engine.command(
          engine.nextTurn(start.state).state, 'p1', const DualCommand('p2'))!;
      expect(step.state.enemies.single.breakGauge, 10);
    });

    test('la Quebrar base pide objetivo Fisurado (paso 7, § 5.2)', () {
      final engine = _engine();
      // Sin Fisurado, el host la rechaza (antes sumaba 1 punto).
      expect(
          engine.command(
              _myTurn(engine, ['devorador']), 'p1', const SkillCommand('quebrar')),
          isNull);
    });

    test('daño secundario de notables (rebote): 0', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['golem', 'golem']);
      turn.party.single.mechanics = {'rebote'};
      final step = engine.command(turn, 'p1', const AttackCommand(targetId: 'e0'))!;
      final bounce = step.events
          .whereType<DamageEvent>()
          .singleWhere((d) => d.sourceId == 'rebote');
      expect(bounce.targetId, 'e1');
      expect(step.state.enemies[1].breakGauge, 0);
    });

    test('aturdir aplicado: +6 (también desde procs)', () {
      // Paladín: 3% de aturdir con el ataque (azar 0 en esa tirada).
      final engine = _engine([0.99, 0.99, 0.0]);
      final step = engine.command(
          _myTurn(engine, ['golem'], classId: 'paladin'), 'p1', const AttackCommand())!;
      expect(step.events.whereType<StatusAppliedEvent>().single.kind, StatusKind.stun);
      expect(step.state.enemies.single.breakGauge, 4 + 6);
    });

    test('los ticks de estado no suman', () {
      final engine = _engine([0.0]);
      final start = engine.start(party: [_member('p1', 'guerrero')], enemyTypes: ['golem']);
      start.state.enemies.single.statuses[StatusKind.burn] = 5;
      final step = engine.nextTurn(start.state);
      expect(step.state.currentId, 'e0');
      expect(step.state.enemies.single.breakGauge, 0);
    });

    test('la vida perdida carga la ULT enemiga: +1 por cada 1%', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['reyLimo']);
      expect(turn.enemies.single.ult, BattleEngine.enemyUltStart);
      final step = engine.command(turn, 'p1', const AttackCommand())!;
      // Rey Limo solo: 230 × 0.9 = 207 (soloBossHp 1.0).
      expect(step.state.enemies.single.ult, closeTo(40 + 15 / 207 * 100, 1e-9));
      // Los comunes no tienen ULT.
      final slime = engine
          .command(_myTurn(engine, ['slime']), 'p1', const AttackCommand())!
          .state
          .enemies
          .single;
      expect(slime.ult, 0);
    });
  });

  group('Fisurado y Quebrar', () {
    test('baja 10% del umbral al empezar el turno del enemigo', () {
      final engine = _engine([0.0]);
      final start = engine.start(party: [_member('p1', 'guerrero')], enemyTypes: ['golem']);
      start.state.enemies.single.breakGauge = 8;
      final step = engine.nextTurn(start.state);
      expect(step.state.currentId, 'e0');
      expect(step.state.enemies.single.breakGauge, closeTo(6.9, 1e-9));
      expect(_breaks(step).single.phase, BreakPhase.decay);
    });

    test('barra llena: FISURADO, no quebrado', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['golem']);
      turn.enemies.single.breakGauge = 8;
      final step = engine.command(turn, 'p1', const AttackCommand())!;
      final golem = step.state.enemies.single;
      expect(_breaks(step).single.phase, BreakPhase.fissured);
      expect([golem.fissured, golem.broken, golem.breakSkip], [true, false, false]);
      expect(golem.breakGauge, closeTo(10.8, 1e-9));
      expect(step.state.log, contains('¡Gólem queda FISURADO!'));
    });

    test('un golpe sin Quebrar no quiebra a un Fisurado', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['golem']);
      turn.enemies.single
        ..breakGauge = 10.8
        ..fissured = true;
      final step = engine.command(turn, 'p1', const AttackCommand())!;
      expect(_breaks(step), isEmpty);
      expect(step.state.enemies.single.fissured, isTrue);
    });

    test('Quebrar sobre un no Fisurado: rechazada, no suma nada', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['golem']);
      turn.enemies.single.breakGauge = 2;
      expect(engine.command(turn, 'p1', const SkillCommand('quebrar')), isNull);
    });

    test('la ULT que llena la barra no quiebra en el mismo golpe', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['devorador'], ult: 100);
      turn.enemies.single.breakGauge = 80;
      final step = engine.command(turn, 'p1', const UltimateCommand())!;
      expect(_breaks(step).single.phase, BreakPhase.fissured);
      expect(step.state.enemies.single.broken, isFalse);
    });

    test('Quebrar sobre un Fisurado: ¡QUIEBRE!, pierde el turno, +50% de daño '
        '2 turnos del grupo, después la barra a 0 y el umbral +25%', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['golem']);
      turn.enemies.single
        ..breakGauge = 10.8
        ..fissured = true;
      final step = engine.command(turn, 'p1', const SkillCommand('quebrar'))!;
      var golem = step.state.enemies.single;
      expect(_breaks(step).single.phase, BreakPhase.broken);
      expect([golem.vulnerable, golem.breakSkip, golem.fissured], [2, true, false]);
      expect(golem.breakGauge, closeTo(10.8, 1e-9));
      expect(step.state.log, contains('¡QUIEBRE! Gólem: pierde su turno, +50% de daño'));

      // Hasta que se recupera: pierde su turno y los golpes hacen +50%.
      var s = step.state;
      var skipped = false;
      var boosted = 0;
      var recovered = false;
      for (var i = 0; i < 12 && !recovered; i++) {
        final n = engine.nextTurn(s);
        if (_breaks(n).any((b) => b.phase == BreakPhase.skipped)) {
          skipped = true;
          expect(n.state.log, contains('Gólem está QUEBRADO y pierde su turno'));
        }
        s = n.state;
        if (s.currentId != 'p1') continue;
        final a = engine.command(s, 'p1', const AttackCommand())!;
        final hit = a.events.whereType<DamageEvent>().first;
        if (hit.vulnerable) {
          boosted++;
          expect(hit.amount, 23); // 15 × 1.5 = 22.5
          // Quebrado, la barra no se llena.
          expect(_breaks(a).where((b) => b.phase == BreakPhase.fill), isEmpty);
        }
        recovered = _breaks(a).any((b) => b.phase == BreakPhase.recovered);
        s = a.state;
      }
      expect([skipped, boosted, recovered], [true, 2, true]);
      golem = s.enemies.single;
      expect([golem.vulnerable, golem.breaks], [0, 1]);
      expect(golem.breakMax, closeTo(10.8 * 1.25, 1e-9));
      expect(s.log, contains('Gólem se recupera del quiebre'));
    });

    test('Fisurado que llega a su turno: la barra vuelve a la mitad', () {
      final engine = _engine([0.0]);
      final start = engine.start(party: [_member('p1', 'guerrero')], enemyTypes: ['golem']);
      start.state.enemies.single
        ..breakGauge = 10.8
        ..fissured = true;
      final step = engine.nextTurn(start.state);
      expect(step.state.currentId, 'e0');
      final golem = step.state.enemies.single;
      expect([golem.fissured, golem.breakGauge], [false, closeTo(5.4, 1e-9)]);
      expect(_breaks(step).single.phase, BreakPhase.steadied);
      expect(step.state.log, contains('se recompone'));
    });

    test('el umbral sube +25% por quiebre con tope ×2', () {
      final e = Combatant(
          id: 'e', name: 'e', isPlayer: false, hp: 1, maxHp: 1, speed: 1,
          attack: 1, critChance: 0, breakBase: 80);
      expect(e.breakMax, 80);
      e.breaks = 2;
      expect(e.breakMax, 120);
      e.breaks = 9;
      expect(e.breakMax, 160);
    });
  });

  group('ULT enemigas', () {
    test('+25 por turno propio (jefes y élites empiezan con 40)', () {
      final engine = _engine([0.0]);
      final step = engine.enemyTurn(_enemyTurn(engine, 'reyLimo'))!;
      expect(step.state.enemies.single.ult, 40 + 25);
      expect(step.events.first, isA<ActionEvent>());
    });

    test('con la carga llena avisa (no ataca) y la lanza en su próximo '
        'turno', () {
      final engine = _engine([0.0]);
      final turn = _enemyTurn(engine, 'reyLimo', classes: ['guerrero', 'maga']);
      turn.enemies.single.ult = 100;
      final warn = engine.enemyTurn(turn)!;
      final w = warn.events.whereType<EnemyUltWarningEvent>().single;
      expect([w.actorId, w.ultId, w.name], ['e0', 'eult_diluvio', 'Diluvio Ácido']);
      expect(warn.events.whereType<ActionEvent>(), isEmpty);
      expect(warn.events.whereType<DamageEvent>(), isEmpty);
      expect(warn.state.enemies.single.ultPending, isTrue);
      expect(warn.state.log,
          startsWith('¡El Rey Limo se prepara para Diluvio Ácido!'));

      // Su siguiente turno: Diluvio Ácido (ATQ × 1.2 a todos + 2 Veneno).
      final again = warn.state.copy()..currentId = 'e0';
      final ult = engine.enemyTurn(again)!;
      final u = ult.events.first as EnemyUltEvent;
      expect([u.ultId, u.allTargets, u.targetId], ['eult_diluvio', true, null]);
      final hits = ult.events.whereType<DamageEvent>().toList();
      expect(hits.map((h) => h.targetId), ['p1', 'p2']);
      // Guerrero: 13 × 1.4 (ATQ de grupo, 2 jugadores) = 18 × 1.2 ×
      // (1 − 9%) = 19.7.
      expect(hits.first.amount, 20);
      for (final p in ult.state.party) {
        expect(p.stacks(StatusKind.poison), 2);
      }
      final boss = ult.state.enemies.single;
      expect([boss.ult, boss.ultPending], [0, false]);
      expect(ult.state.log, contains('Rey Limo · ULT Diluvio Ácido'));
    });

    test('Engranaje del Fin: ATQ × 1.5 al objetivo + Congelación 3 y '
        'retrasa a todos × 0.5', () {
      final engine = _engine([0.0]);
      final turn = _enemyTurn(engine, 'golemReloj', classes: ['guerrero', 'maga']);
      turn.enemies.single.ultPending = true;
      final before = {for (final p in turn.party) p.id: p.nextTurn};
      final step = engine.enemyTurn(turn)!;
      final u = step.events.first as EnemyUltEvent;
      expect(u.allTargets, isFalse);
      final victim = step.state.byId(u.targetId!)!;
      expect(step.events.whereType<DamageEvent>().single.targetId, victim.id);
      expect(victim.stacks(StatusKind.freeze), 3);
      for (final p in step.state.party) {
        // Retrasados la mitad de su intervalo (antes de la Congelación del
        // golpe, que no cambia el `nextTurn` ya calculado).
        expect(p.nextTurn, greaterThan(before[p.id]!));
      }
      expect(step.events.whereType<DelayedEvent>(), hasLength(2));
    });

    test('Fin de las Eras: ATQ × 1.4 a todos + 2 Quemadura y borra los '
        'buffs del grupo (los escudos absorben antes)', () {
      final engine = _engine([0.0]);
      final turn = _enemyTurn(engine, 'devorador');
      final p = turn.party.single
        // El Devorador es de nivel 50 (v0.3): que aguante el golpe.
        ..maxHp = 9999
        ..hp = 9999
        ..bonusDefense = 4
        ..effects = [
          const TimedEffect(sourceId: 'represalia', stat: BuffStat.attack, value: 0.3, turns: 2),
          const TimedEffect(sourceId: 'egida', stat: BuffStat.shield, value: 5, turns: 2),
          const TimedEffect(sourceId: 'debilitar', stat: BuffStat.attack, value: -0.15, turns: 2),
        ];
      turn.enemies.single.ultPending = true;
      final step = engine.enemyTurn(turn)!;
      expect((step.events.first as EnemyUltEvent).wipedBuffs, isTrue);
      expect(step.events.whereType<ShieldEvent>().single.absorbed, isTrue);
      final q = step.state.party.single;
      expect(q.stacks(StatusKind.burn), 2);
      expect(q.effects.map((e) => e.sourceId), ['debilitar']);
      expect(q.bonusDefense, 0);
      expect(step.state.log, contains('borra los buffs del grupo'));
      expect(p.bonusDefense, 4, reason: 'el estado de entrada no cambia');
    });

    test('Puño de Piedra (élite de Gólem): ATQ × 2.0 al objetivo', () {
      final engine = _engine([0.0]);
      final turn = _enemyTurn(engine, 'golem', elite: true);
      turn.enemies.single.ultPending = true;
      final step = engine.enemyTurn(turn)!;
      expect((step.events.first as EnemyUltEvent).name, 'Puño de Piedra');
      final hit = step.events.whereType<DamageEvent>().single;
      // Sin crítico garantizado (la Furia Élite queda de respaldo).
      expect(hit.critical, isFalse);
      // 16 × 2 × (1 − 9%) = 29.12.
      expect(hit.amount, 29);
      // combat.md § "Control sobre jugadores": break fill, not a stun.
      expect(step.state.party.single.stacks(StatusKind.stun), 0);
    });

    test('Defender reduce a la mitad', () {
      final engine = _engine([0.0]);
      final turn = _enemyTurn(engine, 'golem', elite: true);
      turn.enemies.single.ultPending = true;
      turn.party.single.defending = true;
      final hit = engine.enemyTurn(turn)!.events.whereType<DamageEvent>().single;
      expect(hit.amount, 15); // 29.12 / 2 = 14.56
    });

    test('quebrarlo antes cancela la ULT avisada', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['reyLimo']);
      final boss = turn.enemies.single
        ..ult = 100
        ..ultPending = true;
      expect(boss.breakMax, closeTo(65 * 0.9, 1e-9));
      boss
        ..breakGauge = boss.breakMax
        ..fissured = true;
      final step = engine.command(turn, 'p1', const SkillCommand('quebrar'))!;
      final b = _breaks(step).single;
      expect([b.phase, b.cancelledUlt], [BreakPhase.broken, true]);
      final after = step.state.enemies.single;
      expect([after.ultPending, after.ult], [false, 0]);
      expect(step.state.log, contains('Diluvio Ácido cancelada'));
      // Y su turno lo pierde (no hay ULT ni aviso).
      final t = engine.nextTurn(step.state);
      expect(t.events.whereType<EnemyUltEvent>(), isEmpty);
      expect(_breaks(t).single.phase, BreakPhase.skipped);
    });
  });

  group('determinismo y red', () {
    String run() {
      var seed = 7;
      double rnd() {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return seed / 0x80000000;
      }

      final engine = BattleEngine(stats: _stats, random: rnd);
      var s = engine
          .start(
              party: [_member('p1', 'guerrero'), _member('p2', 'maga')],
              enemyTypes: ['reyLimo', 'slime'])
          .state;
      final log = <String>[];
      for (var i = 0; i < 80 && !s.ended; i++) {
        if (s.currentId == null) {
          s = engine.nextTurn(s).state;
        } else if (!s.current!.isPlayer) {
          s = engine.enemyTurn(s)!.state;
        } else {
          s = (engine.command(s, s.currentId!, const AttackCommand()) ??
                  engine.timeout(s)!)
              .state;
        }
        log.add(s.log);
      }
      return jsonEncode([log, const SessionJson().battleStateToJson(s)]);
    }

    test('con el mismo azar, la misma batalla', () {
      expect(run(), run());
    });

    test('el estado de quiebre y la carga de ULT viajan en el snapshot', () {
      final e = Combatant(
        id: 'e0', name: 'Rey Limo', isPlayer: false, hp: 100, maxHp: 230,
        speed: 8, attack: 13, critChance: 0.12, enemyType: 'reyLimo', boss: true,
        breakBase: 80, breakGauge: 33.5, breaks: 1, vulnerable: 2,
        breakSkip: true, fissured: true, ultId: 'eult_diluvio', ultPending: true,
        ult: 100,
      );
      const json = SessionJson();
      final text = jsonEncode(json.combatantToJson(e));
      final back = json.combatantFromJson(asJson(jsonDecode(text)));
      expect(jsonEncode(json.combatantToJson(back)), text);
      expect([back.breakBase, back.breakGauge, back.breaks, back.vulnerable,
          back.breakSkip, back.fissured, back.ultId, back.ultPending],
          [80, 33.5, 1, 2, true, true, 'eult_diluvio', true]);
      // Un estado viejo (sin los campos) se lee con los valores por defecto.
      final old = json.combatantToJson(e)
        ..remove('brkB')
        ..remove('brk')
        ..remove('eult');
      final o = json.combatantFromJson(asJson(jsonDecode(jsonEncode(old))));
      expect([o.hasBreak, o.breakGauge, o.ultId], [false, 0, null]);
    });
  });
}
