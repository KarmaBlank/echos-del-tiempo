import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/text_size_test.dart' show legendWand;
import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

/// v0.9.11: filas de menú como botones (ui_style.md § "Filas de menú") y
/// tooltips que scrollean en vez de achicar la letra (§ "Tooltips
/// cortos").
void main() {
  testWidgets(
      'menú: filas habilitadas con fondo y borde, desactivadas sin; '
      'nombres repetidos con clase y nivel', (tester) async {
    final c = await pumpPanel(tester, profile: lootWarrior(), build: (v, c) {
      var s = v.session;
      s = c.engine.addPlayer(s, 'p8', newProfile('Héroe', 'maga'))!.state;
      s = c.engine.addPlayer(s, 'p9', newProfile('Héroe', 'guerrero'))!.state;
      return CharacterPanel(
          view: SessionView(session: s, localId: v.localId, map: v.map),
          controller: c,
          initialTab: CharacterTab.inventory);
    });
    final p = c.view!.me!.profile;
    final i = InventoryRules.layout(p).cells.indexOf('e1');
    await tester.tap(find.byKey(ValueKey('inv-cell-$i')),
        buttons: kSecondaryButton);
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsOneWidget);

    BoxDecoration? deco(String key) => tester
        .widget<Container>(find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                (w.key == const ValueKey('menu-row-on') ||
                    w.key == const ValueKey('menu-row-off')))))
        .decoration as BoxDecoration?;
    final on = deco('inv-compare')!;
    expect(on.color, isNotNull);
    expect(on.border, isNotNull);
    expect(tester.getSize(find.byKey(const ValueKey('inv-compare'))).height,
        greaterThanOrEqualTo(16 + 10));
    // Hover: cambia el fondo.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse
        .moveTo(tester.getCenter(find.byKey(const ValueKey('inv-compare'))));
    await tester.pump();
    await tester.pump();
    expect(deco('inv-compare')!.color, isNot(on.color));
    expect(deco('inv-compare')!.border, isNot(on.border));
    await mouse.removePointer();

    // Nombres repetidos: con clase y nivel.
    final labels = find
        .byType(ProtoText)
        .evaluate()
        .map((e) => protoPlain((e.widget as ProtoText).markup))
        .where((t) => t.startsWith('Dar a'))
        .toList();
    expect(labels, hasLength(2));
    expect(labels.toSet(), hasLength(2));
    expect(labels.first, matches(RegExp(r'Dar a Héroe \(.+, Nv \d+\)')));
    // Encabezado no clickeable.
    expect(find.byKey(const ValueKey('inv-ctx-title')), findsOneWidget);
  });

  testWidgets('menú: la desactivada no tiene fondo ni borde', (tester) async {
    await pumpPanel(tester,
        profile: lootWarrior(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));
    await tester.tap(find.byKey(const ValueKey('inv-equipped')),
        buttons: kSecondaryButton);
    await tester.pump();
    final off = tester.widget<Container>(find.descendant(
        of: find.byKey(const ValueKey('inv-salvage')),
        matching: find.byKey(const ValueKey('menu-row-off'))));
    expect(off.decoration, isNull);
  });

  test('desarmar sin materiales seguros: texto claro', () {
    expect(gainsText(), 'sin materiales');
    expect(gainsText(chances: ['Núcleo']), 'puede salir: Núcleo');
  });

  testWidgets('todo desplegado: misma letra, alto máximo y scroll',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: lootWarrior(extra: [legendWand]),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));
    // Pantalla baja: con todo desplegado no entra.
    tester.view.physicalSize =
        const Size(1280, 240) * tester.view.devicePixelRatio;
    await tester.pumpAndSettle();
    final p = c.view!.me!.profile;
    final i = InventoryRules.layout(p).cells.indexOf('lw');
    final cell = find.byKey(ValueKey('inv-cell-$i'));
    await tester.ensureVisible(cell);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(cell));
    await tester.pump();
    double fontOf() => tester
        .renderObject<RenderParagraph>(find
            .descendant(
                of: find.byKey(const ValueKey('inv-cmp-tip')),
                matching: find.byType(RichText))
            .first)
        .text
        .style!
        .fontSize!;
    double scale() {
      final t = tester.getSize(find.byKey(const ValueKey('inv-cmp-tip')));
      final r = tester
          .renderObject<RenderBox>(find.byKey(const ValueKey('inv-cmp-tip')));
      return r.localToGlobal(Offset(t.width, 0)).dx -
          r.localToGlobal(Offset.zero).dx;
    }

    final f0 = fontOf();
    final w0 = scale() /
        tester.getSize(find.byKey(const ValueKey('inv-cmp-tip'))).width;
    // Fijar en la caja y desplegar todo (también los sub-plegables).
    await mouse.moveTo(
        tester.getTopLeft(find.byKey(const ValueKey('inv-cmp-tip'))) +
            const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 300));
    for (var round = 0; round < 3; round++) {
      final heads = find.byWidgetPredicate((w) =>
          w is GestureDetector &&
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('tip-fold-') &&
          !(w.key as ValueKey<String>).value.startsWith('tip-fold-body'));
      for (final e in heads.evaluate().toList()) {
        final f = find.byWidget(e.widget);
        if (f.evaluate().isEmpty) continue;
        await tester.ensureVisible(f);
        await tester.pump();
        await tester.tap(f, warnIfMissed: false);
        await tester.pump();
      }
    }
    expect(fontOf(), f0, reason: 'la letra no se achica');
    final w1 = scale() /
        tester.getSize(find.byKey(const ValueKey('inv-cmp-tip'))).width;
    expect(w1, closeTo(w0, 1e-6), reason: 'sin escalado');
    // La caja entra en la pantalla y scrollea.
    final box = tester.getRect(find.byKey(const ValueKey('retro-tip-scroll')));
    expect(box.bottom, lessThanOrEqualTo(240));
    expect(box.top, greaterThanOrEqualTo(0));
    final pos = tester
        .state<ScrollableState>(find.descendant(
            of: find.byKey(const ValueKey('retro-tip-scroll')),
            matching: find.byType(Scrollable)))
        .position;
    expect(pos.maxScrollExtent, greaterThan(0), reason: 'scrolleable');
    expect(RetroHoverCard.anyShowing, isTrue);
    await mouse.removePointer();
  });
}
