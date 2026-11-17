import 'dart:math' as math;
import 'dart:typed_data';

import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/core/audio/wav_synth.dart';
import 'package:flutter_test/flutter_test.dart';

String _ascii(Uint8List b, int at, int n) =>
    String.fromCharCodes(b.sublist(at, at + n));

void main() {
  const synth = WavSynth(sampleRate: 22050);

  test('cabecera RIFF/WAVE PCM 16 bits mono', () {
    final wav = synth.render(const [SfxTone(440, 0.1)]);
    final b = ByteData.sublistView(wav);
    expect(_ascii(wav, 0, 4), 'RIFF');
    expect(_ascii(wav, 8, 4), 'WAVE');
    expect(_ascii(wav, 12, 4), 'fmt ');
    expect(b.getUint16(20, Endian.little), 1); // PCM
    expect(b.getUint16(22, Endian.little), 1); // mono
    expect(b.getUint32(24, Endian.little), 22050);
    expect(b.getUint32(28, Endian.little), 44100);
    expect(b.getUint16(32, Endian.little), 2);
    expect(b.getUint16(34, Endian.little), 16);
    expect(_ascii(wav, 36, 4), 'data');
    final samples = (0.1 * 22050).ceil();
    expect(b.getUint32(40, Endian.little), samples * 2);
    expect(b.getUint32(4, Endian.little), 36 + samples * 2);
    expect(wav.length, WavSynth.headerBytes + samples * 2);
  });

  test('onda cuadrada: amplitud = volumen y decae exponencialmente', () {
    final s = synth.samples(const [SfxTone(100, 0.5, volume: 0.05)]);
    expect(s.first, closeTo(0.05, 1e-9));
    // La ganancia en t es vol × (0.0001/vol)^(t/d) (rampa exponencial).
    final mid = s.length ~/ 2 + 7; // dentro de un semiciclo
    final t = mid / 22050;
    final expected = 0.05 * math.pow(0.0001 / 0.05, t / 0.5);
    expect(s[mid].abs(), closeTo(expected, 1e-9));
    expect(s.last.abs(), lessThan(0.0002));
  });

  test('frecuencia: cruces por cero de una cuadrada de 441 Hz', () {
    final s = synth.samples(const [SfxTone(441, 1.0)]);
    var flips = 0;
    for (var i = 1; i < s.length; i++) {
      if ((s[i] > 0) != (s[i - 1] > 0)) flips++;
    }
    // Dos cambios de signo por ciclo.
    expect(flips, inInclusiveRange(880, 884));
  });

  test('retraso: un tono desplazado empieza en su muestra y se mezcla', () {
    final s = synth.samples(const [
      SfxTone(523, 0.08),
      SfxTone(784, 0.12, delay: 0.09),
    ]);
    expect(s.length, (0.21 * 22050).ceil());
    final gapStart = (0.08 * 22050).round() + 2;
    final gapEnd = (0.09 * 22050).round() - 2;
    for (var i = gapStart; i < gapEnd; i++) {
      expect(s[i], 0);
    }
    expect(s[(0.09 * 22050).round()].abs(), closeTo(0.05, 1e-9));
  });

  test('las muestras en PCM son round(x × 32767)', () {
    final wav = synth.render(const [SfxTone(100, 0.01, volume: 1)]);
    final b = ByteData.sublistView(wav);
    expect(b.getInt16(WavSynth.headerBytes, Endian.little), 32767);
  });

  test('sawtooth y triangle quedan en [-vol, vol]', () {
    for (final w in [Waveform.sawtooth, Waveform.triangle, Waveform.sine]) {
      final s = synth.samples([SfxTone(300, 0.05, wave: w, volume: 0.07)]);
      expect(s.every((x) => x.abs() <= 0.07 + 1e-9), isTrue, reason: '$w');
      expect(s.any((x) => x.abs() > 0.05), isTrue, reason: '$w');
    }
  });

  test('todo el catálogo se sintetiza y SfxService lo cachea', () {
    final service = SfxService(synth: synth);
    for (final sfx in kSfxCatalog.keys) {
      final wav = service.wav(sfx);
      expect(wav.length, greaterThan(WavSynth.headerBytes), reason: sfx);
      expect(identical(service.wav(sfx), wav), isTrue);
    }
    expect(service.wav('no.existe').length, WavSynth.headerBytes);
    // ULT: dura hasta el impacto (1.15 s) + 0.6 s.
    final ult = service.wav(Sfx.ultimate);
    expect(ult.length,
        WavSynth.headerBytes + ((kUltImpactDelay + 0.6) * 22050).ceil() * 2);
  });

  group('primitivas', () {
    double peak(List<double> s) =>
        s.fold<double>(0, (m, x) => math.max(m, x.abs()));
    int crossings(List<double> s, int from, int to) {
      var n = 0;
      for (var i = from + 1; i < to; i++) {
        if ((s[i] > 0) != (s[i - 1] > 0)) n++;
      }
      return n;
    }

    test('ruido: determinista, en [-vol, vol], cambia con la semilla', () {
      const tone = SfxTone(8000, 0.2, wave: Waveform.noise, volume: 0.5);
      final a = synth.samples(const [tone]);
      final b = synth.samples(const [tone]);
      expect(a, b);
      expect(a.length, (0.2 * 22050).ceil());
      expect(peak(a), lessThanOrEqualTo(0.5 + 1e-9));
      // No es un tono: muchos cambios de signo sin período fijo.
      expect(crossings(a, 0, 2000), greaterThan(200));
      final c = synth.samples(const [
        SfxTone(8000, 0.2, wave: Waveform.noise, volume: 0.5, seed: 77),
      ]);
      expect(c, isNot(equals(a)));
    });

    test('ruido: el reloj más bajo da menos cambios de signo', () {
      final hi = synth.samples(const [
        SfxTone(10000, 0.2, wave: Waveform.noise, volume: 0.5),
      ]);
      final lo = synth.samples(const [
        SfxTone(1000, 0.2, wave: Waveform.noise, volume: 0.5),
      ]);
      expect(crossings(lo, 0, 2000), lessThan(crossings(hi, 0, 2000) ~/ 3));
    });

    test('lowpass suaviza el ruido (menos energía de alta frecuencia)', () {
      double diffEnergy(List<double> s) {
        var e = 0.0;
        for (var i = 1; i < s.length; i++) {
          e += (s[i] - s[i - 1]) * (s[i] - s[i - 1]);
        }
        return e;
      }

      final raw = synth.samples(const [
        SfxTone(9000, 0.2, wave: Waveform.noise, volume: 0.5, hold: 0.2),
      ]);
      final soft = synth.samples(const [
        SfxTone(9000, 0.2,
            wave: Waveform.noise, volume: 0.5, hold: 0.2, lowpass: 500),
      ]);
      expect(diffEnergy(soft), lessThan(diffEnergy(raw) / 10));
    });

    test('barrido: sube (más cruces al final) y baja (menos)', () {
      final up = synth.samples(const [
        SfxTone(200, 1, endFrequency: 800, hold: 1, volume: 0.5),
      ]);
      final down = synth.samples(const [
        SfxTone(800, 1, endFrequency: 200, hold: 1, volume: 0.5),
      ]);
      final q = up.length ~/ 10;
      expect(crossings(up, up.length - q, up.length),
          greaterThan(crossings(up, 0, q) * 3));
      expect(crossings(down, 0, q),
          greaterThan(crossings(down, down.length - q, down.length) * 3));
    });

    test('envolvente: ataque lineal desde 0, meseta y caída', () {
      final s = synth.samples(const [
        SfxTone(100, 0.5,
            wave: Waveform.square, volume: 0.4, attack: 0.1, hold: 0.1),
      ]);
      expect(s.first, 0);
      // A mitad del ataque, la mitad del volumen.
      expect(s[(0.05 * 22050).round()].abs(), closeTo(0.2, 0.01));
      // En la meseta, volumen pleno.
      expect(s[(0.15 * 22050).round()].abs(), closeTo(0.4, 1e-9));
      expect(s.last.abs(), lessThan(0.001));
    });

    test('vibrato: queda en [-vol, vol] y cambia la onda', () {
      const base = SfxTone(500, 0.3, wave: Waveform.sine, volume: 0.3);
      const vib = SfxTone(500, 0.3,
          wave: Waveform.sine, volume: 0.3, vibratoRate: 8, vibratoDepth: 0.1);
      final a = synth.samples(const [base]);
      final b = synth.samples(const [vib]);
      expect(peak(b), lessThanOrEqualTo(0.3 + 1e-9));
      expect(b, isNot(equals(a)));
    });

    test('crush: cuantiza a 2^(bits-1) niveles por voz', () {
      final s = synth.samples(const [
        SfxTone(300, 0.3, wave: Waveform.sine, volume: 1, crush: 3),
      ]);
      final levels = {for (final x in s) (x * 4).round()};
      for (final x in s) {
        expect((x * 4 - (x * 4).round()).abs(), lessThan(1e-9));
      }
      expect(levels.length, lessThanOrEqualTo(9));
    });

    test('pulse 25 %: un cuarto del ciclo arriba', () {
      final s = synth.samples(const [
        SfxTone(100, 0.1, wave: Waveform.pulse, volume: 0.5, hold: 0.1),
      ]);
      final up = s.where((x) => x > 0).length;
      expect(up / s.length, closeTo(0.25, 0.02));
    });

    test('capas: se suman sin recortar en mix y la normalización fija '
        'el pico', () {
      const loud = [
        SfxTone(200, 0.2, volume: 0.9, hold: 0.2),
        SfxTone(200, 0.2, volume: 0.9, hold: 0.2),
      ];
      expect(peak(synth.mix(loud)), closeTo(1.8, 1e-9));
      expect(peak(synth.samples(loud)), 1.0); // recorte duro (prototipo)
      final n = synth.samplesOf(const SfxDef(loud, peak: 0.4));
      expect(peak(n), closeTo(0.4, 1e-9));
    });
  });

  test('SfxService manda los bytes al reproductor (y no si está muteado)',
      () async {
    final player = _RecordingPlayer();
    final service = SfxService(player: player, synth: synth);
    service.play(Sfx.heal);
    service.muted = true;
    service.play(Sfx.hit);
    await Future<void>.delayed(Duration.zero);
    expect(player.played, [service.wav(Sfx.heal)]);
  });
}

class _RecordingPlayer implements SfxPlayer {
  final played = <Uint8List>[];

  @override
  Future<void> play(Uint8List wav) async => played.add(wav);
}
