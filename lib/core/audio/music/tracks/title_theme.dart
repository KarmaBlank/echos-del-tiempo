import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Título · "Ecos del Tiempo".
///
/// Clima: nostálgico y amplio, la ocarina canta lento sobre un arpegio
/// de pulso que no para (el tiempo que corre). Re menor (con La mayor de
/// dominante), 84 bpm, 4/4, 16 compases (≈ 46 s). A (1–8): motivo que
/// sube La–Re–Mi–Fa; B (9–16): se abre hacia Si♭ y Do y vuelve por La.
Song titleTheme() {
  const a = 'Dm Bb F C Dm Bb Gm A';
  const b = 'Bb C Am Dm Gm C A A';
  final chords = '${ch(a, 16)} ${ch(b, 16)}';

  final melody = join([
    // A
    bar('A4:6 D5:2 E5:4 F5:4'),
    bar('D5:8 .:2 F5:2 E5:2 D5:2'),
    bar('C5:6 A4:2 C5:4 F5:4'),
    bar('E5:12 .:4'),
    bar('A4:6 D5:2 E5:4 F5:4'),
    bar('G5:6 F5:2 D5:4 Bb4:4'),
    bar('D5:4 Bb4:2 C5:2 D5:4 G5:4'),
    bar('E5:4 C#5:4 A4:8'),
    // B
    bar('F5:6 G5:2 F5:4 D5:4'),
    bar('E5:6 F5:2 E5:4 C5:4'),
    bar('C5:6 D5:2 E5:4 A5:4'),
    bar('F5:8 E5:4 D5:4'),
    bar('D5:6 Bb4:2 D5:4 G5:4'),
    bar('A5:6 G5:2 E5:4 C5:4'),
    bar('E5:6 F5:2 E5:4 C#5:4'),
    bar('A4:12 .:4'),
  ]);

  // Colchón solo en la B (la tercera del acorde, arriba).
  final pad = '${rep('.:16', 8)} ${comp(ch(b, 16), 'x:16', center: 69, count: 1)}';

  final drums = join([
    rep(bar('k:4 .:4 h:4 .:4', drums: true), 8),
    rep(bar('k:4 h:4 s:4 h:2 h:2', drums: true), 7),
    bar('k:4 h:4 s:2 s:2 T:2 t:2', drums: true),
  ]);

  return Song(
    id: 'title',
    title: 'Ecos del Tiempo',
    bpm: 84,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('arpegio', Inst.arp,
          arp(chords, center: 62, count: 3, shape: const [0, 1, 2, 3, 2, 1],
              rhythm: 'x:2')),
      Track('colchón', Inst.pad, pad),
      Track('bajo', Inst.bass, bassLine(chords, 'R:8 5:6 8:2')),
      Track.drums('batería', drums, gain: 0.7),
    ],
  );
}
