// Capturas del Editor, paso 1 (docs/specs/game_editor.md § 7): Visuales →
// Sprites con un reemplazo en vista previa. NO es parte de la suite:
//   flutter test tool/shots/editor_shots_test.dart
// Overrides en una carpeta temporal (nunca %APPDATA% ni el repo).
import 'dart:io';
import 'dart:ui' as ui;

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

const _out = 'docs/release_shots/editor';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _Files implements EditorFiles {
  Uint8List? png;
  @override
  Future<Uint8List?> pickPng() async => png;
  @override
  Future<Uint8List?> pickZip() async => null;
  @override
  Future<bool> saveZip(Uint8List bytes, String suggestedName) async => false;
}

void main() {
  testWidgets('editor: capturas', (tester) async {
    await loadRealFonts(tester);
    await loadMaterialFonts(tester);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('ecos_editor_shots_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final o = LocalSpriteOverrides('${tmp.path}/overrides');
    final cat = SpriteCatalog.fromYaml(
        File(SpriteCatalog.manifestPath).readAsStringSync(),
        bundle: _DiskBundle(),
        overrides: o);
    final files = _Files();
    final s = SpriteEditorController(
        catalog: cat, overrides: o, files: files, repoPath: tmp.path);
    final c = AdminController(
        host: FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    }));
    await tester.runAsync(() async {
      await c.load();
      await s.loadAll();
    });
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: AdminApp(
            controller: c, sprites: s, initialArea: EditorArea.visuals)));

    Future<void> shot(String name) async {
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

    // 1. Personajes: la Maga reemplazada por otro PNG (override en preview).
    s.setCategory(SpriteCategory.characters);
    final maga = cat.entry('characters.maga.idle')!;
    await tester.runAsync(() => s.select(maga));
    files.png = File('assets/sprites/characters/maga/elementalista.png')
        .readAsBytesSync();
    await tester.runAsync(s.pickAndReplace);
    await shot('01_sprites_override_maga');

    // 2. Validación: tamaño incorrecto rechazado.
    final golem = cat.entry('enemies.golem.idle')!;
    s.setCategory(SpriteCategory.bosses);
    await tester.runAsync(() => s.select(golem));
    files.png = File('assets/sprites/characters/guerrero/idle.png')
        .readAsBytesSync();
    await tester.runAsync(s.pickAndReplace);
    await shot('02_validacion_rechaza');

    // 3. Tiles: procedural, contexto de mapa, con búsqueda.
    s
      ..clearNotice()
      ..setCategory(SpriteCategory.tiles);
    await tester.runAsync(() => s.select(cat.entry('tiles.hierba.idle')!));
    await shot('03_tiles_mapa');

    // 4. Balance dentro del Editor.
    await tester.tap(find.text('BALANCE'));
    await tester.pumpAndSettle();
    await shot('04_balance');
  });
}
