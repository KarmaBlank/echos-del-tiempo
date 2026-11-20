import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/build_templates_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/build_wants.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_plan_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_template_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/rules/weapon_target_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/build_templates_fixture.dart';

final _progression = ProgressionRules(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)));
final _tr = WeaponTargetRules(_progression);
final _plans = BuildPlanRules(_progression);
final _tpl = BuildTemplateRules(_progression);

/// Objetivo del spec (§ 2.4): Hacha Tronante Épica.
const _target = WeaponTarget(
  base: 'hacha_tronante',
  rarity: Rarity.epico,
  slots: 6,
  itemLevel: 40,
  mods: [ModGoal('feroz', 2), ModGoal('letal', 3)],
  passive: 'conmocion',
  passiveLevel: 3,
  skills: ['golpeTrueno', 'tajoMarea'],
  forge: {UpgradeStat.pow: 2},
  keepQuebrar: false,
);

PlayerProfile _p(List<ItemInstance> items, {String? equipped}) =>
    _progression.normalize(PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        level: 40,
        items: items,
        equipped: equipped));

void main() {
  setUpAll(installBuildTemplates);

  group('requisitos y % (§ 1.3)', () {
    test('base, rareza, mods con peor tier, pasiva, habilidad, nivel y forja',
        () {
      const it = ItemInstance(
        uid: 'a',
        baseId: 'hacha_tronante',
        rarity: Rarity.raro,
        itemLevel: 20,
        affixes: [AffixRoll('feroz', 4, 10)],
      );
      final m = _tr.match(_target, it);
      expect(m.req('base')!.value, 1);
      expect(m.req('rarity')!.value, closeTo(3 / 4, 1e-9));
      // Feroz T4 contra T2: (6-4)/(6-2) = 0.5.
      expect(m.req('mod:feroz')!.value, closeTo(0.5, 1e-9));
      expect(m.req('mod:letal')!.value, 0);
      expect(m.req('passive')!.value, 0);
      expect(m.req('skill:golpeTrueno')!.value, 1);
      expect(m.req('skill:tajoMarea')!.value, 0);
      expect(m.req('ilvl')!.value, closeTo(0.5, 1e-9));
      expect(m.req('forge')!.value, 0);
      expect(m.percent, inExclusiveRange(1, 100));
      expect(m.missing, greaterThan(3));
    });

    test('otra base del mismo tipo vale la mitad; otro tipo, 0', () {
      const same = ItemInstance(uid: 'b', baseId: 'hacha_rompe');
      const other = ItemInstance(uid: 'c', baseId: 'espada_bronce');
      expect(_tr.match(_target, same).req('base')!.value, 0.5);
      expect(_tr.match(_target, other).req('base')!.value, 0);
    });

    test('sin perfil no cuentan las estadísticas (lo del anfitrión)', () {
      final t = _target.copyWith(stats: {'atk': 140});
      const it = ItemInstance(uid: 'a', baseId: 'hacha_tronante');
      expect(_tr.match(t, it).req('stat:atk'), isNull);
      final p = _p(const [it]);
      expect(_tr.match(t, it, viewer: p).req('stat:atk'), isNotNull);
    });
  });

  group('candidatas, alijo y qué te falta', () {
    const target = ItemInstance(
        uid: 't',
        baseId: 'hacha_tronante',
        rarity: Rarity.epico,
        itemLevel: 40,
        passiveId: 'espinas');
    const donorInv = ItemInstance(
        uid: 'd1',
        baseId: 'hacha_rompe',
        rarity: Rarity.raro,
        itemLevel: 30,
        affixes: [AffixRoll('feroz', 3, 20)]);
    const donorStash = ItemInstance(
        uid: 'd2',
        baseId: 'hacha_rompe',
        rarity: Rarity.raro,
        itemLevel: 40,
        affixes: [AffixRoll('feroz', 1, 30)]);
    const coral = ItemInstance(uid: 'cor', baseId: 'espada_coral');

    test('el alijo cuenta, va marcado y no gana el empate', () {
      final p = _p(const [target, donorInv, coral]);
      final c = _tr.candidates(_target, p, stash: const [donorStash]);
      expect(c.first.item.uid, 't');
      final st = c.firstWhere((m) => m.item.uid == 'd2');
      expect(st.inStash, isTrue);
      expect(c.where((m) => m.inStash).length, 1);
    });

    test('el mejor donante tiene el mejor tier; si está en el alijo, se dice',
        () {
      final p = _p(const [target, donorInv, coral]);
      final best = _tr.best(_target, p, stash: const [donorStash])!;
      final lines = _tr.missing(_target, best, p, stash: const [donorStash]);
      final feroz = lines.firstWhere((l) => l.key == 'mod:feroz');
      expect(feroz.sourceUid, 'd2');
      expect(feroz.sourceInStash, isTrue);
      expect(feroz.text, contains('[ALIJO]'));
      expect(feroz.op, CraftOp.transferAffix);
      // Sin alijo, el del inventario.
      final inv = _tr.missing(_target, best, p)
          .firstWhere((l) => l.key == 'mod:feroz');
      expect(inv.sourceUid, 'd1');
      expect(inv.sourceInStash, isFalse);
      // Habilidad: Tajo de Marea desde la Espada de Coral.
      final skill = lines.firstWhere((l) => l.key == 'skill:tajoMarea');
      expect(skill.sourceUid, 'cor');
      expect(skill.text, contains('Cristal'));
      // Pasiva distinta y nadie la tiene.
      expect(lines.firstWhere((l) => l.key == 'passive').text,
          contains('Golpe Conmocionante'));
    });

    test('rareza baja: costos de Prismas y Condensar (economía v0.15)', () {
      const raro = ItemInstance(
          uid: 'r', baseId: 'hacha_tronante', rarity: Rarity.raro);
      final p = _p(const [raro]);
      final best = _tr.best(_target, p)!;
      final r = _tr.missing(_target, best, p)
          .firstWhere((l) => l.key == 'rarity');
      expect(r.text, contains('6 Prisma'));
      expect(r.text, contains('Condensar'));
      expect(r.materials[CraftMaterial.prisma], 6);
      expect(r.credits, 800);
    });

    test('plan de fusión: rareza, mods, pasiva, habilidades y forja', () {
      const raro = ItemInstance(
          uid: 'r', baseId: 'hacha_tronante', rarity: Rarity.raro);
      final p = _p(const [raro, donorInv, coral]);
      final best = _tr.best(_target, p)!;
      final plan = _tr.fusionPlan(_target, best, p);
      final kinds = [for (final s in plan.steps) s.forge ? 'forge' : s.op!.name];
      expect(kinds.first, 'upgradeRarity');
      expect(kinds.last, 'forge');
      expect(kinds.indexOf('transferAffix'),
          lessThan(kinds.indexOf('transferSkill')));
      expect(plan.credits, greaterThan(0));
    });
  });

  group('validación (§ 1.2)', () {
    test('afijo fuera del tipo, tier sin nivel, cupos y pasiva', () {
      final bad = _target.copyWith(
        mods: const [
          ModGoal('arcano', 3),
          ModGoal('feroz', 1),
        ],
        itemLevel: () => 30,
        forge: {UpgradeStat.pow: 5, UpgradeStat.crit: 5},
      );
      final e = _tr.validate(bad);
      expect(e, contains('Arcano no sale en hacha'));
      expect(e, contains('Feroz T1 pide nivel de objeto 40'));
      expect(e.any((x) => x.contains('forja 8')), isTrue);
      final caster = _target.copyWith(skills: const ['tajoMarea']);
      expect(_tr.validate(caster.copyWith(base: () => 'tomo_tiempo', type: () => 'tomo')),
          anyElement(contains('solo cuerpo a cuerpo')));
    });

    test('requisito de la base con los atributos del plan', () {
      final e = _tr.validate(_target,
          attributes: const PlayerAttributes({Attribute.fue: 30}));
      expect(e, anyElement(contains('Pide FUE 44')));
    });
  });

  test('buscador: por habilidad y filtros (§ 1.1)', () {
    final r = _tr.searchBases(const BaseQuery(text: 'trueno'));
    expect(r.map((w) => w.id), contains('hacha_tronante'));
    final casters = _tr.searchBases(
        const BaseQuery(categories: {WeaponCategory.caster}, maxLevel: 10));
    expect(casters, isNotEmpty);
    expect(casters.every((w) => w.level <= 10), isTrue);
    expect(
        casters.every((w) => ['báculo', 'tomo', 'varita'].contains(w.type)),
        isTrue);
    final usable = _tr.searchBases(const BaseQuery(usableAt: 5));
    expect(usable.every((w) => w.level <= 5), isTrue);
  });

  group('plan v2', () {
    test('JSON ida y vuelta; un plan v1 sigue en v1', () {
      final t = buildTemplate('gue_tormenta_filo')!;
      final plan = _tpl.follow(BuildPlan.empty, t);
      expect(plan.version, 2);
      final back = BuildPlan.fromJson(jsonDecode(jsonEncode(plan.toJson())))!;
      expect(back, plan);
      expect(back.weaponTargets.length, t.weapons.length);
      expect(back.timeline, plan.timeline);
      expect(back.attrSpans, plan.attrSpans);
      expect(back.ultActive, t.ultActive);
      const v1 = BuildPlan(name: 'viejo', skills: ['hendir']);
      expect(v1.toJson()['v'], 1);
    });

    test('ULT, mejoras y hazañas son metas', () {
      final plan = _tpl.follow(BuildPlan.empty, buildTemplate('gue_berserker')!);
      final p = _p(const []);
      final r = _plans.evaluate(plan, p);
      expect(r.byKey('ult'), isNotNull);
      expect(r.byKey('ultUp:ult2_sangreEco'), isNotNull);
      expect(r.byKey('feat:tree_milestone'), isNotNull);
      expect(r.section(BuildSection.ult), isNotEmpty);
      expect(r.byKey('wt:0'), isNotNull);
    });

    test('árbol por nivel: TOMAR SIGUIENTE y el tramo de atributos', () {
      final plan = _tpl.follow(BuildPlan.empty, buildTemplate('gue_berserker')!);
      final p = _p(const []);
      final id = _plans.nextTreeNode(plan, p);
      expect(id, isNotNull);
      expect(_progression.treeRules.pathTo('guerrero', p.passiveProgress, id!),
          [id]);
      expect(plan.spanAttributeAt(5), Attribute.fue);
      expect(plan.spanAttributeAt(20), Attribute.vit);
    });

    test('COMPARAR al nivel', () {
      final t = buildTemplate('gue_berserker')!;
      final lines = _tpl.compare(t, const {}, _p(const []).attributes, 20);
      expect(lines.first, startsWith('Te faltan'));
    });
  });

  group('import y export', () {
    test('lo importado con id del juego se renombra; lo roto se descarta', () {
      final t = buildTemplate('gue_berserker')!;
      final text = BuildTemplateYaml.write([t]);
      final f = BuildTemplateYaml.parse(text, imported: true);
      final added = BuildTemplates.addImported(f.templates);
      addTearDown(BuildTemplates.clearImported);
      expect(added.single.id, 'gue_berserker_imp');
      expect(added.single.imported, isTrue);
      expect(buildTemplate('gue_berserker')!.imported, isFalse);
      final broken = BuildTemplateYaml.parse('templates: [{id: "X Y"}]');
      expect(broken.templates, isEmpty);
      expect(broken.issues, isNotEmpty);
      expect(BuildTemplateYaml.parse(':::').templates, isEmpty);
    });
  });

  group('BuildMejora (§ 1.4)', () {
    const fr = LootFilterRules();
    final plan = BuildPlan(weaponTargets: [
      _target.copyWith(stats: {'atk': 140})
    ]);

    test('el resumen lleva el objetivo sin estadísticas y viaja acotado', () {
      final w = BuildWants.fromPlan(plan, best: 40);
      expect(w.target!.stats, isEmpty);
      final back = BuildWants.fromJson(jsonDecode(jsonEncode(w.toJson())));
      expect(back, w);
      expect(back.best, 40);
      // Un plan v1 manda lo mismo que antes.
      const v1 = BuildPlan(skills: ['hendir']);
      expect(BuildWants.fromPlan(v1).toJson().containsKey('wt'), isFalse);
      final big = BuildWants.fromJson({
        'wt': {
          'base': 'x' * 200,
          'mods': [
            for (var i = 0; i < 60; i++) ['m$i', 3]
          ],
        },
        'best': 900,
      });
      expect(big.target!.base, isNull);
      expect(big.target!.mods.length, BuildWants.maxEntries);
      expect(big.best, 100);
    });

    test('se lee, se escribe y coincide solo si mejora', () {
      final r = fr.parse('Mostrar\n  BuildMejora\nOcultar\n  BuildMejora No\n');
      expect(r.ok, isTrue);
      final text = fr.serialize(r.filter);
      expect(text, contains('BuildMejora'));
      expect(text, contains('BuildMejora No'));
      const good = ItemInstance(
          uid: 'g',
          baseId: 'hacha_tronante',
          rarity: Rarity.epico,
          itemLevel: 40);
      const bad = ItemInstance(uid: 'b', baseId: 'espada_bronce');
      final score = (_tr.score(_target, good) * 100).round();
      FilterContext ctx(int best) => FilterContext(
          level: 40,
          attributes: const PlayerAttributes({}),
          wants: BuildWants.fromPlan(plan, best: best));
      const cond = BuildUpgradeCondition();
      expect(fr.matches(cond, const LootDrop.item(good), ctx(score - 1)),
          isTrue);
      expect(fr.matches(cond, const LootDrop.item(good), ctx(score)),
          isFalse);
      expect(fr.matches(cond, const LootDrop.item(bad), ctx(score)), isFalse);
      // Sin objetivo v2 no coincide nunca (ni `BuildMejora No`).
      final none = FilterContext(
          level: 40,
          attributes: const PlayerAttributes({}),
          wants: BuildWants.fromPlan(const BuildPlan(skills: ['hendir'])));
      expect(
          fr.matches(const BuildUpgradeCondition(has: false),
              const LootDrop.item(bad), none),
          isFalse);
    });

    test('aviso del loot: requisito que te falta o % mayor', () {
      const mine = ItemInstance(uid: 'm', baseId: 'hacha_rompe');
      final p = _p(const [mine]);
      final best = _tr.best(_target, p);
      const drop = ItemInstance(
          uid: 'x',
          baseId: 'hacha_tronante',
          rarity: Rarity.epico,
          affixes: [AffixRoll('feroz', 2, 25)]);
      expect(_tr.lootNote(_target, drop, best), startsWith('★'));
      expect(_tr.lootNote(_target, mine, best), isNull);
    });
  });
}
