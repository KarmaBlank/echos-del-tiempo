import 'dart:io';
import 'dart:math' as math;

import 'package:echos_del_tiempo/core/audio/music/music_catalog.dart';
import 'package:echos_del_tiempo/core/audio/music/music_renderer.dart';
import 'package:echos_del_tiempo/core/audio/music/music_score.dart';
import 'package:flutter_test/flutter_test.dart';

/// Con `MUSIC_SAMPLES_DIR=<carpeta>` escribe un WAV por pieza e imprime
/// tiempo de render, tamaño, pico y RMS (docs/specs/music.md § 8).
void main() {
  const r = MusicRenderer();

  test('están todas las piezas del repertorio', () {
    expect(kMusicCatalog.keys.toSet(), {
      Music.title,
      Music.town,
      Music.overworld,
      for (final z in Music.zones) Music.zone(z),
      Music.battle,
      Music.boss,
      Music.bossFinal,
      Music.bossAbyss,
      Music.bossSecret,
      Music.victory,
      Music.defeat,
      Music.levelUp,
      Music.zoneUnlocked,
      Music.ascension,
    });
    for (final e in kMusicCatalog.entries) {
      expect(e.value.id, e.key);
    }
  });

  test('bucles de 30–75 s, jingles cortos sin bucle; la ocarina canta', () {
    for (final s in kMusicCatalog.values) {
      if (s.id.startsWith('jingle.')) {
        expect(s.loop, isFalse, reason: s.id);
        expect(s.seconds, inInclusiveRange(1.5, 7), reason: s.id);
      } else {
        expect(s.loop, isTrue, reason: s.id);
        expect(s.seconds, inInclusiveRange(30, 75), reason: s.id);
        expect(s.steps % s.stepsPerBar, 0, reason: '${s.id}: compases enteros');
      }
      expect(s.tracks.first.instrument.voice, Voice.ocarina, reason: s.id);
    }
  });

  test('cada pieza renderiza sin recortar, sin NaN, con costura limpia y '
      'RMS entre −22 y −14 dBFS', () {
    final dir = Platform.environment['MUSIC_SAMPLES_DIR'];
    for (final song in kMusicCatalog.values) {
      final sw = Stopwatch()..start();
      final s = r.samples(song);
      final ms = sw.elapsedMilliseconds;
      var maxStep = 0.0;
      for (var i = 0; i < s.length; i++) {
        expect(s[i].isFinite, isTrue);
        if (i > 0) {
          final d = (s[i] - s[i - 1]).abs();
          if (d > maxStep) maxStep = d;
        }
      }
      final peak = MusicRenderer.peakOf(s);
      expect(peak, closeTo(song.peak, 1e-9), reason: song.id);
      expect(peak, lessThan(1));
      final rmsDb = 20 * math.log(MusicRenderer.rmsOf(s)) / math.ln10;
      expect(rmsDb, inInclusiveRange(-22, -14), reason: '${song.id}: RMS');
      if (song.loop) {
        expect((s.last - s.first).abs(), lessThanOrEqualTo(maxStep),
            reason: '${song.id}: costura');
      } else {
        expect(s.last.abs(), lessThan(1e-6), reason: '${song.id}: fundido');
      }
      if (dir != null) {
        final wav = r.renderWav(song);
        final name = song.id.replaceAll('.', '_');
        File('$dir${Platform.pathSeparator}$name.wav')
          ..createSync(recursive: true)
          ..writeAsBytesSync(wav);
        final rms = MusicRenderer.rmsOf(s);
        // ignore: avoid_print
        print('${song.id.padRight(20)} ${song.title.padRight(18)} '
            '${(s.length / r.sampleRate).toStringAsFixed(1).padLeft(5)} s  '
            'render ${ms.toString().padLeft(4)} ms  '
            '${(wav.length / 1024).round().toString().padLeft(5)} KB  '
            'pico ${peak.toStringAsFixed(3)} (${_db(peak)} dBFS)  '
            'rms ${rms.toStringAsFixed(3)} (${_db(rms)} dBFS)');
      }
    }
  });
}

String _db(double x) => (20 * math.log(x) / math.ln10).toStringAsFixed(1);
