import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Pueblo.
///
/// Clima: cálido y tranquilo, un vals de plaza: bajo en el 1, acordes de
/// pulso en el 2 y el 3, la ocarina canta frases de cuatro compases. Sol
/// mayor, 132 bpm (negra), 3/4, 24 compases (≈ 33 s). Tres frases de 8:
/// la segunda se oscurece por Mi menor, la tercera sube y cierra en Sol.
Song townTheme() {
  const p1 = 'G C G D G C Am D';
  const p2 = 'Em C G D Em C Am D';
  const p3 = 'G C G Em C D G G';
  final chords = ch('$p1 $p2 $p3', 6);

  String b(String s) => bar(s, steps: 6);
  final melody = join([
    // Frase 1
    b('D5:4 B4:2'), b('C5:2 E5:2 G5:2'), b('B4:4 G4:2'), b('A4:6'),
    b('D5:4 B4:2'), b('E5:2 G5:2 E5:2'), b('C5:2 B4:2 A4:2'), b('D5:6'),
    // Frase 2
    b('G5:4 F#5:2'), b('E5:4 C5:2'), b('D5:2 B4:2 G4:2'), b('A4:4 D5:2'),
    b('B4:4 E5:2'), b('G5:4 E5:2'), b('E5:2 D5:2 C5:2'), b('A4:6'),
    // Frase 3
    b('B4:2 D5:2 G5:2'), b('G5:4 E5:2'), b('D5:4 B4:2'), b('B4:2 E5:2 G5:2'),
    b('A5:2 G5:2 E5:2'), b('F#5:4 D5:2'), b('G5:6'), b('.:6'),
  ]);

  // Vals: el bajo en el 1, los acordes en el 2 y el 3.
  final drums = rep(bar('k:2 h:2 h:2', steps: 6, drums: true), 24);

  return Song(
    id: 'town',
    title: 'Pueblo',
    bpm: 132,
    stepsPerBeat: 2,
    beatsPerBar: 3,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('acordes', Inst.harmony, comp(chords, '.:2 x:2 x:2', center: 67)),
      Track('campanitas', Inst.chime,
          arp(chords, center: 79, count: 3, shape: const [2, 1, 0],
              rhythm: '.:4 x:1 .:1'),
          gain: 0.6),
      Track('bajo', Inst.bass, bassLine(chords, 'R:2 .:4')),
      Track.drums('batería', drums, gain: 0.35),
    ],
  );
}
