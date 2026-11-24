import 'dart:io';

import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/npc_editor_controller.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/data/npc_talk_catalog.dart';
import 'package:echos_del_tiempo/game_engine/serialization/npc_data_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import 'fake_admin_host.dart';

/// docs/specs/npc_editor.md.
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

  tearDown(NpcData.restore);

  test('lista de habitantes, umbrales y generadores', () async {
    final (b, _) = await admin(null);
    final c = NpcEditorController(balance: b);
    expect(c.entries.length, 10);
    expect(c.entries.where((e) => e.rooted).length, 5);
    final brann = c.entries.firstWhere((e) => e.id == 'brann');
    expect(
        c.generators(brann).map((g) => g.title), contains('ENCARGO DE FORJA'));
    final native = c.entries.firstWhere((e) => e.id == 'pesc_bosque');
    expect(c.generators(native).single.kind, BalanceKind.fishing);
    expect(c.thresholds(native), isNotEmpty);
    expect(c.dirty, isFalse);
  });

  test('editar, guardar y aplicar; ejemplos con el borrador', () async {
    final (b, host) = await admin(null);
    final c = NpcEditorController(balance: b);
    c.edit(() => (NpcEditorController.listOf(c.npc('ilda'), 'greet'))[0] = {
          for (final l in c.locales) l: 'Hola.'
        });
    expect(c.dirty, isTrue);
    // The migrated file lacks languages: saving is blocked until filled.
    expect(c.missing, isNotEmpty);
    expect(await c.save(), isFalse);
    expect(c.message, contains('faltan idiomas'));
    for (final id in [...(c.draft.$1!.talks.keys)]) {
      c.edit(() => fillAll(c.npc(id), c.locales));
    }
    expect(c.missing, isEmpty);
    expect(await c.save(), isTrue);
    expect(host.files['repo/${NpcData.assetPath}'], contains('Hola.'));
    expect(npcTalk('ilda')!.greet.first.text, 'Hola.');
    expect(c.dirty, isFalse);

    c.select('ilda');
    c.setSampleLevel(30);
    c.generateSamples();
    expect(c.samples.length, 7);
    c.select('brann');
    c.generateSamples();
    expect(c.samples.last.text, contains('Encargo de forja'));
    c.select('pesc_abismo');
    c.generateSamples();
    expect(c.samples, isNotEmpty);

    // Generador: queda en el borrador del Balance.
    c.setValue(BalanceKind.town, 'orderEveryDays', 3);
    expect(c.value(BalanceKind.town, 'orderEveryDays'), 3);
    expect(b.pendingChanges, isNotEmpty);
  });

  test('un borrador roto no se guarda', () async {
    final (b, _) = await admin(null);
    final c = NpcEditorController(balance: b);
    c.edit(() => (c.npc('ilda')['topics'] as List).add({'nada': 1}));
    expect(c.draft.$2, isNotNull);
    expect(await c.save(), isFalse);
  });

  testWidgets('el área NPC: grilla, diálogo, pedidos y probar', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1700, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (b, _) = await admin(tester);
    final c = NpcEditorController(balance: b);
    await tester.pumpWidget(
        AdminApp(controller: b, npcs: c, initialArea: EditorArea.npcs));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('npc-cell-ilda')));
    await tester.pump();
    expect(find.text('UMBRALES DE AMISTAD'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('npc-tab-dialogo')));
    await tester.pumpAndSettle();
    for (final l in c.locales) {
      expect(find.byKey(ValueKey('npc-greet-0-$l')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('npc-missing')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('npc-greet-add')));
    await tester.pump();
    expect(c.dirty, isTrue);
    await tester.tap(find.byKey(const ValueKey('npc-preview')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('npc-preview-talk')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('¿Qué hacés?'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('npc-preview-locale-en')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('npc-preview-time')));
    await tester.pump();
    expect(find.text('DE NOCHE'), findsOneWidget);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('npc-preview-bye')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('npc-tab-pedidos')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('npc-samples')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('npc-samples')));
    await tester.pump();
    expect(c.samples.length, 7);
    expect(find.textContaining('Día 1', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Fills every empty language of every text in [m] (a draft NPC) with
/// the es-AR text.
void fillAll(Object? m, List<String> locales) {
  if (m is Map) {
    if (m.containsKey('es-AR')) {
      for (final l in locales) {
        if ('${m[l] ?? ''}'.trim().isEmpty) m[l] = '${m['es-AR']}';
      }
      return;
    }
    for (final v in m.values) {
      fillAll(v, locales);
    }
  } else if (m is List) {
    for (final v in m) {
      fillAll(v, locales);
    }
  }
}
