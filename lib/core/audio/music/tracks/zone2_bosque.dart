import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';
import 'dungeon_variant.dart';

/// Zone 2 · Forest (biome exterior).
///
/// Mood: an enchanted, tranquil wood where small lights drift between
/// the trunks. D major with a lydian touch (the E major chord over D
/// lends a single G sharp: the "fairy" color). The ocarina sings with a
/// soft echo, a harp rolls the chords upward, sine chimes twinkle high
/// and a quiet pad and bass hold the floor. Only brushes of hi-hat and a
/// soft tom. 84 bpm, 4/4, 16 bars (≈ 46 s).
Song zone2Bosque() {
  const a = 'D E/D D E/D Bm G Em A';
  const b = 'G A F#m Bm G E/D A D';
  final chords = ch('$a $b', 16);

  final melody = join([
    // A
    bar('A5:6 F#5:2 D5:8'),
    bar('E5:4 G#5:4 B5:4 .:4'),
    bar('A5:6 F#5:2 A5:4 D6:4'),
    bar('C#6:8 B5:4 .:4'),
    bar('B5:6 F#5:2 D5:8'),
    bar('G5:6 B5:2 D6:4 .:4'),
    bar('E6:8 B5:4 G5:4'),
    bar('A5:12 .:4'),
    // B
    bar('B5:6 D6:2 B5:4 G5:4'),
    bar('C#6:8 A5:4 .:4'),
    bar('F#5:6 A5:2 C#6:8'),
    bar('D6:8 B5:4 .:4'),
    bar('G5:6 A5:2 B5:4 D6:4'),
    bar('B5:8 A5:4 .:4'),
    bar('E5:6 C#5:2 A4:4 C#5:4'),
    bar('D5:12 .:4'),
  ]);

  final drums = rep(
      join([
        bar('.:4 h:2 .:6 h:2 .:2', drums: true),
        bar('t:4 .:6 h:2 .:4', drums: true),
      ]),
      8);

  return Song(
    id: 'zone2',
    title: 'Forest',
    bpm: 84,
    tracks: [
      Track('ocarina', Inst.ocarinaEcho, melody),
      Track('harp',
          Inst.arp.copyWith(volume: 0.075, decay: 0.3, sustain: 0.15,
              lowpass: 3600),
          arp(chords, center: 60, count: 3,
              shape: const [0, 1, 2, 3, 4, 3, 2, 1], rhythm: 'x:2')),
      Track('lights', Inst.chime.copyWith(volume: 0.06),
          arp(chords, center: 86, count: 4, shape: const [3, 1, 2, 0],
              rhythm: '.:4 x:2 .:6 x:2 .:2')),
      Track('pad', Inst.pad.copyWith(volume: 0.04),
          comp(chords, 'x:16', center: 64, count: 2)),
      Track('bass', Inst.bass.copyWith(volume: 0.18), bassLine(chords, 'R:12 5:4')),
      Track.drums('drums', drums, gain: 0.35),
    ],
  );
}

/// Forest dungeon: the forest theme turned to D minor (F, B flat, C),
/// lower harp, pulsing bass and a heartbeat kick.
Song zone2BosqueDungeon() => dungeonVariant(zone2Bosque(),
    id: 'zone2.dungeon',
    title: 'Forest (depths)',
    tonic: 2,
    flatten: const {4, 6, 9, 11});
