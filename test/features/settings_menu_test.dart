import 'dart:async';

import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/vision_palette.dart';
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

import '../app/hit_target_audit.dart';
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
      // Tamaño del texto en vivo, como `EcosApp`.
      builder: (context, child) => Consumer(
        builder: (context, ref, _) => RetroTextScale(
            factor: ref.watch(
                gameSettingsProvider.select((s) => s.textSize.factor)),
            child: ColorVisionScope(
                mode: ref.watch(
                    gameSettingsProvider.select((s) => s.colorVision)),
                child: child!)),
      ),
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

  testWidgets('PANTALLA / ACCESIBILIDAD: ventana, sacudida y destellos',
      (tester) async {
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-1');
    expect(find.text('PANTALLA COMPLETA'), findsOneWidget);
    await _tap(tester, 'display-fullscreen-PANTALLA COMPLETA');
    expect(f.window.calls, [true]);
    expect(f.game.saved!.fullscreen, isTrue);
    await _tap(tester, 'tab-2');
    await _tap(tester, 'display-shake-NO');
    expect(f.game.saved!.screenShake, isFalse);
    await _tap(tester, 'display-flashes-SUAVES');
    expect(f.game.saved!.flashes, FlashLevel.reduced);
    await _tap(tester, 'tab-1');
    await _tap(tester, 'display-fullscreen-VENTANA');
    expect(f.window.calls, [true, false]);
  });

  testWidgets('PANTALLA: escalado, CRT, partículas y FPS (sin VSync)',
      (tester) async {
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-1');
    // Por defecto: AJUSTAR, CRT NORMAL, ALTA, 60.
    for (final k in [
      'display-scale-AJUSTAR',
      'display-crt-NORMAL',
      'display-particles-ALTA',
      'display-fps-60',
    ]) {
      final b = tester.widget<PanelButton>(find.byKey(ValueKey(k)));
      expect(b.selected, isTrue, reason: k);
    }
    expect(find.textContaining('VSYNC'), findsNothing);
    expect(find.textContaining('ANIMACIONES'), findsNothing);

    await _tap(tester, 'display-scale-PIXEL PERFECT');
    expect(f.game.saved!.scale, ScaleMode.pixelPerfect);
    expect(find.text('Píxeles exactos (×2, ×3...) con barras negras.'),
        findsOneWidget);
    await _tap(tester, 'display-crt-APAGADO');
    expect(f.game.saved!.crt, CrtLevel.off);
    await _tap(tester, 'display-crt-FUERTE');
    expect(f.game.saved!.crt, CrtLevel.strong);
    await _tap(tester, 'display-particles-BAJA');
    expect(f.game.saved!.particles, ParticleLevel.low);
    await _tap(tester, 'display-fps-30');
    expect(f.game.saved!.fpsLimit, FpsLimit.fps30);
    await _tap(tester, 'display-fps-SIN LÍMITE');
    expect(f.game.saved!.fpsLimit, FpsLimit.none);
  });

  testWidgets('PANTALLA: FPS Y PING (apagado) y su ESQUINA', (tester) async {
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-1');
    expect(find.text('FPS Y PING'), findsOneWidget);
    PanelButton btn(String k) =>
        tester.widget<PanelButton>(find.byKey(ValueKey(k)));
    expect(btn('display-perf-NO').selected, isTrue);
    expect(btn('display-perf-corner-ARRIBA DER.').selected, isTrue);
    // Apagado: la esquina no se elige.
    expect(btn('display-perf-corner-ABAJO IZQ.').onPressed, isNull);
    await _tap(tester, 'display-perf-SÍ');
    expect(f.game.saved!.perfOverlay, isTrue);
    await _tap(tester, 'display-perf-corner-ABAJO IZQ.');
    expect(f.game.saved!.perfCorner, OverlayCorner.bottomLeft);
    await _tap(tester, 'display-perf-corner-ARRIBA IZQ.');
    expect(f.game.saved!.perfCorner, OverlayCorner.topLeft);
  });

  testWidgets('ACCESIBILIDAD: TAMAÑO DEL TEXTO se aplica en vivo y se guarda',
      (tester) async {
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-2');
    expect(
        tester
            .widget<PanelButton>(
                find.byKey(const ValueKey('display-text-NORMAL')))
            .selected,
        isTrue);
    double scaleOf(String text) => MediaQuery.textScalerOf(
            tester.element(find.text(text).first))
        .scale(RetroType.small);
    // VT323: 20 / 25 / 30 px.
    expect(scaleOf('TAMAÑO DEL TEXTO'), 20, reason: 'Normal a 1x');
    for (final (key, size, px) in const [
      ('MUY GRANDE', TextSize.huge, 30.0),
      ('GRANDE', TextSize.large, 25.0),
      ('NORMAL', TextSize.normal, 20.0),
    ]) {
      await _tap(tester, 'display-text-$key');
      expect(f.game.saved!.textSize, size);
      expect(scaleOf('TAMAÑO DEL TEXTO'), px, reason: key);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ACCESIBILIDAD: FUENTE DE LECTURA (vista previa) se guarda',
      (tester) async {
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-2');
    // Cada opción escrita en su propia fuente.
    String? family(String key) => tester
        .widget<Text>(find.descendant(
            of: find.byKey(ValueKey(key)), matching: find.byType(Text)))
        .style
        ?.fontFamily;
    expect(family('display-font-vt323'), RetroType.vt323Family);
    expect(family('display-font-classic'), RetroType.pixelFamily);
    await _tap(tester, 'display-font-classic');
    expect(f.game.saved!.readingFont, ReadingFont.classic);
    await _tap(tester, 'display-font-vt323');
    expect(f.game.saved!.readingFont, ReadingFont.vt323);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PANTALLA: sin soporte de ventana no ofrece pantalla completa',
      (tester) async {
    await _pumpMenu(tester, windowSupported: false);
    await _tap(tester, 'tab-1');
    expect(find.text('PANTALLA COMPLETA'), findsNothing);
    expect(find.byKey(const ValueKey('display-scale-AJUSTAR')), findsOneWidget);
  });

  testWidgets('JUEGO: números de daño y confirmar al tirar',
      (tester) async {
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-3');
    expect(find.byKey(const ValueKey('game-speed-x2')), findsNothing,
        reason: 'la velocidad de animaciones ya no existe');
    await _tap(tester, 'game-numbers-NO');
    expect(f.game.saved!.damageNumbers, isFalse);
    await _tap(tester, 'game-confirm-drop-NO');
    expect(f.game.saved!.confirmDrop, isFalse);
  });

  testWidgets('ACCESIBILIDAD: modo daltónico se aplica y se guarda',
      (tester) async {
    addTearDown(() => VisionPalette.mode = ColorVision.off);
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-2');
    expect(find.byKey(const ValueKey('a11y-vision-preview')), findsOneWidget);
    expect(
        tester
            .widget<PanelButton>(find.byKey(const ValueKey('a11y-vision-NO')))
            .selected,
        isTrue);
    for (final (key, mode) in const [
      ('DEUTERANOPÍA', ColorVision.deuteranopia),
      ('PROTANOPÍA', ColorVision.protanopia),
      ('TRITANOPÍA', ColorVision.tritanopia),
      ('NO', ColorVision.off),
    ]) {
      await _tap(tester, 'a11y-vision-$key');
      expect(f.game.saved!.colorVision, mode);
      expect(VisionPalette.mode, mode, reason: 'se aplica en vivo');
      expect(ProtoColors.green.toARGB32(),
          VisionPalette.inMode(mode, VisionSlot.good).toARGB32());
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ACCESIBILIDAD: REDUCIR MOVIMIENTO apaga la sacudida y suaviza',
      (tester) async {
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-2');
    await _tap(tester, 'a11y-motion-SÍ');
    final s = f.game.saved!;
    expect(s.reduceMotion, isTrue);
    expect(s.screenShake, isTrue, reason: 'el ajuste propio no se pisa');
    expect(s.shakeOn, isFalse);
    expect(s.flashFactor, FlashLevel.reduced.factor);
    // SACUDIDA se ve en NO y deshabilitada; DESTELLOS en SUAVES.
    final shake =
        tester.widget<PanelButton>(find.byKey(const ValueKey('display-shake-NO')));
    expect(shake.selected, isTrue);
    expect(shake.onPressed, isNull);
    expect(
        tester
            .widget<PanelButton>(
                find.byKey(const ValueKey('display-flashes-SUAVES')))
            .selected,
        isTrue);
    expect(find.text('Apagada por REDUCIR MOVIMIENTO.'), findsOneWidget);
    await _tap(tester, 'a11y-motion-NO');
    expect(f.game.saved!.shakeOn, isTrue);
  });

  testWidgets('JUEGO: TIEMPO DE TURNO se guarda', (tester) async {
    final f = await _pumpMenu(tester);
    await _tap(tester, 'tab-3');
    expect(
        tester
            .widget<PanelButton>(
                find.byKey(const ValueKey('game-turn-NORMAL (30 S)')))
            .selected,
        isTrue);
    await _tap(tester, 'game-turn-SIN LÍMITE');
    expect(f.game.saved!.turnTimer, TurnTimer.unlimited);
    await _tap(tester, 'game-turn-LARGO (60 S)');
    expect(f.game.saved!.turnTimer, TurnTimer.long);
  });

  testWidgets('objetivos clicables ≥ 24 px en todas las pestañas',
      (tester) async {
    await _pumpMenu(tester);
    for (var i = 0; i < SettingsTab.values.length; i++) {
      await _tap(tester, 'tab-$i');
      expect(smallHitTargets(tester), isEmpty, reason: 'pestaña $i');
    }
  });

  testWidgets('CONTROLES: lista de teclas; Esc cierra', (tester) async {
    await _pumpMenu(tester);
    await _tap(tester, 'tab-4');
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
