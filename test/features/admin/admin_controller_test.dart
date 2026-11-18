import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/features/admin/domain/admin_host.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_patch.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_registries.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_admin_host.dart';

FakeAdminHost _host() => FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    });

void main() {
  tearDown(BalanceRegistries.restore);

  test('cargar, editar, guardar: escribe solo el balance.json del repo', () async {
    final host = _host();
    final c = AdminController(host: host);
    await c.load();
    expect(c.currentVersion, isNotNull);
    expect(c.saved.isEmpty, isTrue);
    expect(c.nextVersion, isNot(c.currentVersion));

    c.setField(BalanceKind.skill, 'sismo', 'power', 1.4);
    expect(c.pendingChanges.single.afterText, '1.4');
    expect(c.canSave, isTrue);
    expect(await c.save(), isTrue);
    expect(host.writes, ['repo/assets/balance/balance.json']);
    final written = jsonDecode(host.files['repo/assets/balance/balance.json']!) as Map;
    expect(written['overrides'], {
      'skill': {
        'sismo': {'power': 1.4}
      }
    });
    expect(written['basedOn'], c.currentVersion);
    expect(c.pendingChanges, isEmpty);

    // Volver al valor del código quita la entrada.
    c.setField(BalanceKind.skill, 'sismo', 'power', 1.2);
    expect(c.draft.isEmpty, isTrue);
    expect(c.pendingChanges.single.beforeText, '1.4');
  });

  test('con errores no se puede guardar ni escribir el parche', () async {
    final host = _host();
    final c = AdminController(host: host);
    await c.load();
    c.setField(BalanceKind.enemy, 'slime', 'hp', -5);
    expect(c.issuesOf(BalanceKind.enemy, 'slime').single.message, contains('rango'));
    expect(c.canSave, isFalse);
    expect(await c.save(), isFalse);
    expect(await c.writePatchFiles(), isFalse);
    expect(host.writes, isEmpty);
  });

  test('parche: notas contra main, archivos y release con confirmación', () async {
    final host = _host()
      ..releasedBalance = jsonEncode({
        'schema': 1,
        'overrides': {
          'enemy': {
            'slime': {'hp': 35}
          }
        }
      });
    final c = AdminController(host: host);
    await c.load();
    expect(c.releasedSource, startsWith('main'));
    c
      ..setField(BalanceKind.enemy, 'slime', 'hp', 40)
      ..regenerateNotes();
    expect(c.notes, contains('**Limo**: vida 35 → 40.'),
        reason: 'compara contra lo publicado, no contra el código');
    expect(await c.writePatchFiles(), isTrue);
    expect(host.writes, [
      'repo/assets/balance/balance.json',
      'repo/${c.plan.notesPath}',
    ]);
    expect(host.files['repo/${c.plan.notesPath}'], contains('vida 35 → 40'));

    // La confirmación tiene que nombrar la versión correcta.
    await c.runRelease(confirmedVersion: '9.9.9', dryRun: true);
    expect(host.runs.where((r) => r.first == 'powershell'), isEmpty);
    await c.runRelease(confirmedVersion: c.nextVersion, dryRun: true);
    final run = host.runs.firstWhere((r) => r.first == 'powershell');
    expect(run, containsAllInOrder(['-Version', c.nextVersion, '-DryRun']));
    expect(c.releaseExit, 0);
  });

  test('la versión siguiente salta lo ya publicado en GitHub', () async {
    final host = FakeAdminHost(
      files: {'repo/pubspec.yaml': 'name: echos_del_tiempo\nversion: 0.5.0+7\n'},
      responses: {
        'https://api.github.com/': HostResponse(
            200,
            jsonEncode([
              {'tag_name': 'v0.5.1', 'assets': []},
              {'tag_name': 'v0.6.0-beta.1', 'prerelease': true, 'assets': []},
              {'tag_name': 'v0.5.0', 'assets': []},
            ])),
      },
    );
    final c = AdminController(host: host);
    await c.load();
    expect(c.nextVersion, '0.5.1');
    await c.refreshReleases();
    expect(c.latestReleased, '0.5.1');
    expect(c.nextVersion, '0.5.2');
    expect(c.notes, contains('v0.5.2'));
  });

  test('el log del juego se lee y nunca se escribe', () async {
    final host = _host()
      ..files['appdata/EcosDelTiempo/ecos.log'] =
          '2026-11-18T10:00:00.000 INFO Inicio\n2026-11-18T10:00:01.000 ERROR algo\n';
    final c = AdminController(host: host);
    await c.loadLog();
    expect(c.logLines.length, 2);
    c.setLogFilter(errorsOnly: true);
    expect(c.visibleLog.single.message, 'algo');
    expect(() => host.writeFile('appdata/EcosDelTiempo/x', ''), throwsStateError);
  });

  testWidgets('UI: elegir una habilidad, subir el poder y ver el cambio', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = AdminController(host: _host());
    await tester.runAsync(c.load);
    await tester.pumpWidget(AdminApp(controller: c));
    await tester.enterText(find.byType(TextField).first, 'sismico');
    await tester.pump();
    await tester.tap(find.text('Golpe Sísmico').first);
    await tester.pump();
    expect(find.text('Impacto'), findsOneWidget);
    expect(find.textContaining('Daño de un uso'), findsOneWidget);
    // El primer "+" del campo Poder (después de MP).
    await tester.tap(find.byTooltip('Subir').at(1));
    await tester.pump();
    expect(c.draft.fieldsOf(BalanceKind.skill, 'sismo')['power'], closeTo(1.25, 1e-9));
    await tester.tap(find.text('Cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Cambios pendientes (1)'), findsOneWidget);
    expect(find.text('1.2  →  1.25'), findsOneWidget);
    expect(BalancePatch.empty.isEmpty, isTrue);
  });
}
