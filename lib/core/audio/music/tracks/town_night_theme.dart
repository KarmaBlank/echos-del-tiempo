import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Pueblo de noche (docs/specs/music.md § 5.3, v0.27.0).
///
/// La armonía del pueblo ([townTheme]) en la calma de la pesca, más
/// suave y más lenta: 72 bpm, la ocarina suave con la melodía raleada
/// (notas largas, respiraciones), un colchón bajo y un bajo punteado
/// apenas en el 1 cada dos compases. Sin batería ni campanitas. 24
/// compases de 3/4 (≈ 60 s); el último queda en silencio de melodía para
/// cerrar el bucle sin costura sobre Sol.
Song townNightTheme() {
  const p1 = 'G C G D G C Am D';
  const p2 = 'Em C G D Em C Am D';
  const p3 = 'G C G Em C D G G';
  final chords = ch('$p1 $p2 $p3', 6);

  String b(String s) => bar(s, steps: 6);
  final melody = join([
    // Frase 1: la del pueblo, con las notas de paso afuera.
    b('D5:6'), b('C5:2 E5:4'), b('B4:6'), b('A4:4 .:2'),
    b('D5:4 B4:2'), b('E5:6'), b('C5:2 A4:4'), b('D5:4 .:2'),
    // Frase 2: más abajo, como de lejos.
    b('G4:4 B4:2'), b('E4:6'), b('D4:2 G4:4'), b('A4:6'),
    b('B4:4 G4:2'), b('E4:6'), b('C4:2 E4:4'), b('A4:4 .:2'),
    // Frase 3: vuelve arriba y se apaga.
    b('B4:2 D5:4'), b('E5:6'), b('D5:4 B4:2'), b('G4:6'),
    b('A4:4 E4:2'), b('F#4:6'), b('G4:6'), b('.:6'),
  ]);

  return Song(
    id: 'townNight',
    title: 'Pueblo (noche)',
    bpm: 72,
    stepsPerBeat: 2,
    beatsPerBar: 3,
    tracks: [
      Track('ocarina', Inst.ocarinaSoft, melody, gain: 0.85),
      Track('colchón', Inst.pad, comp(chords, 'x:6', center: 60), gain: 0.55),
      Track('bajo', Inst.bassPluck, bassLine(chords, 'R:2 .:4'), gain: 0.6),
    ],
  );
}
