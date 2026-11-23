// Lista de PLANTILLAS de BUILD: nombres completos (sin "…") y etiquetas
// en una fila, a 1280×720 y 1024×640 (v0.24.4). Con TPL_SHOTS=<carpeta>
// guarda plantillas_lista.png:
//   $env:TPL_SHOTS = "docs\release_shots\v0.24.4"; flutter test test/features/build_planner/template_list_legible_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../helpers/build_templates_fixture.dart';
import '../panel_test_harness.dart';

final _out = Platform.environment['TPL_SHOTS'];

void main() {
  setUpAll(installBuildTemplates);

  for (final size in const [Size(1280, 720), Size(1024, 640)]) {
    testWidgets('plantillas sin "…" a ${size.width.toInt()}', (tester) async {
      await pumpPanel(tester,
          profile: progression.normalize(
              PlayerProfile(name: 'Ana', classId: 'paladin', level: 6)),
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.build));
      tester.view.physicalSize = size;
      await tester.pump();
      await tapVisible(tester, find.byKey(const ValueKey('build-edit')));
      await tapVisible(tester, find.byKey(const ValueKey('build-template')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tpl-tag-bar')), findsOneWidget);
      final rows = find.byWidgetPredicate((w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('tpl-pal'));
      expect(rows, findsWidgets);
      for (final p in tester.renderObjectList<RenderParagraph>(
          find.descendant(of: rows, matching: find.byType(RichText)))) {
        expect(p.didExceedMaxLines, isFalse);
      }
      expect(tester.takeException(), isNull);
      final out = _out;
      if (out == null) return;
      await tester.runAsync(() async {
        final b = tester.renderObject<RenderRepaintBoundary>(
            find
                .ancestor(
                    of: find.byKey(const ValueKey('tpl-tag-bar')),
                    matching: find.byType(RepaintBoundary))
                .last);
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        final name = size.width == 1280
            ? 'plantillas_lista'
            : 'plantillas_lista_1024';
        File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
