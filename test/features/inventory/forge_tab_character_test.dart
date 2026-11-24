import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

// Plain Tab opens PERSONAJE from FORJA (panels.md § "Teclado en los
// menús"), even from the search field or the item grid; Shift+Tab still
// moves the focus.

Future<SessionController> _forge(WidgetTester tester) => pumpPanel(tester,
    profile: lootWarrior(),
    build: (v, c) => withCharacterTab(
        WorldPanel.forge,
        v,
        c,
        ForgePanel(
            view: v, controller: c, initialTab: ForgeHallTab.upgrade)));

void main() {
  testWidgets('Tab from the BUSCAR field opens PERSONAJE', (tester) async {
    final c = await _forge(tester);
    final field = find.descendant(
        of: find.byKey(const ValueKey('forge-search')),
        matching: find.byType(EditableText));
    await tester.tap(field);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>(),
        isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(c.state?.panel, WorldPanel.character);
  });

  testWidgets('Tab from the item grid opens PERSONAJE', (tester) async {
    final c = await _forge(tester);
    // Keyboard cursor on the grid (InitialFocus), then move it once.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(c.state?.panel, isNot(WorldPanel.character));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(c.state?.panel, WorldPanel.character);
  });

  testWidgets('Shift+Tab keeps moving the focus', (tester) async {
    final c = await _forge(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(c.state?.panel, isNot(WorldPanel.character));
  });
}
