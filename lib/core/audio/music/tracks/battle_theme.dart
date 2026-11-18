import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Batalla.
///
/// Clima: enérgico, empuja hacia adelante. Bajo de triángulo en
/// corcheas con saltos de octava, arpegio de pulso en semicorcheas,
/// batería con contratiempo; la ocarina (doblada una octava abajo por una
/// cuadrada suave para que corte) abre con un motivo de tres golpes y
/// después canta frases largas. Mi menor (Si mayor de dominante), 152
/// bpm, 4/4, 32 compases (≈ 51 s): intro 4, A 8, B 8, C 8, vuelta 4.
Song battleTheme() {
  const intro = 'Em Em C D';
  const a = 'Em C D B Em C Am B';
  const b = 'C D Em Em C D B B7';
  const c = 'Am Em Am B C D Em B';
  const turn = 'Em C D B';
  final chords = ch('$intro $a $b $c $turn', 16);

  final melody = join([
    // Intro
    bar('E5:3 E5:3 E5:2 G5:4 F#5:4'),
    bar('E5:3 E5:3 E5:2 B5:4 A5:4'),
    bar('G5:3 G5:3 G5:2 E5:4 G5:4'),
    bar('F#5:3 F#5:3 F#5:2 A5:4 D6:4'),
    // A
    bar('B5:6 A5:2 G5:4 E5:4'),
    bar('G5:6 F#5:2 E5:4 C5:4'),
    bar('D5:6 E5:2 F#5:4 A5:4'),
    bar('B5:12 A5:2 F#5:2'),
    bar('E6:6 D6:2 B5:4 G5:4'),
    bar('C6:6 B5:2 G5:4 E5:4'),
    bar('A5:4 C6:4 B5:4 A5:4'),
    bar('F#5:8 D#5:8'),
    // B
    bar('E5:2 G5:2 C6:4 B5:4 G5:4'),
    bar('F#5:2 A5:2 D6:4 C6:4 A5:4'),
    bar('B5:6 G5:2 E5:8'),
    bar('.:8 E5:2 F#5:2 G5:2 A5:2'),
    bar('G5:6 E5:2 C6:8'),
    bar('A5:6 F#5:2 D6:8'),
    bar('D#6:8 B5:4 F#5:4'),
    bar('A5:4 B5:4 C6:4 D#6:4'),
    // C
    bar('A4:3 C5:3 E5:2 A5:8'),
    bar('G5:3 F#5:3 E5:2 B4:8'),
    bar('A4:3 C5:3 E5:2 A5:4 C6:4'),
    bar('B5:8 F#5:8'),
    bar('G5:3 E5:3 C5:2 E5:4 G5:4'),
    bar('A5:3 F#5:3 D5:2 F#5:4 A5:4'),
    bar('B5:6 C6:2 B5:4 G5:4'),
    bar('F#5:16'),
    // Vuelta (el riff respira)
    bar('.:16'),
    bar('.:16'),
    bar('.:8 D5:2 E5:2 F#5:2 A5:2'),
    bar('B5:8 D#5:4 F#5:4'),
  ]);

  final beat = bar('k:2 h:2 s:2 h:1 k:1 k:2 h:2 s:2 h:2', drums: true);
  final beat2 = bar('k:2 h:2 s:2 h:1 k:1 k:1 k:1 h:2 s:2 o:2', drums: true);
  final fill = bar('k:2 s:1 s:1 s:2 s:1 s:1 T:2 T:2 t:2 t:2', drums: true);
  final crash = bar('c+k:2 h:2 s:2 h:1 k:1 k:2 h:2 s:2 h:2', drums: true);
  final drums = join([
    rep(beat, 3), fill, // intro
    crash, beat, beat2, beat, beat, beat2, beat, fill, // A
    crash, beat, beat2, beat, beat, beat2, beat, fill, // B
    crash, beat, beat2, beat, beat, beat2, beat, fill, // C
    beat, beat2, beat, fill, // vuelta
  ]);

  return Song(
    id: 'battle',
    title: 'Batalla',
    bpm: 152,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.36, attack: 0.02), melody),
      Track('doble', Inst.leadDouble, melody),
      Track('arpegio', Inst.arp,
          arp(chords, center: 64, count: 3, shape: const [0, 1, 2, 1])),
      Track('bajo', Inst.bassStaccato,
          bassLine(chords, 'R:2 R:2 8:2 R:2 5:2 R:2 8:2 5:2')),
      Track.drums('batería', drums, gain: 0.8),
    ],
  );
}
