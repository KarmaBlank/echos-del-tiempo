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
Song bossTheme() => bossArrangement(BossStyle.standard);

/// The shared boss melody arranged for [style] (docs/specs/music.md
/// § 4.4): same ocarina line and chords, biome-specific tempo,
/// instrumentation and rhythm.
Song bossArrangement(BossStyle style) {
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

  final (String beat, String beat2, String fill, String crash) = switch (style) {
    BossStyle.standard || BossStyle.ruins => (
        bar('k:1 k:1 h:2 s:2 h:1 k:1 k:1 k:1 h:2 s:2 h:2', drums: true),
        bar('k:1 k:1 h:2 s:2 k:1 k:1 k:1 k:1 s:1 k:1 s:2 o:2', drums: true),
        bar('s:1 s:1 s:1 s:1 T:1 T:1 T:1 T:1 t:1 t:1 t:1 t:1 s:1 s:1 s:1 s:1', drums: true),
        bar('c+k:1 k:1 h:2 s:2 h:1 k:1 k:1 k:1 h:2 s:2 h:2', drums: true),
      ),
    BossStyle.forest => (
        bar('k:4 h:2 t:2 s:4 h:2 t:2', drums: true),
        bar('k:4 h:2 t:2 s:4 t:2 T:2', drums: true),
        bar('t:2 t:2 T:2 T:2 t:2 T:2 s:2 s:2', drums: true),
        bar('c+k:4 h:2 t:2 s:4 h:2 t:2', drums: true),
      ),
    BossStyle.caverns => (
        bar('k:4 h:4 s:4 h:4', drums: true),
        bar('k:4 h:4 s:4 h:2 k:2', drums: true),
        bar('k:4 t:4 T:4 s:2 s:2', drums: true),
        bar('c+k:4 h:4 s:4 h:4', drums: true),
      ),
    BossStyle.volcano => (
        bar('b+k:2 k:1 k:1 s:2 a:2 b+k:2 k:2 s:2 a:2', drums: true),
        bar('b+k:2 k:1 k:1 s:2 a:2 b+k:1 k:1 k:2 s:1 s:1 a:2', drums: true),
        bar('s:1 s:1 s:1 s:1 b:2 b:2 T:1 T:1 t:1 t:1 b+c:4', drums: true),
        bar('b+k+c:2 k:1 k:1 s:2 a:2 b+k:2 k:2 s:2 a:2', drums: true),
      ),
    BossStyle.abyss => (
        bar('k:4 .:2 h:2 s:4 .:2 h:2', drums: true),
        bar('k:4 .:2 h:2 s:4 k:2 o:2', drums: true),
        bar('k:2 s:2 .:4 T:4 t:4', drums: true),
        bar('c+k:4 .:2 h:2 s:4 .:2 h:2', drums: true),
      ),
  };
  final drums = join([
    crash, beat, beat, beat2, beat, beat, beat2, fill, // riff
    crash, beat, beat2, beat, beat, beat2, beat, fill, // A
    crash, beat, beat2, beat, beat, beat2, beat, fill, // B
    crash, beat, beat2, beat, beat, beat2, beat2, fill, // C
  ]);

  final lead = Inst.ocarina.copyWith(volume: 0.36, attack: 0.02);
  return switch (style) {
    BossStyle.standard => Song(
        id: 'boss',
        title: 'Jefe',
        bpm: 168,
        tracks: [
          Track('ocarina', lead, melody),
          Track('doble', Inst.leadDouble.copyWith(volume: 0.06), melody),
          Track('riff', Inst.harmony,
              arp(chords, center: 57, count: 3, shape: const [0, 0, 2, 0, 1, 0, 2, 1])),
          Track('bajo', Inst.bassStaccato, bassLine(chords, 'R:2 R:2 8:2 R:2 b:2 R:2 8:2 5:2')),
          Track.drums('batería', drums, gain: 0.85),
        ],
      ),
    // Airy: echoing ocarina, rising harp, chimes, light toms.
    BossStyle.forest => Song(
        id: 'boss.zone2',
        title: 'Boss (forest)',
        bpm: 150,
        tracks: [
          Track('ocarina', Inst.ocarinaEcho.copyWith(volume: 0.36), melody),
          Track('harp', Inst.arp.copyWith(decay: 0.2, sustain: 0.2),
              arp(chords, center: 62, count: 3, shape: const [0, 1, 2, 3, 4, 3, 2, 1])),
          Track('lights', Inst.chime.copyWith(volume: 0.06),
              arp(chords, center: 84, count: 3, shape: const [2, 0, 1],
                  rhythm: 'x:4')),
          Track('bass', Inst.bassStaccato, bassLine(chords, 'R:4 8:4 5:4 8:4')),
          Track.drums('drums', drums, gain: 0.7),
        ],
      ),
    // Ancient: a horn under the ocarina, solemn chords, bass drum.
    BossStyle.ruins => Song(
        id: 'boss.zone3',
        title: 'Boss (ruins)',
        bpm: 160,
        tracks: [
          Track('ocarina', lead, melody),
          Track('horn',
              Inst.brass.copyWith(volume: 0.055, lowpass: 2200, transpose: -12),
              melody),
          Track('chords', Inst.harmony,
              comp(chords, 'x:4 .:2 x:2 .:4 x:4', center: 57, count: 3)),
          Track('bass', Inst.bassStaccato, bassLine(chords, 'R:4 R:2 8:2 R:4 5:4')),
          Track.drums('drums', drums, gain: 0.8),
        ],
      ),
    // Cold: long echo, icy chimes and a slow pad, sparse beat.
    BossStyle.caverns => Song(
        id: 'boss.zone4',
        title: 'Boss (caverns)',
        bpm: 156,
        tracks: [
          Track('ocarina', Inst.ocarinaEcho.copyWith(volume: 0.36, echoSteps: 4),
              melody),
          Track('ice', Inst.chime.copyWith(volume: 0.08),
              arp(chords, center: 81, count: 3, shape: const [0, 2, 1, 2],
                  rhythm: 'x:2')),
          Track('pad', Inst.pad.copyWith(volume: 0.05),
              comp(chords, 'x:16', center: 60, count: 3)),
          Track('bass', Inst.bassStaccato, bassLine(chords, 'R:2 .:2 R:2 .:2 8:2 .:2 5:2 .:2')),
          Track.drums('drums', drums, gain: 0.75),
        ],
      ),
    // Driving: fast, brass stabs, sixteenth-note bass, deep drum.
    BossStyle.volcano => Song(
        id: 'boss.zone7',
        title: 'Boss (rift)',
        bpm: 184,
        tracks: [
          Track('ocarina', lead, melody),
          Track('brass', Inst.brass,
              comp(chords, 'x:2 .:2 x:2 .:6 x:2 .:2', center: 55, count: 3),
              gain: 0.8),
          Track('riff', Inst.harmony.copyWith(volume: 0.06),
              arp(chords, center: 55, count: 3, shape: const [0, 0, 1, 0])),
          Track('bass', Inst.bassStaccato,
              bassLine(chords, 'R:1 R:1 8:1 R:1 R:1 R:1 b:1 R:1')),
          Track.drums('drums', drums, gain: 0.8),
        ],
      ),
    // Eerie: echoing ocarina over a tritone drone, slow pulse.
    BossStyle.abyss => Song(
        id: 'boss.zone9',
        title: 'Boss (abyss)',
        bpm: 164,
        tracks: [
          Track('ocarina', Inst.ocarinaEcho.copyWith(volume: 0.36, echoSteps: 6),
              melody),
          Track('drone', Inst.pad.copyWith(volume: 0.05, lowpass: 1000),
              rep('D3+G#3:128', 4)),
          Track('arp', Inst.arp.copyWith(volume: 0.07),
              arp(chords, center: 60, count: 3, shape: const [0, 2, 1, 3])),
          Track('bass', Inst.bassStaccato, bassLine(chords, 'R:4 .:4 b:4 R:4')),
          Track.drums('drums', drums, gain: 0.75),
        ],
      ),
  };
}

/// Biome arrangements of the boss theme.
enum BossStyle { standard, forest, ruins, caverns, volcano, abyss }
