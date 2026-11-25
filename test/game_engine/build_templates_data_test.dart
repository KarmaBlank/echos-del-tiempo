import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/build_templates_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_plan_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_template_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:flutter_test/flutter_test.dart';

final _tree = PassiveTreeRules(kPassiveTree);
final _progression = ProgressionRules(
    stats: StatsCalculator(classes: kClasses, treeRules: _tree));
final _rules = BuildTemplateRules(_progression);

/// build_planner_v2.md § 2.2: el archivo de plantillas del juego es
/// válido contra todos los catálogos.
void main() {
  final file = BuildTemplateYaml.parse(
      File(BuildTemplateYaml.assetPath).readAsStringSync());

  test('se lee sin avisos', () {
    expect(file.issues, isEmpty);
    expect(file.templates, isNotEmpty);
  });

  test('5 por clase, una de grupo, ids únicos', () {
    for (final c in kClasses.keys) {
      final mine = file.templates.where((t) => t.classId == c).toList();
      expect(mine.length, 5, reason: c);
      expect(mine.where((t) => t.isGroup).length, 1, reason: c);
    }
    final ids = {for (final t in file.templates) t.id};
    expect(ids.length, file.templates.length);
    // Las de v1 siguen con su id (un plan viejo con `tpl` sigue apuntando).
    for (final id in const [
      'gue_berserker',
      'gue_quiebre',
      'mag_brasa',
      'mag_cronos',
      'tir_precision',
      'tir_toxina',
      'pal_guardian',
      'pal_templario',
    ]) {
      expect(ids, contains(id));
    }
  });

  for (final t in file.templates) {
    test('${t.id} es válida', () {
      expect(_rules.validate(t), isEmpty);
      final tl = _rules.timeline(t);
      // Cada paso entra en los puntos de su nivel.
      var spent = 0;
      for (final s in tl.steps) {
        spent++;
        expect(spent, lessThanOrEqualTo(BuildTemplateRules.pointsAt(s.level)),
            reason: '${s.node} al nivel ${s.level}');
      }
      // Los hitos del árbol caen en su nivel o después.
      for (final s in tl.steps.where((s) => s.milestone != null)) {
        expect(s.level, greaterThanOrEqualTo(s.milestone!));
      }
      // The ascension fits the points of the three Trials (tree v2).
      final asc = kAscensions[t.ascensionId]!;
      final cost =
          t.ascensionOrder.fold<int>(0, (a, n) => a + asc.node(n)!.cost);
      expect(cost, lessThanOrEqualTo(3 * AscensionProgress.pointsPerTrial));
      expect(t.ascensionOrder.where((n) => asc.node(n)!.capstone).length,
          lessThanOrEqualTo(1));
      // Sin metas bloqueadas para un personaje nuevo de su clase.
      final fresh =
          _progression.normalize(PlayerProfile(name: 'X', classId: t.classId));
      final plan = _rules.follow(BuildPlan.empty, t);
      expect(plan.version, 2);
      final r = BuildPlanRules(_progression).evaluate(plan, fresh);
      expect(
          [
            for (final g in r.goals)
              if (g.state == GoalState.blocked) g.key
          ],
          isEmpty);
    });
  }

  test('exportar y volver a importar da lo mismo', () {
    final text = BuildTemplateYaml.write(file.templates);
    final back = BuildTemplateYaml.parse(text, imported: true);
    expect(back.issues, isEmpty);
    expect(back.templates.length, file.templates.length);
    for (var i = 0; i < back.templates.length; i++) {
      expect(back.templates[i].imported, isTrue);
      expect(back.templates[i].toJson(), file.templates[i].toJson());
    }
  });
}
