// Capturas antes / después de la forma del árbol v7 (v0.10.1,
// progression_v2.md § 11.1). NO es parte de la suite. Correr con
//   flutter test tool/shots/v0101_tree_shape_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/passive_tree/presentation/passive_tree_view.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/game_engine/passive_tree_v7_shape_test.dart' show v7Before;
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.10.1';

Future<void> _render(WidgetTester tester, PassiveTreeCatalog c, String title,
    String file, {double crop = 1}) async {
  const side = 1400.0;
  const s = PassiveTreeView.size;
  final picSide = s * crop;
  final key = GlobalKey();
  tester.view.physicalSize = const Size(side, side + 60);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: RepaintBoundary(
      key: key,
      child: ColoredBox(
        color: ProtoColors.bg,
        child: Column(children: [
          SizedBox(
            height: 60,
            child: Center(
                child: Text(title,
                    style: const TextStyle(
                        fontFamily: RetroType.pixelFamily,
                        fontSize: 18,
                        color: ProtoColors.gold))),
          ),
          SizedBox(
            width: side,
            height: side,
            child: FittedBox(
              child: SizedBox(
                width: picSide,
                height: picSide,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: s,
                    maxHeight: s,
                    child: CustomPaint(
                      size: const Size(s, s),
                      painter: PassiveTreePainter(
                        catalog: c,
                        startId: c.startNodeByClass.values.first,
                        states: const {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    ),
  ));
  await tester.pump();
  final ro = key.currentContext!.findRenderObject()! as dynamic;
  await tester.runAsync(() async {
    final ui.Image img = await ro.toImage(pixelRatio: 1.0);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$file');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('árbol antes / después', (tester) async {
    await loadRealFonts(tester);
    final before = v7Before();
    for (final (c, name, t) in [
      (kPassiveTreeV6, 'v6', 'ARBOL V6 (REFERENCIA)'),
      (before, 'antes', 'ARBOL V7 - v0.10.0 (ANTES)'),
      (kPassiveTree, 'despues', 'ARBOL V7 - v0.10.1 (DESPUES)'),
    ]) {
      await _render(tester, c, t, 'arbol_completo_$name.png');
      await _render(tester, c, '$t - CENTRO', 'arbol_centro_$name.png',
          crop: 0.3);
    }
  });
}
