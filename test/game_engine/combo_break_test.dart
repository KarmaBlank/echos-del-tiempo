// Convergencias, área y quiebre por puntos (docs/specs/combo_balance.md
// § 4 y § 5, pasos 3-4). Los combatientes se arman a mano; el azar es fijo
// (0.99: nunca crítico ni probabilidad).

import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/data/affixes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemy_families.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/battle_log_helper.dart';

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine({bool families = false, bool breaks = false}) =>
    BattleEngine(
        stats: _stats,
        random: () => 0.99,
        familiesEnabled: families,
        breakEnabled: breaks);

Combatant _hero(
        {String id = 'p1',
        List<String> skills = const [],
        String weaponType = 'báculo',
        double ult = 0}) =>
    Combatant(
      id: id,
      name: id == 'p1' ? 'Ana' : 'Leo',
      isPlayer: true,
      // Pulso lleno: las pruebas de mecánicas no miden el Pulso.
      pulse: BattleEngine.pulseMax,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: skills,
      classId: 'maga',
      weaponType: weaponType,
      ult: ult,
    );

Combatant _foe(String id,
        {int hp = 500,
        String type = 'golem',
        bool boss = false,
        bool elite = false,
        double breakBase = 0,
        Map<StatusKind, int>? st,
        Map<StatusKind, String>? primedBy}) =>
    Combatant(
      id: id,
      name: 'Foe $id',
      isPlayer: false,
      hp: hp,
      maxHp: hp,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: type,
      boss: boss,
      elite: elite,
      breakBase: breakBase,
      statuses: st,
      primedBy: primedBy,
      nextTurn: 50,
    );

BattleStep _skill(BattleEngine e, BattleState s, String skill,
    {String who = 'p1'}) {
  s.currentId = who;
  return e.command(s, who, SkillCommand(skill, targetId: 'e0'))!;
}

ReactionEvent _rx(BattleStep s) => s.events.whereType<ReactionEvent>().single;

void main() {
  group('Convergencias (§ 4)', () {
    test('Combustión: Quemadura + golpe de Veneno, 2.5% por stack, 30% a '
        'los demás', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['dardo'])
          ], enemies: [
            _foe('e0', st: {StatusKind.burn: 10}),
            _foe('e1'),
          ]),
          'dardo');
      final r = _rx(s);
      // 10 × 2.5% de 500 = 125; salpica 30% = 37.5 → 38.
      expect([r.kind, r.amount, r.consumedStacks],
          [ReactionKind.combustion, 125, 10]);
      expect(r.splash, {'e1': 38});
      expect(s.state.enemies.first.stacks(StatusKind.burn), 0);
      expect(s.state.log, contains('¡COMBUSTIÓN! 10 Quemadura × 2.5% = 25%'));
      expect(reactionOf(StatusKind.burn, GameElement.veneno),
          ReactionKind.combustion);
      expect(ReactionKind.combustion.convergence, isTrue);
      expect(ReactionKind.electrocucion.convergence, isFalse);
    });

    test('topes por común (70%), élite (55%) y jefe (40%)', () {
      int amount({bool elite = false, bool boss = false}) => _rx(_skill(
              _engine(),
              BattleState(party: [
                _hero(skills: ['bola'])
              ], enemies: [
                _foe('e0',
                    hp: 1000,
                    elite: elite,
                    boss: boss,
                    st: {StatusKind.poison: 30}),
              ]),
              'bola'))
          .amount;
      // 30 × 2.5% = 75%.
      expect(amount(), 700);
      expect(amount(elite: true), 550);
      expect(amount(boss: true), 400);
    });

    test('× 1.25 si es débil al elemento que detona; inmune → 0', () {
      // Limo (ooze): débil al Fuego.
      final weak = _skill(
          _engine(families: true),
          BattleState(party: [
            _hero(skills: ['bola'])
          ], enemies: [
            _foe('e0', type: 'slime', st: {StatusKind.poison: 4}),
          ]),
          'bola');
      // 4 × 2.5% × 1.25 = 12.5% de 500.
      expect(_rx(weak).amount, 63);
      expect(weak.state.log, contains('× 1.25'));
      // Salamandra (elemental de fuego): inmune al Fuego.
      final immune = _skill(
          _engine(families: true),
          BattleState(party: [
            _hero(skills: ['bola'])
          ], enemies: [
            _foe('e0', type: 'salamandra', st: {StatusKind.poison: 4}),
          ]),
          'bola');
      expect(_rx(immune).amount, 0);
    });

    test('combo entre jugadores: +10 de ULT a quien preparó y a quien '
        'detonó', () {
      BattleStep run(String primer) => _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['bola']),
            _hero(id: 'p2'),
          ], enemies: [
            _foe('e0',
                st: {StatusKind.poison: 4},
                primedBy: {StatusKind.poison: primer}),
          ]),
          'bola');
      final duo = run('p2');
      final solo = run('p1');
      expect(duo.state.byId('p2')!.ult, 10);
      expect(solo.state.byId('p2')!.ult, 0);
      expect(duo.state.byId('p1')!.ult - solo.state.byId('p1')!.ult,
          closeTo(10, 1e-9));
      expect(duo.state.log, contains('+10 de ULT a los dos'));
    });

    test('Quemadura y Veneno: tope de 30 stacks por enemigo', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['dardo'])
          ], enemies: [
            _foe('e0', st: {StatusKind.poison: 29}),
          ]),
          'dardo');
      expect(s.state.enemies.single.stacks(StatusKind.poison), 30);
    });

    test('la Convergencia tiene Quebrar: quiebra a un Fisurado', () {
      final st = BattleState(party: [
        _hero(skills: ['bola'])
      ], enemies: [
        _foe('e0', breakBase: 20, st: {StatusKind.poison: 4})
          ..breakGauge = 20
          ..fissured = true,
      ]);
      final s = _skill(_engine(breaks: true), st, 'bola');
      expect(s.events.whereType<BreakEvent>().map((b) => b.phase),
          contains(BreakPhase.broken));
      expect(s.state.enemies.single.broken, isTrue);
    });
  });

  group('área (§ 4)', () {
    test('las habilidades a todos pegan × 0.6 por blanco, con su estado '
        'completo; las ULT no', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['llamarada'])
          ], enemies: [
            _foe('e0'),
            _foe('e1'),
          ]),
          'llamarada');
      // MAG 20 × 1.2 × 0.6 = 14.4.
      expect(s.state.enemies.map((e) => 500 - e.hp), [14, 14]);
      expect(s.state.log, contains('× 0.6 área'));
      expect(s.state.enemies.every((e) => e.stacks(StatusKind.burn) == 1),
          isTrue);
      // ULT a todos (Meteoro): sin el ×0.6.
      final u = _engine().command(
          BattleState(party: [
            _hero(ult: 100)
          ], enemies: [
            _foe('e0'),
            _foe('e1'),
          ], currentId: 'p1'),
          'p1',
          const UltimateCommand(targetId: 'e0'))!;
      expect(u.state.log, isNot(contains('área')));
    });
  });

  group('quiebre por puntos (§ 5)', () {
    test('reacción: +8 (Electrocución: habilidad 4 + reacción 8 + '
        'aturdido 6)', () {
      final s = _skill(
          _engine(breaks: true),
          BattleState(party: [
            _hero(skills: ['chispazo'])
          ], enemies: [
            _foe('e0', breakBase: 999, st: {StatusKind.wet: 2}),
          ]),
          'chispazo');
      expect(s.state.enemies.single.breakGauge, 4 + 8 + 6);
    });

    test('golpe a una debilidad: +50%', () {
      final s = _skill(
          _engine(families: true, breaks: true),
          BattleState(party: [
            _hero(skills: ['bola'])
          ], enemies: [
            _foe('e0', type: 'slime', breakBase: 999),
          ]),
          'bola');
      expect(s.state.enemies.single.breakGauge, 4 * 1.5);
    });

    test('armas pesadas +25%', () {
      final s = _engine(breaks: true).command(
          BattleState(party: [
            _hero(weaponType: 'hacha')
          ], enemies: [
            _foe('e0', breakBase: 999),
          ], currentId: 'p1'),
          'p1',
          const AttackCommand(targetId: 'e0'))!;
      expect(s.state.enemies.single.breakGauge, 5);
    });

    test('afijo Rompedor: +10% a +30% de puntos por tier', () {
      final r = kAffixes['rompedor']!;
      expect(r.stat, ModStat.breakPower);
      expect([r.tiers.first.min, r.tiers.last.max], [26, 12]);
      expect(r.tiers.map((t) => t.min).reduce((a, b) => a < b ? a : b), 10);
      final engine = BattleEngine(
          stats: _stats, random: () => 0.99, familiesEnabled: false);
      final cls = kClasses['guerrero']!;
      final start = engine.start(party: [
        BattlePartyMember(
          id: 'p1',
          name: 'G',
          build: PlayerBuild(
            classId: 'guerrero',
            level: 1,
            attributes: PlayerAttributes.base(cls.baseAttributes),
            equippedWeapon: kWeapons['espada_bronce']!,
            item: const ItemInstance(
                uid: 'w',
                baseId: 'espada_bronce',
                affixes: [AffixRoll('rompedor', 1, 30)]),
          ),
        ),
      ], enemyTypes: [
        'devorador'
      ], triggeredBy: 'p1');
      var s = start.state;
      s = engine.nextTurn(s).state;
      final step = engine.command(s, 'p1', const AttackCommand())!;
      expect(step.state.enemies.single.breakGauge, closeTo(4 * 1.3, 1e-9));
    });
  });

  group('tope por golpe: élite y jefe escalan con el grupo', () {
    test('jefe 25 / 22 / 18 / 15%, élite 45 → 35%, común 60%', () {
      const h = HitCapDef();
      final boss = [
        for (var n = 1; n <= 4; n++) h.fraction(elite: false, boss: true, partySize: n)
      ];
      expect(boss[0], closeTo(0.25, 1e-9));
      expect(boss[1], closeTo(0.2167, 1e-3));
      expect(boss[2], closeTo(0.1833, 1e-3));
      expect(boss[3], closeTo(0.15, 1e-9));
      expect(h.fraction(elite: true, boss: false), closeTo(0.45, 1e-9));
      expect(h.fraction(elite: true, boss: false, partySize: 4),
          closeTo(0.35, 1e-9));
      expect(h.fraction(elite: false, boss: false, partySize: 4), 0.60);
    });

    test('el motor usa el tamaño del grupo', () {
      int hit(int players) {
        final party = [
          for (var i = 1; i <= players; i++)
            _hero(id: 'p$i', skills: ['rayoArcano']),
        ];
        final s = _skill(
            BattleEngine(stats: _stats, random: () => 0.99),
            BattleState(party: party, enemies: [
              _foe('e0', hp: 100, boss: true, type: 'golem'),
            ]),
            'rayoArcano');
        return s.events.whereType<DamageEvent>().first.amount;
      }

      // Constructo: resiste lo mágico (× 0.5): MAG 20 × 2.2 × 0.5 = 22.
      expect(hit(1), 22); // tope 25
      expect(hit(4), 15); // tope 15
    });
  });

  group('red', () {
    test('Fisurado y Se recompone viajan en los eventos', () {
      const codec = EventJson();
      for (final ph in [BreakPhase.fissured, BreakPhase.steadied]) {
        final back = codec.battleFromJson(asJson(jsonDecode(jsonEncode(
            codec.battleToJson(BreakEvent('e0', ph, 10.8, 10.8))))));
        expect((back as BreakEvent).phase, ph);
      }
    });

    test('las reglas de combos se editan en el admin de balance', () {
      final codec = codecOf(BalanceKind.combo);
      const base = ComboRulesDef();
      final v = codec.read(base);
      expect(v['stackCap'], 30);
      final edited = codec.write(base,
          BalanceFieldReader({...v, 'areaMult': 0.8, 'breakUltimate': 20}))
          as ComboRulesDef;
      expect([edited.areaMult, edited.breakUltimate], [0.8, 20]);
      expect(GameCatalog.standard.combo.areaMult, 0.6);
      final cap = codecOf(BalanceKind.hitCap).read(const HitCapDef());
      expect([cap['bossSolo'], cap['boss']], [0.25, 0.15]);
    });
  });
}
