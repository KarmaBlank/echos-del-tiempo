import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/battle_log_helper.dart';

// Límites de combate (docs/specs/combat.md § "Límites"): efectos
// encadenados, tope por golpe, aguanta una ronda, velocidad y carga de
// ULT extra.

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine({int seed = 1}) => BattleEngine(
    stats: _stats, random: mulberry32(seed), familiesEnabled: false);

/// Sin azar: nunca crítico ni probabilidad.
BattleEngine _plain() =>
    BattleEngine(stats: _stats, random: () => 0.99, familiesEnabled: false);

Combatant _hero({
  String id = 'p1',
  int attack = 20,
  double speed = 10,
  Set<String> mech = const {},
  Set<String> keys = const {},
  List<String> skills = const [],
  double ultBonus = 0,
  double nextTurn = 0,
  double crit = 0,
}) =>
    Combatant(
      id: id,
      name: id,
      isPlayer: true,
      pulse: BattleEngine.pulseMax,
      hp: 100,
      maxHp: 100,
      speed: speed,
      attack: attack,
      magic: 20,
      critChance: crit,
      mp: 50,
      maxMp: 50,
      mechanics: {...mech},
      keystones: {...keys},
      skillIds: skills,
      classId: 'guerrero',
      weaponType: 'espada',
      ultChargeBonus: ultBonus,
      nextTurn: nextTurn,
    );

Combatant _foe(String id,
        {int hp = 100,
        bool boss = false,
        bool elite = false,
        double speed = 5,
        double nextTurn = 50}) =>
    Combatant(
      id: id,
      name: id,
      isPlayer: false,
      hp: hp,
      maxHp: 100,
      speed: speed,
      attack: 10,
      critChance: 0,
      enemyType: 'slime',
      boss: boss,
      elite: elite,
      nextTurn: nextTurn,
    );

void _tune(Map<String, num> values) {
  final d = kTuningDefaults[TuningId.combatLimits]!;
  kTuning[TuningId.combatLimits] =
      TuningDef(d.name, {...d.values, ...values});
}

void main() {
  tearDown(() =>
      kTuning[TuningId.combatLimits] = kTuningDefaults[TuningId.combatLimits]!);

  group('efectos encadenados', () {
    /// Peor caso: todas las mecánicas y keystones de cadena, dos héroes,
    /// cuatro enemigos. Devuelve el máximo de efectos en un paso.
    int worst({int seed = 7}) {
      final e = _engine(seed: seed);
      final all = kMechanics.keys.toSet();
      const keys = {'danza', 'almaHielo', 'cadena', 'egida'};
      const skills = ['bola', 'chispa', 'rafaga', 'cura', 'venenosa'];
      var s = BattleState(party: [
        _hero(mech: all, keys: keys, skills: skills, crit: 0.4),
        _hero(
            id: 'p2',
            mech: all,
            keys: keys,
            skills: skills,
            crit: 0.4,
            nextTurn: 3),
      ], enemies: [
        for (var i = 0; i < 4; i++)
          _foe('e$i', nextTurn: 2.0 + i)
            ..hp = 1500
            ..maxHp = 1500,
      ]);
      var most = 0;
      for (var i = 0; i < 1500 && !s.ended; i++) {
        final cur = s.current;
        BattleStep step;
        if (cur == null) {
          step = e.nextTurn(s);
        } else if (!cur.isPlayer) {
          step = e.enemyTurn(s)!;
        } else {
          final pick = i % (skills.length + 1);
          final cmd = pick < skills.length
              ? SkillCommand(skills[pick], targetId: 'e${i % 4}')
              : AttackCommand(targetId: 'e${i % 4}');
          step = e.command(s, cur.id, cmd) ??
              e.command(s, cur.id, const AttackCommand())!;
        }
        final n = step.events.whereType<ProcEvent>().length;
        if (n > most) most = n;
        s = step.state;
      }
      return most;
    }

    test('el peor caso no pasa del tope por acción', () {
      for (final seed in [1, 2, 3]) {
        expect(worst(seed: seed),
            lessThanOrEqualTo(BattleEngine.maxProcsPerStep));
      }
    });

    test('el tope es editable y se respeta', () {
      _tune({'procMax': 5});
      expect(BattleEngine.maxProcsPerStep, 5);
      expect(worst(), lessThanOrEqualTo(5));
    });

    test('profundidad 1: ningún efecto dispara otro', () {
      final free = worst();
      _tune({'procDepth': 1});
      expect(worst(), lessThanOrEqualTo(free));
    });
  });

  group('tope por golpe', () {
    BattleState fight(Combatant foe, {List<Combatant>? party}) =>
        BattleState(
            party: party ?? [_hero(attack: 9999)],
            enemies: [foe],
            currentId: 'p1');

    test('jefe: un golpe saca como máximo el 35%', () {
      final s = _plain()
          .command(fight(_foe('e0', boss: true)), 'p1',
              const AttackCommand(targetId: 'e0'))!
          .state;
      expect(s.enemies.single.hp, greaterThanOrEqualTo(65));
      expect(s.enemies.single.alive, isTrue);
    });

    test('élite: como máximo el 60%', () {
      final s = _plain()
          .command(fight(_foe('e0', elite: true)), 'p1',
              const AttackCommand(targetId: 'e0'))!
          .state;
      expect(s.enemies.single.hp, greaterThanOrEqualTo(40));
    });

    // El tope de combo_balance.md § 3.2 (60% del común sin debilidad)
    // sigue aparte: el común arranca con 30 de vida.
    test('común en solitario: sin tope, muere de un golpe', () {
      final s = _plain()
          .command(fight(_foe('e0', hp: 30)), 'p1', const AttackCommand(targetId: 'e0'))!
          .state;
      expect(s.enemies.single.alive, isFalse);
    });
  });

  group('aguanta una ronda', () {
    BattleState coop({Set<String>? acted}) => BattleState(
        party: [_hero(attack: 9999), _hero(id: 'p2', nextTurn: 50)],
        enemies: [_foe('e0', hp: 30), _foe('e1', hp: 30)],
        currentId: 'p1',
        acted: acted);

    test('cooperativo: el primer golpe letal lo deja en 1', () {
      final s = _plain()
          .command(coop(), 'p1', const AttackCommand(targetId: 'e0'))!
          .state;
      expect(s.enemies.first.hp, 1);
      expect(s.log, contains('aguanta'));
    });

    test('el segundo golpe letal de la ronda sí lo mata', () {
      final a = _plain()
          .command(coop(), 'p1', const AttackCommand(targetId: 'e0'))!
          .state
        ..currentId = 'p1';
      final b = _plain()
          .command(a, 'p1', const AttackCommand(targetId: 'e0'))!
          .state;
      expect(b.enemies.first.alive, isFalse);
    });

    test('si el resto ya actuó, muere', () {
      final s = _plain()
          .command(coop(acted: {'p2'}), 'p1',
              const AttackCommand(targetId: 'e0'))!
          .state;
      expect(s.enemies.first.alive, isFalse);
    });

    test('apagado en Balance: muere', () {
      _tune({'holdCoop': 0});
      final s = _plain()
          .command(coop(), 'p1', const AttackCommand(targetId: 'e0'))!
          .state;
      expect(s.enemies.first.alive, isFalse);
    });

    test('la ronda cierra cuando actuaron todos los vivos', () {
      final s = _plain()
          .command(coop(acted: {'p2'}), 'p1',
              const AttackCommand(targetId: 'e1'))!
          .state;
      expect(s.round, 1);
      expect(s.acted, isEmpty);
    });
  });

  group('velocidad', () {
    test('rendimiento decreciente sobre el umbral', () {
      final e = _plain();
      expect(e.interval(_hero(speed: 10)), closeTo(10, 1e-9));
      // 26 → 16 + 10 × 0.5 = 21.
      expect(e.interval(_hero(speed: 26)), closeTo(100 / 21, 1e-9));
    });

    test('nadie tiene más de 2 turnos por turno del aliado más lento', () {
      final e = _plain();
      var s = BattleState(party: [
        _hero(speed: 60, nextTurn: 0),
        _hero(id: 'p2', speed: 4, nextTurn: 0.5),
      ], enemies: [
        _foe('e0', speed: 1, nextTurn: 9999)..hp = 100000
          ..maxHp = 100000,
      ]);
      final order = <String>[];
      for (var i = 0; i < 80 && !s.ended; i++) {
        final cur = s.current;
        if (cur == null) {
          s = e.nextTurn(s).state;
          continue;
        }
        if (!cur.isPlayer) {
          s = e.enemyTurn(s)!.state;
          continue;
        }
        order.add(cur.id);
        s = e.command(s, cur.id, const DefendCommand())!.state;
      }
      // Entre dos turnos del lento, el rápido actúa como mucho 2 veces
      // (Defender adelanta un poco el turno: × 0.7, tolera 3).
      var run = 0;
      var seenSlow = false;
      for (final id in order) {
        if (id == 'p2') {
          seenSlow = true;
          run = 0;
        } else if (seenSlow) {
          run++;
          expect(run, lessThanOrEqualTo(3));
        }
      }
      expect(order.where((id) => id == 'p2').length, greaterThan(2));
    });

    test('tope por el aliado más lento', () {
      final e = _plain();
      final s = BattleState(party: [
        _hero(speed: 60),
        _hero(id: 'p2', speed: 4),
      ], enemies: [_foe('e0')]);
      expect(e.cappedInterval(s, s.party.first), closeTo(25 / 2, 1e-9));
      _tune({'turnsPerSlowest': 0});
      expect(e.cappedInterval(s, s.party.first),
          closeTo(e.interval(s.party.first), 1e-9));
    });
  });

  group('carga de ULT extra', () {
    test('tope por acción y por turno', () {
      final e = _plain();
      final s0 = BattleState(party: [
        _hero(ultBonus: 20),
        _hero(id: 'p2', nextTurn: 50),
      ], enemies: [_foe('e0', hp: 100000)..maxHp = 100000], currentId: 'p1');
      final a = e.command(s0, 'p1', const AttackCommand(targetId: 'e0'))!.state;
      final p = a.party.first;
      expect(p.ultBonusTurn, lessThanOrEqualTo(BattleEngine.ultBonusPerAction));
      expect(p.ultBonusTurn, greaterThan(0));
      // Otra acción en el mismo turno (Instante, turno extra): no pasa
      // del tope por turno.
      a.currentId = 'p1';
      final b = e.command(a, 'p1', const AttackCommand(targetId: 'e0'))!.state;
      expect(b.party.first.ultBonusTurn,
          lessThanOrEqualTo(BattleEngine.ultBonusPerTurn));
      // Sin bonus, la carga de ATACAR sola tampoco llega lejos.
      expect(b.party.first.ult, lessThanOrEqualTo(50 + 2 * 22 + 1e-9));
    });

    test('se reinicia al empezar su turno', () {
      final e = _plain();
      final s = BattleState(party: [
        _hero(nextTurn: 0)..ultBonusTurn = 50,
      ], enemies: [_foe('e0', nextTurn: 99)]);
      final t = e.nextTurn(s).state;
      expect(t.party.first.ultBonusTurn, 0);
    });
  });
}
