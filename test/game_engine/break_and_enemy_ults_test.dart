import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
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
    test('umbral por tipo × grupo × élite; ULT solo jefes y élites', () {
      final s = _engine().start(
          party: [_member('p1', 'guerrero'), _member('p2', 'maga')],
          enemyTypes: ['golem', 'slime'],
          elite: true).state;
      // 50 × 1.45 (2 jugadores) × 1.5 (élite).
      expect(s.enemies[0].breakBase, closeTo(50 * 1.45 * 1.5, 1e-9));
      expect(s.enemies[0].ultId, kEliteUltId);
      expect(s.enemies[1].breakBase, closeTo(25 * 1.45, 1e-9));
      expect(s.enemies[1].ultId, isNull);
      final boss = _engine()
          .start(party: [_member('p1', 'guerrero')], enemyTypes: ['devorador'])
          .state
          .enemies
          .single;
      expect([boss.breakBase, boss.ultId], [910, 'eult_finEras']);
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
  });

  group('llenado por tipo de acción', () {
    test('ataque básico ×1.0', () {
      final engine = _engine();
      final step =
          engine.command(_myTurn(engine, ['golem']), 'p1', const AttackCommand())!;
      expect(step.state.enemies.single.breakGauge, 15);
      final b = _breaks(step).single;
      expect([b.phase, b.gauge, b.max], [BreakPhase.fill, 15, 50]);
      // Va después del golpe.
      expect(step.events.indexOf(b),
          greaterThan(step.events.indexWhere((e) => e is DamageEvent)));
    });

    test('habilidad física ×1.3', () {
      final engine = _engine();
      final step = engine.command(
          _myTurn(engine, ['golem']), 'p1', const SkillCommand('embestida'))!;
      expect(step.state.enemies.single.breakGauge, closeTo(18 * 1.3, 1e-9));
    });

    test('habilidad mágica ×0.8', () {
      final engine = _engine();
      final step = engine.command(_myTurn(engine, ['golem'], classId: 'maga'),
          'p1', const SkillCommand('chispa'))!;
      final dmg = step.events.whereType<DamageEvent>().first.amount;
      expect(step.state.enemies.single.breakGauge, closeTo(dmg * 0.8, 0.05));
    });

    test('crítico ×1.5 adicional', () {
      final engine = _engine([0.99, 0.0]);
      final step =
          engine.command(_myTurn(engine, ['golem']), 'p1', const AttackCommand())!;
      expect(step.events.whereType<DamageEvent>().single.critical, isTrue);
      expect(step.state.enemies.single.breakGauge, closeTo(23 * 1.5, 1e-9));
    });

    test('ULT ×2.0', () {
      final engine = _engine();
      final step = engine.command(
          _myTurn(engine, ['devorador'], ult: 100), 'p1', const UltimateCommand())!;
      expect(step.state.enemies.single.breakGauge, 45 * 2.0);
    });

    test('dúo ×1.5', () {
      final engine = _engine();
      final start = engine.start(
          party: [_member('p1', 'guerrero'), _member('p2', 'maga')],
          enemyTypes: ['devorador'],
          triggeredBy: 'p1');
      final step = engine.command(
          engine.nextTurn(start.state).state, 'p1', const DualCommand('p2'))!;
      final dmg = step.events.whereType<DamageEvent>().single.amount;
      expect(step.state.enemies.single.breakGauge, closeTo(dmg * 1.5, 0.05));
    });

    test('daño secundario de notables ×0.5 (rebote)', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['golem', 'golem']);
      turn.party.single.mechanics = {'rebote'};
      final step = engine.command(turn, 'p1', const AttackCommand(targetId: 'e0'))!;
      final bounce = step.events
          .whereType<DamageEvent>()
          .singleWhere((d) => d.sourceId == 'rebote');
      expect(bounce.targetId, 'e1');
      expect(step.state.enemies[1].breakGauge, closeTo(bounce.amount * 0.5, 1e-9));
    });

    test('aturdir aplicado: +15 plano (también desde procs)', () {
      // Paladín: 3% de aturdir con el ataque (azar 0 en esa tirada).
      final engine = _engine([0.99, 0.99, 0.0]);
      final step = engine.command(
          _myTurn(engine, ['golem'], classId: 'paladin'), 'p1', const AttackCommand())!;
      final dmg = step.events.whereType<DamageEvent>().single.amount;
      expect(step.events.whereType<StatusAppliedEvent>().single.kind, StatusKind.stun);
      expect(step.state.enemies.single.breakGauge, closeTo(dmg + 15, 1e-9));
    });

    test('la vida perdida carga la ULT enemiga: +1 por cada 1%', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['reyLimo']);
      expect(turn.enemies.single.ult, BattleEngine.enemyUltStart);
      final step = engine.command(turn, 'p1', const AttackCommand())!;
      expect(step.state.enemies.single.ult, closeTo(40 + 15 / 230 * 100, 1e-9));
      // Los comunes no tienen ULT.
      final slime = engine
          .command(_myTurn(engine, ['slime']), 'p1', const AttackCommand())!
          .state
          .enemies
          .single;
      expect(slime.ult, 0);
    });
  });

  group('baja y quiebre', () {
    test('baja 10% del umbral al empezar el turno del enemigo', () {
      final engine = _engine([0.0]);
      final start = engine.start(party: [_member('p1', 'guerrero')], enemyTypes: ['golem']);
      start.state.enemies.single.breakGauge = 30;
      final step = engine.nextTurn(start.state);
      expect(step.state.currentId, 'e0');
      expect(step.state.enemies.single.breakGauge, 25);
      expect(_breaks(step).single.phase, BreakPhase.decay);
    });

    test('quiebre: pierde el turno, +50% de daño 2 turnos del grupo, '
        'después la barra a 0 y el umbral +25%', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['golem']);
      turn.enemies.single.breakGauge = 40;
      var step = engine.command(turn, 'p1', const AttackCommand())!;
      var golem = step.state.enemies.single;
      expect(_breaks(step).single.phase, BreakPhase.broken);
      expect([golem.breakGauge, golem.vulnerable, golem.breakSkip], [50, 2, true]);
      expect(step.state.log, contains('¡QUIEBRE! Gólem: pierde su turno, +50% de daño'));

      // 1.er turno del grupo: +50%.
      var s = engine.nextTurn(step.state).state;
      expect(s.currentId, 'p1');
      step = engine.command(s, 'p1', const AttackCommand())!;
      final hit = step.events.whereType<DamageEvent>().single;
      expect([hit.amount, hit.vulnerable], [23, true]); // 15 × 1.5 = 22.5
      expect(step.state.log, contains('× 1.5 QUIEBRE'));
      expect(step.state.enemies.single.vulnerable, 1);
      // Quebrado, la barra no se llena.
      expect(_breaks(step), isEmpty);

      // Turno del gólem: lo pierde.
      final skip = engine.nextTurn(step.state);
      expect(skip.state.currentId, isNull);
      expect(_breaks(skip).single.phase, BreakPhase.skipped);
      expect(skip.state.log, contains('Gólem está QUEBRADO y pierde su turno'));
      expect(skip.state.enemies.single.breakSkip, isFalse);

      // 2.º turno del grupo: +50% y se recupera al terminar.
      s = engine.nextTurn(skip.state).state;
      expect(s.currentId, 'p1');
      step = engine.command(s, 'p1', const AttackCommand())!;
      expect(step.events.whereType<DamageEvent>().single.amount, 23);
      golem = step.state.enemies.single;
      expect(_breaks(step).single.phase, BreakPhase.recovered);
      expect([golem.vulnerable, golem.breakGauge, golem.breaks], [0, 0, 1]);
      expect(golem.breakMax, 62.5);
      expect(step.state.log, contains('Gólem se recupera del quiebre'));

      // 3.er turno: daño normal.
      s = engine.nextTurn(step.state).state;
      final after = engine.command(s, 'p1', const AttackCommand())!;
      expect(after.events.whereType<DamageEvent>().single.vulnerable, isFalse);
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
      // Guerrero: 13 × 1.2 × (1 − 9%) = 14.2.
      expect(hits.first.amount, 14);
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

    test('Furia Élite: ATQ × 2.0 al objetivo con crítico garantizado', () {
      final engine = _engine([0.0]);
      final turn = _enemyTurn(engine, 'golem', elite: true);
      turn.enemies.single.ultPending = true;
      final step = engine.enemyTurn(turn)!;
      expect((step.events.first as EnemyUltEvent).name, 'Furia Élite');
      final hit = step.events.whereType<DamageEvent>().single;
      expect(hit.critical, isTrue);
      // 16 × 2 × 1.5 × (1 − 9%) = 43.68.
      expect(hit.amount, 44);
    });

    test('Defender reduce a la mitad', () {
      final engine = _engine([0.0]);
      final turn = _enemyTurn(engine, 'golem', elite: true);
      turn.enemies.single.ultPending = true;
      turn.party.single.defending = true;
      final hit = engine.enemyTurn(turn)!.events.whereType<DamageEvent>().single;
      expect(hit.amount, 22); // 43.68 / 2 = 21.84
    });

    test('quebrarlo antes cancela la ULT avisada', () {
      final engine = _engine();
      final turn = _myTurn(engine, ['reyLimo']);
      final boss = turn.enemies.single
        ..ult = 100
        ..ultPending = true
        ..breakGauge = 79;
      expect(boss.breakMax, 80);
      final step = engine.command(turn, 'p1', const AttackCommand())!;
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
        breakSkip: true, ultId: 'eult_diluvio', ultPending: true, ult: 100,
      );
      const json = SessionJson();
      final text = jsonEncode(json.combatantToJson(e));
      final back = json.combatantFromJson(asJson(jsonDecode(text)));
      expect(jsonEncode(json.combatantToJson(back)), text);
      expect([back.breakBase, back.breakGauge, back.breaks, back.vulnerable,
          back.breakSkip, back.ultId, back.ultPending],
          [80, 33.5, 1, 2, true, 'eult_diluvio', true]);
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
