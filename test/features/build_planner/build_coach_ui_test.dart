// Vista simple de BUILD (build_planner.md § 10, ui_minimal.md § 6).
// Goldens:
//   flutter test --update-goldens test/features/build_planner/build_coach_ui_test.dart
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_plan_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/build_templates_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_coach_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_plan_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/square_ui_audit.dart';
import '../../game_engine/session_test_helpers.dart';
import '../../helpers/build_templates_fixture.dart';
import '../panel_test_harness.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

String _text(WidgetTester tester, Finder of) => tester
    .widgetList<RichText>(
        find.descendant(of: of, matching: find.byType(RichText)))
    .map((r) => r.text.toPlainText())
    .join(' ');

/// Una sigla de atributo suelta (sin su nombre completo delante).
final _bareShort = RegExp(r'(?<!\()\b(FUE|VIT|ESP|AGI|DES)\b(?!\))');

PlayerProfile _ana({int level = 6}) => progression
    .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: level));

Future<void> _pump(WidgetTester tester, PlayerProfile p,
        {TextSize? textSize}) =>
    pumpPanel(tester,
        profile: p,
        textSize: textSize,
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.build));

Future<void> _applyBerserker(WidgetTester tester) async {
  await _container(tester).read(buildPlanProvider.notifier).save(
      BuildPlanRules(progression)
          .applyTemplate(BuildPlan.empty, buildTemplate('gue_berserker')!));
  await tester.pump();
}

Future<void> _openArea(WidgetTester tester, String area) => tapVisible(
    tester,
    find.descendant(
        of: find.byKey(ValueKey('build-area-$area')),
        matching: find.byKey(const ValueKey('ds-fold-head'))));

void main() {
  setUpAll(installBuildTemplates);

  test('textos: siglas siempre con el nombre completo', () {
    expect(BuildCoach.attributeLabel(Attribute.fue), 'Fuerza (FUE)');
    expect(BuildCoach.typeName('maza+escudo'), 'Maza y escudo');
    expect(BuildCoach.tierText(1), 'nivel 1 (el mejor)');
    expect(BuildCoach.tierText(3), 'nivel 3 o mejor');
    expect(BuildCoach.difficultyLabel(1), 'Fácil');
    expect(BuildCoach.difficultyLabel(3), 'Avanzada');
    expect(BuildCoach.expandShorts('usa FUE · Fuerza (FUE)'),
        'usa Fuerza (FUE) · Fuerza (FUE)');
  });

  test('pasos: como máximo 3 y sin siglas sueltas', () {
    final rules = BuildPlanRules(progression);
    for (final t in buildTemplatesFor('guerrero')) {
      final plan = rules.applyTemplate(BuildPlan.empty, t);
      final steps = BuildCoach(rules).nextSteps(plan, _ana());
      expect(steps.length, lessThanOrEqualTo(BuildCoach.maxSteps));
      expect(steps, isNotEmpty, reason: t.id);
      for (final s in steps) {
        expect(_bareShort.hasMatch(s.text), isFalse, reason: s.text);
      }
    }
  });

  testWidgets('sin plan: elegir plantilla y APLICAR', (tester) async {
    await _pump(tester, _ana());
    expect(find.byKey(const ValueKey('build-choose')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('build-tpl-gue_berserker')), findsOneWidget);
    expect(
        _text(
            tester, find.byKey(const ValueKey('build-tpl-diff-gue_berserker'))),
        anyOf('FÁCIL', 'FACIL', 'MEDIA', 'AVANZADA'));
    await tapVisible(
        tester, find.byKey(const ValueKey('build-apply-gue_berserker')));
    await tester.pump();
    final plan = _container(tester).read(buildPlanProvider).plan;
    expect(plan.templateId, 'gue_berserker');
    expect(_text(tester, find.byKey(const ValueKey('build-summary-name'))),
        contains('Tu plan:'));
    expect(find.byKey(const ValueKey('build-template')), findsOneWidget);
  });

  testWidgets('con plan: Qué hacer ahora, áreas plegadas, sin controles',
      (tester) async {
    await _pump(tester, _ana());
    await _applyBerserker(tester);
    expect(find.byKey(const ValueKey('build-now')), findsOneWidget);
    expect(find.byKey(const ValueKey('build-step-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('build-step-3')), findsNothing);
    // Puntos libres: "Poné N puntos en Fuerza (FUE)" (el tramo de la
    // plantilla) con IR A ATRIBUTOS.
    final first = _text(tester, find.byKey(const ValueKey('build-step-0')));
    expect(first, contains('Fuerza (FUE)'));
    expect(first, contains('IR A ATRIBUTOS'));
    for (var i = 0; i < 3; i++) {
      final f = find.byKey(ValueKey('build-step-$i'));
      if (f.evaluate().isEmpty) continue;
      expect(_bareShort.hasMatch(_text(tester, f)), isFalse);
    }
    expect(find.byKey(const ValueKey('build-legend')), findsOneWidget);
    // Controles de edición escondidos por defecto.
    expect(find.byKey(const ValueKey('build-inc-fue')), findsNothing);
    expect(find.byKey(const ValueKey('build-add-attributes')), findsNothing);
    expect(
        find.byKey(const ValueKey('build-remove-skill:hendir')), findsNothing);
    // Áreas plegadas: abrir Mods muestra la lista legible.
    expect(find.byKey(const ValueKey('build-mods')), findsNothing);
    await _openArea(tester, 'mods');
    expect(find.byKey(const ValueKey('build-mods')), findsOneWidget);
    // IR A ATRIBUTOS cambia de pestaña.
    await tapVisible(tester, find.byKey(const ValueKey('build-step-go-0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('build-planner')), findsNothing);
  });

  testWidgets('EDITAR PLAN muestra los controles y LISTO vuelve',
      (tester) async {
    await _pump(tester, _ana());
    await _applyBerserker(tester);
    await tapVisible(tester, find.byKey(const ValueKey('build-edit')));
    expect(find.byKey(const ValueKey('build-inc-fue')), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('build-edit-done')));
    expect(find.byKey(const ValueKey('build-inc-fue')), findsNothing);
    expect(find.byKey(const ValueKey('build-now')), findsOneWidget);
  });

  const cases = {
    'wide': (Size(1920, 1080), TextSize.normal),
    'narrow': (Size(800, 900), TextSize.enormous),
  };
  for (final MapEntry(key: name, value: (size, text)) in cases.entries) {
    for (final withPlan in [false, true]) {
      final shot = withPlan ? 'plan' : 'choose';
      testWidgets('golden: BUILD simple $shot ($name)', (tester) async {
        await _pump(tester, _ana(), textSize: text);
        tester.view.physicalSize = size;
        await tester.pump();
        if (withPlan) {
          await _applyBerserker(tester);
          await _openArea(tester, 'weapon');
          await _openArea(tester, 'mods');
          await tester
              .ensureVisible(find.byKey(const ValueKey('build-summary')));
          await tester.pump();
        }
        expect(roundedUi(tester), isEmpty);
        await expectLater(find.byType(CharacterPanel),
            matchesGoldenFile('goldens/build_simple_${shot}_$name.png'));
      });
    }
  }
}
