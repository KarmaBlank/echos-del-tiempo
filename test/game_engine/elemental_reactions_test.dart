import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_patch.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_registries.dart';
import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/elemental_skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/elements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemy_families.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skill_variants_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:echos_del_tiempo/game_engine/data/summoner_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/battle_log_helper.dart';

// Elementos y reacciones v0.7 (docs/specs/elemental_reactions.md). Los
// combatientes se arman a mano; el azar es una lista fija (0.99 cuando se
// acaba: nunca crítico ni probabilidad).

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine(
    {List<double> rolls = const [],
    bool families = false,
    GameCatalog catalog = GameCatalog.standard}) {
  var i = 0;
  return BattleEngine(
      stats: _stats,
      catalog: catalog,
      random: () => i < rolls.length ? rolls[i++] : 0.99,
      familiesEnabled: families,
      breakEnabled: false);
}

Combatant _hero(
        {String id = 'p1',
        String name = 'Ana',
        List<String> skills = const [],
        int hp = 100,
        EnemyFamily? family,
        Map<StatusKind, int>? st}) =>
    Combatant(
      id: id,
      name: name,
      isPlayer: true,
      hp: hp,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: skills,
      classId: 'maga',
      weaponType: 'báculo',
      family: family,
      statuses: st,
    );

Combatant _foe(String id,
        {int hp = 500,
        String type = 'slime',
        bool boss = false,
        int attack = 10,
        StatusApplication? inflicts,
        Map<StatusKind, int>? st}) =>
    Combatant(
      id: id,
      name: 'Foe $id',
      isPlayer: false,
      hp: hp,
      maxHp: hp,
      speed: 5,
      attack: attack,
      critChance: 0,
      enemyType: type,
      boss: boss,
      inflicts: inflicts,
      statuses: st,
      nextTurn: 50,
    );

BattleStep _skill(BattleEngine e, BattleState s, String skill,
    {String target = 'e0', String who = 'p1'}) {
  s.currentId = who;
  return e.command(s, who, SkillCommand(skill, targetId: target))!;
}

List<ReactionEvent> _reactions(BattleStep s) =>
    s.events.whereType<ReactionEvent>().toList();

void main() {
  group('modelo', () {
    test('tabla de reacciones: 5 pares, el resto no reacciona', () {
      expect(reactionOf(StatusKind.wet, GameElement.electro),
          ReactionKind.electrocucion);
      expect(reactionOf(StatusKind.poison, GameElement.fuego),
          ReactionKind.explosionToxica);
      expect(reactionOf(StatusKind.wet, GameElement.hielo),
          ReactionKind.congelacionSubita);
      expect(reactionOf(StatusKind.freeze, GameElement.fuego),
          ReactionKind.derretir);
      expect(reactionOf(StatusKind.charged, GameElement.agua),
          ReactionKind.cortocircuito);
      // Pedido del dueño: fuego + agua, fuego + electro, hielo + electro...
      expect(reactionOf(StatusKind.burn, GameElement.agua), isNull);
      expect(reactionOf(StatusKind.wet, GameElement.fuego), isNull);
      expect(reactionOf(StatusKind.burn, GameElement.electro), isNull);
      expect(reactionOf(StatusKind.charged, GameElement.fuego), isNull);
      expect(reactionOf(StatusKind.freeze, GameElement.electro), isNull);
      expect(reactionOf(StatusKind.charged, GameElement.hielo), isNull);
      for (final k in ReactionKind.values) {
        expect(kReactions[k.name]!.kind, k);
        expect(k.sfxId, 'sfx.reaction.${k.name}');
      }
      expect(StatusKind.wet.iconId, 'status_wet');
      expect(StatusKind.charged.iconId, 'status_charged');
    });

    test('Quemadura y Veneno: tope de stacks del catálogo (30, v0.9)', () {
      expect(GameCatalog.standard.combo.stackCap, 30);
    });

    test('elementOf clasifica TODA habilidad, kit, variante y ULT', () {
      final ids = {
        ...kSkills.keys,
        for (final u in kAllUltimates.values) u.id,
        for (final u in kAscensionUltimates.values) u.id,
        for (final u in kSummonerUltimates.values) u.id,
      };
      for (final id in ids) {
        expect(kSkillElement, contains(id), reason: id);
      }
      expect(kSkillElement.keys.toSet().difference(ids), isEmpty);
      // El elemento coincide con el estado que aplica (salvo la luz).
      for (final id in kSkills.keys) {
        final st = kSkills[id]!.status;
        final el = st == null ? null : statusElement(st.kind);
        if (el == null || el == GameElement.sagrado) continue;
        if (elementOf(id) == GameElement.sagrado) continue; // Consagrar
        // Prisma Elemental prepara sin detonar (ascension.md § 4.1).
        if (id == 'prismaElemental') continue;
        expect(elementOf(id), el, reason: id);
      }
      expect(elementOf('bola'), GameElement.fuego);
      expect(elementOf('lanzaH'), GameElement.hielo);
      expect(elementOf('venenosa'), GameElement.veneno);
      expect(elementOf('consagrar'), GameElement.sagrado);
      expect(elementOf('rayoF'), GameElement.electro);
      expect(elementOf('prismaElemental'), GameElement.fisico);
      expect(elementOf('ult_elementalista'), GameElement.agua);
      expect(elementOf(null), GameElement.fisico);
      expect(elementOf('giro'), GameElement.fisico);
    });

    test('enemigos con elemento por zona (bestiary.md § 4)', () {
      expect(enemyAttackElement(kEnemies['sierpe'], kEnemies['sierpe']!.inflicts),
          GameElement.agua);
      expect(kEnemies['sierpe']!.inflicts!.kind, StatusKind.wet);
      expect(enemyUltElement(kEnemyUlts['eult_aliento']!), GameElement.hielo);
      expect(
          enemyAttackElement(
              kEnemies['bestiaMagma'], kEnemies['bestiaMagma']!.inflicts),
          GameElement.fuego);
      expect(enemyUltElement(kEnemyUlts['eult_erupcion']!), GameElement.fuego);
      expect(enemyAttackElement(kEnemies['centinela'], null), GameElement.electro);
      expect(kEnemies['centinela']!.inflicts!.kind, StatusKind.charged);
      expect(enemyUltElement(kEnemyUlts['eult_colapsoVacio']!), GameElement.agua);
      expect(enemyAttackElement(kEnemies['ojoAbismo'], null), GameElement.electro);
      expect(kEnemies['vigilanteVacio']!.inflicts!.kind, StatusKind.wet);
      expect(enemyAttackElement(kEnemies['bat'], null), GameElement.fisico);
    });
  });

  group('reacciones del grupo', () {
    test('Electrocución: ×1.5, aturde 1 turno y consume Mojado', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['chispazo'])
          ], enemies: [
            _foe('e0', st: {StatusKind.wet: 2})
          ]),
          'chispazo');
      final foe = s.state.enemies.single;
      expect(foe.hp, 500 - 45); // MAG 20 × 1.5 × 1.5
      expect(foe.stacks(StatusKind.wet), 0);
      expect(foe.stacks(StatusKind.stun), 1);
      expect(foe.stacks(StatusKind.charged), 1); // el golpe deja Cargado
      final r = _reactions(s).single;
      expect([r.kind, r.amount, r.consumedStacks, r.sourceId],
          [ReactionKind.electrocucion, 45, 2, 'p1']);
      expect(s.state.log, contains('ELECTROCUCIÓN'));
    });

    test('Explosión tóxica (Convergencia): 2.5% de vida máx. por stack, 30% a los demás', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['bola'])
          ], enemies: [
            _foe('e0', st: {StatusKind.poison: 3}),
            _foe('e1'),
            _foe('e2'),
          ]),
          'bola');
      final hp = s.state.enemies.map((e) => e.hp).toList();
      // Bola de Fuego 36; 3 × 2.5% de 500 = 37.5 → 38; salpica 30% = 11.
      expect(hp, [500 - 36 - 38, 500 - 11, 500 - 11]);
      expect(s.state.enemies.first.stacks(StatusKind.poison), 0);
      expect(s.state.enemies.first.stacks(StatusKind.burn), 2);
      final r = _reactions(s).single;
      expect([r.kind, r.amount, r.consumedStacks],
          [ReactionKind.explosionToxica, 38, 3]);
      expect(r.splash, {'e1': 11, 'e2': 11});
      final extra = s.events
          .whereType<DamageEvent>()
          .where((d) => d.sourceId == reactionSourceId(ReactionKind.explosionToxica));
      expect(extra, hasLength(3));

      // 12 Veneno = 30% de la vida máx. (no depende del golpe).
      final big = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['bola'])
          ], enemies: [
            _foe('e0', hp: 1000, st: {StatusKind.poison: 12}),
          ]),
          'bola');
      expect(_reactions(big).single.amount, 300);
    });

    test('Explosión tóxica contra un jefe: tope 40% de su vida máx.', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['bola'])
          ], enemies: [
            _foe('e0', hp: 400, boss: true, st: {StatusKind.poison: 20}),
          ]),
          'bola');
      final r = _reactions(s).single;
      expect(r.amount, 160); // 20 × 2.5% = 50% → 40% de 400
      // Tope absoluto de jefe por golpe (combat.md § "Límites"): 35% de
      // 400 = 140.
      expect(s.state.enemies.single.hp, 400 - 36 - 140);
      expect(s.state.log, contains('(tope)'));
    });

    test('Congelación súbita: Mojado + Hielo congela al instante', () {
      final e = _engine();
      final s = _skill(
          e,
          BattleState(party: [
            _hero(skills: ['lanzaH'])
          ], enemies: [
            _foe('e0', st: {StatusKind.wet: 2})
          ]),
          'lanzaH');
      final foe = s.state.enemies.single;
      expect(foe.stacks(StatusKind.freeze), 5);
      expect(foe.stacks(StatusKind.wet), 0);
      expect(_reactions(s).single.kind, ReactionKind.congelacionSubita);
      // Pierde su próximo turno.
      final next = e.nextTurn(s.state.copy()..party.single.nextTurn = 999);
      expect(next.events.whereType<TurnSkippedEvent>().single.cause,
          StatusKind.freeze);
    });

    test('Congelación súbita no entra con resistencia: no hay reacción', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['lanzaH'])
          ], enemies: [
            _foe('e0', st: {StatusKind.wet: 2})..freezeResist = 2
          ]),
          'lanzaH');
      expect(_reactions(s), isEmpty);
      expect(s.state.enemies.single.stacks(StatusKind.wet), 2);
      expect(s.state.enemies.single.stacks(StatusKind.freeze), 0);
    });

    test('Derretir: ×1.5 y quita la Congelación', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['bola'])
          ], enemies: [
            _foe('e0', st: {StatusKind.freeze: 3})
          ]),
          'bola');
      final foe = s.state.enemies.single;
      expect(foe.hp, 500 - 54); // 36 × 1.5
      expect(foe.stacks(StatusKind.freeze), 0);
      expect(_reactions(s).single.kind, ReactionKind.derretir);
    });

    test('Cortocircuito: salta a 1 más con 50% y le deja Mojado', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['chorro'])
          ], enemies: [
            _foe('e0', st: {StatusKind.charged: 1}),
            _foe('e1'),
            _foe('e2'),
          ]),
          'chorro');
      final hp = s.state.enemies.map((e) => e.hp).toList();
      expect(hp, [500 - 30, 500 - 15, 500]);
      expect(s.state.enemies[0].stacks(StatusKind.charged), 0);
      expect(s.state.enemies[0].stacks(StatusKind.wet), 2);
      expect(s.state.enemies[1].stacks(StatusKind.wet), 2);
      final r = _reactions(s).single;
      expect([r.kind, r.amount, r.splash],
          [ReactionKind.cortocircuito, 15, {'e1': 15}]);
    });

    test('pares sin reacción: no pasa nada', () {
      for (final (st, skill) in [
        (StatusKind.burn, 'chorro'), // fuego + agua
        (StatusKind.burn, 'chispazo'), // fuego + electro
        (StatusKind.freeze, 'chispazo'), // hielo + electro
        (StatusKind.charged, 'bola'), // electro + fuego
        (StatusKind.poison, 'chispazo'), // veneno + electro
      ]) {
        final s = _skill(
            _engine(),
            BattleState(party: [
              _hero(skills: [skill])
            ], enemies: [
              _foe('e0', st: {st: 2})
            ]),
            skill);
        expect(_reactions(s), isEmpty, reason: '$st + $skill');
      }
      // Un ataque físico no detona nada.
      final atk = _engine().command(
          BattleState(
              party: [_hero()],
              enemies: [
                _foe('e0', st: {StatusKind.wet: 2, StatusKind.poison: 3})
              ],
              currentId: 'p1'),
          'p1',
          const AttackCommand(targetId: 'e0'))!;
      expect(_reactions(atk), isEmpty);
      expect(atk.state.enemies.single.hp, 500 - 20);
    });

    test('una reacción por golpe (Veneno + Congelación + fuego)', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['bola'])
          ], enemies: [
            _foe('e0', st: {StatusKind.poison: 2, StatusKind.freeze: 3})
          ]),
          'bola');
      expect(_reactions(s).single.kind, ReactionKind.explosionToxica);
      expect(s.state.enemies.single.stacks(StatusKind.freeze), 3);
    });

    test('co-op: uno moja y otro electrocuta', () {
      final e = _engine();
      final s0 = BattleState(party: [
        _hero(skills: ['chorro']),
        _hero(id: 'p2', name: 'Leo', skills: ['chispazo']),
      ], enemies: [
        _foe('e0')
      ]);
      final a = _skill(e, s0, 'chorro');
      expect(a.state.enemies.single.stacks(StatusKind.wet), 2);
      final b = _skill(e, a.state, 'chispazo', who: 'p2');
      final r = _reactions(b).single;
      expect([r.kind, r.sourceId], [ReactionKind.electrocucion, 'p2']);
      expect(b.state.enemies.single.stacks(StatusKind.stun), 1);
    });

    test('Mojado dura 2 turnos propios y Cargado 1', () {
      final e = _engine();
      final s = BattleState(
          party: [_hero()..nextTurn = 999],
          enemies: [
            _foe('e0', st: {StatusKind.wet: 2, StatusKind.charged: 1})
              ..nextTurn = 1
          ]);
      final t1 = e.nextTurn(s).state;
      expect(t1.enemies.single.stacks(StatusKind.wet), 1);
      expect(t1.enemies.single.stacks(StatusKind.charged), 0);
    });

    test('los números salen del catálogo (admin de balance)', () {
      final patch = BalancePatch.fromJson({
        'overrides': {
          'reaction': {
            'electrocucion': {'damageMult': 2.0}
          }
        }
      }, BalanceBase.standard());
      expect(patch.hasErrors, isFalse, reason: '${patch.issues}');
      final cat = patch.patch.applyTo(GameCatalog.standard);
      expect(cat.reaction(ReactionKind.electrocucion).damageMult, 2.0);
      final s = _skill(
          _engine(catalog: cat),
          BattleState(party: [
            _hero(skills: ['chispazo'])
          ], enemies: [
            _foe('e0', st: {StatusKind.wet: 2})
          ]),
          'chispazo');
      expect(s.state.enemies.single.hp, 500 - 60);
      expect(BalanceKind.byJsonKey('elementStatus'), BalanceKind.elementStatus);
    });
  });

  group('reacciones de enemigos sobre jugadores (simétrico)', () {
    BattleStep enemyHit(List<Combatant> party, Combatant foe,
        {List<double> rolls = const [0.0], bool families = false}) {
      final s = BattleState(party: party, enemies: [foe], currentId: foe.id);
      return _engine(rolls: rolls, families: families).enemyTurn(s)!;
    }

    test('el Ojo del Abismo (Electro) electrocuta a un jugador mojado', () {
      final s = enemyHit([
        _hero(st: {StatusKind.wet: 2})
      ], _foe('e0', type: 'ojoAbismo'));
      final p = s.state.party.single;
      expect(p.hp, 100 - 15);
      // combat.md § "Control sobre jugadores": no stun on players.
      expect(p.stacks(StatusKind.stun), 0);
      expect(p.stacks(StatusKind.wet), 0);
      final r = _reactions(s).single;
      expect([r.kind, r.targetId, r.sourceId],
          [ReactionKind.electrocucion, 'p1', 'e0']);
    });

    test('la Sierpe (Agua) hace Cortocircuito a un Cargado y moja', () {
      final s = enemyHit([
        _hero(st: {StatusKind.charged: 1}),
        _hero(id: 'p2', name: 'Leo'),
      ], _foe('e0', type: 'sierpe', inflicts: const StatusApplication(StatusKind.wet, 1)));
      final hp = s.state.party.map((p) => p.hp).toList();
      expect(hp, [100 - 10, 100 - 5]);
      expect(s.state.party[0].stacks(StatusKind.wet), 2);
      expect(s.state.party[1].stacks(StatusKind.wet), 2);
      expect(_reactions(s).single.kind, ReactionKind.cortocircuito);
    });

    test('un golpe de fuego detona el Veneno de un jugador', () {
      final s = enemyHit([
        _hero(st: {StatusKind.poison: 4}),
        _hero(id: 'p2', name: 'Leo'),
      ], _foe('e0', type: 'salamandra', inflicts: const StatusApplication(StatusKind.burn, 2)));
      final hp = s.state.party.map((p) => p.hp).toList();
      // Convergencia: 4 × 2.5% de 100 = 10; salpica 30% = 3.
      expect(hp, [100 - 10 - 10, 100 - 3]);
      expect(s.state.party[0].stacks(StatusKind.poison), 0);
      expect(s.state.party[0].stacks(StatusKind.burn), 2);
      expect(_reactions(s).single.kind, ReactionKind.explosionToxica);
    });
  });

  group('hielo (§ 7)', () {
    test('Congelado → Quebradizo → golpe físico ×1.5 → resistencia 2', () {
      final e = _engine();
      var s = BattleState(
          party: [_hero(skills: ['lanzaH'])..nextTurn = 999],
          enemies: [
            _foe('e0', st: {StatusKind.freeze: 5})..nextTurn = 1
          ]);
      s = e.nextTurn(s).state;
      final foe = s.enemies.single;
      expect(foe.brittle, isTrue);
      expect(foe.stacks(StatusKind.freeze), 5);
      s.currentId = 'p1';
      final hit = e.command(s, 'p1', const AttackCommand(targetId: 'e0'))!;
      final f2 = hit.state.enemies.single;
      expect(f2.hp, 500 - 30); // ATQ 20 × 1.5
      expect(f2.brittle, isFalse);
      expect(f2.stacks(StatusKind.freeze), 0);
      expect(f2.freezeResist, 2);
      expect(hit.events.whereType<IceEvent>().single.phase, IcePhase.shattered);
      // Recién descongelado: resiste la Congelación.
      final again = _skill(e, hit.state, 'lanzaH');
      expect(again.state.enemies.single.stacks(StatusKind.freeze), 0);
      expect(again.events.whereType<IceEvent>().last.phase, IcePhase.resisted);
    });

    test('si nadie lo rompe, se descongela solo al turno siguiente', () {
      final e = _engine();
      final foe = _foe('e0', st: {StatusKind.freeze: 5})
        ..brittle = true
        ..nextTurn = 1;
      final s = e.nextTurn(
          BattleState(party: [_hero()..nextTurn = 999], enemies: [foe]));
      final f = s.state.enemies.single;
      expect(f.brittle, isFalse);
      expect(f.stacks(StatusKind.freeze), 0);
      expect(f.freezeResist, 2);
      expect(s.state.currentId, 'e0'); // esta vez juega
    });

    test('un golpe mágico a un Quebradizo no lo rompe', () {
      final s = _skill(
          _engine(),
          BattleState(party: [
            _hero(skills: ['chispazo'])
          ], enemies: [
            _foe('e0', st: {StatusKind.freeze: 5})..brittle = true
          ]),
          'chispazo');
      expect(s.state.enemies.single.brittle, isTrue);
      expect(s.state.enemies.single.hp, 500 - 30);
    });

    test('−6% de velocidad por stack', () {
      final e = _engine();
      final f = _foe('e0', st: {StatusKind.freeze: 3});
      expect(e.interval(f), closeTo(100 / (5 * 0.82), 1e-9));
    });
  });

  group('familia / raza simétrica (§ 5.3–5.4)', () {
    test('las curas dañan a un jugador no muerto', () {
      final e = _engine(families: true);
      final s = _skill(
          e,
          BattleState(party: [
            _hero(skills: ['cura'], hp: 50),
            _hero(id: 'p2', name: 'Zom', hp: 80, family: EnemyFamily.undead),
          ], enemies: [
            _foe('e0')
          ]),
          'cura');
      // Cura: MAG 20 × 1.5 + 6 = 36.
      expect(s.state.party[0].hp, 86);
      expect(s.state.party[1].hp, 80 - 36);
      expect(
          s.events
              .whereType<DamageEvent>()
              .where((d) => d.targetId == 'p2' && d.sourceId == kHealHarmSourceId),
          hasLength(1));
    });

    test('inmunidades y debilidades de la raza valen para el jugador', () {
      final s = BattleState(party: [
        _hero(family: EnemyFamily.undead),
      ], enemies: [
        _foe('e0',
            type: 'salamandra',
            inflicts: const StatusApplication(StatusKind.poison, 2))
      ], currentId: 'e0');
      final step = _engine(rolls: const [0.0], families: true).enemyTurn(s)!;
      final p = step.state.party.single;
      expect(p.stacks(StatusKind.poison), 0); // no muerto: inmune al Veneno
      // El golpe de la salamandra lleva el elemento de su estado (veneno:
      // sin tipo de familia) → sin debilidad.
      expect(p.hp, 90);
      // Con fuego, débil ×1.5 (combo_balance.md § 3.1).
      final fire = BattleState(party: [
        _hero(family: EnemyFamily.undead),
      ], enemies: [
        _foe('e0',
            type: 'salamandra',
            inflicts: const StatusApplication(StatusKind.burn, 1))
      ], currentId: 'e0');
      final f = _engine(rolls: const [0.0], families: true).enemyTurn(fire)!;
      expect(f.state.party.single.hp, 100 - 15); // 10 × 1.5
      expect(f.events.whereType<DamageEvent>().first.affinity, 1.5);
    });

    test('jugadores sin raza: family null; enemigos: la de su tipo', () {
      expect(_hero().family, isNull);
      expect(_foe('e0', type: 'esqueleto').family, EnemyFamily.undead);
    });
  });

  group('contenido Agua y Electro', () {
    test('cada habilidad nueva: en kSkills, con entrega, look y elemento', () {
      expect(kElementalSkills.length, greaterThanOrEqualTo(16));
      for (final e in kElementalSkills.entries) {
        expect(kSkills[e.key], same(e.value), reason: e.key);
        expect(kSkillDelivery, contains(e.key));
        expect(kSkills, contains(kSkillLooks[e.key]), reason: e.key);
        expect(kSkillVariants, isNot(contains(kSkillLooks[e.key])));
        expect([GameElement.agua, GameElement.electro], contains(elementOf(e.key)));
        final st = e.value.status;
        if (st != null) {
          expect(statusElement(st.kind), elementOf(e.key), reason: e.key);
        }
      }
      int count(GameElement el) =>
          kElementalSkills.keys.where((k) => elementOf(k) == el).length;
      expect(count(GameElement.agua), inInclusiveRange(8, 12));
      expect(count(GameElement.electro), inInclusiveRange(8, 12));
    });

    test('bases nuevas: ≤3 habilidades, entrega acorde al tipo, fórmulas', () {
      const ids = [
        'espada_coral', 'varita_voltaica', 'baculo_marea', 'lanza_mareas',
        'arco_relampago', 'dagas_electricas', 'tomo_tormentas',
        'hacha_tronante', 'tomo_mareas',
      ];
      final given = <String>{};
      for (final id in ids) {
        final w = kWeapons[id]!;
        expect(w.skillIds.length, inInclusiveRange(1, 3), reason: id);
        expect(w.price, 100 * w.level + 4 * w.level * w.level, reason: id);
        expect(w.level, inInclusiveRange(2, 50));
        final cat = kWeaponTypeCategory[w.type]!;
        for (final s in w.skillIds) {
          given.add(s);
          final d = kSkillDelivery[s]!;
          if (d == SkillDelivery.melee) {
            expect(cat, WeaponCategory.melee, reason: '$id $s');
          }
          if (d == SkillDelivery.ranged) {
            expect(cat, WeaponCategory.ranged, reason: '$id $s');
          }
        }
      }
      expect(given.containsAll(kElementalSkills.keys), isTrue);
    });
  });

  group('serialización y protocolo', () {
    test('ReactionEvent e IceEvent: ida y vuelta', () {
      const j = EventJson();
      const r = ReactionEvent('e0', ReactionKind.explosionToxica, 108,
          sourceId: 'p1', consumedStacks: 3, splash: {'e1': 54});
      final back = j.battleFromJson(j.battleToJson(r)) as ReactionEvent;
      expect([back.targetId, back.kind, back.amount, back.sourceId,
          back.consumedStacks, back.splash],
          ['e0', ReactionKind.explosionToxica, 108, 'p1', 3, {'e1': 54}]);
      expect(j.battleToJson(r)['k'], 'react');
      final ice = j.battleFromJson(
          j.battleToJson(const IceEvent('e0', IcePhase.shattered))) as IceEvent;
      expect([ice.targetId, ice.phase], ['e0', IcePhase.shattered]);
    });

    test('Combatant: Mojado, Cargado, Quebradizo, resistencia y raza', () {
      const sj = SessionJson();
      final c = _hero(
          family: EnemyFamily.undead,
          st: {StatusKind.wet: 2, StatusKind.charged: 1})
        ..brittle = true
        ..freezeResist = 2;
      final back = sj.combatantFromJson(sj.combatantToJson(c));
      expect(back.family, EnemyFamily.undead);
      expect(back.brittle, isTrue);
      expect(back.freezeResist, 2);
      expect(back.stacks(StatusKind.wet), 2);
      expect(back.stacks(StatusKind.charged), 1);
      final foe = sj.combatantFromJson(sj.combatantToJson(_foe('e0', type: 'esqueleto')));
      expect(foe.family, EnemyFamily.undead);
      expect(sj.combatantToJson(_foe('e0', type: 'esqueleto')), isNot(contains('fam')));
    });

    test('protocolo 8 o más', () => expect(kProtocolVersion, greaterThanOrEqualTo(8)));
  });
}
