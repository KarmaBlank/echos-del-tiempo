import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/lobby/domain/patch_notes.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/patch_notes_panel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';

/// Notas del parche (docs/specs/title_screen.md § 4).
void main() {
  test('versiones: más nueva arriba, por número; sin numerar se ignora', () {
    final l = patchNotesFrom([
      'docs/release_notes/v0.9.0.md',
      'docs/release_notes/v0.36.0.md',
      'docs/release_notes/v0.10.1.md',
      'docs/release_notes/travesia-v0.3.0.md',
      'docs/release_notes/title-screen.md',
      'assets/otro/v9.9.9.md',
    ]);
    expect(l.map((e) => e.version), ['0.36.0', '0.10.1', '0.9.0']);
    final t = patchNotesFrom(['docs/release_notes/travesia-v0.3.0.md',
        'docs/release_notes/v0.36.0.md'], prefix: 'travesia-');
    expect(t.map((e) => e.version), ['0.3.0']);
  });

  test('markdown: encabezados, viñetas con continuación, sin negrita', () {
    final b = parsePatchNotes('﻿# v1.0.0\n\n## Título\n'
        '- **Uno:** primera\n  sigue\n  - anidada `x`\n\nPárrafo [link](u).\n');
    expect(b.map((e) => e.toString()), [
      'heading(1): v1.0.0',
      'heading(2): Título',
      'bullet(0): Uno: primera sigue',
      'bullet(1): anidada x',
      'paragraph(0): Párrafo link.',
    ]);
  });

  testWidgets('panel: lista de versiones, notas y scroll con teclado',
      (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showPatchNotes(context),
                child: const Text('x')),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('open')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('patch-notes')), findsOneWidget);
    expect(find.byKey(const ValueKey('patch-notes-versions')), findsOneWidget);
    // La más nueva arriba y abierta.
    final manifest = await tester
        .runAsync(() => AssetManifest.loadFromAssetBundle(rootBundle));
    final newest = patchNotesFrom(manifest!.listAssets()).first;
    expect(find.byKey(ValueKey('patch-notes-v${newest.version}')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('patch-notes-text-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Fin baja al final; Inicio vuelve.
    final scroll = tester
        .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('patch-notes-body')))
        .controller!;
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(scroll.offset, scroll.position.maxScrollExtent);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(scroll.offset, 0);
    // Otra versión.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('patch-notes-text-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('patch-notes-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('patch-notes')), findsNothing);
  });

  test('hasUnseenPatchNotes: la más nueva contra la última vista', () {
    const e = [PatchNoteEntry('0.37.1', ''), PatchNoteEntry('0.9.0', '')];
    expect(hasUnseenPatchNotes(e, ''), isTrue);
    expect(hasUnseenPatchNotes(e, '0.37.0'), isTrue);
    expect(hasUnseenPatchNotes(e, '0.37.1'), isFalse);
    expect(hasUnseenPatchNotes(e, '0.40.0'), isFalse);
    expect(hasUnseenPatchNotes(const [], ''), isFalse);
  });

  test('seenPatchNotes se guarda en los ajustes', () {
    const s = GameSettings(seenPatchNotes: '0.37.1');
    expect(GameSettings.fromJson(s.toJson()).seenPatchNotes, '0.37.1');
    expect(GameSettings.fromJson(const {}).seenPatchNotes, '');
  });
}
