// La lista de ULT de PERSONAJE muestra los nombres completos (sin "…")
// a 1280×720 y 1024×640. Con ULT_SHOTS=<carpeta> guarda las capturas:
//   $env:ULT_SHOTS = "docs\release_shots\v0.24.4"; flutter test test/features/characters/ult_list_legible_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

final _out = Platform.environment['ULT_SHOTS'];

void main() {
  for (final size in const [Size(1280, 720), Size(1024, 640)]) {
    testWidgets('nombres de ULT completos a ${size.width.toInt()}', (tester) async {
      final key = GlobalKey();
      await pumpPanel(tester,
          profile: newProfile('Ana', 'paladin'),
          build: (v, c) => RepaintBoundary(
              key: key, child: CharacterPanel(view: v, controller: c)));
      tester.view.physicalSize = size;
      await tester.pump();
      final tab = CharacterTab.values.indexOf(CharacterTab.ults);
      await tester.tap(find.byKey(ValueKey('tab-$tab')));
      await tester.pump();
      expect(find.byKey(const ValueKey('ult-filter-bar')), findsOneWidget);
      final longest = [...kUltV2List]
        ..sort((a, b) => b.skill.name.length.compareTo(a.skill.name.length));
      final u = longest.first;
      final row = find.byKey(ValueKey('ult-row-${u.id}'));
      await tester.ensureVisible(row);
      await tester.pump();
      final title = find.descendant(of: row, matching: find.byType(RichText));
      for (final p in tester.renderObjectList<RenderParagraph>(title)) {
        expect(p.didExceedMaxLines, isFalse);
      }
      expect(tester.takeException(), isNull);
      final out = _out;
      if (out == null) return;
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('ult-filter-bar')), -200,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        final name = size.width == 1280 ? 'ult_lista' : 'ult_lista_1024';
        File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
