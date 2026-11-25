import 'dart:io';
import 'dart:typed_data';

import 'package:echos_del_tiempo/core/audio/audio_settings.dart';
import 'package:echos_del_tiempo/core/audio/music/music_service.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/core/settings/frame_limiter.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/window_mode.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_window_mode.dart';

class _SfxRecorder implements SfxPlayer {
  final volumes = <double>[];

  @override
  Future<void> play(Uint8List wav, {double volume = 1}) async =>
      volumes.add(volume);
}

void main() {
  group('GameSettings', () {
    test('JSON: ida y vuelta; inválidos al de por defecto', () {
      const s = GameSettings(
        fullscreen: true,
        screenShake: false,
        flashes: FlashLevel.reduced,
        damageNumbers: false,
        confirmDrop: false,
        scale: ScaleMode.pixelPerfect,
        crt: CrtLevel.strong,
        particles: ParticleLevel.low,
        fpsLimit: FpsLimit.none,
      );
      expect(GameSettings.fromJson(s.toJson()), s);
      expect(
          GameSettings.fromJson({
            'fullscreen': 'sí',
            'shake': 3,
            'flashes': 'cegador',
            'damageNumbers': null,
            'scale': 'estirar',
            'crt': true,
            'particles': 'ultra',
            'fpsLimit': 45,
          }),
          const GameSettings());
      expect(s.toJson()['fpsLimit'], 0, reason: 'sin límite = 0');
    });

    test('accesibilidad v0.5.1: daltónico, reducir movimiento, tiempo de turno',
        () {
      const d = GameSettings();
      expect(d.colorVision, ColorVision.off);
      expect(d.reduceMotion, isFalse);
      expect(d.turnTimer, TurnTimer.normal);
      const s = GameSettings(
          colorVision: ColorVision.tritanopia,
          reduceMotion: true,
          turnTimer: TurnTimer.unlimited);
      final j = s.toJson();
      expect(j['colorVision'], 'tritanopia');
      expect(j['reduceMotion'], true);
      expect(j['turnTimer'], 'unlimited');
      expect(GameSettings.fromJson(j), s);
      // Inválidos o ausentes (game.json de v0.5.0): por defecto.
      expect(
          GameSettings.fromJson(
              {'colorVision': 'acromático', 'reduceMotion': 'sí', 'turnTimer': 9}),
          d);
      // Efectivos: REDUCIR MOVIMIENTO apaga la sacudida y deja los
      // destellos a lo sumo SUAVES (NO sigue en NO).
      expect(d.shakeOn, isTrue);
      expect(d.flashFactor, FlashLevel.normal.factor);
      expect(s.shakeOn, isFalse);
      expect(s.flashFactor, FlashLevel.reduced.factor);
      expect(s.copyWith(flashes: FlashLevel.off).flashFactor, 0);
      expect(const GameSettings(screenShake: false).shakeOn, isFalse);
    });

    test('FPS y ping v0.5.1: apagado arriba a la derecha; JSON y game.json viejo',
        () async {
      const d = GameSettings();
      expect(d.perfOverlay, isFalse);
      expect(d.perfCorner, OverlayCorner.topRight);
      const s = GameSettings(
          perfOverlay: true, perfCorner: OverlayCorner.bottomLeft);
      final j = s.toJson();
      expect(j['perfOverlay'], true);
      expect(j['perfCorner'], 'bottomLeft');
      expect(GameSettings.fromJson(j), s);
      expect(s, isNot(d));
      expect(s.copyWith(perfCorner: OverlayCorner.topLeft).perfCorner,
          OverlayCorner.topLeft);
      // game.json de antes (sin las claves) o con valores inválidos.
      final old = Map<String, Object?>.of(d.toJson())
        ..remove('perfOverlay')
        ..remove('perfCorner');
      expect(GameSettings.fromJson(old), d);
      expect(
          GameSettings.fromJson(const {'perfOverlay': 1, 'perfCorner': 'x'}),
          d);
      // El controlador guarda el cambio; game.json en disco.
      final store = InMemoryGameSettingsStore();
      final c = GameSettingsController(store: store);
      addTearDown(c.dispose);
      await c.update(d.copyWith(perfOverlay: true));
      expect(store.saved?.perfOverlay, isTrue);
      final dir = await Directory.systemTemp.createTemp('ecos_perf_test_');
      addTearDown(() => dir.delete(recursive: true));
      final file = JsonFileGameSettingsStore.inDirectory(dir.path);
      await file.save(s);
      expect(await file.load(), s);
    });

    test('por defecto: CRT SUAVE (v0.49.9), partículas ALTA, 60 FPS, AJUSTAR',
        () {
      const d = GameSettings();
      expect(d.crt, CrtLevel.soft);
      // Desde el formato 3, el nivel guardado se conserva.
      expect(GameSettings.fromJson(const {'version': 3, 'crt': 'normal'}).crt,
          CrtLevel.normal);
      expect(const GameSettings(crt: CrtLevel.normal).toJson()['crt'],
          'normal');
      expect(d.particles, ParticleLevel.high);
      expect(d.fpsLimit, FpsLimit.fps60);
      expect(d.scale, ScaleMode.fit);
      expect(GameSettings.fromJson(const {}), d);
    });

    test('migración: un game.json de v0.2.1 con battleSpeed carga igual',
        () async {
      final dir = await Directory.systemTemp.createTemp('ecos_game_mig_');
      addTearDown(() => dir.delete(recursive: true));
      final store = JsonFileGameSettingsStore.inDirectory(dir.path);
      await store.file.writeAsString('{"fullscreen":false,"shake":false,'
          '"flashes":"reduced","battleSpeed":2,"damageNumbers":true,'
          '"confirmDrop":false}');
      final s = await store.load();
      expect(
          s,
          const GameSettings(
              screenShake: false,
              flashes: FlashLevel.reduced,
              confirmDrop: false));
      // Los gráficos nuevos, por defecto (CRT prendido, SUAVE).
      expect(s!.crt, CrtLevel.soft);
      await store.save(s);
      final raw = await store.file.readAsString();
      expect(raw, isNot(contains('battleSpeed')));
      expect(raw, contains('"crt":"soft"'));
    });

    test('el controlador aplica el límite de FPS (al crear, cargar y cambiar)',
        () async {
      final limiter = FrameLimiter(fps: 999);
      final c = GameSettingsController(
          store: InMemoryGameSettingsStore(
              const GameSettings(fpsLimit: FpsLimit.fps30)),
          frameLimiter: limiter);
      expect(limiter.fps, 60);
      await c.load();
      expect(limiter.fps, 30);
      await c.update(c.state.copyWith(fpsLimit: FpsLimit.none));
      expect(limiter.fps, isNull);
      c.dispose();
    });

    test('el controlador guarda cada cambio y aplica la ventana', () async {
      final store = InMemoryGameSettingsStore();
      final window = FakeWindowMode();
      final c = GameSettingsController(store: store, window: window);
      await c.update(c.state.copyWith(screenShake: false));
      expect(store.saved!.screenShake, isFalse);
      expect(window.calls, isEmpty);
      await c.update(c.state.copyWith(fullscreen: true));
      expect(window.calls, [true]);
      expect(store.saved!.fullscreen, isTrue);
      await c.update(c.state.copyWith(fullscreen: false));
      expect(window.calls, [true, false]);
      c.dispose();
    });

    test('al cargar vuelve a pantalla completa si así quedó', () async {
      final window = FakeWindowMode();
      final c = GameSettingsController(
          store: InMemoryGameSettingsStore(
              const GameSettings(fullscreen: true, damageNumbers: false)),
          window: window);
      await c.load();
      expect(c.state.damageNumbers, isFalse);
      expect(window.calls, [true]);
      c.dispose();
    });

    test('sin soporte (o sin runner) la ventana no hace nada', () async {
      expect(await const WindowMode.unsupported().setFullscreen(true), isFalse);
    });

    test('game.json en disco (atómico, corrupto = null)', () async {
      final dir = await Directory.systemTemp.createTemp('ecos_game_test_');
      addTearDown(() => dir.delete(recursive: true));
      final store = JsonFileGameSettingsStore.inDirectory(dir.path);
      expect(await store.load(), isNull);
      const s = GameSettings(flashes: FlashLevel.off, crt: CrtLevel.off);
      await store.save(s);
      expect(await store.load(), s);
      await store.file.writeAsString('[1, 2');
      expect(await store.load(), isNull);
    });
  });

  group('AudioSettings (volumen general)', () {
    test('un audio.json de antes (sin master) se conserva', () async {
      final dir = await Directory.systemTemp.createTemp('ecos_audio_mig_');
      addTearDown(() => dir.delete(recursive: true));
      final store = JsonFileAudioSettingsStore.inDirectory(dir.path);
      await store.file
          .writeAsString('{"music":0.25,"sfx":0.5,"muted":false}');
      final s = await store.load();
      expect(s, const AudioSettings(musicVolume: 0.25, sfxVolume: 0.5));
      expect(s!.masterVolume, 1);
    });

    test('el general multiplica música y efectos', () {
      final music = MusicService(autoTick: false);
      final sfx = SfxService();
      final c = AudioSettingsController(
          store: InMemoryAudioSettingsStore(), music: music, sfx: sfx);
      c.setMusic(0.5);
      c.setSfx(0.8);
      c.setMaster(0.5);
      expect(music.volume, closeTo(0.25, 1e-9));
      expect(sfx.volume, closeTo(0.4, 1e-9));
      c.dispose();
    });

    test('muestra de efectos: suena con el volumen nuevo, sin ráfagas',
        () async {
      final rec = _SfxRecorder();
      final c = AudioSettingsController(
          store: InMemoryAudioSettingsStore(),
          music: MusicService(autoTick: false),
          sfx: SfxService(player: rec));
      c.setSfx(0.3);
      c.preview();
      c.preview(); // enseguida: no repite
      await Future<void>.delayed(Duration.zero);
      expect(rec.volumes, [closeTo(0.3, 1e-9)]);
      c.preview(force: true);
      await Future<void>.delayed(Duration.zero);
      expect(rec.volumes, hasLength(2));
      c.dispose();
    });
  });
}
