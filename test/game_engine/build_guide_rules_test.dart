import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_guide_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Árbol chico: el inicio se abre en una rama de ATQ (a1 → keystone a2)
/// y una de MAG con Quemadura (m1 → notable m2).
PassiveNode _n(String id, String kind, Map<String, num> fx, List<String> l) =>
    PassiveNode(
        id: id, x: 0, y: 0, name: id.toUpperCase(), effects: fx, kind: kind,
        links: l);

final _tree = PassiveTreeCatalog(
  nodes: {
    's': _n('s', 'st', const {}, ['a1', 'm1']),
    'a1': _n('a1', 's', const {'atk': 0.03}, ['s', 'a2']),
    'a2': _n('a2', 'k', const {'atk': 0.1}, ['a1']),
    'm1': _n('m1', 's', const {'mag': 0.03}, ['s', 'm2']),
    'm2': _n('m2', 'n', const {'burn': 1}, ['m1', 'x1']),
    'x1': _n('x1', 's', const {'hp': 0.03}, ['m2']),
  },
  startNodeByClass: {for (final c in kClasses.keys) c: 's'},
  exclusions: const {},
);

final _small = ProgressionRules(
    stats: StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(_tree)));
final _full = ProgressionRules(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)));

PlayerProfile _p(String cls, List<ItemInstance> items,
        {String? equipped, Map<Attribute, int> attrs = const {}, int lvl = 40}) =>
    PlayerProfile(
        name: 'Ana',
        classId: cls,
        level: lvl,
        items: items,
        equipped: equipped,
        attributes: PlayerAttributes(attrs));

const _plan = BuildPlan(treeNodes: ['a1', 'a2', 'm1', 'm2']);

void main() {
  group('orden del árbol (§ 9.2)', () {
    final g = BuildGuideRules(_small);

    test('con un báculo de fuego va primero la rama de MAG y Quemadura', () {
      final p = _p('maga', [ItemInstance.common('w', 'baculo_fuego')],
          equipped: 'w', attrs: const {Attribute.esp: 20});
      final o = g.treeOrder(_plan, p);
      expect(o.steps.map((s) => s.node), ['m1', 'm2', 'a1', 'a2']);
      expect(o.next!.node, 'm1');
      expect(o.next!.alternatives, 2);
      expect(o.next!.reason, contains('Báculo de Fuego'));
      expect(o.numbers, {'m1': 1, 'm2': 2, 'a1': 3, 'a2': 4});
    });

    test('con un hacha va primero la rama de ATQ', () {
      final p = _p('guerrero', [ItemInstance.common('w', 'hacha_tronante')],
          equipped: 'w', attrs: const {Attribute.fue: 50});
      final o = g.treeOrder(_plan, p);
      expect(o.steps.first.node, 'a1');
      expect(o.steps.map((s) => s.node).take(2), ['a1', 'a2']);
    });

    test('lo tomado no se numera; un nodo suelto se conecta', () {
      final p = _p('maga', [ItemInstance.common('w', 'baculo_fuego')],
              equipped: 'w')
          .copyWith(tree: const ['m1']);
      final o = g.treeOrder(const BuildPlan(treeNodes: ['x1']), p);
      expect(o.steps.map((s) => s.node), ['m2', 'x1']);
      expect(o.steps.first.onPlan, isFalse);
      expect(o.steps.first.reason, 'Conecta con X1');
    });

    test('sin plan no hay orden', () {
      expect(g.treeOrder(BuildPlan.empty, _p('maga', const [])).steps,
          isEmpty);
    });

    test('es determinista', () {
      final p = _p('maga', [ItemInstance.common('w', 'baculo_fuego')],
          equipped: 'w');
      expect(g.treeOrder(_plan, p).numbers, g.treeOrder(_plan, p).numbers);
    });
  });

  group('armas recomendadas (§ 9.3)', () {
    final g = BuildGuideRules(_full);

    test('con FUE alta, el hacha gana al báculo y dice por qué', () {
      final p = _p('guerrero', [
        ItemInstance.common('b', 'baculo_fuego'),
        ItemInstance.common('h', 'hacha_tronante'),
      ], attrs: const {Attribute.fue: 50, Attribute.vit: 10});
      final r = g.rankItems(BuildPlan.empty, p);
      expect(r.first.base.id, 'hacha_tronante');
      expect(r.first.recommended, isTrue);
      expect(r.first.reasons, contains(startsWith('Usa FUE, que tenés alta')));
      expect(r.first.meets, isTrue);
      final staff = r.firstWhere((w) => w.base.id == 'baculo_fuego');
      expect(staff.meets, isFalse);
      expect(staff.reasons.last, startsWith('Te faltan'));
    });

    test('lo que pide el plan suma y lo nombra', () {
      final p = _p('guerrero', [
        ItemInstance.common('b', 'baculo_fuego'),
        ItemInstance.common('h', 'hacha_tronante'),
      ], attrs: const {Attribute.esp: 20, Attribute.fue: 50});
      const plan = BuildPlan(weaponBases: ['baculo_fuego']);
      final r = g.rankItems(plan, p);
      final staff = r.firstWhere((w) => w.base.id == 'baculo_fuego');
      expect(staff.reasons.first, 'Del plan: base del plan');
    });

    test('armería: nivel insuficiente lo dice; recomienda como mucho 3', () {
      final p = _p('guerrero', const [],
          attrs: const {Attribute.fue: 60}, lvl: 10);
      final r = g.rankBases(BuildPlan.empty, p,
          kWeapons.values.where((w) => w.classId == 'guerrero'));
      expect(r.where((w) => w.recommended).length, 3);
      final far = r.firstWhere((w) => w.base.level > 10);
      expect(far.reasons, contains('Nivel ${far.base.level}'));
      expect(r.where((w) => w.recommended).every((w) => w.meets), isTrue);
    });
  });
}
