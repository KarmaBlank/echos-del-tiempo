import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/family_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Familias de enemigos (docs/specs/bestiary.md § 1): un escenario
// determinístico por regla. Azar fijo 0.99 (nunca crítico ni esquiva).

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

Combatant _hero({int attack = 20, int magic = 20, String? skill}) => Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: attack,
      magic: magic,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: [if (skill != null) skill],
      classId: 'sacerdote',
      weaponType: 'baculo',
    );

Combatant _foe(String type,
        {String id = 'e0', int hp = 500, double breakBase = 0}) =>
    Combatant(
      id: id,
      name: kEnemies[type]!.name,
      isPlayer: false,
      hp: hp,
      maxHp: hp,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: type,
      nextTurn: 50,
      breakBase: breakBase,
    );

class _B {
  _B(List<Combatant> enemies,
      {Combatant? hero, bool families = true})
      : s = BattleState(
            party: [hero ?? _hero()],
            enemies: enemies,
            currentId: 'p1') {
    e = BattleEngine(
        stats: _stats,
        catalog: _catalog,
        random: () => 0.99,
        familiesEnabled: families);
  }

  BattleState s;
  late final BattleEngine e;

  BattleStep use(String skill, {String target = 'e0'}) {
    s.currentId = 'p1';
    final step = e.command(s, 'p1', SkillCommand(skill, targetId: target));
    expect(step, isNotNull, reason: 'comando $skill inválido');
    s = step!.state;
    return step;
  }

  BattleStep attack({String target = 'e0'}) {
    s.currentId = 'p1';
    final step = e.command(s, 'p1', AttackCommand(targetId: target))!;
    s = step.state;
    return step;
  }

  Combatant foe([String id = 'e0']) => s.byId(id)!;
}

void main() {
  group('catálogo', () {
    test('todo enemigo, jefe e invocación tiene familia y regla', () {
      for (final id in kEnemies.keys) {
        expect(kEnemyFamily[id], isNotNull, reason: id);
      }
      for (final f in EnemyFamily.values) {
        expect(kFamilyRules[f]?.family, f);
      }
      // Los jefes de zona también (bosses.md).
      for (final z in kZones) {
        expect(familyOf(z.bossId), isNotNull, reason: z.id);
      }
    });

    test('cada familia tiene rasgos, solo con datos de juego', () {
      for (final r in kFamilyRules.values) {
        expect(familyTraits(r), isNotEmpty, reason: r.family.label);
      }
      final undead = familyTraits(kFamilyRules[EnemyFamily.undead]!)
          .map((t) => t.label)
          .toList();
      expect(undead, [
        'las curas le hacen daño (100% de la cura)',
        'Sagrado ×1.5',
        'Fuego ×1.5',
        'daño del estado Sagrado ×2',
        'Hielo ×0.5',
        'Veneno',
      ]);
    });

    test('tipos de daño de las habilidades', () {
      expect(skillDamageTags(null), {DamageTag.physical});
      expect(skillDamageTags(kSkills['chispa']),
          {DamageTag.magical, DamageTag.fire});
      expect(skillDamageTags(kSkills['sagrado']),
          {DamageTag.physical, DamageTag.holy});
      expect(skillDamageTags(kSkills['lanzaH']),
          {DamageTag.magical, DamageTag.ice});
      expect(skillDamageTags(kSkills['cura']), {DamageTag.holy});
    });

    test('de los elementos cuenta la debilidad más alta, no el producto', () {
      final undead = kFamilyRules[EnemyFamily.undead]!;
      // Consagrar: mágico + Sagrado + fuego → solo Sagrado ×1.5.
      expect(familyMultiplier(undead, skillDamageTags(kSkills['consagrar'])),
          1.5);
      final spectre = kFamilyRules[EnemyFamily.spectre]!;
      // Lanza de Luz: mágico (normal desde v0.9) y Sagrado ×1.5.
      expect(familyMultiplier(spectre, skillDamageTags(kSkills['lanzaLuz'])),
          closeTo(1.5, 1e-9));
    });

    test('isFamily (para notables y pasivas)', () {
      final e = _foe('esqueleto');
      expect(isFamily(e, EnemyFamily.undead), isTrue);
      expect(isFamily(e, EnemyFamily.beast), isFalse);
      expect(isFamily(_hero(), EnemyFamily.undead), isFalse);
      expect(familyOfCombatant(_foe('lobo')), EnemyFamily.beast);
    });
  });

  group('las curas dañan a los no muertos', () {
    test('Cura sobre el grupo quema al Esqueleto con el mismo número', () {
      final b = _B([_foe('esqueleto')], hero: _hero(skill: 'cura'));
      // Lanzada al grupo (no al enemigo): el daño pasivo de siempre.
      final step = b.use('cura', target: 'p1');
      // (MAG 20 × 1.5 + 6) = 36.
      expect(b.foe().hp, 500 - 36);
      final dmg = step.events.whereType<DamageEvent>().single;
      expect([dmg.targetId, dmg.amount, dmg.sourceId],
          ['e0', 36, kHealHarmSourceId]);
      expect(b.s.log, contains('¡La cura quema al Esqueleto! 36'));
    });

    test('más poder de curación = más daño (build full curas)', () {
      final weak = _B([_foe('esqueleto')], hero: _hero(magic: 20, skill: 'cura'));
      final strong =
          _B([_foe('esqueleto')], hero: _hero(magic: 60, skill: 'cura'));
      weak.use('cura');
      strong.use('cura');
      expect(500 - strong.foe().hp, greaterThan(2 * (500 - weak.foe().hp)));
    });

    test('espectros: a medias; varios: "a los no muertos"', () {
      final b = _B([_foe('esqueleto'), _foe('ghost', id: 'e1'), _foe('lobo', id: 'e2')],
          hero: _hero(skill: 'cura'));
      b.use('cura', target: 'p1');
      expect(b.foe('e0').hp, 500 - 36);
      expect(b.foe('e1').hp, 500 - 18);
      expect(b.foe('e2').hp, 500); // la bestia no
      expect(b.s.log,
          contains('¡La cura quema a los no muertos! Esqueleto 36, Espectro 18'));
    });

    group('lanzada a un enemigo (§ 1.4.1)', () {
      // curaFocal: (MAG 20 × 2.6 + 6) = 58; × healFoeMult 1.5.
      test('de un blanco a un no muerto: daño × healHarm × 1.5, sin curar',
          () {
        final hero = _hero(skill: 'curaFocal')..hp = 40;
        final b = _B([_foe('esqueleto'), _foe('esqueleto', id: 'e1')],
            hero: hero);
        final step = b.use('curaFocal', target: 'e0');
        expect(b.foe('e0').hp, 500 - 87);
        expect(b.foe('e1').hp, 500); // solo al elegido
        expect(b.s.byId('p1')!.hp, 40); // no cura
        final dmg = step.events.whereType<DamageEvent>().single;
        expect(dmg.sourceId, kHealHarmSourceId);
        expect(b.s.log, contains('¡la cura quema al Esqueleto! 87'));
      });

      test('a un espectro: a medias', () {
        final b = _B([_foe('ghost')], hero: _hero(skill: 'curaFocal'));
        b.use('curaFocal', target: 'e0');
        expect(b.foe('e0').hp, 500 - 44); // 58 × 0.5 × 1.5 = 43.5
      });

      test('un enemigo normal no es blanco: cura al más herido', () {
        final hero = _hero(skill: 'curaFocal')..hp = 40;
        final b = _B([_foe('lobo')], hero: hero);
        expect(healCanTargetFoe(kSkills['curaFocal']!, _foe('lobo')), isFalse);
        final step = b.use('curaFocal', target: 'e0');
        expect(b.foe('e0').hp, 500);
        expect(step.events.whereType<DamageEvent>(), isEmpty);
        expect(b.s.byId('p1')!.hp, 98);
      });

      test('a un aliado: cura como siempre', () {
        final hero = _hero(skill: 'curaFocal')..hp = 40;
        final b = _B([_foe('esqueleto')], hero: hero);
        b.use('curaFocal', target: 'p1');
        expect(b.s.byId('p1')!.hp, 98);
        expect(b.foe('e0').hp, 500 - 58); // y el daño pasivo de siempre
      });

      test('de grupo (Sanación) a un no muerto: solo a él, sin curar', () {
        final hero = _hero(skill: 'sanar')..hp = 40;
        final b = _B([_foe('esqueleto'), _foe('ghost', id: 'e1')],
            hero: hero);
        b.use('sanar', target: 'e0');
        // (20 × 1.1 + 6) = 28 × 1.5 = 42; el espectro, nada.
        expect(b.foe('e0').hp, 500 - 42);
        expect(b.foe('e1').hp, 500);
        expect(b.s.byId('p1')!.hp, 40);
      });

      test('de grupo al grupo: el daño pasivo de siempre', () {
        final b = _B([_foe('esqueleto'), _foe('ghost', id: 'e1')],
            hero: _hero(skill: 'sanar'));
        b.use('sanar', target: 'p1');
        expect(b.foe('e0').hp, 500 - 28);
        expect(b.foe('e1').hp, 500 - 14);
      });

      test('con las familias apagadas, no daña', () {
        final b = _B([_foe('esqueleto')],
            hero: _hero(skill: 'curaFocal'), families: false);
        b.use('curaFocal', target: 'e0');
        expect(b.foe().hp, 500);
      });
    });

    test('contra enemigos vivos normales la cura no hace daño', () {
      final b = _B([_foe('lobo')], hero: _hero(skill: 'cura'));
      final step = b.use('cura');
      expect(step.events.whereType<DamageEvent>(), isEmpty);
      expect(b.s.log, isNot(contains('quema')));
    });

    test('con las familias apagadas, no', () {
      final b = _B([_foe('esqueleto')],
          hero: _hero(skill: 'cura'), families: false);
      b.use('cura');
      expect(b.foe().hp, 500);
    });

    test('el estado Sagrado arde el doble en un no muerto', () {
      final e = _foe('esqueleto')
        ..nextTurn = 0
        ..statuses[StatusKind.holy] = 2
        ..holyTurns = 3;
      final b = _B([e]);
      b.s.party.first.nextTurn = 50;
      b.s.currentId = null;
      b.s = b.e.nextTurn(b.s).state;
      // 5 × 2 stacks × 2.
      expect(b.foe().hp, 500 - 20);
    });
  });

  group('debilidades y resistencias de daño', () {
    test('Golpe Sagrado a un no muerto: ×1.5 DÉBIL Sagrado', () {
      final b = _B([_foe('esqueleto')], hero: _hero(skill: 'sagrado'));
      final step = b.use('sagrado');
      final dmg = step.events.whereType<DamageEvent>().single;
      // ATQ 20 × 1.5 = 30 × 1.5.
      expect([dmg.amount, dmg.affinity], [45, 1.5]);
      expect(b.s.log, contains('× 1.5 DÉBIL Sagrado'));
    });

    test('espectro: el ataque físico ×0.5 (RESISTE físico)', () {
      final b = _B([_foe('ghost')]);
      final step = b.attack();
      final dmg = step.events.whereType<DamageEvent>().single;
      expect([dmg.amount, dmg.affinity], [10, 0.5]);
      expect(b.s.log, contains('× 0.5 RESISTE físico'));
    });

    test('elemental de escarcha: inmune al daño de hielo y a la Congelación', () {
      final b = _B([_foe('elementalEscarcha')], hero: _hero(skill: 'lanzaH'));
      final step = b.use('lanzaH');
      // v0.9: inmune al hielo (×0), cartel INMUNE.
      final dmg = step.events.whereType<DamageEvent>().single;
      expect([dmg.amount, dmg.affinity], [0, 0]);
      expect(b.s.log, contains('× 0 INMUNE hielo'));
      expect(b.foe().stacks(StatusKind.freeze), 0);
      expect(step.events.whereType<StatusAppliedEvent>(), isEmpty);
      expect(b.s.log, contains('INMUNE a Congelación'));
    });

    test('elemental ígneo: el hielo ×1.5 y +1 Congelación', () {
      final b = _B([_foe('salamandra')], hero: _hero(skill: 'lanzaH'));
      final step = b.use('lanzaH');
      expect(step.events.whereType<DamageEvent>().single.amount, 48);
      expect(b.foe().stacks(StatusKind.freeze), 3);
    });

    test('aberración: el mágico ×0.5', () {
      final b = _B([_foe('ojoAbismo')], hero: _hero(skill: 'misil'));
      final step = b.use('misil');
      // MAG 20 × 1.4 = 28 × 0.5.
      expect(step.events.whereType<DamageEvent>().single.amount, 14);
    });
  });

  group('estados', () {
    test('no muerto: inmune al Veneno, una sola nota por paso', () {
      final b = _B([_foe('esqueleto')], hero: _hero(skill: 'venenosa'));
      final step = b.use('venenosa');
      expect(b.foe().stacks(StatusKind.poison), 0);
      expect(step.events.whereType<StatusAppliedEvent>(), isEmpty);
      expect('INMUNE a Veneno'.allMatches(b.s.log).length, 1);
      expect(b.s.log, contains('No muerto'));
      // El log no dice que entró.
      expect(b.s.log, isNot(contains('+3 Veneno')));
    });

    test('bestia: +1 stack de Quemadura', () {
      final b = _B([_foe('lobo')], hero: _hero(skill: 'chispa'));
      final step = b.use('chispa');
      expect(b.foe().stacks(StatusKind.burn), 2);
      expect(step.events.whereType<StatusAppliedEvent>().single.stacks, 2);
    });

    test('temporal: Veneno −1 stack (mín. 1)', () {
      final b = _B([_foe('ecoSombra')], hero: _hero(skill: 'venenosa'));
      b.use('venenosa');
      expect(b.foe().stacks(StatusKind.poison), 2);
      expect(familyStacks(kFamilyRules[EnemyFamily.temporal], StatusKind.poison, 1),
          1);
    });
  });

  group('quiebre, retrasos y Marca', () {
    test('constructo: la barra de quiebre se llena ×1.5', () {
      final b = _B([_foe('golem', breakBase: 1000)]);
      final on = b.attack();
      expect(on.events.whereType<DamageEvent>(), hasLength(1));
      // Puntos de quiebre (combo_balance.md § 5): ataque 4 × 1.5.
      expect(b.foe().breakGauge, closeTo(4 * 1.5, 0.05));
      final off = _B([_foe('golem', breakBase: 1000)], families: false);
      off.attack();
      expect(off.foe().breakGauge, closeTo(4, 0.05));
    });

    test('temporal: los retrasos de las habilidades ×1.5', () {
      double delayOf(String type) {
        final b = _B([_foe(type)], hero: _hero(skill: 'detener'));
        final before = b.foe().nextTurn;
        b.use('detener');
        return b.foe().nextTurn - before;
      }

      // Intervalo 100 / 5 = 20; Detener retrasa 1.0.
      expect(delayOf('lobo'), closeTo(20, 1e-9));
      expect(delayOf('ecoSombra'), closeTo(30, 1e-9));
    });

    test('bestia: la Marca pega ×1.5 más', () {
      final b = _B([_foe('lobo')]);
      b.foe().effects.add(const TimedEffect(
          sourceId: 'x', stat: BuffStat.damageTaken, value: 0.2, turns: 2));
      final step = b.attack();
      // 20 × (1 + 0.2 × 1.5) = 26.
      expect(step.events.whereType<DamageEvent>().single.amount, 26);
    });
  });

  test('DamageEvent.affinity viaja por la red (aditivo)', () {
    const json = EventJson();
    final out = json.toJson(const BattleStepEvent(
        [DamageEvent('e0', 45, affinity: 1.5), DamageEvent('e1', 3)]));
    final back = json.fromJson(out) as BattleStepEvent;
    final evs = back.events.cast<DamageEvent>();
    expect(evs.first.affinity, 1.5);
    expect(evs.last.affinity, 1);
    // Sin factor no se manda la clave (los clientes viejos no la ven).
    expect(out.toString(), isNot(contains('af: 1,')));
  });
}
