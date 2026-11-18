import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// Un escenario determinístico por cada notable y keystone nuevo del árbol
// v3 (docs/specs/passive_tree_v3.md § 5-8). Combatientes armados a mano;
// el azar es una lista fija (0.99 al acabarse: nunca crítico ni
// probabilidad).

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  return BattleEngine(
      stats: _stats, random: () => i < rolls.length ? rolls[i++] : 0.99);
}

Combatant _hero({
  String id = 'p1',
  Set<String> mech = const {},
  double crit = 0,
  int hp = 100,
  List<String> skills = const [],
  double nextTurn = 0,
  double ult = 0,
  bool defending = false,
}) =>
    Combatant(
      id: id,
      name: id,
      isPlayer: true,
      hp: hp,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: crit,
      mp: 50,
      maxMp: 50,
      mechanics: {...mech},
      skillIds: skills,
      classId: 'guerrero',
      weaponType: 'espada',
      nextTurn: nextTurn,
      ult: ult,
      defending: defending,
    );

Combatant _foe(String id,
        {int hp = 100,
        double breakBase = 0,
        int vulnerable = 0,
        Map<StatusKind, int>? st,
        List<TimedEffect>? fx}) =>
    Combatant(
      id: id,
      name: 'Limo $id',
      isPlayer: false,
      hp: hp,
      maxHp: 100,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: 'slime',
      statuses: st,
      nextTurn: 50,
      breakBase: breakBase,
      vulnerable: vulnerable,
      effects: fx,
    );

BattleState _battle(List<Combatant> party, List<Combatant> enemies,
        {String? current = 'p1'}) =>
    BattleState(party: party, enemies: enemies, currentId: current);

BattleStep _cmd(BattleEngine e, BattleState s, BattleCommand c) =>
    e.command(s, 'p1', c)!;

BattleStep _enemyHits(BattleEngine e, BattleState s) {
  s.currentId = 'e0';
  return e.enemyTurn(s)!;
}

bool _proc(BattleStep s, String id) =>
    s.events.whereType<ProcEvent>().any((p) => p.sourceId == id);

Combatant _p(BattleStep s, [String id = 'p1']) => s.state.byId(id)!;
Combatant _e(BattleStep s, [int i = 0]) => s.state.enemies[i];

const _atk = AttackCommand(targetId: 'e0');
const _ult = UltimateCommand(targetId: 'e0');
SkillCommand _sk(String id) => SkillCommand(id, targetId: 'e0');

/// Vida que perdió el héroe al recibir un golpe de `e0`.
int _hurt(Set<String> mech, {int hp = 100, bool defending = false}) {
  final st = _enemyHits(_engine(),
      _battle([_hero(mech: mech, hp: hp, defending: defending)], [_foe('e0')]));
  return hp - _p(st).hp;
}

void main() {
  test('todas las mecánicas nuevas del árbol están en kMechanics', () {
    final v3 = {
      for (final n in kPassiveTree.nodes.values)
        if (n.mechanicId != null) n.mechanicId!,
    };
    for (final id in v3) {
      expect(mechanicById(id), isNotNull, reason: id);
    }
  });

  group('Guerrero: Quiebre', () {
    test('Rompeguardias: +30% de llenado de quiebre', () {
      final a = _cmd(_engine(), _battle([_hero()], [_foe('e0', breakBase: 999)]), _atk);
      final b = _cmd(_engine(),
          _battle([_hero(mech: {'rompeguardias'})], [_foe('e0', breakBase: 999)]), _atk);
      expect(_e(b).breakGauge, closeTo(_e(a).breakGauge * 1.3, 1e-6));
    });

    test('Ensañamiento (vsBroken): +25% a quebrados, nada al resto', () {
      final a = _cmd(_engine(),
          _battle([_hero(mech: {'ensanamiento'})], [_foe('e0', vulnerable: 2)]), _atk);
      expect(_e(a).hp, 100 - 38); // 20 × 1.5 QUIEBRE × 1.25
      final b = _cmd(_engine(), _battle([_hero(mech: {'ensanamiento'})], [_foe('e0')]), _atk);
      expect(_e(b).hp, 80);
    });

    test('Demoledor: al quebrar +20 ULT y +25% ATQ 2 turnos', () {
      final a = _cmd(_engine(), _battle([_hero()], [_foe('e0', breakBase: 10)]), _atk);
      final b = _cmd(_engine(),
          _battle([_hero(mech: {'demoledor'})], [_foe('e0', breakBase: 10)]), _atk);
      expect(_e(b).broken, isTrue);
      expect(_proc(b, 'demoledor'), isTrue);
      expect(_p(b).ult - _p(a).ult, closeTo(20, 1e-9));
      final fx = _p(b).effectFrom('demoledor', BuffStat.attack)!;
      expect((fx.value, fx.turns), (0.25, 2));
    });
  });

  group('Guerrero: Gritos', () {
    test('Clamor: tu ULT da +15% ATQ a todo el grupo', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'clamor'}, ult: 100),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0', hp: 999)]), _ult);
      for (final id in ['p1', 'p2']) {
        expect(_p(st, id).effectFrom('clamor', BuffStat.attack)!.value, 0.15,
            reason: id);
      }
    });

    test('Rugido: al matar +5 ULT propia y +8 a cada aliado', () {
      final a = _cmd(_engine(), _battle([_hero(), _hero(id: 'p2', nextTurn: 50)],
          [_foe('e0', hp: 5), _foe('e1')]), _atk);
      final b = _cmd(_engine(), _battle([
        _hero(mech: {'rugido'}),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0', hp: 5), _foe('e1')]), _atk);
      expect(_p(b).ult - _p(a).ult, closeTo(5, 1e-9));
      expect(_p(b, 'p2').ult, 8);
    });

    test('Caudillo: al empezar tu turno, grupo +12% ATQ (1 turno)', () {
      final st = _engine().nextTurn(_battle([
        _hero(mech: {'caudillo'}),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0')], current: null));
      expect(st.state.currentId, 'p1');
      for (final id in ['p1', 'p2']) {
        final fx = _p(st, id).effectFrom('caudillo', BuffStat.attack)!;
        expect((fx.value, fx.turns), (0.12, 1), reason: id);
      }
    });
  });

  group('Maga: Cronos', () {
    const embestida = 'embestida'; // retrasa 45%

    test('Reloj Roto: retrasar adelanta tu turno 25%', () {
      final a = _cmd(_engine(), _battle([_hero(skills: [embestida])], [_foe('e0')]),
          _sk(embestida));
      final b = _cmd(
          _engine(),
          _battle([_hero(mech: {'relojRoto'}, skills: [embestida])], [_foe('e0')]),
          _sk(embestida));
      expect(_proc(b, 'relojRoto'), isTrue);
      expect(_p(b).nextTurn, closeTo(_p(a).nextTurn * 0.75, 1e-9));
    });

    test('Paso Compartido: retrasar adelanta al aliado más lento 20%', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'pasoCompartido'}, skills: [embestida]),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0')]), _sk(embestida));
      expect(_p(st, 'p2').nextTurn, closeTo(48, 1e-9)); // IV 10 × 0.2
    });

    test('Bucle Eterno: retrasos 60% más largos', () {
      final a = _cmd(_engine(), _battle([_hero(skills: [embestida])], [_foe('e0')]),
          _sk(embestida));
      final b = _cmd(_engine(),
          _battle([_hero(mech: {'bucle'}, skills: [embestida])], [_foe('e0')]),
          _sk(embestida));
      expect(_e(b).nextTurn - 50, closeTo((_e(a).nextTurn - 50) * 1.6, 1e-9));
    });
  });

  group('Maga: Prisma', () {
    const two = {StatusKind.burn: 1, StatusKind.poison: 1};

    test('Refracción: +15% contra 2 elementos', () {
      final a = _cmd(_engine(),
          _battle([_hero(mech: {'refraccion'})], [_foe('e0', st: two)]), _atk);
      expect(_e(a).hp, 100 - 23);
      final b = _cmd(_engine(), _battle([_hero(mech: {'refraccion'})],
          [_foe('e0', st: {StatusKind.burn: 1})]), _atk);
      expect(_e(b).hp, 80);
    });

    test('Catalizador: 50% de sumar el primer elemento que falta', () {
      Combatant mage() => _hero(mech: {'catalizador'}, skills: ['lanzaH']);
      final yes = _cmd(_engine([0.99, 0.1]), _battle([mage()], [_foe('e0')]),
          _sk('lanzaH'));
      expect(_e(yes).stacks(StatusKind.freeze), 2);
      expect(_e(yes).stacks(StatusKind.burn), 1);
      final no = _cmd(_engine(), _battle([mage()], [_foe('e0')]), _sk('lanzaH'));
      expect(_e(no).stacks(StatusKind.burn), 0);
    });

    test('Singularidad: +30% daño y +10% crítico contra 2 elementos', () {
      final a = _cmd(_engine(),
          _battle([_hero(mech: {'singularidad'})], [_foe('e0', st: two)]), _atk);
      expect(_e(a).hp, 100 - 26);
      // 0.05 < 10% de crítico: critea solo por la keystone.
      final c = _cmd(_engine([0.05]),
          _battle([_hero(mech: {'singularidad'})], [_foe('e0', st: two)]), _atk);
      expect(c.events.whereType<DamageEvent>().first.critical, isTrue);
    });
  });

  group('Tirador: Lluvia', () {
    Combatant archer(Set<String> mech) => _hero(mech: mech, skills: ['rafaga']);
    List<Combatant> foes() => [_foe('e0'), _foe('e1')];

    test('Aguacero: habilidades a todos +15%', () {
      final st = _cmd(_engine(), _battle([archer({'aguacero'})], foes()), _sk('rafaga'));
      for (final f in st.state.enemies) {
        expect(f.hp, 100 - 21); // 18 × 1.15
      }
      // A un solo objetivo no aplica.
      final one = _cmd(_engine(), _battle([archer({'aguacero'})], foes()), _atk);
      expect(_e(one).hp, 80);
    });

    test('Esquirlas: después de una habilidad a todos, turno 20% antes', () {
      final a = _cmd(_engine(), _battle([archer({})], foes()), _sk('rafaga'));
      final b = _cmd(_engine(), _battle([archer({'esquirlas'})], foes()), _sk('rafaga'));
      expect(_p(b).nextTurn, closeTo(_p(a).nextTurn * 0.8, 1e-9));
    });

    test('Diluvio: la habilidad a todos se repite al 40%', () {
      final st = _cmd(_engine(), _battle([archer({'diluvio'})], foes()), _sk('rafaga'));
      expect(_proc(st, 'diluvio'), isTrue);
      for (final f in st.state.enemies) {
        expect(f.hp, 100 - 18 - 7);
      }
    });
  });

  group('Tirador: Acecho', () {
    test('Presa Herida: +15% a marcados', () {
      const mark = TimedEffect(
          sourceId: 'x', stat: BuffStat.damageTaken, value: 0.15, turns: 3);
      final st = _cmd(_engine(), _battle([_hero(mech: {'presaHerida'})],
          [_foe('e0', fx: [mark])]), _atk);
      expect(_e(st).hp, 100 - 26); // 20 × 1.15 × 1.15
    });

    test('Rematar: remata con menos de 12% de vida (no jefes)', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'rematar'})], [_foe('e0', hp: 30), _foe('e1')]), _atk);
      expect(_e(st).alive, isFalse);
      expect(_proc(st, 'rematar'), isTrue);
      final keep = _cmd(_engine(),
          _battle([_hero(mech: {'rematar'})], [_foe('e0', hp: 40), _foe('e1')]), _atk);
      expect(_e(keep).hp, 20);
    });

    test('Depredador: cada golpe marca +25% de daño recibido', () {
      final st = _cmd(_engine(), _battle([_hero(mech: {'depredador'})], [_foe('e0')]), _atk);
      final fx = _e(st).effectFrom('depredador', BuffStat.damageTaken)!;
      expect((fx.value, fx.turns), (0.25, 3));
    });
  });

  group('Paladín: Luz', () {
    test('Llama Sagrada: 30% de 1 Sagrado a un solo objetivo', () {
      final yes = _cmd(_engine([0.99, 0.1]),
          _battle([_hero(mech: {'llamaSagrada'})], [_foe('e0')]), _atk);
      expect(_e(yes).stacks(StatusKind.holy), 1);
      final no = _cmd(_engine(), _battle([_hero(mech: {'llamaSagrada'})], [_foe('e0')]), _atk);
      expect(_e(no).stacks(StatusKind.holy), 0);
    });

    test('Resplandor: +20% contra enemigos con Sagrado', () {
      final st = _cmd(_engine(), _battle([_hero(mech: {'resplandor'})],
          [_foe('e0', st: {StatusKind.holy: 1})]), _atk);
      expect(_e(st).hp, 100 - 24);
    });

    test('Sol Interior: cada golpe aplica 1 Sagrado (también a todos)', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'solInterior'}, skills: ['rafaga'])],
              [_foe('e0'), _foe('e1')]),
          _sk('rafaga'));
      for (final f in st.state.enemies) {
        expect(f.stacks(StatusKind.holy), 1);
      }
    });
  });

  group('Paladín: Vigilia (guarda por condición)', () {
    test('Guardia Alta: golpe defendiendo → escudo 10%', () {
      final st = _enemyHits(_engine(),
          _battle([_hero(mech: {'guardiaAlta'}, defending: true)], [_foe('e0')]));
      expect(_p(st).shield, 10);
    });

    test('Voto de Hierro: −15% de daño con menos de 50% de vida', () {
      final base = _hurt({}, hp: 40);
      expect(_hurt({'votoHierro'}, hp: 40), lessThan(base));
      expect(_hurt({'votoHierro'}, hp: 90), _hurt({}, hp: 90));
    });

    test('Inamovible: −25% de daño siempre', () {
      final base = _hurt({});
      final tank = _hurt({'inamovible'});
      expect(tank, lessThan(base));
      expect(tank, closeTo(base * 0.75, 1));
    });
  });

  group('Puentes', () {
    test('Filo Rúnico y Égida Rúnica: habilidad mágica → +20% ATQ y escudo', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'filoRunico', 'egidaRunica'}, skills: ['chispa']),
      ], [_foe('e0')]), _sk('chispa'));
      expect(_p(st).effectFrom('filoRunico', BuffStat.attack)!.value, 0.20);
      expect(_p(st).shield, 8);
    });

    test('Ojo Arcano: +15% crítico en habilidades mágicas', () {
      SkillCommand c = _sk('chispa');
      final yes = _cmd(_engine([0.1]),
          _battle([_hero(mech: {'ojoArcano'}, skills: ['chispa'])], [_foe('e0')]), c);
      expect(yes.events.whereType<DamageEvent>().first.critical, isTrue);
      final atk = _cmd(_engine([0.1]),
          _battle([_hero(mech: {'ojoArcano'})], [_foe('e0')]), _atk);
      expect(atk.events.whereType<DamageEvent>().first.critical, isFalse);
    });

    test('Sobrecarga y Saeta Sagrada: al critear', () {
      final a = _cmd(_engine(), _battle([_hero(crit: 1)], [_foe('e0', hp: 999)]), _atk);
      final b = _cmd(_engine(), _battle([
        _hero(mech: {'sobrecarga', 'saetaSagrada'}, crit: 1),
      ], [_foe('e0', hp: 999)]), _atk);
      expect(_p(b).ult - _p(a).ult, closeTo(8, 1e-9));
      expect(_e(b).stacks(StatusKind.holy), 1);
    });

    test('Ojo del Vigía: el que te pega queda marcado', () {
      final st = _enemyHits(_engine(), _battle([_hero(mech: {'vigia'})], [_foe('e0')]));
      expect(_e(st).effectFrom('vigia', BuffStat.damageTaken)!.value, 0.15);
    });

    test('Cobertura: al empezar tu turno, escudo al más herido', () {
      final st = _engine().nextTurn(_battle([
        _hero(mech: {'cobertura'}),
        _hero(id: 'p2', nextTurn: 50, hp: 40),
      ], [_foe('e0')], current: null));
      expect(_p(st, 'p2').shield, 6);
      expect(_p(st).shield, 0);
    });

    test('Piel de Piedra y Peso Muerto: al recibir un golpe', () {
      final st = _enemyHits(_engine(),
          _battle([_hero(mech: {'pielPiedra', 'pesoMuerto'})], [_foe('e0')]));
      expect(_p(st).shield, 5);
      expect(_p(st).effectFrom('pesoMuerto', BuffStat.attack)!.value, 0.15);
    });

    test('Desquite: con menos de 50% devolvés el 40%', () {
      final st = _enemyHits(_engine(),
          _battle([_hero(mech: {'desquite'}, hp: 40)], [_foe('e0')]));
      final taken = 40 - _p(st).hp;
      expect(_e(st).hp, 100 - (taken * 0.4).round().clamp(1, 99));
      final high = _enemyHits(_engine(),
          _battle([_hero(mech: {'desquite'})], [_foe('e0')]));
      expect(_e(high).hp, 100);
    });
  });

  group('Clusters de grupo', () {
    test('Bandera de Guerra: aura +5% de daño (también solo)', () {
      final solo = _cmd(_engine(),
          _battle([_hero(mech: {'banderaGuerra'})], [_foe('e0')]), _atk);
      expect(_e(solo).hp, 79);
      final ally = _engine().command(
          _battle([
            _hero(mech: {'banderaGuerra'}, nextTurn: 50),
            _hero(id: 'p2'),
          ], [_foe('e0')], current: 'p2'),
          'p2',
          _atk)!;
      expect(_e(ally).hp, 79);
    });

    test('Carga Conjunta: al quebrar, grupo +10% ATQ', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'cargaConjunta'}),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0', breakBase: 10)]), _atk);
      for (final id in ['p1', 'p2']) {
        expect(_p(st, id).effectFrom('cargaConjunta', BuffStat.attack)!.value,
            0.10);
      }
    });

    test('Relevo y Escudo Compartido: al usar tu ULT', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'relevo', 'escudoCompartido'}, ult: 100),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0', hp: 999)]), _ult);
      expect(_p(st, 'p2').ult, 10);
      expect(_p(st).ult, 5);
      expect(_p(st, 'p2').shield, 10);
      expect(_p(st).shield, 10);
    });

    test('A la Carga y Lazo Vital: al matar', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'alaCarga', 'lazoVital'}),
        _hero(id: 'p2', nextTurn: 50, hp: 50),
      ], [_foe('e0', hp: 5), _foe('e1')]), _atk);
      expect(_p(st, 'p2').nextTurn, closeTo(48, 1e-9));
      expect(_p(st, 'p2').hp, 54);
    });

    test('Formación: aura −5% de daño recibido', () {
      final base = _hurt({});
      expect(_hurt({'formacion'}), closeTo(base * 0.95, 1));
    });

    test('Hermandad: al empezar tu turno cura 3% al más herido', () {
      final st = _engine().nextTurn(_battle([
        _hero(mech: {'hermandad'}),
        _hero(id: 'p2', nextTurn: 50, hp: 50),
      ], [_foe('e0')], current: null));
      expect(_p(st, 'p2').hp, 53);
    });
  });

  test('sin las mecánicas nuevas, los números no cambian (sin azar extra)', () {
    var calls = 0;
    final e = BattleEngine(stats: _stats, random: () {
      calls++;
      return 0.99;
    });
    final st = e.command(_battle([_hero()], [_foe('e0')]), 'p1', _atk)!;
    expect(_e(st).hp, 80);
    expect(calls, 1, reason: 'solo el crítico');
    expect(kMechanics['ensanamiento']!.isCondition, isTrue);
  });
}
