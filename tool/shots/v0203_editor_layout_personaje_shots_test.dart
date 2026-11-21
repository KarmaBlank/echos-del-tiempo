// Capturas de v0.20.3 (docs/specs/editor_layout.md § 6, fase 4): Editor →
// LAYOUT moviendo en PERSONAJE el grupo REINICIAR / DESHACER / CONFIRMAR
// al pie del marco y CONFIRMAR suelto en la barra. NO es parte de la suite:
//   flutter test tool/shots/v0203_editor_layout_personaje_shots_test.dart
// Overrides en una carpeta temporal (nunca %APPDATA% ni el repo).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/layout/layout_catalog.dart';
import 'package:echos_del_tiempo/core/layout/layout_overrides_io.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/layout_editor_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_layout.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/admin/fake_admin_host.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.20.3/editor';

void main() {
  testWidgets('v0.20.3: Editor LAYOUT, PERSONAJE', (tester) async {
    await loadRealFonts(tester);
    await loadMaterialFonts(tester);
    tester.view.physicalSize = const Size(1800, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('ecos_v0203_shots_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final overrides = LocalLayoutOverrides('${tmp.path}/overrides');
    final catalog = LayoutCatalog(overrides: overrides);
    await tester.runAsync(catalog.load);
    final l = LayoutEditorController(
        catalog: catalog, overrides: overrides, repoPath: tmp.path);
    final c = AdminController(
        host: FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    }));
    await tester.runAsync(c.load);

    final key = GlobalKey();
    Future<void> save(String name) async {
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        final f = File('$_out/$name.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: AdminApp(
            controller: c, layouts: l, initialArea: EditorArea.layout)));
    await tester.pump();
    l.openScreen(l.previews
        .indexWhere((p) => p.screen == CharacterLayout.screen));
    l.select(CharacterLayout.attrActions);
    await save('layout_personaje_antes');

    l
      ..move(CharacterLayout.attrActions, 'actions', 0)
      ..move(CharacterLayout.confirm, 'toolbar', 1)
      ..select(CharacterLayout.confirm);
    await save('layout_personaje_despues');
    expect(tester.takeException(), isNull);
  });
}
