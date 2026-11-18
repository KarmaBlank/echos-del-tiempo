import 'dart:async';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/audio/audio_settings.dart';
import 'package:echos_del_tiempo/core/audio/music/music_service.dart';
import 'package:echos_del_tiempo/core/audio/presentation/audio_providers.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/settings/presentation/settings_menu.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../core/settings/fake_window_mode.dart';
import '../game_engine/session_test_helpers.dart';

class _SfxRecorder implements SfxPlayer {
  int plays = 0;

  @override
  Future<void> play(Uint8List wav, {double volume = 1}) async => plays++;
}

/// El menú de configuración solo (como lo abre el título), con stores
/// en memoria y una ventana falsa.
Future<
    ({
      InMemoryAudioSettingsStore audio,
      InMemoryGameSettingsStore game,
      _SfxRecorder sfx,
      FakeWindowMode window,
      MusicService music,
    })> _pumpMenu(WidgetTester tester, {bool windowSupported = true}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final audio = InMemoryAudioSettingsStore();
  final game = InMemoryGameSettingsStore();
  final sfx = _SfxRecorder();
  final window = FakeWindowMode();
  final music = MusicService(autoTick: false);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      audioSettingsProvider.overrideWith((ref) => AudioSettingsController(
          store: audio, music: music, sfx: SfxService(player: sfx))),
      if (windowSupported) windowModeProvider.overrideWithValue(window),
      gameSettingsProvider.overrideWith((ref) => GameSettingsController(
          store: game, window: ref.watch(windowModeProvider))),
    ],
    child: MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () => showSettingsDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return (audio: audio, game: game, sfx: sfx, window: window, music: music);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('SONIDO: general, música, efectos con muestra y silencio',
      (tester) async {
    final f = await _pumpMenu(tester);
    expect(find.text('CONFIGURACION'), findsOneWidget);
    // Sin salidas fuera del juego.
    expect(find.byKey(const ValueKey('pause-exit-title')), findsNothing);
    expect(find.byKey(const ValueKey('pause-quit')), findsNothing);
    expect(find.text('100%'), findsOneWidget); // general
    expect(find.text('60%'), findsOneWidget); // música
    expect(find.text('80%'), findsOneWidget); // efectos

    // Música al mínimo: se aplica al soltar y se guarda.
    await tester.drag(
        find.byKey(const ValueKey('audio-music')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(f.music.volume, 0);
    expect(f.audio.saved!.musicVolume, 0);
    expect(f.sfx.plays, 0, reason: 'la música no toca muestras de FX');

    // Mover los efectos toca una muestra con el volumen nuevo.
    await tester.drag(
        find.byKey(const ValueKey('audio-sfx')), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(f.sfx.plays, greaterThan(0));
    expect(f.audio.saved!.sfxVolume, lessThan(AudioSettings.defaultSfx));

    // El general también (pasado el intervalo mínimo entre muestras).
    await tester.runAsync(() => Future<void>.delayed(
        AudioSettingsController.previewGap * 2));
    final before = f.sfx.plays;
    await tester.drag(
        find.byKey(const ValueKey('audio-master')), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(f.sfx.plays, greaterThan(before));
    expect(f.audio.saved!.masterVolume, lessThan(1));

    await _tap(tester, 'audio-mute-SÍ');
    expect(f.audio.saved!.muted, isTrue);
    expect(f.music.muted, isTrue);
    expect(find.text('Todo el sonido está silenciado.'), findsOneWidget);

    await _tap(tester, 'settings-close');
    expect(find.byKey(const ValueKey('settings-menu')), findsNothing);
  });

  testWidgets('PANTALLA: ventana, sacudida y destellos se guardan',
      (tester) async {
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-1');
    expect(find.text('PANTALLA COMPLETA'), findsOneWidget);
    await _tap(tester, 'display-fullscreen-PANTALLA COMPLETA');
    expect(f.window.calls, [true]);
    expect(f.game.saved!.fullscreen, isTrue);
    await _tap(tester, 'display-shake-NO');
    expect(f.game.saved!.screenShake, isFalse);
    await _tap(tester, 'display-flashes-SUAVES');
    expect(f.game.saved!.flashes, FlashLevel.reduced);
    await _tap(tester, 'display-fullscreen-VENTANA');
    expect(f.window.calls, [true, false]);
  });

  testWidgets('PANTALLA: sin soporte de ventana no ofrece pantalla completa',
      (tester) async {
    await _pumpMenu(tester, windowSupported: false);
    await _tap(tester, 'tab-1');
    expect(find.text('PANTALLA COMPLETA'), findsNothing);
    expect(find.byKey(const ValueKey('display-shake-SÍ')), findsOneWidget);
  });

  testWidgets('JUEGO: velocidad, números de daño y confirmar al tirar',
      (tester) async {
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-2');
    await _tap(tester, 'game-speed-x2');
    expect(f.game.saved!.battleSpeed, 2);
    await _tap(tester, 'game-speed-x1.5');
    expect(f.game.saved!.battleSpeed, 1.5);
    await _tap(tester, 'game-numbers-NO');
    expect(f.game.saved!.damageNumbers, isFalse);
    await _tap(tester, 'game-confirm-drop-NO');
    expect(f.game.saved!.confirmDrop, isFalse);
  });

  testWidgets('CONTROLES: lista de teclas; Esc cierra', (tester) async {
    await _pumpMenu(tester);
    await _tap(tester, 'tab-3');
    expect(find.byKey(const ValueKey('settings-controls')), findsOneWidget);
    for (final t in ['MAPA', 'BATALLA', 'MENUS', 'CHAT']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('WASD / Flechas'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-menu')), findsNothing);
  });

  testWidgets('título: CONFIGURACIÓN abre el mismo menú sin salidas',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine()),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
        gameSpritesProvider
            .overrideWith((ref) => Completer<GameSprites>().future),
      ],
      child: MaterialApp(theme: RetroTheme.build(), home: const TitleScreen()),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('SONIDO'), findsNothing, reason: 'ya no hay botón suelto');
    await _tap(tester, 'title-settings');
    expect(find.byKey(const ValueKey('settings-menu')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('settings-menu')),
            matching: find.text('CONFIGURACION')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('pause-quit')), findsNothing);
    expect(find.byKey(const ValueKey('pause-status')), findsNothing);
    await _tap(tester, 'settings-close');
    expect(find.byKey(const ValueKey('settings-menu')), findsNothing);
  });
}
