import 'dart:async';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/persistence/exit_guard.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

/// SALIR DEL JUEGO en el título (v0.8.2, settings.md § 7).
Future<List<String>> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = <String>[];
  // La salida real: guarda con ExitGuard y cierra (acá, anotado).
  ExitGuard.register(#titleQuitTest, () async => calls.add('flush'));
  addTearDown(() => ExitGuard.unregister(#titleQuitTest));
  final a = CharacterRules(progression)
      .create(Account(), 'Ana', 'maga', now: DateTime(2026, 11, 1))!;
  final repo = AccountRepository(InMemoryAccountStore(a));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider
          .overrideWithValue(SelectedCharacterProfileStore(repo)),
      accountRepositoryProvider.overrideWithValue(repo),
      gameSpritesProvider
          .overrideWith((ref) => Completer<GameSprites>().future),
      appExitProvider.overrideWithValue(() async {
        await ExitGuard.flushAll();
        calls.add('exit');
      }),
    ],
    child: MaterialApp(
      theme: RetroTheme.build(),
      home: TitleScreen(onStart: () {}),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return calls;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('SALIR DEL JUEGO: confirma y sale guardando', (tester) async {
    final calls = await _pump(tester);
    expect(find.byKey(const ValueKey('title-quit')), findsOneWidget);
    await _tap(tester, 'title-quit');
    expect(find.byKey(const ValueKey('quit-dialog')), findsOneWidget);
    expect(find.textContaining('¿Salir del juego?', findRichText: true),
        findsOneWidget);
    expect(calls, isEmpty, reason: 'nada sale sin confirmar');
    await _tap(tester, 'quit-yes');
    expect(calls, ['flush', 'exit'], reason: 'guarda antes de cerrar');
    expect(find.byKey(const ValueKey('quit-dialog')), findsNothing);
  });

  testWidgets('CANCELAR y Esc no salen', (tester) async {
    final calls = await _pump(tester);
    await _tap(tester, 'title-quit');
    await _tap(tester, 'quit-cancel');
    expect(find.byKey(const ValueKey('quit-dialog')), findsNothing);
    await _tap(tester, 'title-quit');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('quit-dialog')), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets('con teclado: el foco abre en CANCELAR; Tab + Enter sale',
      (tester) async {
    final calls = await _pump(tester);
    await _tap(tester, 'title-quit');
    await tester.pump();
    // Enter sobre CANCELAR (el foco inicial) cierra sin salir.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('quit-dialog')), findsNothing);
    expect(calls, isEmpty);
    await _tap(tester, 'title-quit');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(calls, ['flush', 'exit']);
  });
}
