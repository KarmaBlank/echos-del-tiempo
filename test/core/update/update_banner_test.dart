import 'dart:async';
import 'dart:io';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/update/presentation/update_banner.dart';
import 'package:echos_del_tiempo/core/update/release_info.dart';
import 'package:echos_del_tiempo/core/update/semver.dart';
import 'package:echos_del_tiempo/core/update/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final _release = ReleaseInfo(
  tag: 'v0.2.0',
  version: const SemVer(0, 2, 0),
  notes: '- Jefe nuevo <grande>',
  installer: ReleaseAsset(
      name: 'EcosDelTiempo-Setup-0.2.0.exe',
      url: Uri.parse('https://example.com/a.exe'),
      size: 100),
);

class FakeUpdateService implements UpdateService {
  FakeUpdateService(this.result, {this.canInstall = true});

  UpdateCheck result;
  int checks = 0;
  Completer<File>? downloadGate;
  DownloadProgress? lastProgress;
  UpdateFailure? downloadError;
  File? installed;

  @override
  final bool canInstall;

  @override
  SemVer get currentVersion => const SemVer(0, 1, 0);

  @override
  Future<UpdateCheck> check() async {
    checks++;
    return result;
  }

  @override
  Future<File> download(ReleaseInfo release, {DownloadProgress? onProgress}) {
    if (downloadError != null) return Future.error(downloadError!);
    lastProgress = onProgress;
    downloadGate = Completer<File>();
    return downloadGate!.future;
  }

  @override
  Future<void> installAndExit(File installer) async => installed = installer;
}

void main() {
  Future<void> pump(WidgetTester tester, FakeUpdateService s,
      {bool autoCheck = true}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
          body: Center(child: UpdateBanner(service: s, autoCheck: autoCheck))),
    ));
    await tester.pump();
  }

  testWidgets('al día: versión y BUSCAR vuelve a consultar', (tester) async {
    final s = FakeUpdateService(const UpToDate(current: SemVer(0, 1, 0),
        latest: SemVer(0, 1, 0)));
    await pump(tester, s);
    expect(find.textContaining('v0.1.0 · al día'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('update-check')));
    await tester.pump();
    expect(s.checks, 2);
  });

  testWidgets('sin búsqueda automática no consulta', (tester) async {
    final s = FakeUpdateService(const UpToDate(current: SemVer(0, 1, 0)));
    await pump(tester, s, autoCheck: false);
    expect(s.checks, 0);
    expect(find.text('v0.1.0'), findsOneWidget);
  });

  testWidgets('sin red: motivo y REINTENTAR', (tester) async {
    final s = FakeUpdateService(
        const UpdateCheckFailed('No se pudo buscar actualizaciones: sin conexión a internet.'));
    await pump(tester, s);
    expect(find.textContaining('sin conexión'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('disponible → descarga con progreso → instala', (tester) async {
    final s = FakeUpdateService(
        UpdateAvailable(current: const SemVer(0, 1, 0), release: _release));
    await pump(tester, s);
    expect(find.byKey(const ValueKey('update-available')), findsOneWidget);
    expect(find.textContaining('Actualización disponible v0.2.0'), findsOneWidget);
    expect(find.textContaining('Jefe nuevo <grande>'), findsOneWidget);

    await tester.tap(find.text('ACTUALIZAR'));
    await tester.pump();
    s.lastProgress!(50, 100);
    await tester.pump();
    expect(find.text('Descargando… 50%'), findsOneWidget);

    final file = File('x.exe');
    s.downloadGate!.complete(file);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('update-installing')), findsOneWidget);
    expect(s.installed, file);
  });

  testWidgets('descarga rechazada: error y REINTENTAR', (tester) async {
    final s = FakeUpdateService(
        UpdateAvailable(current: const SemVer(0, 1, 0), release: _release))
      ..downloadError = const UpdateFailure('no coincide con su SHA-256');
    await pump(tester, s);
    await tester.tap(find.text('ACTUALIZAR'));
    await tester.pump();
    expect(find.textContaining('SHA-256'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('fuera de Windows el botón queda deshabilitado con motivo',
      (tester) async {
    final s = FakeUpdateService(
        UpdateAvailable(current: const SemVer(0, 1, 0), release: _release),
        canInstall: false);
    await pump(tester, s);
    expect(find.textContaining('Solo en Windows'), findsOneWidget);
    await tester.tap(find.text('ACTUALIZAR'));
    await tester.pump();
    expect(s.downloadGate, isNull);
  });

  Future<void> pumpCompact(WidgetTester tester, FakeUpdateService s) async {
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
          body: Center(
              child: UpdateBanner(service: s, autoCheck: true, compact: true))),
    ));
    await tester.pump();
  }

  testWidgets('compacto (título): al día muestra versión y BUSCAR', (tester) async {
    await pumpCompact(
        tester,
        FakeUpdateService(const UpToDate(
            current: SemVer(0, 1, 0), latest: SemVer(0, 1, 0))));
    expect(find.textContaining('v0.1.0'), findsOneWidget);
    expect(find.byKey(const ValueKey('update-check')), findsOneWidget);
    expect(find.byKey(const ValueKey('update-available')), findsNothing);
    expect(find.byKey(const ValueKey('update-apply')), findsNothing);
  });

  testWidgets('compacto (título): versión nueva = solo ACTUALIZAR',
      (tester) async {
    final s = FakeUpdateService(
        UpdateAvailable(current: const SemVer(0, 1, 0), release: _release));
    await pumpCompact(tester, s);
    expect(find.text('ACTUALIZAR'), findsOneWidget);
    expect(find.textContaining('Actualización disponible'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('update-apply')));
    await tester.pump();
    expect(s.downloadGate, isNotNull);
  });
}
