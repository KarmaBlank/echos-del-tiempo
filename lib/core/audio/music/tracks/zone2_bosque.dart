import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Zona 2 · Bosque Hondo.
///
/// Clima: misterioso, neblina entre árboles altos. Ocarina con eco
/// (corchea con punto), notas largas que dejan oír la repetición; el Fa
/// natural (II frigio) sobre Mi menor da la sensación de que algo mira
/// desde la espesura. Arpegio grave y lento, bajo de notas largas,
/// percusión mínima (tom suelto y hi-hats dispersos). Mi menor, 92 bpm,
/// 4/4, 16 compases (≈ 42 s).
Song zone2Bosque() {
  const a = 'Em F Em D C B Em Em';
  const b = 'Am Em F C Am B7 Em Em';
  final chords = ch('$a $b', 16);

  final melody = join([
    // A
    bar('E5:6 G5:2 F#5:4 B4:4'),
    bar('C5:12 A4:4'),
    bar('B4:6 E5:2 G5:4 B5:4'),
    bar('A5:8 F#5:4 D5:4'),
    bar('E5:6 G5:2 E5:4 C5:4'),
    bar('D#5:8 F#5:4 B4:4'),
    bar('E5:12 .:4'),
    bar('.:8 F5:2 E5:2 B4:4'),
    // B
    bar('A4:6 C5:2 E5:8'),
    bar('G5:6 F#5:2 E5:8'),
    bar('F5:6 E5:2 C5:4 A4:4'),
    bar('G4:6 C5:2 E5:8'),
    bar('A5:6 G5:2 E5:4 C5:4'),
    bar('B4:4 D#5:4 F#5:4 A5:4'),
    bar('G5:6 F#5:2 E5:8'),
    bar('B4:12 .:4'),
  ]);

  final drums = join([
    rep(
        join([
          bar('t:4 .:4 .:2 h:2 .:4', drums: true),
          bar('.:6 h:2 .:4 h:2 h:2', drums: true),
        ]),
        7),
    bar('t:4 .:4 T:2 .:2 t:4', drums: true),
    bar('t:4 .:4 t:2 t:2 T:2 t:2', drums: true),
  ]);

  return Song(
    id: 'zone2',
    title: 'Bosque Hondo',
    bpm: 92,
    tracks: [
      Track('ocarina', Inst.ocarinaEcho, melody),
      Track('arpegio', Inst.arp,
          arp(chords, center: 55, count: 3, shape: const [0, 1, 2, 1],
              rhythm: 'x:2'),
          gain: 0.8),
      Track('colchón', Inst.pad, comp(chords, 'x:16', center: 64, count: 2)),
      Track('bajo', Inst.bass, bassLine(chords, 'R:12 5:4')),
      Track.drums('batería', drums, gain: 0.5),
    ],
  );
}
