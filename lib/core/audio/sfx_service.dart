import 'dart:async';
import 'dart:typed_data';

import 'sfx_catalog.dart';
import 'wav_synth.dart';

/// Reproduce un WAV en memoria. La implementación real necesita un
/// plugin de audio (p. ej. `audioplayers`, ver docs/specs/audio.md
/// § "Reproducción"); hoy se registra [NoopSfxPlayer].
abstract interface class SfxPlayer {
  Future<void> play(Uint8List wav);
}

/// No suena: el proyecto todavía no tiene un plugin de audio.
class NoopSfxPlayer implements SfxPlayer {
  const NoopSfxPlayer();

  @override
  Future<void> play(Uint8List wav) async {}
}

/// Efectos de sonido del juego: sintetiza cada [Sfx] del catálogo una
/// sola vez (caché) y lo manda al [SfxPlayer].
class SfxService {
  SfxService({
    SfxPlayer player = const NoopSfxPlayer(),
    this.synth = const WavSynth(),
    this.catalog = kSfxCatalog,
  }) : _player = player;

  final SfxPlayer _player;
  final WavSynth synth;
  final Map<Sfx, List<SfxTone>> catalog;
  final _cache = <Sfx, Uint8List>{};

  /// Apagado: [play] no hace nada.
  bool muted = false;

  /// Los bytes WAV de [sfx] (sintetizados la primera vez).
  Uint8List wav(Sfx sfx) =>
      _cache[sfx] ??= synth.render(catalog[sfx] ?? const []);

  void play(Sfx sfx) {
    if (muted) return;
    unawaited(_player.play(wav(sfx)).catchError((Object _) {}));
  }
}
