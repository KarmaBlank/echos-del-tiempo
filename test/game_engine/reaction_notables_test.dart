import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_migration.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Notables de reacción y de familia del árbol v5 (v0.7,
// docs/specs/passive_tree_v4.md § 8). Un escenario determinístico por
// notable; combatientes armados a mano, el azar es una lista fija (0.99
// al acabarse: nunca crítico ni probabilidad).

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTreeV6));

BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  return BattleEngine(
      stats: _stats,
      random: () => i < rolls.length ? rolls[i++] : 0.99,
      familiesEnabled: true);
}

Combatant _hero({
  String id = 'p1',
  Set<String> mech = const {},
  List<String> skills = const [],
  int hp = 100,
  double nextTurn = 0,
  double ult = 0,
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
      critChance: 0,
      mp: 50,
      maxMp: 50,
      mechanics: {...mech},
      skillIds: skills,
      classId: 'maga',
      weaponType: 'báculo',
      nextTurn: nextTurn,
      ult: ult,
    );

Combatant _foe(String id,
        {int hp = 300,
        String type = 'slime',
        bool boss = false,
        Map<StatusKind, int>? st,
        Map<StatusKind, String>? primed}) =>
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
      statuses: st,
      primedBy: primed,
      nextTurn: 50,
    );

BattleStep _run(BattleEngine e, List<Combatant> party, List<Combatant> foes,
    BattleCommand c,
    [String who = 'p1']) {
  final s = BattleState(party: party, enemies: foes, currentId: who);
  return e.command(s, who, c)!;
}

SkillCommand _sk(String id, [String target = 'e0']) =>
    SkillCommand(id, targetId: target);

bool _proc(BattleStep s, String id) =>
    s.events.whereType<ProcEvent>().any((p) => p.sourceId == id);

List<ReactionEvent> _reactions(BattleStep s) =>
    s.events.whereType<ReactionEvent>().toList();

Combatant _e(BattleStep s, [int i = 0]) => s.state.enemies[i];
Combatant _p(BattleStep s, [String id = 'p1']) => s.state.byId(id)!;

const _wet = {StatusKind.wet: 2};

void main() {
  test('catálogo: 15 nodos cambiados, cada uno con su mecánica nueva', () {
    const expected = {
      'arcano_n1': 'saltoVoltaico',
      'brasa_n1': 'fundicion',
      'brasa_nc': 'mechaCorta',
      'escarcha_nc': 'cristalizar',
      'prisma_n1': 'rocioArcano',
      'prisma_nc': 'altoVoltaje',
      'cronos_nc': 'estasis',
      'toxina_nc': 'reguero',
      'lluvia_nc': 'chaparron',
      'runas_nr': 'pulsoRunico',
      'hojaArcana_nl': 'hojaMarea',
      'estandarte_nt': 'comboEquipo',
      'sintonia_nt': 'sincroniaElemental',
      'luz_nc': 'luzPurificadora',
      'acecho_nc': 'cazadorBestias',
    };
    expect(kPassiveTreeVersion, 6);
    expect(kTreeIdsChangedInV5, expected.keys.toSet());
    for (final MapEntry(key: node, value: mech) in expected.entries) {
      final n = kPassiveTreeV6.nodes[node]!;
      expect(n.kind, 'n', reason: node);
      expect(n.mechanicId, mech, reason: node);
      final m = kMechanics[mech]!;
      expect(m.name, n.name, reason: node);
      expect(m.description, isNotEmpty, reason: node);
      expect(kTreeIdsStableSinceV3.contains(node), isFalse, reason: node);
    }
    // Los reemplazados ya no existen.
    for (final old in [
      'canalizar', 'ascuasVivas', 'pira', 'hieloQuebradizo', //
      'chispaPrismatica', 'descomposicion', 'anclaTemporal', 'nubeToxica',
      'granizo', 'disparoRunico', 'hechizoAfilado', 'estandarteAlzado',
      'resonanciaGrupal', 'estallidoSolar', 'caceria',
    ]) {
      expect(kMechanics[old], isNull, reason: old);
    }
  });

  test('migración v4 → árbol v7: se devuelve todo (progresión v2)', () {
    final kept = migrateTreeIds(
        'maga',
        [
          'mag_r1', 'mag_f2', 'brasa_n1', 'brasa_m1', 'mag_f3', //
          'cronos_n1', 'cronos_m1',
        ],
        4);

    expect(kept, isEmpty);
    final p = PlayerProfile.fromJson({
      'name': 'Ana',
      'cls': 'maga',
      'lvl': 30,
      'tv': 4,
      'tree': ['mag_r1', 'mag_f2', 'mag_f1', 'arcano_n1', 'arcano_m1'],
    });
    expect(p.tree, isEmpty);
    expect(p.treeRefunded, 5);
    expect(p.toJson()['tv'], 6);
  });

  test('quién preparó: se guarda al aplicar y viaja en el JSON', () {
    final st = _run(_engine(), [_hero(skills: ['chorro'])], [_foe('e0')],
        _sk('chorro'));
    expect(_e(st).primedBy, {StatusKind.wet: 'p1'});
    const sj = SessionJson();
    final back =
        sj.battleStateFromJson(sj.battleStateToJson(st.state)).enemies.first;
    expect(back.primedBy, {StatusKind.wet: 'p1'});
    // La reacción lo consume.
    final det = _run(_engine(), [_hero(skills: ['chispazo'])],
        [_foe('e0', st: _wet, primed: {StatusKind.wet: 'p1'})],
        _sk('chispazo'));
    expect(_e(det).primedBy.containsKey(StatusKind.wet), isFalse);
  });

  group('Maga', () {
    test('Salto Voltaico: el Cortocircuito salta a 1 más', () {
      BattleStep run(Set<String> mech) => _run(
          _engine(),
          [_hero(mech: mech, skills: ['chorro'])],
          [
            _foe('e0', st: {StatusKind.charged: 1}),
            _foe('e1'),
            _foe('e2'),
          ],
          _sk('chorro'));
      final off = run({});
      expect(_e(off, 2).hp, 300);
      final on = run({'saltoVoltaico'});
      final jump = 300 - _e(on, 1).hp;
      expect(jump, greaterThan(0));
      expect(300 - _e(on, 2).hp, jump);
      expect(_e(on, 2).stacks(StatusKind.wet), greaterThan(0));
      expect(_proc(on, 'saltoVoltaico'), isTrue);
    });

    test('Fundición: Derretir devuelve el MP de la habilidad', () {
      BattleStep run(Set<String> mech) => _run(
          _engine(),
          [_hero(mech: mech, skills: ['bola'])],
          [_foe('e0', st: {StatusKind.freeze: 2})],
          _sk('bola'));
      expect(_reactions(run({})).single.kind, ReactionKind.derretir);
      expect(_p(run({})).mp, 50 - 4);
      expect(_p(run({'fundicion'})).mp, 50);
      // Sin Derretir no devuelve nada.
      final none = _run(_engine(), [_hero(mech: {'fundicion'}, skills: ['bola'])],
          [_foe('e0')], _sk('bola'));
      expect(_p(none).mp, 50 - 4);
    });

    test('Mecha Corta: la Explosión tóxica deja Quemadura = Veneno / 2', () {
      int burn(Set<String> mech) => _e(_run(
              _engine(),
              [_hero(mech: mech, skills: ['bola'])],
              [_foe('e0', hp: 2000, st: {StatusKind.poison: 5})],
              _sk('bola')))
          .stacks(StatusKind.burn);
      expect(burn({'mechaCorta'}) - burn({}), 3); // ⌈5 / 2⌉
    });

    test('Cristalizar: la Congelación súbita deja Quebradizos a los demás', () {
      BattleStep run(Set<String> mech) => _run(
          _engine(),
          [_hero(mech: mech, skills: ['lanzaH'])],
          [
            _foe('e0', st: _wet),
            _foe('e1', st: {StatusKind.freeze: 2}),
            _foe('e2'),
          ],
          _sk('lanzaH'));
      expect(_e(run({}), 1).brittle, isFalse);
      final on = run({'cristalizar'});
      expect(_reactions(on).single.kind, ReactionKind.congelacionSubita);
      expect(_e(on, 1).brittle, isTrue);
      expect(_e(on, 2).brittle, isFalse, reason: 'sin Congelación');
      // El congelado no: queda Quebradizo al perder su turno.
      expect(_e(on).brittle, isFalse);
      expect(on.events.whereType<IceEvent>().any((e) =>
          e.targetId == 'e1' && e.phase == IcePhase.brittle), isTrue);
    });

    test('Rocío Arcano: mojar da +10 de ULT', () {
      double ult(Set<String> mech) => _p(_run(_engine(),
              [_hero(mech: mech, skills: ['chorro'])], [_foe('e0')],
              _sk('chorro')))
          .ult;
      expect(ult({'rocioArcano'}) - ult({}), closeTo(10, 1e-9));
      // Sin Mojado (Chispa) no.
      double chispa(Set<String> mech) => _p(_run(_engine(),
              [_hero(mech: mech, skills: ['chispa'])], [_foe('e0')],
              _sk('chispa')))
          .ult;
      expect(chispa({'rocioArcano'}), chispa({}));
    });

    test('Alto Voltaje: la Electrocución aturde 2 turnos (no a jefes)', () {
      final e = _engine();
      final st = _run(e, [_hero(mech: {'altoVoltaje'}, skills: ['chispazo'])],
          [_foe('e0', st: _wet)], _sk('chispazo'));
      final f = _e(st);
      expect(f.stacks(StatusKind.stun), 1);
      expect(f.hasEffect(BuffStat.stunLock), isTrue);
      // Pierde su turno y sigue aturdido el siguiente.
      var s = st.state..currentId = 'e0';
      s = e.enemyTurn(s)!.state;
      expect(s.enemies.first.stacks(StatusKind.stun), 1);
      final boss = _run(_engine(),
          [_hero(mech: {'altoVoltaje'}, skills: ['chispazo'])],
          [_foe('e0', st: _wet, boss: true)], _sk('chispazo'));
      expect(_e(boss).hasEffect(BuffStat.stunLock), isFalse);
    });

    test('Estasis: detonar retrasa al objetivo 25%', () {
      double next(Set<String> mech) => _e(_run(_engine(),
              [_hero(mech: mech, skills: ['chispazo'])],
              [_foe('e0', st: _wet)], _sk('chispazo')))
          .nextTurn;
      expect(next({'estasis'}) - next({}), closeTo(20 * 0.25, 1e-9));
    });

    test('Pulso Rúnico: detonar adelanta tu próximo turno 25%', () {
      double next(Set<String> mech) => _p(_run(_engine(),
              [_hero(mech: mech, skills: ['chispazo'])],
              [_foe('e0', st: _wet)], _sk('chispazo')))
          .nextTurn;
      expect(next({}) - next({'pulsoRunico'}), closeTo(10 * 0.25, 1e-9));
    });

    test('Hoja de Marea: 30% de mojar a un solo objetivo', () {
      final yes = _run(_engine([0.99, 0.1]), [_hero(mech: {'hojaMarea'})],
          [_foe('e0')], const AttackCommand(targetId: 'e0'));
      expect(_e(yes).stacks(StatusKind.wet), greaterThan(0));
      final no = _run(_engine([0.99, 0.5]), [_hero(mech: {'hojaMarea'})],
          [_foe('e0')], const AttackCommand(targetId: 'e0'));
      expect(_e(no).stacks(StatusKind.wet), 0);
    });
  });

  group('Tirador', () {
    test('Reguero de Pólvora: detonan tu Veneno → +20 ULT (aliado o vos)', () {
      double ult(Set<String> mech, {String who = 'p2'}) => _p(_run(
              _engine(),
              [
                _hero(mech: mech, skills: ['bola']),
                _hero(id: 'p2', skills: ['bola'], nextTurn: 5),
              ],
              [
                _foe('e0',
                    hp: 2000,
                    st: {StatusKind.poison: 2},
                    primed: {StatusKind.poison: 'p1'}),
              ],
              _sk('bola'),
              who))
          .ult;
      expect(ult({'reguero'}) - ult({}), closeTo(20, 1e-9));
      expect(ult({'reguero'}, who: 'p1') - ult({}, who: 'p1'),
          closeTo(20, 1e-9));
    });

    test('Chaparrón: las habilidades a todos mojan', () {
      final st = _run(_engine(), [_hero(mech: {'chaparron'}, skills: ['rafaga'])],
          [_foe('e0'), _foe('e1')], _sk('rafaga'));
      for (final f in st.state.enemies) {
        expect(f.stacks(StatusKind.wet), greaterThan(0), reason: f.id);
      }
      final one = _run(_engine(), [_hero(mech: {'chaparron'})],
          [_foe('e0')], const AttackCommand(targetId: 'e0'));
      expect(_e(one).stacks(StatusKind.wet), 0);
    });

    test('Cazador de Bestias: +25% de daño a Bestias', () {
      int lost(Set<String> mech, String type) => 300 -
          _e(_run(_engine(), [_hero(mech: mech)], [_foe('e0', type: type)],
                  const AttackCommand(targetId: 'e0')))
              .hp;
      expect(lost({'cazadorBestias'}, 'lobo'),
          closeTo(lost({}, 'lobo') * 1.25, 1));
      expect(lost({'cazadorBestias'}, 'slime'), lost({}, 'slime'));
    });
  });

  group('Paladín', () {
    test('Luz Purificadora: tus curas queman +50% a los no muertos', () {
      int burned(Set<String> mech) => 300 -
          _e(_run(
                  _engine(),
                  [
                    _hero(mech: mech, skills: ['cura'], hp: 20),
                  ],
                  [_foe('e0', type: 'esqueleto')],
                  const SkillCommand('cura')))
              .hp;
      final base = burned({});
      expect(base, greaterThan(0));
      expect(burned({'luzPurificadora'}), closeTo(base * 1.5, 1));
    });
  });

  group('Grupo (co-op)', () {
    List<Combatant> party(Set<String> mech) => [
          _hero(mech: mech, skills: ['chispazo']),
          _hero(id: 'p2', skills: ['chispazo'], nextTurn: 5),
        ];
    List<Combatant> primed() =>
        [_foe('e0', st: _wet, primed: {StatusKind.wet: 'p1'})];

    test('Combo de Equipo: el aliado detona lo tuyo → ambos +20%', () {
      final st = _run(
          _engine(), party({'comboEquipo'}), primed(), _sk('chispazo'), 'p2');
      for (final id in ['p1', 'p2']) {
        expect(_p(st, id).effectFrom('comboEquipo', BuffStat.damage)!.value,
            0.20,
            reason: id);
      }
      // Lo detonás vos: solo vos.
      final solo = _run(
          _engine(), party({'comboEquipo'}), primed(), _sk('chispazo'), 'p1');
      expect(_p(solo).hasEffect(BuffStat.damage), isTrue);
      expect(_p(solo, 'p2').hasEffect(BuffStat.damage), isFalse);
      // Lo preparó otro: nada.
      final other = _run(_engine(), party({'comboEquipo'}),
          [_foe('e0', st: _wet, primed: {StatusKind.wet: 'p2'})],
          _sk('chispazo'), 'p2');
      expect(_proc(other, 'comboEquipo'), isFalse);
    });

    test('Sincronía Elemental: cualquier reacción da +6 ULT al grupo', () {
      double ult(Set<String> mech, String id) => _p(
              _run(_engine(), party(mech), primed(), _sk('chispazo'), 'p2'),
              id)
          .ult;
      expect(ult({'sincroniaElemental'}, 'p1') - ult({}, 'p1'),
          closeTo(6, 1e-9));
      expect(ult({'sincroniaElemental'}, 'p2') - ult({}, 'p2'),
          closeTo(6, 1e-9));
    });

    test('un enemigo que detona sobre un jugador no dispara el árbol', () {
      final e = _engine();
      final s = BattleState(party: [
        _hero(mech: {'sincroniaElemental', 'pulsoRunico'}),
      ], enemies: [
        Combatant(
          id: 'e0',
          name: 'Ojo',
          isPlayer: false,
          hp: 300,
          maxHp: 300,
          speed: 5,
          attack: 10,
          critChance: 0,
          enemyType: 'ojoAbismo',
        ),
      ], currentId: 'e0');
      s.party.first.statuses[StatusKind.wet] = 2;
      final st = e.enemyTurn(s)!;
      expect(_reactions(st), isNotEmpty);
      expect(st.events.whereType<ProcEvent>(), isEmpty);
    });
  });
}
