// "Dónde la conseguís", ULT y mods por arma objetivo (build_planner.md
// § 10.2, 10.4, 10.5).
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_coach_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_plan_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

const _sword = ItemInstance(
    uid: 'sw',
    baseId: 'espada_bronce',
    rarity: Rarity.raro,
    affixes: [AffixRoll('veloz', 2, 8)]);
const _staff = ItemInstance(
    uid: 'st',
    baseId: 'baculo_fuego',
    rarity: Rarity.raro,
    affixes: [AffixRoll('arcano', 1, 35), AffixRoll('feroz', 2, 28)]);
const _tome =
    ItemInstance(uid: 'to', baseId: 'tomo_plaga', rarity: Rarity.raro);

PlayerProfile _ana() => progression.normalize(PlayerProfile(
    name: 'Ana',
    classId: 'guerrero',
    level: 6,
    items: const [_sword, _staff, _tome],
    equipped: 'sw'));

BuildCoach get _coach => BuildCoach(BuildPlanRules(progression));

void main() {
  test('habilidad: dónde la conseguís (bases por nivel, FUSIÓN)', () {
    final w = _coach.skillWhere('giro', _ana());
    expect(w.first, startsWith('Ya la tenés en'));
    expect(w.first, contains('inventario'));
    expect(
        w.any((x) => x.startsWith('La da Espada de Bronce (Espada, nivel 1)')),
        isTrue);
    expect(w.where((x) => x.startsWith('La da ')).length, lessThanOrEqualTo(3));
    expect(w.last, startsWith('FUSIÓN, Traer una habilidad: desde'));

    final none = _coach.skillWhere(
        'giro', PlayerProfile(name: 'B', classId: 'guerrero', items: const []));
    expect(
        none.last, 'FUSIÓN, Traer una habilidad: desde un arma que la tenga');
  });

  test('paso de habilidad y de mod con su lista "dónde"', () {
    const plan = BuildPlan(skills: ['hendir'], mods: [ModGoal('certero', 5)]);
    final steps = _coach.nextSteps(plan, _ana());
    final skill = steps.firstWhere((s) => s.text.contains('habilidad'));
    expect(skill.where, isNotEmpty);
    expect(skill.where.last, startsWith('FUSIÓN, Traer una habilidad'));
    final mod = steps.firstWhere((s) => s.text.contains('el mod'));
    expect(
        mod.where
            .any((x) => x.startsWith('Sale al azar en armas de rareza Mágico')),
        isTrue);
    expect(mod.where,
        contains('FUSIÓN, Traer un mod: desde un arma que lo tenga'));
  });

  test('ULT: "Equipá la ULT X" y acción ult', () {
    final id = kUltV2.keys.first;
    final steps = _coach.nextSteps(BuildPlan(ultActive: id), _ana());
    final s = steps.firstWhere((s) => s.action == BuildStepAction.ult);
    expect(s.text, startsWith('Equipá la ULT '));
  });

  test('mods por arma objetivo: en tu arma, pasalo, no entra, falta', () {
    const plan = BuildPlan(mods: [
      ModGoal('veloz', 3),
      ModGoal('feroz', 3),
      ModGoal('arcano', 3),
      ModGoal('letal', 5),
    ]);
    final m = {for (final x in _coach.modsWanted(plan, _ana())) x.affixId: x};
    expect(m['veloz']!.state, ModState.onWeapon);
    expect(m['veloz']!.status, 'En tu arma');
    expect(m['feroz']!.state, ModState.transferable);
    expect(m['feroz']!.status,
        allOf(startsWith('Lo tenés en'), endsWith('en FUSIÓN')));
    expect(m['arcano']!.state, ModState.blocked);
    expect(m['arcano']!.reason, 'No sale en este tipo de arma');
    expect(m['arcano']!.suggestion, startsWith('Podría ir en'));
    expect(m['arcano']!.status, contains('no entra en'));
    expect(m['letal']!.state, ModState.missing);
    expect(m['letal']!.status, 'Falta');
    // Solo "En tu arma" cuenta como hecho.
    final pr = BuildPlanRules(progression).evaluate(plan, _ana());
    final mods = _coach
        .areas(plan, _ana(), pr)
        .firstWhere((a) => a.area == BuildArea.mods);
    expect((mods.done, mods.total), (1, 4));
  });

  test('arma recomendada: qué mods le podés traer', () {
    const plan = BuildPlan(mods: [ModGoal('feroz', 3), ModGoal('arcano', 3)]);
    final lines = _coach.transferableTo(_sword, plan, _ana());
    expect(lines.length, 1);
    expect(lines.single, startsWith('Feroz desde'));
    final toTome = _coach.transferableTo(_tome, plan, _ana());
    expect(toTome.length, 2);
  });
}
