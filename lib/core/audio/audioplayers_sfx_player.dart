import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'sfx_service.dart';

/// [SfxPlayer] real con `audioplayers` (docs/specs/audio.md § "Reproducción").
///
/// Cada WAV se escribe una sola vez a un archivo temporal y se reproduce
/// desde ahí: así funciona igual en todas las plataformas de escritorio,
/// sin depender del soporte de audio desde bytes en memoria. Usa un pool
/// chico de reproductores en rotación para que los sonidos se superpongan
/// (p. ej. el golpe y la curación del mismo turno).
class AudioplayersSfxPlayer implements SfxPlayer {
  AudioplayersSfxPlayer({this.voices = 4})
      : _players = List.generate(voices, (_) => AudioPlayer());

  final int voices;
  final List<AudioPlayer> _players;
  final _files = <Uint8List, Future<String>>{};
  int _next = 0;

  /// `SfxService` cachea los bytes de cada efecto, así que el mismo
  /// sonido llega siempre como el mismo objeto: se usa como clave.
  Future<String> _fileFor(Uint8List wav) => _files[wav] ??= () async {
        final dir = await Directory.systemTemp.createTemp('ecos_sfx_');
        final file = File('${dir.path}${Platform.pathSeparator}sfx_${_files.length}.wav');
        await file.writeAsBytes(wav, flush: true);
        return file.path;
      }();

  @override
  Future<void> play(Uint8List wav) async {
    final path = await _fileFor(wav);
    final player = _players[_next];
    _next = (_next + 1) % voices;
    await player.stop();
    await player.play(DeviceFileSource(path));
  }

  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
  }
}
