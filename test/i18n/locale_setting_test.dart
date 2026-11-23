import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/audio/audio_settings.dart';
import 'package:echos_del_tiempo/core/audio/music/music_service.dart';
import 'package:echos_del_tiempo/core/audio/presentation/audio_providers.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/settings/presentation/settings_menu.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../core/settings/fake_window_mode.dart';

class _MuteSfx implements SfxPlayer {
  @override
  Future<void> play(Uint8List wav, {double volume = 1}) async {}
}

/// OPCIONES → JUEGO → IDIOMA (docs/specs/i18n.md § 3.1): solo idiomas
/// publicados; elegir ENGLISH cambia los textos migrados al momento.
void main() {
  testWidgets('IDIOMA lista los publicados y cambia los textos',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = InMemoryGameSettingsStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        audioSettingsProvider.overrideWith((ref) => AudioSettingsController(
            store: InMemoryAudioSettingsStore(),
            music: MusicService(autoTick: false),
            sfx: SfxService(player: _MuteSfx()))),
        windowModeProvider.overrideWithValue(FakeWindowMode()),
        gameSettingsProvider.overrideWith((ref) => GameSettingsController(
            store: store, window: ref.watch(windowModeProvider))),
      ],
      child: MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(
            body: SettingsMenu(onClose: () {}, initialTab: SettingsTab.game)),
      ),
    ));
    await tester.pumpAndSettle();

    // Automático en un test = es-AR.
    expect(find.text('CONFIGURACION', findRichText: true), findsOneWidget);
    expect(find.text('IDIOMA', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('game-locale-AUTOMÁTICO')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-locale-ESPAÑOL')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-locale-ENGLISH')), findsOneWidget);
    // zh-Hans está oculto: no se ofrece.
    expect(find.byKey(const ValueKey('game-locale-简体中文')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('game-locale-ENGLISH')));
    await tester.pumpAndSettle();
    expect(store.saved?.locale, 'en');
    expect(find.text('SETTINGS', findRichText: true), findsOneWidget);
    expect(find.text('LANGUAGE', findRichText: true), findsOneWidget);
    expect(find.text('GAME', findRichText: true), findsOneWidget);
    expect(find.text('CLOSE [ESC]', findRichText: true), findsOneWidget);
    // Lo no migrado sigue en español (fallback por literal, fase 2).
    expect(find.text('NUMEROS FLOTANTES', findRichText: true), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-locale-AUTO')));
    await tester.pumpAndSettle();
    expect(store.saved?.locale, '');
    expect(find.text('CONFIGURACION', findRichText: true), findsOneWidget);
  });
}
