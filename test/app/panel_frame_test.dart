import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(body: child),
    ));
    await tester.pump();
  }

  testWidgets('marco: Esc cierra, Tab mueve el foco y Enter activa',
      (tester) async {
    var closed = 0;
    final pressed = <String>[];
    await pump(
        tester,
        PanelFrame(
          title: 'PRUEBA',
          help: 'Ayuda de la <b>prueba</b>',
          onClose: () => closed++,
          leading: [
            PanelButton('A',
                key: const ValueKey('a'), onPressed: () => pressed.add('A')),
          ],
          actions: [
            PanelButton('B',
                key: const ValueKey('b'), onPressed: () => pressed.add('B')),
            PanelButton('C',
                key: const ValueKey('c'), onPressed: () => pressed.add('C')),
          ],
          child: const Text('contenido'),
        ));
    expect(find.byKey(const ValueKey('panel-help')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, 1);

    // Tab al primer botón, Tab al segundo, Enter lo activa.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(pressed, ['B']);
    // Flecha a la derecha: siguiente botón.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(pressed, ['B', 'C']);

    // El primario queda abajo a la derecha.
    final c = tester.getCenter(find.byKey(const ValueKey('c')));
    final b = tester.getCenter(find.byKey(const ValueKey('b')));
    final a = tester.getCenter(find.byKey(const ValueKey('a')));
    expect(c.dx, greaterThan(b.dx));
    expect(a.dx, lessThan(b.dx));
  });

  testWidgets('marco: sin onClose el Esc no se usa', (tester) async {
    await pump(tester, const PanelFrame(title: 'X', child: Text('contenido')));
    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(handled, isFalse);
  });

  testWidgets('botón deshabilitado muestra el motivo', (tester) async {
    await pump(
        tester,
        PanelFrame(
          title: 'X',
          actions: [
            PanelButton('COMPRAR', reason: 'Faltan \$5', onPressed: () {}),
          ],
          child: const SizedBox(),
        ));
    expect(find.text('Faltan \$5'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(btn.onPressed, isNull);
  });
}
