import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Zona 5 · Fortaleza Caída.
///
/// Clima: sombrío y marcial, un ejército que ya no está pero sigue
/// marchando. Redobles de caja, bombo en 1 y 3, bajo de corcheas
/// insistentes y "metales" de pulso en golpes cortos; la ocarina toca
/// una melodía digna en ritmos con punto. Do menor (La♭ y Si♭ de la
/// escala natural, Sol mayor de dominante), 96 bpm, 4/4, 16 compases
/// (40 s).
Song zone5Fortaleza() {
  const a = 'Cm Ab Fm G Cm Ab Bb G';
  const b = 'Ab Eb Fm Cm Ab Bb G7 G';
  final chords = ch('$a $b', 16);

  final melody = join([
    // A
    bar('C5:6 C5:2 Eb5:4 G5:4'),
    bar('Ab5:8 G5:4 Eb5:4'),
    bar('F5:6 Eb5:2 C5:4 Ab4:4'),
    bar('G4:8 B4:4 D5:4'),
    bar('C5:6 C5:2 Eb5:4 G5:4'),
    bar('C6:8 Bb5:4 Ab5:4'),
    bar('Bb5:6 Ab5:2 F5:4 D5:4'),
    bar('G5:12 .:4'),
    // B
    bar('Eb5:6 F5:2 Ab5:8'),
    bar('G5:6 F5:2 Eb5:8'),
    bar('F5:4 Ab5:4 C6:6 Bb5:2'),
    bar('G5:12 .:4'),
    bar('Ab5:6 G5:2 F5:4 Eb5:4'),
    bar('D5:6 Eb5:2 F5:4 Bb4:4'),
    bar('B4:6 C5:2 D5:4 F5:4'),
    bar('D5:8 B4:4 G4:4'),
  ]);

  final march = bar('k:4 s:2 s:1 s:1 k:4 s:4', drums: true);
  final roll = bar('k:4 s:2 s:1 s:1 k:2 s:1 s:1 s:1 s:1 s:1 s:1', drums: true);
  final drums = join([
    rep(march, 3), roll, rep(march, 3), roll,
    rep(march, 3), roll, rep(march, 2),
    bar('k:2 s:1 s:1 s:1 s:1 s:1 s:1 t:2 t:2 T:2 T:2', drums: true),
    bar('c+k:4 s:1 s:1 s:1 s:1 s:1 s:1 s:1 s:1 s:1 s:1 s:1 s:1', drums: true),
  ]);

  return Song(
    id: 'zone5',
    title: 'Fortaleza Caída',
    bpm: 96,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('metales', Inst.brass,
          comp(chords, 'x:2 .:1 x:1 .:4 x:2 .:1 x:1 .:4', center: 62, count: 3)),
      Track('bajo', Inst.bassStaccato, bassLine(chords, 'R:2 R:2 R:2 5:2 R:2 R:2 L:2 5:2')),
      Track.drums('tambores', drums, gain: 0.55),
    ],
  );
}
