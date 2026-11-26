// Previews of the met / unmet status colours and the tree tooltips
// (design_system.md § 3.4). Only runs with PREVIEW=1 (or PREVIEW_SHOTS=1):
//   $env:PREVIEW = "1"; flutter test test/design/text_hierarchy_2_preview_test.dart
// Writes docs/preview/text_hierarchy_2/*.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/design/gallery/ds_examples.dart';
import 'package:echos_del_tiempo/features/passive_tree/presentation/passive_tree_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_skills_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/town_build_palette.dart';
import 'package:echos_del_tiempo/game_engine/data/life_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';

final _on = Platform.environment['PREVIEW'] != null ||
    Platform.environment['PREVIEW_SHOTS'] != null;

const _dir = 'docs/preview/text_hierarchy_2';

/// Saves [rect] of the whole screen (overlays included).
Future<void> _save(WidgetTester tester, String name, Rect rect) async {
  await tester.runAsync(() async {
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final img = await layer.toImage(rect, pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
    img.dispose();
  });
}

/// The whole logical view.
Rect _view(WidgetTester tester) =>
    Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;

Future<TestGesture> _mouseTo(WidgetTester tester, Offset at) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  await g.moveTo(at);
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
  return g;
}

Widget _box(Widget child) => ColoredBox(
    color: DsColors.surface,
    child: Align(
        alignment: Alignment.topLeft,
        child: Padding(padding: const EdgeInsets.all(24), child: child)));

PlayerProfile get _ana =>
    progression.normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'));

Widget _cell(Color c) => Container(width: 20, height: 20, color: c);

void main() {
  testWidgets('cost grid: met and unmet', (tester) async {
    await pumpPanel(tester,
        profile: _ana,
        build: (v, c) => _box(DsCostGrid([
              for (final (id, have, need, col) in [
                ('tablas', 12, 8, const Color(0xFFB07040)),
                ('hierro', 2, 5, const Color(0xFF9AA4B0)),
                ('piedra', 6, 6, const Color(0xFF808890)),
                ('fibra', 0, 3, const Color(0xFF90B060)),
              ])
                DsCostEntry(
                    id: id,
                    icon: _cell(col),
                    need: need,
                    have: have,
                    card: DsTooltipCard.text('$id $have/$need')),
            ])));
    final g = await _mouseTo(
        tester, tester.getCenter(find.byKey(const ValueKey('cost-hierro'))));
    expect(g, isNotNull);
    await _save(tester, 'cost_grid', const Rect.fromLTWH(0, 0, 420, 160));
  }, skip: !_on);

  testWidgets('quest checklist', (tester) async {
    tester.view.physicalSize = const Size(1280, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPanel(tester,
        profile: _ana,
        build: (v, c) => const ColoredBox(
            color: DsColors.surface,
            child: SingleChildScrollView(
                padding: EdgeInsets.all(24), child: QuestTemplateMockup())));
    await tester.pump();
    await _save(tester, 'quest_checklist', _view(tester));
  }, skip: !_on);

  testWidgets('skill tree tooltip (life tree)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPanel(tester,
        profile: _ana,
        build: (v, c) => LifeSkillsView(
            profile: v.me!.profile,
            onTake: c.takeLifeNode,
            onReset: c.resetLifeTree));
    await tester.pump();
    final n = kLifeTrees[LifeSkillKind.pesca]![2];
    final f = find.byKey(ValueKey('life-node-${n.id}'));
    await tester.ensureVisible(f);
    await tester.pump();
    await _mouseTo(tester, tester.getCenter(f));
    await _save(tester, 'skill_tree_tooltip', _view(tester));
  }, skip: !_on);

  testWidgets('passive tree tooltip', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPanel(tester,
        profile: progression.normalize(
            PlayerProfile(name: 'Leo', classId: 'tirador', level: 1)),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.tree));
    await tester.ensureVisible(find.byKey(const ValueKey('tree-viewport')));
    await tester.pump();
    final path = treeRules.pathTo(
        'tirador', PlayerPassiveProgress.empty, 'precision_k')!;
    final id = path[1];
    final box = tester
        .renderObject<RenderBox>(find.byKey(const ValueKey('tree-canvas')));
    await _mouseTo(tester,
        box.localToGlobal(PassiveTreeView.nodeCenter(kPassiveTree.nodes[id]!)));
    expect(find.byKey(const ValueKey('tree-tooltip')), findsOneWidget);
    await _save(tester, 'passive_tree_tooltip', _view(tester));
  }, skip: !_on);

  testWidgets('building detail (build palette)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPanel(tester,
        profile: _ana,
        build: (v, c) => ColoredBox(
            color: DsColors.surface,
            child: TownBuildPalette(controller: c)));
    await tester.pump();
    final f = find.byKey(const ValueKey('town-edit-build-huerta_chica'));
    await _mouseTo(tester, tester.getCenter(f));
    await _save(tester, 'building_detail', _view(tester));
  }, skip: !_on);
}
