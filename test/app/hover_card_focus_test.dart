import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Regresión v0.19.1: al cambiar de pestaña (PERSONAJE, etc.) el primer
/// elemento recibe el cursor de teclado y su tip se abría con el mouse
/// quieto sobre la pestaña. Por foco solo se abre si la última entrada
/// fue el teclado.
class _Tabs extends StatefulWidget {
  const _Tabs();
  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Column(children: [
        ElevatedButton(
            key: const ValueKey('tab'),
            onPressed: () => setState(() => tab++),
            child: const Text('PESTAÑA')),
        const SizedBox(height: 100),
        // Como las casillas: el primero queda "enfocado" al abrir.
        RetroTooltip(
            key: ValueKey('cell-$tab'),
            message: 'tip-$tab',
            keyboardFocus: true,
            child: const SizedBox(width: 60, height: 60)),
      ]);
}

void main() {
  testWidgets('cambiar de pestaña con el mouse no abre el tip por foco',
      (tester) async {
    RetroHoverCard.keyboardNav = false;
    await tester.pumpWidget(MaterialApp(
        theme: RetroTheme.build(), home: const Scaffold(body: _Tabs())));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('tab'))));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await mouse.down(tester.getCenter(find.byKey(const ValueKey('tab'))));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.textContaining('tip-', findRichText: true), findsNothing);
    }

    // Con el teclado sí: el elemento con el cursor muestra su tip.
    // (cambio de pestaña con Enter sobre la pestaña enfocada).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(RetroHoverCard.keyboardNav, isTrue);
    Focus.of(tester.element(find.text('PESTAÑA'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.textContaining('tip-', findRichText: true), findsOneWidget);
  });

  testWidgets('una tecla (no modificadora) activa la navegación por teclado',
      (tester) async {
    RetroHoverCard.keyboardNav = false;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    expect(RetroHoverCard.keyboardNav, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(RetroHoverCard.keyboardNav, isTrue);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(const Offset(10, 10));
    expect(RetroHoverCard.keyboardNav, isFalse);
    await mouse.removePointer();
  });
}
