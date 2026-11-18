import 'dart:typed_data';

import 'package:echos_del_tiempo/core/audio/music/music_renderer.dart';
import 'package:echos_del_tiempo/core/audio/music/music_score.dart';
import 'package:echos_del_tiempo/core/audio/music/tracks/overworld_theme.dart';
import 'package:echos_del_tiempo/core/audio/music/tracks/title_theme.dart';
import 'package:echos_del_tiempo/core/audio/music/tracks/zone2_bosque.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seno limpio: ataque y release cortos, sin decaimiento.
const _probe = Instrument(
  voice: Voice.sine,
  volume: 0.5,
  attack: 0.001,
  decay: 0.001,
  sustain: 1,
  release: 0.005,
);

Song _song(String score,
        {double bpm = 120,
        Instrument ins = _probe,
        bool loop = false,
        List<Track> extra = const []}) =>
    Song(id: 't', title: 't', bpm: bpm, loop: loop, tracks: [
      Track('a', ins, score),
      ...extra,
    ]);

/// Primera y última muestra con |x| > [eps].
(int, int) _span(Float64List s, {double eps = 1e-3}) {
  var first = -1, last = -1;
  for (var i = 0; i < s.length; i++) {
    if (s[i].abs() > eps) {
      if (first < 0) first = i;
      last = i;
    }
  }
  return (first, last);
}

void main() {
  const r = MusicRenderer();
  const sr = 22050;

  group('secuenciador: tiempos', () {
    test('una nota empieza en su paso y dura sus pasos + el release', () {
      final song = _song('.:4 A4:8 .:4');
      final sps = song.samplesPerStep(sr);
      final s = r.mix(song, fold: false);
      final (first, last) = _span(s);
      expect(first, inInclusiveRange(4 * sps, 4 * sps + 30));
      final relN = (_probe.release * sr).round();
      expect(last, inInclusiveRange(12 * sps, 12 * sps + relN));
    });

    test('el tempo fija dónde cae cada paso', () {
      for (final bpm in [60.0, 120.0, 150.0]) {
        final song = _song('.:6 C5:2', bpm: bpm);
        final sps = song.samplesPerStep(sr);
        expect(sps, (60 / bpm / 4 * sr).round());
        final (first, _) = _span(r.mix(song, fold: false));
        expect(first, inInclusiveRange(6 * sps, 6 * sps + 30),
            reason: '$bpm bpm');
      }
    });

    test('la altura es la de la nota (cruces por cero de A4 = 440 Hz)', () {
      final song = _song('A4:32', bpm: 60); // 2 s
      final s = r.mix(song, fold: false);
      var crossings = 0;
      for (var i = sr ~/ 2 + 1; i < sr ~/ 2 + sr; i++) {
        if ((s[i - 1] < 0) != (s[i] < 0)) crossings++;
      }
      expect(crossings, inInclusiveRange(878, 882)); // 2 × 440 en 1 s
    });

    test('canal monofónico: la nota siguiente corta el release', () {
      final longRelease = _probe.copyWith(release: 0.6);
      final both = r.mix(_song('A4:4 E5:4 .:8', ins: longRelease), fold: false);
      final alone = r.mix(_song('.:4 E5:4 .:8', ins: longRelease), fold: false);
      final sps = _song('A4:4').samplesPerStep(sr);
      final fade = (MusicRenderer.monoFadeSeconds * sr).round();
      for (var i = 4 * sps + fade + 1; i < both.length; i++) {
        expect(both[i], closeTo(alone[i], 1e-12), reason: 'muestra $i');
      }
    });
  });

  group('rasgueo', () {
    test('las notas de un golpe entran escalonadas, alternando el sentido',
        () {
      final strum = _probe.copyWith(strum: 0.01);
      final song = _song('C5+E5+G5:8 C5+E5+G5:8', ins: strum);
      final sps = song.samplesPerStep(sr);
      final off = (0.01 * sr).round();
      // Bajada: Do primero, Mi a +off, Sol a +2·off.
      final down = r.mix(_song('C5:8 .:8', ins: strum), fold: false);
      final s = r.mix(song, fold: false);
      for (var i = 0; i < off; i++) {
        expect(s[i], closeTo(down[i], 1e-12), reason: 'muestra $i');
      }
      // Subida: Sol primero (el Mi entra a +off); el golpe anterior se
      // apaga en el fundido monofónico.
      final up = r.mix(_song('.:8 G5:8', ins: strum), fold: false);
      final fade = (MusicRenderer.monoFadeSeconds * sr).round();
      for (var i = 8 * sps + fade + 1; i < 8 * sps + off; i++) {
        expect(s[i], closeTo(up[i], 1e-12), reason: 'muestra $i');
      }
    });

    test('bombo y aro suenan y no recortan', () {
      final s = r.mix(Song(id: 'd', title: 'd', bpm: 100, loop: false,
          tracks: [Track.drums('d', 'b:4 a:4 b+a:8')]), fold: false);
      expect(MusicRenderer.peakOf(s), inExclusiveRange(0.1, 1));
    });
  });

  group('bucles', () {
    test('la costura es exacta: el bucle plegado = la 2.ª vuelta de corrido',
        () {
      // Release largo y eco que cruzan el final del bucle.
      final echo = _probe.copyWith(release: 0.4, echoSteps: 3, echoGain: 0.5);
      for (final song in [
        _song('C5:4 E5:4 G5:6 B5:2', ins: echo, loop: true, extra: [
          Track.drums('d', 'k:4 s:4 k:4 c:4'),
        ]),
        titleTheme(),
        overworldTheme(), // charango rasgueado y zampoña con eco
        zone2Bosque(), // ocarina con eco
      ]) {
        final loop = r.mix(song);
        final twice = r.mix(song, cycles: 2, fold: false);
        final n = r.loopSamples(song);
        expect(loop.length, n);
        var maxDiff = 0.0;
        for (var i = 0; i < n; i++) {
          final d = (loop[i] - twice[n + i]).abs();
          if (d > maxDiff) maxDiff = d;
        }
        expect(maxDiff, lessThan(1e-9), reason: song.id);
      }
    });

    test('la costura no salta: |s[fin] − s[0]| no supera el salto normal',
        () {
      final song = titleTheme();
      final s = r.samples(song);
      var maxStep = 0.0;
      for (var i = 1; i < s.length; i++) {
        final d = (s[i] - s[i - 1]).abs();
        if (d > maxStep) maxStep = d;
      }
      expect((s.last - s.first).abs(), lessThanOrEqualTo(maxStep));
    });
  });

  group('render', () {
    test('determinista: dos renders dan los mismos bytes', () {
      final a = r.renderWav(titleTheme());
      final b = r.renderWav(titleTheme());
      expect(a, b);
    });

    test('normaliza al pico de la pieza sin recortar', () {
      final song = titleTheme();
      final s = r.samples(song);
      expect(MusicRenderer.peakOf(s), closeTo(song.peak, 1e-9));
      expect(s.length, r.loopSamples(song));
    });

    test('un jingle termina con fundido y sin silencio de cola', () {
      final song = _song('C5:4 E5:4 G5:8');
      final s = r.samples(song);
      expect(s.last.abs(), lessThan(1e-6));
      expect(s.length, greaterThanOrEqualTo(16 * song.samplesPerStep(sr)));
      expect(s.length,
          lessThan(16 * song.samplesPerStep(sr) + (0.1 * sr).round()));
    });

    test('cabecera WAV: mono, 22050 Hz, 16 bits', () {
      final wav = r.renderWav(_song('C5:4'));
      final b = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(b.getUint16(22, Endian.little), 1);
      expect(b.getUint32(24, Endian.little), sr);
      expect(b.getUint16(34, Endian.little), 16);
    });
  });
}
