// Pasos del flujo de JUGAR del título (docs/specs/title_screen.md § 1.1),
// compartidos por los tests que necesitan llegar a un paso.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> tapTitleKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump();
}

/// Menú → JUGAR → SOLITARIO → (Mundo → CONTINUAR) → paso Personaje.
Future<void> goToSoloCharacters(WidgetTester tester) async {
  await tapTitleKey(tester, 'title-start');
  await tapTitleKey(tester, 'title-solo');
  await _passWorlds(tester);
}

/// Menú → JUGAR → COOPERATIVO.
Future<void> goToCoop(WidgetTester tester) async {
  await tapTitleKey(tester, 'title-start');
  await tapTitleKey(tester, 'title-coop');
}

/// … → COOPERATIVO → CREAR SALA → (Mundo) → paso Personaje.
Future<void> goToHostCharacters(WidgetTester tester) async {
  await goToCoop(tester);
  await tapTitleKey(tester, 'title-host');
  await _passWorlds(tester);
}

/// … → COOPERATIVO → UNIRSE → código → paso Personaje.
Future<void> goToJoinCharacters(WidgetTester tester, String code) async {
  await goToCoop(tester);
  await tapTitleKey(tester, 'title-join-step');
  await tester.enterText(find.byKey(const ValueKey('title-code')), code);
  await tapTitleKey(tester, 'title-join-next');
}

Future<void> _passWorlds(WidgetTester tester) async {
  final next = find.byKey(const ValueKey('title-worlds-next'));
  if (next.evaluate().isEmpty) return;
  // Los mundos cargan del store (en memoria en los tests).
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tapTitleKey(tester, 'title-worlds-next');
}
