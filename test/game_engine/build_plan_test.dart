import 'dart:convert';

import 'package:echos_del_tiempo/features/build_planner/domain/build_tracker.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/game_engine/data/affixes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/build_templates_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapon_passives.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_plan_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/build_templates_fixture.dart';

final _tree = PassiveTreeRules(kPassiveTree);
final _progression = ProgressionRules(
    stats: StatsCalculator(classes: kClasses, treeRules: _tree));
final _rules = BuildPlanRules(_progression);

PlayerProfile _guerrero({
  int level = 10,
  Map<Attribute, int>? attrs,
  List<String> tree = const [],
  List<ItemInstance>? items,
  String? equipped,
  AscensionProgress ascension = AscensionProgress.empty,
}) {
  // Puntos sin repartir = los del nivel menos los ya puestos (si no,
  // `normalize` reinicia los atributos).
  final spent = attrs == null
      ? 0
      : (attrs.values.fold<int>(0, (a, b) => a + b) -
              _baseAttrs.values.fold<int>(0, (a, b) => a + b)) ~/
          kAttrPerPoint;
  return _progression.normalize(PlayerProfile(
    name: 'Ana',
    classId: 'guerrero',
    level: level,
    attributes: attrs == null ? null : PlayerAttributes(attrs),
    points: (level - 1) * ProgressionRules.pointsPerLevel - spent,
    tree: tree,
    items: items,
    equipped: equipped,
    ascension: ascension,
  ));
}

const _baseAttrs = {
  Attribute.vit: 10,
  Attribute.esp: 4,
  Attribute.agi: 6,
  Attribute.fue: 12,
  Attribute.des: 6,
};

const _fullPlan = BuildPlan(
  name: 'Berserker',
  notes: 'pegar fuerte',
  templateId: 'gue_berserker',
  attributes: {Attribute.fue: 40, Attribute.vit: 20},
  treeNodes: ['gue_r1', 'sangre_k'],
  ascensionId: 'berserker',
  ascensionNodes: ['berserker_m11'],
  weaponTypes: ['hacha'],
  weaponBases: ['hacha_berserker'],
  mods: [ModGoal('feroz', 3)],
  weaponPassive: 'sedDelArma',
  skills: ['hendir'],
  targetLevel: 50,
  targetMastery: 5,
  checklist: [ChecklistItem('Farmear', done: true), ChecklistItem('Prismas')],
);

void main() {
  group('JSON', () {
    test('ida y vuelta de un plan completo', () {
      final json = jsonDecode(jsonEncode(_fullPlan.toJson()));
      final back = BuildPlan.fromJson(json)!;
      expect(back, _fullPlan);
      expect(back.mods.single.minTier, 3);
      expect(back.checklist.first.done, isTrue);
      expect(back.goalCount, _fullPlan.goalCount);
    });

    test('lectura tolerante: basura → valores por defecto', () {
      expect(BuildPlan.fromJson('x'), isNull);
      final p = BuildPlan.fromJson({
        'name': 3,
        'attr': {'FUE': 'a', 'VIT': -2, 'AGI': 12.7},
        'tree': ['a', 1, 'a', ''],
        'mods': [
          ['feroz', 9],
          [2],
          ['feroz', 1]
        ],
        'check': [
          ['  ', true],
          ['ok']
        ],
        'lvl': 'x',
      })!;
      expect(p.name, '');
      expect(p.attributes, {Attribute.agi: 12});
      expect(p.treeNodes, ['a']);
      expect(p.mods, [const ModGoal('feroz', 5)]);
      expect(p.checklist, [const ChecklistItem('ok')]);
      expect(p.targetLevel, isNull);
    });

    test('el slot guarda el plan y una cuenta vieja carga sin plan', () {
      final a =
          Account().add(PlayerProfile(name: 'Ana'))!.withPlan('c1', _fullPlan);
      final back = Account.fromJson(
          jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>);
      expect(back.byId('c1')!.plan, _fullPlan);
      // Cuenta de v0.4 (sin `plan`).
      final old = Account.fromJson({
        'v': 1,
        'sel': 'c1',
        'chars': [
          {'id': 'c1', 'p': PlayerProfile(name: 'Bo').toJson()}
        ],
      });
      expect(old.byId('c1')!.plan, isNull);
      // Un plan vacío no se escribe.
      final cleared = a.withPlan('c1', null).toJson();
      expect((cleared['chars'] as List).first, isNot(contains('plan')));
    });

    test('guardar el perfil desde la sesión conserva el plan', () async {
      final repo = AccountRepository(InMemoryAccountStore());
      await repo.update((a) => a.add(PlayerProfile(name: 'Ana'))!);
      await repo.update((a) => a.withPlan('c1', _fullPlan));
      await SelectedCharacterProfileStore(repo)
          .save(PlayerProfile(name: 'Ana', level: 7));
      expect(repo.current!.byId('c1')!.profile.level, 7);
      expect(repo.current!.byId('c1')!.plan, _fullPlan);
    });
  });

  group('evaluate', () {
    test('sin metas: siguiente paso por defecto', () {
      final r = _rules.evaluate(BuildPlan.empty, _guerrero());
      expect(r.goals, isEmpty);
      expect(r.next, contains('plantilla'));
    });

    test('atributos: actual/objetivo y hecho', () {
      final p = _guerrero(attrs: {..._baseAttrs, Attribute.fue: 33});
      final r = _rules.evaluate(
          const BuildPlan(attributes: {Attribute.fue: 40, Attribute.vit: 8}),
          p);
      final fue = r.byKey('attr:fue')!;
      expect(fue.state, GoalState.partial);
      expect((fue.current, fue.total), (33, 40));
      expect(r.byKey('attr:vit')!.state, GoalState.done);
    });

    test('nodo del árbol: hecho, faltan puntos y bloqueado', () {
      const plan = BuildPlan(treeNodes: ['gue_r1', 'sangre_k']);
      final none = _rules.evaluate(plan, _guerrero());
      expect(none.byKey('node:gue_r1')!.hint, 'falta 1 punto');
      final k = none.byKey('node:sangre_k')!;
      expect(k.state, GoalState.todo);
      expect(k.label, 'Keystone Furia de Sangre');
      expect(k.major, isTrue);
      final route =
          _tree.pathTo('guerrero', PlayerPassiveProgress.empty, 'sangre_k')!;
      expect(k.hint, 'faltan ${route.length} puntos');
      final taken = _rules.evaluate(plan, _guerrero(tree: ['gue_r1']));
      expect(taken.byKey('node:gue_r1')!.state, GoalState.done);
      // Nodo desconocido.
      expect(
          _rules
              .evaluate(const BuildPlan(treeNodes: ['nope']), _guerrero())
              .byKey('node:nope')!
              .state,
          GoalState.blocked);
    });

    test('nodo excluido por otra keystone: bloqueado', () {
      final ex = kPassiveTree.exclusions.entries.first;
      final path =
          _tree.pathTo('guerrero', PlayerPassiveProgress.empty, ex.value);
      if (path == null) return; // la exclusión es de otra zona
      final p = _guerrero(level: 50, tree: path);
      final g = _rules
          .evaluate(BuildPlan(treeNodes: [ex.key]), p)
          .byKey('node:${ex.key}')!;
      expect(g.state, GoalState.blocked);
    });

    test('ascensión y sus nodos', () {
      const plan =
          BuildPlan(ascensionId: 'berserker', ascensionNodes: ['berserker_m11']);
      var r = _rules.evaluate(plan, _guerrero(level: 30));
      expect(r.byKey('asc')!.state, GoalState.todo);
      expect(r.byKey('ascN:berserker_m11')!.state, GoalState.todo);
      r = _rules.evaluate(
          plan,
          _guerrero(
              level: 30, ascension: const AscensionProgress(trials: {1})));
      expect(r.byKey('asc')!.state, GoalState.partial);
      expect(r.next, contains('Berserker'));
      r = _rules.evaluate(
          plan,
          _guerrero(
              level: 30,
              ascension:
                  const AscensionProgress(trials: {1}, id: 'berserker')));
      expect(r.byKey('asc')!.state, GoalState.done);
      expect(r.byKey('ascN:berserker_m11')!.state, GoalState.partial);
      r = _rules.evaluate(
          plan,
          _guerrero(
              level: 30,
              ascension: const AscensionProgress(
                  trials: {1}, id: 'berserker', nodes: ['berserker_m11'])));
      expect(r.byKey('ascN:berserker_m11')!.state, GoalState.done);
      // La otra ascensión de la clase: bloqueada.
      r = _rules.evaluate(
          plan,
          _guerrero(
              level: 30,
              ascension:
                  const AscensionProgress(trials: {1}, id: 'senorGuerra')));
      expect(r.byKey('asc')!.state, GoalState.blocked);
      // De otra clase.
      expect(
          _rules
              .evaluate(const BuildPlan(ascensionId: 'cronomante'), _guerrero())
              .byKey('asc')!
              .state,
          GoalState.blocked);
    });

    test('tipo y base de arma: equipada, en el inventario o no', () {
      const plan =
          BuildPlan(weaponTypes: ['hacha'], weaponBases: ['hacha_rompe']);
      final strong = {..._baseAttrs, Attribute.fue: 30};
      var r = _rules.evaluate(plan, _guerrero(attrs: strong));
      expect(r.byKey('type:hacha')!.state, GoalState.todo);
      expect(r.byKey('base:hacha_rompe')!.hint, contains('Armería'));
      final items = [
        ItemInstance.common('espada_bronce', 'espada_bronce'),
        ItemInstance.common('h1', 'hacha_rompe'),
      ];
      r = _rules.evaluate(plan, _guerrero(attrs: strong, items: items));
      expect(r.byKey('type:hacha')!.state, GoalState.partial);
      expect(r.byKey('base:hacha_rompe')!.state, GoalState.partial);
      expect(r.next, contains('Equipá'));
      r = _rules.evaluate(
          plan, _guerrero(attrs: strong, items: items, equipped: 'h1'));
      expect(r.byKey('type:hacha')!.state, GoalState.done);
      expect(r.byKey('base:hacha_rompe')!.state, GoalState.done);
    });

    test('mods: tier mínimo, peor tier y en otra arma', () {
      const plan = BuildPlan(mods: [ModGoal('feroz', 3)]);
      ItemInstance sword(String uid, int tier) => ItemInstance(
          uid: uid,
          baseId: 'espada_bronce',
          // Los mods fijos (tier 0) son de los legendarios.
          rarity: tier == 0 ? Rarity.legendario : Rarity.magico,
          affixes: [AffixRoll('feroz', tier, 10)]);
      var r = _rules.evaluate(
          plan, _guerrero(items: [sword('a', 5)], equipped: 'a'));
      expect(r.byKey('mod:feroz')!.state, GoalState.partial);
      expect(r.byKey('mod:feroz')!.hint, contains('buscás T3'));
      r = _rules.evaluate(plan,
          _guerrero(items: [sword('a', 5), sword('b', 2)], equipped: 'a'));
      expect(r.byKey('mod:feroz')!.hint, contains('FUSIÓN'));
      r = _rules.evaluate(
          plan, _guerrero(items: [sword('a', 3)], equipped: 'a'));
      expect(r.byKey('mod:feroz')!.state, GoalState.done);
      // Mod fijo de un legendario (tier 0) cumple.
      expect(_rules.itemFit(plan, sword('a', 0)).matches, ['+10% ATQ (fijo)']);
      r = _rules.evaluate(plan, _guerrero());
      expect(r.byKey('mod:feroz')!.state, GoalState.todo);
    });

    test('pasiva de arma', () {
      const plan = BuildPlan(weaponPassive: 'filoResonante');
      const epic = ItemInstance(
          uid: 'e',
          baseId: 'espada_bronce',
          rarity: Rarity.epico,
          passiveId: 'filoResonante');
      var r = _rules.evaluate(plan, _guerrero());
      expect(r.byKey('wp')!.state, GoalState.todo);
      r = _rules.evaluate(
          plan,
          _guerrero(items: [
            ItemInstance.common('espada_bronce', 'espada_bronce'),
            epic,
          ]));
      expect(r.byKey('wp')!.state, GoalState.partial);
      r = _rules.evaluate(plan, _guerrero(items: [epic], equipped: 'e'));
      expect(r.byKey('wp')!.state, GoalState.done);
    });

    test('habilidades: arma equipada, otra arma, kit de ascensión', () {
      const plan = BuildPlan(skills: ['giro', 'hendir', 'sangria']);
      var r = _rules.evaluate(plan, _guerrero());
      // La Espada de Bronce da Corte Giratorio.
      expect(r.byKey('skill:giro')!.state, GoalState.done);
      expect(r.byKey('skill:hendir')!.state, GoalState.todo);
      expect(r.byKey('skill:hendir')!.hint, contains('la da'));
      expect(r.byKey('skill:sangria')!.hint, contains('Berserker'));
      r = _rules.evaluate(
          plan,
          _guerrero(
              level: 30,
              items: [
                ItemInstance.common('espada_bronce', 'espada_bronce'),
                ItemInstance.common('h', 'hacha_berserker'),
              ],
              ascension:
                  const AscensionProgress(trials: {1}, id: 'berserker')));
      expect(r.byKey('skill:hendir')!.state, GoalState.partial);
      expect(r.byKey('skill:sangria')!.state, GoalState.done);
    });

    test('nivel, maestría y checklist', () {
      const plan = BuildPlan(
          targetLevel: 20,
          targetMastery: 5,
          checklist: [ChecklistItem('a', done: true), ChecklistItem('b')]);
      final r = _rules.evaluate(plan, _guerrero(level: 12));
      expect((r.byKey('lvl')!.current, r.byKey('lvl')!.total), (12, 20));
      expect(r.byKey('ms')!.state, GoalState.todo);
      expect(r.byKey('check:0')!.state, GoalState.done);
      expect(r.byKey('check:1')!.state, GoalState.todo);
      expect(r.ratio, greaterThan(0));
      expect(r.ratio, lessThan(1));
    });

    test('siguiente paso: puntos de atributo y de árbol', () {
      // Nivel 4: 9 puntos, 8 en FUE → queda 1... nivel 5 (12): 9 en FUE.
      final p = _guerrero(level: 5, attrs: {..._baseAttrs, Attribute.fue: 18});
      var r = _rules.evaluate(
          const BuildPlan(
              attributes: {Attribute.fue: 40}, treeNodes: ['quiebre_na']),
          p);
      expect(r.next, 'Tenés 2 puntos: según tu build, FUE (18/40)');
      r = _rules.evaluate(
          const BuildPlan(treeNodes: ['quiebre_na']), _guerrero(level: 1));
      final n = _tree
          .pathTo('guerrero', PlayerPassiveProgress.empty, 'quiebre_na')!
          .length;
      expect(r.next, 'Te faltan $n puntos para Rompeguardias');
      r = _rules.evaluate(
          const BuildPlan(treeNodes: ['quiebre_na']), _guerrero(level: 5));
      expect(r.next, startsWith('Tomá '));
    });
  });

  group('diff y avisos', () {
    const plan = BuildPlan(
      attributes: {Attribute.fue: 60},
      treeNodes: ['gue_r1', 'gue_f3', 'sangre_na'],
      weaponBases: ['hacha_rompe'],
    );

    test('✓, progreso contable, todo → parcial; sin retrocesos', () {
      final before = _rules.evaluate(
          plan, _guerrero(attrs: {..._baseAttrs, Attribute.fue: 30}));
      final after = _rules.evaluate(
          plan,
          _guerrero(attrs: {
            ..._baseAttrs,
            Attribute.fue: 33
          }, tree: [
            'gue_r1',
            'gue_f3'
          ], items: [
            ItemInstance.common('espada_bronce', 'espada_bronce'),
            ItemInstance.common('h', 'hacha_rompe'),
          ]));
      final n = BuildPlanRules.diff(before, after).map((e) => e.text).toList();
      expect(n, contains('Build: FUE 33/60'));
      expect(n, contains('Build: árbol 2/3'));
      expect(n.any((t) => t.startsWith('Build: » Hacha Rompeturnos')), isTrue);
      // Al revés no avisa nada.
      expect(BuildPlanRules.diff(after, before), isEmpty);
    });

    test('notable o keystone: aviso propio con ✓', () {
      final path =
          _tree.pathTo('guerrero', PlayerPassiveProgress.empty, 'sangre_na')!;
      final before = _rules.evaluate(
          plan, _guerrero(level: 50, tree: path.sublist(0, path.length - 1)));
      final after = _rules.evaluate(plan, _guerrero(level: 50, tree: path));
      final n = BuildPlanRules.diff(before, after);
      expect(n.single.text, 'Build: ★ Notable Último Aliento');
      expect(n.single.done, isTrue);
    });

    test('tracker: base sin avisos, cambio de plan no avisa, tope', () {
      final t = BuildTracker(_rules,
          throttle: BuildNoticeThrottle(max: 2, windowS: 4));
      final p0 = _guerrero(attrs: {..._baseAttrs, Attribute.fue: 15});
      expect(t.observe(plan, p0, 0), isEmpty); // base
      final p1 = _guerrero(attrs: {..._baseAttrs, Attribute.fue: 18});
      expect(t.observe(plan, p1, 1), ['Build: FUE 18/60']);
      // Plan nuevo: base nueva, sin aviso.
      const plan2 = BuildPlan(attributes: {Attribute.fue: 18});
      expect(t.observe(plan2, p1, 2), isEmpty);
      final p2 = _guerrero(attrs: {..._baseAttrs, Attribute.fue: 21});
      expect(t.observe(plan, p2, 2.5), isEmpty); // otra vez otro plan
      final p3 = _guerrero(attrs: {..._baseAttrs, Attribute.fue: 24});
      expect(t.observe(plan, p3, 3), ['Build: FUE 24/60']);
      // Tope de 2 en 4 s (1 s y 3 s): el siguiente espera.
      final p4 = _guerrero(attrs: {..._baseAttrs, Attribute.fue: 27});
      expect(t.observe(plan, p4, 3.5), isEmpty);
      final p5 = _guerrero(attrs: {..._baseAttrs, Attribute.fue: 30});
      expect(t.observe(plan, p5, 5.5), ['Build: FUE 30/60']);
    });

    test('tope: lo que sobra se resume', () {
      final th = BuildNoticeThrottle(max: 3);
      final out = th.admit([
        for (var i = 0; i < 5; i++) BuildNotice('k$i', 'n$i', done: i == 4),
      ], 0);
      expect(out, ['n4', 'n0', 'Build: +3 avances']);
    });
  });

  group('encaje de un arma', () {
    test('base, tipo, mods, pasiva y habilidades', () {
      const plan = BuildPlan(
        weaponTypes: ['hacha'],
        weaponBases: ['hacha_berserker'],
        mods: [ModGoal('feroz', 3), ModGoal('del_vampiro', 2)],
        weaponPassive: 'sedDelArma',
        skills: ['hendir'],
      );
      const it = ItemInstance(
        uid: 'x',
        baseId: 'hacha_berserker',
        rarity: Rarity.epico,
        affixes: [AffixRoll('feroz', 2, 15), AffixRoll('del_vampiro', 4, 2)],
        passiveId: 'sedDelArma',
      );
      final fit = _rules.itemFit(plan, it);
      expect(fit.matches, [
        'base del plan',
        'tipo hacha',
        '+15% ATQ (T2)',
        'pasiva Sed del Arma',
        'Hendidura Tóxica',
      ]);
      expect(fit.near.single, contains('buscás T2'));
      expect(_rules.itemFit(BuildPlan.empty, it).isEmpty, isTrue);
    });

    test('fusión: lo que la acción agrega', () {
      const plan = BuildPlan(mods: [ModGoal('feroz', 5)]);
      const before = ItemInstance(uid: 'x', baseId: 'espada_bronce');
      final after = before.copyWith(affixes: [const AffixRoll('feroz', 4, 9)]);
      expect(_rules.advances(plan, before, after).matches, ['+9% ATQ (T4)']);
      expect(_rules.advances(plan, after, after).any, isFalse);
    });
  });

  group('plantillas', () {
    setUpAll(installBuildTemplates);

    test('5 por clase y sin metas bloqueadas para un personaje nuevo', () {
      const cat = GameCatalog.standard;
      for (final c in cat.classes.keys) {
        expect(buildTemplatesFor(c).length, 5, reason: c);
      }
      for (final t in kBuildTemplates) {
        final p = _rules.applyTemplate(BuildPlan.empty, t);
        expect(p.templateId, t.id);
        for (final n in p.treeNodes) {
          expect(kPassiveTree.nodes, contains(n), reason: '${t.id}: $n');
        }
        expect(kAscensions[p.ascensionId]!.classId, t.classId, reason: t.id);
        for (final m in p.mods) {
          expect(kAffixes[m.affixId], isNotNull, reason: '${t.id}: ${m.affixId}');
        }
        if (p.weaponPassive != null) {
          expect(kWeaponPassives[p.weaponPassive], isNotNull, reason: t.id);
        }
        final fresh = _progression
            .normalize(PlayerProfile(name: 'X', classId: t.classId));
        final r = _rules.evaluate(p, fresh);
        expect(r.goals.where((g) => g.state == GoalState.blocked), isEmpty,
            reason: t.id);
      }
    });

    test('aplicar completa el camino y conserva notas y checklist', () {
      final t = buildTemplate('gue_berserker')!;
      const mine = BuildPlan(
          notes: 'mis notas', checklist: [ChecklistItem('hacer algo')]);
      final p = _rules.applyTemplate(mine, t);
      expect(p.name, t.name);
      expect(p.notes, 'mis notas');
      // Lo tuyo se queda primero; lo de la plantilla se suma.
      expect(p.checklist.first, mine.checklist.first);
      expect(p.checklist.map((c) => c.text),
          containsAll(t.endgame.checklist));
      final route =
          _tree.pathTo('guerrero', PlayerPassiveProgress.empty, 'sangre_k')!;
      expect(p.treeNodes, containsAll(route));
      // El árbol por nivel va en orden de nivel.
      for (var i = 1; i < p.timeline.length; i++) {
        expect(p.timeline[i].level,
            greaterThanOrEqualTo(p.timeline[i - 1].level));
      }
      // Un nombre propio se queda; el de otra plantilla, no.
      expect(_rules.applyTemplate(mine.copyWith(name: 'Mío'), t).name, 'Mío');
      final other = buildTemplate('gue_quiebre')!;
      expect(_rules.applyTemplate(p, other).name, other.name);
    });
  });
}
