import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_plan_providers.dart';
import 'package:echos_del_tiempo/features/inventory/domain/filter_build_snippets.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/build_wants.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

String _txt(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data ?? '';

/// "Coincide con mi build" en el editor del filtro (loot.md § 13,
/// build_planner.md § 6).
void main() {
  group('atajos de texto', () {
    test('condición debajo de la línea del cursor, dentro de la regla', () {
      const text = 'Mostrar # a\n  Rareza Raro\nOcultar\n  Rareza Común\n';
      final (out, cur) = FilterBuildSnippets.insertCondition(
          text, text.indexOf('Raro'), {BuildMatch.mod});
      expect(out,
          'Mostrar # a\n  Rareza Raro\n  Build Mod\nOcultar\n  Rareza Común\n');
      expect(out.substring(0, cur), endsWith('  Build Mod'));
      expect(const LootFilterRules().parse(out).ok, isTrue);
      // Al final sin salto de línea.
      expect(FilterBuildSnippets.insertCondition('Mostrar', -1, {}).$1,
          'Mostrar\n  Build\n');
    });

    test('sin regla arriba del cursor: agrega una regla que resalta', () {
      final (out, _) = FilterBuildSnippets.insertCondition(
          '', 0, {BuildMatch.pasiva, BuildMatch.base});
      expect(out, startsWith('Mostrar # Coincide con mi build\n  Build Base Pasiva\n'));
      final f = const LootFilterRules().parse(out);
      expect(f.ok, isTrue);
      expect(const LootFilterRules()
          .parse(FilterBuildSnippets.hideRule)
          .filter
          .rules
          .single
          .show, isFalse);
    });
  });

  for (final size in [TextSize.normal, TextSize.huge]) {
    testWidgets('editor: sección de build, vista previa con ★ y atajos '
        '(${size.name})', (tester) async {
      final c = await pumpPanel(tester,
          profile: lootWarrior(),
          textSize: size,
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.filter));
      final container =
          ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
      expect(_txt(tester, 'filter-build-plan'), contains('No tenés plan'));
      expect(plain(tester, 'filter-sample-3'), isNot(contains('★')));

      await container
          .read(buildPlanProvider.notifier)
          .save(const BuildPlan(mods: [ModGoal('feroz', 5)]));
      await tester.pump();
      expect(_txt(tester, 'filter-build-plan'), contains('Tu plan busca: 1 mod'));
      // El Épico de muestra tiene Feroz: regla "Tu build" del por defecto y ★.
      final s3 = plain(tester, 'filter-sample-3');
      expect(s3, contains('★'));
      expect(s3, contains('Tu build'));
      expect(plain(tester, 'filter-sample-0'), isNot(contains('★')));

      // Elegir MOD y agregar la condición a la regla del cursor (al final).
      await tapVisible(tester, find.byKey(const ValueKey('filter-build-kind-mod')));
      expect(_txt(tester, 'filter-build-line'), contains('Build Mod'));
      await tapVisible(tester, find.byKey(const ValueKey('filter-view-text')));
      final field = find.byKey(const ValueKey('filter-text'));
      final ctl = tester.widget<TextField>(field).controller!;
      ctl.selection = TextSelection.collapsed(offset: ctl.text.length);
      await tapVisible(tester, find.byKey(const ValueKey('filter-build-insert')));
      expect(ctl.text, endsWith('  Build Mod\n'));

      await tapVisible(
          tester, find.byKey(const ValueKey('filter-build-highlight')));
      expect(ctl.text, startsWith('Mostrar # Coincide con mi build\n  Build Mod\n'));
      await tapVisible(tester, find.byKey(const ValueKey('filter-build-hide')));
      expect(ctl.text, startsWith('Ocultar # Comunes fuera de mi build\n'));
      expect(plain(tester, 'filter-status'), contains('Sin errores'));

      // CUALQUIER META vuelve a la condición sin clases.
      await tapVisible(tester, find.byKey(const ValueKey('filter-build-kind-any')));
      expect(_txt(tester, 'filter-build-line'), endsWith('Build'));

      // Guardar viaja como cualquier filtro.
      await tapVisible(tester, find.byKey(const ValueKey('filter-save')));
      expect(c.view!.me!.profile.lootFilter, contains('Build No'));
      expect(tester.takeException(), isNull);
    });
  }
}
