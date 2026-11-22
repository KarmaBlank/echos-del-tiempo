import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/build_planner/data/template_files.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_plan_providers.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_planner_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/build_templates_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_plan_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/square_ui_audit.dart';
import '../../game_engine/session_test_helpers.dart';
import '../../helpers/build_templates_fixture.dart';
import '../panel_test_harness.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

String _text(WidgetTester tester, String key) {
  final f = find.descendant(
      of: find.byKey(ValueKey(key)), matching: find.byType(RichText));
  return tester
      .widgetList<RichText>(f)
      .map((r) => r.text.toPlainText())
      .join(' ');
}

/// Diálogos de archivo falsos: nunca tocan el disco.
class _FakeFiles implements TemplateFiles {
  String? toImport;
  String? saved;
  String? savedName;

  @override
  Future<String?> pickYaml() async => toImport;

  @override
  Future<bool> saveYaml(String text, String suggestedName) async {
    saved = text;
    savedName = suggestedName;
    return true;
  }
}

PlayerProfile _guerrero({List<ItemInstance>? items}) => progression.normalize(
    PlayerProfile(name: 'Ana', classId: 'guerrero', level: 24, items: items));

Future<void> _pumpView(WidgetTester tester,
    {required PlayerProfile profile,
    BuildPlan plan = BuildPlan.empty,
    List<ItemInstance> stash = const [],
    TemplateFiles? files,
    TextSize? textSize,
    bool edit = true,
    ValueChanged<BuildPlan>? onChanged}) async {
  var current = plan;
  await pumpPanel(tester,
      profile: profile,
      textSize: textSize,
      build: (v, c) => StatefulBuilder(
          builder: (context, set) => BuildPlannerView(
                key: const ValueKey('build-planner'),
                rules: BuildPlanRules(progression),
                profile: profile,
                plan: current,
                stash: stash,
                templateFiles: files ?? _FakeFiles(),
                onChanged: (p) {
                  onChanged?.call(p);
                  set(() => current = p);
                },
              )));
  // Las pruebas de acá usan la vista avanzada (EDITAR PLAN).
  if (edit) await tapVisible(tester, find.byKey(const ValueKey('build-edit')));
}

void main() {
  setUpAll(installBuildTemplates);
  tearDown(BuildTemplates.clearImported);

  testWidgets('+ ARMA OBJETIVO: buscar por habilidad, armar y guardar',
      (tester) async {
    await pumpPanel(tester,
        profile: _guerrero(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.build));
    await tapVisible(tester, find.byKey(const ValueKey('build-edit')));
    await tapVisible(tester, find.byKey(const ValueKey('build-add-target')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('base-search')), findsOneWidget);
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('base-search-field')),
            matching: find.byType(EditableText)),
        'trueno');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('base-hacha_tronante')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('target-detail')), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('target-edit-rarity')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('pick-rar-epico')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('target-save')));
    await tester.pumpAndSettle();
    final plan = _container(tester).read(buildPlanProvider).plan;
    expect(plan.weaponTargets.single.base, 'hacha_tronante');
    expect(plan.weaponTargets.single.rarity, Rarity.epico);
    expect(plan.weaponTargets.single.priority, TargetPriority.main);
    expect(find.byKey(const ValueKey('build-target-0')), findsOneWidget);
  });

  testWidgets('el detalle separa el alijo y lo marca', (tester) async {
    const inv = ItemInstance(uid: 'i1', baseId: 'hacha_rompe');
    const st = ItemInstance(
        uid: 's1',
        baseId: 'hacha_tronante',
        rarity: Rarity.epico,
        itemLevel: 40);
    final p = _guerrero(items: [inv]);
    await _pumpView(tester,
        profile: p,
        stash: const [st],
        plan: const BuildPlan(weaponTargets: [
          WeaponTarget(base: 'hacha_tronante', rarity: Rarity.epico)
        ]));
    // La mejor candidata está en el alijo: la fila lo dice.
    expect(_text(tester, 'build-target-0'), contains('ALIJO'));
    await tapVisible(tester, find.byKey(const ValueKey('build-target-0')));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('cand-stash')),
            matching: find.byType(GestureDetector)),
        findsWidgets);
    expect(find.byKey(const ValueKey('target-candidates')), findsOneWidget);
    expect(_text(tester, 'target-candidates'), contains('ALIJO'));
    expect(roundedUi(tester), isEmpty);
  });

  testWidgets('plantillas: exportar e importar con archivo', (tester) async {
    final files = _FakeFiles();
    await _pumpView(tester, profile: _guerrero(), files: files);
    await tapVisible(tester, find.byKey(const ValueKey('build-template')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('tpl-export-all')));
    await tester.pumpAndSettle();
    expect(files.savedName, 'plantillas_guerrero.yaml');
    final back = BuildTemplateYaml.parse(files.saved!);
    expect(back.templates.length, 5);
    // Un amigo la manda de vuelta: se importa renombrada y se puede seguir.
    files.toImport = files.saved;
    await tapVisible(tester, find.byKey(const ValueKey('tpl-import')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tpl-notice'), contains('Importadas 5'));
    expect(find.byKey(const ValueKey('tpl-gue_berserker_imp')), findsOneWidget);
    // Un archivo roto avisa y no rompe nada.
    files.toImport = 'esto: [no es';
    await tapVisible(tester, find.byKey(const ValueKey('tpl-import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tpl-notice')), findsOneWidget);
  });

  testWidgets(
      'vista de plantilla: slider con teclado, línea de tiempo y '
      'COMPARAR', (tester) async {
    BuildPlan? got;
    await _pumpView(tester, profile: _guerrero(), onChanged: (p) => got = p);
    await tapVisible(tester, find.byKey(const ValueKey('build-template')));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.byKey(const ValueKey('tpl-gue_tormenta_filo')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'tpl-level'), contains('Nv 24'));
    // Fin: al último nivel (Maestría 20); Inicio: al 1.
    await tester.tap(find.byKey(const ValueKey('tpl-slider')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(_text(tester, 'tpl-level'), contains('Maestría 20'));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(_text(tester, 'tpl-level'), contains('Nv 1'));
    await tapVisible(tester, find.byKey(const ValueKey('tpl-mark-arma-34')));
    await tester.pump();
    expect(_text(tester, 'tpl-level'), contains('Nv 34'));
    await tapVisible(tester, find.byKey(const ValueKey('tpl-compare')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tpl-compare-line')), findsWidgets);
    await tapVisible(tester, find.byKey(const ValueKey('tpl-follow')));
    await tester.pumpAndSettle();
    expect(got?.templateId, 'gue_tormenta_filo');
    expect(got?.weaponTargets.length, 2);
  });

  testWidgets('filtro: SOLO SI MEJORA escribe BuildMejora', (tester) async {
    await pumpPanel(tester,
        profile: _guerrero(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.filter));
    await _container(tester).read(buildPlanProvider.notifier).save(
            const BuildPlan(weaponTargets: [
          WeaponTarget(base: 'hacha_tronante', rarity: Rarity.epico)
        ]));
    await tester.pump();
    expect(_text(tester, 'filter-build-plan'), contains('arma objetivo'));
    await tapVisible(
        tester, find.byKey(const ValueKey('filter-build-kind-upgrade')));
    expect(_text(tester, 'filter-build-line'), contains('BuildMejora'));
    await tapVisible(
        tester, find.byKey(const ValueKey('filter-build-kind-mod')));
    expect(_text(tester, 'filter-build-line'), contains('Build Mod'));
  });

  for (final size in [TextSize.normal, TextSize.huge, TextSize.enormous]) {
    testWidgets('sin desbordes ni redondeos con texto ${size.name}',
        (tester) async {
      const st = ItemInstance(
          uid: 's1',
          baseId: 'hacha_tronante',
          rarity: Rarity.raro,
          itemLevel: 30,
          affixes: [AffixRoll('feroz', 3, 20)]);
      final plan = BuildPlanRules(progression)
          .applyTemplate(BuildPlan.empty, buildTemplate('gue_tormenta_filo')!);
      await _pumpView(tester,
          profile: _guerrero(items: const [
            ItemInstance(uid: 'c', baseId: 'espada_coral'),
          ]),
          plan: plan,
          stash: const [st],
          textSize: size);
      expect(find.byKey(const ValueKey('build-targets')), findsOneWidget);
      expect(find.byKey(const ValueKey('build-section-ult')), findsOneWidget);
      expect(roundedUi(tester), isEmpty);
      // Detalle del objetivo.
      await tapVisible(tester, find.byKey(const ValueKey('build-target-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('target-missing')), findsOneWidget);
      expect(roundedUi(tester), isEmpty);
      await tapVisible(tester, find.byKey(const ValueKey('target-close')));
      await tester.pumpAndSettle();
      // Buscador de bases.
      await tapVisible(tester, find.byKey(const ValueKey('build-add-target')));
      await tester.pumpAndSettle();
      expect(roundedUi(tester), isEmpty);
      await tapVisible(
          tester, find.byKey(const ValueKey('base-search-cancel')));
      await tester.pumpAndSettle();
      // Vista de plantilla.
      await tapVisible(tester, find.byKey(const ValueKey('build-template')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tpl-side')), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('tpl-compare')));
      await tester.pump();
      expect(roundedUi(tester), isEmpty);
    });
  }
}
