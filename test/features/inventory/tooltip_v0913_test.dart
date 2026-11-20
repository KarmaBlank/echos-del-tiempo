import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/inventory/domain/weapon_compare.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/weapon_compare_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

// v0.9.13 (docs/specs/ui_style.md § "Tooltips cortos", panels.md §
// "Inventario"): tooltip atravesable, Alt / Shift / clic y franja de
// cambios.

void main() {
  late Finder Function(String uid) cellOf;

  Future<TestGesture> open(WidgetTester tester) async {
    final c = await pumpPanel(tester,
        profile: lootWarrior(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));
    final p = c.view!.me!.profile;
    cellOf = (uid) => find.byKey(
        ValueKey('inv-cell-${InventoryRules.layout(p).cells.indexOf(uid)}'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    return mouse;
  }

  String tipText(WidgetTester tester) => tester
      .widgetList<RichText>(find.descendant(
          of: find.byKey(const ValueKey('inv-cmp-tip')),
          matching: find.byType(RichText)))
      .map((r) => r.text.toPlainText())
      .join('\n');

  testWidgets('no captura el mouse: la casilla de al lado cambia el ítem',
      (tester) async {
    final mouse = await open(tester);
    await mouse.moveTo(tester.getCenter(cellOf('e1')));
    await tester.pump();
    final first = tipText(tester);
    expect(first, contains('Filo del Alba'));
    expect(
        find.ancestor(
            of: find.byKey(const ValueKey('inv-cmp-tip')),
            matching: find
                .byWidgetPredicate((w) => w is IgnorePointer && w.ignoring)),
        findsWidgets);
    // Nunca tapa la casilla mirada.
    final tip = tester.getRect(find.byKey(const ValueKey('retro-tip-scroll')));
    expect(tip.overlaps(tester.getRect(cellOf('e1'))), isFalse);
    expect(find.text('Alt: detalle · Shift: comparar · clic: fijar'),
        findsOneWidget);
    await mouse.moveTo(tester.getCenter(cellOf('l1')));
    await tester.pump();
    expect(tipText(tester), isNot(first));
    await mouse.removePointer();
  });

  testWidgets('Alt despliega los ▸ mientras se mantiene', (tester) async {
    final mouse = await open(tester);
    await mouse.moveTo(tester.getCenter(cellOf('e1')));
    await tester.pump();
    final body = find.byKey(const ValueKey('tip-fold-body-Habilidades'));
    expect(body, findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(body, findsOneWidget);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(body, findsNothing);
    await mouse.removePointer();
  });

  testWidgets('clic fija (toma el mouse) y Esc lo suelta', (tester) async {
    final mouse = await open(tester);
    await mouse.moveTo(tester.getCenter(cellOf('e1')));
    await tester.pump();
    expect(RetroHoverCard.pinned, isFalse);
    await mouse.down(tester.getCenter(cellOf('e1')));
    await mouse.up();
    await tester.pump();
    expect(RetroHoverCard.pinned, isTrue);
    await tester.tap(find.byKey(const ValueKey('tip-fold-Habilidades')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tip-fold-body-Habilidades')),
        findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(RetroHoverCard.anyShowing, isFalse);
    await mouse.removePointer();
  });

  testWidgets('una columna angosta; Shift suma la equipada', (tester) async {
    final mouse = await open(tester);
    await mouse.moveTo(tester.getCenter(cellOf('e1')));
    await tester.pump();
    final ctx = tester.element(find.byKey(const ValueKey('inv-cmp-tip')));
    final w1 = tester.getSize(find.byKey(const ValueKey('inv-cmp-tip'))).width;
    expect(w1, lessThanOrEqualTo(RetroType.width(ctx, 200)));
    expect(find.byKey(const ValueKey('inv-cmp-tip-equipped')), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-cmp-tip-equipped')), findsOneWidget);
    expect(find.byKey(const ValueKey('inv-cmp-tip-delta')), findsNothing);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-cmp-tip-equipped')), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('franja: valores actuales en gris y deltas al pasar',
      (tester) async {
    final mouse = await open(tester);
    final strip = find.byKey(const ValueKey('inv-strip'));
    expect(strip, findsOneWidget);
    // DsStatLine: un Text por parte (etiqueta, antes, →, después, ▲, Δ).
    String line(String l) => tester
        .widgetList<RichText>(find.descendant(
            of: find.byKey(ValueKey('inv-strip-$l')),
            matching: find.byType(RichText)))
        .map((t) => t.text.toPlainText().trim())
        .join(' ');
    final p = lootWarrior();
    final now = stripStats(progression, p);
    expect(line('ATQ'), 'ATQ ${now.first.format(now.first.before)}');
    expect([for (final s in now) s.label],
        ['ATQ', 'MAG', 'CRÍT', 'VEL', 'Vida', 'Maná', 'DEF', 'Peso']);
    await mouse.moveTo(tester.getCenter(cellOf('e1')));
    await tester.pump();
    final d = stripStats(progression, p, to: p.itemByUid('e1'));
    final atq = d.first;
    expect(atq.changed, isTrue);
    expect(line('ATQ'), contains('→ ${atq.format(atq.after)}'));
    expect(line('ATQ'), contains(atq.better ? '▲' : '▼'));
    // No achica la grilla: la franja está a la izquierda, sin pisarla.
    expect(tester.getRect(strip).right,
        lessThanOrEqualTo(tester.getRect(cellOf('e1')).left));
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(line('ATQ'), isNot(contains('→')));
    await mouse.removePointer();
  });

  test('HoverCompareCard.cardWidth ~32 letras', () {
    expect(HoverCompareCard.cardWidth, lessThan(200));
  });
}
