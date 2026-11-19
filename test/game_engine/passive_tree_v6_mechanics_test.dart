import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_v6.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// Un escenario determinístico por cada notable y keystone del árbol v6
// (docs/specs/passive_tree_v6.md § 4-6) y uno por cada tipo de efecto de
// nodo chico (§ 3). Combatientes armados a mano; el azar es fijo: 0.99
// (nunca crítico ni probabilidad) salvo que el test diga otra cosa.

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine({double roll = 0.99, List<double> rolls = const [],
    bool fam = false}) {
  var i = 0;
  return BattleEngine(
      stats: _stats,
      random: () => i < rolls.length ? rolls[i++] : roll,
      familiesEnabled: fam);
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
  bool protecting = false,
  int taunt = 0,
  List<TimedEffect>? fx,
  bool mage = false,
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
      classId: mage ? 'maga' : 'guerrero',
      weaponType: mage ? 'báculo' : 'espada',
      nextTurn: nextTurn,
      ult: ult,
      defending: defending,
      protecting: protecting,
      taunt: taunt,
      effects: fx,
    );

Combatant _foe(String id,
        {int hp = 1000,
        int? maxHp,
        int atk = 10,
        String type = 'slime',
        double breakBase = 0,
        bool fissured = false,
        double nextTurn = 50,
        Map<StatusKind, int>? st,
        Map<StatusKind, String>? primed,
        List<TimedEffect>? fx}) =>
    Combatant(
      id: id,
      name: 'Foe $id',
      isPlayer: false,
      hp: hp,
      maxHp: maxHp ?? hp,
      speed: 5,
      attack: atk,
      critChance: 0,
      enemyType: type,
      statuses: st,
      primedBy: primed,
      nextTurn: nextTurn,
      breakBase: breakBase,
      fissured: fissured,
      effects: fx,
    );

BattleState _battle(List<Combatant> party, List<Combatant> enemies,
        {String? current = 'p1'}) =>
    BattleState(party: party, enemies: enemies, currentId: current);

BattleStep _cmd(BattleEngine e, BattleState s, BattleCommand c,
        [String who = 'p1']) =>
    e.command(s, who, c)!;

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
SkillCommand _sk(String id, [String target = 'e0']) =>
    SkillCommand(id, targetId: target);

const _wet = {StatusKind.wet: 2};
const _charged = {StatusKind.charged: 1};

TimedEffect _mark() => const TimedEffect(
    sourceId: 'x', stat: BuffStat.damageTaken, value: 0.15, turns: 3);

TimedEffect _trap() => const TimedEffect(
    sourceId: 'x', stat: BuffStat.trap, value: 10, turns: 2, ownerId: 'p1');

/// Daño que hace un ataque (o [cmd]) de p1 a e0.
int _dmg(Set<String> mech,
    {Map<StatusKind, int>? st,
    String type = 'slime',
    bool fam = false,
    BattleCommand cmd = _atk,
    List<String> skills = const [],
    bool mage = false,
    double crit = 0,
    List<TimedEffect>? foeFx,
    List<TimedEffect>? heroFx}) {
  final s = _cmd(
      _engine(fam: fam),
      _battle([
        _hero(mech: mech, skills: skills, mage: mage, crit: crit, fx: heroFx)
      ], [
        _foe('e0', st: st, type: type, fx: foeFx),
      ]),
      cmd);
  return 1000 - _e(s).hp;
}

/// ¿El ataque de p1 a e0 sale crítico con la tirada 0.1?
bool _crits(Set<String> mech, {Map<StatusKind, int>? st}) {
  final s = _cmd(_engine(rolls: [0.1]),
      _battle([_hero(mech: mech)], [_foe('e0', st: st)]), _atk);
  return s.events.whereType<DamageEvent>().first.critical;
}

/// Barra de quiebre de e0 después de un ataque.
double _gauge(Set<String> mech, {Map<StatusKind, int>? st}) {
  final s = _cmd(_engine(),
      _battle([_hero(mech: mech)], [_foe('e0', breakBase: 999, st: st)]),
      _atk);
  return _e(s).breakGauge;
}

/// Vida que pierde p1 con un golpe de e0.
int _hurt(Set<String> mech, {bool defending = false}) {
  final s = _enemyHits(
      _engine(),
      _battle([_hero(mech: mech, defending: defending)], [_foe('e0', atk: 60)]));
  return 100 - _p(s).hp;
}

/// Reacción: p1 (maga) usa [skill] sobre e0 con [st].
BattleStep _react(Set<String> mech, Map<StatusKind, int> st, String skill,
        {int hp = 100, List<Combatant> more = const []}) =>
    _cmd(
        _engine(),
        _battle([
          _hero(mech: mech, skills: [skill], mage: true, hp: hp),
          ...more,
        ], [
          _foe('e0', st: st),
          _foe('e1'),
        ]),
        _sk(skill));

/// p2 detona sobre un estado que preparó p1 (dueño de [mech]).
BattleStep _primed(Set<String> mech) => _cmd(
    _engine(),
    _battle([
      _hero(mech: mech, skills: ['chispazo'], mage: true),
      _hero(id: 'p2', skills: ['chispazo'], mage: true, nextTurn: 5),
    ], [
      _foe('e0', st: _wet, primed: {StatusKind.wet: 'p1'}),
    ], current: 'p2'),
    _sk('chispazo'),
    'p2');

/// Un aliado (p2, provocando, 1 HP) cae por un golpe de e0.
BattleStep _allyDown(Set<String> mech, {int hp = 100}) => _enemyHits(
    _engine(),
    _battle([
      _hero(mech: mech, hp: hp),
      _hero(id: 'p2', hp: 1, taunt: 1),
    ], [
      _foe('e0')
    ]));

/// e0 golpea a p2, que está bajo la Protección de p1.
BattleStep _protect(Set<String> mech) => _enemyHits(
    _engine(),
    _battle([
      _hero(mech: mech, protecting: true, nextTurn: 10),
      _hero(id: 'p2'),
    ], [
      _foe('e0')
    ]));

/// p1 quiebra a e0 (Fisurado) con la Quebrar base (con p2 en el grupo;
/// combo_balance.md § 5).
BattleStep _break(Set<String> mech) => _cmd(
    _engine(),
    _battle([
      _hero(mech: mech, skills: ['quebrar']),
      _hero(id: 'p2', nextTurn: 50),
    ], [
      _foe('e0', breakBase: 10, fissured: true),
      _foe('e1'),
    ]),
    _sk('quebrar'));

/// p1 mata a e0 (1 HP) con un ataque; p2 a media vida.
BattleStep _kill(Set<String> mech,
        {Map<StatusKind, int>? st, int hp = 100, double crit = 0}) =>
    _cmd(
        _engine(),
        _battle([
          _hero(mech: mech, hp: hp, crit: crit),
          _hero(id: 'p2', hp: 50, nextTurn: 50),
        ], [
          _foe('e0', hp: 1, maxHp: 100, st: st),
          _foe('e1', hp: 500),
        ]),
        _atk);

/// p1 usa su ULT; p2 a media vida y lento.
BattleStep _ultStep(Set<String> mech) => _cmd(
    _engine(),
    _battle([
      _hero(mech: mech, ult: 100, hp: 50),
      _hero(id: 'p2', hp: 50, nextTurn: 50),
    ], [
      _foe('e0')
    ]),
    _ult);

/// Empieza el turno de e0 (estados y trampas) y actúa.
BattleStep _foeTurn(Set<String> mech, {Map<StatusKind, int>? st,
        List<TimedEffect>? fx, double roll = 0.99}) =>
    _engine(roll: roll).nextTurn(_battle([
      _hero(mech: mech, nextTurn: 50),
    ], [
      _foe('e0', st: st, fx: fx, nextTurn: 0),
    ], current: null));

/// p1 se cura con Cura; p2 a media vida y lento.
BattleStep _heal(Set<String> mech) => _cmd(
    _engine(),
    _battle([
      _hero(mech: mech, skills: ['cura'], hp: 40),
      _hero(id: 'p2', hp: 50, nextTurn: 50),
    ], [
      _foe('e0')
    ]),
    const SkillCommand('cura', targetId: 'p1'));

/// Empieza el turno de p1 (p2 a media vida).
BattleStep _turnStart(Set<String> mech) => _engine().nextTurn(_battle([
      _hero(mech: mech),
      _hero(id: 'p2', hp: 50, nextTurn: 30),
    ], [
      _foe('e0')
    ], current: null));

void main() {
  test('todas las mecánicas v6 existen, con nombre y texto', () {
    final inTree = {
      for (final n in kPassiveTree.nodes.values)
        if (n.mechanicId != null) n.mechanicId!,
    };
    expect(kTreeV6Mechanics, hasLength(96 + 16));
    for (final m in kTreeV6Mechanics) {
      expect(identical(kMechanics[m.id], m), isTrue, reason: m.id);
      expect(inTree, contains(m.id), reason: m.id);
      expect(m.effects, isNotEmpty, reason: m.id);
    }
    // Las keystones dicen su contra en el texto.
    for (final (k, _, _) in kTreeV6Drawbacks) {
      expect(kMechanics[k]!.description, contains('Pero'), reason: k);
    }
  });

  test('contras de las keystones v6 (aggregate)', () {
    final rules = PassiveTreeRules(kPassiveTree);
    for (final (k, stat, v) in kTreeV6Drawbacks) {
      final node = kPassiveTree.nodes.values.firstWhere((n) => n.keystoneId == k);
      final m = rules.aggregate('guerrero', PlayerPassiveProgress([node.id]));
      final base = rules.aggregate('guerrero', PlayerPassiveProgress.empty);
      expect(m.keys, {k});
      expect(m[stat] - base[stat], closeTo(v, 1e-9), reason: k);
      expect(m.mechanics, {k});
    }
  });

  group('nodos chicos', () {
    test('cada chico tiene su propia mecánica y dos iguales suman', () {
      final rules = PassiveTreeRules(kPassiveTree);
      final m = rules.aggregate(
          'maga', const PlayerPassiveProgress(['marea_s1', 'marea_s2']));
      expect(m.mechanics, {'marea_s1', 'marea_s2'});
      final one = _dmg({'marea_s1'}, st: _wet);
      final two = _dmg({'marea_s1', 'marea_s2'}, st: _wet);
      final none = _dmg({}, st: _wet);
      expect(one, closeTo(none * 1.06, 1));
      expect(two, closeTo(none * 1.12, 1));
    });

    test('daño, crítico y quiebre contra un estado', () {
      expect(_crits({'marea_ma'}, st: _wet), isFalse,
          reason: '4% no alcanza la tirada de 0.1');
      expect(
          _crits({'marea_ma', 'marea_mb', 'marea_ma2'}, st: _wet), isTrue);
      expect(_gauge({'forja_a1'}, st: {StatusKind.burn: 1}),
          greaterThan(_gauge({}, st: {StatusKind.burn: 1})));
      expect(_gauge({'voltio_s1'}, st: _charged),
          greaterThan(_gauge({}, st: _charged)));
      expect(_gauge({'forja_i1'}), greaterThan(_gauge({})));
    });

    test('familia, marca y 2+ elementos', () {
      expect(_dmg({'verdugo_ma'}, type: 'ojoAbismo', fam: true),
          greaterThan(_dmg({}, type: 'ojoAbismo', fam: true)));
      expect(_dmg({'monteria_ma'}, foeFx: [_mark()]),
          greaterThan(_dmg({}, foeFx: [_mark()])));
      const two = {StatusKind.burn: 1, StatusKind.poison: 1};
      expect(_dmg({'alquimia_ma'}, st: two), greaterThan(_dmg({}, st: two)));
    });

    test('crítico a un objetivo, área y reacción', () {
      expect(_dmg({'verdugo_s1'}, crit: 1), greaterThan(_dmg({}, crit: 1)));
      // Lluvia (×1.1): con el ×0.6 del área, Ráfaga redondea igual.
      expect(_dmg({'monzon_ma'}, cmd: _sk('lluvia'), skills: ['lluvia']),
          greaterThan(_dmg({}, cmd: _sk('lluvia'), skills: ['lluvia'])));
      int rx(Set<String> m) => 1000 - _e(_react(m, _wet, 'chispazo')).hp;
      expect(rx({'voltio_ma'}), greaterThan(rx({})));
    });

    test('defensa: defendiendo y aura de grupo', () {
      expect(_hurt({'pararrayos_s1'}, defending: true),
          lessThan(_hurt({}, defending: true)));
      expect(_hurt({'pararrayos_s1'}), _hurt({}),
          reason: 'sin defender no hace nada');
      expect(_hurt({'vanguardia_s1', 'vanguardia_s2', 'vanguardia_m1',
            'vanguardia_m2', 'santuario_e1', 'santuario_a1', 'santuario_a2'}),
          lessThan(_hurt({})));
    });

    test('aura de daño del grupo', () {
      final with4 = {'tactica_b1', 'tactica_b2', 'coro_b1', 'coro_b2'};
      expect(_dmg(with4), greaterThan(_dmg({})));
    });

    test('potencia de buffs, escudos, trampas, reflejo y curas que dañan', () {
      final a = _ultStep({'clamor', 'vanguardia_ma'});
      expect(_p(a).effectFrom('clamor', BuffStat.attack)!.value,
          closeTo(0.15 * 1.06, 1e-9));
      final s = _ultStep({'escudoCompartido', 'manantial_s1'});
      final b = _ultStep({'escudoCompartido'});
      expect(_p(s, 'p2').effectFrom('escudoCompartido', BuffStat.shield)!.value,
          greaterThan(
              _p(b, 'p2').effectFrom('escudoCompartido', BuffStat.shield)!.value));
      // La potencia de trampa se aplica al plantarla (Gran Cazador).
      double trap(Set<String> m) => _e(_cmd(_engine(),
              _battle([_hero(mech: {'granCazador', ...m})], [_foe('e0')]), _atk))
          .effectFrom('granCazador', BuffStat.trap)!
          .value;
      expect(trap({'monteria_s1'}), greaterThan(trap({})));
      int reflect(Set<String> m) => 1000 -
          _e(_enemyHits(
              _engine(),
              _battle([
                _hero(mech: {'puas', ...m}, fx: [
                  const TimedEffect(
                      sourceId: 'x',
                      stat: BuffStat.shield,
                      value: 50,
                      turns: 2,
                      ownerId: 'p1'),
                ])
              ], [
                _foe('e0')
              ]))).hp;
      expect(reflect({'pararrayos_ma'}), greaterThan(reflect({})));
      int burned(Set<String> m) => 300 -
          _e(_cmd(
                  _engine(fam: true),
                  _battle([
                    _hero(mech: m, skills: ['cura'], hp: 20)
                  ], [
                    _foe('e0', hp: 300, type: 'esqueleto')
                  ]),
                  const SkillCommand('cura')))
              .hp;
      expect(burned({'exorcismo_ma'}), greaterThan(burned({})));
    });

    test('Sagrado de los enemigos (aura) y stacks extra', () {
      int tick(Set<String> m) =>
          1000 - _e(_foeTurn(m, st: {StatusKind.holy: 4})).hp;
      expect(tick({'santuario_b1', 'santuario_b2'}), greaterThan(tick({})));
      final st = _cmd(
          _engine(roll: 0),
          _battle([
            _hero(mech: {'forja_b1'}, skills: ['bola'], mage: true)
          ], [
            _foe('e0')
          ]),
          _sk('bola'));
      expect(_e(st).stacks(StatusKind.burn), 3, reason: 'Bola 2 + 1');
    });
  });

  group('Guerrero', () {
    test('Decapitar (15%) y Verdugo (25%): rematan', () {
      final d = _dmg({});
      Combatant hit(Set<String> m, int left) => _e(_cmd(
          _engine(),
          _battle([_hero(mech: m)], [_foe('e0', hp: d + left, maxHp: 100)]),
          _atk));
      expect(hit({}, 10).hp, 10);
      expect(hit({'decapitar'}, 10).hp, 0);
      expect(hit({'decapitar'}, 20).hp, 20);
      expect(hit({'verdugo'}, 20).hp, 0);
    });

    test('Quiebrahuesos y Desguace: no muertos y constructos', () {
      for (final (m, type) in [
        ('quiebrahuesos', 'esqueleto'),
        ('desguace', 'golem'),
      ]) {
        expect(_dmg({m}, type: type, fam: true),
            closeTo(_dmg({}, type: type, fam: true) * 1.25, 1),
            reason: m);
        expect(_dmg({m}, fam: true), _dmg({}, fam: true), reason: m);
      }
    });

    test('Cosecha: al matar +20% ATQ 3 turnos', () {
      final fx = _p(_kill({'cosecha'})).effectFrom('cosecha', BuffStat.attack)!;
      expect((fx.value, fx.turns), (0.20, 3));
    });

    test('Ejecución Pública: al matar, grupo +10% daño 2 turnos', () {
      final st = _kill({'ejecucionPublica'});
      for (final id in ['p1', 'p2']) {
        final fx = _p(st, id).effectFrom('ejecucionPublica', BuffStat.damage)!;
        expect((fx.value, fx.turns), (0.10, 2), reason: id);
      }
    });

    test('Martillo Trueno: 25% de dejar Cargado', () {
      Combatant run(double roll) => _e(_cmd(_engine(roll: roll),
          _battle([_hero(mech: {'martilloTrueno'})], [_foe('e0')]), _atk));
      expect(run(0.1).stacks(StatusKind.charged), greaterThan(0));
      expect(run(0.99).stacks(StatusKind.charged), 0);
    });

    test('Resaca: Electrocución → +25% ATQ 2 turnos', () {
      final fx =
          _p(_react({'resaca'}, _wet, 'chispazo')).effectFrom('resaca', BuffStat.attack)!;
      expect((fx.value, fx.turns), (0.25, 2));
    });

    test('Trueno Sordo: +40% de quiebre a Cargados', () {
      expect(_gauge({'truenoSordo'}, st: _charged),
          closeTo(_gauge({}, st: _charged) * 1.4, 1e-6));
      expect(_gauge({'truenoSordo'}), _gauge({}));
    });

    test('Galerna: al quebrar, el quebrado queda Mojado', () {
      final st = _break({'galerna'});
      expect(_e(st).broken, isTrue);
      expect(_e(st).stacks(StatusKind.wet), greaterThan(0));
      expect(_e(_break({})).stacks(StatusKind.wet), 0);
    });

    test('Ojo de la Tormenta: 30% de aturdir a un Mojado', () {
      Combatant run(Map<StatusKind, int>? st) => _e(_cmd(_engine(roll: 0.1),
          _battle([_hero(mech: {'ojoTormenta'})], [_foe('e0', st: st)]),
          _atk));
      expect(run(_wet).stacks(StatusKind.stun), greaterThan(0));
      expect(run(null).stacks(StatusKind.stun), 0);
    });

    test('Dios del Trueno: cada golpe deja Cargado', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'diosTrueno'})], [_foe('e0')]), _atk);
      expect(_e(st).stacks(StatusKind.charged), greaterThan(0));
    });

    test('Toque de Clarín: la ULT adelanta a los aliados 25%', () {
      expect(_p(_ultStep({'toqueClarin'}), 'p2').nextTurn,
          lessThan(_p(_ultStep({}), 'p2').nextTurn));
    });

    test('Guardaespaldas: golpe absorbido por Protección → refleja 30%', () {
      final st = _protect({'guardaespaldas'});
      expect(_proc(st, 'guardaespaldas'), isTrue);
      expect(_e(st).hp, lessThan(1000));
    });

    test('Ánimo Inquebrantable: cae un aliado → grupo +20% ATQ 3 turnos', () {
      final st = _allyDown({'animoInquebrantable'});
      expect(_p(st, 'p2').alive, isFalse);
      final fx = _p(st).effectFrom('animoInquebrantable', BuffStat.attack)!;
      expect((fx.value, fx.turns), (0.20, 3));
    });

    test('Formación Cerrada: golpe defendiendo → escudo 8% al más herido', () {
      final st = _enemyHits(
          _engine(),
          _battle([_hero(mech: {'formacionCerrada'}, defending: true)],
              [_foe('e0')]));
      expect(_p(st).effectFrom('formacionCerrada', BuffStat.shield), isNotNull);
    });

    test('Grito de Victoria: al matar, +10 ULT a cada aliado', () {
      expect(_p(_kill({'gritoVictoria'}), 'p2').ult, 10);
    });

    test('Primera Línea: el grupo recibe −10%', () {
      expect(_hurt({'primeraLinea'}), lessThan(_hurt({})));
    });
  });

  group('Maga', () {
    test('Pleamar: mojar retrasa 10%', () {
      double next(Set<String> m) => _e(_cmd(
              _engine(),
              _battle([_hero(mech: m, skills: ['chorro'], mage: true)],
                  [_foe('e0')]),
              _sk('chorro')))
          .nextTurn;
      expect(next({'pleamar'}), greaterThan(next({})));
    });

    test('Marejada: Congelación súbita → +15 ULT y turno 20% antes', () {
      final st = _react({'marejada'}, _wet, 'lanzaH');
      expect(_proc(st, 'marejada'), isTrue);
      expect(_p(st).ult, greaterThanOrEqualTo(15));
      expect(_p(st).nextTurn, lessThan(_p(_react({}, _wet, 'lanzaH')).nextTurn));
    });

    test('Ahogo: +20% a Mojados', () {
      expect(_dmg({'ahogo'}, st: _wet), closeTo(_dmg({}, st: _wet) * 1.2, 1));
    });

    test('Vórtice: área a Mojados → −15% velocidad', () {
      final st = _cmd(
          _engine(),
          _battle([_hero(mech: {'vortice'}, skills: ['rafaga'])],
              [_foe('e0', st: _wet), _foe('e1')]),
          _sk('rafaga'));
      expect(_e(st).effectFrom('vortice', BuffStat.speed)!.value, -0.15);
      expect(_e(st, 1).effectFrom('vortice', BuffStat.speed), isNull);
    });

    test('Tsunami: mágica a uno Mojado salpica 30%', () {
      final st = _react({'tsunami'}, _wet, 'misil');
      expect(_e(st, 1).hp, lessThan(1000));
      expect(_e(_react({}, _wet, 'misil'), 1).hp, 1000);
    });

    test('Señora de las Mareas: cada golpe moja', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'senoraMareas'})], [_foe('e0')]), _atk);
      expect(_e(st).stacks(StatusKind.wet), greaterThan(0));
    });

    test('Arco Eléctrico: cargar rebota 35%', () {
      final st = _react({'arcoElectrico'}, const {}, 'chispazo');
      expect(_e(st, 1).hp, lessThan(1000));
    });

    test('Sobretensión: Electrocución → +15 ULT', () {
      expect(_p(_react({'sobretension'}, _wet, 'chispazo')).ult,
          greaterThanOrEqualTo(15));
      expect(_proc(_react({'sobretension'}, _wet, 'chispazo'), 'sobretension'),
          isTrue);
    });

    test('Campo Magnético: cargar → −15% ATQ', () {
      final st = _react({'campoMagnetico'}, const {}, 'chispazo');
      expect(_e(st).effectFrom('campoMagnetico', BuffStat.attack)!.value, -0.15);
    });

    test('Relámpago Globular: Cortocircuito → turno 30% antes', () {
      expect(_p(_react({'relampagoGlobular'}, _charged, 'chorro')).nextTurn,
          lessThan(_p(_react({}, _charged, 'chorro')).nextTurn));
    });

    test('Descarga en Cadena: crítico → Cargado', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'descargaCadena'}, crit: 1)], [_foe('e0')]),
          _atk);
      expect(_e(st).stacks(StatusKind.charged), greaterThan(0));
    });

    test('Corazón de Tormenta: mágica a uno carga y rebota 40%', () {
      final st = _react({'corazonTormenta'}, const {}, 'misil');
      expect(_e(st).stacks(StatusKind.charged), greaterThan(0));
      expect(_e(st, 1).hp, lessThan(1000));
    });

    test('Solvente: Derretir deja Mojado', () {
      final st = _react({'solvente'}, const {StatusKind.freeze: 2}, 'bola');
      expect(_e(st).stacks(StatusKind.wet), greaterThan(0));
    });

    test('Transmutación: Electrocución deja 2 Veneno', () {
      expect(_e(_react({'transmutacion'}, _wet, 'chispazo'))
          .stacks(StatusKind.poison), 2);
    });

    test('Precipitado: Explosión tóxica deja Congelación = mitad', () {
      expect(_e(_react({'precipitado'}, const {StatusKind.poison: 4}, 'bola'))
          .stacks(StatusKind.freeze), 2);
    });

    test('Reacción en Cadena: los estados restantes se esparcen', () {
      final st = _react({'reaccionCadena'},
          const {StatusKind.wet: 2, StatusKind.burn: 4}, 'chispazo');
      expect(_e(st, 1).stacks(StatusKind.burn), 2);
    });

    test('Piedra Filosofal: golpe que detona +20%', () {
      int rx(Set<String> m) => 1000 - _e(_react(m, _wet, 'chispazo')).hp;
      expect(rx({'piedraFilosofal'}), greaterThan(rx({})));
    });

    test('Gran Obra: aplicar un elemento suma el primero que falta', () {
      final st = _react({'granObra'}, const {}, 'bola');
      expect(_e(st).stacks(StatusKind.freeze) + _e(st).stacks(StatusKind.poison),
          greaterThan(0));
    });
  });

  group('Tirador', () {
    BattleStep area(Set<String> m, {Map<StatusKind, int>? st}) => _cmd(
        _engine(),
        _battle([
          _hero(mech: m, skills: ['rafaga']),
          _hero(id: 'p2', nextTurn: 50),
        ], [
          _foe('e0', st: st),
          _foe('e1'),
        ]),
        _sk('rafaga'));

    test('Aguanieve: área → +1 Congelación a Mojados', () {
      final st = area({'aguanieve'}, st: _wet);
      expect(_e(st).stacks(StatusKind.freeze), 1);
      expect(_e(st, 1).stacks(StatusKind.freeze), 0);
    });

    test('Remojón: detonan lo que preparaste → +12 ULT', () {
      expect(_p(_primed({'remojon'})).ult, 12);
    });

    test('Tormenta Tropical: área → grupo +10% crítico', () {
      final st = area({'tormentaTropical'});
      for (final id in ['p1', 'p2']) {
        expect(_p(st, id).effectFrom('tormentaTropical', BuffStat.crit)!.value,
            0.10, reason: id);
      }
    });

    test('Inundación: área marca a los Mojados', () {
      final st = area({'inundacion'}, st: _wet);
      expect(_e(st).effectFrom('inundacion', BuffStat.damageTaken)!.value, 0.12);
      expect(_e(st, 1).effectFrom('inundacion', BuffStat.damageTaken), isNull);
    });

    test('Ojo del Monzón: una reacción del grupo cura 3%', () {
      final st = _react({'ojoMonzon'}, _wet, 'chispazo', hp: 50);
      expect(_p(st).hp, 53);
    });

    test('Frente de Tormenta: área adelanta a los aliados', () {
      expect(_p(area({'frenteTormenta'}), 'p2').nextTurn,
          lessThan(_p(area({}), 'p2').nextTurn));
    });

    test('Flecha Imantada: crítico a uno → Cargado', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'flechaImantada'}, crit: 1)], [_foe('e0')]),
          _atk);
      expect(_e(st).stacks(StatusKind.charged), greaterThan(0));
    });

    test('Chispa Certera: +20% crítico a Cargados', () {
      expect(_crits({'chispaCertera'}, st: _charged), isTrue);
      expect(_crits({'chispaCertera'}), isFalse);
    });

    test('Electroshock: Electrocución marca +20%', () {
      expect(
          _e(_react({'electroshock'}, _wet, 'chispazo'))
              .effectFrom('electroshock', BuffStat.damageTaken)!
              .value,
          0.20);
    });

    test('Tensión Máxima: Electrocución → turno 30% antes', () {
      expect(_p(_react({'tensionMaxima'}, _wet, 'chispazo')).nextTurn,
          lessThan(_p(_react({}, _wet, 'chispazo')).nextTurn));
    });

    test('Trueno Final: muere un Cargado → pasa al de más vida', () {
      final st = _kill({'truenoFinal'}, st: _charged);
      expect(_e(st, 1).stacks(StatusKind.charged), greaterThan(0));
    });

    test('Tormenta Perfecta: Cargados +15% daño y +25% crítico', () {
      expect(_dmg({'tormentaPerfecta'}, st: _charged),
          closeTo(_dmg({}, st: _charged) * 1.15, 1));
      expect(_crits({'tormentaPerfecta'}, st: _charged), isTrue);
    });

    test('Lazo de Caza y Cepo: al saltar la trampa', () {
      BattleStep run(Set<String> m, {double roll = 0.99}) =>
          _foeTurn(m, fx: [_trap()], roll: roll);
      expect(
          _e(run({'lazoCaza'})).effectFrom('lazoCaza', BuffStat.damageTaken),
          isNotNull);
      expect(_proc(run({'cepo'}, roll: 0.1), 'cepo'), isTrue);
      expect(_proc(run({'cepo'}), 'cepo'), isFalse);
    });

    test('Cazador de Arácnidos y de Cienos', () {
      for (final (m, type) in [
        ('cazadorAracnidos', 'arana'),
        ('cazadorCienos', 'slime'),
      ]) {
        expect(_dmg({m}, type: type, fam: true),
            closeTo(_dmg({}, type: type, fam: true) * 1.25, 1),
            reason: m);
      }
    });

    test('Trofeo: al matar +10 ULT y 5% de vida', () {
      final st = _kill({'trofeo'}, hp: 50);
      expect(_p(st).ult, greaterThanOrEqualTo(10));
      expect(_p(st).hp, 55);
    });

    test('Gran Cazador: cada golpe a uno deja una trampa', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'granCazador'})], [_foe('e0')]), _atk);
      final trap = _e(st).effectFrom('granCazador', BuffStat.trap)!;
      expect((trap.value, trap.turns), (10.0, 2));
    });
  });

  group('Paladín', () {
    test('Exorcizar (espectros) y Destierro (no muertos)', () {
      expect(_dmg({'exorcizar'}, type: 'ghost', fam: true),
          closeTo(_dmg({}, type: 'ghost', fam: true) * 1.25, 1));
      expect(_dmg({'destierro'}, type: 'esqueleto', fam: true),
          closeTo(_dmg({}, type: 'esqueleto', fam: true) * 1.3, 1));
    });

    test('Consagración: golpe a uno con Sagrado → +1 Sagrado', () {
      final st = _cmd(
          _engine(),
          _battle([_hero(mech: {'consagracion'})],
              [_foe('e0', st: {StatusKind.holy: 1})]),
          _atk);
      expect(_e(st).stacks(StatusKind.holy), 2);
    });

    test('Cegar: golpe a uno con Sagrado → −15% ATQ', () {
      final st = _cmd(
          _engine(),
          _battle([_hero(mech: {'cegar'})],
              [_foe('e0', st: {StatusKind.holy: 1})]),
          _atk);
      expect(_e(st).effectFrom('cegar', BuffStat.attack)!.value, -0.15);
    });

    test('Juicio Final: muere uno con Sagrado → pasa al de más vida', () {
      final st = _kill({'juicioFinal'}, st: {StatusKind.holy: 2});
      expect(_e(st, 1).stacks(StatusKind.holy), 2);
    });

    test('Inquisidor: +30% a enemigos con Sagrado', () {
      const h = {StatusKind.holy: 1};
      expect(_dmg({'inquisidor'}, st: h), closeTo(_dmg({}, st: h) * 1.3, 1));
    });

    test('Agua Bendecida: curar → +4 ULT', () {
      expect(_p(_heal({'aguaBendecida'})).ult, greaterThanOrEqualTo(4));
      expect(_proc(_heal({'aguaBendecida'}), 'aguaBendecida'), isTrue);
    });

    test('Marea Sanadora: la ULT cura 10% al grupo', () {
      expect(_p(_ultStep({'mareaSanadora'}), 'p2').hp, 60);
    });

    test('Bautismo: cae un aliado → el grupo se cura 15%', () {
      expect(_p(_allyDown({'bautismo'}, hp: 50)).hp, 65);
    });

    test('Fuente de Vida: curar adelanta al más lento', () {
      expect(_p(_heal({'fuenteVida'}), 'p2').nextTurn,
          lessThan(_p(_heal({}), 'p2').nextTurn));
    });

    test('Desborde: curar cura 3% al grupo', () {
      expect(_p(_heal({'desborde'}), 'p2').hp, _p(_heal({}), 'p2').hp + 3);
    });

    test('Santo Patrono: al empezar tu turno el grupo se cura 5%', () {
      expect(_turnStart({'santoPatrono'}).state.party[1].hp, 55);
    });

    test('Pararrayos: el que te pega queda Cargado', () {
      final st = _enemyHits(
          _engine(), _battle([_hero(mech: {'pararrayos'})], [_foe('e0')]));
      expect(_e(st).stacks(StatusKind.charged), greaterThan(0));
    });

    test('Jaula de Faraday: golpe con poca vida → escudo 12%', () {
      final st = _enemyHits(_engine(),
          _battle([_hero(mech: {'jaulaFaraday'}, hp: 40)], [_foe('e0')]));
      expect(_p(st).effectFrom('jaulaFaraday', BuffStat.shield), isNotNull);
      final full = _enemyHits(_engine(),
          _battle([_hero(mech: {'jaulaFaraday'})], [_foe('e0')]));
      expect(_p(full).effectFrom('jaulaFaraday', BuffStat.shield), isNull);
    });

    test('Polo Opuesto: Protección → atacante Cargado y +4 ULT', () {
      final st = _protect({'poloOpuesto'});
      expect(_e(st).stacks(StatusKind.charged), greaterThan(0));
      expect(_p(st).ult, greaterThanOrEqualTo(4));
    });

    test('Retorno a Tierra: el que te pega −10% ATQ', () {
      final st = _enemyHits(
          _engine(), _battle([_hero(mech: {'retornoTierra'})], [_foe('e0')]));
      expect(_e(st).effectFrom('retornoTierra', BuffStat.attack)!.value, -0.10);
    });

    test('Tormenta Protectora: Provocar → escudo 8% al grupo', () {
      final st = _cmd(
          _engine(),
          _battle([
            _hero(mech: {'tormentaProtectora'}, skills: ['provocar']),
            _hero(id: 'p2', nextTurn: 50),
          ], [
            _foe('e0')
          ]),
          const SkillCommand('provocar'));
      for (final id in ['p1', 'p2']) {
        expect(_p(st, id).effectFrom('tormentaProtectora', BuffStat.shield),
            isNotNull, reason: id);
      }
    });

    test('Torre de Tormenta: refleja 40% y carga al atacante', () {
      final st = _enemyHits(
          _engine(), _battle([_hero(mech: {'torreTormenta'})], [_foe('e0')]));
      expect(_e(st).hp, lessThan(1000));
      expect(_e(st).stacks(StatusKind.charged), greaterThan(0));
    });
  });

  group('Puentes elementales', () {
    test('Temple: al quebrar → +2 Quemadura', () {
      expect(_e(_break({'temple'})).stacks(StatusKind.burn), 2);
    });

    test('Hierro al Rojo: +40% de quiebre a quemados', () {
      const b = {StatusKind.burn: 1};
      expect(_gauge({'hierroRojo'}, st: b), closeTo(_gauge({}, st: b) * 1.4, 1e-6));
    });

    test('Crisol: Derretir deja 3 Quemadura', () {
      const f = {StatusKind.freeze: 2};
      expect(_e(_react({'crisol'}, f, 'bola')).stacks(StatusKind.burn),
          _e(_react({}, f, 'bola')).stacks(StatusKind.burn) + 3);
    });

    test('Acero Fundido: +15% crítico a quemados', () {
      expect(_crits({'aceroFundido'}, st: {StatusKind.burn: 1}), isTrue);
      expect(_crits({'aceroFundido'}), isFalse);
    });

    test('Escoria: al quebrar → −20% ATQ', () {
      expect(_e(_break({'escoria'})).effectFrom('escoria', BuffStat.attack)!.value,
          -0.20);
    });

    test('Alma de Forja: quemados +25% daño y +50% quiebre', () {
      const b = {StatusKind.burn: 1};
      expect(_dmg({'almaForja'}, st: b), closeTo(_dmg({}, st: b) * 1.25, 1));
      expect(_gauge({'almaForja'}, st: b), greaterThan(_gauge({}, st: b) * 1.2));
    });

    test('Pila: Cortocircuito → +12 ULT', () {
      expect(_p(_react({'pila'}, _charged, 'chorro')).ult,
          greaterThanOrEqualTo(12));
    });

    test('Electrólisis: Electrocución deja Cargado', () {
      expect(_e(_react({'electrolisis'}, _wet, 'descarga'))
          .stacks(StatusKind.charged), greaterThan(0));
      expect(_e(_react({}, _wet, 'descarga')).stacks(StatusKind.charged), 0);
    });

    test('Circuito Cerrado: Cortocircuito deja Mojado', () {
      expect(_e(_react({'circuitoCerrado'}, _charged, 'torrente'))
          .stacks(StatusKind.wet), greaterThan(0));
      expect(_e(_react({}, _charged, 'torrente')).stacks(StatusKind.wet), 0);
    });

    test('Arco de Plasma: Cargados +15% daño', () {
      expect(_dmg({'arcoPlasma'}, st: _charged),
          closeTo(_dmg({}, st: _charged) * 1.15, 1));
    });

    test('Corriente Alterna: mojar → 30% de Cargado', () {
      Combatant run(double roll) => _e(_cmd(
          _engine(roll: roll),
          _battle([
            _hero(mech: {'corrienteAlterna'}, skills: ['chorro'], mage: true)
          ], [
            _foe('e0')
          ]),
          _sk('chorro')));
      expect(run(0.1).stacks(StatusKind.charged), greaterThan(0));
      expect(run(0.99).stacks(StatusKind.charged), 0);
    });

    test('Superconductor: golpe que detona +50%', () {
      int rx(Set<String> m) => 1000 - _e(_react(m, _wet, 'chispazo')).hp;
      expect(rx({'superconductor'}), greaterThan(rx({})));
    });

    test('Purga: muere un envenenado → el grupo se cura 4%', () {
      expect(_p(_kill({'purga'}, st: {StatusKind.poison: 1}), 'p2').hp, 54);
    });

    test('Sombra Sagrada: crítico → +2 Veneno', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'sombraSagrada'}, crit: 1)], [_foe('e0')]),
          _atk);
      expect(_e(st).stacks(StatusKind.poison), 2);
    });

    test('Penitencia: envenenar → +1 Sagrado', () {
      final st = _react({'penitencia'}, const {}, 'dardo');
      expect(_e(st).stacks(StatusKind.holy), 1);
    });

    test('Corrupción: golpe a uno con 5+ Veneno → sagrado MAG × 0.5', () {
      const p = {StatusKind.poison: 5};
      expect(_dmg({'corrupcion'}, st: p), _dmg({}, st: p) + 10);
    });

    test('Antídoto: al matar cura 8% al más herido', () {
      expect(_p(_kill({'antidoto'}), 'p2').hp, 58);
    });

    test('Crepúsculo: envenenados +20% daño', () {
      const p = {StatusKind.poison: 1};
      expect(_dmg({'crepusculo'}, st: p), closeTo(_dmg({}, st: p) * 1.2, 1));
    });

    test('Avalancha: golpe a uno con 3+ Congelación salpica 40%', () {
      final st = _cmd(
          _engine(),
          _battle([_hero(mech: {'avalancha'})],
              [_foe('e0', st: {StatusKind.freeze: 3}), _foe('e1')]),
          _atk);
      expect(_e(st, 1).hp, lessThan(1000));
    });

    test('Escarcha Viva: congelar → −15% ATQ', () {
      final st = _react({'escarchaViva'}, const {}, 'lanzaH');
      expect(_e(st).effectFrom('escarchaViva', BuffStat.attack)!.value, -0.15);
    });

    test('Glaciación: Congelación súbita → escudo 12%', () {
      expect(_p(_react({'glaciacion'}, _wet, 'lanzaH'))
          .effectFrom('glaciacion', BuffStat.shield), isNotNull);
    });

    test('Quebrar Témpanos: +15% crítico a congelados', () {
      expect(_crits({'quebrarTempanos'}, st: {StatusKind.freeze: 1}), isTrue);
    });

    test('Aliento Gélido: la ULT da −10% de daño recibido al grupo', () {
      final st = _ultStep({'alientoGelido'});
      for (final id in ['p1', 'p2']) {
        expect(_p(st, id).effectFrom('alientoGelido', BuffStat.guard)!.value,
            0.10, reason: id);
      }
    });

    test('Corazón Glaciar: el que te pega recibe 2 Congelación', () {
      final st = _enemyHits(
          _engine(), _battle([_hero(mech: {'corazonGlaciar'})], [_foe('e0')]));
      expect(_e(st).stacks(StatusKind.freeze), 2);
    });
  });

  group('Grupos exteriores (co-op)', () {
    test('Preparación: detonan lo tuyo → +15% daño (y el buff pega)', () {
      final fx = _p(_primed({'preparacion'})).effectFrom('preparacion', BuffStat.damage)!;
      expect((fx.value, fx.turns), (0.15, 2));
      expect(_dmg({}, heroFx: [fx]), closeTo(_dmg({}) * 1.15, 1));
    });

    test('Pinza: una reacción del grupo → +6 ULT', () {
      expect(_p(_primed({'pinza'})).ult, 6);
    });

    test('Fuego Cruzado: al quebrar lo marca', () {
      expect(_e(_break({'fuegoCruzado'}))
          .effectFrom('fuegoCruzado', BuffStat.damageTaken), isNotNull);
    });

    test('Golpe Maestro: detonan lo tuyo → grupo +10% daño', () {
      final st = _primed({'golpeMaestro'});
      for (final id in ['p1', 'p2']) {
        expect(_p(st, id).effectFrom('golpeMaestro', BuffStat.damage)!.value,
            0.10, reason: id);
      }
    });

    test('Himno: la ULT da +15% velocidad al grupo', () {
      expect(_p(_ultStep({'himno'}), 'p2').effectFrom('himno', BuffStat.speed)!
          .value, 0.15);
    });

    test('Contrapunto: al quebrar, grupo +10% crítico', () {
      expect(_p(_break({'contrapunto'}), 'p2')
          .effectFrom('contrapunto', BuffStat.crit)!.value, 0.10);
    });

    test('Canon: buffs de grupo 1 turno más', () {
      expect(_p(_ultStep({'clamor', 'canon'})).effectFrom('clamor', BuffStat.attack)!
          .turns, _p(_ultStep({'clamor'})).effectFrom('clamor', BuffStat.attack)!.turns + 1);
    });

    test('Crescendo: al empezar tu turno, +4 ULT a cada aliado', () {
      expect(_turnStart({'crescendo'}).state.party[1].ult, 4);
    });

    test('Altar: el Sagrado de los enemigos +25%', () {
      int tick(Set<String> m) =>
          1000 - _e(_foeTurn(m, st: {StatusKind.holy: 4})).hp;
      expect(tick({'altar'}), closeTo(tick({}) * 1.25, 1));
    });

    test('Oración Compartida: curar → escudo 5% al más herido', () {
      final st = _heal({'oracionCompartida'});
      expect(
          st.state.party.any((c) =>
              c.effectFrom('oracionCompartida', BuffStat.shield) != null),
          isTrue);
    });

    test('Último Rezo: cae un aliado → escudo 12%', () {
      expect(_p(_allyDown({'ultimoRezo'})).effectFrom('ultimoRezo', BuffStat.shield),
          isNotNull);
    });

    test('Santuario: al empezar tu turno el grupo se cura 2%', () {
      expect(_turnStart({'santuarioGrupal'}).state.party[1].hp, 52);
    });

    test('Rastrillo y Foso: golpe absorbido por Protección', () {
      expect(_p(_protect({'rastrillo'})).effectFrom('rastrillo', BuffStat.shield),
          isNotNull);
      expect(_e(_protect({'foso'})).nextTurn,
          greaterThan(_e(_protect({})).nextTurn));
    });

    test('Torre del Homenaje: golpe defendiendo → +4 ULT a los aliados', () {
      final st = _enemyHits(
          _engine(),
          _battle([
            _hero(mech: {'torreHomenaje'}, defending: true, taunt: 1),
            _hero(id: 'p2', nextTurn: 50),
          ], [
            _foe('e0')
          ]));
      expect(_p(st, 'p2').ult, greaterThanOrEqualTo(4));
    });

    test('Ciudadela: cae un aliado → −20% de daño 3 turnos', () {
      final fx = _p(_allyDown({'ciudadela'})).effectFrom('ciudadela', BuffStat.guard)!;
      expect((fx.value, fx.turns), (0.20, 3));
    });
  });
}
