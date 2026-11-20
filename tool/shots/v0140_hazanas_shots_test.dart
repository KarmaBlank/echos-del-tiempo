// Capturas de las Hazañas (v0.14.0, docs/specs/achievements.md § 7) a
// 1920×1080: la pestaña HAZAÑAS (con el tooltip de cómo se consigue) y el
// toast. NO es parte de la suite. Correr con
//   flutter test tool/shots/v0140_hazanas_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/achievements/presentation/achievement_feed.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/achievement.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';

const _out = 'docs/release_shots/v0.14.0';

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

PlayerProfile _profile() => progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'maga',
      level: 14,
      achievements: AchievementProgress(done: {
        'forge_first': 1763000000,
        'fuse_first': 1763100000,
        'fuse_skill': 1763100500,
        'sell_first': 1763200000,
        'combat_break': 1763300000,
        'tree_milestone': 1763400000,
      }, counters: {
        'forgeLevels': 7,
        'fusions': 3,
        'salvaged': 6,
      }),
    ));

void main() {
  testWidgets('HAZAÑAS: pestaña con tooltip', (tester) async {
    await pumpPanel(tester,
        devicePixelRatio: 1.5,
        profile: _profile(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.achievements));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('ach-row-forge_10'))));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 200));
    await _shot(tester, 'hazanas_pestana');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('HAZAÑAS: toast', (tester) async {
    await pumpPanel(tester,
        devicePixelRatio: 1.5,
        profile: _profile(),
        build: (v, c) => Stack(children: [
              Positioned.fill(
                  child: CharacterPanel(
                      view: v,
                      controller: c,
                      initialTab: CharacterTab.inventory)),
              const Positioned(
                  top: 56,
                  right: 12,
                  child: AchievementToastBox(id: 'fuse_skill')),
            ]));
    await tester.pumpAndSettle();
    await _shot(tester, 'hazanas_toast');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
