// TÍTULO por defecto (docs/specs/title_screen.md): VERIFICAR sin avisos y
// nada cortado ni desbordado de 1280×720 a 2560×1440, con texto grande.
// Goldens:
//   flutter test --update-goldens test/features/lobby/title_default_layout_test.dart
@Tags(['golden'])
library;

import 'dart:async';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/persistence/exit_guard.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_bindings.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_layout.dart';
import 'package:echos_del_tiempo/core/screen_layout/screen_layout_catalog.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/screen_editor/domain/screen_checks.dart';
import 'package:echos_del_tiempo/features/screen_editor/presentation/screen_editor_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

Account _account() {
  final rules = CharacterRules(progression);
  var a = Account();
  final names = ['Ana', 'Bartolomeo', 'Cata', 'Dulcinea'];
  for (var i = 0; i < names.length; i++) {
    final t = DateTime(2026, 11, 19 + i);
    a = rules.create(a, names[i], 'maga', now: t)!;
    a = a.touch(a.characters.last.id, t);
  }
  return a;
}

Future<void> _pump(WidgetTester tester,
    {required Size size, TextSize text = TextSize.normal}) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(RetroType.reset);
  final repo = AccountRepository(InMemoryAccountStore(_account()));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider
          .overrideWithValue(SelectedCharacterProfileStore(repo)),
      accountRepositoryProvider.overrideWithValue(repo),
      gameSpritesProvider
          .overrideWith((ref) => Completer<GameSprites>().future),
      appExitProvider.overrideWithValue(() async {}),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RetroTheme.build(),
      builder: (context, child) =>
          RetroTextScale(factor: text.factor, child: child!),
      home: TitleScreen(onStart: () {}),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

/// Nada desbordado (Flutter lo reporta como excepción), ningún texto
/// cortado por líneas ni con "…", y todo dentro de la ventana.
void _expectNothingClipped(WidgetTester tester, Size window) {
  expect(tester.takeException(), isNull);
  for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
    final text = p.text.toPlainText();
    expect(p.didExceedMaxLines, isFalse, reason: 'cortado: "$text"');
    expect(text.contains('…'), isFalse, reason: 'con "…": "$text"');
  }
  final screen = Offset.zero & window;
  for (final e in ScreenLayoutCatalog.instance.get('title')?.elements ??
      const <ScreenElement>[]) {
    final f = find.byKey(ValueKey(e.id));
    if (f.evaluate().isEmpty) continue;
    final r = tester.getRect(f);
    expect(screen.inflate(0.5).contains(r.topLeft), isTrue, reason: e.id);
    expect(screen.inflate(0.5).contains(r.bottomRight), isTrue, reason: e.id);
  }
  // Los botones de la columna se ven enteros (el texto no se sale del
  // botón).
  for (final id in ['title-start', 'title-settings', 'title-quit']) {
    final button = tester.getRect(find.byKey(ValueKey(id)));
    final label = find.descendant(
        of: find.byKey(ValueKey(id)), matching: find.byType(RichText));
    for (final l in label.evaluate()) {
      final r = tester.getRect(find.byWidget(l.widget));
      expect(button.inflate(0.5).contains(r.topLeft), isTrue, reason: id);
      expect(button.inflate(0.5).contains(r.bottomRight), isTrue, reason: id);
    }
  }
}

Future<ScreenLayout> _bundled(WidgetTester tester) async {
  final text = await tester.runAsync(
      () => rootBundle.loadString(ScreenLayoutCatalog.pathOf('title')));
  return ScreenLayout.parse(text!);
}

void main() {
  tearDown(() => ScreenLayoutCatalog.instance.put('title', null));
  setUp(() => ExitGuard.register(#titleDefault, () async {}));
  tearDown(() => ExitGuard.unregister(#titleDefault));

  testWidgets('VERIFICAR no da avisos sobre el título por defecto',
      (tester) async {
    await loadRealFonts(tester);
    final l = await _bundled(tester);
    final issues = ScreenChecker(bindings: titleBindings, measure: measureDsText)
        .run(l);
    expect(issues, isEmpty);
    expect(l.elements.where((e) => e.text == 'Co-op JRPG táctico · 1-8 jugadores'),
        isEmpty);
    expect(l.byId('title-patch-notes')?.action, 'verNotasParche');
  });

  const cases = {
    '1280x720': (Size(1280, 720), TextSize.normal),
    '1920x1080': (Size(1920, 1080), TextSize.normal),
    '2560x1440': (Size(2560, 1440), TextSize.normal),
    '1280x720-muy-grande': (Size(1280, 720), TextSize.huge),
    '1920x1080-enorme': (Size(1920, 1080), TextSize.enormous),
  };
  for (final MapEntry(key: name, value: (size, text)) in cases.entries) {
    testWidgets('layout por defecto sin recortes ($name)', (tester) async {
      ScreenLayoutCatalog.instance.put('title', await _bundled(tester));
      await _pump(tester, size: size, text: text);
      expect(find.byKey(const ValueKey('title-screen-layout')), findsOneWidget);
      expect(find.text('Jugado: 19/11/26'), findsOneWidget);
      // Huecos vacíos no se ven (antes salía "ESTADO DE RED").
      expect(find.text('ESTADO DE RED'), findsNothing);
      expect(find.text('AVISOS DE LA CUENTA'), findsNothing);
      _expectNothingClipped(tester, size);
      if (text == TextSize.normal && size.width < 2000) {
        await expectLater(find.byType(TitleScreen),
            matchesGoldenFile('goldens/title_default_$name.png'));
      }
    });

    testWidgets('fallback de código sin recortes ($name)', (tester) async {
      ScreenLayoutCatalog.instance.put('title', null);
      await _pump(tester, size: size, text: text);
      expect(find.byKey(const ValueKey('title-screen-layout')), findsNothing);
      expect(find.byKey(const ValueKey('title-patch-notes')), findsOneWidget);
      _expectNothingClipped(tester, size);
    });
  }
}
