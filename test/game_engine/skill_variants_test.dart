import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/elemental_skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skill_variants_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/data/summoner_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

// Variantes de habilidades v0.5 (docs/specs/combat.md § "Variantes de
// habilidades"): un escenario determinístico por mecánica. Azar fijo
// (0.99 al acabarse: nunca crítico ni probabilidad).

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

const _catalog = GameCatalog(
  classes: kClasses,
  weapons: kWeapons,
  skills: kSkills,
  ultimates: kAllUltimates,
  duals: kDuals,
  enemies: kEnemies,
);

Combatant _hero(String id,
        {int hp = 100, int attack = 20, int magic = 20, String? skill}) =>
    Combatant(
      id: id,
      name: 'H$id',
      isPlayer: true,
      hp: hp,
      maxHp: 100,
      speed: 10,
      attack: attack,
      magic: magic,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: [if (skill != null) skill],
      classId: 'tirador',
      weaponType: 'arco',
    );

Combatant _foe(String id,
        {int hp = 200,
        int attack = 10,
        double nextTurn = 50,
        String? ultId,
        double ult = 0,
        double breakBase = 0}) =>
    Combatant(
      id: id,
      name: 'Limo $id',
      isPlayer: false,
      hp: hp,
      maxHp: hp < 200 ? 200 : hp,
      speed: 5,
      attack: attack,
      critChance: 0,
      enemyType: 'slime',
      nextTurn: nextTurn,
      ultId: ultId,
      ult: ult,
      breakBase: breakBase,
    );

/// Una batalla que sigue el estado que devuelve el motor.
class _B {
  _B(List<Combatant> party, List<Combatant> enemies, [List<double> rolls = const []])
      : s = BattleState(party: party, enemies: enemies, currentId: party.first.id) {
    var i = 0;
    e = BattleEngine(
        stats: _stats,
        catalog: _catalog,
        random: () => i < rolls.length ? rolls[i++] : 0.99);
  }

  BattleState s;
  late final BattleEngine e;

  Combatant operator [](String id) => s.byId(id)!;

  BattleStep use(String skill, {String target = 'e0', String who = 'p1'}) {
    s.currentId = who;
    final step = e.command(s, who, SkillCommand(skill, targetId: target));
    expect(step, isNotNull, reason: 'comando $skill inválido');
    s = step!.state;
    return step;
  }

  void attack({String target = 'e0', String who = 'p1'}) {
    s.currentId = who;
    s = e.command(s, who, AttackCommand(targetId: target))!.state;
  }

  void enemy([String id = 'e0']) {
    s.currentId = id;
    s = e.enemyTurn(s)!.state;
  }

  void next() => s = e.nextTurn(s).state;
}

int _shield(Combatant c) => c.effects
    .where((e) => e.stat == BuffStat.shield)
    .fold(0, (s, e) => s + e.value.round());

void main() {
  group('catálogo de variantes', () {
    test('ids únicos, sin pisar habilidades existentes, con familia y look', () {
      final all = {...kSkills, ...kSkillVariants};
      for (final e in kSkillVariants.entries) {
        expect(e.value.id, e.key);
        final old = kSkills[e.key];
        expect(old == null || identical(old, e.value), isTrue,
            reason: '${e.key} pisa una habilidad existente');
        expect(mechanicById(e.key), isNull,
            reason: '${e.key} choca con una mecánica (efectos y chips)');
        expect(kSkillVariantFamily, contains(e.key));
        expect(all, contains(kSkillLooks[e.key]), reason: 'look de ${e.key}');
      }
      expect(kSkillVariantFamily.keys.toSet(), kSkillVariants.keys.toSet());
      // v0.7: también las de Agua y Electro tienen look.
      expect(kSkillLooks.keys.toSet(),
          {...kSkillVariants.keys, ...kElementalSkills.keys, ...kSummonerSkills.keys});
      expect(all.length, greaterThanOrEqualTo(120));
    });

    test('cada familia tiene sus variantes', () {
      int n(SkillFamily f) =>
          kSkillVariantFamily.values.where((x) => x == f).length;
      expect(n(SkillFamily.heal), greaterThanOrEqualTo(10));
      expect(n(SkillFamily.shield), greaterThanOrEqualTo(6));
      expect(n(SkillFamily.shot), greaterThanOrEqualTo(10));
      expect(n(SkillFamily.debuff), greaterThanOrEqualTo(4));
      expect(n(SkillFamily.control), greaterThanOrEqualTo(3));
      expect(n(SkillFamily.buff), greaterThanOrEqualTo(3));
    });
  });

  group('curación', () {
    test('Cura Focalizada cura solo al más herido', () {
      final b = _B([_hero('p1', skill: 'curaFocal'), _hero('p2', hp: 30), _hero('p3', hp: 60)],
          [_foe('e0')]);
      b.use('curaFocal');
      expect(b['p2'].hp, 30 + (20 * 2.6 + 6).round());
      expect(b['p3'].hp, 60);
    });

    test('Rocío Sanador cura poco a todos', () {
      final b = _B([_hero('p1', hp: 50, skill: 'rocio'), _hero('p2', hp: 50)], [_foe('e0')]);
      b.use('rocio');
      expect(b['p1'].hp, 50 + 20);
      expect(b['p2'].hp, 50 + 20);
    });

    test('Resurrección revive al caído (y si no hay, cura al más herido)', () {
      final b = _B([_hero('p1', skill: 'resurreccion'), _hero('p2', hp: 0)], [_foe('e0')]);
      final step = b.use('resurreccion');
      expect(b['p2'].alive, isTrue);
      expect(b['p2'].hp, 35);
      expect(step.events.whereType<RevivedEvent>().single.targetId, 'p2');
      // Sin caídos: cura normal al más herido.
      b['p2'].hp = 10;
      b.use('resurreccion');
      expect(b['p2'].hp, 10 + (20 * 1.4 + 6).round());
    });

    test('Llama Fénix revive con 70% y sin estados', () {
      final down = _hero('p2', hp: 0)..statuses[StatusKind.freeze] = 2;
      final b = _B([_hero('p1', skill: 'fenix'), down], [_foe('e0')]);
      b.use('fenix');
      expect(b['p2'].hp, 70);
      expect(b['p2'].stacks(StatusKind.freeze), 0);
    });

    test('Gracia Desbordante: lo que sobra se vuelve escudo', () {
      final b = _B([_hero('p1', hp: 95, skill: 'graciaDesbordante')], [_foe('e0')]);
      b.use('graciaDesbordante');
      final heal = (20 * 2.0 + 6).round(); // 46
      expect(b['p1'].hp, 100);
      expect(_shield(b['p1']), heal - 5);
    });

    test('Semilla Vital: Regeneración solo al más herido', () {
      final b = _B([_hero('p1', skill: 'semilla'), _hero('p2', hp: 20)], [_foe('e0')]);
      b.use('semilla');
      expect(b['p2'].stacks(StatusKind.regen), greaterThan(0));
      expect(b['p1'].stacks(StatusKind.regen), 0);
    });

    test('Drenar Vida: el daño cura al aliado más herido', () {
      final b = _B([_hero('p1', skill: 'drenar'), _hero('p2', hp: 20)], [_foe('e0')]);
      b.use('drenar');
      final dmg = 200 - b['e0'].hp;
      // × 0.92: mitigación de grupo con 2 jugadores (combo_balance.md § 3.3).
      expect(dmg, (20 * 1.4 * 0.92).round());
      expect(b['p2'].hp, 20 + (dmg * 0.6).round());
    });
  });

  group('escudos', () {
    test('Escudo Arcano va al más herido', () {
      final b = _B([_hero('p1', skill: 'escudoArcano'), _hero('p2', hp: 40)], [_foe('e0')]);
      b.use('escudoArcano');
      expect(_shield(b['p2']), 30);
      expect(_shield(b['p1']), 0);
    });

    test('Barrera escuda a todos', () {
      final b = _B([_hero('p1', skill: 'barrera'), _hero('p2')], [_foe('e0')]);
      b.use('barrera');
      expect(_shield(b['p1']), 12);
      expect(_shield(b['p2']), 12);
    });

    test('Desafío: provoca y se escuda', () {
      final b = _B([_hero('p1', skill: 'retoEscudado')], [_foe('e0')]);
      b.use('retoEscudado');
      expect(b['p1'].taunt, 2);
      expect(_shield(b['p1']), 20);
    });

    test('Égida Espinosa refleja lo absorbido al atacante', () {
      final b = _B([_hero('p1', skill: 'egidaEspinosa')], [_foe('e0', attack: 20)]);
      b.use('egidaEspinosa');
      expect(_shield(b['p1']), 22);
      b.enemy();
      expect(b['e0'].hp, lessThan(200), reason: 'refleja daño');
    });

    test('Escudo Volátil explota al romperse', () {
      final b = _B([_hero('p1', skill: 'escudoVolatil')],
          [_foe('e0', attack: 80), _foe('e1')]);
      b.use('escudoVolatil');
      expect(_shield(b['p1']), 20);
      b.enemy();
      expect(_shield(b['p1']), 0);
      expect(b['e1'].hp, 200 - (20 * 1.2).round());
    });

    test('Bastión Creciente crece al parar golpes', () {
      final b = _B([_hero('p1', skill: 'bastionCreciente')], [_foe('e0', attack: 6)]);
      b.use('bastionCreciente');
      final before = _shield(b['p1']);
      expect(before, 12);
      b.enemy();
      expect(_shield(b['p1']), greaterThan(before));
      expect(_shield(b['p1']), lessThanOrEqualTo(50));
    });
  });

  group('disparos', () {
    test('Flecha Perforante atraviesa a los de atrás, no a los de adelante', () {
      final b = _B([_hero('p1', skill: 'flechaPerforante')],
          [_foe('e0'), _foe('e1'), _foe('e2')]);
      b.use('flechaPerforante', target: 'e1');
      expect(b['e0'].hp, 200);
      expect(b['e1'].hp, 200 - 28);
      expect(b['e2'].hp, 200 - (28 * 0.7).round());
    });

    test('Tiro de Rebote: rebota 2 veces (solo: vuelve al mismo)', () {
      final b = _B([_hero('p1', skill: 'tiroRebote')], [_foe('e0')]);
      b.use('tiroRebote');
      expect(b['e0'].hp,
          200 - 24 - (24 * 0.7).round() - (24 * 0.7 * 0.7).round());
      final b2 = _B([_hero('p1', skill: 'tiroRebote')], [_foe('e0'), _foe('e1')]);
      b2.use('tiroRebote');
      expect(b2['e1'].hp, lessThan(200));
    });

    test('Ráfaga Triple pega 3 veces', () {
      final b = _B([_hero('p1', skill: 'rafagaTriple')], [_foe('e0')]);
      final step = b.use('rafagaTriple');
      expect(b['e0'].hp, 200 - 3 * 12);
      expect(
          step.events.whereType<DamageEvent>().where((d) => d.targetId == 'e0'),
          hasLength(3));
    });

    test('Disparo Cargado cae al empezar el próximo turno', () {
      final b = _B([_hero('p1', skill: 'disparoCargado')], [_foe('e0', nextTurn: 1000)]);
      b.use('disparoCargado');
      expect(b['e0'].hp, 200, reason: 'no pega al cargar');
      expect(b['p1'].effects.where((x) => x.stat == BuffStat.charge), hasLength(1));
      b.next();
      expect(b.s.currentId, 'p1');
      expect(b['e0'].hp, 200 - (20 * 3.4).round());
      expect(b['p1'].effects.where((x) => x.stat == BuffStat.charge), isEmpty);
    });

    test('Disparo Cargado que remata termina la batalla', () {
      final b = _B([_hero('p1', skill: 'disparoCargado')],
          [_foe('e0', hp: 50, nextTurn: 1000)]);
      b.use('disparoCargado');
      b.next();
      expect(b.s.outcome?.victory, isTrue);
    });

    test('Flecha Marcadora marca: el grupo pega más', () {
      final b = _B([_hero('p1', skill: 'flechaMarcadora')], [_foe('e0', nextTurn: 1000)]);
      b.use('flechaMarcadora');
      expect(b['e0'].effectTotal(BuffStat.damageTaken), closeTo(0.25, 1e-9));
      final hp = b['e0'].hp;
      b.attack();
      expect(hp - b['e0'].hp, (20 * 1.25).round());
    });

    test('Tiro Quebrantador llena más la barra de quiebre', () {
      double fill(String skill) {
        final b = _B([_hero('p1', skill: skill)], [_foe('e0', hp: 2000, breakBase: 1000)]);
        b.use(skill);
        return b['e0'].breakGauge;
      }

      // Mismo poder (1.3): +100% contra +50%.
      expect(fill('tiroQuebrantador'),
          closeTo(fill('rompearmaduras') * 2 / 1.5, 1e-6));
    });
  });

  group('debuffs y control', () {
    test('Rugido debilita a todos (sin daño)', () {
      final b = _B([_hero('p1', skill: 'rugidoIntimidante')], [_foe('e0'), _foe('e1')]);
      b.use('rugidoIntimidante');
      for (final id in ['e0', 'e1']) {
        expect(b[id].hp, 200);
        expect(b[id].effectTotal(BuffStat.attack), closeTo(-0.25, 1e-9));
      }
    });

    test('Lentitud alarga los turnos del enemigo', () {
      final b = _B([_hero('p1', skill: 'lentitud')], [_foe('e0')]);
      final base = b.e.interval(b['e0']);
      b.use('lentitud');
      expect(b.e.interval(b['e0']), greaterThan(base));
    });

    test('Silencio quita carga de ULT', () {
      final b = _B([_hero('p1', skill: 'silencio')],
          [_foe('e0', ultId: 'eult_furia', ult: 80)]);
      b.use('silencio');
      expect(b['e0'].ult, lessThan(50));
    });

    test('Viento de Prisa: velocidad para el grupo', () {
      final b = _B([_hero('p1', skill: 'vientoPrisa'), _hero('p2')], [_foe('e0')]);
      b.use('vientoPrisa');
      expect(b['p2'].effectTotal(BuffStat.speed), closeTo(0.25, 1e-9));
    });
  });

  test('todas las variantes se pueden usar sin romper el motor', () {
    for (final id in kSkillVariants.keys) {
      final b = _B([_hero('p1', skill: id, hp: 70), _hero('p2', hp: 0)],
          [_foe('e0', ultId: 'eult_furia', ult: 50), _foe('e1')]);
      final step = b.use(id);
      expect(step.events, isNotEmpty, reason: id);
      expect(b['p1'].mp, 50 - kSkillVariants[id]!.mp, reason: id);
      // Un turno enemigo y el siguiente (los disparos cargados caen).
      b.enemy();
      b.next();
    }
  });

  test('SkillDef: valores por defecto de las variantes apagados', () {
    const s = SkillDef(id: 'x', name: 'x', kind: SkillKind.physical);
    expect(s.hits, 1);
    expect(s.charge + s.pierce + s.drainHeal + s.overheal + s.revive, 0);
    expect(s.bounces, 0);
    expect(s.debuffs, isEmpty);
    expect(s.shields, isFalse);
  });
}
