import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/companion_ai.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// AUTO de los compañeros (docs/specs/solo_party.md § 4.1).
void main() {
  const ai = CompanionAi();

  BattleState battle({String cls = 'guerrero', int potions = 0}) {
    final engine = BattleEngine(stats: statsCalc, random: () => 0.5);
    BattlePartyMember m(String id, String c, {int potions = 0}) =>
        BattlePartyMember(
            id: id,
            name: id,
            build: progression.buildOf(newProfile(id, c)),
            potions: potions);
    return engine.start(
      party: [m('yo', 'guerrero'), m('c', cls, potions: potions)],
      enemyTypes: const ['slime', 'slime', 'slime'],
    ).state;
  }

  test('ataca al enemigo vivo con menos vida', () {
    final s = battle();
    s.enemies[1].hp = 5;
    s.enemies[2].hp = 3;
    s.enemies[2].hp = 0; // caído: no cuenta
    s.party[1].chained = true; // ya preparó con su Instante
    final c = ai.choose(s, 'c');
    expect(c, isA<AttackCommand>());
    expect((c as AttackCommand).targetId, s.enemies[1].id);
  });

  test('ULT lista → ULT al más débil', () {
    final s = battle();
    s.party[1].ult = 100;
    s.enemies[0].hp = 2;
    final c = ai.choose(s, 'c');
    expect(c, isA<UltimateCommand>());
    expect((c as UltimateCommand).targetId, s.enemies[0].id);
  });

  test('aliado por debajo del 40 %: cura con habilidad si tiene maná', () {
    final s = battle(cls: 'maga');
    expect(s.party[1].skillIds, contains('cura'));
    s.party[0].hp = (s.party[0].maxHp * 0.3).floor();
    s.party[1].ult = 100; // curar va antes que la ULT
    expect(ai.choose(s, 'c'), isA<SkillCommand>());
    expect((ai.choose(s, 'c') as SkillCommand).skillId, 'cura');
  });

  test('sin habilidad de cura: poción al que tiene menos vida (caído = 0 %)',
      () {
    final s = battle(potions: 2);
    s.party[0].hp = 0;
    final c = ai.choose(s, 'c');
    expect(c, isA<ItemCommand>());
    expect((c as ItemCommand).item, BattleItem.potion);
    expect(c.targetPlayerId, 'yo');
  });

  test('sin maná ni pociones: ataca', () {
    final s = battle(cls: 'maga');
    s.party[0].hp = 1;
    s.party[1].mp = 0;
    expect(ai.choose(s, 'c'), isA<AttackCommand>());
  });

  test('determinística: el mismo estado elige lo mismo', () {
    final s = battle();
    s.enemies[2].hp = 4;
    final a = ai.choose(s, 'c') as SkillCommand;
    final b = ai.choose(s.copy(), 'c') as SkillCommand;
    expect([a.skillId, a.targetId], [b.skillId, b.targetId]);
  });

  group('combos (combo_balance.md § 5.2)', () {
    test('turno nuevo: prepara con su Instante (Brasa Fugaz)', () {
      final s = battle();
      final c = ai.choose(s, 'c') as SkillCommand;
      expect(c.skillId, 'brasaEco');
    });

    test('ya encadenó: no prepara otra vez, ataca', () {
      final s = battle()..party[1].chained = true;
      expect(ai.choose(s, 'c'), isA<AttackCommand>());
    });

    test('Fisurado y Pulso 2: Quebrar sobre él', () {
      final s = battle();
      s.enemies[1].fissured = true;
      s.party[1].pulse = 2;
      final c = ai.choose(s, 'c') as SkillCommand;
      expect([c.skillId, c.targetId], ['quebrar', s.enemies[1].id]);
    });

    test('Fisurado sin Pulso: no intenta Quebrar', () {
      final s = battle();
      s.enemies[1].fissured = true;
      s.party[1].pulse = 1;
      expect((ai.choose(s, 'c') as SkillCommand).skillId, isNot('quebrar'));
    });

    test('5+ Quemadura y Pulso 2: el Tirador detona Combustión', () {
      final s = battle(cls: 'tirador');
      s.enemies[2].statuses[StatusKind.burn] = 6;
      s.party[1].pulse = 2;
      final c = ai.choose(s, 'c') as SkillCommand;
      expect(c.targetId, s.enemies[2].id);
      expect(c.skillId, 'ponzonaEco');
    });

    test('prepara sin detonar antes de tiempo', () {
      // 2 de Quemadura en todos: la Flecha Venenosa no va a ninguno (los
      // detonaría con pocos stacks); prepara donde no hay nada.
      final s = battle(cls: 'tirador');
      for (final e in s.enemies.take(2)) {
        e.statuses[StatusKind.burn] = 2;
      }
      final c = ai.choose(s, 'c') as SkillCommand;
      expect([c.skillId, c.targetId], ['venenosa', s.enemies[2].id]);
    });
  });

  test('un id que no está o un enemigo: null', () {
    final s = battle();
    expect(ai.choose(s, 'nadie'), isNull);
    expect(ai.choose(s, s.enemies.first.id), isNull);
  });
}
