import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Comprueba que [f] se ve como botón (ui_style.md § "Toda acción se ve
/// como botón"): fondo `button` / `buttonHover` y borde fino visible; o,
/// con [enabled] `false`, sin fondo ni borde.
void expectButtonLook(WidgetTester tester, Finder f, {bool enabled = true}) {
  expect(f, findsOneWidget);
  final bgs = {
    ProtoColors.button.toARGB32(),
    ProtoColors.buttonHover.toARGB32(),
  };
  bool isTransparent(Color? c) => c == null || c.a == 0;
  // ElevatedButton / PanelButton: la Material interna lleva fondo y borde.
  for (final m in tester.widgetList<Material>(find.descendant(
      of: f, matching: find.byType(Material), matchRoot: true))) {
    final shape = m.shape;
    if (shape is! OutlinedBorder) continue;
    if (enabled) {
      expect(bgs, contains(m.color!.toARGB32()), reason: 'fondo de botón');
      expect(shape.side.width, greaterThan(0));
      expect(isTransparent(shape.side.color), isFalse, reason: 'borde');
    } else {
      expect(isTransparent(m.color), isTrue, reason: 'sin fondo');
      expect(isTransparent(shape.side.color), isTrue, reason: 'sin borde');
    }
    return;
  }
  // Filas y cajas (MenuRow, ActionBox): BoxDecoration.
  for (final d in tester.widgetList<DecoratedBox>(find.descendant(
      of: f, matching: find.byType(DecoratedBox), matchRoot: true))) {
    final dec = d.decoration;
    if (dec is! BoxDecoration || dec.border == null) continue;
    final side = (dec.border! as Border).top;
    if (enabled) {
      expect(bgs, contains(dec.color!.toARGB32()), reason: 'fondo de botón');
      expect(isTransparent(side.color), isFalse, reason: 'borde');
    } else {
      expect(isTransparent(dec.color), isTrue, reason: 'sin fondo');
    }
    return;
  }
  fail('sin decoración de botón');
}
