import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_text.dart';
import 'package:echos_del_tiempo/features/passive_tree/presentation/skill_tree_canvas.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_skills_view.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';

// OFICIOS tree v2 (life_trees_v2.md § 3). With `LIFE_TREE_PREVIEW=1` it
// also writes docs/preview/life_tree_<profession>.png.

final _preview = Platform.environment['LIFE_TREE_PREVIEW'] != null;
final _shot = GlobalKey();

int _xp(int Function(int) need, int level) {
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += need(l);
  }
  return xp;
}

PlayerProfile _crafter(int level) {
  final b = PlayerProfile(name: 'Ana', classId: 'guerrero', level: 10);
  return b.copyWith(
      life: b.life.copyWith(
          fishXp: _xp(FishingRules.xpNeed, level),
          smithXp: _xp(SmithRules.xpNeed, level),
          farm: b.life.farm.copyWith(xp: _xp(FarmingRules.xpNeed, level))));
}

/// [p] with branch [b] of [k] taken up to [tier].
PlayerProfile _upTo(PlayerProfile p, LifeSkillKind k, String b, int tier) {
  final pre = kLifeTrees[k]!.first.id.split('_').first;
  for (var t = 1; t <= tier; t++) {
    p = LifeTreeRules.take(p, k, '${pre}_$b$t') ?? p;
  }
  return p;
}

Future<void> _save(WidgetTester tester, String name) async {
  if (!_preview) return;
  await tester.runAsync(() async {
    final b =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview').createSync(recursive: true);
    File('docs/preview/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('tree renders every node with states and takes a node',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: _crafter(12),
        build: (v, c) => LifeSkillsView(
            profile: v.me!.profile,
            onTake: c.takeLifeNode,
            onReset: c.resetLifeTree));
    await tester.pump();
    // Drawn by the shared skill-tree organism: one hit box per node.
    expect(find.byType(SkillTreeCanvas), findsOneWidget);
    expect(find.byKey(const ValueKey('life-node-labels')), findsOneWidget);
    for (final n in kLifeTrees[LifeSkillKind.pesca]!) {
      expect(find.byKey(ValueKey('life-node-${n.id}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('life-node-fish_r-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('life-node-fish_a1-available')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('life-node-fish_a2-locked')),
        findsOneWidget);
    // Take a reward node through the detail panel.
    final p0 = c.view!.me!.profile;
    for (final id in ['fish_d1', 'fish_d2', 'fish_d3', 'fish_d4']) {
      await tester.ensureVisible(find.byKey(ValueKey('life-node-$id')));
      await tester.tap(find.byKey(ValueKey('life-node-$id')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('life-take')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    final me = c.view!.me!.profile;
    expect(LifeTreeRules.has(me, LifeSkillKind.pesca, 'fish_d4'), isTrue);
    expect(me.items.length, p0.items.length + 1);
    expect(find.byKey(const ValueKey('life-node-fish_d4-taken')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('life-claimed')), findsOneWidget);
    // Nothing is cut with "…".
    for (final r in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      expect(r.didExceedMaxLines, isFalse);
    }
  });

  testWidgets('selecting a node shows its detail; profession switch',
      (tester) async {
    await pumpPanel(tester,
        profile: _crafter(1),
        build: (v, c) => LifeSkillsView(
            profile: v.me!.profile,
            onTake: c.takeLifeNode,
            onReset: c.resetLifeTree));
    await tester.pump();
    final cap = kLifeTrees[LifeSkillKind.pesca]!.last;
    await tester.tap(find.byKey(ValueKey('life-node-${cap.id}')));
    await tester.pump();
    final title = lifeNodeName(cap).toUpperCase();
    expect(
        find.byWidgetPredicate((w) =>
            w is Text && (w.data == title || w.data == retroText(title))),
        findsOneWidget);
    // Level 1: the capstone is behind its level gate, TAKE is disabled.
    expect(find.byKey(ValueKey('life-node-${cap.id}-locked')), findsOneWidget);
    final take = tester.widget<DsButton>(find.byKey(const ValueKey('life-take')));
    expect(take.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('life-row-herreria')));
    await tester.pump();
    final root = kLifeTrees[LifeSkillKind.herreria]!.first;
    expect(find.byKey(ValueKey('life-node-${root.id}-start')), findsOneWidget);
    // Zoom buttons keep every node on the canvas.
    await tester.tap(find.byKey(const ValueKey('life-node-zoom-in')));
    await tester.tap(find.byKey(const ValueKey('life-node-fit')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview per profession', (tester) async {
    var p = _crafter(30);
    p = _upTo(p, LifeSkillKind.pesca, 'b', 10);
    p = _upTo(p, LifeSkillKind.pesca, 'd', 6);
    p = _upTo(p, LifeSkillKind.cultivo, 'e', 10);
    p = _upTo(p, LifeSkillKind.cultivo, 'a', 5);
    p = _upTo(p, LifeSkillKind.herreria, 'c', 10);
    p = _upTo(p, LifeSkillKind.herreria, 'b', 4);
    await pumpPanel(tester,
        profile: p,
        build: (v, c) => RepaintBoundary(
              key: _shot,
              child: Container(
                color: DsColors.background,
                padding: const EdgeInsets.all(16),
                child: LifeSkillsView(
                    profile: v.me!.profile,
                    onTake: c.takeLifeNode,
                    onReset: c.resetLifeTree),
              ),
            ));
    tester.view.physicalSize = const Size(1280, 960);
    await tester.pump();
    for (final k in LifeSkillKind.values) {
      await tester.tap(find.byKey(ValueKey('life-row-${k.name}')));
      await tester.pump();
      final cap = kLifeTrees[k]!.firstWhere((n) => n.capstone &&
          LifeTreeRules.has(p, k, n.id));
      await tester.tap(find.byKey(ValueKey('life-node-${cap.id}')));
      await tester.pump();
      expect(find.text(lifeNodeName(cap).toUpperCase()), findsOneWidget);
      await _save(tester, 'life_tree_${k.name}');
      if (k == LifeSkillKind.pesca) await _save(tester, 'life_tree_view');
    }
  });
}
