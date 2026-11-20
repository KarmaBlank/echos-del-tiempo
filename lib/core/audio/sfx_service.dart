import 'dart:async';
import 'dart:typed_data';

import 'sfx_catalog.dart';
import 'sfx_files.dart';
import 'wav_synth.dart';

/// Reproduce un WAV en memoria. El juego registra
/// `AudioplayersSfxPlayer` (docs/specs/audio.md § "Reproducción").
abstract interface class SfxPlayer {
  /// Toca [wav] a [volume] (0..1, el volumen de efectos de los ajustes).
  Future<void> play(Uint8List wav, {double volume = 1});
}

/// No suena: para tests y plataformas sin audio.
class NoopSfxPlayer implements SfxPlayer {
  const NoopSfxPlayer();

  @override
  Future<void> play(Uint8List wav, {double volume = 1}) async {}
}

/// Un sonido programado: id del catálogo y retraso en ms desde que llega
/// el evento (para alinearlo con el efecto visual).
typedef SfxCue = ({String id, int delayMs});

/// Id "afinado": [id] con volumen ([vol], 0..1) y tono ([pitch]) propios
/// (`hit@0.8,1.2`). Con los valores neutros devuelve [id] igual. Lo usa la
/// pista `sound` de las animaciones (game_editor.md § 7.6).
String tunedSfx(String id, {double vol = 1, double pitch = 1}) =>
    (vol - 1).abs() < 0.001 && (pitch - 1).abs() < 0.001
        ? id
        : '$id@${_f(vol)},${_f(pitch)}';

String _f(double v) => v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// Partes de un id afinado: `(id, vol, pitch)`.
(String, double, double) parseTunedSfx(String tuned) {
  final at = tuned.indexOf('@');
  if (at < 0) return (tuned, 1, 1);
  final parts = tuned.substring(at + 1).split(',');
  double n(int i) => i < parts.length ? double.tryParse(parts[i]) ?? 1 : 1;
  return (tuned.substring(0, at), n(0).clamp(0, 1), n(1).clamp(0.25, 4));
}

/// Efectos de sonido del juego: sintetiza cada id del catálogo una sola
/// vez (caché) y lo manda al [SfxPlayer], ahora o después de un retraso.
class SfxService {
  SfxService({
    SfxPlayer player = const NoopSfxPlayer(),
    this.synth = const WavSynth(),
    Map<String, SfxDef>? catalog,
    SfxFiles? Function()? files,
  })  : _player = player,
        catalog = catalog ?? kSfxCatalog,
        _files = files ?? (() => SfxFiles.active);

  final SfxPlayer _player;
  final WavSynth synth;
  final Map<String, SfxDef> catalog;
  final _cache = <String, Uint8List>{};
  final SfxFiles? Function() _files;
  final _tuned = <String, (Uint8List, Uint8List)>{};

  /// Archivos que reemplazan sonidos del catálogo (assets + overrides).
  SfxFiles? get files => _files();

  /// `true` si [id] (o su base, si está afinado) suena: está en el
  /// catálogo sintetizado o tiene archivo.
  bool knows(String id) {
    final base = parseTunedSfx(id).$1;
    return catalog.containsKey(base) || (files?.has(base) ?? false);
  }

  /// Apagado: [play] no hace nada.
  bool muted = false;

  /// Volumen de los efectos (0..1; 0 = no suena). Ver
  /// docs/specs/music.md § 7.
  double volume = 1;

  /// Los bytes WAV de [id] (sintetizados la primera vez). Un id que no
  /// está en el catálogo es un WAV vacío.
  /// Si el id tiene archivo (asset u override del Editor), esos bytes.
  Uint8List wav(String id) =>
      files?.bytesOf(id) ??
      (_cache[id] ??= synth.renderDef(catalog[id] ?? const SfxDef([])));

  /// Bytes de [id] con el tono [pitch] (caché por bytes de origen, así el
  /// reproductor recibe siempre el mismo objeto).
  Uint8List tunedWav(String id, double pitch) {
    final src = wav(id);
    if ((pitch - 1).abs() < 0.001) return src;
    final k = '$id@$pitch';
    final hit = _tuned[k];
    if (hit != null && identical(hit.$1, src)) return hit.$2;
    final out = retuneWav(src, pitch);
    _tuned[k] = (src, out);
    return out;
  }

  /// Toca [id] (puede venir afinado, [tunedSfx]) ahora o dentro de
  /// [delayMs] milisegundos.
  void play(String id, {int delayMs = 0}) {
    if (muted || volume <= 0 || !knows(id)) return;
    if (delayMs <= 0) {
      _playNow(id);
    } else {
      Timer(Duration(milliseconds: delayMs), () {
        if (!muted) _playNow(id);
      });
    }
  }

  /// Toca [id] ya, aunque el juego esté en silencio (botón ESCUCHAR y
  /// vista previa del Editor; respeta solo [vol] y [pitch]).
  void preview(String id, {double vol = 1, double pitch = 1}) {
    final (base, v0, p0) = parseTunedSfx(id);
    if (!knows(base)) return;
    unawaited(_player
        .play(tunedWav(base, p0 * pitch), volume: (v0 * vol).clamp(0, 1))
        .catchError((Object _) {}));
  }

  void _playNow(String id) {
    final (base, v, p) = parseTunedSfx(id);
    unawaited(_player
        .play(tunedWav(base, p), volume: (volume * v).clamp(0, 1))
        .catchError((Object _) {}));
  }
}
