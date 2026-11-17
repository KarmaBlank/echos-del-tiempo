import 'dart:async';
import 'dart:typed_data';

import 'sfx_catalog.dart';
import 'wav_synth.dart';

/// Reproduce un WAV en memoria. El juego registra
/// `AudioplayersSfxPlayer` (docs/specs/audio.md § "Reproducción").
abstract interface class SfxPlayer {
  Future<void> play(Uint8List wav);
}

/// No suena: para tests y plataformas sin audio.
class NoopSfxPlayer implements SfxPlayer {
  const NoopSfxPlayer();

  @override
  Future<void> play(Uint8List wav) async {}
}

/// Un sonido programado: id del catálogo y retraso en ms desde que llega
/// el evento (para alinearlo con el efecto visual).
typedef SfxCue = ({String id, int delayMs});

/// Efectos de sonido del juego: sintetiza cada id del catálogo una sola
/// vez (caché) y lo manda al [SfxPlayer], ahora o después de un retraso.
class SfxService {
  SfxService({
    SfxPlayer player = const NoopSfxPlayer(),
    this.synth = const WavSynth(),
    Map<String, SfxDef>? catalog,
  })  : _player = player,
        catalog = catalog ?? kSfxCatalog;

  final SfxPlayer _player;
  final WavSynth synth;
  final Map<String, SfxDef> catalog;
  final _cache = <String, Uint8List>{};

  /// Apagado: [play] no hace nada.
  bool muted = false;

  /// Los bytes WAV de [id] (sintetizados la primera vez). Un id que no
  /// está en el catálogo es un WAV vacío.
  Uint8List wav(String id) => _cache[id] ??=
      synth.renderDef(catalog[id] ?? const SfxDef([]));

  /// Toca [id] ahora o dentro de [delayMs] milisegundos.
  void play(String id, {int delayMs = 0}) {
    if (muted || !catalog.containsKey(id)) return;
    if (delayMs <= 0) {
      _playNow(id);
    } else {
      Timer(Duration(milliseconds: delayMs), () {
        if (!muted) _playNow(id);
      });
    }
  }

  void _playNow(String id) =>
      unawaited(_player.play(wav(id)).catchError((Object _) {}));
}
