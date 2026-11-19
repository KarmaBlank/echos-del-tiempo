import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Tooltips v0.9.7 (docs/specs/ui_style.md § "Tooltips"): uno solo a la
// vez, se cierran al cambiar de pantalla y los cortos se pliegan.

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _tip(String text, String msg, {int? foldAfter}) => RetroTooltip(
    message: msg,
    foldAfter: foldAfter,
    child: SizedBox(width: 120, height: 40, child: Text(text)));

void main() {
  testWidgets('cambia la pantalla con el mouse quieto: queda una sola caja',
      (tester) async {
    await tester.pumpWidget(_app(Center(child: _tip('A', 'tip A'))));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('A')));
    await tester.pump();
    expect(find.text('tip A'), findsOneWidget);
    // Otra pantalla con un objetivo justo debajo del mouse, y la vieja
    // todavía montada (p. ej. una ruta tapada a medias).
    await tester.pumpWidget(_app(Stack(children: [
      Center(child: _tip('A', 'tip A')),
      Center(child: _tip('B', 'tip B')),
    ])));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.text('B')) + const Offset(1, 0));
    await tester.pump();
    expect(find.text('tip B'), findsOneWidget);
    expect(find.text('tip A'), findsNothing, reason: 'una sola a la vez');
    await mouse.removePointer();
    await tester.pump();
  });

  testWidgets('una ruta encima cierra la caja de la de abajo', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: Scaffold(body: Center(child: _tip('A', 'tip A')))));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('A')));
    await tester.pump();
    expect(find.text('tip A'), findsOneWidget);
    nav.currentState!.push(PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, __, ___) => const SizedBox()));
    await tester.pumpAndSettle();
    expect(find.text('tip A'), findsNothing);
    expect(RetroHoverCard.anyShowing, isFalse);
    await mouse.removePointer();
    await tester.pump();
  });

  testWidgets('tooltip corto: resumen + ▸ que se despliega con la caja fija',
      (tester) async {
    await tester.pumpWidget(_app(Align(
        alignment: Alignment.topLeft,
        child: _tip('A', '<b>Nombre</b><br>línea larga de detalle',
            foldAfter: 1))));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('A')));
    await tester.pump();
    final fold = find.byKey(const ValueKey('tip-fold-Más detalle'));
    expect(fold, findsOneWidget);
    expect(find.byKey(const ValueKey('tip-fold-body-Más detalle')),
        findsNothing);
    // Del objetivo a la caja: no se cierra (se fija) y el ▸ despliega.
    await mouse.moveTo(tester.getCenter(fold));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(RetroHoverCard.pinDelay);
    expect(fold, findsOneWidget, reason: 'fija con el mouse encima');
    await mouse.down(tester.getCenter(fold));
    await mouse.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('tip-fold-body-Más detalle')),
        findsOneWidget);
    // Afuera de las dos: se cierra.
    await mouse.moveTo(const Offset(700, 500));
    await tester.pump(RetroHoverCard.pinDelay + const Duration(milliseconds: 50));
    expect(fold, findsNothing);
    await mouse.removePointer();
    await tester.pump();
  });
}
