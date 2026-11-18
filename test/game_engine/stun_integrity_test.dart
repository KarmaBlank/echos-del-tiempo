import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// "Un enemigo aturdido igual me atacó" (v0.5.1): el log nunca dice que
// alguien quedó aturdido si el estado no entró, y un aturdido nunca
// actúa (docs/specs/combat.md § "Aturdido").

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

/// Azar con valores fijos; cuando se acaban, 0.99 (nunca crítico ni
/// probabilidad).
BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  return BattleEngine(
      stats: _stats, random: () => i < rolls.length ? rolls[i++] : 0.99);
}

Combatant _hero({List<String> skills = const [], double stun = 0}) =>
    Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      hp: 9999,
      maxHp: 9999,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: skills,
      classId: 'paladin',
      weaponType: 'espada+escudo',
      stunOnAttackChance: stun,
      nextTurn: 999,
    );

Combatant _foe(String id,
        {String type = 'slime',
        bool boss = false,
        int hp = 500,
        int maxHp = 500,
        double nextTurn = 50,
        Map<StatusKind, int>? st}) =>
    Combatant(
      id: id,
      name: 'Enemigo $id',
      isPlayer: false,
      hp: hp,
      maxHp: maxHp,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: type,
      boss: boss,
      statuses: st,
      nextTurn: nextTurn,
    );

BattleState _battle(List<Combatant> enemies, {Combatant? hero}) =>
    BattleState(
        party: [hero ?? _hero()], enemies: enemies, currentId: 'p1');

/// Le toca al enemigo: el grupo espera.
BattleState _foesFirst(BattleState s) {
  final c = s.copy();
  for (final p in c.party) {
    p.nextTurn = 9999;
  }
  return c;
}

int _stunEvents(BattleStep s, String id) => s.events
    .whereType<StatusAppliedEvent>()
    .where((e) => e.targetId == id && e.kind == StatusKind.stun)
    .length;

void main() {
  group('el log no miente', () {
    test('Golpe de Escudo (30%) que falla: no dice "Aturdido" y el enemigo actúa',
        () {
      final e = _engine(); // 0.99: la tirada del 30% falla
      final st = e.command(
          _battle([_foe('e0')], hero: _hero(skills: ['golpeEscudo'])),
          'p1',
          const SkillCommand('golpeEscudo', targetId: 'e0'))!;
      expect(st.state.enemies[0].stacks(StatusKind.stun), 0);
      expect(_stunEvents(st, 'e0'), 0);
      expect(st.state.log, isNot(contains('1 Aturdido')));
      expect(st.state.log, contains('Aturdido: falla (30%)'));

      // Su turno: no está aturdido, actúa (y eso es correcto).
      final next = e.nextTurn(_foesFirst(st.state));
      expect(next.events.whereType<TurnSkippedEvent>(), isEmpty);
      expect(next.state.currentId, 'e0');
    });

    test('Golpe de Escudo (30%) que entra: lo dice y el enemigo pierde el turno',
        () {
      final e = _engine([0.99, 0.0]); // crítico no; aturdir sí
      final st = e.command(
          _battle([_foe('e0')], hero: _hero(skills: ['golpeEscudo'])),
          'p1',
          const SkillCommand('golpeEscudo', targetId: 'e0'))!;
      expect(st.state.enemies[0].stacks(StatusKind.stun), 1);
      expect(_stunEvents(st, 'e0'), 1);
      expect(st.state.log, contains('+1 Aturdido (30%)'));

      final next = e.nextTurn(_foesFirst(st.state));
      expect(next.events.whereType<TurnSkippedEvent>().single.cause,
          StatusKind.stun);
      expect(next.state.currentId, isNull);
      expect(e.enemyTurn(next.state), isNull);
    });

    test('Temblor (15%, a todos): cuenta a cuántos aturdió', () {
      // Por enemigo: crítico, aturdir.
      final e = _engine([0.99, 0.0, 0.99, 0.99, 0.99, 0.99]);
      final st = e.command(
          _battle([_foe('e0'), _foe('e1'), _foe('e2')],
              hero: _hero(skills: ['temblor'])),
          'p1',
          const SkillCommand('temblor'))!;
      expect([for (final f in st.state.enemies) f.stacks(StatusKind.stun)],
          [1, 0, 0]);
      expect(st.state.log, contains('Aturdido a 1 de 3 (15%)'));
      expect(st.state.log, isNot(contains('15% 1 Aturdido')));
    });

    test('Paladín (aturdir al atacar) contra un jefe inmune: no dice "¡aturde!"',
        () {
      final e = _engine([0.99, 0.0]); // crítico no; 3% de aturdir sí
      final st = e.command(
          _battle([
            _foe('e0', type: 'espectroCoronado', boss: true),
            _foe('e1', type: 'siervoEspectral'),
          ], hero: _hero(stun: 0.03)),
          'p1',
          const AttackCommand(targetId: 'e0'))!;
      expect(st.state.enemies[0].stacks(StatusKind.stun), 0);
      expect(_stunEvents(st, 'e0'), 0);
      expect(st.state.log, contains('INMUNE'));
      expect(st.state.log, isNot(contains('aturde')));
    });

    test('Paladín (aturdir al atacar) que entra: "¡aturde!" y pierde el turno',
        () {
      final e = _engine([0.99, 0.0]);
      final st = e.command(_battle([_foe('e0')], hero: _hero(stun: 0.03)),
          'p1', const AttackCommand(targetId: 'e0'))!;
      expect(st.state.enemies[0].stacks(StatusKind.stun), 1);
      expect(st.state.log, contains('¡aturde!'));
      expect(e.nextTurn(_foesFirst(st.state)).events.whereType<TurnSkippedEvent>(),
          hasLength(1));
    });
  });

  group('un aturdido no actúa', () {
    test('Devorador aturdido que se transforma por Veneno al empezar su turno '
        'igual pierde ese turno', () {
      final e = _engine();
      // A 1 HP del umbral del 50%: el Veneno lo cruza en su statusTick.
      final boss = _foe('e0',
          type: 'devorador',
          boss: true,
          hp: 251,
          maxHp: 500,
          nextTurn: 0,
          st: {StatusKind.stun: 1, StatusKind.poison: 5});
      final s = _battle([boss])..currentId = null;
      final st = e.nextTurn(s);
      final b = st.state.enemies[0];
      expect(b.phase, 2, reason: 'se transformó');
      expect(b.stacks(StatusKind.stun), 0, reason: 'la fase 2 limpia estados');
      expect(st.events.whereType<TurnSkippedEvent>().single.cause,
          StatusKind.stun);
      expect(st.state.currentId, isNull);
      expect(st.state.log, contains('ATURDIDO'));
      expect(e.enemyTurn(st.state), isNull);
      // El siguiente turno ya es normal.
      final again = e.nextTurn(st.state.copy()
        ..party[0].nextTurn = 9999
        ..enemies[0].nextTurn = 0);
      expect(again.events.whereType<TurnSkippedEvent>(), isEmpty);
      expect(again.state.currentId, 'e0');
    });

    test('un común aturdido pierde el turno y no llega a actuar', () {
      final e = _engine();
      final s = _battle([
        _foe('e0', nextTurn: 0, st: {StatusKind.stun: 1})
      ])
        ..currentId = null;
      final st = e.nextTurn(s);
      expect(st.events.whereType<TurnSkippedEvent>(), hasLength(1));
      expect(st.state.enemies[0].stacks(StatusKind.stun), 0);
      expect(e.enemyTurn(st.state), isNull);
    });
  });
}
