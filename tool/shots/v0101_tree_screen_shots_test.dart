// Capturas de la pantalla PERSONAJE → ÁRBOL nueva (v0.10.1,
// progression_v2.md § 11.2). NO es parte de la suite. Correr con
//   flutter test tool/shots/v0101_tree_screen_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/panel_test_harness.dart';
import '../../test/features/passive_tree/passive_tree_view_test.dart'
    show tapNode;
import '../../test/game_engine/session_test_helpers.dart';

const _out = 'docs/release_shots/v0.10.1';

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(const Offset(0, 0) & const Size(1280, 720));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _tree(WidgetTester tester, PlayerProfile p) => pumpPanel(tester,
    profile: progression.normalize(p),
    build: (v, c) =>
        CharacterPanel(view: v, controller: c, initialTab: CharacterTab.tree));

void main() {
  final rules = treeRules;
  final taken =
      rules.pathTo('maga', PlayerPassiveProgress.empty, 'marea_na') ?? [];

  testWidgets('árbol: normal', (tester) async {
    await _tree(
        tester,
        PlayerProfile(
            name: 'Ana',
            classId: 'maga',
            level: taken.length + 4,
            tree: taken,
            milestone10: rules.milestoneOptions('maga', 10).first));
    await _shot(tester, 'pantalla_arbol.png');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('árbol: tooltip fijado', (tester) async {
    await _tree(
        tester,
        PlayerProfile(
            name: 'Ana',
            classId: 'maga',
            level: taken.length + 4,
            tree: taken,
            milestone10: rules.milestoneOptions('maga', 10).first));
    await tapNode(tester, kTooltipNode);
    await tester.pump();
    await _shot(tester, 'pantalla_arbol_tooltip.png');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('árbol: tarjetas de hito', (tester) async {
    await _tree(
        tester, PlayerProfile(name: 'Ana', classId: 'maga', level: 10));
    final opts = rules.milestoneOptions('maga', 10);
    await tester.tap(find.byKey(ValueKey('milestone-pick-${opts[1]}')));
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
        location:
            tester.getCenter(find.byKey(ValueKey('milestone-pick-${opts[1]}'))));
    await tester.pump();
    await _shot(tester, 'pantalla_arbol_hito.png');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}

/// Un notable lejano (sin conexión): el tooltip muestra TOMAR CAMINO.
const kTooltipNode = 'marea_nc';
