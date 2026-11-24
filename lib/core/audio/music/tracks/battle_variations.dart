import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Battle II.
///
/// Mood: a skirmish on the road, quick and folk-like. A dorian (the F
/// sharp of the D major chord is the only accidental): a galloping kick,
/// a pulse arpeggio and a bouncing bass; the ocarina throws a short
/// three-note call and answers it. 148 bpm, 4/4, 24 bars (≈ 39 s):
/// intro 4, A 8, B 8, turn 4.
Song battleTheme2() {
  const intro = 'Am Am G Am';
  const a = 'Am G D Am Am G Em Am';
  const b = 'F G Am Am F G D Em';
  const turn = 'Am G D Em';
  final chords = ch('$intro $a $b $turn', 16);

  final melody = join([
    // Intro
    bar('A4:2 A4:2 E5:4 .:8'),
    bar('A4:2 A4:2 E5:4 D5:4 C5:4'),
    bar('B4:2 B4:2 D5:4 G5:4 .:4'),
    bar('A5:4 G5:4 E5:4 .:4'),
    // A
    bar('E5:6 A5:2 C6:4 B5:4'),
    bar('D6:6 B5:2 G5:4 .:4'),
    bar('F#5:6 A5:2 D6:4 C6:4'),
    bar('A5:12 .:4'),
    bar('C6:6 B5:2 A5:4 E5:4'),
    bar('D5:6 G5:2 B5:4 .:4'),
    bar('E6:8 D6:4 B5:4'),
    bar('A5:12 .:4'),
    // B
    bar('F5:4 A5:4 C6:8'),
    bar('D6:4 B5:4 G5:4 .:4'),
    bar('E5:4 A5:4 C6:4 E6:4'),
    bar('D6:8 C6:4 .:4'),
    bar('C6:6 A5:2 F5:8'),
    bar('B5:6 D6:2 G5:4 .:4'),
    bar('F#5:6 A5:2 D6:8'),
    bar('E6:8 B5:4 .:4'),
    // Turn
    bar('.:8 A5:2 G5:2 E5:2 D5:2'),
    bar('D5:8 B4:4 .:4'),
    bar('A4:4 D5:4 F#5:4 A5:4'),
    bar('G5:8 B5:4 .:4'),
  ]);

  final gallop = bar('k:2 k:1 k:1 s:2 h:2 k:2 k:1 k:1 s:2 h:2', drums: true);
  final gallop2 = bar('k:2 k:1 k:1 s:2 h:2 k:2 s:1 s:1 s:2 o:2', drums: true);
  final fill = bar('k:2 s:2 s:2 s:2 T:2 T:2 t:2 t:2', drums: true);
  final crash = bar('c+k:2 k:1 k:1 s:2 h:2 k:2 k:1 k:1 s:2 h:2', drums: true);
  final drums = join([
    gallop, gallop, gallop2, fill,
    crash, gallop, gallop2, gallop, gallop, gallop2, gallop, fill,
    crash, gallop, gallop2, gallop, gallop, gallop2, gallop, fill,
    gallop, gallop2, gallop, fill,
  ]);

  return Song(
    id: 'battle2',
    title: 'Battle II',
    bpm: 148,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.36, attack: 0.02), melody),
      Track('double', Inst.leadDouble, melody),
      Track('arp', Inst.arp,
          arp(chords, center: 62, count: 3, shape: const [0, 2, 1, 2])),
      Track('bass', Inst.bassStaccato,
          bassLine(chords, 'R:2 5:2 8:2 5:2 R:2 5:2 8:2 R:2')),
      Track.drums('drums', drums, gain: 0.8),
    ],
  );
}

/// Battle III.
///
/// Mood: a stand against something larger, steady and proud. D natural
/// minor (the A major chord brings the only accidental, C sharp): a
/// marching snare, a horn doubling the ocarina an octave below, chord
/// stabs and a driving bass. 160 bpm, 4/4, 24 bars (≈ 36 s): intro 4, A
/// 8, B 8, turn 4.
Song battleTheme3() {
  const intro = 'Dm C Bb A';
  const a = 'Dm F C Dm Bb C Dm A';
  const b = 'Gm Dm Bb F Gm Dm Bb A';
  const turn = 'Dm C Bb A';
  final chords = ch('$intro $a $b $turn', 16);

  final melody = join([
    // Intro
    bar('D5:4 F5:4 A5:8'),
    bar('G5:4 E5:4 C5:4 .:4'),
    bar('F5:4 D5:4 Bb4:8'),
    bar('C#5:4 E5:4 A5:4 .:4'),
    // A
    bar('D6:6 C6:2 A5:4 F5:4'),
    bar('C6:6 A5:2 F5:4 .:4'),
    bar('E5:4 G5:4 C6:4 E6:4'),
    bar('D6:12 .:4'),
    bar('F5:3 F5:3 Bb5:2 D6:8'),
    bar('E5:3 E5:3 G5:2 C6:4 .:4'),
    bar('A5:6 F5:2 D5:4 F5:4'),
    bar('E5:8 C#5:4 .:4'),
    // B
    bar('G5:6 Bb5:2 D6:8'),
    bar('F5:6 A5:2 D6:4 .:4'),
    bar('D6:6 C6:2 Bb5:4 F5:4'),
    bar('A5:12 .:4'),
    bar('Bb5:6 A5:2 G5:4 D5:4'),
    bar('F5:6 E5:2 D5:4 .:4'),
    bar('Bb4:4 D5:4 F5:4 Bb5:4'),
    bar('A5:8 E5:4 .:4'),
    // Turn
    bar('.:16'),
    bar('.:8 C5:2 D5:2 E5:2 G5:2'),
    bar('F5:8 D5:4 .:4'),
    bar('E5:4 C#5:4 A4:4 .:4'),
  ]);

  final march = bar('k:2 s:1 s:1 k:2 s:2 k:2 k:2 s:2 h:2', drums: true);
  final march2 = bar('k:2 s:1 s:1 k:2 s:2 k:2 s:1 s:1 s:2 o:2', drums: true);
  final fill = bar('s:1 s:1 s:1 s:1 s:2 s:2 T:2 T:2 t:2 t:2', drums: true);
  final crash = bar('c+k:2 s:1 s:1 k:2 s:2 k:2 k:2 s:2 h:2', drums: true);
  final drums = join([
    march, march, march2, fill,
    crash, march, march2, march, march, march2, march, fill,
    crash, march, march2, march, march, march2, march, fill,
    march, march2, march, fill,
  ]);

  return Song(
    id: 'battle3',
    title: 'Battle III',
    bpm: 160,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.36, attack: 0.02), melody),
      Track('horn', Inst.brass.copyWith(volume: 0.05, lowpass: 2200, transpose: -12),
          melody),
      Track('stabs', Inst.harmony,
          comp(chords, 'x:2 .:4 x:2 .:2 x:2 .:4', center: 60, count: 3)),
      Track('bass', Inst.bassStaccato,
          bassLine(chords, 'R:2 R:2 8:2 R:2 R:2 R:2 5:2 8:2')),
      Track.drums('drums', drums, gain: 0.8),
    ],
  );
}
