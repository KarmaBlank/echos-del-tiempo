// Capturas de v0.19.0 (docs/specs/game_editor.md § 7.5): perillas del
// arte procedural de un arma con la vista previa modificada.
// NO es parte de la suite:
//   flutter test tool/shots/v0190_editor_procedural_shots_test.dart
// Overrides en una carpeta temporal (nunca %APPDATA% ni el repo).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/procedural/procedural_art.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/sprite_editor_controller.dart';
import 'package:echos_del_tiempo/features/combat/data/local_sprite_overrides_io.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/admin/fake_admin_host.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.19.0/editor';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  testWidgets('v0.19.0: perillas del arte procedural', (tester) async {
    await loadRealFonts(tester);
    await loadMaterialFonts(tester);
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(ProceduralArt.instance.reset);
    final tmp = Directory.systemTemp.createTempSync('ecos_v0190_shots_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final o = LocalSpriteOverrides('${tmp.path}/overrides');
    final cat = SpriteCatalog.fromYaml(
        File(SpriteCatalog.manifestPath).readAsStringSync(),
        bundle: _DiskBundle(),
        overrides: o);
    final s = SpriteEditorController(catalog: cat, overrides: o, repoPath: tmp.path);
    final c = AdminController(
        host: FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    }));
    final espada = s.entries.firstWhere((e) => e.id == 'items.espada.idle');
    await tester.runAsync(() async {
      await c.load();
      await s.loadAll();
      await s.select(espada);
    });
    s
      ..setCategory(SpriteCategory.items)
      ..setZoom(8);

    final key = GlobalKey();
    Future<void> save(String name) async {
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
            controller: c,
            sprites: s,
            animateFx: false,
            initialArea: EditorArea.visuals)));
    await tester.pump();
    await save('perillas_espada_por_defecto');

    // Perillas modificadas (sin guardar): vista previa en tiempo real.
    s
      ..setKnob('metal', '#ffd166')
      ..setKnob('handle', '#636e72')
      ..setKnob('accent', '#d63031')
      ..setKnob('gem', true)
      ..setKnob('outline', true)
      ..setKnob('highlight', true)
      ..setKnob('shine', 0.1);
    await save('perillas_espada_modificada');

    // Familia: toda la sección de armas e ítems con contorno.
    await tester.runAsync(s.saveProc);
    s
      ..setProcFamily(true)
      ..setKnob('outline', true)
      ..setKnob('outline_color', '#2d3436');
    await save('perillas_familia');
  });
}
