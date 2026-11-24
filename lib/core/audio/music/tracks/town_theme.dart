import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Town chords (shared with [townNightTheme]): D mixolydian, 24 bars of
/// 3/4 in three phrases of 8.
const townChords = 'D C D G D C Am D '
    'Bm G A D Bm C G A '
    'G D C D G C D D';

/// Town.
///
/// Mood: home after the road. A gentle 3/4 dance in D mixolydian (the
/// C natural gives it an old, pastoral color): a lute-like pulse picks
/// the chords in eighths, a soft open-fifth drone hums under everything
/// and the ocarina sings short, hummable phrases with a breath every two
/// bars. 112 bpm, 24 bars (≈ 39 s).
Song townTheme() {
  final chords = ch(townChords, 6);

  String b(String s) => bar(s, steps: 6);
  final melody = join([
    // Phrase 1
    b('A4:4 D5:2'), b('E5:2 C5:2 E5:2'), b('F#5:4 E5:2'), b('D5:4 .:2'),
    b('A4:2 D5:2 F#5:2'), b('G5:4 E5:2'), b('C5:2 E5:2 A5:2'), b('F#5:4 .:2'),
    // Phrase 2: a little shade (B minor)
    b('D5:4 F#5:2'), b('G5:2 B5:2 G5:2'), b('E5:4 C#5:2'), b('D5:4 .:2'),
    b('B4:2 D5:2 F#5:2'), b('E5:4 G5:2'), b('D5:2 B4:2 D5:2'), b('A4:4 .:2'),
    // Phrase 3: back home
    b('B4:2 D5:2 G5:2'), b('A5:4 F#5:2'), b('G5:2 E5:2 C5:2'), b('D5:4 .:2'),
    b('B4:4 D5:2'), b('C5:2 E5:2 G5:2'), b('F#5:4 E5:2'), b('D5:4 .:2'),
  ]);

  final drums = rep(bar('k:2 h:2 h:2', steps: 6, drums: true), 24);

  return Song(
    id: 'town',
    title: 'Town',
    bpm: 112,
    stepsPerBeat: 2,
    beatsPerBar: 3,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('lute',
          Inst.arp.copyWith(volume: 0.085, decay: 0.25, sustain: 0.2,
              lowpass: 3200),
          arp(chords, center: 62, count: 3, shape: const [0, 2, 1, 2, 1, 2])),
      Track('drone', Inst.pad.copyWith(volume: 0.04), rep('D3+A3:48', 3)),
      Track('bass', Inst.bassPluck, bassLine(chords, 'R:2 .:4')),
      Track.drums('drums', drums, gain: 0.25),
    ],
  );
}
