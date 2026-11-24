import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/renown_editor_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/renown_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import 'fake_admin_host.dart';

/// docs/specs/renown_town_growth.md § 8.
void main() {
  Future<(AdminController, FakeAdminHost)> admin(WidgetTester? t) async {
    final host = FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    });
    final c = AdminController(host: host);
    if (t == null) {
      await c.load();
    } else {
      await t.runAsync(c.load);
    }
    return (c, host);
  }

  tearDown(() => kRenown = kRenownDefaults);

  test('validación bloquea guardar; guardar escribe y aplica', () async {
    final (b, host) = await admin(null);
    final c = RenownEditorController(balance: b);
    expect(c.problems, isEmpty);
    c.addLine();
    expect(c.problems.any((p) => p.startsWith('Falta idioma')), isTrue);
    expect(await c.save(), isFalse);
    c.edit(() {
      for (final t in c.locales) {
        (c.selectedLine!['text'] as Map)[t] = 'Hola {townName}';
      }
    });
    c.edit(() => (c.doc['sources'] as Map)[RenownSource.rift] = 99);
    expect(c.problems, isEmpty);
    expect(await c.save(), isTrue);
    expect(kRenown.weight(RenownSource.rift), 99);
    final saved = host.files.entries
        .firstWhere((e) => e.key.endsWith('renown.json'))
        .value;
    final cfg = RenownConfig.fromJson(jsonDecode(saved));
    expect(cfg.lines.length, kRenownDefaults.lines.length + 1);
    expect(c.dirty, isFalse);
  });

  testWidgets('el área RENOMBRE: subpestañas, grilla y detalle',
      (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1700, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (b, _) = await admin(tester);
    final c = RenownEditorController(balance: b);
    await tester.pumpWidget(
        AdminApp(controller: b, renown: c, initialArea: EditorArea.renown));
    await tester.pump();
    expect(find.byKey(const ValueKey('renown-source-zone')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('renown-tab-tiers')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('renown-tier-1')));
    await tester.pump();
    for (final l in c.locales) {
      expect(find.byKey(ValueKey('renown-tier-name-$l')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('renown-tab-lines')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('renown-line-visitor_heard')));
    await tester.pump();
    expect(find.byKey(const ValueKey('renown-line-text-en')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('renown-tab-events')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('renown-event-tourney_kael')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('renown-event-tab-rounds')));
    await tester.pump();
    expect(find.byKey(const ValueKey('renown-event-round-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
