import 'package:echos_del_tiempo/core/audio/music/instruments.dart';
import 'package:echos_del_tiempo/core/audio/music/music_dsl.dart';
import 'package:echos_del_tiempo/core/audio/music/music_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notas', () {
    test('nombre ↔ MIDI y frecuencia', () {
      expect(noteToMidi('C4'), 60);
      expect(noteToMidi('A4'), 69);
      expect(noteToMidi('F#3'), 54);
      expect(noteToMidi('Bb5'), 82);
      expect(noteToMidi('C-1'), 0);
      expect(noteToMidi('H4'), isNull);
      expect(midiToNote(61), 'C#4');
      expect(midiToHz(69), closeTo(440, 1e-9));
      expect(midiToHz(81), closeTo(880, 1e-9));
      expect(midiToHz(60), closeTo(261.6256, 1e-3));
    });
  });

  group('parseScore', () {
    test('duraciones, silencios y ligas', () {
      final p = parseScore('C4 D4:3 . E4:2 - -:2 .:4 | G4');
      expect(p.steps, 1 + 3 + 1 + 2 + 1 + 2 + 4 + 1);
      expect(p.events, const [
        NoteEvent(0, 1, midi: 60),
        NoteEvent(1, 3, midi: 62),
        NoteEvent(5, 5, midi: 64), // E4:2 + - + -:2
        NoteEvent(14, 1, midi: 67),
      ]);
    });

    test('díadas y golpes de batería', () {
      expect(parseScore('C4+E4:2').events, const [
        NoteEvent(0, 2, midi: 60),
        NoteEvent(0, 2, midi: 64),
      ]);
      final d = parseScore('k+h . s:2 r q', drums: true);
      expect(d.steps, 6);
      expect(d.events.map((e) => (e.start, e.drum)).toList(),
          [(0, 'k'), (0, 'h'), (2, 's'), (4, 'r'), (5, 'q')]);
    });

    test('errores con el token culpable', () {
      expect(() => parseScore('C4 X9'), throwsFormatException);
      expect(() => parseScore('C4:0'), throwsFormatException);
      expect(() => parseScore('- C4'), throwsFormatException);
      expect(() => parseScore('k z', drums: true), throwsFormatException);
      // Bombo legüero y su aro.
      expect(parseScore('b a:2 b+a', drums: true).steps, 4);
    });
  });

  group('Song', () {
    test('tempo: paso, muestras por paso y largo', () {
      final s = Song(id: 'x', title: 'x', bpm: 120, tracks: [
        Track('a', Inst.ocarina, 'C4:16 D4:16'),
      ]);
      expect(s.steps, 32);
      expect(s.bars, 2);
      expect(s.stepSeconds, closeTo(0.125, 1e-12)); // semicorchea a 120
      expect(s.seconds, closeTo(4, 1e-12));
      expect(s.samplesPerStep(22050), 2756); // 2756.25 redondeado

      final waltz = Song(id: 'w', title: 'w', bpm: 132, stepsPerBeat: 2,
          beatsPerBar: 3, tracks: [Track('a', Inst.ocarina, 'G4:6')]);
      expect(waltz.stepsPerBar, 6);
      expect(waltz.seconds, closeTo(3 * 60 / 132, 1e-12));
    });

    test('todas las pistas deben medir lo mismo', () {
      expect(
          () => Song(id: 'x', title: 'x', bpm: 100, tracks: [
                Track('a', Inst.ocarina, 'C4:16'),
                Track('b', Inst.bass, 'C2:15'),
              ]),
          throwsArgumentError);
    });

    test('la firma cambia con cualquier nota o parámetro', () {
      Song make(String melody, {double vol = 0.3}) => Song(
          id: 'x',
          title: 'x',
          bpm: 100,
          tracks: [Track('a', Inst.ocarina.copyWith(volume: vol), melody)]);
      expect(make('C4:4').hash, make('C4:4').hash);
      expect(make('C4:4').hash, isNot(make('D4:4').hash));
      expect(make('C4:4').hash, isNot(make('C4:4', vol: 0.2).hash));
    });
  });

  group('ayudas para componer', () {
    test('acordes cifrados', () {
      expect(Chord.parse('Dm').intervals, [0, 3, 7]);
      expect(Chord.parse('F#m7').root, 6);
      expect(Chord.parse('D/C').bass, 0);
      expect(Chord.parse('Gmaj7').intervals, [0, 4, 7, 11]);
      expect(() => Chord.parse('Cxyz'), throwsFormatException);
      // Las 3 notas de Do mayor más cercanas a Mi4.
      expect(Chord.parse('C').voiced(64, 3), [60, 64, 67]);
      expect(ch('Am F', 8), 'Am:8 F:8');
    });

    test('arpegio, bajo y acordes miden lo que el cifrado', () {
      const chords = 'C:8 G:8';
      final a = arp(chords, center: 64, shape: const [0, 1, 2], rhythm: 'x:2');
      expect(a, 'C4:2 E4:2 G4:2 C4:2 B3:2 D4:2 G4:2 B3:2');
      expect(bassLine(chords, 'R:2 5:2 8:2 .:2'),
          'C2:2 G2:2 C3:2 .:2 G2:2 D3:2 G3:2 .:2');
      expect(comp('C:4', 'x:2 .:2', center: 64, count: 2), 'E4+G4:2 .:2');
      expect(parseScore(arp(chords)).steps, 16);
    });

    test('bar atrapa compases mal contados', () {
      expect(bar('C4:8 D4:8'), 'C4:8 D4:8');
      expect(() => bar('C4:8 D4:7'), throwsArgumentError);
      expect(bar('k:3 h:3', steps: 6, drums: true), 'k:3 h:3');
      expect(rep('C4', 3), 'C4 C4 C4');
    });

    test('shift transporta notas y díadas, deja silencios y ligas', () {
      expect(shift('D5:2 G5 .:4 - C5+E5:3', -12), 'D4:2 G4 .:4 - C4+E4:3');
      expect(shift('B4', 1), 'C5');
      expect(() => shift('X4', 1), throwsFormatException);
    });

    test('el rasgueo solo cambia la firma si se usa', () {
      expect(Inst.ocarina.signature, isNot(contains('strum')));
      expect(Inst.charango.signature, contains('strum'));
      expect(Inst.charango.copyWith(strum: 0).signature,
          isNot(contains('strum')));
    });
  });
}
