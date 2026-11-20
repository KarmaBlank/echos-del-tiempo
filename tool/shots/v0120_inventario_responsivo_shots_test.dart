// Capturas antes / después del INVENTARIO responsivo (v0.12.0,
// panels.md § "Inventario"): 1750×1040 con texto Grande y muchos
// materiales. NO es parte de la suite. Correr con
//   $env:SHOT_SUFFIX="antes"; flutter test tool/shots/v0120_inventario_responsivo_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/inventory/loot_fixtures.dart';
import '../../test/features/panel_test_harness.dart';

const _out = 'docs/release_shots/v0.12.0';
final _suffix = Platform.environment['SHOT_SUFFIX'] ?? 'despues';

void main() {
  testWidgets('inventario 1750x1040 texto grande', (tester) async {
    var p = lootWarrior();
    for (final k in StackKind.values) {
      p = InventoryRules.withStack(p, k, 3);
    }
    await pumpPanel(tester,
        profile: p,
        textSize: TextSize.large,
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));
    tester.view.physicalSize = const Size(1750, 1040);
    await tester.pump();
    await tester.pump();
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final img =
          await layer.toImage(const Offset(0, 0) & const Size(1750, 1040));
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('$_out/inventario_responsivo_$_suffix.png');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
