import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';
import 'town_theme.dart';

/// Town at night (docs/specs/music.md § 5.3).
///
/// Mood: the hearth after dark. The town's chords ([townChords]) slowed
/// to 76 bpm: the soft ocarina hums the town phrases in long notes, a
/// slow harp rolls one note per beat, the open-fifth drone and a plucked
/// bass on the downbeat. No drums. 24 bars of 3/4 (≈ 57 s).
Song townNightTheme() {
  final chords = ch(townChords, 6);

  String b(String s) => bar(s, steps: 6);
  final melody = join([
    b('A4:6'), b('E5:6'), b('F#5:4 E5:2'), b('D5:4 .:2'),
    b('A4:4 D5:2'), b('G5:6'), b('E5:6'), b('F#5:4 .:2'),
    b('D5:6'), b('B4:4 D5:2'), b('C#5:6'), b('D5:4 .:2'),
    b('F#5:6'), b('E5:4 G5:2'), b('D5:6'), b('A4:4 .:2'),
    b('B4:4 D5:2'), b('A5:6'), b('G5:4 E5:2'), b('F#5:4 .:2'),
    b('D5:6'), b('C5:4 E5:2'), b('E5:6'), b('D5:4 .:2'),
  ]);

  return Song(
    id: 'townNight',
    title: 'Town (night)',
    bpm: 76,
    stepsPerBeat: 2,
    beatsPerBar: 3,
    tracks: [
      Track('ocarina', Inst.ocarinaSoft, melody, gain: 0.85),
      Track('harp', Inst.arp.copyWith(volume: 0.06, decay: 0.4, sustain: 0.1),
          arp(chords, center: 60, count: 3, shape: const [0, 1, 2],
              rhythm: 'x:2')),
      Track('drone', Inst.pad, rep('D3+A3:48', 3), gain: 0.5),
      Track('bass', Inst.bassPluck, bassLine(chords, 'R:2 .:4'), gain: 0.6),
    ],
  );
}
