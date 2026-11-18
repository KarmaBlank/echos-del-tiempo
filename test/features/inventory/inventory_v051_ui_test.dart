import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/inventory/domain/shop_guards.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/clean_selection.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/consumables_bar.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_sort_button.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/inventory_sort.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: RetroTheme.build(),
    home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child)),
  ));
  await tester.pump();
}

Finder _k(String k) => find.byKey(ValueKey(k));

void main() {
  group('CONSUMIBLES / MATERIALES', () {
    testWidgets('casillas fijas con cantidad; en 0 no se eligen',
        (tester) async {
      final p = lootWarrior(materials: const {CraftMaterial.cristal: 3});
      final picked = <String>[];
      await _pump(
          tester,
          InventoryStacksBar(
              rules: progression, profile: p, onSelect: picked.add));
      expect(find.text('CONSUMIBLES'), findsOneWidget);
      expect(find.text('MATERIALES'), findsOneWidget);
      for (final t in ['pot', 'eter', 'mat:esquirla', 'mat:cristal',
        'mat:prisma', 'mat:ancla']) {
        expect(_k('inv-stack-$t'), findsOneWidget, reason: t);
      }
      expect(
          find.descendant(of: _k('inv-stack-mat:cristal'), matching: find.text('3')),
          findsOneWidget);
      await tester.tap(_k('inv-stack-pot'));
      await tester.tap(_k('inv-stack-mat:prisma')); // 0: nada
      await tester.tap(_k('inv-stack-mat:cristal'));
      expect(picked, ['pot', 'mat:cristal']);
    });

    testWidgets('teclado: flechas eligen, Enter también', (tester) async {
      final p = lootWarrior();
      final picked = <String>[];
      await _pump(
          tester,
          InventoryStacksBar(
              rules: progression, profile: p, onSelect: picked.add));
      // Clic pasa el cursor; después flecha a la derecha.
      await tester.tap(_k('inv-stack-pot'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(picked.last, 'eter');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(picked.last, 'eter');
    });

    testWidgets('solo lectura: sin onSelect no elige', (tester) async {
      await _pump(tester,
          InventoryStacksBar(rules: progression, profile: lootWarrior()));
      await tester.tap(_k('inv-stack-pot'));
      expect(tester.takeException(), isNull);
    });
  });

  group('ORDENAR ▾', () {
    testWidgets('abre el menú, elige y cierra; Esc cierra sin ordenar',
        (tester) async {
      final got = <InventorySortKey>[];
      await _pump(tester, InventorySortButton(onSort: got.add));
      expect(_k('inv-sort-menu'), findsNothing);
      await tester.tap(_k('inv-sort'));
      await tester.pump();
      expect(_k('inv-sort-menu'), findsOneWidget);
      for (final k in InventorySortKey.values) {
        expect(find.text(k.label), findsOneWidget);
      }
      await tester.tap(_k('inv-sort-name'));
      await tester.pump();
      expect(got, [InventorySortKey.name]);
      expect(_k('inv-sort-menu'), findsNothing);

      await tester.tap(_k('inv-sort'));
      await tester.pump();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_k('inv-sort-menu'), findsNothing);
      expect(got, hasLength(1));
    });

    testWidgets('teclado: el cursor entra al menú; abajo + Enter elige',
        (tester) async {
      final got = <InventorySortKey>[];
      await _pump(tester, InventorySortButton(onSort: got.add));
      await tester.tap(_k('inv-sort'));
      await tester.pump();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(got, [InventorySortKey.itemLevel]);
    });

    testWidgets('con motivo: deshabilitado', (tester) async {
      await _pump(tester,
          InventorySortButton(onSort: (_) {}, reason: 'Solo lectura'));
      expect(find.text('Solo lectura'), findsOneWidget);
    });
  });

  group('en la pestaña INVENTARIO', () {
    Future<SessionController> inventory(WidgetTester tester) => pumpPanel(
        tester,
        profile: lootWarrior(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));
    Future<void> tap(WidgetTester tester, String key) =>
        tapVisible(tester, _k(key));

    testWidgets('pilas en su sección: elegir, dar / tirar como antes',
        (tester) async {
      final c = await inventory(tester);
      final p = c.view!.me!.profile;
      expect(InventoryRules.layout(p).cells, isNot(contains('pot')));
      expect(_k('inv-stacks'), findsOneWidget);
      await tap(tester, 'inv-stack-pot');
      expect(_k('inv-drop'), findsOneWidget);
      expect(_k('inv-move'), findsNothing, reason: 'lugar fijo');
      await tap(tester, 'inv-drop');
      if (_k('inv-drop-confirm').evaluate().isNotEmpty) {
        await tap(tester, 'inv-drop-confirm');
      }
      expect(c.view!.me!.profile.potions, p.potions - 1);
    });

    testWidgets('ORDENAR por rareza manda la acción', (tester) async {
      final c = await inventory(tester);
      await tap(tester, 'inv-sort');
      await tester.pump();
      await tap(tester, 'inv-sort-rarity');
      final cells = InventoryRules.layout(c.view!.me!.profile).cells;
      expect(cells.take(5), ['l1', 'e1', 'r1', 'm1', 'c1']);
    });

    testWidgets('ELEGIR A MANO: marcar con clic y Espacio, candado, vender',
        (tester) async {
      final c = await inventory(tester);
      PlayerProfile me() => c.view!.me!.profile;
      int cell(String t) => InventoryRules.layout(me()).cells.indexOf(t);
      final credits = me().credits;
      await tap(tester, 'inv-clean');
      await tap(tester, 'inv-clean-mode-pick');
      expect(_k('inv-clean-count'), findsOneWidget);
      await tap(tester, 'inv-cell-${cell('m1')}');
      expect(_k('clean-check'), findsOneWidget);
      // Teclado: el cursor está en m1; flecha a la derecha y Espacio.
      final next = cell('m1') + 1;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      final t = InventoryRules.layout(me()).cells[next]!;
      expect(_k('clean-check'), findsNWidgets(2), reason: 'marcó $t');
      await tap(tester, 'inv-clean-sell');
      await tap(tester, 'inv-clean-confirm');
      expect(me().itemByUid('m1'), isNull);
      expect(me().itemByUid(t), isNull);
      expect(me().credits, greaterThan(credits));
      expect(find.textContaining('Elegidas: 0'), findsOneWidget);
      // POR RAREZA sigue.
      await tap(tester, 'inv-clean-mode-rarity');
      expect(_k('inv-clean-rarity-comun'), findsOneWidget);
    });
  });

  group('LIMPIAR: ELEGIR A MANO', () {
    final p = lootWarrior();
    final guards = ShopGuards(progression, SessionMode.lobby);

    test('helpers: candados, marcar, atajo por rareza, podar', () {
      expect(cleanLockReason(progression, p, 'espada_bronce', const []),
          'Está equipada');
      expect(cleanLockReason(progression, p, 'e1', const []), isNull);
      var sel = togglePicked(progression, p, const [], 'm1');
      expect(sel, ['m1']);
      expect(togglePicked(progression, p, sel, 'espada_bronce'), sel);
      sel = addRarityPicked(progression, p, sel, Rarity.comun);
      expect(sel, ['m1', 'c1']);
      expect(addableCount(progression, p, sel, Rarity.comun), 0);
      expect(togglePicked(progression, p, sel, 'm1'), ['c1']);
      final sold = p.copyWith(items: [
        for (final i in p.items)
          if (i.uid != 'c1') i,
      ]);
      expect(prunePicked(progression, sold, sel), ['m1']);
    });

    testWidgets('resumen = vista previa del motor; confirmar manda la lista',
        (tester) async {
      CraftAction? sent;
      Rarity? added;
      await _pump(
          tester,
          SizedBox(
            width: 600,
            child: CleanSelectionPanel(
              rules: progression,
              guards: guards,
              profile: p,
              picked: const ['m1', 'c1'],
              sell: true,
              onSell: (_) {},
              onAdd: (r) => added = r,
              onClear: () {},
              onConfirm: (a) => sent = a,
              onCancel: () {},
            ),
          ));
      final price = progression.crafting.sellPrice(magicKatana) +
          progression.crafting.sellPrice(commonStaff);
      expect(plain(tester, 'inv-clean-summary'), contains('$price'));
      expect(find.textContaining('Elegidas: 2'), findsOneWidget);
      expect(find.text('VENDER 2 SELECCIONADAS'), findsOneWidget);
      await tester.tap(_k('inv-clean-confirm'));
      expect(sent!.op, CraftOp.sellSelected);
      expect(sent!.uids, ['m1', 'c1']);
      await tester.tap(_k('inv-clean-add-raro'));
      expect(added, Rarity.raro);
    });

    testWidgets('sin elegir: motivo "Elige armas"', (tester) async {
      await _pump(
          tester,
          SizedBox(
            width: 600,
            child: CleanSelectionPanel(
              rules: progression,
              guards: guards,
              profile: p,
              picked: const [],
              sell: false,
              onSell: (_) {},
              onAdd: (_) {},
              onClear: () {},
              onConfirm: (_) {},
              onCancel: () {},
            ),
          ));
      expect(button(tester, 'inv-clean-confirm').reason, 'Elige armas');
    });

    testWidgets('marca: ✓ elegida, candado bloqueada', (tester) async {
      await _pump(
          tester,
          const Row(children: [
            CleanCellMark(picked: true, child: SizedBox.square(dimension: 44)),
            CleanCellMark(locked: true, child: SizedBox.square(dimension: 44)),
          ]));
      expect(_k('clean-check'), findsOneWidget);
      expect(_k('clean-lock'), findsOneWidget);
    });
  });
}
