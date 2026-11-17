import 'dart:io';
import 'dart:typed_data';

import 'package:echos_del_tiempo/core/audio/audio_settings.dart';
import 'package:echos_del_tiempo/core/audio/music/music_service.dart';
import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _SfxRecorder implements SfxPlayer {
  final volumes = <double>[];

  @override
  Future<void> play(Uint8List wav, {double volume = 1}) async =>
      volumes.add(volume);
}

void main() {
  test('JSON: ida y vuelta, valores inválidos al de por defecto', () {
    const s = AudioSettings(musicVolume: 0.25, sfxVolume: 0.5, muted: true);
    expect(AudioSettings.fromJson(s.toJson()), s);
    expect(
        AudioSettings.fromJson({'music': 'x', 'sfx': 9, 'muted': 'sí'}),
        const AudioSettings(
            musicVolume: AudioSettings.defaultMusic, sfxVolume: 1));
    expect(const AudioSettings().copyWith(musicVolume: -1).musicVolume, 0);
  });

  test('el controlador aplica a música y efectos y guarda al confirmar',
      () async {
    final store = InMemoryAudioSettingsStore();
    final music = MusicService(autoTick: false);
    final rec = _SfxRecorder();
    final sfx = SfxService(player: rec);
    final c = AudioSettingsController(store: store, music: music, sfx: sfx);
    expect(music.volume, AudioSettings.defaultMusic);
    expect(sfx.volume, AudioSettings.defaultSfx);

    c.setMusic(0.3);
    c.setSfx(0.4);
    expect(music.volume, 0.3);
    expect(sfx.volume, 0.4);
    expect(store.saved, isNull, reason: 'arrastrar no guarda');
    await c.commit();
    expect(store.saved, const AudioSettings(musicVolume: 0.3, sfxVolume: 0.4));

    sfx.play(Sfx.heal);
    await Future<void>.delayed(Duration.zero);
    expect(rec.volumes, [0.4]);

    await c.toggleMute();
    expect(music.muted, isTrue);
    expect(sfx.muted, isTrue);
    expect(store.saved!.muted, isTrue);
    sfx.play(Sfx.heal);
    await Future<void>.delayed(Duration.zero);
    expect(rec.volumes, [0.4], reason: 'silenciado');
    c.dispose();
  });

  test('carga lo guardado al arrancar', () async {
    final store = InMemoryAudioSettingsStore(
        const AudioSettings(musicVolume: 0.1, sfxVolume: 0.2));
    final music = MusicService(autoTick: false);
    final c = AudioSettingsController(
        store: store, music: music, sfx: SfxService());
    await c.load();
    expect(c.state.musicVolume, 0.1);
    expect(music.volume, 0.1);
    c.dispose();
  });

  test('audio.json en disco (escritura atómica, corrupto = null)', () async {
    final dir = await Directory.systemTemp.createTemp('ecos_audio_test_');
    addTearDown(() => dir.delete(recursive: true));
    final store = JsonFileAudioSettingsStore.inDirectory(dir.path);
    expect(await store.load(), isNull);
    const s = AudioSettings(musicVolume: 0.35, sfxVolume: 0.9);
    await store.save(s);
    expect(await store.load(), s);
    await store.file.writeAsString('{no es json');
    expect(await store.load(), isNull);
  });
}
