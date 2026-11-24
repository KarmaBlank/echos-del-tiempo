import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/combat_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/battle_log_helper.dart';

const _stats = StatsCalculator(
    classes: kClasses,
    treeRules: PassiveTreeRules(PassiveTreeCatalog(
        nodes: {}, startNodeByClass: {}, exclusions: {})));

BattleEngine _engine() =>
    BattleEngine(stats: _stats, random: () => 0.99, breakEnabled: false);

BattlePartyMember _member(String id, String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: id,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

/// Modos de turno del RPG (docs/specs/turn_modes.md).
void main() {
  final engine = _engine();

  BattleState start(TurnRule rule, {int players = 2}) {
    final s = engine
        .start(
          party: [
            for (var i = 0; i < players; i++)
              _member('p$i', ['guerrero', 'maga', 'guerrero'][i % 3]),
          ],
          enemyTypes: ['slime', 'slime'],
          turnRule: rule,
        )
        .state;
    // Enemigos con mucha vida: la pelea no termina en estas pruebas.
    for (final e in s.enemies) {
      e.hp = e.maxHp = 99999;
    }
    return s;
  }

  /// Una ronda entera: los jugadores defienden, los enemigos actúan. Devuelve
  /// quiénes actuaron, en orden, y el estado al cerrarla.
  (List<String>, BattleState) playRound(BattleState s,
      {BattleCommand cmd = const DefendCommand()}) {
    final order = <String>[];
    final round = s.round;
    for (var i = 0; i < 100; i++) {
      if (s.awaitingGroup) {
        final p = s.pendingGroup.first;
        order.add(p.id);
        s = engine.command(s, p.id, cmd)!.state;
        continue;
      }
      final cur = s.current;
      if (cur != null && !cur.isPlayer) {
        order.add(cur.id);
        s = engine.enemyTurn(s)!.state;
        continue;
      }
      final next = engine.nextTurn(s).state;
      if (next.round != round && round != 0) return (order, s);
      s = next;
    }
    return (order, s);
  }

  group('Por rondas', () {
    test('cada combatiente actúa exactamente una vez por ronda', () {
      var s = start(TurnRule.porRonda);
      // Uno rapidísimo: igual actúa una vez.
      s.party.first.speed = 999;
      s = engine.nextTurn(s).state;
      for (var r = 0; r < 3; r++) {
        final (order, next) = playRound(s);
        expect(order.toSet().length, order.length, reason: 'ronda $r');
        expect(order.toSet(), {'p0', 'p1', 'e0', 'e1'});
        s = engine.nextTurn(next).state;
      }
    });

    test('orden por velocidad; los cambios rigen desde la próxima ronda', () {
      var s = start(TurnRule.porRonda);
      for (final e in s.enemies) {
        e.speed = 1;
      }
      s = engine.nextTurn(s).state;
      expect(s.roundOrder.take(2).toSet(), {'p0', 'p1'});
      expect(s.roundOrder.skip(2), ['e0', 'e1']);
      // e1 se vuelve rapidísimo a mitad de ronda: no cambia esta ronda.
      s.enemies.last.speed = 999;
      expect(s.roundOrder.last, 'e1');
      final (_, end) = playRound(s);
      final next = engine.nextTurn(end).state;
      expect(next.roundOrder.first, 'e1');
    });

    test('bloque: los jugadores seguidos actúan en cualquier orden', () {
      var s = start(TurnRule.porRonda, players: 3);
      for (final e in s.enemies) {
        e.speed = 1;
      }
      s = engine.nextTurn(s).state;
      expect(s.awaitingGroup, isTrue);
      expect({for (final p in s.pendingGroup) p.id}, {'p0', 'p1', 'p2'});
      s = engine.command(s, 'p2', const DefendCommand())!.state;
      s = engine.command(s, 'p0', const DefendCommand())!.state;
      expect(engine.command(s, 'p0', const DefendCommand()), isNull,
          reason: 'cada uno una vez');
      s = engine.command(s, 'p1', const DefendCommand())!.state;
      expect(s.pendingGroup, isEmpty);
      s = engine.nextTurn(s).state;
      expect(s.current!.isPlayer, isFalse);
    });

    test('ESPERAR: pasa al final de la ronda, una vez por ronda', () {
      var s = start(TurnRule.porRonda);
      for (final e in s.enemies) {
        e.speed = 1;
      }
      s = engine.nextTurn(s).state;
      final pulse = s.byId('p0')!.pulse;
      s = engine.command(s, 'p0', const WaitCommand())!.state;
      expect(s.roundOrder.last, 'p0');
      expect([for (final p in s.pendingGroup) p.id], ['p1']);
      s = engine.command(s, 'p1', const DefendCommand())!.state;
      // Enemigos.
      for (var i = 0; i < 2; i++) {
        s = engine.nextTurn(s).state;
        expect(s.current!.isPlayer, isFalse);
        s = engine.enemyTurn(s)!.state;
      }
      s = engine.nextTurn(s).state;
      expect([for (final p in s.pendingGroup) p.id], ['p0']);
      expect(s.byId('p0')!.pulse, pulse, reason: 'no vuelve a arrancar');
      expect(engine.command(s, 'p0', const WaitCommand()), isNull,
          reason: 'ya esperó (y no queda nadie detrás)');
      s = engine.command(s, 'p0', const DefendCommand())!.state;
      s = engine.nextTurn(s).state;
      expect(s.round, 2);
      expect(s.waited, isEmpty);
    });

    test('turno extra: una acción extra dentro del mismo turno', () {
      var s = start(TurnRule.porRonda);
      for (final e in s.enemies) {
        e.speed = 1;
      }
      s = engine.nextTurn(s).state;
      s.byId('p0')!.extraTurn = 1;
      s = engine.command(s, 'p0', const DefendCommand())!.state;
      expect(s.acted, isNot(contains('p0')));
      expect(s.pendingGroup.map((p) => p.id), contains('p0'));
      s = engine.command(s, 'p0', const DefendCommand())!.state;
      expect(s.acted, contains('p0'));
      expect(engine.command(s, 'p0', const DefendCommand()), isNull);
    });

    test('las duraciones cuentan en rondas (una por turno propio)', () {
      var s = start(TurnRule.porRonda);
      s = engine.nextTurn(s).state;
      s.byId('p0')!.effects = [
        const TimedEffect(
            sourceId: 'prueba', stat: BuffStat.attack, value: 0.1, turns: 2),
      ];
      final (_, end) = playRound(s);
      expect(end.byId('p0')!.effects.single.turns, 1);
    });

    test('aturdido: pierde su lugar en esta ronda', () {
      var s = start(TurnRule.porRonda);
      for (final e in s.enemies) {
        e.speed = 1;
      }
      s.party.first.statuses = {StatusKind.stun: 1};
      s = engine.nextTurn(s).state;
      expect(s.acted, contains('p0'));
      expect([for (final p in s.pendingGroup) p.id], ['p1']);
    });

    test('el estado y los comandos viajan por la red', () {
      var s = engine.nextTurn(start(TurnRule.porRonda)).state;
      s = engine.command(s, s.pendingGroup.first.id, const WaitCommand())?.state ??
          s;
      final j = jsonDecode(jsonEncode(const SessionJson().battleStateToJson(s)));
      final back = const SessionJson().battleStateFromJson(asJson(j));
      expect(back.turnRule, TurnRule.porRonda);
      expect(back.roundOrder, s.roundOrder);
      expect(back.waited, s.waited);
      for (final c in [const WaitCommand(), const EndTurnCommand()]) {
        final w = ActionJson.toJson(BattleAction(c));
        final a = ActionJson.fromJson(asJson(jsonDecode(jsonEncode(w))));
        expect((a as BattleAction).command.runtimeType, c.runtimeType);
      }
    });
  });

  group('Por fases', () {
    test('fase enemiga primero y después fase de jugadores', () {
      var s = start(TurnRule.porFases);
      s = engine.nextTurn(s).state;
      expect(s.groupPhase, isFalse);
      expect(s.current!.id, 'e0');
      s = engine.enemyTurn(s)!.state;
      s = engine.nextTurn(s).state;
      expect(s.current!.id, 'e1');
      s = engine.enemyTurn(s)!.state;
      s = engine.nextTurn(s).state;
      expect(s.groupPhase, isTrue);
      expect(s.awaitingGroup, isTrue);
      expect(s.log, startsWith('Fase de jugadores'));
    });

    test('los efectos del grupo no cuentan en la fase enemiga', () {
      var s = start(TurnRule.porFases);
      s.party.first.effects = [
        const TimedEffect(
            sourceId: 'prueba', stat: BuffStat.attack, value: 0.1, turns: 2),
      ];
      final ult = s.party.first.ult;
      s = engine.nextTurn(s).state;
      s = engine.enemyTurn(s)!.state;
      s = engine.nextTurn(s).state;
      s = engine.enemyTurn(s)!.state;
      expect(s.byId('p0')!.effects.single.turns, 2);
      // El daño recibido carga ULT como siempre; nada carga por tiempo.
      expect(s.byId('p0')!.ult, greaterThanOrEqualTo(ult));
    });

    test('TERMINAR TURNO con 3 jugadores: la fase termina con todos', () {
      var s = start(TurnRule.porFases, players: 3);
      for (var i = 0; i < 3 && !s.awaitingGroup; i++) {
        s = engine.nextTurn(s).state;
        if (s.current != null) s = engine.enemyTurn(s)!.state;
      }
      s = engine.nextTurn(s).state;
      expect(s.awaitingGroup, isTrue);
      final pulse = s.byId('p1')!.pulse;
      s = engine.command(s, 'p1', const EndTurnCommand())!.state;
      expect(s.byId('p1')!.pulse, pulse, reason: 'sin Pulso de acción');
      expect(engine.command(s, 'p1', const EndTurnCommand()), isNull);
      s = engine.command(s, 'p2', const AttackCommand())!.state;
      expect(s.awaitingGroup, isTrue);
      s = engine.command(s, 'p0', const EndTurnCommand())!.state;
      expect(s.pendingGroup, isEmpty);
      s = engine.nextTurn(s).state;
      expect(s.round, 2);
      expect(s.groupPhase, isFalse);
      expect(s.current!.isPlayer, isFalse);
    });

    test('ESPERAR no existe en Por fases', () {
      var s = start(TurnRule.porFases);
      for (var i = 0; i < 5 && !s.awaitingGroup; i++) {
        s = engine.nextTurn(s).state;
        if (s.current != null) s = engine.enemyTurn(s)!.state;
      }
      expect(s.awaitingGroup, isTrue);
      expect(engine.command(s, 'p0', const WaitCommand()), isNull);
    });
  });

  test('línea de tiempo: TERMINAR TURNO es Pasar; ESPERAR no vale', () {
    var s = engine.nextTurn(start(TurnRule.velocidad)).state;
    final id = s.currentId!;
    if (s.current!.isPlayer) {
      expect(engine.command(s, id, const WaitCommand()), isNull);
      expect(engine.command(s, id, const EndTurnCommand()), isNotNull);
    }
  });

  test('modo por defecto: rondas en cooperativo, línea de tiempo solo', () {
    expect(CombatMode.defaultFor(coop: true), CombatMode.phases);
    expect(CombatMode.defaultFor(coop: false), CombatMode.phases);
    for (final m in CombatMode.values) {
      expect(CombatMode.fromName(m.name), m);
      expect(m.tip, isNotEmpty);
    }
  });
}
