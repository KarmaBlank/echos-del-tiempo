// Capturas del hito en columna dentro del visor del árbol (v0.13.3,
// progression_v2.md § 11.2). NO es parte de la suite. Correr con
//   flutter test tool/shots/v0133_hito_columna_shots_test.dart
// (variable SHOT_TAG=antes|despues elige el nombre del archivo).
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

const _out = 'docs/release_shots/v0.13.3';

void main() {
  final tag = Platform.environment['SHOT_TAG'] ?? 'despues';
  testWidgets('hito en columna', (tester) async {
    await pumpPanel(tester,
        profile: progression.normalize(
            PlayerProfile(name: 'Ana', classId: 'maga', level: 10)),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.tree));
    final opts = treeRules.milestoneOptions('maga', 10);
    final card = find.byKey(ValueKey('milestone-pick-${opts[1]}'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(card));
    await tester.pump();
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final img =
          await layer.toImage(const Offset(0, 0) & const Size(1280, 720));
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('$_out/hito_columna_$tag.png');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
