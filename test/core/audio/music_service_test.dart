import 'package:echos_del_tiempo/core/audio/music/music_catalog.dart';
import 'package:echos_del_tiempo/core/audio/music/music_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_music_player.dart';

void main() {
  late FakeMusicPlayer player;
  late MusicService music;

  setUp(() {
    player = FakeMusicPlayer();
    music = MusicService(player: player, autoTick: false)..volume = 1;
  });

  /// Avanza [seconds] en pasos de 40 ms (como el timer del juego).
  void run(double seconds) {
    for (var t = 0.0; t < seconds - 1e-9; t += 0.04) {
      music.tick(0.04);
    }
  }

  group('bucles y crossfade', () {
    test('la primera pieza entra desde 0 con fundido', () {
      music.playTrack(Music.title);
      expect(player.calls, ['play 1 title loop']);
      expect(music.current, Music.title);
      expect(player.volume[1], 0);
      run(0.6);
      expect(player.volume[1], closeTo(0.5, 0.05));
      run(0.7);
      expect(player.volume[1], 1);
      expect(music.animating, isFalse);
    });

    test('cambiar de pieza: una sube mientras la otra baja y se detiene', () {
      music.playTrack(Music.town);
      run(2);
      music.playTrack(Music.overworld);
      expect(player.calls.last, 'play 0 overworld loop');
      run(0.6);
      expect(player.volume[0], closeTo(0.5, 0.05));
      expect(player.volume[1], closeTo(0.5, 0.05));
      run(0.7);
      expect(player.volume[0], 1);
      expect(player.calls.last, 'stop 1');
      expect(music.deckTrack(1), isNull);
    });

    test('pedir la que ya suena no hace nada', () {
      music.playTrack(Music.town);
      run(2);
      final n = player.calls.length;
      music.playTrack(Music.town);
      run(1);
      expect(player.calls.length, n);
    });

    test('volver a la que se estaba yendo no la reinicia', () {
      music.playTrack(Music.town);
      run(2);
      music.playTrack(Music.overworld);
      run(0.3);
      music.playTrack(Music.town); // vuelve al pueblo antes de salir
      expect(player.calls.where((c) => c.startsWith('play')).toList(),
          ['play 1 town loop', 'play 0 overworld loop']);
      run(1.5);
      expect(music.current, Music.town);
      expect(player.volume[1], 1);
      expect(player.track[0], isNull, reason: 'el mapa se detuvo');
    });

    test('la batalla entra rápido; null funde a silencio', () {
      music.playTrack(Music.zone(1));
      run(2);
      music.playTrack(Music.battle, fade: MusicService.battleFadeSeconds);
      run(0.44);
      expect(player.volume[0], 1);
      music.playTrack(null);
      expect(music.current, isNull);
      run(1.3);
      expect(player.track[0], isNull);
      expect(player.track[1], isNull);
    });

    test('una pieza desconocida es silencio', () {
      music.playTrack('nope');
      expect(player.calls, isEmpty);
      expect(music.current, isNull);
    });
  });

  group('jingles', () {
    test('bajan el bucle de fondo y lo devuelven al terminar, en cola', () {
      music.playTrack(Music.zone(2));
      run(2);
      music.playJingle(Music.victory);
      music.playJingle(Music.levelUp);
      expect(player.calls.last, 'play 2 jingle.victory');
      expect(music.jingle, Music.victory);
      expect(music.queuedJingles, [Music.levelUp]);
      run(MusicService.jingleDuckSeconds + 0.05);
      expect(player.volume[1], closeTo(MusicService.jingleBedLevel, 1e-9),
          reason: 'bucle de fondo');
      final victory = kMusicCatalog[Music.victory]!.seconds +
          MusicService.jingleTailSeconds;
      run(victory);
      expect(music.jingle, Music.levelUp);
      expect(player.calls.last, 'play 2 jingle.levelUp');
      expect(player.volume[1], closeTo(MusicService.jingleBedLevel, 1e-9));
      run(kMusicCatalog[Music.levelUp]!.seconds +
          MusicService.jingleTailSeconds);
      expect(music.jingle, isNull);
      expect(player.calls.last, 'stop 2');
      run(MusicService.jingleReturnSeconds + 0.05);
      expect(player.volume[1], 1, reason: 'el bucle volvió');
    });

    test('la pieza nueva se funde debajo del jingle', () {
      music.playTrack(Music.battle);
      run(2);
      music.playJingle(Music.victory);
      music.playTrack(Music.zone(1));
      run(2);
      // De fondo mientras suena.
      expect(music.deckVolume(0), closeTo(MusicService.jingleBedLevel, 1e-9));
      expect(music.deckTrack(1), isNull, reason: 'la batalla ya salió');
      run(5);
      expect(music.deckVolume(0), 1);
    });

    test('interrupt corta el jingle que suena; la cola sigue', () {
      music.playJingle(Music.victory);
      music.playJingle(Music.zoneUnlocked);
      run(1);
      music.playJingle(Music.levelUp, interrupt: true);
      expect(music.jingle, Music.levelUp);
      expect(player.calls.last, 'play 2 jingle.levelUp');
      expect(music.queuedJingles, [Music.zoneUnlocked]);
      run(kMusicCatalog[Music.levelUp]!.seconds +
          MusicService.jingleTailSeconds);
      expect(music.jingle, Music.zoneUnlocked);
    });

    test('cambiar de bucle no corta el jingle', () {
      music.playTrack(Music.battle);
      run(2);
      music.playJingle(Music.victory);
      music.playTrack(Music.zone(1));
      music.playTrack(Music.town);
      music.playTrack(null);
      run(1);
      expect(music.jingle, Music.victory);
      expect(player.calls.where((c) => c == 'stop 2'), isEmpty);
    });

    test('bedHeld retiene el bucle de fondo sin jingle', () {
      music.playTrack(Music.town);
      run(2);
      music.bedHeld = true;
      run(MusicService.jingleDuckSeconds + 0.05);
      expect(player.volume[1], closeTo(MusicService.jingleBedLevel, 1e-9));
      run(3);
      expect(player.volume[1], closeTo(MusicService.jingleBedLevel, 1e-9));
      expect(music.animating, isFalse, reason: 'sin timer mientras espera');
      music.bedHeld = false;
      run(MusicService.jingleReturnSeconds / 2);
      expect(player.volume[1], inExclusiveRange(0.5, 0.8));
      run(MusicService.jingleReturnSeconds / 2 + 0.05);
      expect(player.volume[1], 1);
    });

    test('fadeOut: la pieza que sale se corta rápido', () {
      music.playTrack(Music.battle);
      run(2);
      music.playTrack(Music.zone(1), fadeOut: MusicService.battleCutSeconds);
      run(MusicService.battleCutSeconds + 0.04);
      expect(music.deckTrack(1), isNull);
      expect(player.track[1], isNull);
      expect(music.deckVolume(0), lessThan(0.3),
          reason: 'la zona recién entra');
    });

    test('silenciado no suenan jingles', () {
      music.muted = true;
      music.playJingle(Music.victory);
      expect(music.jingle, isNull);
      expect(player.calls, isEmpty);
    });
  });

  group('duck de ULT', () {
    test('baja al nivel de duck y vuelve', () {
      music.playTrack(Music.boss);
      run(2);
      music.duck(1.5);
      run(0.2);
      expect(player.volume[1], closeTo(MusicService.ultDuckLevel, 1e-9));
      run(1.4);
      expect(player.volume[1], lessThan(1));
      run(MusicService.ultReturnSeconds + 0.1);
      expect(player.volume[1], 1);
      expect(music.animating, isFalse);
    });
  });

  group('volumen', () {
    test('volumen y silencio se aplican enseguida a lo que suena', () {
      music.playTrack(Music.town);
      run(2);
      music.volume = 0.5;
      expect(player.volume[1], 0.5);
      music.muted = true;
      expect(player.volume[1], 0);
      music.muted = false;
      expect(player.volume[1], 0.5);
      music.volume = 7;
      expect(music.volume, 1);
    });

    test('el reproductor no-op no crea timers ni pide WAVs', () {
      final quiet = MusicService();
      expect(quiet.autoTick, isFalse);
      quiet.playTrack(Music.title);
      quiet.playJingle(Music.victory);
      quiet.duck(1);
      expect(quiet.current, Music.title);
    });

    test('precarga en orden, ignorando ids desconocidos', () async {
      await music.preload([Music.battle, 'nope', Music.boss]);
      expect(player.preloaded, [Music.battle, Music.boss]);
    });
  });
}
