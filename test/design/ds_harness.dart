import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Monta [child] con el tema retro + DsTheme, el escalador del texto y el
/// tema de interfaz pedidos.
Future<void> pumpDs(WidgetTester tester, Widget child,
    {double factor = 1,
    InterfaceTheme theme = InterfaceTheme.highContrast,
    Size size = const Size(1280, 720)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(UiTheme.reset);
  addTearDown(RetroType.reset);
  UiTheme.kind = theme;
  UiTheme.textColors = TextColorMode.reduced;
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: DsTheme.apply(RetroTheme.build()),
    builder: (context, c) => RetroTextScale(factor: factor, child: c!),
    home: Scaffold(
      backgroundColor: DsColors.background,
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RepaintBoundary(key: dsShotKey, child: child),
        ),
      ),
    ),
  ));
  await tester.pump();
}

final dsShotKey = GlobalKey();
