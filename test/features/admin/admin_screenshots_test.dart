// Capturas del admin con datos reales (repo, GitHub, Firestore, ecos.log),
// sin escribir nada. Solo corre con la variable ADMIN_SHOTS=<carpeta>:
//   $env:ADMIN_SHOTS = "C:\ruta"; flutter test test/features/admin/admin_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/admin/data/admin_host_io.dart';
import 'package:echos_del_tiempo/features/admin/domain/admin_host.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/firebase_options.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_registries.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final _out = Platform.environment['ADMIN_SHOTS'];

/// No escribe nunca (las capturas no guardan nada).
class _ReadOnlyHost extends IoAdminHost {
  @override
  Future<void> writeFile(String path, String content) async =>
      throw StateError('solo lectura');

  /// Solo `git show` (lectura); nunca release.ps1.
  @override
  Future<int> run(String exe, List<String> args,
      {required String workingDirectory,
      required void Function(String line) onLine}) {
    if (exe != 'git' || args.first != 'show') throw StateError('no');
    return super.run(exe, args, workingDirectory: workingDirectory, onLine: onLine);
  }
}

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  testWidgets('capturas del admin', (tester) async {
    HttpOverrides.global = null; // red real (GitHub, Firestore)
    const fonts = r'C:\tools\flutter\bin\cache\artifacts\material_fonts';
    await tester.runAsync(() async {
      // Segoe UI (la fuente real del admin en Windows) con el nombre que
      // usa Material en los tests.
      await _font('Roboto', [
        r'C:\Windows\Fonts\segoeui.ttf',
        r'C:\Windows\Fonts\segoeuisb.ttf',
        r'C:\Windows\Fonts\segoeuib.ttf',
      ].where((f) => File(f).existsSync()).toList());
      await _font('MaterialIcons', ['$fonts\\materialicons-regular.otf']);
      await _font('Consolas', [r'C:\Windows\Fonts\consola.ttf']);
    });
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(BalanceRegistries.restore);

    const fb = DefaultFirebaseOptions.windows;
    final AdminHost host = _ReadOnlyHost();
    final c = AdminController(
        host: host, firestoreProjectId: fb.projectId, firestoreApiKey: fb.apiKey);
    await tester.runAsync(() async {
      await c.load();
      await c.refreshReleases();
    });
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: AdminApp(controller: c)));
    await tester.pump();

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$_out\\$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    // 1. Navegador: enemigos, Gólem elegido.
    c.setCategory(BalanceKind.enemy.jsonKey);
    c.selectRef(BalanceKind.enemy, 'golem');
    c.setField(BalanceKind.enemy, 'golem', 'hp', 80);
    await tester.pump();
    await tester.tap(find.text('Simular'));
    await shot('admin_browser');

    // 2. Editor + impacto: Golpe Sísmico con más poder, MP y quemadura.
    c.setCategory(BalanceKind.skill.jsonKey);
    c.selectRef(BalanceKind.skill, 'sismo');
    c
      ..setField(BalanceKind.skill, 'sismo', 'power', 1.4)
      ..setField(BalanceKind.skill, 'sismo', 'mp', 5)
      ..setField(BalanceKind.skill, 'sismo', 'status', {'kind': 'burn', 'stacks': 1, 'chance': 0.3})
      ..setField(BalanceKind.skill, 'giro', 'disabled', true)
      ..setField(BalanceKind.affix, 'feroz', 'weight', 900)
      ..setPreview(level: 8, enemy: 'golem', count: 2);
    await tester.pump();
    await tester.tap(find.text('Simular'));
    await shot('admin_editor_impact');

    // 3. Diff.
    await tester.tap(find.text('Cambios'));
    await tester.pumpAndSettle();
    await shot('admin_diff');

    // 4. Parche con notas.
    c.regenerateNotes();
    await tester.tap(find.text('Parche'));
    await tester.pumpAndSettle();
    await shot('admin_patch_notes');
    await tester.drag(find.text('Generar parche'), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Correr release.ps1…'));
    await tester.pumpAndSettle();
    await shot('admin_release_confirm');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // 5. Monitoreo con datos reales.
    await tester.runAsync(() async {
      await c.countRooms();
      await c.loadLog();
    });
    await tester.tap(find.text('Monitoreo'));
    await tester.pumpAndSettle();
    await shot('admin_monitoring');
  }, skip: _out == null);
}
