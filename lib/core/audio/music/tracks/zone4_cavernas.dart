import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';
import 'dungeon_variant.dart';

/// Zona 4 · Cavernas Heladas.
///
/// Clima: frío, escaso, el aliento se ve. La ocarina con eco largo toca
/// pocas notas y deja mucho aire; campanitas de seno como gotas que se
/// congelan, un colchón de cuadrada filtrada que entra despacio (séptimas
/// mayores: Sol maj7, Re maj7) y un bajo de redondas. Sin batería, solo
/// hi-hats sueltos como goteo. Si menor, 72 bpm, 4/4, 12 compases (40 s).
Song zone4Cavernas() {
  const prog = 'Bm Gmaj7 Em F# Bm Gmaj7 Dmaj7 A Gmaj7 Em F#sus4 F#';
  final chords = ch(prog, 16);

  final melody = join([
    bar('F#5:8 .:4 D5:4'),
    bar('B4:12 .:4'),
    bar('E5:6 F#5:2 G5:8'),
    bar('F#5:8 E5:4 C#5:4'),
    bar('D5:8 .:4 B4:4'),
    bar('D5:6 E5:2 F#5:8'),
    bar('A5:12 .:4'),
    bar('E5:8 C#5:8'),
    bar('B5:8 A5:4 F#5:4'),
    bar('G5:8 E5:8'),
    bar('B4:8 C#5:8'),
    bar('A#4:12 .:4'),
  ]);

  final drips = join([
    bar('.:6 h:1 .:5 h:1 .:3', drums: true),
    bar('.:10 h:1 .:5', drums: true),
    bar('.:3 h:1 .:8 h:1 .:3', drums: true),
  ]);

  return Song(
    id: 'zone4',
    title: 'Cavernas Heladas',
    bpm: 72,
    tracks: [
      Track('ocarina', Inst.ocarinaEcho.copyWith(echoSteps: 4, echoGain: 0.4),
          melody),
      Track('gotas', Inst.chime,
          arp(chords, center: 86, count: 4, shape: const [3, 1, 2, 0],
              rhythm: 'x:2 .:4 x:2 .:6 x:2')),
      Track('colchón', Inst.pad.copyWith(volume: 0.06),
          comp(chords, 'x:16', center: 62, count: 3)),
      Track('bajo', Inst.bass.copyWith(volume: 0.2), bassLine(chords, 'R:16')),
      Track('frost', Inst.pad.copyWith(volume: 0.03, lowpass: 700),
          rep('B1+F#2:64', 3)),
      Track.drums('goteo', rep(drips, 4), gain: 0.5),
    ],
  );
}

/// Caverns dungeon: the frozen theme with a phrygian C natural, lower
/// chimes, pulsing bass and a heartbeat kick.
Song zone4CavernasDungeon() => dungeonVariant(zone4Cavernas(),
    id: 'zone4.dungeon',
    title: 'Caverns (depths)',
    tonic: 11,
    flatten: const {2});
