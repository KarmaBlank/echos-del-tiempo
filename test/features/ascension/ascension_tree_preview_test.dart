// Previews of the ascension tree v2 (docs/specs/ascension.md § 3.6): one
// PNG per ascension in docs/preview/ascension_tree_<id>.png. Only runs
// with ASC_TREE_PREVIEW=1:
//   $env:ASC_TREE_PREVIEW = "1"; flutter test test/features/ascension/ascension_tree_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:echos_del_tiempo/features/ascension/presentation/ascension_views.dart';
import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';

final _on = Platform.environment['ASC_TREE_PREVIEW'] != null;

/// A plausible mid-game build: one branch to its capstone, another to
/// its first notable, and the first Trades node.
List<String> _sample(AscensionDef a) {
  String at(int b, int t) =>
      a.nodes.firstWhere((n) => n.branch == b && n.tier == t).id;
  return [
    for (var t = 1; t <= 10; t++) at(0, t),
    for (var t = 1; t <= 3; t++) at(3, t),
    at(4, 1),
  ];
}

void main() {
  for (final a in kAscensions.values) {
    testWidgets('preview ${a.id}', (tester) async {
      await loadRealFonts(tester);
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(UiTheme.reset);
      addTearDown(RetroType.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: RetroTheme.build(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AscensionTreeView(
                  def: a,
                  progress: AscensionProgress(
                      trials: const {1, 2, 3}, id: a.id, nodes: _sample(a)),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory('docs/preview').createSync(recursive: true);
        File('docs/preview/ascension_tree_${a.id}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }, skip: !_on);
  }
}
