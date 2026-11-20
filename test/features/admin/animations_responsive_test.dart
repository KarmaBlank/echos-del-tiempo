// Bug v0.18: con Visuales → Animaciones reproduciendo, la app dejaba de
// responder (docs/specs/game_editor.md § 7.5). Overrides en carpeta
// temporal (nunca %APPDATA% ni el repo).
import 'dart:io';

import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/fx_editor_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/sprite_editor_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/sprites_page.dart';
import 'package:echos_del_tiempo/features/combat/data/local_sprite_overrides_io.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_bridge.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_admin_host.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  testWidgets('con la animación corriendo, pestañas y botones responden',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('ecos_fx_bug_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final o = LocalSpriteOverrides('${tmp.path}/overrides');
    final cat = SpriteCatalog.fromYaml(
        File(SpriteCatalog.manifestPath).readAsStringSync(),
        bundle: _DiskBundle(),
        overrides: o);
    final s = SpriteEditorController(catalog: cat, overrides: o);
    final c = AdminController(
        host: FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    }));
    late FxEditorController fx;
    await tester.runAsync(() async {
      await c.load();
      fx = FxEditorController(
          catalog: await installFx(bundle: _DiskBundle(), overrides: o),
          overrides: o);
    });

    await tester.pumpWidget(AdminApp(
        controller: c,
        sprites: s,
        animations: fx,
        initialArea: EditorArea.visuals,
        initialVisualTab: 1));
    await tester.pump();

    // Elegir una animación NO la arranca (pausa por defecto).
    await tester.tap(find.byKey(ValueKey('fx-row-${fx.visible.first}')));
    await tester.pump();
    expect(fx.playing, isFalse);
    expect(find.text('REPRODUCIR'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fx-play')));
    await tester.pump();
    expect(fx.playing, isTrue);

    // Reproduciendo: el reloj avanza sin notificar al controlador (no
    // reconstruye la página por frame).
    var notifications = 0;
    void count() => notifications++;
    fx.addListener(count);
    final t0 = fx.time;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fx.time, greaterThan(t0));
    expect(notifications, 0);
    fx.removeListener(count);

    // Los botones de la página responden con la animación corriendo.
    await tester.tap(find.byKey(const ValueKey('fx-speed-0.5')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(fx.speed, 0.5);
    expect(fx.playing, isTrue);

    // Y cambiar de pestaña también.
    await tester.tap(find.text('SPRITES'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(SpritesPage), findsOneWidget);

    // Y de área (menú superior).
    await tester.tap(find.text('BALANCE'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(SpritesPage), findsNothing);

    // Sin tickers colgados al salir.
    await tester.pumpWidget(const SizedBox());
  });
}
