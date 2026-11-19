import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
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
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Escenarios determinísticos de cada notable / keystone v2
// (docs/specs/passive_tree_v2.md § 3-5). Los combatientes se arman a
// mano para controlar cada número; el azar es una lista fija (0.99 cuando
// se acaba: nunca crítico ni probabilidad).

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  // Sin familias (el Limo es débil al fuego): los números de las
  // mecánicas solas (bestiary.md § 1 tiene sus tests).
  return BattleEngine(
      stats: _stats,
      random: () => i < rolls.length ? rolls[i++] : 0.99,
      familiesEnabled: false);
}

Combatant _hero({
  String id = 'p1',
  String name = 'Ana',
  Set<String> mech = const {},
  Set<String> keys = const {},
  int attack = 20,
  int magic = 20,
  double crit = 0,
  int hp = 100,
  List<String> skills = const [],
  double stun = 0,
  double nextTurn = 0,
}) =>
    Combatant(
      id: id,
      name: name,
      isPlayer: true,
      // Pulso lleno: las pruebas de mecánicas no miden el Pulso.
      pulse: BattleEngine.pulseMax,
      hp: hp,
      maxHp: 100,
      speed: 10,
      attack: attack,
      magic: magic,
      critChance: crit,
      mp: 50,
      maxMp: 50,
      mechanics: {...mech},
      keystones: {...keys},
      skillIds: skills,
      classId: 'guerrero',
      weaponType: 'espada',
      stunOnAttackChance: stun,
      nextTurn: nextTurn,
    );

Combatant _foe(String id, String name,
        {int hp = 100,
        int attack = 10,
        bool boss = false,
        double nextTurn = 50,
        Map<StatusKind, int>? st}) =>
    Combatant(
      id: id,
      name: name,
      isPlayer: false,
      hp: hp,
      maxHp: 100,
      speed: 5,
      attack: attack,
      critChance: 0,
      enemyType: 'slime',
      boss: boss,
      statuses: st,
      nextTurn: nextTurn,
    );

List<Combatant> _foes({List<int> hp = const [100, 100, 100]}) => [
      for (var i = 0; i < hp.length; i++)
        _foe('e$i', ['Limo A', 'Limo B', 'Limo C', 'Limo D'][i], hp: hp[i]),
    ];

BattleState _battle(List<Combatant> party, List<Combatant> enemies,
        {String? current = 'p1'}) =>
    BattleState(party: party, enemies: enemies, currentId: current);

BattleStep _cmd(BattleEngine e, BattleState s, BattleCommand c,
        [String who = 'p1']) =>
    e.command(s, who, c)!;

Iterable<ProcEvent> _procs(BattleStep s, String id) =>
    s.events.whereType<ProcEvent>().where((p) => p.sourceId == id);

void main() {
  group('Filo', () {
    test('Frenesí: crítico → +20% velocidad 2 turnos, no acumula', () {
      final e = _engine([0.0]);
      var s = _battle([
        _hero(mech: {'frenesi'}, crit: 0.5)
      ], _foes(hp: [500, 500]));
      final st = _cmd(e, s, const AttackCommand(targetId: 'e0'));
      expect(_procs(st, 'frenesi'), hasLength(1));
      final buff = st.events.whereType<BuffAppliedEvent>().single;
      expect([buff.targetId, buff.stat, buff.value, buff.turns],
          ['p1', BuffStat.speed, 0.2, 2]);
      expect(st.state.log, contains('Frenesí: +20% velocidad (2 turnos)'));
      var p = st.state.party.single;
      expect(p.nextTurn, closeTo(100 / 12, 1e-9));
      expect(p.effects.single.turns, 2);

      // Dos esperas aceleradas más (turnos 2 y 3 sin crítico) y se va.
      s = st.state;
      final waits = <double>[];
      for (var i = 0; i < 2; i++) {
        s = e.nextTurn(s).state;
        expect(s.currentId, 'p1');
        final before = s.party.single.nextTurn;
        s = _cmd(e, s, const AttackCommand(targetId: 'e0')).state;
        waits.add(s.party.single.nextTurn - before);
      }
      p = s.party.single;
      expect(waits[0], closeTo(100 / 12, 1e-9));
      expect(waits[1], closeTo(10, 1e-9));
      expect(p.effects, isEmpty);
    });

    test('Corte en Cadena: solo con crítico, 50% a otro enemigo', () {
      final crit = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'corteCadena'}, crit: 1)
          ], _foes()),
          const AttackCommand(targetId: 'e0'));
      expect(crit.state.enemies.map((e) => e.hp), [70, 85, 100]);
      final bounce = crit.events.whereType<DamageEvent>().last;
      expect([bounce.targetId, bounce.amount, bounce.sourceId],
          ['e1', 15, 'corteCadena']);
      final plain = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'corteCadena'})
          ], _foes()),
          const AttackCommand(targetId: 'e0'));
      expect(plain.state.enemies.map((e) => e.hp), [80, 100, 100]);
    });

    test('Danza de Cuchillas: turno extra inmediato, no encadena, tope 40%',
        () {
      final e = _engine([0.3, 0.3]);
      var s = _battle([
        _hero(mech: {'danza'}, keys: {'danza'}, crit: 1)
      ], _foes(hp: [500, 500]));
      final first = _cmd(e, s, const AttackCommand(targetId: 'e0'));
      expect(first.state.party.single.nextTurn, 0);
      expect(first.state.party.single.extraTurn, 1);
      expect(first.state.log, contains('Danza de Cuchillas: ¡turno extra!'));
      s = e.nextTurn(first.state).state;
      expect(s.currentId, 'p1');
      expect(s.party.single.extraTurn, 2);
      final second = _cmd(e, s, const AttackCommand(targetId: 'e0'));
      expect(second.events.whereType<DamageEvent>().first.critical, isTrue);
      expect(_procs(second, 'danza'), isEmpty);
      expect(second.state.party.single.nextTurn, 10);

      // Crítico 100% → 40%: una tirada de 0.5 ya no es crítico.
      final capped = _cmd(
          _engine([0.5]),
          _battle([
            _hero(mech: {'danza'}, keys: {'danza'}, crit: 1)
          ], _foes()),
          const AttackCommand(targetId: 'e0'));
      expect(capped.events.whereType<DamageEvent>().first.critical, isFalse);
    });

    test('Danza de Cuchillas en los stats: crítico máximo 40%', () {
      final cls = kClasses['tirador']!;
      final attrs = Map.of(cls.baseAttributes)..[Attribute.des] = 60;
      PlayerBuild build(List<String> tree) => PlayerBuild(
            classId: 'guerrero',
            level: 60,
            attributes: PlayerAttributes(attrs),
            equippedWeapon: kWeapons['espada_bronce']!,
            passiveProgress: PlayerPassiveProgress(tree),
          );
      const filo = [
        'gue_r1', 'gue_f4', 'gue_f5', 'filo_n1', 'filo_m1', 'filo_m2', //
        'filo_na', 'filo_nb', 'filo_ma', 'filo_mb', 'filo_nc',
      ];
      expect(_stats.calculate(build(filo)).critChance, greaterThan(0.4));
      final d = _stats.calculate(build([...filo, 'filo_k']));
      expect(d.critChance, 0.40);
      expect(d.mechanics,
          {'estocadaPrecisa', 'frenesi', 'corteCadena', 'desarme', 'danza'});
    });
  });

  group('Sangre', () {
    test('Último Aliento: < 30% vida → +25% ATQ y +10% crítico', () {
      final low = _cmd(
          _engine([0.05]),
          _battle([
            _hero(mech: {'ultimoAliento'}, hp: 20)
          ], _foes()),
          const AttackCommand(targetId: 'e0'));
      expect(low.state.enemies.first.hp, 100 - 38); // 25 × 1.5
      expect(low.state.log, contains('ATQ 25 (20 +25%)'));
      expect(low.state.log, contains('CRÍTICO'));
      final ok = _cmd(
          _engine([0.05]),
          _battle([
            _hero(mech: {'ultimoAliento'}, hp: 50)
          ], _foes()),
          const AttackCommand(targetId: 'e0'));
      expect(ok.state.enemies.first.hp, 80);
    });

    test('Sed de Sangre: al matar, turno 50% antes y +10% vida (1 vez)', () {
      final one = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'sedSangre'}, hp: 50)
          ], _foes(hp: [10, 100])),
          const AttackCommand(targetId: 'e0'));
      final p = one.state.party.single;
      expect(p.nextTurn, 5);
      expect(p.hp, 60);
      expect(one.state.log,
          contains('Sed de Sangre: tu próximo turno llega 50% antes'));

      final two = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'sedSangre'}, hp: 50, skills: ['giro'])
          ], _foes(hp: [10, 10, 100])),
          const SkillCommand('giro', targetId: 'e0'));
      expect(two.state.enemies.where((e) => !e.alive), hasLength(2));
      expect(two.state.party.single.hp, 60, reason: 'una sola vez por acción');
      expect(_procs(two, 'sedSangre'), hasLength(2),
          reason: 'un ProcEvent por efecto (turno + cura)');
    });
  });

  group('Muralla', () {
    test('Contraataque (defendiendo) y Represalia (+30% ATQ 1 turno)', () {
      final e = _engine();
      final hero = _hero(mech: {'contraataque', 'represalia'})
        ..defending = true
        ..nextTurn = 10;
      final foe = _foe('e0', 'Limo A', nextTurn: 0);
      var step = e.enemyTurn(_battle([hero], [foe], current: 'e0'))!;
      expect(step.state.party.single.hp, 95); // 10 × ½
      expect(step.state.enemies.single.hp, 97); // round(5 × 0.5)
      final reflect = step.events
          .whereType<DamageEvent>()
          .firstWhere((d) => d.sourceId == 'contraataque');
      expect(reflect.amount, 3);
      expect(step.state.log, contains('Contraataque: 3 a Limo A'));
      expect(step.state.log, contains('Represalia: +30% ATQ (1 turno)'));

      var s = e.nextTurn(step.state).state;
      expect(s.currentId, 'p1');
      step = _cmd(e, s, const AttackCommand(targetId: 'e0'));
      expect(step.state.enemies.single.hp, 97 - 26);
      expect(step.state.log, contains('ATQ 26 (20 +30%)'));
      expect(step.state.party.single.effects, isEmpty);

      // Sin defender: no hay reflejo.
      final open = e.enemyTurn(_battle([
        _hero(mech: {'contraataque'}, nextTurn: 10)
      ], [
        _foe('e0', 'Limo A', nextTurn: 0)
      ], current: 'e0'))!;
      expect(open.state.enemies.single.hp, 100);
    });
  });

  group('Brasa', () {
    test('Combustión: explota si ya tenía 3+ Quemadura, 1 por acción', () {
      List<Combatant> burning(int n) => [
            for (final (i, name) in ['Limo A', 'Limo B', 'Limo C'].indexed)
              _foe('e$i', name, st: {StatusKind.burn: n}),
          ];
      final hit = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'combustion'}, skills: ['bola'])
          ], burning(3)),
          const SkillCommand('bola', targetId: 'e0'));
      expect(hit.state.enemies.map((e) => e.hp), [64, 82, 82]);
      expect(hit.state.log, contains('Combustión: Limo A explota'));
      final cold = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'combustion'}, skills: ['bola'])
          ], burning(2)),
          const SkillCommand('bola', targetId: 'e0'));
      expect(cold.state.enemies.map((e) => e.hp), [64, 100, 100]);

      final area = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'combustion'}, skills: ['llamarada'])
          ], burning(3)),
          const SkillCommand('llamarada'));
      expect(_procs(area, 'combustion'), hasLength(1));
      // Área × 0.6 (combo_balance.md § 4).
      expect(area.state.enemies.map((e) => e.hp), [86, 79, 79]);
    });

    test('Choque Térmico: quemar a un congelado lo aturde', () {
      final s = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'choqueTermico'}, skills: ['bola'])
          ], [
            _foe('e0', 'Limo A', st: {StatusKind.freeze: 2})
          ]),
          const SkillCommand('bola', targetId: 'e0'));
      final foe = s.state.enemies.single;
      expect(foe.stacks(StatusKind.freeze), 0);
      expect(foe.stacks(StatusKind.stun), 1);
      expect(s.state.log, contains('Choque Térmico'));
    });
  });

  group('Escarcha', () {
    test('Tiempo Gélido: congelar retrasa 20% de su espera', () {
      final s = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'tiempoGelido'}, skills: ['lanzaH'])
          ], [
            _foe('e0', 'Limo A')
          ]),
          const SkillCommand('lanzaH', targetId: 'e0'));
      final foe = s.state.enemies.single;
      // v0.7: −6% de velocidad por stack de Congelación.
      expect(foe.nextTurn, closeTo(50 + 100 / (5 * (1 - 0.12)) * 0.2, 1e-9));
      expect(s.events.whereType<DelayedEvent>(), hasLength(1));
    });

    test('Fractura: +25% a enemigos con Congelación', () {
      final s = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'fractura'})
          ], [
            _foe('e0', 'Limo A', st: {StatusKind.freeze: 1})
          ]),
          const AttackCommand(targetId: 'e0'));
      expect(s.state.enemies.single.hp, 75);
      expect(s.state.log, contains('× 1.25 Fractura'));
    });

    test('Alma de Hielo: la Congelación enemiga no se derrite y no quema', () {
      BattleState frozen(Set<String> keys) => _battle([
            _hero(keys: keys, mech: keys, nextTurn: 100, skills: ['bola']),
          ], [
            _foe('e0', 'Limo A', nextTurn: 1, st: {StatusKind.freeze: 2}),
          ], current: null);
      expect(
          _engine()
              .nextTurn(frozen({'almaHielo'}))
              .state
              .enemies
              .single
              .stacks(StatusKind.freeze),
          2);
      expect(
          _engine()
              .nextTurn(frozen({}))
              .state
              .enemies
              .single
              .stacks(StatusKind.freeze),
          1);

      final burn = _cmd(
          _engine(),
          _battle([
            _hero(keys: {'almaHielo'}, mech: {'almaHielo'}, skills: ['bola']),
          ], [
            _foe('e0', 'Limo A'),
          ]),
          const SkillCommand('bola', targetId: 'e0'));
      expect(burn.state.enemies.single.stacks(StatusKind.burn), 0);
      expect(burn.events.whereType<StatusAppliedEvent>(), isEmpty);
      expect(burn.state.log, contains('sin Quemadura (Alma de Hielo)'));
    });
  });

  group('Arcano', () {
    test('Arco Voltaico: habilidad mágica a uno rebota al 50%', () {
      final s = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'arcoVoltaico'}, skills: ['chispa', 'certero'])
          ], _foes()),
          const SkillCommand('chispa', targetId: 'e0'));
      expect(s.state.enemies.map((e) => e.hp), [68, 84, 100]);
      final phys = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'arcoVoltaico'}, skills: ['certero'])
          ], _foes()),
          const SkillCommand('certero', targetId: 'e0'));
      expect(phys.state.enemies.map((e) => e.hp), [68, 100, 100]);
    });

    test('Eco Arcano: 20% de repetir al 50% (sin crítico) con su estado', () {
      BattleStep cast(double roll) => _cmd(
          _engine([0.99, roll]),
          _battle([
            _hero(mech: {'ecoArcano'}, skills: ['bola'])
          ], [
            _foe('e0', 'Limo A')
          ]),
          const SkillCommand('bola', targetId: 'e0'));
      final echo = cast(0.1);
      expect(echo.state.enemies.single.hp, 100 - 36 - 18);
      expect(echo.state.enemies.single.stacks(StatusKind.burn), 4);
      expect(echo.state.log,
          contains('Eco Arcano: Bola de Fuego se repite al 50%'));
      final none = cast(0.5);
      expect(none.state.enemies.single.hp, 64);
    });
  });

  group('Precisión', () {
    test('Marca del Cazador: +15% de daño de todos por 3 turnos', () {
      final e = _engine();
      var step = _cmd(
          e,
          _battle([
            _hero(mech: {'marcaCazador'})
          ], _foes()),
          const AttackCommand(targetId: 'e0'));
      final mark = step.state.enemies.first.effects.single;
      expect(
          [mark.stat, mark.value, mark.turns], [BuffStat.damageTaken, 0.15, 3]);
      expect(step.state.log,
          contains('Marca del Cazador: Limo A recibe +15% de daño (3 turnos)'));
      final s = e.nextTurn(step.state).state;
      step = _cmd(e, s, const AttackCommand(targetId: 'e0'));
      expect(step.state.enemies.first.hp, 80 - 23);
      expect(step.state.log, contains('× 1.15 Marca'));
      expect(_procs(step, 'marcaCazador'), isEmpty, reason: 'ya marcado');
    });

    test('Punto Débil: +20% crítico contra marcados', () {
      final marked = _foe('e0', 'Limo A')
        ..effects = [
          const TimedEffect(
              sourceId: 'marcaCazador',
              stat: BuffStat.damageTaken,
              value: 0.15,
              turns: 3),
        ];
      final s = _cmd(
          _engine([0.1]),
          _battle([
            _hero(mech: {'puntoDebil'})
          ], [
            marked,
            _foe('e1', 'Limo B')
          ]),
          const AttackCommand(targetId: 'e0'));
      expect(s.state.enemies.first.hp, 100 - 35); // 20 × 1.5 × 1.15
      final plain = _cmd(
          _engine([0.1]),
          _battle([
            _hero(mech: {'puntoDebil'})
          ], _foes()),
          const AttackCommand(targetId: 'e0'));
      expect(plain.state.enemies.first.hp, 80);
    });
  });

  group('Toxina', () {
    test('Debilitar: −15% ATQ por 2 turnos del enemigo', () {
      final e = _engine();
      final step = _cmd(
          e,
          _battle([
            _hero(mech: {'debilitar'}, skills: ['venenosa'])
          ], [
            _foe('e0', 'Limo A', nextTurn: 5)
          ]),
          const SkillCommand('venenosa', targetId: 'e0'));
      expect(step.state.enemies.single.effectTotal(BuffStat.attack), -0.15);
      // Flecha Venenosa es Instante (§ 5.2): termina el turno a mano.
      final done = e.command(step.state, 'p1', const PassCommand())!;
      var s = e.nextTurn(done.state).state;
      expect(s.currentId, 'e0');
      final hit = e.enemyTurn(s)!;
      expect(hit.state.party.single.hp, 91); // round(10 × 0.85)
      expect(hit.state.log, contains('ATQ 9 (debilitado)'));
      expect(hit.state.enemies.single.effects.single.turns, 1);
    });

    test('Plaga Contagiosa: los stacks pasan al enemigo con más vida', () {
      final foes = [
        _foe('e0', 'Limo A', hp: 10, st: {StatusKind.poison: 3}),
        _foe('e1', 'Limo B', hp: 50),
        _foe('e2', 'Limo C', hp: 80),
      ];
      final s = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'plagaContagiosa'})
          ], foes),
          const AttackCommand(targetId: 'e0'));
      expect(s.state.enemies[2].stacks(StatusKind.poison), 3);
      expect(s.state.enemies[1].stacks(StatusKind.poison), 0);
      expect(
          s.state.log, contains('Plaga Contagiosa: 3 Veneno pasan a Limo C'));

      // También si muere por el veneno en su turno.
      final tick = _engine().nextTurn(_battle([
        _hero(mech: {'plagaContagiosa'}, nextTurn: 100),
      ], [
        _foe('e0', 'Limo A', hp: 1, nextTurn: 1, st: {StatusKind.poison: 2}),
        _foe('e1', 'Limo B', hp: 50),
      ], current: null));
      expect(tick.state.enemies[1].stacks(StatusKind.poison), 1);
    });
  });

  group('Viento', () {
    test('Rebote 40% (1 salto) y Cadena Infinita (todos, 60% c/u, −20%)', () {
      final one = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'rebote'})
          ], _foes()),
          const AttackCommand(targetId: 'e0'));
      expect(one.state.enemies.map((e) => e.hp), [80, 92, 100]);
      expect(one.state.log, contains('Rebote: 8 a Limo B'));

      final chain = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'rebote', 'cadena'}, keys: {'cadena'})
          ], _foes()),
          const AttackCommand(targetId: 'e1'));
      // 20 × 0.8 = 16 → 6 (40%) a Limo C → 4 (60%) a Limo A.
      expect(chain.state.enemies.map((e) => e.hp), [96, 84, 94]);
      expect(chain.state.log,
          contains('Rebote (Cadena Infinita): 6 a Limo C, 4 a Limo A'));
      expect(chain.state.log, contains('× 0.8 Cadena Infinita'));

      final both = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'rebote', 'corteCadena'}, crit: 1)
          ], _foes()),
          const AttackCommand(targetId: 'e0'));
      expect(both.state.enemies.map((e) => e.hp), [70, 85, 100],
          reason: 'un solo rebote, el de mayor %');

      final area = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'rebote'}, skills: ['giro'])
          ], _foes()),
          const SkillCommand('giro'));
      // Área × 0.6 (combo_balance.md § 4).
      expect(area.state.enemies.map((e) => e.hp), [88, 88, 88]);
    });

    test('Viento a Favor: habilidad a todos → ataque gratis al más débil', () {
      final s = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'vientoFavor'}, skills: ['rafaga'])
          ], _foes(hp: [100, 30, 100])),
          const SkillCommand('rafaga'));
      // Área × 0.6 (combo_balance.md § 4).
      expect(s.state.enemies.map((e) => e.hp), [89, 0, 89]);
      expect(
          s.state.log, contains('Viento a Favor: ataque gratis → Limo B: 20'));
      expect(s.events.whereType<ActionEvent>().map((a) => a.kind).toList(),
          [BattleActionKind.skill, BattleActionKind.attack]);
    });
  });

  group('Fe', () {
    test('Mano Sanadora: escudo del 20% de lo curado que absorbe golpes', () {
      final e = _engine();
      final step = _cmd(
          e,
          _battle([
            _hero(mech: {'manoSanadora'}, skills: ['cura'], hp: 50),
            _hero(id: 'p2', name: 'Leo', nextTurn: 30),
          ], [
            _foe('e0', 'Limo A', nextTurn: 5),
          ]),
          const SkillCommand('cura'));
      for (final p in step.state.party) {
        expect(p.shield, 7, reason: p.name); // round(36 × 0.2)
      }
      var s = e.nextTurn(step.state).state;
      expect(s.currentId, 'e0');
      final hit = e.enemyTurn(s)!; // azar 0.99 → Leo
      final leo = hit.state.party[1];
      expect(leo.hp, 97);
      expect(leo.shield, 0);
      expect(hit.events.whereType<ShieldEvent>().single.absorbed, isTrue);
      expect(hit.state.log, contains('escudo de Leo absorbe 7'));
    });

    test('Plegaria: al empezar tu turno cura 5% al aliado más herido', () {
      final s = _engine().nextTurn(_battle([
        _hero(mech: {'plegaria'}),
        _hero(id: 'p2', name: 'Leo', hp: 50, nextTurn: 30),
      ], _foes(), current: null));
      expect(s.state.party[1].hp, 55);
      expect(s.state.log, contains('Plegaria: Leo +5 HP'));
      final full = _engine().nextTurn(_battle([
        _hero(mech: {'plegaria'})
      ], _foes(), current: null));
      expect(full.events.whereType<ProcEvent>(), isEmpty);
    });
  });

  group('Bastión', () {
    test('Guardián: golpe absorbido por Protección → +8 ULT', () {
      final s = _engine().enemyTurn(_battle([
        _hero(mech: {'guardian'}, nextTurn: 10)..protecting = true,
        _hero(id: 'p2', name: 'Leo', nextTurn: 30),
      ], [
        _foe('e0', 'Limo A', nextTurn: 0),
      ], current: 'e0'))!;
      final ana = s.state.party.first;
      expect(ana.hp, 90);
      expect(ana.ult, closeTo(10 / 100 * 110 + 8, 1e-9));
      expect(_procs(s, 'guardian'), hasLength(1));
    });

    test('Desafío: Provocar da un escudo del 15% por 2 turnos', () {
      final s = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'desafio'}, skills: ['provocar'])
          ], _foes()),
          const SkillCommand('provocar'));
      final sh = s.state.party.single.effects.single;
      expect([sh.stat, sh.value, sh.turns], [BuffStat.shield, 15, 2]);
      expect(s.events.whereType<ShieldEvent>().single.amount, 15);
    });

    test('Égida Eterna: escudo del 10% al empezar el turno, no acumula', () {
      final e = _engine();
      var s = e
          .nextTurn(_battle([
            _hero(mech: {'egida'}, keys: {'egida'})
          ], _foes(), current: null))
          .state;
      expect(s.party.single.shield, 10);
      s = _cmd(e, s, const DefendCommand()).state;
      s = e.nextTurn(s).state;
      expect(s.currentId, 'p1');
      expect(s.party.single.shield, 10);
      expect(s.party.single.effects, hasLength(1));
    });
  });

  group('Juicio', () {
    test('Martillo Bendito: el aturdimiento dura 1 turno más (no jefes)', () {
      final e = _engine();
      var s = _cmd(
              e,
              _battle([
                _hero(mech: {'martilloBendito'}, stun: 1)
              ], [
                _foe('e0', 'Limo A', nextTurn: 5)
              ]),
              const AttackCommand(targetId: 'e0'))
          .state;
      expect(s.enemies.single.hasEffect(BuffStat.stunLock), isTrue);
      var skipped = 0;
      for (var i = 0; i < 8 && skipped < 3; i++) {
        final step = e.nextTurn(s);
        s = step.state;
        skipped += step.events.whereType<TurnSkippedEvent>().length;
        if (s.currentId == 'p1') s = e.timeout(s)!.state;
        if (s.currentId == 'e0') break;
      }
      expect(skipped, 2);
      expect(s.currentId, 'e0', reason: 'al tercer turno ya actúa');

      final boss = _cmd(
          e,
          _battle([
            _hero(mech: {'martilloBendito'}, stun: 1)
          ], [
            _foe('e0', 'Rey', boss: true)
          ]),
          const AttackCommand(targetId: 'e0'));
      expect(boss.state.enemies.single.hasEffect(BuffStat.stunLock), isFalse);
    });

    test('Castigo Divino: al aturdir, daño sagrado MAG × 0.6', () {
      final s = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'castigoDivino'}, stun: 1)
          ], [
            _foe('e0', 'Limo A')
          ]),
          const AttackCommand(targetId: 'e0'));
      expect(s.state.enemies.single.hp, 100 - 20 - 12);
      final holy = s.events.whereType<DamageEvent>().last;
      expect([holy.amount, holy.sourceId], [12, 'castigoDivino']);
      expect(s.state.log, contains('Castigo Divino: 12 sagrado a Limo A'));
    });
  });

  group('sistema', () {
    /// Batalla larga con TODAS las mecánicas en dos jugadores.
    List<String> run(int seed) {
      final e = BattleEngine(stats: _stats, random: mulberry32(seed));
      final all = kMechanics.keys.toSet();
      const keys = {'danza', 'almaHielo', 'cadena', 'egida'};
      const skills = [
        'bola',
        'chispa',
        'rafaga',
        'cura',
        'provocar',
        'venenosa',
        'lanzaH'
      ];
      var s = BattleState(party: [
        _hero(mech: all, keys: keys, skills: skills, crit: 0.35),
        _hero(
            id: 'p2',
            name: 'Leo',
            mech: all,
            keys: keys,
            skills: skills,
            crit: 0.35,
            nextTurn: 3,
            stun: 0.3),
      ], enemies: [
        for (var i = 0; i < 4; i++)
          // 1500 de vida desde v0.9: con las Instante (Chispa, Flecha
          // Venenosa) el grupo actúa dos veces por turno y con 300 la
          // pelea terminaba antes de que nada rebotara.
          _foe('e$i', 'Limo $i', nextTurn: 2.0 + i)
            ..hp = 1500
            ..maxHp = 1500,
      ]);
      final trace = <String>[];
      for (var i = 0; i < 3000 && !s.ended; i++) {
        final cur = s.current;
        BattleStep step;
        if (cur == null) {
          step = e.nextTurn(s);
        } else if (!cur.isPlayer) {
          step = e.enemyTurn(s)!;
        } else {
          final pick = i % (skills.length + 2);
          final cmd = pick < skills.length
              ? SkillCommand(skills[pick], targetId: 'e${i % 4}')
              : pick == skills.length
                  ? const DefendCommand()
                  : AttackCommand(targetId: 'e${i % 4}');
          step = e.command(s, cur.id, cmd) ??
              e.command(s, cur.id, const AttackCommand())!;
        }
        expect(step.events.whereType<ProcEvent>().length,
            lessThanOrEqualTo(BattleEngine.maxProcsPerStep));
        s = step.state;
        trace.add(s.log);
      }
      expect(s.ended, isTrue, reason: 'la batalla termina');
      trace.add(jsonEncode(const SessionJson().battleStateToJson(s)));
      return trace;
    }

    test('sin bucles infinitos y determinístico con el mismo azar', () {
      // La primera semilla que pasa por un rebote de Cadena Infinita (es
      // solo suerte del azar: cambió con el árbol v6 y con las Instante de
      // v0.9, que no terminan el turno).
      // ignore: avoid_print
      bool rebote(List<String> t) =>
          t.any((l) => l.contains('Rebote (Cadena Infinita)'));
      final seed = [for (var k = 1; k <= 40; k++) k]
          .firstWhere((k) => rebote(run(k)), orElse: () => -1);
      expect(seed, isNot(-1), reason: 'ninguna semilla rebota');
      final a = run(seed);
      expect(run(seed), a);
    });

    test('Combatant con mecánicas, efectos y turno extra: ida y vuelta JSON',
        () {
      final c = _hero(mech: {'frenesi', 'egida'}, keys: {'egida'})
        ..extraTurn = 1
        ..effects = [
          const TimedEffect(
              sourceId: 'frenesi',
              stat: BuffStat.speed,
              value: 0.2,
              turns: 2,
              ownerId: 'p1',
              fresh: true),
          const TimedEffect(
              sourceId: 'egida', stat: BuffStat.shield, value: 10, turns: 1),
        ];
      const js = SessionJson();
      final wire = asJson(jsonDecode(jsonEncode(js.combatantToJson(c))));
      final back = js.combatantFromJson(wire);
      expect(back.mechanics, c.mechanics);
      expect(back.extraTurn, 1);
      expect(
          back.effects.map((e) =>
              [e.sourceId, e.stat, e.value, e.turns, e.ownerId, e.fresh]),
          c.effects.map((e) =>
              [e.sourceId, e.stat, e.value, e.turns, e.ownerId, e.fresh]));
      expect(jsonEncode(js.combatantToJson(back)),
          jsonEncode(js.combatantToJson(c)));

      // Un combatiente viejo (sin las claves nuevas) se sigue leyendo.
      final old = Map.of(js.combatantToJson(_hero()))
        ..remove('mech')
        ..remove('fx')
        ..remove('xt');
      final o = js.combatantFromJson(old);
      expect(o.mechanics, isEmpty);
      expect(o.effects, isEmpty);
      expect(o.extraTurn, 0);
    });
  });
}
