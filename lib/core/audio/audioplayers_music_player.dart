import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'music/music_renderer.dart';
import 'music/music_score.dart';
import 'music/music_service.dart';

/// Render de una pieza fuera del hilo de UI (docs/specs/music.md § 6).
Future<Uint8List> renderSongInIsolate(Song song) =>
    Isolate.run(() => const MusicRenderer().renderWav(song));

/// [MusicPlayer] real con `audioplayers`: un `AudioPlayer` por deck (dos
/// bucles con `ReleaseMode.loop` para el crossfade y uno para jingles).
///
/// Cada pieza se escribe una sola vez en `<temp>/ecos_music/<id>_<firma>.wav`
/// y se reproduce con `DeviceFileSource`. Si el archivo ya existe (otra
/// ejecución con la misma partitura) no se vuelve a renderizar.
class AudioplayersMusicPlayer implements MusicPlayer {
  AudioplayersMusicPlayer({Directory? cacheRoot})
      : _root = cacheRoot ?? Directory.systemTemp,
        _players = List.generate(MusicService.jingleDeck + 1, (_) => AudioPlayer());

  final Directory _root;
  final List<AudioPlayer> _players;
  final _files = <String, Future<String>>{};

  /// Generación por deck: un `play` cuyo archivo llegó tarde (la pieza ya
  /// cambió o se detuvo) no suena.
  late final _gen = List.filled(_players.length, 0);
  late final _volume = List.filled(_players.length, 0.0);

  static String get _sep => Platform.pathSeparator;

  Future<String> _fileFor(MusicSource s) {
    final cached = _files[s.id];
    if (cached != null) return cached;
    final f = _write(s);
    _files[s.id] = f;
    // Si falló, que se pueda reintentar.
    unawaited(f.then<void>((_) {}, onError: (Object _) {
      _files.remove(s.id);
    }));
    return f;
  }

  Future<String> _write(MusicSource s) async {
    final dir = Directory('${_root.path}${_sep}ecos_music');
    await dir.create(recursive: true);
    final name = '${s.id}_${s.hash}.wav';
    final file = File('${dir.path}$_sep$name');
    if (await file.exists() && await file.length() > 44) return file.path;
    final bytes = await s.wav();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
    // Versiones viejas de la misma pieza (otra partitura).
    await for (final e in dir.list()) {
      final n = e.uri.pathSegments.last;
      if (e is File && n.startsWith('${s.id}_') && n != name) {
        try {
          await e.delete();
        } on FileSystemException {
          // En uso o sin permiso: queda para la próxima.
        }
      }
    }
    return file.path;
  }

  @override
  Future<void> play(int deck, MusicSource source,
      {required bool loop, required double volume}) async {
    final g = ++_gen[deck];
    _volume[deck] = volume;
    final path = await _fileFor(source);
    if (g != _gen[deck]) return;
    final p = _players[deck];
    await p.stop();
    await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    if (g != _gen[deck]) return;
    await p.play(DeviceFileSource(path), volume: _volume[deck]);
  }

  @override
  Future<void> setVolume(int deck, double volume) async {
    _volume[deck] = volume;
    await _players[deck].setVolume(volume);
  }

  @override
  Future<void> stop(int deck) async {
    _gen[deck]++;
    await _players[deck].stop();
  }

  @override
  Future<void> preload(MusicSource source) => _fileFor(source);

  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
  }
}
