import 'package:echos_del_tiempo/core/audio/music/music_service.dart';

/// Reproductor falso: registra lo que se le pide (sin renderizar).
class FakeMusicPlayer implements MusicPlayer {
  final calls = <String>[];

  /// Pieza y volumen actuales por deck.
  final track = <int, String?>{};
  final volume = <int, double>{};
  final preloaded = <String>[];

  @override
  Future<void> play(int deck, MusicSource source,
      {required bool loop, required double volume}) async {
    calls.add('play $deck ${source.id}${loop ? ' loop' : ''}');
    track[deck] = source.id;
    this.volume[deck] = volume;
  }

  @override
  Future<void> setVolume(int deck, double volume) async =>
      this.volume[deck] = volume;

  @override
  Future<void> stop(int deck) async {
    calls.add('stop $deck');
    track[deck] = null;
  }

  @override
  Future<void> preload(MusicSource source) async => preloaded.add(source.id);
}
