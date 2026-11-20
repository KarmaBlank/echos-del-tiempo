import 'dart:io';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _loaded = false;

/// Carga las fuentes reales del juego (Press Start 2P, VT323 y Atkinson) para que
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
    await (FontLoader(RetroType.atkinsonFamily)
          ..addFont(rootBundle
              .load('assets/fonts/AtkinsonHyperlegible-Regular.ttf')))
        .load();
  }

  if (tester != null) {
    await tester.runAsync(load);
  } else {
    await load();
  }
  _loaded = true;
}

bool _materialLoaded = false;

/// Fuentes de Material que trae el SDK de Flutter (íconos y Roboto, la de
/// los campos de texto del Editor): sin ellas las capturas muestran
/// cuadrados en los íconos y en los números de los `TextField`. Se leen de
/// `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts`; si no están, no
/// hace nada.
Future<void> loadMaterialFonts(WidgetTester tester) async {
  if (_materialLoaded) return;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> font(String family, String file) async {
    final f = File('$dir/$file');
    if (!f.existsSync()) return;
    final bytes = f.readAsBytesSync();
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  }

  await tester.runAsync(() async {
    await font('MaterialIcons', 'materialicons-regular.otf');
    await font('Roboto', 'roboto-regular.ttf');
  });
  _materialLoaded = true;
}
