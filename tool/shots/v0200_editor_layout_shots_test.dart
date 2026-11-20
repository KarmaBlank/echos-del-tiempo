// Capturas de v0.20.0 (docs/specs/editor_layout.md § 3): Editor → LAYOUT
// moviendo la fila de botones del ALIJO, antes/después en dos tamaños.
// NO es parte de la suite:
//   flutter test tool/shots/v0200_editor_layout_shots_test.dart
// Overrides en una carpeta temporal (nunca %APPDATA% ni el repo).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/layout/layout_catalog.dart';
import 'package:echos_del_tiempo/core/layout/layout_overrides_io.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/layout_editor_controller.dart';
import 'package:echos_del_tiempo/features/characters/presentation/stash_layout.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/admin/fake_admin_host.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.20.0/editor';

void main() {
  testWidgets('v0.20.0: Editor LAYOUT, fila de acciones del alijo',
      (tester) async {
    await loadRealFonts(tester);
    await loadMaterialFonts(tester);
    tester.view.physicalSize = const Size(1800, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('ecos_v0200_shots_');
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

    // Antes (1280×720): la fila seleccionada en el pie.
    l.select(StashLayout.actions);
    await save('layout_alijo_1280_antes');

    // Arrastre en curso: guía de inserción y región destino resaltada.
    final from = tester.getCenter(find.byKey(const ValueKey('stash-move-all')));
    final to = tester.getCenter(find.byKey(const ValueKey('stash-search-stash')));
    final g = await tester.startGesture(from);
    await tester.pump();
    await g.moveBy(const Offset(4, 4));
    await tester.pump();
    await g.moveTo(to + const Offset(0, 6));
    await save('layout_alijo_arrastrando');
    await g.cancel();
    await tester.pump();

    // Después: la fila entera arriba (Tab) y ELEGIR al lado del alijo.
    l
      ..select(StashLayout.actions)
      ..move(StashLayout.actions, 'header', 0)
      ..move(StashLayout.pick, 'right', 2)
      ..select(StashLayout.actions);
    await save('layout_alijo_1280_despues');

    // Angosto (800×600, texto 150 %): antes y después.
    l
      ..setSize(const Size(800, 600))
      ..setText(1.5);
    await save('layout_alijo_800_despues');
    while (l.canUndo) {
      l.undo();
    }
    l.select(StashLayout.actions);
    await save('layout_alijo_800_antes');
    expect(tester.takeException(), isNull);
  });
}
