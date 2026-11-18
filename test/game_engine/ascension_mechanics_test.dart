import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// Un escenario determinístico por nodo de impacto de cada ascensión y por
// habilidad / ULT del kit (docs/specs/ascension.md § 3-4). Combatientes
// armados a mano; el azar es una lista fija (0.99 al acabarse: nunca
// crítico ni probabilidad).

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

bool _proc(BattleStep s, String id) =>
    s.events.whereType<ProcEvent>().any((p) => p.sourceId == id);

Combatant _p(BattleStep s, [String id = 'p1']) => s.state.byId(id)!;

const _atk = AttackCommand(targetId: 'e0');

void main() {
  test('catálogo: 8 ascensiones, 2 por clase, 8 nodos con la forma del spec',
      () {
    expect(kAscensions.keys.toSet(), {
      'berserker', 'senorGuerra', 'cronomante', 'elementalista', //
      'francotirador', 'trampero', 'templario', 'guardian',
    });
    for (final c in kClasses.keys) {
      expect(ascensionsOf(c), hasLength(2), reason: c);
    }
    for (final a in kAscensions.values) {
      expect(a.nodes, hasLength(8), reason: a.id);
      expect(a.nodes.fold(0, (s, n) => s + n.cost), 10, reason: a.id);
      expect(a.node(a.rootId)!.cost, 0);
      // El Guardián tiene 3: el kit clásico del Paladín (ascension.md § 4).
      expect(a.skillIds, hasLength(a.id == 'guardian' ? 3 : 2), reason: a.id);
      expect(kAscensionUltimates[a.id]!.id, a.ultId);
      expect(a.spriteId, '${a.classId}_${a.id}');
      // Todos los nodos tienen mecánica salvo Sobrecarga (stats).
      for (final n in a.nodes) {
        expect(n.mechanicId != null || n.stats.isNotEmpty, isTrue,
            reason: n.id);
        expect(n.text, isNotEmpty, reason: n.id);
      }
    }
  });

  group('Berserker', () {
    test('Sed Roja: con < 50% de vida cada golpe da un turno parcial', () {
      final e = _engine();
      final low = _cmd(e, _battle([_hero(mech: {'berserker_r'}, hp: 40)], [_foe('e0')]), _atk);
      expect(_proc(low, 'berserker_r'), isTrue);
      expect(_p(low).nextTurn, closeTo(5, 1e-9));
      final high = _cmd(e, _battle([_hero(mech: {'berserker_r'}, hp: 60)], [_foe('e0')]), _atk);
      expect(_p(high).nextTurn, closeTo(10, 1e-9));
    });

    test('Furia Creciente: +0.8% de daño por 1% de vida que falta', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'berserker_a1'}, hp: 10)], [_foe('e0')]), _atk);
      expect(st.state.enemies.first.hp, 100 - 34); // 20 × 1.72
    });

    test('Golpe Desesperado: con < 30% de vida todo es crítico', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'berserker_a2'}, hp: 20)], [_foe('e0')]), _atk);
      expect(st.events.whereType<DamageEvent>().first.critical, isTrue);
      expect(st.state.enemies.first.hp, 70);
    });

    test('Carnicero: al matar, turno extra inmediato', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'berserker_a3'})], [_foe('e0', hp: 10), _foe('e1')]),
          _atk);
      expect(_p(st).nextTurn, 0);
      expect(_p(st).extraTurn, 1);
    });

    test('Sangre por Sangre: con < 50% roba 30% del daño', () {
      final st = _cmd(_engine(),
          _battle([_hero(mech: {'berserker_b1'}, hp: 40)], [_foe('e0')]), _atk);
      expect(_p(st).hp, 46);
    });

    test('Cicatrices: golpe recibido con < 50% → escudo 12% (1 turno)', () {
      final st = _enemyHits(_engine(),
          _battle([_hero(mech: {'berserker_b2'}, hp: 40)], [_foe('e0')]));
      expect(_p(st).hp, 30);
      expect(_p(st).effectFrom('berserker_b2', BuffStat.shield)!.value, 12);
    });

    test('Inmortal: el golpe mortal deja en 1 HP, una vez por batalla', () {
      final e = _engine();
      final st = _enemyHits(e, _battle([_hero(mech: {'berserker_b3'}, hp: 5)], [_foe('e0')]));
      expect(_p(st).hp, 1);
      expect(_p(st).once, contains('berserker_b3'));
      expect(_proc(st, 'berserker_b3'), isTrue);
      final again = _enemyHits(e, st.state);
      expect(_p(again).alive, isFalse);
    });

    test('Berserker Desatado: con < 50% cada golpe +15 de ULT', () {
      final e = _engine();
      final a = _cmd(e, _battle([_hero(hp: 40)], [_foe('e0')]), _atk);
      final b = _cmd(e, _battle([_hero(mech: {'berserker_k'}, hp: 40)], [_foe('e0')]), _atk);
      expect(_p(b).ult - _p(a).ult, closeTo(15, 1e-9));
    });
  });

  group('Señor de la Guerra', () {
    const grito = SkillCommand('gritoGuerra', targetId: 'e0');
    test('Grito de Guerra + Voz de Mando: grupo +25% ATQ y aliados 25% antes',
        () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'senorGuerra_r'}, skills: ['gritoGuerra']),
        _hero(id: 'p2', name: 'Bo', nextTurn: 50),
      ], [_foe('e0')]), grito);
      expect(_p(st, 'p2').nextTurn, closeTo(47.5, 1e-9));
      for (final id in ['p1', 'p2']) {
        expect(_p(st, id).effectFrom('gritoGuerra', BuffStat.attack)!.value, 0.25);
      }
      // Solo: el propio turno llega 25% antes.
      final solo = _cmd(_engine(),
          _battle([_hero(mech: {'senorGuerra_r'}, skills: ['gritoGuerra'])], [_foe('e0')]),
          grito);
      expect(_p(solo).nextTurn, closeTo(7.5, 1e-9));
    });

    test('Eco del Grito y Señor de la Guerra: +1 turno y 50% más fuerte', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'senorGuerra_a1', 'senorGuerra_k'}, skills: ['gritoGuerra']),
      ], [_foe('e0')]), grito);
      final fx = _p(st).effectFrom('gritoGuerra', BuffStat.attack)!;
      expect(fx.value, closeTo(0.375, 1e-9));
      expect(fx.turns, 4);
    });

    test('Inspiración: al empezar tu turno, aliados +6 de ULT', () {
      final st = _engine().nextTurn(_battle([
        _hero(mech: {'senorGuerra_a2'}),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0')], current: null));
      expect(st.state.currentId, 'p1');
      expect(_p(st, 'p2').ult, 6);
      expect(_p(st).ult, 0);
    });

    test('Estratega: cuando un aliado quiebra, todo el grupo +20% ATQ', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'senorGuerra_a3'}, nextTurn: 30),
        _hero(id: 'p2'),
      ], [_foe('e0', breakBase: 10)], current: 'p2'), _atk, 'p2');
      expect(st.state.enemies.first.broken, isTrue);
      for (final id in ['p1', 'p2']) {
        expect(_p(st, id).effectFrom('senorGuerra_a3', BuffStat.attack)!.value, 0.2);
      }
    });

    test('Bandera Firme: el grupo recibe −10% de daño', () {
      final s = _battle([_hero(mech: {'senorGuerra_b1'}), _hero(id: 'p2')],
          [_foe('e0', attack: 20)]);
      // El enemigo elige al primero vivo con 0.0.
      final st = _enemyHits(_engine([0.0]), s);
      expect(_p(st).hp, 82);
    });

    test('Muralla de Voces: los gritos dan escudo 8% a todos', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'senorGuerra_b2'}, skills: ['gritoGuerra']),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0')]), grito);
      expect(_p(st, 'p2').shield, 8);
      expect(_p(st).shield, 8);
    });

    test('Último Bastión: al caer un aliado, el resto +30% ATQ y −20% daño', () {
      final s = _battle([
        _hero(id: 'p2', hp: 5),
        _hero(mech: {'senorGuerra_b3'}),
      ], [_foe('e0', attack: 20)]);
      final st = _enemyHits(_engine([0.0]), s);
      expect(_p(st, 'p2').alive, isFalse);
      expect(_p(st).effectFrom('senorGuerra_b3', BuffStat.attack)!.value, 0.3);
      expect(_p(st).effectFrom('senorGuerra_b3', BuffStat.guard)!.value, 0.2);
    });
  });

  group('Cronomante', () {
    const grieta = SkillCommand('grietaTemporal', targetId: 'e0');
    Combatant mage(Set<String> mech) =>
        _hero(mech: mech, skills: ['grietaTemporal'], classId: 'maga');

    test('Bucle Temporal: retrasar adelanta al aliado más lento 30%', () {
      final st = _cmd(_engine(), _battle([
        mage({'cronomante_r'}),
        _hero(id: 'p2', nextTurn: 50),
        _hero(id: 'p3', nextTurn: 20),
      ], [_foe('e0')]), grieta);
      expect(_proc(st, 'cronomante_r'), isTrue);
      expect(_p(st, 'p2').nextTurn, closeTo(47, 1e-9));
      expect(_p(st, 'p3').nextTurn, 20);
      // Solo: el propio turno.
      final solo = _cmd(_engine(), _battle([mage({'cronomante_r'})], [_foe('e0')]), grieta);
      expect(_p(solo).nextTurn, closeTo(7, 1e-9));
    });

    test('Ecos del Reloj: retrasos 50% más largos', () {
      final base = _cmd(_engine(), _battle([mage({})], [_foe('e0')]), grieta);
      final up = _cmd(_engine(), _battle([mage({'cronomante_a1'})], [_foe('e0')]), grieta);
      expect(base.state.enemies.first.nextTurn, closeTo(66, 1e-9));
      expect(up.state.enemies.first.nextTurn, closeTo(74, 1e-9));
    });

    test('Ancla del Tiempo: retrasar quita 20 de carga de ULT enemiga', () {
      final st = _cmd(_engine(), _battle([mage({'cronomante_a2'})],
          [_foe('e0', ultId: 'eult_furia', ult: 50)]), grieta);
      // +30 por la vida que perdió (30%), −20 del Ancla.
      expect(st.state.enemies.first.ult, closeTo(60, 1e-9));
    });

    test('Tiempo Robado: retrasar adelanta tu turno 35%', () {
      final st = _cmd(_engine(), _battle([mage({'cronomante_a3'})], [_foe('e0')]), grieta);
      expect(_p(st).nextTurn, closeTo(6.5, 1e-9));
    });

    test('Sincronía: al empezar tu turno el más lento se adelanta 15%', () {
      final st = _engine().nextTurn(_battle([
        mage({'cronomante_b1'}),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0', nextTurn: 60)], current: null));
      expect(_p(st, 'p2').nextTurn, closeTo(48.5, 1e-9));
    });

    test('Contratiempo: al recibir un golpe el atacante se retrasa 30%', () {
      final st = _enemyHits(_engine(),
          _battle([mage({'cronomante_b2'})], [_foe('e0', nextTurn: 0)]));
      // reloj 0 + IV 20 + retraso 20 × 0.3.
      expect(st.state.enemies.first.nextTurn, closeTo(26, 1e-9));
    });

    test('Instante Eterno: al usar la ULT todos los aliados actúan ya', () {
      final st = _cmd(_engine(), _battle([
        _hero(
            mech: {'cronomante_b3'},
            ult: 100,
            classId: 'maga',
            build: _build('maga', 'cronomante')),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0')]), const UltimateCommand(targetId: 'e0'));
      expect(st.events.whereType<UltimateUsedEvent>().single.name,
          'Detener el Tiempo');
      expect(_p(st, 'p2').nextTurn, lessThanOrEqualTo(0.02));
    });

    test('Desfase: los retrasados reciben +20% de daño de todos', () {
      final st = _cmd(_engine(), _battle([mage({'cronomante_k'})], [_foe('e0')]), grieta);
      expect(st.state.enemies.first.effectTotal(BuffStat.damageTaken), 0.2);
    });
  });

  // v0.7: kit y mini-árbol de reacciones (ascension.md § 3 y § 4.1).
  group('Elementalista', () {
    Combatant mage(Set<String> mech, {List<String> skills = const []}) =>
        _hero(mech: mech, skills: skills, classId: 'maga');
    const wet = {StatusKind.wet: 2};
    int lost(BattleStep s, [int i = 0]) => 100 - s.state.enemies[i].hp;

    test('Catalizadora: tus reacciones pegan +25%', () {
      BattleStep run(Set<String> mech) => _cmd(_engine(), _battle(
          [mage(mech, skills: ['chispazo'])], [_foe('e0', st: wet)]),
          const SkillCommand('chispazo', targetId: 'e0'));
      final base = lost(run({}));
      expect(lost(run({'elementalista_r'})), closeTo(base * 1.25, 1));
      // Sin reacción no cambia.
      final plain = _cmd(_engine(), _battle(
          [mage({'elementalista_r'}, skills: ['chispazo'])], [_foe('e0')]),
          const SkillCommand('chispazo', targetId: 'e0'));
      final ctrl = _cmd(_engine(), _battle(
          [mage({}, skills: ['chispazo'])], [_foe('e0')]),
          const SkillCommand('chispazo', targetId: 'e0'));
      expect(lost(plain), lost(ctrl));
    });

    test('Conductora: mojar también deja Cargado', () {
      final st = _cmd(_engine(), _battle(
          [mage({'elementalista_a1'}, skills: ['chorro'])], [_foe('e0')]),
          const SkillCommand('chorro', targetId: 'e0'));
      final f = st.state.enemies.first;
      expect(f.stacks(StatusKind.wet), greaterThan(0));
      expect(f.stacks(StatusKind.charged), greaterThan(0));
    });

    test('Sobrecarga: +1 stack a los 3 elementos (stats)', () {
      final d = _stats.calculate(
          _build('maga', 'elementalista', nodes: ['elementalista_a1', 'elementalista_a2']));
      expect(d.statusBonus[StatusKind.burn], 1);
      expect(d.statusBonus[StatusKind.freeze], 1);
      expect(d.statusBonus[StatusKind.poison], 1);
      expect(d.mechanics, containsAll(['elementalista_r', 'elementalista_a1']));
    });

    test('Detonación en Cadena: detonar → 40% del golpe a los demás', () {
      final st = _cmd(_engine(), _battle(
          [mage({'elementalista_a3'}, skills: ['chispazo'])],
          [_foe('e0', st: wet), _foe('e1')]),
          const SkillCommand('chispazo', targetId: 'e0'));
      expect(lost(st, 1), (lost(st) * 0.4).round());
      expect(_proc(st, 'elementalista_a3'), isTrue);
    });

    test('Chispa Compartida: un aliado detona lo que preparaste → +12 ULT', () {
      double ult(Set<String> mech) => _p(_cmd(_engine(), _battle([
            mage(mech),
            _hero(id: 'p2', skills: ['chispazo'], nextTurn: 5),
          ], [
            Combatant(
              id: 'e0',
              name: 'Limo',
              isPlayer: false,
              hp: 100,
              maxHp: 100,
              speed: 5,
              attack: 10,
              critChance: 0,
              enemyType: 'slime',
              statuses: {...wet},
              primedBy: {StatusKind.wet: 'p1'},
              nextTurn: 50,
            ),
          ], current: 'p2'), const SkillCommand('chispazo', targetId: 'e0'),
              'p2'))
          .ult;
      expect(ult({'elementalista_b1'}) - ult({}), closeTo(12, 1e-9));
    });

    test('Estática: +25% de crítico contra Cargados', () {
      final hit = _cmd(_engine([0.2]), _battle([mage({'elementalista_b2'})], [
        _foe('e0', st: {StatusKind.charged: 1}),
      ]), _atk);
      expect(hit.events.whereType<DamageEvent>().first.critical, isTrue);
      final no = _cmd(_engine([0.2]), _battle([mage({'elementalista_b2'})], [
        _foe('e0'),
      ]), _atk);
      expect(no.events.whereType<DamageEvent>().first.critical, isFalse);
    });

    test('Eco Elemental: 35% de repetir una habilidad mágica', () {
      final st = _cmd(_engine([0.99, 0.1]), _battle(
          [mage({'elementalista_b3'}, skills: ['chispa'])], [_foe('e0')]),
          const SkillCommand('chispa', targetId: 'e0'));
      expect(_proc(st, 'elementalista_b3'), isTrue);
    });

    test('Tormenta Perfecta: detonar da 50% de turno extra', () {
      BattleStep run(List<double> rolls) => _cmd(_engine(rolls), _battle(
          [mage({'elementalista_k'}, skills: ['chispazo'])],
          [_foe('e0', hp: 999, st: wet)]),
          const SkillCommand('chispazo', targetId: 'e0'));
      expect(_proc(run([0.99, 0.1]), 'elementalista_k'), isTrue);
      expect(_proc(run([0.99, 0.9]), 'elementalista_k'), isFalse);
    });
  });

  group('Francotirador', () {
    test('Un Disparo, Una Baja: crítico a un objetivo × 2.25', () {
      final st = _cmd(_engine([0.0]),
          _battle([_hero(mech: {'francotirador_r'}, crit: 0.5)], [_foe('e0')]), _atk);
      expect(st.state.enemies.first.hp, 100 - 45);
    });

    test('Marca Letal y Tiro Seguro: marca y +40% de crítico al marcado', () {
      final st = _cmd(_engine(), _battle(
          [_hero(mech: {'francotirador_a1'})], [_foe('e0')]), _atk);
      expect(st.state.enemies.first.effectTotal(BuffStat.damageTaken), 0.15);
      final sure = _cmd(_engine([0.3]), _battle([_hero(mech: {'francotirador_a2'})], [
        _foe('e0', fx: [
          const TimedEffect(
              sourceId: 'x', stat: BuffStat.damageTaken, value: 0.15, turns: 3),
        ]),
      ]), _atk);
      expect(sure.events.whereType<DamageEvent>().first.critical, isTrue);
    });

    test('Ejecución: remata a los comunes por debajo de 20%, no a jefes', () {
      final st = _cmd(_engine(), _battle(
          [_hero(mech: {'francotirador_a3'}, attack: 10)],
          [_foe('e0', hp: 25), _foe('e1')]), _atk);
      expect(st.state.enemies.first.alive, isFalse);
      expect(_proc(st, 'francotirador_a3'), isTrue);
      final boss = _cmd(_engine(), _battle(
          [_hero(mech: {'francotirador_a3'}, attack: 10)],
          [_foe('e0', hp: 25, boss: true)]), _atk);
      expect(boss.state.enemies.first.hp, 15);
    });

    test('Recarga, Concentración, Perforante y Leyenda al hacer crítico', () {
      final st = _cmd(_engine([0.0]), _battle([
        _hero(mech: {
          'francotirador_b1',
          'francotirador_b2',
          'francotirador_b3',
          'francotirador_k',
        }, crit: 0.5),
      ], [_foe('e0'), _foe('e1')]), _atk);
      final p = _p(st);
      expect(p.nextTurn, closeTo(7, 1e-9)); // Concentración
      expect(st.state.enemies[1].hp, 100 - 23); // 30 × 0.75 perforado
      expect(p.effectFrom('francotirador_k', BuffStat.critMulti)!.value, 0.5);
      expect(_proc(st, 'francotirador_b1'), isTrue); // Recarga (+15)
    });
  });

  group('Trampero', () {
    test('Maestro de Trampas: el golpe deja una trampa que salta en su turno',
        () {
      final e = _engine();
      final st = _cmd(e, _battle([_hero(mech: {'trampero_r'})], [_foe('e0', nextTurn: 1)]), _atk);
      final trap = st.state.enemies.first.effectFrom('trampero_r', BuffStat.trap)!;
      expect(trap.value, 12);
      expect(trap.turns, 1);
      final next = e.nextTurn(st.state);
      expect(next.state.currentId, 'e0');
      expect(next.state.enemies.first.hp, 80 - 12);
      expect(next.events.whereType<DamageEvent>().last.sourceId, 'trampero_r');
    });

    test('Púas, Persistente, Detonador y Cazador Supremo', () {
      final e = _engine();
      final st = _cmd(e, _battle([
        _hero(mech: {
          'trampero_r',
          'trampero_a1',
          'trampero_a2',
          'trampero_a3',
          'trampero_k',
        }),
      ], [_foe('e0', nextTurn: 1), _foe('e1')]), _atk);
      final trap = st.state.enemies.first.effectFrom('trampero_r', BuffStat.trap)!;
      expect(trap.value, 22); // 20 × 0.6 × 1.8
      expect(trap.turns, 2);
      final next = e.nextTurn(st.state);
      final e0 = next.state.enemies.first;
      expect(e0.hp, 80 - 22);
      expect(e0.stacks(StatusKind.poison), 2);
      expect(next.state.enemies[1].hp, 100 - 11); // Detonador 50%
    });

    test('Lluvia Constante, Fragmentación y Campo de Muerte (área)', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'trampero_b1', 'trampero_b2', 'trampero_b3'}, skills: ['rafaga']),
      ], [_foe('e0'), _foe('e1')]), const SkillCommand('rafaga', targetId: 'e0'));
      for (final f in st.state.enemies) {
        expect(f.hp, 100 - 23); // 20 × 0.9 × 1.25
        expect(f.stacks(StatusKind.poison), 1);
        expect(f.effectFrom('trampero_b3', BuffStat.trap)!.value, 8);
      }
    });
  });

  group('Templario', () {
    test('Martillo de la Fe y Fervor: aturdir → sagrado MAG × 0.8, +1 S, ULT',
        () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'templario_r', 'templario_a2'}, stun: 1),
      ], [_foe('e0')]), _atk);
      final f = st.state.enemies.first;
      expect(f.stacks(StatusKind.stun), 1);
      expect(f.stacks(StatusKind.holy), 1);
      expect(f.hp, 100 - 20 - 16);
      expect(_proc(st, 'templario_a2'), isTrue);
    });

    test('Condena y Sentencia: +35% de daño y quiebre ×2 a aturdidos', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'templario_a1', 'templario_a3'}),
      ], [_foe('e0', breakBase: 100, st: {StatusKind.stun: 1})]), _atk);
      final f = st.state.enemies.first;
      expect(f.hp, 73);
      expect(f.breakGauge, closeTo(27 * 2, 1e-9));
    });

    test('Aura Sagrada: todo el grupo hace +10% de daño', () {
      final st = _cmd(_engine(), _battle([
        _hero(mech: {'templario_b1'}, nextTurn: 30),
        _hero(id: 'p2'),
      ], [_foe('e0')], current: 'p2'), _atk, 'p2');
      expect(st.state.enemies.first.hp, 78);
    });

    test('Penitencia: el atacante recibe 2 Sagrado', () {
      final st = _enemyHits(_engine(), _battle([_hero(mech: {'templario_b2'})], [_foe('e0')]));
      expect(st.state.enemies.first.stacks(StatusKind.holy), 2);
    });

    test('Ira Divina: el Sagrado enemigo hace el doble por turno', () {
      final s = _battle([_hero(mech: {'templario_b3'}, nextTurn: 30)],
          [_foe('e0', nextTurn: 1, st: {StatusKind.holy: 1})], current: null);
      final st = _engine().nextTurn(s);
      expect(st.state.enemies.first.hp, 90);
    });

    test('Avatar de Luz: la ULT cura 20% y da escudo al grupo', () {
      final st = _cmd(_engine(), _battle([
        _hero(
            mech: {'templario_k'},
            hp: 50,
            ult: 100,
            classId: 'paladin',
            build: _build('paladin', 'templario')),
      ], [_foe('e0')]), const UltimateCommand(targetId: 'e0'));
      expect(_p(st).hp, greaterThanOrEqualTo(70));
      expect(_p(st).shield, 10);
    });
  });

  group('Guardián', () {
    test('Escudo Viviente y Escudos Duraderos: el más herido gana 13', () {
      final st = _engine().nextTurn(_battle([
        _hero(mech: {'guardian_r', 'guardian_a2'}),
        _hero(id: 'p2', hp: 50, nextTurn: 40),
      ], [_foe('e0')], current: null));
      expect(_p(st, 'p2').shield, 13);
      expect(_p(st).shield, 0);
    });

    test('Égida Reflectante: lo absorbido vuelve 50% al atacante', () {
      final s = _battle([
        _hero(id: 'p2', nextTurn: 40)
          ..effects = [
            const TimedEffect(
                sourceId: 'guardian_r',
                stat: BuffStat.shield,
                value: 10,
                turns: 2,
                ownerId: 'p1'),
          ],
        _hero(mech: {'guardian_a1'}, nextTurn: 30),
      ], [_foe('e0', attack: 10)]);
      final st = _enemyHits(_engine([0.0]), s);
      expect(_p(st, 'p2').hp, 100);
      expect(st.state.enemies.first.hp, 95);
    });

    test('Bastión Inquebrantable: el grupo recibe −15%', () {
      final st = _enemyHits(_engine([0.0]), _battle([
        _hero(id: 'p2'),
        _hero(mech: {'guardian_a3'}),
      ], [_foe('e0', attack: 20)]));
      expect(_p(st, 'p2').hp, 83);
    });

    test('Represalia del Guardián: protegiendo devuelve 60%', () {
      final s = _battle([
        _hero(id: 'p2'),
        _hero(mech: {'guardian_b1'})..protecting = true,
      ], [_foe('e0', attack: 10)]);
      final st = _enemyHits(_engine([0.0]), s);
      expect(_p(st).hp, 90);
      expect(st.state.enemies.first.hp, 94);
    });

    test('Muralla Viviente: escudo 6% a todo el grupo', () {
      final st = _engine().nextTurn(_battle([
        _hero(mech: {'guardian_b2'}),
        _hero(id: 'p2', nextTurn: 40),
      ], [_foe('e0')], current: null));
      expect(_p(st).shield, 6);
      expect(_p(st, 'p2').shield, 6);
    });

    test('Mártir: el primer aliado que caería queda en 1 HP', () {
      final st = _enemyHits(_engine([0.0]), _battle([
        _hero(id: 'p2', hp: 5),
        _hero(mech: {'guardian_b3'}),
      ], [_foe('e0', attack: 10)]));
      expect(_p(st, 'p2').hp, 1);
      expect(_p(st).once, contains('guardian_b3'));
    });

    test('Juramento Eterno: el Guardián recibe 25% del daño de los aliados',
        () {
      final st = _enemyHits(_engine([0.0]), _battle([
        _hero(id: 'p2'),
        _hero(mech: {'guardian_k'}),
      ], [_foe('e0', attack: 20)]));
      expect(_p(st, 'p2').hp, 85);
      expect(_p(st).hp, 95);
    });
  });

  group('kit y ULT', () {
    test('ultimateOf: la de la ascensión reemplaza la del arma', () {
      final base = _hero(build: _build('guerrero', null));
      final asc = _hero(build: _build('guerrero', 'berserker'));
      expect(ultimateOf(base)!.id, 'ult_espada');
      expect(ultimateOf(asc)!.id, 'ult_berserker');
      // De otra clase: no vale.
      expect(ultimateOf(_hero(build: _build('guerrero', 'cronomante')))!.id,
          'ult_espada');
    });

    test('el kit entra a la batalla con la ascensión', () {
      final st = _engine().start(party: [
        BattlePartyMember(id: 'p1', name: 'Ana', build: _build('maga', 'cronomante')),
      ], enemyTypes: ['slime']);
      expect(st.state.party.single.skillIds,
          containsAll(['aceleron', 'grietaTemporal']));
      expect(st.state.party.single.mechanics, contains('cronomante_r'));
    });

    test('Sangría cuesta 10% de vida; Torbellino roba 30%', () {
      final s1 = _cmd(_engine(), _battle([_hero(skills: ['sangria'])], [_foe('e0')]),
          const SkillCommand('sangria', targetId: 'e0'));
      expect(_p(s1).hp, 90);
      expect(s1.state.enemies.first.hp, 100 - 48);
      final s2 = _cmd(_engine(), _battle([_hero(skills: ['torbellino'], hp: 50)],
          [_foe('e0'), _foe('e1')]), const SkillCommand('torbellino', targetId: 'e0'));
      expect(_p(s2).hp, 50 + 14); // 48 de daño × 0.3
    });

    test('Estandarte: grupo −25% de daño; Protección (Guardián): −20% propio',
        () {
      final st = _cmd(_engine(), _battle([
        _hero(skills: ['estandarte']),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0')]), const SkillCommand('estandarte', targetId: 'e0'));
      expect(_p(st, 'p2').effectTotal(BuffStat.guard), 0.25);
      final j = _cmd(_engine(), _battle([_hero(skills: ['proteccion'])], [_foe('e0')]),
          const SkillCommand('proteccion', targetId: 'e0'));
      expect(_p(j).protecting, isTrue);
      expect(_p(j).effectTotal(BuffStat.guard), 0.20);
      expect(_p(j).mp, 50 - 5);
    });

    test('Acelerón: aliados 40% antes', () {
      final st = _cmd(_engine(), _battle([
        _hero(skills: ['aceleron']),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0')]), const SkillCommand('aceleron', targetId: 'e0'));
      expect(_p(st, 'p2').nextTurn, closeTo(46, 1e-9));
    });

    // Elementalista v0.7 (ascension.md § 4.1): Prisma prepara, Detonar y
    // Trinidad son catalizadores.
    test('Prisma Elemental: deja Mojado y Cargado sin detonar', () {
      final st = _cmd(_engine(), _battle([_hero(skills: ['prismaElemental'])], [
        _foe('e0', st: {StatusKind.charged: 1}),
      ]), const SkillCommand('prismaElemental', targetId: 'e0'));
      final f = st.state.enemies.first;
      expect(st.events.whereType<ReactionEvent>(), isEmpty);
      expect(f.stacks(StatusKind.wet), greaterThan(0));
      expect(f.stacks(StatusKind.charged), greaterThan(0));
      expect(f.hp, 100 - 26); // 20 × 1.3
    });

    test('Detonar: detona lo que haya con el elemento justo, ×1.3', () {
      BattleStep run(Map<StatusKind, int>? st) => _cmd(_engine(),
          _battle([_hero(skills: ['detonar'])], [_foe('e0', hp: 999, st: st)]),
          const SkillCommand('detonar', targetId: 'e0'));
      // Sin nada: golpe neutro 20 × 1.5.
      final plain = run(null);
      expect(plain.events.whereType<ReactionEvent>(), isEmpty);
      expect(999 - plain.state.enemies.first.hp, 30);
      // Mojado → Electro: Electrocución ×1.5 × 1.3 y aturde.
      final wet = run({StatusKind.wet: 2});
      expect(wet.events.whereType<ReactionEvent>().single.kind,
          ReactionKind.electrocucion);
      expect(999 - wet.state.enemies.first.hp, 59); // 30 × 1.5 × 1.3
      expect(wet.state.enemies.first.stacks(StatusKind.stun), 1);
      // Veneno → Fuego: Explosión tóxica.
      final poi = run({StatusKind.poison: 2});
      expect(poi.events.whereType<ReactionEvent>().single.kind,
          ReactionKind.explosionToxica);
      // Congelación → Fuego (Derretir); Cargado → Agua (Cortocircuito).
      expect(
          run({StatusKind.freeze: 2})
              .events
              .whereType<ReactionEvent>()
              .single
              .kind,
          ReactionKind.derretir);
      expect(
          run({StatusKind.charged: 1})
              .events
              .whereType<ReactionEvent>()
              .single
              .kind,
          ReactionKind.cortocircuito);
    });

    test('Trinidad: detona lo que haya y deja Mojado, Cargado y 2 Veneno', () {
      final st = _cmd(_engine(), _battle([
        _hero(
            classId: 'maga',
            build: _build('maga', 'elementalista'),
            ult: 100),
      ], [
        _foe('e0', hp: 999, st: {StatusKind.wet: 2}),
        _foe('e1', hp: 999),
      ]), const UltimateCommand(targetId: 'e0'));
      expect(st.events.whereType<ReactionEvent>().single.kind,
          ReactionKind.electrocucion);
      for (final f in st.state.enemies) {
        expect(f.stacks(StatusKind.wet), greaterThan(0), reason: f.id);
        expect(f.stacks(StatusKind.charged), greaterThan(0), reason: f.id);
        expect(f.stacks(StatusKind.poison), 2, reason: f.id);
      }
    });

    test('Tiro a la Cabeza remata; Apuntar da crítico seguro', () {
      final st = _cmd(_engine(), _battle([_hero(skills: ['tiroCabeza'])],
          [_foe('e0', hp: 70), _foe('e1')]), const SkillCommand('tiroCabeza', targetId: 'e0'));
      expect(st.state.enemies.first.alive, isFalse);
      final e = _engine();
      var s = _cmd(e, _battle([_hero(skills: ['apuntar'])], [_foe('e0', nextTurn: 99)]),
          const SkillCommand('apuntar', targetId: 'e0')).state;
      expect(s.party.single.nextTurn, closeTo(5, 1e-9));
      s = e.nextTurn(s).state;
      final hit = _cmd(e, s, _atk);
      expect(hit.events.whereType<DamageEvent>().first.critical, isTrue);
    });

    test('Trampa de Púas: trampa en todos; Fortaleza (Guardián): escudos', () {
      final st = _cmd(_engine(), _battle([_hero(skills: ['trampaPuas'])],
          [_foe('e0'), _foe('e1')]), const SkillCommand('trampaPuas', targetId: 'e0'));
      for (final f in st.state.enemies) {
        expect(f.effectFrom('trampaPuas', BuffStat.trap)!.value, 20);
      }
      // Fortaleza sube la DEF (recalcula stats): necesita un build.
      final eg = _cmd(_engine(), _battle([
        _hero(skills: ['fortaleza'], classId: 'paladin', build: _build('paladin', 'guardian')),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0')]), const SkillCommand('fortaleza', targetId: 'e0'));
      expect(_p(eg, 'p2').shield, (_p(eg).maxHp * 0.15).round());
      expect(_p(eg, 'p2').effectTotal(BuffStat.guard), 0.10);
      expect(_p(eg).bonusDefense, 2);
    });

    test('ULT del Guardián: escudos, defensa y Protección sin daño', () {
      final st = _cmd(_engine(), _battle([
        _hero(ult: 100, classId: 'paladin', build: _build('paladin', 'guardian')),
        _hero(id: 'p2', nextTurn: 50),
      ], [_foe('e0')]), const UltimateCommand(targetId: 'e0'));
      expect(st.state.enemies.first.hp, 100);
      expect(_p(st, 'p2').shield, 25);
      expect(_p(st, 'p2').effectTotal(BuffStat.guard), 0.25);
      expect(_p(st).protecting, isTrue);
    });

    test('ULT del Berserker: roba 50%', () {
      final st = _cmd(_engine(), _battle([
        _hero(ult: 100, hp: 40, build: _build('guerrero', 'berserker')),
      ], [_foe('e0', hp: 500)]), const UltimateCommand(targetId: 'e0'));
      expect(st.events.whereType<UltimateUsedEvent>().single.name, 'Frenesí Carmesí');
      expect(_p(st).hp, 40 + 36); // 72 × 0.5
    });
  });
}
