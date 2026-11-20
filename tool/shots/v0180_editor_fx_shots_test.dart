// Capturas de v0.18.0 (docs/specs/game_editor.md § 7.3 y § 7.4): el
// editor de línea de tiempo con keys y animaciones pasadas a datos.
// NO es parte de la suite:
//   flutter test tool/shots/v0180_editor_fx_shots_test.dart
// Overrides en una carpeta temporal (nunca %APPDATA% ni el repo).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/fx/fx_catalog.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/fx_editor_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/fx_preview.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/sprite_editor_controller.dart';
import 'package:echos_del_tiempo/features/combat/data/local_sprite_overrides_io.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_bridge.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/admin/fake_admin_host.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.18.0';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  testWidgets('v0.18.0: editor de línea de tiempo y fx de datos', (tester) async {
    await loadRealFonts(tester);
    await loadMaterialFonts(tester);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('ecos_v0180_shots_');
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
          spriteImage: s.imageOf);
    });

    Future<void> save(GlobalKey key, String name) async {
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

    // 1. Animaciones pasadas a datos en este paso (mini escena).
    for (final (id, ms, n) in const [
      ('ult_berserker', 1240.0, 1),
      ('ult_cronomante', 1450.0, 3),
      ('convergence', 140.0, 1),
      ('skill_pulse', 260.0, 1),
    ]) {
      final t = fx.catalog.timeline(id)!;
      final key = GlobalKey();
      final cls = previewClassOf(t);
      await tester.pumpWidget(Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 960,
            height: 540,
            child: CustomPaint(
              painter: FxPreviewPainter(
                timeline: t,
                time: ms,
                sim: FxPreviewSim(),
                enemies: n,
                hero: s.imageOf('characters.$cls.idle'),
                partner: s.imageOf('characters.maga.idle'),
                enemyImages: [
                  for (final e in const ['slime', 'bat', 'golem'])
                    s.imageOf('enemies.$e.idle'),
                ],
              ),
            ),
          ),
        ),
      ));
      await save(key, 'fx_${id}_${ms.round()}ms');
    }

    // 2. Editor: Tajo Final con una capa de ecos nueva, la tarjeta y las
    // barras de cine como pistas, un key de dim elegido con su curva.
    fx
      ..setCategory('ult')
      ..select('ult_espada')
      ..addEchoLayer()
      ..addTrack('letterbox')
      ..addTrack('title_card')
      ..seek(1130);
    final dim = fx.edit!.tracks.indexWhere((t) => t.type == 'dim');
    fx.selectKey((track: dim, fire: false, index: 1));
    fx.setKeyEase(fx.selectedKey!, FxEase.back);
    final key = GlobalKey();
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
    await save(key, 'editor_linea_de_tiempo');

    // 3. Momentos de batalla en la lista (categoría PROCS: quiebre).
    fx
      ..setCategory('proc')
      ..select('break')
      ..seek(120);
    await tester.pump();
    await save(key, 'editor_momento_quiebre');
  });
}
