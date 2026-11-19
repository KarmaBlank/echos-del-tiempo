import 'package:echos_del_tiempo/game_engine/data/branch_ults_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/elements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/summoner_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// Bug v0.8.3 (reporte del dueño): "un enemigo mojado, le tiro electro,
// quedan los dos estados". Un golpe que LLEVA un elemento detona la
// reacción aunque el elemento no sea el "propio" de la habilidad
// (elemental_reactions.md § 9): estados extra de la habilidad, estados
// que el golpe deja por el árbol / el arma (Dios del Trueno, Señora de
// las Mareas, Avatar), Detonar que consumía el estado antes del golpe y
// las repeticiones (Eco). Azar fijo 0.99 (nunca crítico ni probabilidad).

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine({GameCatalog catalog = GameCatalog.standard,
    List<double> rolls = const []}) {
  var i = 0;
  return BattleEngine(
      stats: _stats,
      catalog: catalog,
      random: () => i < rolls.length ? rolls[i++] : 0.99,
      familiesEnabled: false,
      breakEnabled: false);
}

/// Catálogo estándar con la ULT de la varita reemplazada por [ult].
GameCatalog _withUlt(SkillDef ult) => GameCatalog(
      classes: GameCatalog.standard.classes,
      weapons: GameCatalog.standard.weapons,
      skills: GameCatalog.standard.skills,
      ultimates: {...GameCatalog.standard.ultimates, 'varita': ult},
      duals: GameCatalog.standard.duals,
      enemies: GameCatalog.standard.enemies,
    );

Combatant _hero(
        {Set<String> mech = const {},
        List<String> skills = const [],
        double ult = 0,
        List<TimedEffect>? fx,
        Set<String>? once}) =>
    Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: skills,
      mechanics: {...mech},
      classId: 'maga',
      weaponType: 'varita',
      ult: ult,
      effects: fx,
      once: once,
    );

Combatant _foe(String id, {Map<StatusKind, int>? st, int hp = 1000}) =>
    Combatant(
      id: id,
      name: 'Foe $id',
      isPlayer: false,
      hp: hp,
      maxHp: hp,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: 'slime',
      statuses: st,
      nextTurn: 50,
    );

BattleStep _run(BattleEngine e, List<Combatant> enemies, BattleCommand c,
    {Combatant? hero}) {
  final s = BattleState(
      party: [hero ?? _hero()], enemies: enemies, currentId: 'p1');
  return e.command(s, 'p1', c)!;
}

List<ReactionEvent> _rx(BattleStep s) =>
    s.events.whereType<ReactionEvent>().toList();

const _atk = AttackCommand(targetId: 'e0');
const _ult = UltimateCommand(targetId: 'e0');

void main() {
  group('golpes que llevan el elemento por el árbol / el arma', () {
    test('Dios del Trueno: ataque básico a un Mojado → Electrocución', () {
      final s = _run(_engine(), [_foe('e0', st: {StatusKind.wet: 2})], _atk,
          hero: _hero(mech: {'diosTrueno'}));
      final foe = s.state.enemies.single;
      final r = _rx(s).single;
      expect(r.kind, ReactionKind.electrocucion);
      expect(foe.stacks(StatusKind.wet), 0, reason: 'Mojado consumido');
      expect(foe.stacks(StatusKind.stun), 1);
      // El golpe deja su Cargado DESPUÉS de reaccionar (como Chispazo).
      expect(foe.stacks(StatusKind.charged), greaterThan(0));
      // ATQ 20 × 1.5 (el golpe que detona).
      expect(foe.hp, 1000 - 30);
    });

    test('Señora de las Mareas: ataque básico a un Cargado → Cortocircuito',
        () {
      final s = _run(
          _engine(),
          [
            _foe('e0', st: {StatusKind.charged: 1}),
            _foe('e1'),
          ],
          _atk,
          hero: _hero(mech: {'senoraMareas'}));
      final r = _rx(s).single;
      expect(r.kind, ReactionKind.cortocircuito);
      expect(s.state.enemies.first.stacks(StatusKind.charged), 0);
      expect(s.state.enemies.first.stacks(StatusKind.wet), greaterThan(0));
      expect(s.state.enemies[1].hp, lessThan(1000), reason: 'el salto');
    });

    test('Sin Mojado, Dios del Trueno solo deja Cargado (sin reacción)', () {
      final s = _run(_engine(), [_foe('e0')], _atk,
          hero: _hero(mech: {'diosTrueno'}));
      expect(_rx(s), isEmpty);
      expect(s.state.enemies.single.stacks(StatusKind.charged), greaterThan(0));
      expect(s.state.enemies.single.hp, 1000 - 20);
    });

    test('Avatar del Pacto con Electro: el golpe electrocuta al Mojado', () {
      final s = _run(_engine(), [_foe('e0', st: {StatusKind.wet: 2})], _atk,
          hero: _hero(fx: [
            TimedEffect(
                sourceId: kAvatarUltimate.id,
                stat: BuffStat.damage,
                value: 0.0001,
                turns: 2,
                ownerId: 'p1'),
          ], once: {
            'avatar:${SummonKind.electro.name}'
          }));
      expect(_rx(s).single.kind, ReactionKind.electrocucion);
      final foe = s.state.enemies.single;
      expect(foe.stacks(StatusKind.wet), 0);
      expect(foe.stacks(StatusKind.charged), greaterThan(0));
    });
  });

  group('ULT con estados extra', () {
    test('Electrólisis (Agua + Cargado) sobre un Mojado → Electrocución', () {
      final ult = kBranchUltSkills['ult_electrolisis']!;
      expect(elementOf(ult.id), GameElement.agua);
      final s = _run(_engine(catalog: _withUlt(ult)),
          [_foe('e0', st: {StatusKind.wet: 2})], _ult,
          hero: _hero(ult: 100));
      expect(_rx(s).single.kind, ReactionKind.electrocucion);
      final foe = s.state.enemies.single;
      // Consumió el Mojado viejo; después el golpe deja Mojado + Cargado.
      expect(foe.stacks(StatusKind.stun), 1);
    });

    test('Ojo de la Tormenta (Agua + Cargado) sobre un Mojado → reacciona',
        () {
      final ult = kBranchUltSkills['ult_ojoTormenta']!;
      final s = _run(_engine(catalog: _withUlt(ult)),
          [_foe('e0', st: {StatusKind.wet: 2})], _ult,
          hero: _hero(ult: 100));
      expect(_rx(s).single.kind, ReactionKind.electrocucion);
    });
  });

  group('Detonar no se come el estado que el golpe detona', () {
    test('Supernova (fuego, detona) sobre Veneno → Explosión tóxica', () {
      final ult = kBranchUltSkills['ult_supernova']!;
      final s = _run(_engine(catalog: _withUlt(ult)),
          [_foe('e0', st: {StatusKind.poison: 3})], _ult,
          hero: _hero(ult: 100));
      final r = _rx(s).single;
      expect(r.kind, ReactionKind.explosionToxica);
      expect(r.consumedStacks, 3);
      expect(s.state.enemies.single.stacks(StatusKind.poison), 0);
    });

    test('Supernova sobre Congelación → Derretir', () {
      final ult = kBranchUltSkills['ult_supernova']!;
      final s = _run(_engine(catalog: _withUlt(ult)),
          [_foe('e0', st: {StatusKind.freeze: 2})], _ult,
          hero: _hero(ult: 100));
      expect(_rx(s).single.kind, ReactionKind.derretir);
      expect(s.state.enemies.single.stacks(StatusKind.freeze), 0);
    });
  });

  group('regresión: los caminos que ya reaccionaban', () {
    test('Cadena de Rayos: el rebote electrocuta a otro Mojado', () {
      final s = _run(
          _engine(),
          [
            _foe('e0'),
            _foe('e1', st: {StatusKind.wet: 2}),
          ],
          const SkillCommand('cadenaRayos', targetId: 'e0'),
          hero: _hero(skills: ['cadenaRayos']));
      final r = _rx(s);
      expect(r.map((x) => (x.targetId, x.kind)),
          contains(('e1', ReactionKind.electrocucion)));
      expect(s.state.enemies[1].stacks(StatusKind.wet), 0);
    });

    test('Tormenta Eléctrica (todos): una Electrocución por Mojado', () {
      final s = _run(
          _engine(),
          [
            _foe('e0', st: {StatusKind.wet: 2}),
            _foe('e1', st: {StatusKind.wet: 2}),
          ],
          const SkillCommand('tormentaElectrica', targetId: 'e0'),
          hero: _hero(skills: ['tormentaElectrica']));
      expect(_rx(s), hasLength(2));
      for (final e in s.state.enemies) {
        expect(e.stacks(StatusKind.wet), 0);
      }
    });

    test('Ataque básico sin nada del árbol: neutro, no reacciona', () {
      final s = _run(_engine(), [_foe('e0', st: {StatusKind.wet: 2})], _atk);
      expect(_rx(s), isEmpty);
      expect(s.state.enemies.single.stacks(StatusKind.wet), 2);
    });

    test('Un golpe = una reacción: Chispazo + Dios del Trueno no repite', () {
      final s = _run(_engine(), [_foe('e0', st: {StatusKind.wet: 2})],
          const SkillCommand('chispazo', targetId: 'e0'),
          hero: _hero(skills: ['chispazo'], mech: {'diosTrueno'}));
      expect(_rx(s), hasLength(1));
    });
  });
}
