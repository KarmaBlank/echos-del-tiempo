import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_registries.dart';
import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ascension_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/meal_buff.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/ascension_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// Ascension tree v2 (docs/specs/ascension.md § 3): shape, prereqs,
// capstone cap, migration, branch stats, Trades conditions and every new
// mechanic applied by the BattleEngine. Helpers as in
// ascension_mechanics_test.dart (fixed random list, 0.99 when it ends).

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  return BattleEngine(
      stats: _stats, random: () => i < rolls.length ? rolls[i++] : 0.99);
}

/// Un build con la ascensión [asc] (para el kit y la ULT).
PlayerBuild _build(String classId, String? asc, {List<String> nodes = const []}) =>
    PlayerBuild(
      classId: classId,
      level: 50,
      attributes: PlayerAttributes.base(kClasses[classId]!.baseAttributes),
      equippedWeapon: kWeapons[kClasses[classId]!.startWeaponId]!,
      ascension: AscensionProgress(
          trials: const {1, 2, 3}, id: asc, nodes: nodes),
    );

Combatant _hero({
  String id = 'p1',
  String name = 'Ana',
  Set<String> mech = const {},
  int attack = 20,
  int magic = 20,
  double crit = 0,
  int hp = 100,
  List<String> skills = const [],
  double stun = 0,
  double nextTurn = 0,
  double ult = 0,
  String classId = 'guerrero',
  PlayerBuild? build,
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
      skillIds: skills,
      classId: classId,
      weaponType: build?.equippedWeapon.type ?? 'espada',
      stunOnAttackChance: stun,
      nextTurn: nextTurn,
      ult: ult,
      build: build,
    );

Combatant _foe(String id,
        {int hp = 100,
        int attack = 10,
        bool boss = false,
        double nextTurn = 50,
        double breakBase = 0,
        bool fissured = false,
        String? ultId,
        double ult = 0,
        Map<StatusKind, int>? st,
        List<TimedEffect>? fx}) =>
    Combatant(
      id: id,
      name: 'Limo $id',
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
      breakBase: breakBase,
      fissured: fissured,
      ultId: ultId,
      ult: ult,
      effects: fx,
    );

BattleState _battle(List<Combatant> party, List<Combatant> enemies,
        {String? current = 'p1'}) =>
    BattleState(party: party, enemies: enemies, currentId: current);

BattleStep _cmd(BattleEngine e, BattleState s, BattleCommand c,
        [String who = 'p1']) =>
    e.command(s, who, c)!;

/// El enemigo `e0` ataca (tiene el turno).
BattleStep _enemyHits(BattleEngine e, BattleState s) {
  s.currentId = 'e0';
  return e.enemyTurn(s)!;
}

Combatant _p(BattleStep s, [String id = 'p1']) => s.state.byId(id)!;

const _atk = AttackCommand(targetId: 'e0');

// ---- Tree v2 (docs/specs/ascension.md § 3) ----

const _rules = AscensionRules();

PlayerProfile _prof(String classId, String asc,
        {Set<int> trials = const {1, 2, 3}, List<String> nodes = const []}) =>
    PlayerProfile(name: 'Ana', classId: classId, level: 50).copyWith(
        ascension:
            AscensionProgress(trials: trials, id: asc, nodes: nodes));

/// The ids of branch [b] tiers 1..[to] of [asc], in order.
List<String> _branch(String asc, int b, [int to = 10]) {
  final def = kAscensions[asc]!;
  return [
    for (var t = 1; t <= to; t++)
      def.nodes.firstWhere((n) => n.branch == b && n.tier == t).id,
  ];
}

DerivedStats _calc(PlayerBuild b) => _stats.calculate(b);

PlayerBuild _with(PlayerBuild b,
        {List<String>? nodes, MealBuff? meal, int mastery = 0,
        WeaponUpgradeLevels up = const WeaponUpgradeLevels()}) =>
    PlayerBuild(
      classId: b.classId,
      level: b.level,
      attributes: b.attributes,
      equippedWeapon: b.equippedWeapon,
      weaponUpgrades: up,
      ascension: b.ascension.copyWith(nodes: nodes),
      meal: meal,
      mastery: mastery,
    );

void main() {
  tearDown(BalanceRegistries.restore);

  test('shape: 51 nodes, 5 branches × 10 tiers, costs and kinds (§ 3.0)', () {
    for (final a in kAscensions.values) {
      expect(a.nodes, hasLength(51), reason: a.id);
      expect(a.nodes.map((n) => n.id).toSet(), hasLength(51), reason: a.id);
      expect(a.nodes.fold(0, (s, n) => s + n.cost), 75, reason: a.id);
      expect(branchesOf(a.id), hasLength(5));
      for (var b = 0; b < 5; b++) {
        final ids = _branch(a.id, b);
        expect(ids, hasLength(10));
        final nodes = [for (final id in ids) a.node(id)!];
        expect([for (final n in nodes) n.kind], [
          AscNodeKind.minor, AscNodeKind.minor, AscNodeKind.notable, //
          AscNodeKind.minor, AscNodeKind.minor, AscNodeKind.notable,
          AscNodeKind.minor, AscNodeKind.minor, AscNodeKind.major,
          AscNodeKind.capstone,
        ]);
        expect(nodes.first.links, contains(a.rootId));
        for (var t = 1; t < 10; t++) {
          expect(nodes[t].links, contains(nodes[t - 1].id));
          expect(nodes[t - 1].links, contains(nodes[t].id));
        }
      }
      for (final n in a.nodes) {
        if (n.mechanicId case final m?) {
          expect(kAscensionMechanics[m], isNotNull, reason: n.id);
        }
        // Every node gives something (mechanic, stats or a Trades bonus).
        expect(
            n.mechanicId != null ||
                n.stats.isNotEmpty ||
                n.condition == AscCondition.town,
            isTrue,
            reason: n.id);
      }
      // The v0.5 ids live on, at their new tiers.
      expect(a.node('${a.id}_a1')!.tier, 3);
      expect(a.node('${a.id}_b3')!.tier, 10);
      expect(a.node('${a.id}_k')!.capstone, isTrue);
    }
  });

  test('points: 7 per Trial (tunable), 21 with the three', () {
    expect(_rules.free(_prof('guerrero', 'berserker').ascension), 21);
    BalanceRegistries.install({
      BalanceKind.ascension: {
        'ascension': {'pointsPerTrial': 5}
      }
    });
    expect(_rules.free(_prof('guerrero', 'berserker').ascension), 15);
  });

  test('prereqs: top-down along the branch, no skipping (§ 3.0)', () {
    var p = _prof('guerrero', 'berserker');
    expect(_rules.cannotTake(p, 'berserker_m12'), 'No está conectado');
    expect(_rules.cannotTake(p, 'berserker_a1'), 'No está conectado');
    p = _rules.take(p, 'berserker_m11')!;
    p = _rules.take(p, 'berserker_m12')!;
    p = _rules.take(p, 'berserker_a1')!;
    expect(_rules.free(p.ascension), 21 - 4);
    // Other branches start at the root too.
    expect(_rules.cannotTake(p, 'berserker_e1'), 'No está conectado');
    expect(_rules.cannotTake(p, 'berserker_m41'), isNull);
  });

  test('capstones: only maxCapstones (1, tunable); sanitize drops extras',
      () {
    BalanceRegistries.install({
      BalanceKind.ascension: {
        'ascension': {'pointsPerTrial': 20}
      }
    });
    var p = _prof('guerrero', 'berserker');
    for (final id in _branch('berserker', 0)) {
      p = _rules.take(p, id)!;
    }
    for (final id in _branch('berserker', 1, 9)) {
      p = _rules.take(p, id)!;
    }
    expect(_rules.cannotTake(p, 'berserker_b3'), 'Ya tenés tu cúspide');
    final forged = AscensionProgress(
        trials: const {1, 2, 3},
        id: 'berserker',
        nodes: [..._branch('berserker', 0), ..._branch('berserker', 1)]);
    final clean = _rules.sanitize('guerrero', 50, forged);
    expect(clean.nodes, isNot(contains('berserker_b3')));
    expect(clean.nodes, contains('berserker_a3'));
  });

  test('migration: an old 8-node save gets every point back (§ 3.1b)', () {
    final old = AscensionProgress.fromJson({
      'tr': [1, 2, 3],
      'id': 'cronomante',
      'n': ['cronomante_a1', 'cronomante_a2', 'cronomante_k'],
    });
    expect(old.id, 'cronomante');
    expect(old.trials, {1, 2, 3});
    expect(old.nodes, isEmpty);
    expect(_rules.free(old), 21);
    // The new tree round-trips with its version.
    const now = AscensionProgress(
        trials: {1}, id: 'cronomante', nodes: ['cronomante_m11']);
    final json = now.toJson();
    expect(json['v'], AscensionProgress.treeVersion);
    expect(AscensionProgress.fromJson(json), now);
  });

  test('stats: minors and major add the tuned branch stat (§ 3.2)', () {
    final b = _build('guerrero', 'berserker');
    final base = _calc(b);
    final branch = _branch('berserker', 0, 9);
    final full = _calc(_with(b, nodes: branch));
    // 6 minors × 2% + the major 4% = +16% ATK (rounding aside).
    expect(full.attack / base.attack, closeTo(1.16, 0.07));
    expect(full.critChance, greaterThan(base.critChance));
    BalanceRegistries.install({
      BalanceKind.ascension: {
        'ascension': {'minorAtk': 0.1}
      }
    });
    expect(_calc(_with(b, nodes: ['berserker_m11'])).attack / base.attack,
        closeTo(1.1, 0.07));
  });

  test('Trades branch: each node only while its condition holds (§ 3.5)', () {
    // Big values so the integer rounding of the stats never hides them.
    BalanceRegistries.install({
      BalanceKind.ascension: {
        'ascension': {
          'minorHp': 0.5,
          'minorAtk': 0.5,
          'minorMag': 0.5,
          'townPerCondition': 0.5,
        }
      }
    });
    final b = _build('guerrero', 'berserker');
    final nodes = _branch('berserker', 4);
    final none = _calc(_with(b, nodes: nodes));
    final base = _calc(b);
    expect(none.maxHp, base.maxHp);
    expect(none.attack, base.attack);
    const meal = MealBuff('sopa_nabo', CropQuality.normal, 1);
    final fed = _calc(_with(b, nodes: ['berserker_of1'], meal: meal));
    final fedBase = _calc(_with(b, meal: meal));
    expect(fed.maxHp, greaterThan(fedBase.maxHp));
    // Forge: 3 upgrades (tunable `forgedLevel`).
    final f2 = _calc(_with(b,
        nodes: ['berserker_of1', 'berserker_of2'],
        up: const WeaponUpgradeLevels(pow: 3)));
    final f2Base = _calc(_with(b,
        nodes: ['berserker_of1'], up: const WeaponUpgradeLevels(pow: 3)));
    expect(f2.attack, greaterThan(f2Base.attack));
    expect(ascConditionTimes(AscCondition.forged,
        _with(b, up: const WeaponUpgradeLevels(pow: 2))), 0);
    // Echoes Mastery.
    expect(ascConditionTimes(AscCondition.mastery, _with(b, mastery: 5)), 1);
    expect(ascConditionTimes(AscCondition.mastery, _with(b, mastery: 4)), 0);
    // Heart of the Town counts the conditions that hold.
    expect(
        ascConditionTimes(
            AscCondition.town,
            _with(b,
                meal: meal,
                mastery: 9,
                up: const WeaponUpgradeLevels(pow: 3))),
        3);
    final heart = _calc(_with(b, nodes: nodes, meal: meal, mastery: 9));
    final heartBase = _calc(_with(b,
        nodes: nodes.where((n) => n != 'berserker_of10').toList(),
        meal: meal,
        mastery: 9));
    expect(heart.attack, greaterThan(heartBase.attack));
  });

  test('the build carries the Echoes Mastery over the wire', () {
    final b = _with(_build('guerrero', 'berserker'), mastery: 7);
    final json = const SessionJson().buildToJson(b);
    expect(json['ms'], 7);
    expect(const SessionJson().buildFromJson(json).mastery, 7);
  });

  group('new mechanics in BattleEngine (§ 3.3, 3.4)', () {
    test('Herida Que Ruge: hit below 50% → +8 ULT', () {
      double ult(Set<String> m) => _p(_enemyHits(_engine(),
              _battle([_hero(mech: m, hp: 40)], [_foe('e0')])))
          .ult;
      expect(ult({'berserker_c1'}) - ult({}), closeTo(8, 1e-9));
    });

    test('Sangre Hirviente: below 50% +15% damage', () {
      int lost(Set<String> m, int hp) => 100 -
          _cmd(_engine(), _battle([_hero(mech: m, hp: hp)], [_foe('e0')]),
                  _atk)
              .state
              .enemies
              .first
              .hp;
      expect(lost({'berserker_c2'}, 40), greaterThan(lost({}, 40)));
      expect(lost({'berserker_c2'}, 60), lost({}, 60));
    });

    test('Tambor de Guerra: shouts give allies +8 ULT', () {
      double ult(Set<String> m) => _p(
          _cmd(
              _engine(),
              _battle([
                _hero(mech: m, skills: ['gritoGuerra']),
                _hero(id: 'p2', name: 'Bo', nextTurn: 50),
              ], [_foe('e0')]),
              const SkillCommand('gritoGuerra', targetId: 'e0')),
          'p2').ult;
      expect(ult({'senorGuerra_c1'}) - ult({}), closeTo(8, 1e-9));
    });

    test('Orden de Avance: an ally break moves the party 15% sooner', () {
      double next(Set<String> m) => _p(
          _cmd(
              _engine(),
              _battle([
                _hero(mech: m, nextTurn: 30),
                _hero(id: 'p2', skills: ['quebrar']),
                _hero(id: 'p3', name: 'Cy', nextTurn: 40),
              ], [
                _foe('e0', breakBase: 10, fissured: true)
              ], current: 'p2'),
              const SkillCommand('quebrar', targetId: 'e0'),
              'p2'),
          'p3').nextTurn;
      expect(next({'senorGuerra_c2'}), lessThan(next({})));
    });

    test('Arena Que Cae: delaying → +6 ULT', () {
      double ult(Set<String> m) => _p(_cmd(
              _engine(),
              _battle([
                _hero(mech: m, skills: ['grietaTemporal'], classId: 'maga')
              ], [_foe('e0')]),
              const SkillCommand('grietaTemporal', targetId: 'e0')))
          .ult;
      expect(ult({'cronomante_c1'}) - ult({}), closeTo(6, 1e-9));
    });

    BattleStep ult(Set<String> m, String cls, String asc, {int hp = 100}) =>
        _cmd(
            _engine(),
            _battle([
              _hero(
                  mech: m,
                  hp: hp,
                  ult: 100,
                  classId: cls,
                  build: _build(cls, asc)),
              _hero(id: 'p2', name: 'Bo', hp: 50, nextTurn: 50),
            ], [
              _foe('e0', hp: 999)
            ]),
            const UltimateCommand(targetId: 'e0'));

    test('Segundo Prestado: ULT → own next turn 40% sooner', () {
      expect(_p(ult({'cronomante_c2'}, 'maga', 'cronomante')).nextTurn,
          lessThan(_p(ult({}, 'maga', 'cronomante')).nextTurn));
    });

    test('Misericordia: ULT heals the party 8%', () {
      expect(_p(ult({'templario_c2'}, 'paladin', 'templario'), 'p2').hp,
          greaterThan(_p(ult({}, 'paladin', 'templario'), 'p2').hp));
    });

    test('Lo Que Ya Fue Escrito: ULT → party sooner and +15% ATK', () {
      final st = ult({'berserker_e3'}, 'guerrero', 'berserker');
      expect(_p(st, 'p2').nextTurn,
          lessThan(_p(ult({}, 'guerrero', 'berserker'), 'p2').nextTurn));
      expect(_p(st, 'p2').effectFrom('berserker_e3', BuffStat.attack)?.value,
          closeTo(0.15, 1e-9));
    });

    const wet = {StatusKind.wet: 2};
    BattleStep react(Set<String> m) => _cmd(
        _engine(),
        _battle([
          _hero(mech: m, skills: ['chispazo'], classId: 'maga')
        ], [
          _foe('e0', hp: 999, st: wet)
        ]),
        const SkillCommand('chispazo', targetId: 'e0'));

    test('Afinidad: reaction → +8 ULT', () {
      expect(_p(react({'elementalista_c1'})).ult - _p(react({})).ult,
          closeTo(8, 1e-9));
    });

    test('Resonancia: a reaction gives +10% damage (2 turns)', () {
      expect(
          _p(react({'elementalista_c2'}))
              .effectFrom('elementalista_c2', BuffStat.damage)
              ?.value,
          closeTo(0.10, 1e-9));
    });

    test('Pulso Quieto / Vigilia / Eco Que Persiste: on turn start', () {
      BattleStep start(Set<String> m) => _engine().nextTurn(_battle(
          [_hero(mech: m)], [_foe('e0', nextTurn: 60)],
          current: null));
      expect(
          _p(start({'francotirador_c1'}))
              .effectFrom('francotirador_c1', BuffStat.crit)
              ?.value,
          closeTo(0.10, 1e-9));
      expect(_p(start({'templario_c1'})).ult, closeTo(5, 1e-9));
      expect(_p(start({'guardian_e1'})).ult, closeTo(4, 1e-9));
    });

    test('Ojo Paciente: +15% damage against marked enemies', () {
      int lost(Set<String> m) => 100 -
          _cmd(
                  _engine(),
                  _battle([
                    _hero(mech: m)
                  ], [
                    _foe('e0', fx: [
                      const TimedEffect(
                          sourceId: 'x',
                          stat: BuffStat.damageTaken,
                          value: 0.0,
                          turns: 2)
                    ])
                  ]),
                  _atk)
              .state
              .enemies
              .first
              .hp;
      expect(lost({'francotirador_c2'}), greaterThan(lost({})));
    });

    test('Cebo / Red Tensa: a sprung trap → ULT and the enemy delayed', () {
      BattleStep run(Set<String> m) {
        final e = _engine();
        final st = _cmd(
            e,
            _battle([
              _hero(mech: {'trampero_r', ...m})
            ], [
              _foe('e0', nextTurn: 1)
            ]),
            _atk);
        return e.nextTurn(st.state);
      }

      final base = run({});
      expect(_p(run({'trampero_c1'})).ult - _p(base).ult, closeTo(5, 1e-9));
      expect(run({'trampero_c2'}).state.enemies.first.nextTurn,
          greaterThan(base.state.enemies.first.nextTurn));
    });

    test('Centinela / Piedra Antigua: guarding and getting hit', () {
      double ult(Set<String> m) {
        final s = _battle([
          _hero(id: 'p2'),
          _hero(mech: m)..protecting = true,
        ], [
          _foe('e0', attack: 10)
        ]);
        return _p(_enemyHits(_engine([0.0]), s)).ult;
      }

      expect(ult({'guardian_c1'}) - ult({}), closeTo(8, 1e-9));
      final hit = _enemyHits(_engine(),
          _battle([_hero(mech: {'guardian_c2'})], [_foe('e0')]));
      expect(_p(hit).effectFrom('guardian_c2', BuffStat.shield)?.value, 6);
    });

    test('Paso Prestado: a kill moves your next turn 30% sooner', () {
      double next(Set<String> m) => _p(_cmd(
              _engine(),
              _battle([_hero(mech: m)], [_foe('e0', hp: 10), _foe('e1')]),
              _atk))
          .nextTurn;
      expect(next({'berserker_e2'}), closeTo(next({}) * 0.7, 1e-6));
    });

    test('a taken tree node reaches the engine as a mechanic', () {
      final b = _build('guerrero', 'berserker',
          nodes: _branch('berserker', 2, 3));
      expect(_calc(b).mechanics, contains('berserker_c1'));
    });
  });
}
