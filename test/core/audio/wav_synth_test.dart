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
    for (final sfx in Sfx.values) {
      final wav = service.wav(sfx);
      expect(wav.length, greaterThan(WavSynth.headerBytes), reason: '$sfx');
      expect(identical(service.wav(sfx), wav), isTrue);
    }
    // ULT: dura hasta el impacto (1.15 s) + 0.6 s.
    final ult = service.wav(Sfx.ultimate);
    expect(ult.length,
        WavSynth.headerBytes + ((kUltImpactDelay + 0.6) * 22050).ceil() * 2);
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
