import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'sfx_service.dart';

/// [SfxPlayer] real con `audioplayers` (docs/specs/audio.md § "Reproducción").
///
/// Cada WAV se escribe una sola vez a un archivo temporal y se reproduce
/// desde ahí: así funciona igual en todas las plataformas de escritorio,
/// sin depender del soporte de audio desde bytes en memoria. Usa un pool
/// de reproductores para que los sonidos se superpongan como los
/// osciladores del prototipo (un golpe a TODOS + estados + la ULT suenan
/// juntos): cada sonido va a un reproductor libre y, si no hay, al más
/// viejo de la rotación.
class AudioplayersSfxPlayer implements SfxPlayer {
  AudioplayersSfxPlayer({this.voices = 12})
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
    // Primero uno libre (así un efecto largo, como la ULT, no se corta).
    var i = _next;
    for (var k = 0; k < voices; k++) {
      final j = (_next + k) % voices;
      if (_players[j].state != PlayerState.playing) {
        i = j;
        break;
      }
    }
    _next = (i + 1) % voices;
    final player = _players[i];
    await player.stop();
    await player.play(DeviceFileSource(path));
  }

  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
  }
}
