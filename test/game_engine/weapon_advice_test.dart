import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_guide_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

final _full = ProgressionRules(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)));

PassiveNode _n(String id, String kind, Map<String, num> fx, List<String> l) =>
    PassiveNode(
        id: id, x: 0, y: 0, name: id.toUpperCase(), effects: fx, kind: kind,
        links: l);

final _small = ProgressionRules(
    stats: StatsCalculator(
        classes: kClasses,
        treeRules: PassiveTreeRules(PassiveTreeCatalog(
          nodes: {
            's': _n('s', 'st', const {}, ['a1', 'm1']),
            'a1': _n('a1', 's', const {'atk': 0.03}, ['s', 'a2']),
            'a2': _n('a2', 'k', const {'atk': 0.1}, ['a1']),
            'm1': _n('m1', 's', const {'mag': 0.03}, ['s', 'm2']),
            'm2': _n('m2', 'n', const {'mag': 0.1}, ['m1']),
          },
          startNodeByClass: {for (final c in kClasses.keys) c: 's'},
          exclusions: const {},
        ))));

PlayerProfile _p(List<ItemInstance> items,
        {String? equipped,
        Map<Attribute, int> attrs = const {Attribute.fue: 50, Attribute.des: 20},
        int lvl = 40,
        String cls = 'guerrero'}) =>
    PlayerProfile(
        name: 'Ana',
        classId: cls,
        level: lvl,
        items: items,
        equipped: equipped,
        attributes: PlayerAttributes(attrs));

void main() {
  final g = BuildGuideRules(_full);

  test('sin armas ni armería: nada que recomendar, pero hay tipo ideal', () {
    final a = g.advice(BuildPlan.empty, _p(const []), shop: const []);
    expect(a.best, isNull);
    expect(a.upgrade, isNull);
    expect(a.buy, isNull);
    expect(a.idealTypes, isNotEmpty);
    expect(a.idealReason, isNotEmpty);
  });

  test('tipo ideal: la base del plan manda y nombra su atributo', () {
    const plan = BuildPlan(weaponBases: ['baculo_fuego']);
    final a = g.advice(plan, _p(const []), shop: const []);
    expect(a.idealTypes, ['báculo']);
    expect(a.idealReason, startsWith('Base de tu plan: Báculo de Fuego'));
    expect(a.idealAttribute, isNotNull);
  });

  test('mejor que tenés: la más fuerte, avisa si no está equipada', () {
    final p = _p([
      ItemInstance.common('a', 'espada_bronce'),
      ItemInstance.common('b', 'espada_templada', itemLevel: 14),
    ], equipped: 'a');
    final a = g.advice(BuildPlan.empty, p, shop: const []);
    expect(a.best!.item!.uid, 'b');
    expect(a.best!.equipped, isFalse);
  });

  test('empate: gana la equipada; sin equipada, el uid', () {
    final items = [
      ItemInstance.common('a', 'espada_templada'),
      ItemInstance.common('b', 'espada_templada'),
    ];
    expect(g.advice(BuildPlan.empty, _p(items, equipped: 'b'), shop: const [])
        .best!.item!.uid, 'b');
    expect(g.advice(BuildPlan.empty, _p(items), shop: const [])
        .best!.item!.uid, 'a');
  });

  test('requisitos: no recomienda como mejor la que no podés usar', () {
    final p = _p([
      ItemInstance.common('a', 'espada_bronce'),
      ItemInstance.common('h', 'hacha_tronante', itemLevel: 34),
    ], lvl: 10, attrs: const {Attribute.fue: 20});
    final a = g.advice(BuildPlan.empty, p, shop: const []);
    expect(a.best!.base.id, 'espada_bronce');
    expect(a.best!.meets, isTrue);
  });

  test('forja: proyecta POT hasta el tope de rareza con su costo', () {
    final w = kWeapons['espada_templada']!;
    final p = _p([
      ItemInstance.common('a', 'espada_templada'),
      const ItemInstance(
          uid: 'b',
          baseId: 'espada_templada',
          rarity: Rarity.raro,
          itemLevel: 30),
    ], equipped: 'a');
    final a = g.advice(BuildPlan.empty, p, shop: const []);
    final up = a.upgrade!;
    expect(up.pick.item!.uid, 'b');
    expect(up.levels, WeaponUpgradeLevels.upMax);
    var cost = 0;
    for (var l = 0; l < up.levels; l++) {
      cost += CraftRules.forgeCost(w, Rarity.raro, l);
    }
    expect(up.credits, cost);
    expect(up.gain, greaterThan(0));
  });

  test('forja: un arma ya al tope no se sugiere', () {
    final p = _p([
      const ItemInstance(
          uid: 'a',
          baseId: 'espada_templada',
          itemLevel: 1,
          forge: WeaponUpgradeLevels(pow: 2)),
    ], equipped: 'a');
    expect(BuildGuideRules.forgeRoom(kWeapons['espada_templada']!,
            p.items.first).$1, 0);
    expect(g.advice(BuildPlan.empty, p, shop: const []).upgrade, isNull);
  });

  test('armería: sugiere una base que le gana a lo que tenés', () {
    final p = _p([ItemInstance.common('a', 'espada_bronce')], equipped: 'a');
    final a = g.advice(BuildPlan.empty, p);
    expect(a.buy, isNotNull);
    expect(a.buy!.meets, isTrue);
    expect(a.buyGain, greaterThanOrEqualTo(0.2 - 1e-9));
    expect(a.buy!.base.classId, 'guerrero');
  });

  test('armería: si lo que tenés es lo mejor, no sugiere comprar', () {
    final p = _p([ItemInstance.common('a', 'espada_templada', itemLevel: 14)],
        equipped: 'a');
    final a = g.advice(BuildPlan.empty, p,
        shop: [kWeapons['espada_ignea']!]);
    expect(a.buy, isNull);
  });

  test('tipo elegido: filtra las 3 líneas y arma el "Cómo armarlo"', () {
    final p = _p([ItemInstance.common('a', 'espada_bronce')], equipped: 'a');
    const plan = BuildPlan(chosenType: 'lanza');
    final a = g.advice(plan, p);
    expect(a.chosenType, 'lanza');
    expect(a.activeType, 'lanza');
    expect(a.best, isNull);
    expect(a.buy?.base.type, anyOf(isNull, 'lanza'));
    expect(a.allTypes, containsAll(['lanza', 'espada', 'báculo']));
    expect(a.howTo.first, startsWith('Subí '));
  });

  test('tipo elegido desconocido: se ignora', () {
    final a = g.advice(const BuildPlan(chosenType: 'nada'), _p(const []),
        shop: const []);
    expect(a.chosenType, isNull);
  });

  test('Cómo armarlo: nodos que encajan y los que no rinden', () {
    final s = BuildGuideRules(_small);
    const plan = BuildPlan(treeNodes: ['a1', 'a2', 'm1', 'm2']);
    final h = s.howTo(plan, _p(const [], cls: 'maga'), 'báculo');
    expect(h.any((l) => l.startsWith('Te sirven del árbol:') && l.contains('M2')),
        isTrue);
    expect(h.any((l) => l.startsWith('No rinden con BÁCULO:') && l.contains('A2')),
        isTrue);
  });

  test('el tipo elegido viaja en el JSON del plan (y uno viejo no lo trae)',
      () {
    const plan = BuildPlan(chosenType: 'arco');
    expect(BuildPlan.fromJson(plan.toJson())!.chosenType, 'arco');
    expect(BuildPlan.fromJson(const BuildPlan().toJson())!.chosenType, isNull);
    expect(const BuildPlan(chosenType: 'arco').goalCount, 0);
  });
}
