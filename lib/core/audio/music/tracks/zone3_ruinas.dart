import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';
import 'dungeon_variant.dart';

/// Zone 3 · Ruins (biome exterior).
///
/// Mood: ancient and melancholic, stones that remember a time that has
/// not happened yet. A natural minor, slow: an open A–E drone, a harp
/// rolling the chords, a soft horn that answers the ocarina an octave
/// below in the second half and a far bass drum every other bar. The E
/// major chord before each return is the only sharp (G sharp, in the
/// accompaniment). 84 bpm, 4/4, 20 bars (≈ 57 s).
Song zone3Ruinas() {
  const a = 'Am Em Am G F Dm E E';
  const b = 'F G Em Am Dm Em Am E';
  const c = 'F C Dm E';
  final chords = ch('$a $b $c', 16);

  final themeB = join([
    bar('A5:6 G5:2 F5:4 C5:4'),
    bar('B4:6 D5:2 G5:4 .:4'),
    bar('E5:6 G5:2 B5:4 G5:4'),
    bar('A5:12 .:4'),
    bar('F5:6 E5:2 D5:4 A4:4'),
    bar('B4:4 D5:4 E5:4 .:4'),
    bar('C5:6 B4:2 A4:8'),
    bar('B4:12 .:4'),
  ]);
  final melody = join([
    // A
    bar('A4:4 C5:4 E5:6 D5:2'),
    bar('B4:12 .:4'),
    bar('A4:4 C5:4 E5:4 A5:4'),
    bar('G5:6 F5:2 D5:4 .:4'),
    bar('F5:6 E5:2 C5:4 A4:4'),
    bar('D5:4 F5:4 A5:8'),
    bar('B5:6 A5:2 E5:4 D5:4'),
    bar('E5:12 .:4'),
    themeB,
    // Bridge
    bar('A5:8 F5:8'),
    bar('G5:8 E5:4 .:4'),
    bar('F5:8 D5:4 A4:4'),
    bar('E5:12 .:4'),
  ]);

  final drums = rep(
      join([
        bar('b:8 .:8', drums: true),
        bar('.:12 a:4', drums: true),
      ]),
      10);

  return Song(
    id: 'zone3',
    title: 'Ruins',
    bpm: 84,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('horn',
          Inst.brass.copyWith(volume: 0.05, attack: 0.06, lowpass: 2000,
              transpose: -12),
          '.:128 $themeB .:64'),
      Track('harp',
          Inst.arp.copyWith(volume: 0.07, decay: 0.3, sustain: 0.15,
              lowpass: 3400),
          arp(chords, center: 57, count: 3, shape: const [0, 1, 2, 3],
              rhythm: 'x:2')),
      Track('drone', Inst.pad.copyWith(volume: 0.05),
          rep('A2+E3:64', 5)),
      Track('bass', Inst.bass.copyWith(volume: 0.18), bassLine(chords, 'R:8 5:8')),
      Track.drums('drums', drums, gain: 0.45),
    ],
  );
}

/// Ruins dungeon: the ruins theme with a phrygian B flat, lower harp,
/// pulsing bass and a heartbeat kick.
Song zone3RuinasDungeon() => dungeonVariant(zone3Ruinas(),
    id: 'zone3.dungeon',
    title: 'Ruins (depths)',
    tonic: 9,
    flatten: const {2});
