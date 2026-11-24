import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Jefe del Abismo (v0.8, docs/specs/abyss_bosses.md § 4; music.md § 4).
///
/// Clima: el tema de jefe llevado al vacío. Mi menor frigio (el Fa
/// natural contra el Mi) con un tritono (Si♭) como color del Abismo; el
/// riff de pulso en semicorcheas pasa a 3+3+2 (cojea, como el tiempo
/// roto), el bajo cae por cromatismos y la ocarina entra con notas largas
/// en el agudo y después pelea en corcheas.
/// Mi menor frigio, 172 bpm, 4/4, 32 compases (≈ 45 s): riff 8, A 8,
/// B 8 (sube un tono, más tenso), C 8 (vuelve por Si 7).
///
/// Original.
Song abyssBossTheme() {
  const riff = 'Em F Em F Em Bb Em B';
  const a = 'Em F Em Fmaj7 C D B B7';
  const b = 'F#m G F#m G Am Bb B B';
  const c = 'C B Am B7 G D B7b9 B';
  final chords = ch('$riff $a $b $c', 16);

  final melody = join([
    // Riff: notas largas en el agudo
    bar('B5:16'),
    bar('C6:16'),
    bar('B5:8 E6:8'),
    bar('F6:8 E6:8'),
    bar('B5:6 G5:2 E5:8'),
    bar('Bb5:6 A5:2 F5:8'),
    bar('G5:4 F5:4 E5:4 D#5:4'),
    bar('B4:8 D#5:8'),
    // A
    bar('E6:6 D6:2 B5:4 G5:4'),
    bar('A5:6 C6:2 F6:8'),
    bar('E6:6 D6:2 B5:4 E5:4'),
    bar('F5:4 A5:4 C6:4 E6:4'),
    bar('E6:8 D6:4 C6:4'),
    bar('D6:6 C6:2 A5:4 F#5:4'),
    bar('B5:6 C6:2 B5:4 A5:4'),
    bar('F#5:4 D#5:4 B4:8'),
    // B (un tono arriba)
    bar('F#5:6 E6:2 C#6:4 A5:4'),
    bar('B5:6 D6:2 G5:8'),
    bar('F#5:6 E6:2 C#6:4 F#5:4'),
    bar('G5:4 B5:4 D6:4 G5:4'),
    bar('E6:8 C6:4 A5:4'),
    bar('Bb5:6 D6:2 F6:8'),
    bar('F#5:12 D#6:2 B5:2'),
    bar('F#5:16'),
    // C (rítmica)
    bar('G5:3 G5:3 G5:2 E5:8'),
    bar('F#5:3 F#5:3 F#5:2 D#5:8'),
    bar('E5:3 E5:3 E5:2 C5:4 E5:4'),
    bar('D#5:3 F#5:3 B5:2 A5:4 F#5:4'),
    bar('B5:3 B5:3 B5:2 G5:8'),
    bar('A5:3 A5:3 A5:2 F#5:4 D6:4'),
    bar('C6:4 B5:4 A5:4 F#5:4'),
    bar('D#5:4 F#5:4 B5:8'),
  ]);

  // 3+3+2: el pulso cojea.
  final beat = bar('k:1 k:1 h:1 s:2 k:1 h:1 k:1 s:2 k:1 h:1 k:2 s:2', drums: true);
  final beat2 = bar('k:1 k:1 h:1 s:2 k:1 k:1 k:1 s:2 k:1 s:1 k:1 o:2 h:1', drums: true);
  final fill = bar('s:1 s:1 s:1 s:1 T:1 T:1 T:1 T:1 t:1 t:1 t:1 t:1 s:1 s:1 s:1 s:1', drums: true);
  final crash = bar('c+k:1 k:1 h:1 s:2 k:1 h:1 k:1 s:2 k:1 h:1 k:2 s:2', drums: true);
  final drums = join([
    crash, beat, beat, beat2, beat, beat, beat2, fill, // riff
    crash, beat, beat2, beat, beat, beat2, beat, fill, // A
    crash, beat, beat2, beat, beat, beat2, beat, fill, // B
    crash, beat, beat2, beat, beat, beat2, beat2, fill, // C
  ]);

  return Song(
    id: 'bossAbyss',
    title: 'Jefe del Abismo',
    bpm: 172,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.36, attack: 0.02), melody),
      Track('doble', Inst.leadDouble.copyWith(volume: 0.06), melody),
      Track('riff', Inst.harmony,
          arp(chords, center: 52, count: 3, shape: const [0, 0, 1, 0, 0, 2, 1, 0])),
      Track('bajo', Inst.bassStaccato, bassLine(chords, 'R:2 R:1 R:1 b:2 R:2 R:2 8:2 5:2 b:2')),
      Track.drums('batería', drums, gain: 0.85),
    ],
  );
}
