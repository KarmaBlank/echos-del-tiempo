import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/build_wants.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_plan_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Condición `Build` del filtro de loot (docs/specs/build_planner.md § 6,
/// loot.md § 13, netcode.md § "Build y filtro").
const _catalog = GameCatalog.standard;
final _planRules = BuildPlanRules(ProgressionRules(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree))));
const _filters = LootFilterRules();

ItemInstance _item(String base,
        {List<AffixRoll> affixes = const [],
        String? passive,
        List<String> skills = const [],
        Rarity rarity = Rarity.raro}) =>
    ItemInstance(
        uid: 'x',
        baseId: base,
        rarity: rarity,
        itemLevel: 10,
        affixes: affixes,
        passiveId: passive,
        extraSkills: skills);

FilterContext _ctx([BuildWants? w]) =>
    FilterContext(level: 10, attributes: const PlayerAttributes({}), wants: w);

void main() {
  final sword = _catalog.weapons['espada_ignea']!;

  group('resumen del plan (BuildWants)', () {
    const plan = BuildPlan(
      name: 'Mi build',
      notes: 'notas largas',
      attributes: {Attribute.fue: 40},
      treeNodes: ['sangre_n1'],
      weaponTypes: ['hacha'],
      weaponBases: ['espada_ignea'],
      mods: [ModGoal('feroz', 3)],
      weaponPassive: 'impetu',
      skills: ['hendir'],
      targetLevel: 50,
      checklist: [ChecklistItem('farmear')],
    );

    test('solo lo que mira itemFit (sin notas, checklist, árbol ni atributos)',
        () {
      final w = BuildWants.fromPlan(plan);
      expect(w.weaponTypes, ['hacha']);
      expect(w.weaponBases, ['espada_ignea']);
      expect(w.mods, [const ModGoal('feroz', 3)]);
      expect(w.weaponPassive, 'impetu');
      expect(w.skills, ['hendir']);
      expect(w.toJson().keys, unorderedEquals(['types', 'bases', 'mods', 'wp', 'skills']));
      final text = jsonEncode(w.toJson());
      expect(text, isNot(contains('notas')));
      expect(text, isNot(contains('farmear')));
      expect(BuildWants.fromPlan(BuildPlan.empty).isEmpty, isTrue);
      expect(BuildWants.fromPlan(const BuildPlan(targetLevel: 9)).isEmpty, isTrue);
    });

    test('JSON ida y vuelta; lectura acotada y tolerante', () {
      final w = BuildWants.fromPlan(plan);
      expect(BuildWants.fromJson(jsonDecode(jsonEncode(w.toJson()))), w);
      expect(BuildWants.fromJson('basura'), BuildWants.none);
      final big = BuildWants.fromJson({
        'types': [for (var i = 0; i < 100; i++) 't$i', 7, ''],
        'bases': ['x' * 200, 'ok'],
        'mods': [
          ['feroz', 9],
          ['feroz', 2],
          'mal'
        ],
        'wp': 3,
      });
      expect(big.weaponTypes, hasLength(BuildWants.maxEntries));
      expect(big.weaponBases, ['ok']);
      expect(big.mods, [const ModGoal('feroz', 5)], reason: 'tier acotado 1..5');
      expect(big.weaponPassive, isNull);
    });

    test('matches coincide con itemFit del planificador', () {
      final skill = sword.skillIds.first;
      final cases = <(BuildPlan, ItemInstance)>[
        (const BuildPlan(weaponBases: ['espada_ignea']), _item('espada_ignea')),
        (BuildPlan(weaponTypes: [sword.type]), _item('espada_ignea')),
        (const BuildPlan(weaponTypes: ['hacha']), _item('espada_ignea')),
        (
          const BuildPlan(mods: [ModGoal('feroz', 3)]),
          _item('espada_ignea', affixes: const [AffixRoll('feroz', 2, 9)])
        ),
        (
          const BuildPlan(mods: [ModGoal('feroz', 3)]),
          _item('espada_ignea', affixes: const [AffixRoll('feroz', 5, 4)])
        ),
        (
          const BuildPlan(mods: [ModGoal('feroz', 1)]),
          _item('espada_ignea', affixes: const [AffixRoll('feroz', 0, 25)])
        ),
        (const BuildPlan(weaponPassive: 'impetu'), _item('espada_ignea', passive: 'impetu')),
        (BuildPlan(skills: [skill]), _item('espada_ignea')),
        (const BuildPlan(skills: ['zzz']), _item('espada_ignea', skills: const ['zzz'])),
        (const BuildPlan(skills: ['zzz']), _item('espada_ignea')),
      ];
      for (final (plan, it) in cases) {
        final fit = _planRules.itemFit(plan, it);
        final got = BuildWants.fromPlan(plan).matches(it, _catalog.weapons[it.baseId]);
        expect(got.isNotEmpty, fit.any, reason: '${plan.toJson()} vs ${it.toJson()}');
      }
    });
  });

  group('condición Build del filtro', () {
    test('parse / serialize con sus variantes y errores', () {
      final r = _filters.parse('''
Mostrar # build
  Build
  Build Mod Pasiva
  build tipo habilidad
  MiBuild No
''');
      expect(r.errors, isEmpty);
      expect(r.filter.rules.single.conditions, [
        const BuildCondition(),
        const BuildCondition(kinds: [BuildMatch.mod, BuildMatch.pasiva]),
        const BuildCondition(kinds: [BuildMatch.base, BuildMatch.habilidad]),
        const BuildCondition(has: false),
      ]);
      final text = _filters.serialize(r.filter);
      expect(text, contains('  Build Base Habilidad'));
      expect(text, contains('  Build No'));
      expect(_filters.parse(text).filter, r.filter);
      expect(_filters.parse('Mostrar\n  Build Rarisimo\n').errors.single,
          contains('línea 2'));
    });

    test('evaluación: cualquiera, por clase, No y sin plan', () {
      final f = _filters.parse('''
Ocultar # fuera
  Build No
Mostrar # mods
  Build Mod
  Color 1 2 3
Mostrar # algo
  Build
  Color 4 5 6
''').filter;
      final w = BuildWants.fromPlan(const BuildPlan(
          weaponTypes: ['hacha'], mods: [ModGoal('feroz', 3)]));
      final modded = LootDrop.item(
          _item('espada_ignea', affixes: const [AffixRoll('feroz', 1, 9)]));
      final plain = LootDrop.item(_item('espada_ignea'));
      final axe = _catalog.weapons.values.firstWhere((x) => x.type == 'hacha');
      final axeDrop = LootDrop.item(_item(axe.id));

      final a = _filters.evaluate(f, modded, _ctx(w));
      expect((a.visible, a.ruleIndex), (true, 1));
      expect(a.build, {BuildMatch.mod});
      final b = _filters.evaluate(f, axeDrop, _ctx(w));
      expect((b.visible, b.ruleIndex), (true, 2));
      expect(b.buildMatch, isTrue);
      final c = _filters.evaluate(f, plain, _ctx(w));
      expect((c.visible, c.ruleIndex, c.buildMatch), (false, 0, false));
      // Sin plan: ninguna regla de build coincide (ni `Build No`) y no hay ★.
      final d = _filters.evaluate(f, modded, _ctx());
      expect((d.visible, d.ruleIndex, d.buildMatch), (true, null, false));
      // Materiales: nunca.
      final m = _filters.evaluate(
          f, const LootDrop.stack(StackKind.prisma, 1), _ctx(w));
      expect((m.ruleIndex, m.buildMatch), (null, false));
    });

    test('el filtro por defecto resalta lo de tu build (Mágico o más)', () {
      final w = BuildWants.fromPlan(const BuildPlan(weaponBases: ['espada_ignea']));
      final f = LootFilterRules.defaultFilter;
      final idx = f.rules.indexWhere((r) => r.name == 'Tu build');
      expect(idx, greaterThan(0));
      final v = _filters.evaluate(f, LootDrop.item(_item('espada_ignea')), _ctx(w));
      expect(v.ruleIndex, idx);
      expect(v.style.icon, const MapIcon(MapIconShape.estrella, MapIconColor.violeta));
      final common = _filters.evaluate(f,
          LootDrop.item(_item('espada_ignea', rarity: Rarity.comun)), _ctx(w));
      expect(common.ruleIndex, isNot(idx));
      expect(common.buildMatch, isTrue, reason: 'la ★ va igual');
      // Sin plan el por defecto se comporta como antes.
      final none = _filters.evaluate(f, LootDrop.item(_item('espada_ignea')), _ctx());
      expect(f.rules[none.ruleIndex!].name, 'Raros');
    });
  });

  group('red y host', () {
    test('acción wants: ida y vuelta; protocolo 7 (v0.6)', () {
      expect(kProtocolVersion, 7);
      final w = BuildWants.fromPlan(const BuildPlan(
          weaponTypes: ['hacha'], mods: [ModGoal('feroz', 2)], skills: ['hendir']));
      final j = ActionJson.toJson(SetBuildWantsAction(w));
      expect(j['t'], 'wants');
      final back = ActionJson.fromJson(jsonDecode(jsonEncode(j)) as Map<String, Object?>);
      expect((back as SetBuildWantsAction).wants, w);
      final clear = ActionJson.fromJson(
          jsonDecode(jsonEncode(ActionJson.toJson(const SetBuildWantsAction(null))))
              as Map<String, Object?>);
      expect((clear as SetBuildWantsAction).wants, isNull);
      // Por el códec del protocolo.
      final codec = WireCodec();
      final m = codec.decode(codec.encode(ActionMessage(SetBuildWantsAction(w))));
      expect(((m as ActionMessage).action as SetBuildWantsAction).wants, w);
    });

    test('el host guarda el plan por jugador; no viaja en el snapshot', () {
      final e = sessionEngine();
      var s = e.create();
      s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
      final w = BuildWants.fromPlan(const BuildPlan(weaponTypes: ['hacha']));
      s = act(e, s, 'p0', SetBuildWantsAction(w));
      expect(s.players['p0']!.buildWants, w);
      expect(s.copy().players['p0']!.buildWants, w);
      final json = jsonEncode(const SessionJson(GameCatalog.standard).toJson(s));
      expect(json, isNot(contains('hacha')));
      // Con la sala pausada también se acepta (no toca el mundo).
      s = act(e, s, 'p0', const PauseAction(true));
      s = act(e, s, 'p0', const SetBuildWantsAction(null));
      expect(s.players['p0']!.buildWants, isNull);
    });

    test('dos jugadores, planes distintos, el mismo drop: cada filtro con su plan',
        () {
      final e = sessionEngine(fieldFallback: 0.0);
      var s = inField(e, 'm1', classes: const ['guerrero', 'maga']);
      const filter = 'Mostrar # build\n  Build\nOcultar\n  Objeto Arma\n';
      for (final id in ['p0', 'p1']) {
        s = act(e, s, id, const SetLootFilterAction(filter));
      }
      const drop = LootDrop.item(ItemInstance(
          uid: 'mismo', baseId: 'espada_ignea', itemLevel: 1));
      s = act(e, s, 'p0',
          SetBuildWantsAction(BuildWants.fromPlan(BuildPlan(weaponTypes: [sword.type]))));
      s = act(e, s, 'p1',
          SetBuildWantsAction(BuildWants.fromPlan(const BuildPlan(weaponTypes: ['hacha']))));
      final p0 = s.players['p0']!, p1 = s.players['p1']!;
      expect(e.lootVerdict(p0.profile, drop, wants: p0.buildWants).visible, isTrue);
      expect(e.lootVerdict(p1.profile, drop, wants: p1.buildWants).visible, isFalse);

      // El auto-levantar del host usa el plan de cada dueño.
      s.ground
        ..clear()
        ..add(GroundLoot(id: 900, drop: drop, x: p0.x, y: p0.y, ownerId: 'p0'))
        ..add(GroundLoot(id: 901, drop: drop, x: p1.x, y: p1.y, ownerId: 'p1'));
      s = e.tick(s, 0.05).state;
      expect(s.ground.where((g) => g.id == 900), isEmpty, reason: 'p0 lo levanta');
      expect(s.ground.where((g) => g.id == 901), hasLength(1),
          reason: 'para p1 está oculto');
    });
  });
}
