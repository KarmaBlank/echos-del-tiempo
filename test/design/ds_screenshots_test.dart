// Capturas 1920×1080 de la galería del sistema de diseño
// (docs/specs/design_system.md § 8). Solo corre con DS_SHOTS=1:
//   $env:DS_SHOTS = "1"; flutter test test/design/ds_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/app/design/gallery/ds_gallery_screen.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:echos_del_tiempo/core/settings/crt_filter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../real_fonts.dart';

final _on = Platform.environment['DS_SHOTS'] != null;

const _names = {
  DsGalleryPage.palette: '01_paleta_tipografia',
  DsGalleryPage.buttons: '02_botones_estados',
  DsGalleryPage.navigation: '03_pestanas_barra_busqueda',
  DsGalleryPage.surfaces: '04_tooltip_tarjeta_aviso',
  DsGalleryPage.character: '05_mockup_personaje',
  DsGalleryPage.inventory: '06_mockup_inventario',
  DsGalleryPage.battle: '07_mockup_batalla',
};

void main() {
  for (final p in DsGalleryPage.values) {
    testWidgets('captura ${p.name}', (tester) async {
      await loadRealFonts(tester);
      await tester.runAsync(CrtShaders.load);
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(UiTheme.reset);
      addTearDown(RetroType.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: EcosApp(home: DsGalleryScreen(initialPage: p))));
      await tester.pump();
      await tester.pump();
      await tester.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory('docs/design').createSync(recursive: true);
        File('docs/design/${_names[p]}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }, skip: !_on);
  }
}
