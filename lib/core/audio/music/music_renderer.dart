import 'dart:math' as math;
import 'dart:typed_data';

import '../wav_synth.dart';
import 'music_score.dart';

/// Secuenciador + sintetizador de la música a PCM mono (Dart puro,
/// determinista). Ver docs/specs/music.md § 3.
class MusicRenderer {
  const MusicRenderer({this.sampleRate = 22050});

  final int sampleRate;

  /// Fundido con el que una nota corta a la anterior del mismo canal.
  static const monoFadeSeconds = 0.004;

  /// Fundido final de un jingle.
  static const jingleFadeSeconds = 0.02;

  /// Muestras de una vuelta del bucle.
  int loopSamples(Song song) => song.steps * song.samplesPerStep(sampleRate);

  /// Lo que puede sonar después del final de la partitura (s).
  double tailSeconds(Song song) {
    var tail = 0.0;
    for (final t in song.tracks) {
      final ins = t.instrument;
      var x = t.isDrums ? 1.0 : ins.tail;
      if (ins.echoSteps > 0 && ins.echoGain > 0) {
        x += 3 * ins.echoSteps * song.stepSeconds;
      }
      tail = math.max(tail, x);
    }
    return tail + 0.05;
  }

  /// Mezcla sin normalizar de [cycles] vueltas. Con [fold] (por defecto,
  /// en los bucles) la cola se pliega al principio: el resultado
  /// repetido es idéntico a tocarlo de corrido.
  Float64List mix(Song song, {int cycles = 1, bool? fold}) {
    final folded = fold ?? song.loop;
    final sps = song.samplesPerStep(sampleRate);
    final body = song.steps * sps * cycles;
    final n = body + (tailSeconds(song) * sampleRate).ceil();
    final master = Float64List(folded ? body : n);
    final buf = Float64List(n);
    for (final track in song.tracks) {
      buf.fillRange(0, n, 0);
      _renderTrack(song, track, buf, cycles, sps, cyclic: folded);
      _echo(track.instrument, buf, sps);
      final len = master.length;
      for (var i = 0; i < n; i++) {
        master[i % len] += buf[i] * track.gain;
      }
    }
    return master;
  }

  /// Muestras finales: mezcla normalizada al pico de la pieza; los
  /// jingles sin silencio final y con fundido.
  Float64List samples(Song song) {
    var out = mix(song);
    final max = peakOf(out);
    if (max <= 0) return out;
    if (!song.loop) {
      var end = out.length;
      final floor = max * 1e-4;
      while (end > 0 && out[end - 1].abs() < floor) {
        end--;
      }
      out = Float64List.sublistView(out, 0, end);
      final fade = math.min(end, (jingleFadeSeconds * sampleRate).round());
      for (var i = 0; i < fade; i++) {
        out[end - 1 - i] *= i / fade;
      }
    }
    final k = song.peak / max;
    for (var i = 0; i < out.length; i++) {
      out[i] = (out[i] * k).clamp(-1.0, 1.0);
    }
    return out;
  }

  /// Archivo WAV (PCM 16 bits mono) de la pieza.
  Uint8List renderWav(Song song) =>
      WavSynth(sampleRate: sampleRate).encode(samples(song));

  /// Pico absoluto de [s].
  static double peakOf(Float64List s) {
    var m = 0.0;
    for (final x in s) {
      final a = x.abs();
      if (a > m) m = a;
    }
    return m;
  }

  /// Valor eficaz de [s].
  static double rmsOf(Float64List s) {
    if (s.isEmpty) return 0;
    var sum = 0.0;
    for (final x in s) {
      sum += x * x;
    }
    return math.sqrt(sum / s.length);
  }

  // ------------------------------------------------------------------

  void _renderTrack(Song song, Track track, Float64List buf, int cycles,
      int sps,
      {required bool cyclic}) {
    final events = track.events;
    if (events.isEmpty) return;
    // Inicio (en pasos, relativo a la vuelta) de la nota siguiente de
    // cada evento: la corta (canal monofónico).
    final next = List<int?>.filled(events.length, null);
    for (var j = 0; j < events.length; j++) {
      final s = events[j].start;
      int? found;
      for (var k = j + 1; k < events.length; k++) {
        if (events[k].start > s) {
          found = events[k].start;
          break;
        }
      }
      next[j] = found;
    }
    final ins = track.instrument;
    for (var c = 0; c < cycles; c++) {
      final wraps = cyclic || c < cycles - 1;
      for (var j = 0; j < events.length; j++) {
        final e = events[j];
        final start = (c * song.steps + e.start) * sps;
        if (track.isDrums) {
          _drum(e.drum!, buf, start);
          continue;
        }
        final nx = next[j] ?? (wraps ? events.first.start + song.steps : null);
        _note(buf, start, e.length * sps, nx == null ? null : (nx - e.start) * sps,
            midiToHz(e.midi! + ins.transpose), ins, j);
      }
    }
  }

  /// Una nota de [onN] muestras desde [start]; si la siguiente empieza a
  /// [capN] muestras, se corta ahí con un fundido corto.
  void _note(Float64List out, int start, int onN, int? capN, double freq,
      Instrument ins, int seed) {
    final sr = sampleRate.toDouble();
    final gateN = math.max(1, (onN * ins.gate).round());
    final relN = math.max(1, (ins.release * sr).round());
    final fadeN = math.max(1, (monoFadeSeconds * sr).round());
    var total = gateN + relN;
    int? cutAt;
    if (capN != null && total > capN + fadeN) {
      cutAt = capN;
      total = capN + fadeN;
    }
    final aN = math.max(1.0, ins.attack * sr);
    final dN = math.max(1.0, ins.decay * sr);
    final sus = ins.sustain;
    double env(int i) {
      if (i < aN) return i / aN;
      if (i < aN + dN) return 1 - (1 - sus) * (i - aN) / dN;
      return sus;
    }

    final offLevel = env(gateN);
    final voice = ins.voice;
    final vib = ins.vibratoDepth != 0 && ins.vibratoRate != 0;
    final scoopN = (0.05 * sr).round();
    final lpAlpha =
        ins.lowpass > 0 ? 1 - math.exp(-2 * math.pi * ins.lowpass / sr) : 1.0;
    final breath = ins.breath;
    final breathAlpha = 1 - math.exp(-2 * math.pi * 2500 / sr);
    const noiseClock = 9000.0;
    var lfsr = (0x2a5 + seed * 7919) & 0x7fff;
    if (lfsr == 0) lfsr = 1;
    var noiseAcc = 0.0;
    var noiseLp = 0.0;
    var lp = 0.0;
    var phase = 0.0;
    final n = math.min(total, out.length - start);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      var f = freq;
      if (ins.scoop != 0 && i < scoopN) {
        f *= math.pow(2, -ins.scoop / 12 * (1 - i / scoopN));
      }
      if (vib) {
        final ramp = ((t - ins.vibratoDelay) / 0.2).clamp(0.0, 1.0);
        if (ramp > 0) {
          f *= 1 + ins.vibratoDepth * ramp * math.sin(2 * math.pi * ins.vibratoRate * t);
        }
      }
      final p = phase;
      phase += f / sr;
      final frac = p - p.floorToDouble();
      double w;
      switch (voice) {
        case Voice.square:
          w = frac < 0.5 ? 1 : -1;
        case Voice.pulse25:
          w = (frac < 0.25 ? 2.0 : 0.0) - 0.5;
        case Voice.pulse12:
          w = (frac < 0.125 ? 2.0 : 0.0) - 0.25;
        case Voice.triangle:
          final tri = 1 - 4 * (frac - 0.5).abs();
          w = ((tri + 1) * 7.5).roundToDouble() / 7.5 - 1;
        case Voice.sine:
          w = math.sin(2 * math.pi * p);
        case Voice.ocarina:
          final x = 0.85 * math.sin(2 * math.pi * p) +
              0.15 * math.sin(4 * math.pi * p);
          w = (x * 15).roundToDouble() / 15;
        case Voice.drums:
          w = 0;
      }
      if (lpAlpha < 1) {
        lp += lpAlpha * (w - lp);
        w = lp;
      }
      double e;
      if (i < gateN) {
        e = env(i);
      } else {
        final x = (i - gateN) / relN;
        e = x >= 1 ? 0 : offLevel * (1 - x) * (1 - x);
      }
      final cut = cutAt;
      if (cut != null && i >= cut) e *= (total - i) / fadeN;
      var s = w * e;
      if (breath > 0) {
        noiseAcc += noiseClock / sr;
        while (noiseAcc >= 1) {
          final bit = (lfsr ^ (lfsr >> 1)) & 1;
          lfsr = (lfsr >> 1) | (bit << 14);
          noiseAcc -= 1;
        }
        noiseLp += breathAlpha * (((lfsr & 1) == 1 ? 1.0 : -1.0) - noiseLp);
        final chiff = 2.5 * math.exp(-t / 0.02);
        s += noiseLp * breath * (e + chiff * (e > 0 ? 1 : 0));
      }
      out[start + i] += s * ins.volume;
    }
  }

  void _drum(String d, Float64List out, int start) {
    switch (d) {
      case 'k':
        _tone(out, start, 120, 40, 0.12, 0.55, triangle: true);
        _noise(out, start, 4000, 0.02, 0.12);
      case 's':
        _noise(out, start, 7000, 0.16, 0.26, lowpass: 6000);
        _tone(out, start, 200, 130, 0.06, 0.22, triangle: true);
      case 'h':
        _noise(out, start, 20000, 0.035, 0.07);
      case 'o':
        _noise(out, start, 20000, 0.16, 0.06);
      case 't':
        _tone(out, start, 150, 70, 0.18, 0.38, triangle: true);
      case 'T':
        _tone(out, start, 230, 110, 0.14, 0.34, triangle: true);
      case 'c':
        _noise(out, start, 13000, 0.9, 0.11);
      case 'r':
        _tone(out, start, 2600, 2600, 0.018, 0.09);
        _noise(out, start, 18000, 0.008, 0.04);
      case 'q':
        _tone(out, start, 1100, 1000, 0.04, 0.2, triangle: true);
    }
  }

  /// Tono con barrido exponencial y caída exponencial (1 ms de ataque).
  void _tone(Float64List out, int start, double f0, double f1, double dur,
      double vol,
      {bool triangle = false}) {
    final sr = sampleRate.toDouble();
    final n = math.min((dur * sr).round(), out.length - start);
    final atk = math.max(1.0, 0.001 * sr);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final f = f1 == f0 ? f0 : f0 * math.pow(f1 / f0, t / dur);
      final frac = phase - phase.floorToDouble();
      phase += f / sr;
      final w = triangle ? 1 - 4 * (frac - 0.5).abs() : math.sin(2 * math.pi * frac);
      final e = math.min(1.0, i / atk) * math.exp(-5 * t / dur) * (1 - i / n);
      out[start + i] += w * e * vol;
    }
  }

  /// Ruido LFSR de 15 bits (estilo NES) a [clock] Hz con caída
  /// exponencial.
  void _noise(Float64List out, int start, double clock, double dur, double vol,
      {double lowpass = 0}) {
    final sr = sampleRate.toDouble();
    final n = math.min((dur * sr).round(), out.length - start);
    final atk = math.max(1.0, 0.001 * sr);
    final alpha =
        lowpass > 0 ? 1 - math.exp(-2 * math.pi * lowpass / sr) : 1.0;
    var lfsr = 1;
    var acc = 0.0;
    var lp = 0.0;
    for (var i = 0; i < n; i++) {
      acc += clock / sr;
      while (acc >= 1) {
        final bit = (lfsr ^ (lfsr >> 1)) & 1;
        lfsr = (lfsr >> 1) | (bit << 14);
        acc -= 1;
      }
      var w = (lfsr & 1) == 1 ? 1.0 : -1.0;
      if (alpha < 1) {
        lp += alpha * (w - lp);
        w = lp;
      }
      final t = i / sr;
      final e = math.min(1.0, i / atk) * math.exp(-5 * t / dur) * (1 - i / n);
      out[start + i] += w * e * vol;
    }
  }

  /// Eco de 3 repeticiones (g, g², g³) cada `echoSteps` pasos, sobre la
  /// señal seca (de atrás hacia adelante, en el lugar).
  void _echo(Instrument ins, Float64List buf, int sps) {
    if (ins.echoSteps <= 0 || ins.echoGain <= 0) return;
    final d = ins.echoSteps * sps;
    final g = ins.echoGain;
    for (var i = buf.length - 1; i >= d; i--) {
      var s = g * buf[i - d];
      if (i >= 2 * d) s += g * g * buf[i - 2 * d];
      if (i >= 3 * d) s += g * g * g * buf[i - 3 * d];
      buf[i] += s;
    }
  }
}
