import 'dart:math' as math;
import 'dart:typed_data';

import 'sfx_catalog.dart';

/// Sintetizador chiptune a WAV PCM de 16 bits mono, en Dart puro (sin
/// plugins) y determinista. Ver docs/specs/audio.md § "Sintetizador".
class WavSynth {
  const WavSynth({this.sampleRate = 22050});

  final int sampleRate;

  /// Ganancia final de la rampa exponencial
  /// (`exponentialRampToValueAtTime(0.0001, ...)`).
  static const floorGain = 0.0001;

  static const headerBytes = 44;

  /// Muestras de todas las voces [tones] sumadas (sin recortar ni
  /// normalizar).
  Float64List mix(List<SfxTone> tones) {
    final length = tones.fold<double>(0, (m, t) => math.max(m, t.end));
    final n = (length * sampleRate).ceil();
    final out = Float64List(n);
    for (final tone in tones) {
      _renderVoice(tone, out);
    }
    return out;
  }

  /// Muestras en [-1, 1] de todos los [tones] mezclados (recorte duro,
  /// como el destino de audio del prototipo).
  Float64List samples(List<SfxTone> tones) {
    final out = mix(tones);
    for (var i = 0; i < out.length; i++) {
      out[i] = out[i].clamp(-1.0, 1.0);
    }
    return out;
  }

  /// Muestras de un efecto: mezcla y, si tiene `peak`, normaliza para que
  /// el pico sea exactamente ese (nunca recorta).
  Float64List samplesOf(SfxDef def) {
    final peak = def.peak;
    if (peak == null) return samples(def.voices);
    final out = mix(def.voices);
    var max = 0.0;
    for (final x in out) {
      if (x.abs() > max) max = x.abs();
    }
    if (max > 0) {
      final k = peak / max;
      for (var i = 0; i < out.length; i++) {
        out[i] = (out[i] * k).clamp(-1.0, 1.0);
      }
    }
    return out;
  }

  /// Archivo WAV completo de unas voces sueltas (sin normalizar).
  Uint8List render(List<SfxTone> tones) => encode(samples(tones));

  /// Archivo WAV completo de un efecto del catálogo.
  Uint8List renderDef(SfxDef def) => encode(samplesOf(def));

  /// Cabecera RIFF de 44 bytes + PCM 16 bits de [s] (en [-1, 1]).
  Uint8List encode(Float64List s) {
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

  /// Suma una voz a [out].
  void _renderVoice(SfxTone tone, Float64List out) {
    final n = out.length;
    final start = (tone.delay * sampleRate).round();
    final count = (tone.duration * sampleRate).round();
    final ratio = floorGain / tone.volume;
    final f0 = tone.frequency;
    final f1 = tone.endFrequency ?? f0;
    final sweep = f1 != f0;
    final vibrato = tone.vibratoDepth != 0 && tone.vibratoRate != 0;
    // Frecuencia constante: fase = f·t, idéntico al `beep` del prototipo.
    final constant = !sweep && !vibrato;
    final attack = tone.attack;
    final sustainEnd = attack + tone.hold;
    final decay = math.max(1e-9, tone.duration - sustainEnd);
    final alpha = tone.lowpass > 0
        ? 1 - math.exp(-2 * math.pi * tone.lowpass / sampleRate)
        : 1.0;
    final levels = tone.crush > 0 ? (1 << (tone.crush - 1)).toDouble() : 0.0;

    var phase = 0.0;
    var lfsr = tone.seed & 0x7fff;
    if (lfsr == 0) lfsr = 1;
    var lastCycle = 0;
    var lp = 0.0;
    for (var i = 0; i < count && start + i < n; i++) {
      final t = i / sampleRate;
      double cycles;
      if (constant) {
        cycles = f0 * t;
      } else {
        var f = sweep ? f0 * math.pow(f1 / f0, t / tone.duration) : f0;
        if (vibrato) {
          f *= 1 + tone.vibratoDepth * math.sin(2 * math.pi * tone.vibratoRate * t);
        }
        cycles = phase;
        phase += f / sampleRate;
      }
      double w;
      if (tone.wave == Waveform.noise) {
        // LFSR de 15 bits estilo NES: avanza una vez por ciclo.
        final c = cycles.floor();
        while (lastCycle < c) {
          final bit = (lfsr ^ (lfsr >> 1)) & 1;
          lfsr = (lfsr >> 1) | (bit << 14);
          lastCycle++;
        }
        w = (lfsr & 1) == 1 ? 1.0 : -1.0;
      } else {
        w = _wave(tone.wave, cycles);
      }
      if (alpha < 1) {
        lp += alpha * (w - lp);
        w = lp;
      }
      double env;
      if (t < attack) {
        env = t / attack;
      } else if (t < sustainEnd) {
        env = 1;
      } else {
        env = math.pow(ratio, (t - sustainEnd) / decay).toDouble();
      }
      var x = w * env;
      if (levels > 0) x = (x * levels).roundToDouble() / levels;
      out[start + i] += x * tone.volume;
    }
  }

  /// Valor de la onda en la fase [cycles] (vueltas, no radianes).
  static double _wave(Waveform w, double cycles) {
    final frac = cycles - cycles.floorToDouble();
    switch (w) {
      case Waveform.sine:
        return math.sin(2 * math.pi * cycles);
      case Waveform.square:
        return frac < 0.5 ? 1 : -1;
      case Waveform.pulse:
        return frac < 0.25 ? 1 : -1;
      case Waveform.sawtooth:
        return 2 * frac - 1;
      case Waveform.triangle:
        return 1 - 4 * (frac - 0.5).abs();
      case Waveform.noise:
        return 0; // se resuelve en _renderVoice (necesita estado)
    }
  }
}
