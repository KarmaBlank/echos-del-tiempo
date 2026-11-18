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

// Un escenario determinístico por cada notable nuevo del árbol v4
// (docs/specs/passive_tree_v4.md § 3-4). Combatientes armados a mano; el
// azar es una lista fija (0.99 al acabarse: nunca crítico ni
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
  List<TimedEffect>? fx,
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
      effects: fx,
    );

Combatant _foe(String id,
        {int hp = 100,
        double breakBase = 0,
        double nextTurn = 50,
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
      nextTurn: nextTurn,
      breakBase: breakBase,
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

const _mark = TimedEffect(
    sourceId: 'x', stat: BuffStat.damageTaken, value: 0.15, turns: 3);

/// Vida que perdió el héroe al recibir un golpe de `e0`.
int _hurt(Set<String> mech, {int hp = 100}) {
  final st =
      _enemyHits(_engine(), _battle([_hero(mech: mech, hp: hp)], [_foe('e0')]));
  return hp - _p(st).hp;
}

/// Cuánto subió la barra de quiebre de `e0` con un ataque.
double _gauge(Set<String> mech, {Map<StatusKind, int>? st, bool mark = false}) {
  final s = _cmd(
      _engine(),
      _battle([
        _hero(mech: mech)
      ], [
        _foe('e0', breakBase: 999, st: st, fx: mark ? [_mark] : null),
      ]),
      _atk);
  return _e(s).breakGauge;
}

void main() {
  test('todas las mecánicas nuevas del árbol v4 existen y no son de v3', () {
    const v4 = [
      'rompeolas', 'corazaEspinas', 'sangriaVital', 'frenesiSangriento', //
      'mazazo', 'brecha', 'arenga', 'estruendo', 'estocadaPrecisa', 'desarme',
      'canalizar', 'pulsoArcano', 'ascuasVivas', 'pira', 'arenaTiempo',
      'anclaTemporal', 'frioPenetrante', 'hieloQuebradizo', 'chispaPrismatica',
      'descomposicion', 'vientoCortante', 'huracan', 'lluviaAcida', 'granizo',
      'tiroALaCabeza', 'grietaExpuesta', 'trampaCaza', 'caceria',
      'toxinaParalizante', 'nubeToxica', 'manoLuminosa', 'estallidoSolar',
      'sentencia', 'veredicto', 'comunion', 'milagro', 'represaliaSagrada',
      'resiliencia', 'puas', 'escudoSolidario', 'estandarteAlzado',
      'resonanciaGrupal', 'angelGuardian', 'muroEscudos',
    ];
    expect(v4.toSet(), hasLength(44));
    final inTree = {
      for (final n in kPassiveTree.nodes.values)
        if (n.mechanicId != null) n.mechanicId!,
    };
    for (final id in v4) {
      expect(kMechanics[id], isNotNull, reason: id);
      expect(inTree, contains(id), reason: id);
      expect(kMechanics[id]!.description, isNotEmpty, reason: id);
    }
  });

  group('Guerrero', () {
    test('Rompeolas: defender retrasa al atacante 25%', () {
      double next(Set<String> mech) => _e(_enemyHits(_engine(),
              _battle([_hero(mech: mech, defending: true)], [_foe('e0')])))
          .nextTurn;
      expect(next({'rompeolas'}) - next({}), closeTo(20 * 0.25, 1e-9));
      // Sin defender no pasa nada.
      final st = _enemyHits(
          _engine(),
          _battle([
            _hero(mech: {'rompeolas'})
          ], [
            _foe('e0')
          ]));
      expect(_proc(st, 'rompeolas'), isFalse);
    });

    test('Coraza de Espinas: cada golpe recibido devuelve el 20%', () {
      final st = _enemyHits(
          _engine(),
          _battle([
            _hero(mech: {'corazaEspinas'})
          ], [
            _foe('e0')
          ]));
      final taken = 100 - _p(st).hp;
      expect(_e(st).hp, 100 - (taken * 0.2).round().clamp(1, 99));
    });

    test('Sangría: robás el 10% del daño', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'sangriaVital'}, hp: 50)
          ], [
            _foe('e0')
          ]),
          _atk);
      expect(_p(st).hp, 52);
    });

    test('Frenesí Sangriento: más daño cuanta más vida falta', () {
      final half = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'frenesiSangriento'}, hp: 50)
          ], [
            _foe('e0')
          ]),
          _atk);
      expect(_e(half).hp, 100 - 24); // 20 × 1.2
      final full = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'frenesiSangriento'})
          ], [
            _foe('e0')
          ]),
          _atk);
      expect(_e(full).hp, 80);
    });

    test('Mazazo: 12% de aturdir a un solo objetivo', () {
      final yes = _cmd(
          _engine([0.99, 0.05]),
          _battle([
            _hero(mech: {'mazazo'})
          ], [
            _foe('e0')
          ]),
          _atk);
      expect(_e(yes).stacks(StatusKind.stun), 1);
      final no = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'mazazo'})
          ], [
            _foe('e0')
          ]),
          _atk);
      expect(_e(no).stacks(StatusKind.stun), 0);
    });

    test('Brecha: al quebrar, tu próximo turno (solo) llega 30% antes', () {
      final a = _cmd(
          _engine(), _battle([_hero()], [_foe('e0', breakBase: 10)]), _atk);
      final b = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'brecha'})
          ], [
            _foe('e0', breakBase: 10)
          ]),
          _atk);
      expect(_e(b).broken, isTrue);
      expect(_proc(b, 'brecha'), isTrue);
      expect(_p(b).nextTurn, closeTo(_p(a).nextTurn * 0.7, 1e-9));
    });

    test('Brecha en grupo: el aliado más lento se adelanta 30%', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'brecha'}),
            _hero(id: 'p2', nextTurn: 50),
          ], [
            _foe('e0', breakBase: 10)
          ]),
          _atk);
      expect(_p(st, 'p2').nextTurn, closeTo(47, 1e-9)); // IV 10 × 0.3
    });

    test('Arenga: al matar, grupo +15% velocidad 2 turnos', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'arenga'}),
            _hero(id: 'p2', nextTurn: 50),
          ], [
            _foe('e0', hp: 5),
            _foe('e1')
          ]),
          _atk);
      for (final id in ['p1', 'p2']) {
        final fx = _p(st, id).effectFrom('arenga', BuffStat.speed)!;
        expect((fx.value, fx.turns), (0.15, 2), reason: id);
      }
    });

    test('Estruendo: buffs de grupo 30% más fuertes y 1 turno más', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'clamor', 'estruendo'}, ult: 100)
          ], [
            _foe('e0', hp: 999)
          ]),
          _ult);
      final fx = _p(st).effectFrom('clamor', BuffStat.attack)!;
      expect(fx.value, closeTo(0.15 * 1.3, 1e-9));
      expect(fx.turns, 3);
    });

    test('Estocada Precisa: críticos a uno ×1.8', () {
      int dmg(Set<String> mech) => _cmd(
              _engine(),
              _battle([_hero(mech: mech, crit: 1)], [_foe('e0', hp: 999)]),
              _atk)
          .events
          .whereType<DamageEvent>()
          .first
          .amount;
      expect(dmg({}), 30);
      expect(dmg({'estocadaPrecisa'}), 36);
    });

    test('Desarme: al critear, el objetivo pega −20% ATQ', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'desarme'}, crit: 1)
          ], [
            _foe('e0', hp: 999)
          ]),
          _atk);
      final fx = _e(st).effectFrom('desarme', BuffStat.attack)!;
      expect((fx.value, fx.turns), (-0.20, 2));
    });
  });

  group('Maga', () {
    test('Canalizar: cada habilidad mágica +4 ULT', () {
      final a = _cmd(
          _engine(),
          _battle([
            _hero(skills: ['chispa'])
          ], [
            _foe('e0')
          ]),
          _sk('chispa'));
      final b = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'canalizar'}, skills: ['chispa'])
          ], [
            _foe('e0')
          ]),
          _sk('chispa'));
      expect(_p(b).ult - _p(a).ult, closeTo(4, 1e-9));
    });

    test('Pulso Arcano: después de la ULT, turno 50% antes', () {
      final a = _cmd(
          _engine(), _battle([_hero(ult: 100)], [_foe('e0', hp: 999)]), _ult);
      final b = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'pulsoArcano'}, ult: 100)
          ], [
            _foe('e0', hp: 999)
          ]),
          _ult);
      expect(_p(b).nextTurn, closeTo(_p(a).nextTurn * 0.5, 1e-9));
    });

    test('Ascuas Vivas: +15% crítico contra quemados', () {
      bool crit(Map<StatusKind, int>? st) => _cmd(
              _engine([0.1]),
              _battle([
                _hero(mech: {'ascuasVivas'})
              ], [
                _foe('e0', st: st)
              ]),
              _atk)
          .events
          .whereType<DamageEvent>()
          .first
          .critical;
      expect(crit({StatusKind.burn: 1}), isTrue);
      expect(crit(null), isFalse);
    });

    test('Pira: la Quemadura de un enemigo que muere pasa al de más vida', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'pira'})
          ], [
            _foe('e0', hp: 5, st: {StatusKind.burn: 3}),
            _foe('e1'),
          ]),
          _atk);
      expect(_e(st).alive, isFalse);
      expect(_e(st, 1).stacks(StatusKind.burn), 3);
    });

    test('Arena del Tiempo: 25% de retrasar 15% a un solo objetivo', () {
      final yes = _cmd(
          _engine([0.99, 0.1]),
          _battle([
            _hero(mech: {'arenaTiempo'})
          ], [
            _foe('e0')
          ]),
          _atk);
      expect(_e(yes).nextTurn, closeTo(50 + 20 * 0.15, 1e-9));
      final no = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'arenaTiempo'})
          ], [
            _foe('e0')
          ]),
          _atk);
      expect(_e(no).nextTurn, 50);
    });

    test('Ancla Temporal: retrasar deja al enemigo −20% velocidad', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'anclaTemporal'}, skills: ['embestida'])
          ], [
            _foe('e0')
          ]),
          _sk('embestida'));
      final fx = _e(st).effectFrom('anclaTemporal', BuffStat.speed)!;
      expect((fx.value, fx.turns), (-0.20, 2));
    });

    test('Frío Penetrante: 50% de +1 Congelación al congelar', () {
      Combatant mage() => _hero(mech: {'frioPenetrante'}, skills: ['lanzaH']);
      final yes = _cmd(
          _engine([0.99, 0.1]), _battle([mage()], [_foe('e0')]), _sk('lanzaH'));
      expect(_e(yes).stacks(StatusKind.freeze), 3);
      final no =
          _cmd(_engine(), _battle([mage()], [_foe('e0')]), _sk('lanzaH'));
      expect(_e(no).stacks(StatusKind.freeze), 2);
    });

    test('Hielo Quebradizo: +50% de quiebre contra congelados', () {
      const frz = {StatusKind.freeze: 1};
      expect(_gauge({'hieloQuebradizo'}, st: frz),
          closeTo(_gauge({}, st: frz) * 1.5, 0.11));
      expect(_gauge({'hieloQuebradizo'}), _gauge({}));
    });

    test('Chispa Prismática: la mágica a uno suma 1 Congelación', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'chispaPrismatica'}, skills: ['chispa'])
          ], [
            _foe('e0')
          ]),
          _sk('chispa'));
      expect(_e(st).stacks(StatusKind.burn), 1);
      expect(_e(st).stacks(StatusKind.freeze), 1);
    });

    test('Descomposición: los elementos del muerto se esparcen a la mitad', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'descomposicion'})
          ], [
            _foe('e0', hp: 5, st: {StatusKind.burn: 2, StatusKind.poison: 3}),
            _foe('e1'),
          ]),
          _atk);
      expect(_e(st, 1).stacks(StatusKind.burn), 1);
      expect(_e(st, 1).stacks(StatusKind.poison), 2);
    });
  });

  group('Tirador', () {
    List<Combatant> foes() => [_foe('e0'), _foe('e1')];
    Combatant archer(Set<String> mech) => _hero(mech: mech, skills: ['rafaga']);

    test('Viento Cortante: habilidad a todos → +15% crítico 2 turnos', () {
      final st = _cmd(
          _engine(),
          _battle([
            archer({'vientoCortante'})
          ], foes()),
          _sk('rafaga'));
      final fx = _p(st).effectFrom('vientoCortante', BuffStat.crit)!;
      expect((fx.value, fx.turns), (0.15, 2));
    });

    test('Huracán: 35% de turno extra al matar', () {
      final yes = _cmd(
          _engine([0.99, 0.1]),
          _battle([
            _hero(mech: {'huracan'})
          ], [
            _foe('e0', hp: 5),
            _foe('e1')
          ]),
          _atk);
      expect(_proc(yes, 'huracan'), isTrue);
      expect(_p(yes).extraTurn, 1);
      final no = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'huracan'})
          ], [
            _foe('e0', hp: 5),
            _foe('e1')
          ]),
          _atk);
      expect(_proc(no, 'huracan'), isFalse);
    });

    test('Lluvia Ácida y Granizo: a todos, +1 Veneno y retraso 10%', () {
      final st = _cmd(
          _engine(),
          _battle([
            archer({'lluviaAcida', 'granizo'})
          ], foes()),
          _sk('rafaga'));
      for (final f in st.state.enemies) {
        expect(f.stacks(StatusKind.poison), 1, reason: f.id);
        expect(f.nextTurn, closeTo(50 + 20 * 0.10, 1e-9), reason: f.id);
      }
      // A un solo objetivo no aplican.
      final one = _cmd(
          _engine(),
          _battle([
            archer({'lluviaAcida', 'granizo'})
          ], foes()),
          _atk);
      expect(_e(one).stacks(StatusKind.poison), 0);
    });

    test('Tiro a la Cabeza: 25% de aturdir al critear a uno', () {
      final st = _cmd(
          _engine([0.5, 0.1]),
          _battle([
            _hero(mech: {'tiroALaCabeza'}, crit: 1)
          ], [
            _foe('e0', hp: 999)
          ]),
          _atk);
      expect(_e(st).stacks(StatusKind.stun), 1);
    });

    test('Grieta Expuesta: +40% de quiebre contra marcados', () {
      expect(_gauge({'grietaExpuesta'}, mark: true),
          closeTo(_gauge({}, mark: true) * 1.4, 0.11));
      expect(_gauge({'grietaExpuesta'}), _gauge({}));
    });

    test('Trampa de Caza y Cacería: trampa al 30%; al saltar, marca', () {
      final e = _engine([0.99, 0.1]);
      final st = _cmd(
          e,
          _battle([
            _hero(mech: {'trampaCaza', 'caceria'})
          ], [
            _foe('e0', nextTurn: 1)
          ]),
          _atk);
      final trap = _e(st).effectFrom('trampaCaza', BuffStat.trap)!;
      expect((trap.value, trap.turns), (12.0, 2));
      final next = e.nextTurn(st.state);
      expect(next.state.currentId, 'e0');
      final e0 = next.state.enemies.first;
      expect(e0.hp, 80 - 12);
      expect(e0.effectFrom('caceria', BuffStat.damageTaken)!.value, 0.20);
    });

    test('Toxina Paralizante: envenenar → −15% velocidad', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'toxinaParalizante'}, skills: ['venenosa'])
          ], [
            _foe('e0')
          ]),
          _sk('venenosa'));
      expect(_e(st).stacks(StatusKind.poison), greaterThan(0));
      final fx = _e(st).effectFrom('toxinaParalizante', BuffStat.speed)!;
      expect((fx.value, fx.turns), (-0.15, 2));
    });

    test('Nube Tóxica: con 4+ Veneno el golpe salpica 40%', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'nubeToxica'})
          ], [
            _foe('e0', st: {StatusKind.poison: 4}),
            _foe('e1'),
          ]),
          _atk);
      expect(_e(st, 1).hp, 100 - 8);
      final few = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'nubeToxica'})
          ], [
            _foe('e0', st: {StatusKind.poison: 3}),
            _foe('e1'),
          ]),
          _atk);
      expect(_e(few, 1).hp, 100);
    });
  });

  group('Paladín', () {
    test('Mano Luminosa: golpear a uno cura 3% al más herido', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'manoLuminosa'}, hp: 50)
          ], [
            _foe('e0')
          ]),
          _atk);
      expect(_p(st).hp, 53);
    });

    test('Estallido Solar: con 3+ Sagrado, daño sagrado MAG × 0.5', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'estallidoSolar'})
          ], [
            _foe('e0', st: {StatusKind.holy: 3})
          ]),
          _atk);
      expect(_e(st).hp, 100 - 20 - 10);
      final two = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'estallidoSolar'})
          ], [
            _foe('e0', st: {StatusKind.holy: 2})
          ]),
          _atk);
      expect(_e(two).hp, 80);
    });

    test('Sentencia: +30% a aturdidos', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'sentencia'})
          ], [
            _foe('e0', st: {StatusKind.stun: 1})
          ]),
          _atk);
      expect(_e(st).hp, 100 - 26);
    });

    test('Veredicto: aturdir marca +20%', () {
      final st = _cmd(
          _engine([0.99, 0.1]),
          _battle([
            _hero(mech: {'veredicto'}, skills: ['golpeEscudo'])
          ], [
            _foe('e0')
          ]),
          _sk('golpeEscudo'));
      expect(_e(st).stacks(StatusKind.stun), 1);
      expect(_e(st).effectFrom('veredicto', BuffStat.damageTaken)!.value, 0.20);
    });

    test('Comunión: tus curas también te curan 5%', () {
      int hp(Set<String> mech) => _p(_cmd(
              _engine(),
              _battle([
                _hero(mech: mech, skills: ['cura'], hp: 20),
                _hero(id: 'p2', nextTurn: 30, hp: 20),
              ], [
                _foe('e0')
              ]),
              const SkillCommand('cura')))
          .hp;
      expect(hp({'comunion'}) - hp({}), 5);
    });

    test('Milagro: el golpe mortal te deja en 1 HP (1 vez)', () {
      final st = _enemyHits(
          _engine(),
          _battle([
            _hero(mech: {'milagro'}, hp: 5)
          ], [
            _foe('e0')
          ]));
      expect(_p(st).hp, 1);
      expect(_p(st).once, contains('milagro'));
    });

    test('Represalia Sagrada: el que te pega recibe 1 Sagrado', () {
      final st = _enemyHits(
          _engine(),
          _battle([
            _hero(mech: {'represaliaSagrada'})
          ], [
            _foe('e0')
          ]));
      expect(_e(st).stacks(StatusKind.holy), 1);
    });

    test('Resiliencia: menos daño cuanta más vida falta', () {
      expect(_hurt({'resiliencia'}, hp: 30), lessThan(_hurt({}, hp: 30)));
      expect(_hurt({'resiliencia'}), _hurt({}));
    });

    test('Púas: tus escudos devuelven 40% de lo que absorben', () {
      const shield = TimedEffect(
          sourceId: 'x',
          stat: BuffStat.shield,
          value: 50,
          turns: 2,
          ownerId: 'p1');
      final st = _enemyHits(
          _engine(),
          _battle([
            _hero(mech: {'puas'}, fx: [shield]),
          ], [
            _foe('e0')
          ]));
      final absorbed = st.events
          .whereType<ShieldEvent>()
          .firstWhere((s) => s.absorbed)
          .amount;
      expect(_p(st).hp, 100);
      expect(_proc(st, 'puas'), isTrue);
      expect(_e(st).hp, 100 - (absorbed * 0.4).round().clamp(1, 99));
    });

    test('Escudo Solidario: al recibir un golpe, escudo al más herido', () {
      // El azar 0.99 elige al último del grupo (p1).
      final st = _enemyHits(
          _engine(),
          _battle([
            _hero(id: 'p2', hp: 40, nextTurn: 50),
            _hero(mech: {'escudoSolidario'}),
          ], [
            _foe('e0')
          ]));
      expect(_p(st).hp, lessThan(100));
      expect(_p(st, 'p2').shield, 6);
    });
  });

  group('Clusters de grupo: la punta', () {
    test('Estandarte Alzado: tu ULT adelanta al grupo 25%', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'estandarteAlzado'}, ult: 100),
            _hero(id: 'p2', nextTurn: 50),
          ], [
            _foe('e0', hp: 999)
          ]),
          _ult);
      expect(_p(st, 'p2').nextTurn, closeTo(47.5, 1e-9));
    });

    test('Resonancia: al quebrar, +6 ULT para todo el grupo', () {
      List<Combatant> party(Set<String> mech) =>
          [_hero(mech: mech), _hero(id: 'p2', nextTurn: 50)];
      final a = _cmd(
          _engine(), _battle(party({}), [_foe('e0', breakBase: 10)]), _atk);
      final b = _cmd(
          _engine(),
          _battle(party({'resonanciaGrupal'}), [_foe('e0', breakBase: 10)]),
          _atk);
      expect(_p(b).ult - _p(a).ult, closeTo(6, 1e-9));
      expect(_p(b, 'p2').ult, 6);
    });

    test('Ángel Guardián: el primer aliado que caería queda en 1 HP', () {
      final st = _enemyHits(
          _engine([0.0]),
          _battle([
            _hero(id: 'p2', hp: 5),
            _hero(mech: {'angelGuardian'}),
          ], [
            _foe('e0')
          ]));
      expect(_p(st, 'p2').hp, 1);
      expect(_p(st).once, contains('angelGuardian'));
    });

    test('Muro de Escudos: golpe defendiendo → escudo 6% a todos', () {
      final st = _enemyHits(
          _engine(),
          _battle([
            _hero(id: 'p2', nextTurn: 50),
            _hero(mech: {'muroEscudos'}, defending: true),
          ], [
            _foe('e0')
          ]));
      expect(_p(st, 'p2').shield, 6);
      expect(_p(st).shield, 6);
    });
  });

  test('sin las mecánicas nuevas, los números no cambian (sin azar extra)', () {
    var calls = 0;
    final e = BattleEngine(
        stats: _stats,
        random: () {
          calls++;
          return 0.99;
        });
    final st = e.command(_battle([_hero()], [_foe('e0')]), 'p1', _atk)!;
    expect(_e(st).hp, 80);
    expect(calls, 1, reason: 'solo el crítico');
  });
}
