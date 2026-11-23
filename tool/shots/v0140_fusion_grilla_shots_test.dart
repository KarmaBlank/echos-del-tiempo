// Capturas antes / después de la FUSIÓN con la grilla de ítems (v0.14.0,
// docs/specs/design_system.md § "Estructura atómica"). NO es parte de la
// suite. Correr con
//   $env:SHOT_SUFFIX="antes"; flutter test tool/shots/v0140_fusion_grilla_shots_test.dart
// (con la mesa de main) o con "despues" en la rama.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/inventory/loot_fixtures.dart';
import '../../test/features/panel_test_harness.dart';

const _out = 'docs/release_shots/v0.14.0';
final _suffix = Platform.environment['SHOT_SUFFIX'] ?? 'despues';

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img =
        await layer.toImage(const Offset(0, 0) & const Size(1920, 1080));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/${name}_$_suffix.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('fusión: elegir arma', (tester) async {
    await pumpPanel(tester,
        devicePixelRatio: 1.5,
        profile: lootWarrior(),
        build: (v, c) =>
            ForgePanel(view: v, controller: c, initialTab: ForgeHallTab.fuse));
    await tester.pump();
    await _shot(tester, 'fusion_grilla');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
