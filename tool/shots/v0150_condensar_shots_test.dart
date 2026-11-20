// Capturas de CONDENSAR en la mesa de fusión (v0.15.0,
// docs/specs/materials_economy.md § 4.3). NO es parte de la suite. Correr
// con
//   flutter test tool/shots/v0150_condensar_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/inventory/loot_fixtures.dart';
import '../../test/features/panel_test_harness.dart';

const _out = 'docs/release_shots/v0.15.0';

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img =
        await layer.toImage(const Offset(0, 0) & const Size(1920, 1080));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, String key) =>
    tapVisible(tester, find.byKey(ValueKey(key)));

void main() {
  testWidgets('condensar: botón, recetas y confirmación', (tester) async {
    await pumpPanel(tester,
        devicePixelRatio: 1.5,
        profile: lootWarrior(credits: 4200, materials: const {
          CraftMaterial.esquirla: 99,
          CraftMaterial.cristal: 14,
          CraftMaterial.prisma: 1,
        }),
        build: (v, c) =>
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.fuse));
    await tester.pump();
    await _shot(tester, '01_fusion_boton_condensar');
    await _tap(tester, 'bench-condense');
    await _shot(tester, '02_condensar_recetas');
    await _tap(tester, 'condense-cristal-all');
    await _shot(tester, '03_condensar_confirmar');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
