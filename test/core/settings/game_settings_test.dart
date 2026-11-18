import 'dart:io';
import 'dart:typed_data';

import 'package:echos_del_tiempo/core/audio/audio_settings.dart';
import 'package:echos_del_tiempo/core/audio/music/music_service.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
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
        battleSpeed: 2,
        damageNumbers: false,
        confirmDrop: false,
      );
      expect(GameSettings.fromJson(s.toJson()), s);
      expect(
          GameSettings.fromJson({
            'fullscreen': 'sí',
            'shake': 3,
            'flashes': 'cegador',
            'battleSpeed': 'x',
            'damageNumbers': null,
          }),
          const GameSettings());
      // La velocidad se ajusta a la ofrecida más cercana.
      expect(GameSettings.fromJson({'battleSpeed': 1.4}).battleSpeed, 1.5);
      expect(const GameSettings().copyWith(battleSpeed: 9).battleSpeed, 2);
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
      const s = GameSettings(flashes: FlashLevel.off, battleSpeed: 1.5);
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
