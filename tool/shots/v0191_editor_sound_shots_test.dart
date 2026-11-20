// Capturas de v0.19.1 (docs/specs/game_editor.md § 7.6): tooltips del
// Editor y un disparo de sonido elegido en la línea de tiempo.
// NO es parte de la suite:
//   flutter test tool/shots/v0191_editor_sound_shots_test.dart
// Overrides en una carpeta temporal (nunca %APPDATA% ni el repo).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/fx_editor_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/sprite_editor_controller.dart';
import 'package:echos_del_tiempo/features/combat/data/local_sprite_overrides_io.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_bridge.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/admin/fake_admin_host.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.19.1/editor';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  testWidgets('v0.19.1: tooltips y sonido en Animaciones', (tester) async {
    await loadRealFonts(tester);
    await loadMaterialFonts(tester);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('ecos_v0191_shots_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final o = LocalSpriteOverrides('${tmp.path}/overrides');
    final cat = SpriteCatalog.fromYaml(
        File(SpriteCatalog.manifestPath).readAsStringSync(),
        bundle: _DiskBundle(),
        overrides: o);
    final s = SpriteEditorController(catalog: cat, overrides: o, repoPath: tmp.path);
    late FxEditorController fx;
    final c = AdminController(
        host: FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    }));
    await tester.runAsync(() async {
      await c.load();
      await s.loadAll();
      fx = FxEditorController(
          catalog: await installFx(bundle: _DiskBundle(), overrides: o),
          overrides: o,
          repoPath: tmp.path,
          spriteImage: s.imageOf,
          sfx: SfxService());
    });

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

    fx
      ..setCategory('ult')
      ..select('ult_espada')
      ..seek(900);
    final snd = fx.edit!.tracks.indexWhere((t) => t.type == 'sound');
    fx.selectKey((track: snd, fire: true, index: 1));
    fx.setSoundLevel(fx.selectedKey!, 'vol', 0.8);
    fx.setSoundLevel(fx.selectedKey!, 'pitch', 1.1);
    fx.setSoundQuery('ult_espada');
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: AdminApp(
            controller: c,
            sprites: s,
            animations: fx,
            animateFx: false,
            initialArea: EditorArea.visuals,
            initialVisualTab: 1)));
    await tester.pump();
    await save('editor_key_de_sonido');

    // Tooltip del IMÁN con el mouse encima.
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: tester.getCenter(find.byKey(const ValueKey('fx-snap'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await save('editor_tooltip_iman');
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('fx-sound-replace'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await save('editor_tooltip_reemplazar_sonido');
    await g.removePointer();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });
}
