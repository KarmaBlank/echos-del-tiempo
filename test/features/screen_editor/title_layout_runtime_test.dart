import 'dart:async';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/persistence/exit_guard.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_layout.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_layout_catalog.dart';
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

/// El juego dibuja el TÍTULO desde `assets/layouts/title.screen.json`
/// (docs/specs/screen_editor.md § 3), con fallback a la pantalla de código.
Future<List<String>> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = <String>[];
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
      appExitProvider.overrideWithValue(() async => calls.add('exit')),
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

void main() {
  tearDown(() => ScreenLayoutCatalog.instance.put('title', null));

  test('el catálogo lee el título del bundle; sin archivo da null', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = ScreenLayoutCatalog(bundle: rootBundle);
    await c.load();
    final l = c.get('title');
    expect(l, isNotNull);
    expect(l!.byId('title-settings')?.action, 'configuracion');
    expect(c.parse('no es json'), isNull);
    expect(c.log, isNotEmpty);
  });

  testWidgets('con layout: el título sale del archivo y las acciones andan',
      (tester) async {
    final text = await tester.runAsync(
        () => rootBundle.loadString(ScreenLayoutCatalog.pathOf('title')));
    ScreenLayoutCatalog.instance.put('title', ScreenLayout.parse(text!));
    ExitGuard.register(#titleLayoutTest, () async {});
    addTearDown(() => ExitGuard.unregister(#titleLayoutTest));
    final calls = await _pump(tester);
    expect(find.byKey(const ValueKey('title-screen-layout')), findsOneWidget);
    expect(find.text('ECOS DEL TIEMPO'), findsOneWidget);
    // Hueco "personajes": el selector real de la pantalla.
    expect(find.byKey(const ValueKey('title-start')), findsOneWidget);
    // Botón con acción por nombre: salirDelJuego.
    await tester.tap(find.byKey(const ValueKey('title-quit')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('quit-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quit-yes')));
    await tester.pump();
    await tester.pump();
    expect(calls, ['exit']);
  });

  testWidgets('sin layout: la pantalla de código (fallback)', (tester) async {
    ScreenLayoutCatalog.instance.put('title', null);
    await _pump(tester);
    expect(find.byKey(const ValueKey('title-screen-layout')), findsNothing);
    expect(find.byKey(const ValueKey('title-quit')), findsOneWidget);
    expect(find.text('ECOS DEL TIEMPO'), findsOneWidget);
  });
}
