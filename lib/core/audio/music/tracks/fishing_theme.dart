import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Pueblo, pescando (docs/specs/music.md § 5.2).
///
/// La misma melodía y armonía del pueblo ([townTheme]) pero muy calma:
/// 84 bpm en vez de 132, la ocarina suave sola al frente, un colchón
/// largo que sostiene cada acorde y un bajo punteado apenas audible en
/// el 1. Sin batería ni campanitas. 24 compases de 3/4 (≈ 51 s); el
/// último compás queda en silencio de melodía, así el bucle cierra sin
/// costura sobre Sol.
Song fishingTheme() {
  const p1 = 'G C G D G C Am D';
  const p2 = 'Em C G D Em C Am D';
  const p3 = 'G C G Em C D G G';
  final chords = ch('$p1 $p2 $p3', 6);

  String b(String s) => bar(s, steps: 6);
  final melody = join([
    // Frase 1
    b('D5:4 B4:2'), b('C5:2 E5:2 G5:2'), b('B4:4 D5:2'), b('A4:6'),
    b('D5:4 B4:2'), b('E5:2 G5:2 E5:2'), b('C5:2 B4:2 A4:2'), b('D5:6'),
    // Frase 2
    b('G5:4 F#5:2'), b('E5:4 C5:2'), b('D5:2 B4:2 A4:2'), b('A4:4 D5:2'),
    b('B4:4 E5:2'), b('G5:4 E5:2'), b('E5:2 D5:2 C5:2'), b('A4:6'),
    // Frase 3
    b('B4:2 D5:2 G5:2'), b('G5:4 E5:2'), b('D5:4 B4:2'), b('B4:2 E5:2 G5:2'),
    b('A5:2 G5:2 E5:2'), b('F#5:4 D5:2'), b('G5:6'), b('.:6'),
  ]);

  return Song(
    id: 'fishing',
    title: 'Pueblo (pesca)',
    bpm: 84,
    stepsPerBeat: 2,
    beatsPerBar: 3,
    tracks: [
      Track('ocarina', Inst.ocarinaSoft, melody),
      Track('colchón', Inst.pad, comp(chords, 'x:6', center: 64), gain: 0.7),
      Track('bajo', Inst.bassPluck, bassLine(chords, 'R:2 .:4')),
    ],
  );
}
