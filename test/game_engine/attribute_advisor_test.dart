import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/attribute_advisor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Recomendación de atributos (docs/specs/build_planner.md § 8).
final _rules = zoneProgression;
final _advisor = AttributeAdvisor(_rules);

PlayerProfile _p(String cls, int level, {Map<Attribute, int>? spend}) {
  var p = _rules.normalize(PlayerProfile(name: 'A', classId: cls, level: level));
  if (spend != null) p = _rules.allocate(p, spend)!;
  return p;
}

int _sum(List<AttrSuggestion> s) => s.fold(0, (a, x) => a + x.points);

/// Nodos del árbol con [key] en sus efectos.
List<String> _nodesWith(String key) => [
      for (final n in kPassiveTree.nodes.values)
        if (n.effects.containsKey(key) && n.kind != 'st') n.id,
    ]..sort();

void main() {
  test('sin puntos: vacío', () {
    final p = _p('guerrero', 1);
    expect(p.points, 0);
    expect(_advisor.recommend(p), isEmpty);
    expect(AttributeAdvisor.summary(const []), 'Sin puntos para repartir');
    expect(_advisor.recommend(_p('guerrero', 5), BuildPlan.empty, 0), isEmpty);
  });

  test('escala del arma: el atributo de su fórmula primero', () {
    // Espada de Bronce: 6 + FUE×0.6 + DES×0.2.
    final g = _p('guerrero', 2);
    final s = _advisor.recommend(g);
    expect(s.first.attribute, Attribute.fue);
    expect(s.first.kind, AttrSuggestionKind.scaling);
    expect(s.first.reasons.first,
        contains('ATQ por punto con tu Espada de Bronce (escala FUE×0.6)'));
    expect(_sum(s), 1);
    final sc = _advisor.scores(g, BuildPlan.empty);
    expect(sc[Attribute.fue]!.total, greaterThan(sc[Attribute.des]!.total));
    expect(sc[Attribute.des]!.total, greaterThan(sc[Attribute.esp]!.total));
    // Arco Corto: DES; Báculo de Aprendiz: ESP (MAG ESP×0.75).
    expect(_advisor.recommend(_p('tirador', 2)).first.attribute,
        Attribute.des);
    final m = _advisor.recommend(_p('maga', 2));
    expect(m.first.attribute, Attribute.esp);
    expect(m.first.reasons.first, contains('MAG'));
    expect(m.first.reasons.first, contains('ESP×0.75'));
  });

  test('requisito de un arma del plan: prioridad dura', () {
    // Hacha Rompeturnos (nivel 4): FUE 18; el guerrero arranca con 12.
    final g = _p('guerrero', 4);
    const plan = BuildPlan(weaponBases: ['hacha_rompe']);
    final s = _advisor.recommend(g, plan);
    expect(s.first.attribute, Attribute.fue);
    expect(s.first.kind, AttrSuggestionKind.requirement);
    expect(s.first.reasons.first,
        'Te faltan 6 FUE para equipar Hacha Rompeturnos');
    expect(s.first.points, greaterThanOrEqualTo(2));
    expect(_sum(s), g.points);
    expect(AttributeAdvisor.summary(s),
        startsWith('FUE +${s.first.points * 3}'));

    // Con menos puntos que el requisito: todos ahí, y lo dice.
    final few = _p('guerrero', 2);
    final f = _advisor.recommend(few, plan);
    expect(AttributeAdvisor.allocation(f), {Attribute.fue: 1});
    expect(f.single.reasons.first, contains('(nivel 4)'));
    expect(f.single.reasons.first, contains('después quedan 3'));

    // Un arma del plan muy lejos de tu nivel no es requisito duro.
    const far = BuildPlan(weaponBases: ['hacha_cataclismo']);
    expect(
        _advisor
            .recommend(g, far)
            .any((x) => x.kind == AttrSuggestionKind.requirement),
        isFalse);
  });

  test('el árbol cambia los pesos: crítico pide DES, vida pide VIT', () {
    final g = _p('guerrero', 10);
    final base = _advisor.scores(g, BuildPlan.empty);
    final critPlan = BuildPlan(treeNodes: _nodesWith('crit'));
    final crit = _advisor.scores(g, critPlan);
    expect(_advisor.needs(g, critPlan).weight(AdviceStat.crit),
        greaterThan(_advisor.needs(g, BuildPlan.empty).weight(AdviceStat.crit)));
    expect(crit[Attribute.des]!.total, greaterThan(base[Attribute.des]!.total));
    // Más DES respecto de FUE (los nodos de crítico a veces traen ATQ).
    expect(crit[Attribute.des]!.total / crit[Attribute.fue]!.total,
        greaterThan(base[Attribute.des]!.total / base[Attribute.fue]!.total));
    expect(crit[Attribute.des]!.reasons.join(' '), contains('tu árbol:'));

    final hpPlan = BuildPlan(treeNodes: _nodesWith('hp'));
    final hp = _advisor.scores(g, hpPlan);
    expect(hp[Attribute.vit]!.total, greaterThan(base[Attribute.vit]!.total));
    final s = _advisor.recommend(g, hpPlan);
    expect(s.any((x) => x.attribute == Attribute.vit), isTrue,
        reason: 'un árbol de vida pide VIT');
    expect(_advisor.recommend(g).any((x) => x.attribute == Attribute.vit),
        isFalse);
  });

  test('piso de supervivencia: VIT si la vida es baja para el nivel', () {
    // Maga nivel 10 sin VIT: 20 + 6×4 + 20 = 64 < 70.
    final m = _p('maga', 10);
    expect(_rules.derivedStats(m).maxHp, lessThan(AttributeAdvisor.survivalHp(10)));
    final s = _advisor.recommend(m);
    expect(s.first.attribute, Attribute.vit);
    expect(s.first.kind, AttrSuggestionKind.survival);
    expect(s.first.points, 1); // 6 HP / 12 por punto (+3 VIT)
    expect(s.first.reasons.first, contains('Tu vida (64)'));
    expect(_sum(s), m.points);

    // Con pocos puntos, como mucho la mitad (mínimo 1) va a VIT.
    final late = _p('maga', 25, spend: {Attribute.esp: 21});
    expect(late.points, 3);
    final l = _advisor.recommend(late);
    expect(AttributeAdvisor.allocation(l)[Attribute.vit], 1);
    expect(_sum(l), 3);

    // El guerrero nivel 10 tiene vida de sobra: nada de VIT.
    expect(
        _advisor
            .recommend(_p('guerrero', 10))
            .any((x) => x.kind == AttrSuggestionKind.survival),
        isFalse);
  });

  test('reparte justo los puntos, determinista, y proyecta', () {
    for (final cls in ['guerrero', 'maga', 'paladin', 'tirador']) {
      for (final lv in [2, 7, 20, 40]) {
        final p = _p(cls, lv);
        final a = _advisor.recommend(p);
        expect(_sum(a), p.points, reason: '$cls $lv');
        expect(a.map((x) => '$x').toList(),
            _advisor.recommend(p).map((x) => '$x').toList());
        expect(_rules.allocate(p, AttributeAdvisor.allocation(a)), isNotNull);
      }
    }
    final g = _p('guerrero', 2);
    expect(AttributeAdvisor.horizonPoints(g), 1 + 5);
    expect(_sum(_advisor.recommend(g, null, 18)), 18);
    expect(AttributeAdvisor.horizonPoints(_p('guerrero', 50)),
        _p('guerrero', 50).points);
  });

  test('AGREGAR COMO META: objetivo actual + puntos, sin bajar metas', () {
    final g = _p('guerrero', 2);
    const s = [
      AttrSuggestion(
          attribute: Attribute.fue,
          points: 2,
          kind: AttrSuggestionKind.scaling,
          reasons: []),
      AttrSuggestion(
          attribute: Attribute.des,
          points: 1,
          kind: AttrSuggestionKind.scaling,
          reasons: []),
    ];
    const plan = BuildPlan(attributes: {Attribute.des: 40, Attribute.vit: 20});
    final out = AttributeAdvisor.addAsGoals(plan, g, s);
    expect(out.attributes, {
      Attribute.fue: g.attributes[Attribute.fue] + 6,
      Attribute.des: 40,
      Attribute.vit: 20,
    });
    expect(AttributeAdvisor.split(s), 'FUE +6, DES +3');
  });
}
