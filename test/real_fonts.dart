import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _loaded = false;

/// Carga las fuentes reales del juego (Press Start 2P y VT323) para que
/// los tests y las capturas midan y dibujen con los glifos de verdad (sin
/// esto `flutter test` usa una fuente de prueba de cuadrados). Una vez por
/// proceso. Dentro de un `testWidgets`, pasar [tester] (corre fuera del
/// reloj falso); en `setUpAll`, sin él.
Future<void> loadRealFonts([WidgetTester? tester]) async {
  if (_loaded) return;
  Future<void> load() async {
    await (FontLoader(RetroType.pixelFamily)
          ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf')))
        .load();
    await (FontLoader(RetroType.vt323Family)
          ..addFont(rootBundle.load('assets/fonts/VT323-Regular.ttf')))
        .load();
  }

  if (tester != null) {
    await tester.runAsync(load);
  } else {
    await load();
  }
  _loaded = true;
}
