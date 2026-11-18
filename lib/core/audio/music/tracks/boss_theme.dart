import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Jefe.
///
/// Clima: intenso, peligro grande. Un riff de pulso en semicorcheas que
/// martilla la fundamental, el Mi♭ frigio contra el Re menor y el Si♭
/// sobre La (novena menor) como tensión; bajo con aproximaciones
/// cromáticas, batería a doble bombo. La ocarina (doblada abajo) entra
/// con notas largas amenazantes y después pelea en el registro agudo.
/// Re menor frigio, 168 bpm, 4/4, 32 compases (≈ 46 s): riff 8, A 8, B 8,
/// C 8 (rítmica, vuelve por La).
Song bossTheme() {
  const riff = 'Dm Eb Dm Eb Dm Eb Dm A';
  const a = 'Dm Eb Dm Ebmaj7 Bb C A A7';
  const b = 'Gm Dm Gm A Bb C Dm Dm';
  const c = 'Bb A Gm A7 F C A7b9 A';
  final chords = ch('$riff $a $b $c', 16);

  final melody = join([
    // Riff: notas largas
    bar('A5:16'),
    bar('Bb5:16'),
    bar('A5:8 D6:8'),
    bar('Bb5:8 G5:8'),
    bar('A5:6 F5:2 D5:8'),
    bar('Eb5:6 G5:2 Bb5:8'),
    bar('A5:4 G5:4 F5:4 E5:4'),
    bar('C#5:8 E5:8'),
    // A
    bar('D6:6 C6:2 A5:4 F5:4'),
    bar('G5:6 Bb5:2 Eb6:8'),
    bar('D6:6 C6:2 A5:4 D5:4'),
    bar('Eb5:4 G5:4 Bb5:4 D6:4'),
    bar('D6:8 C6:4 Bb5:4'),
    bar('C6:6 Bb5:2 G5:4 E5:4'),
    bar('A5:6 Bb5:2 A5:4 G5:4'),
    bar('E5:4 C#5:4 A4:8'),
    // B
    bar('G5:6 A5:2 Bb5:4 D6:4'),
    bar('A5:12 F5:4'),
    bar('Bb5:6 C6:2 D6:4 Bb5:4'),
    bar('C#6:8 A5:8'),
    bar('F5:4 Bb5:4 D6:8'),
    bar('E5:4 G5:4 C6:8'),
    bar('D6:12 C6:2 A5:2'),
    bar('D6:16'),
    // C
    bar('F5:3 F5:3 F5:2 D5:8'),
    bar('E5:3 E5:3 E5:2 C#5:8'),
    bar('D5:3 D5:3 D5:2 Bb4:4 D5:4'),
    bar('C#5:3 E5:3 A5:2 G5:4 E5:4'),
    bar('A5:3 A5:3 A5:2 F5:8'),
    bar('G5:3 G5:3 G5:2 E5:4 C6:4'),
    bar('Bb5:4 A5:4 G5:4 E5:4'),
    bar('C#5:4 E5:4 A5:8'),
  ]);

  final beat = bar('k:1 k:1 h:2 s:2 h:1 k:1 k:1 k:1 h:2 s:2 h:2', drums: true);
  final beat2 = bar('k:1 k:1 h:2 s:2 k:1 k:1 k:1 k:1 s:1 k:1 s:2 o:2', drums: true);
  final fill = bar('s:1 s:1 s:1 s:1 T:1 T:1 T:1 T:1 t:1 t:1 t:1 t:1 s:1 s:1 s:1 s:1', drums: true);
  final crash = bar('c+k:1 k:1 h:2 s:2 h:1 k:1 k:1 k:1 h:2 s:2 h:2', drums: true);
  final drums = join([
    crash, beat, beat, beat2, beat, beat, beat2, fill, // riff
    crash, beat, beat2, beat, beat, beat2, beat, fill, // A
    crash, beat, beat2, beat, beat, beat2, beat, fill, // B
    crash, beat, beat2, beat, beat, beat2, beat2, fill, // C
  ]);

  return Song(
    id: 'boss',
    title: 'Jefe',
    bpm: 168,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.36, attack: 0.02), melody),
      Track('doble', Inst.leadDouble.copyWith(volume: 0.06), melody),
      Track('riff', Inst.harmony,
          arp(chords, center: 57, count: 3, shape: const [0, 0, 2, 0, 1, 0, 2, 1])),
      Track('bajo', Inst.bassStaccato, bassLine(chords, 'R:2 R:2 8:2 R:2 b:2 R:2 8:2 5:2')),
      Track.drums('batería', drums, gain: 0.85),
    ],
  );
}
