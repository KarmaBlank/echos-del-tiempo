import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Mapa del mundo.
///
/// Clima: aventura, ganas de salir a caminar. Marcha con bajo que camina
/// en negras; el Re mayor sobre Do (cuarta aumentada, color lidio) le da
/// el aire de "horizonte abierto". Do mayor, 120 bpm, 4/4, 24 compases
/// (48 s). A (1–8) tema que sube por el acorde; B (9–16) se expande
/// hasta el Do agudo; C (17–24) puente legato a medio tiempo que vuelve.
Song overworldTheme() {
  const a = 'C D/C C D/C Am F G G';
  const b = 'F G Em Am F G C C';
  const c = 'Am Em F C Dm G F G';
  final ab = ch('$a $b', 16);
  final cc = ch(c, 16);

  final melody = join([
    // A
    bar('G4:2 C5:2 E5:2 G5:2 G5:6 E5:2'),
    bar('F#5:4 E5:2 D5:2 A4:8'),
    bar('G4:2 C5:2 E5:2 G5:2 C6:6 B5:2'),
    bar('A5:8 F#5:4 D5:4'),
    bar('E5:6 A5:2 G5:4 E5:4'),
    bar('F5:6 A5:2 G5:4 F5:4'),
    bar('D5:6 E5:2 F5:4 G5:4'),
    bar('G5:12 .:4'),
    // B
    bar('A5:6 G5:2 F5:4 C5:4'),
    bar('B4:6 C5:2 D5:4 G5:4'),
    bar('G5:6 F#5:2 E5:4 B4:4'),
    bar('C5:6 D5:2 E5:8'),
    bar('F5:4 E5:2 F5:2 A5:4 C6:4'),
    bar('B5:6 A5:2 G5:4 D5:4'),
    bar('E5:4 G5:4 C6:4 G5:4'),
    bar('C6:12 .:4'),
    // C (puente)
    bar('E5:8 A4:8'),
    bar('B4:8 E5:8'),
    bar('F5:8 C5:4 A4:4'),
    bar('G4:12 .:4'),
    bar('A4:6 D5:2 F5:8'),
    bar('G5:6 F5:2 D5:8'),
    bar('C5:6 D5:2 E5:4 F5:4'),
    bar('G5:8 F5:4 D5:4'),
  ]);

  final march = bar('k:2 h:2 s:2 h:2 k:2 k:2 s:2 h:2', drums: true);
  final drums = join([
    rep(march, 7),
    bar('k:2 h:2 s:2 h:2 s:2 s:2 T:2 t:2', drums: true),
    rep(march, 7),
    bar('k:2 h:2 s:2 s:2 T:2 T:2 t:2 t:2', drums: true),
    rep(bar('k:4 h:4 s:4 h:4', drums: true), 7),
    bar('k:4 h:4 s:2 s:2 s:2 s:2', drums: true),
  ]);

  return Song(
    id: 'overworld',
    title: 'Mapa del mundo',
    bpm: 120,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('marcha', Inst.harmony,
          '${comp(ab, 'x:2 .:2 x:1 .:1 x:2', center: 64)} '
          '${comp(cc, 'x:8', center: 64)}'),
      Track('arpegio', Inst.arp,
          '${arp(ab, center: 72, count: 4, shape: const [0, 1, 2, 3], rhythm: 'x:2')} '
          '${arp(cc, center: 72, count: 4, shape: const [0, 2, 1, 3], rhythm: 'x:4')}'),
      Track('bajo', Inst.bass,
          '${bassLine(ab, 'R:4 5:4 8:4 5:4')} ${bassLine(cc, 'R:8 5:8')}'),
      Track.drums('batería', drums, gain: 0.6),
    ],
  );
}
