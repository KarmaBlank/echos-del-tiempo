// Capturas de la vista de hito (v0.13.1, progression_v2.md § 11.4) a
// 1920×1080. NO es parte de la suite. Correr con
//   flutter test tool/shots/v0131_hito_shots_test.dart
// (SHOT_NAME=hito_antes.png para la captura del código anterior).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';

const _out = 'docs/release_shots/v0.13.1';

void main() {
  testWidgets('hito del nivel 20 con el mouse en una tarjeta',
      (tester) async {
    await pumpPanel(tester,
        devicePixelRatio: 1.5,
        profile: progression.normalize(PlayerProfile(
            name: 'Ana',
            classId: 'maga',
            level: 20,
            milestone10: treeRules.milestoneOptions('maga', 10).first)),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.tree));
    final opts = treeRules.milestoneOptions('maga', 20);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
        tester.getCenter(find.byKey(ValueKey('milestone-pick-${opts[1]}'))));
    await tester.pump();
    final name = Platform.environment['SHOT_NAME'] ?? 'hito_despues.png';
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final img = await layer.toImage(
          const Offset(0, 0) & const Size(1280, 720),
          pixelRatio: 1.5);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('$_out/$name');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
