// v0.20.12: restaurar el Quebrar propio (loot.md § 16.3.1), marcas de
// build en los traslados (build_planner.md § 9.6) y el texto del afijo
// Quebrantador con su habilidad.

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/break_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_guide_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart' show progression;

final _craft = progression.crafting;
final _items = progression.items;
final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

PlayerProfile _profile(List<ItemInstance> items, String equipped) =>
    progression.normalize(PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        credits: 10000,
        items: items,
        equipped: equipped));

List<String> _kit(ItemInstance w) =>
    BattleEngine(stats: _stats, random: () => 0.5)
        .start(party: [
          BattlePartyMember(
              id: 'p1',
              name: 'Ana',
              build: progression.buildOf(_profile([w], w.uid))),
        ], enemyTypes: const ['slime'])
        .state
        .party
        .single
        .skillIds;

/// Una espada que cambió Quebrar por Daga Saltarina.
PlayerProfile _replaced() {
  final p = _profile(const [
    ItemInstance(uid: 'w', baseId: 'espada_bronce', extraSkills: ['tajoGemelo']),
    ItemInstance(uid: 'd', baseId: 'dagas_cobre'),
    ItemInstance(uid: 'x', baseId: 'dagas_cobre'),
  ], 'x');
  return _craft
      .transferSkill(p, 'w', 'd', 'dagaSaltarina', replaceSkillId: kQuebrarId)
      .profile!;
}

void main() {
  group('restaurar Quebrar (loot.md § 16.3.1)', () {
    test('el propio sí; trasladar cualquier Quebrar no, con motivo claro', () {
      final w = _replaced().itemByUid('w')!;
      expect(w.quebrarReplaced, isTrue);
      expect(_items.canReceiveSkill(w, kQuebrarId),
          'Usá Restaurar Quebrar: no hace falta sacrificar un arma');
      expect(_items.canReceiveSkill(w, kQuebrarArcanoId),
          'Solo podés restaurar el Quebrar propio de esta arma');
    });

    test('cupos llenos: hay que elegir cuál se pierde; cobra; batalla con Quebrar',
        () {
      final p = _replaced();
      expect(_craft.restoreQuebrar(p, 'w').error,
          'Elegí qué habilidad deja su ranura');
      final r = _craft.restoreQuebrar(p, 'w', replaceSkillId: 'dagaSaltarina');
      expect(r.ok, isTrue, reason: r.error);
      final after = r.after!;
      expect(after.quebrarReplaced, isFalse);
      expect(after.extraSkills, ['tajoGemelo']);
      expect(r.replacedSkillId, 'dagaSaltarina');
      expect(r.credits, CraftRules.restoreQuebrarCost(after.rarity));
      expect(r.credits, greaterThan(0));
      expect(r.consumed, isEmpty);
      expect(r.profile!.credits, p.credits - r.credits);
      expect(_items.skillsOf(after).last, kQuebrarId);
      expect(_kit(after), contains(kQuebrarId));
      // Por la acción (lo que valida el host).
      final a = _craft.apply(p, CraftOp.restoreQuebrar, 'w',
          replaceSkillId: 'tajoGemelo');
      expect(a.after!.extraSkills, ['dagaSaltarina']);
    });

    test('con lugar no pierde nada; sin reemplazo previo no se puede', () {
      final p = _profile(const [
        ItemInstance(uid: 'w', baseId: 'espada_bronce', quebrarReplaced: true),
        ItemInstance(uid: 'x', baseId: 'dagas_cobre'),
      ], 'x');
      final r = _craft.restoreQuebrar(p, 'w');
      expect(r.ok, isTrue, reason: r.error);
      expect(r.replacedSkillId, isNull);
      expect(r.lost, isEmpty);
      expect(_craft.restoreQuebrar(r.profile!, 'w').error, 'Ya tiene su Quebrar');
    });
  });

  group('marcas de build en traslados (build_planner.md § 9.6)', () {
    final guide = BuildGuideRules(progression);
    final p = _profile(
        const [ItemInstance(uid: 'w', baseId: 'espada_bronce')], 'w');

    test('sin plan no marca', () {
      expect(guide.skillFit(const BuildPlan(), p, 'cura'), isNull);
      expect(guide.passiveFit(const BuildPlan(), p, 'impetu'), isNull);
    });

    test('lo que pide el plan va; lo que no comparte nada, no', () {
      final fit =
          guide.skillFit(const BuildPlan(skills: ['cura']), p, 'cura')!;
      expect(fit.fits, isTrue);
      expect(fit.reason, 'Tu plan la pide');
      const plan = BuildPlan(weaponBases: ['espada_bronce']);
      expect(guide.skillFit(plan, p, 'tajoGemelo')!.fits, isTrue);
      final no = guide.skillFit(plan, p, 'cura')!;
      expect(no.fits, isFalse);
      expect(no.reason, contains('curas'));
      expect(
          guide
              .passiveFit(const BuildPlan(weaponPassive: 'impetu'), p, 'impetu')!
              .fits,
          isTrue);
    });
  });

  group('Quebrantador nombra su habilidad', () {
    test('con arma: el nombre; sin arma: el genérico', () {
      const it = ItemInstance(
          uid: 'w',
          baseId: 'espada_bronce',
          rarity: Rarity.magico,
          affixes: [AffixRoll('quebrantador', 1, 1)]);
      final w = _items.baseOf(it)!;
      final name = kSkills[BreakRules.modSkillOf(w)]!.name;
      expect(_items.affixText(it.affixes.first, on: it),
          '$name puede quebrar (T1)');
      expect(_items.affixText(it.affixes.first),
          'Habilidad principal: puede quebrar (T1)');
      expect(ItemRules.breakSkillHelp, startsWith('Quebrantador:'));
    });
  });
}
