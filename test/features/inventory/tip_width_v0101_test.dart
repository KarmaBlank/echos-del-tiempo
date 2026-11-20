import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_plan_providers.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/weapon_compare_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

// v0.10.1: la caja del tooltip de la grilla del inventario mide una
// columna (más el padding), con "★ Tu build" y con cualquier tamaño de
// texto; antes, con la línea de la build, tomaba todo el ancho.

void main() {
  for (final size in TextSize.values) {
    testWidgets('caja de una columna con ★ Tu build ($size)', (tester) async {
      final c = await pumpPanel(tester,
          profile: lootWarrior(),
          textSize: size,
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.inventory));
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(buildPlanProvider.notifier)
          .save(const BuildPlan(weaponTypes: ['hacha', 'espada', 'katana']));
      await tester.pump();
      await tester.pump();
      final p = c.view!.me!.profile;
      final cells = InventoryRules.layout(p).cells;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final screenW = tester.view.physicalSize.width;
      var checked = 0, fits = 0;
      for (var i = 0; i < cells.length; i++) {
        final cell = find.byKey(ValueKey('inv-cell-$i'));
        if (cells[i] == null || cell.evaluate().isEmpty) continue;
        await tester.ensureVisible(cell);
        await tester.pump();
        await mouse.moveTo(tester.getCenter(cell));
        await tester.pump();
        final box = find.byKey(const ValueKey('retro-tip-scroll'));
        if (box.evaluate().isEmpty) continue;
        final w = tester.getSize(box).width;
        final card = find.byKey(const ValueKey('inv-cmp-tip'));
        if (card.evaluate().isNotEmpty) {
          // Una columna (Shift no está apretado): el ancho escalado de
          // la ficha, no el que le haya quedado al SizedBox.
          final col =
              RetroType.width(tester.element(card), HoverCompareCard.cardWidth);
          expect(w, lessThanOrEqualTo(col + 1), reason: '${cells[i]} ($size)');
        } else {
          expect(w, lessThan(screenW * 0.6), reason: '${cells[i]} ($size)');
        }
        // Nunca tapa la franja de CAMBIOS ni la EQUIPADA / pilas.
        final r = tester.getRect(box);
        for (final f in [
          find.byType(ChangeStrip),
          find.byKey(const ValueKey('inv-equipped')),
          find.byKey(const ValueKey('inv-side')),
        ]) {
          if (f.evaluate().isEmpty) continue;
          expect(r.overlaps(tester.getRect(f.first)), isFalse,
              reason: '${cells[i]} ($size) tapa $f');
        }
        checked++;
        if (find
            .byKey(const ValueKey('inv-build-fit-hover'))
            .evaluate()
            .isNotEmpty) {
          fits++;
        }
        await mouse.moveTo(Offset.zero);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(checked, greaterThan(3));
      // Con la línea "★ Tu build" (el caso que se iba a todo el ancho).
      expect(fits, greaterThan(0));
      await mouse.removePointer();
    });
  }

  // v0.10.1: la franja de CAMBIOS, cada stat en una sola línea
  // (`ATQ 15→50 ▲35`) y todas a la vista o scrolleables.
  for (final size in [TextSize.normal, TextSize.large, TextSize.enormous]) {
    testWidgets('franja de CAMBIOS: una línea por stat ($size)',
        (tester) async {
      final c = await pumpPanel(tester,
          profile: lootWarrior(),
          textSize: size,
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.inventory));
      final p = c.view!.me!.profile;
      final i = InventoryRules.layout(p).cells.indexOf('e1');
      final cell = find.byKey(ValueKey('inv-cell-$i'));
      await tester.ensureVisible(cell);
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(cell));
      await tester.pump();
      final strip = find.byKey(const ValueKey('inv-strip'));
      expect(strip, findsOneWidget);
      final lines = find.descendant(
          of: strip,
          matching: find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('inv-strip-')));
      expect(lines.evaluate().length, greaterThanOrEqualTo(6));
      final head = tester.getSize(find.descendant(
          of: strip, matching: find.textContaining(RegExp('CAMBIOS|ACTUAL'))));
      for (final k in [for (final e in lines.evaluate()) e.widget.key!]) {
        final f = find.byKey(k);
        final r = tester.renderObject<RenderParagraph>(
            find.descendant(of: f, matching: find.byType(RichText)).first);
        // Una línea: ni partida ni recortada.
        expect(tester.getSize(f).height, closeTo(head.height, 0.5),
            reason: '$k ($size)');
        expect(r.didExceedMaxLines, isFalse, reason: '$k');
        expect(r.size.width,
            greaterThanOrEqualTo(r.getMaxIntrinsicWidth(double.infinity) - 0.5),
            reason: '$k recortada');
        // Se puede llevar a la vista (scroll del panel).
        await tester.ensureVisible(f);
        await tester.pump();
        expect(
            tester.getRect(f).bottom,
            lessThanOrEqualTo(
                tester.view.physicalSize.height / tester.view.devicePixelRatio +
                    0.5));
      }
      await mouse.removePointer();
    });
  }
}
