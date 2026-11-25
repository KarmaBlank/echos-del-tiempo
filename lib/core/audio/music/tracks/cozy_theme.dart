import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Calm outdoors: fishing or on a raft outside the town
/// (docs/specs/cozy_life.md § 1).
///
/// A slow, soft piece: 66 bpm in 3/4, the soft ocarina over a plucked
/// charango arpeggio, a long pad and a bass touched on the 1. No drums. 16 bars; the last bar rests so the loop closes on D.
Song cozyTheme() {
  const p1 = 'D G D A D G Em A';
  const p2 = 'Bm G D A G A D D';
  final chords = ch('$p1 $p2', 6);

  String b(String s) => bar(s, steps: 6);
  final melody = join([
    b('A4:2 D5:2 F#5:2'), b('E5:4 D5:2'), b('A4:2 F#5:2 D5:2'), b('E5:6'),
    b('A4:2 D5:2 E5:2'), b('D5:4 B4:2'), b('B4:2 E5:2 G5:2'), b('E5:6'),
    b('D5:2 F#5:2 A5:2'), b('G5:4 D5:2'), b('A4:2 D5:2 F#5:2'), b('E5:6'),
    b('B4:2 D5:2 G5:2'), b('A5:2 G5:2 E5:2'), b('D5:6'), b('.:6'),
  ]);

  return Song(
    id: 'cozy',
    title: 'Calma (pesca y balsa)',
    bpm: 66,
    stepsPerBeat: 2,
    beatsPerBar: 3,
    tracks: [
      Track('ocarina', Inst.ocarinaSoft, melody),
      // The plucked strings: a soft arpeggio under the ocarina.
      Track('charango', Inst.charango, comp(chords, 'x:2 x:2 x:2', center: 60),
          gain: 0.7),
      Track('colchón', Inst.pad, comp(chords, 'x:6', center: 62), gain: 0.5),
      Track('bajo', Inst.bassPluck, bassLine(chords, 'R:2 .:4')),
    ],
  );
}
