import 'package:echos_del_tiempo/app/design/ds_components.dart';
import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Tooltips anclados (ui_style.md § "Tooltips anclados"): cerca del borde
/// de abajo la caja no salta arriba del cursor; si no entra, scrollea, y
/// sigue abierta con el mouse encima. Desplegar "▸ Más detalle" no la
/// mueve.
void main() {
  Future<TestGesture> setUp(WidgetTester t, Widget tip) async {
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          // Objetivo a 220 px del borde de abajo: hay lugar (≥ mínimo)
          // debajo, pero no para todo el texto.
          Positioned(left: 600, top: 460, child: tip),
        ]),
      ),
    ));
    final g = await t.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(t.getCenter(find.byKey(const ValueKey('target'))));
    await t.pumpAndSettle();
    return g;
  }

  const target = SizedBox(key: ValueKey('target'), width: 40, height: 40);
  final long = List.filled(60, 'línea larga del tooltip').join('<br>');

  testWidgets('RetroTooltip abajo: anclado debajo, scrollea, abierto encima',
      (t) async {
    final g = await setUp(t, RetroTooltip(message: long, child: target));
    final tRect = t.getRect(find.byKey(const ValueKey('target')));
    final scroll = find.byKey(const ValueKey('retro-tip-scroll'));
    expect(scroll, findsOneWidget);
    final box = t.getRect(scroll);
    expect(box.top, greaterThanOrEqualTo(tRect.bottom));
    expect(box.bottom, lessThanOrEqualTo(720));
    final sv = t.widget<SingleChildScrollView>(find.descendant(
        of: scroll, matching: find.byType(SingleChildScrollView)));
    expect(sv.controller!.position.maxScrollExtent, greaterThan(0));
    // Pasar a la caja la deja abierta.
    await g.moveTo(box.center);
    await t.pump(const Duration(milliseconds: 400));
    expect(RetroHoverCard.anyShowing, isTrue);
    await t.pumpAndSettle();
    expect(t.getRect(scroll).top, box.top);
  });

  testWidgets('desplegar Más detalle cerca del borde no mueve la caja',
      (t) async {
    final g = await setUp(
        t, RetroTooltip(message: long, foldAfter: 2, child: target));
    final fold = find.textContaining('Más detalle');
    expect(fold, findsOneWidget);
    final before = t.getRect(find.byKey(const ValueKey('retro-tip-scroll')));
    await g.moveTo(t.getCenter(fold));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(fold);
    await t.pumpAndSettle();
    expect(RetroHoverCard.anyShowing, isTrue);
    final after = t.getRect(find.byKey(const ValueKey('retro-tip-scroll')));
    expect(after.top, before.top);
    expect(after.bottom, lessThanOrEqualTo(720));
  });

  testWidgets('DsTooltip abajo: anclado debajo y abierto con el mouse encima',
      (t) async {
    final g = await setUp(
        t,
        DsTooltip(
            card: DsTooltipCard(
                title: 'Mecánica', children: [Text('x ' * 2000)]),
            child: target));
    final tRect = t.getRect(find.byKey(const ValueKey('target')));
    final card = find.byType(DsTooltipCard);
    final r = t.getRect(card);
    expect(r.top, greaterThanOrEqualTo(tRect.bottom));
    expect(r.bottom, lessThanOrEqualTo(720));
    await g.moveTo(r.center);
    await t.pump(const Duration(milliseconds: 400));
    expect(card, findsOneWidget);
  });
}
