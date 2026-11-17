import 'dart:math' as math;
import 'dart:typed_data';

import 'sfx_catalog.dart';

/// Sintetizador de los `beep` del prototipo a WAV PCM de 16 bits mono,
/// en Dart puro (sin plugins). Ver docs/specs/audio.md § "Sintetizador".
class WavSynth {
  const WavSynth({this.sampleRate = 22050});

  final int sampleRate;

  /// Ganancia final de la rampa exponencial
  /// (`exponentialRampToValueAtTime(0.0001, ...)`).
  static const floorGain = 0.0001;

  static const headerBytes = 44;

  /// Muestras en [-1, 1] de todos los [tones] mezclados.
  Float64List samples(List<SfxTone> tones) {
    final length = tones.fold<double>(0, (m, t) => math.max(m, t.end));
    final n = (length * sampleRate).ceil();
    final out = Float64List(n);
    for (final tone in tones) {
      final start = (tone.delay * sampleRate).round();
      final count = (tone.duration * sampleRate).round();
      final ratio = floorGain / tone.volume;
      for (var i = 0; i < count && start + i < n; i++) {
        final t = i / sampleRate;
        final gain = tone.volume * math.pow(ratio, t / tone.duration);
        out[start + i] += _wave(tone.wave, tone.frequency * t) * gain;
      }
    }
    for (var i = 0; i < n; i++) {
      out[i] = out[i].clamp(-1.0, 1.0);
    }
    return out;
  }

  /// Archivo WAV completo (cabecera RIFF de 44 bytes + datos).
  Uint8List render(List<SfxTone> tones) {
    final s = samples(tones);
    final dataBytes = s.length * 2;
    final b = ByteData(headerBytes + dataBytes);
    void ascii(int at, String text) {
      for (var i = 0; i < text.length; i++) {
        b.setUint8(at + i, text.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    b.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    b.setUint32(16, 16, Endian.little); // tamaño del bloque fmt
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // mono
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little); // byteRate
    b.setUint16(32, 2, Endian.little); // blockAlign
    b.setUint16(34, 16, Endian.little); // bits por muestra
    ascii(36, 'data');
    b.setUint32(40, dataBytes, Endian.little);
    for (var i = 0; i < s.length; i++) {
      b.setInt16(headerBytes + i * 2, (s[i] * 32767).round(), Endian.little);
    }
    return b.buffer.asUint8List();
  }

  /// Valor de la onda en la fase [cycles] (vueltas, no radianes).
  static double _wave(Waveform w, double cycles) {
    final frac = cycles - cycles.floorToDouble();
    switch (w) {
      case Waveform.sine:
        return math.sin(2 * math.pi * cycles);
      case Waveform.square:
        return frac < 0.5 ? 1 : -1;
      case Waveform.sawtooth:
        return 2 * frac - 1;
      case Waveform.triangle:
        return 1 - 4 * (frac - 0.5).abs();
    }
  }
}
