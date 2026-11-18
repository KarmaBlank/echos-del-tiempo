import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Zona 1 · Pradera Esmeralda.
///
/// Clima: luminoso y pastoral, una canción de pastor que se balancea en
/// 6/8 (negra–corchea), con un arpegio de pulso como arroyo y un bajo en
/// negras con punto. Fa mayor, 76 bpm (negra con punto), 6/8, 32
/// compases (≈ 51 s). A (1–16) dos frases que suben a La y a Re agudo;
/// B (17–32) más cantada, toca Sol menor y La menor y vuelve por Do.
Song zone1Pradera() {
  const p1 = 'F F Bb F Dm Gm C C';
  const p2 = 'F F Bb F Dm Bb C F';
  const p3 = 'Bb C Am Dm Bb C F F';
  const p4 = 'Gm C Am Dm Bb C F C';
  final chords = ch('$p1 $p2 $p3 $p4', 6);

  String b(String s) => bar(s, steps: 6);
  final melody = join([
    // A, frase 1
    b('C5:2 A4:1 F5:3'), b('E5:2 F5:1 G5:2 A5:1'), b('F5:3 D5:3'), b('C5:6'),
    b('D5:2 E5:1 F5:2 A5:1'), b('Bb5:3 G5:2 D5:1'), b('E5:2 F5:1 G5:2 E5:1'),
    b('C5:3 .:3'),
    // A, frase 2
    b('C5:2 A4:1 F5:3'), b('E5:2 F5:1 G5:2 A5:1'), b('D6:3 C6:2 Bb5:1'),
    b('A5:3 F5:3'), b('D5:2 E5:1 F5:2 D5:1'), b('D5:2 C5:1 Bb4:3'),
    b('G5:2 A5:1 G5:2 E5:1'), b('F5:6'),
    // B, frase 3
    b('F5:2 G5:1 Bb5:3'), b('A5:2 G5:1 E5:3'), b('E5:2 F5:1 A5:3'),
    b('F5:3 D5:3'), b('Bb5:2 A5:1 G5:2 F5:1'), b('E5:2 F5:1 G5:3'),
    b('A5:2 G5:1 F5:3'), b('F5:3 .:3'),
    // B, frase 4
    b('G5:2 A5:1 Bb5:3'), b('C6:2 Bb5:1 G5:3'), b('A5:2 G5:1 E5:3'),
    b('F5:2 E5:1 D5:3'), b('D5:2 F5:1 Bb5:3'), b('G5:2 E5:1 C5:3'),
    b('A4:2 C5:1 F5:3'), b('G5:3 E5:3'),
  ]);

  // Contracanto de flauta (pulso) solo en la B: la nota de arriba del
  // acorde, sostenida.
  final counter = '${rep('.:6', 16)} '
      '${comp(ch('$p3 $p4', 6), 'x:6', center: 70, count: 1)}';

  final drums = join([
    rep(bar('k:3 h:3', steps: 6, drums: true), 15),
    bar('k:3 T:1 t:2', steps: 6, drums: true),
    rep(bar('k:2 h:1 s:2 h:1', steps: 6, drums: true), 15),
    bar('k:2 s:1 s:1 s:1 s:1', steps: 6, drums: true),
  ]);

  return Song(
    id: 'zone1',
    title: 'Pradera Esmeralda',
    bpm: 76,
    stepsPerBeat: 3,
    beatsPerBar: 2,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('arroyo', Inst.arp,
          arp(chords, center: 65, count: 4, shape: const [0, 1, 2, 3, 2, 1])),
      Track('flauta', Inst.harmony, counter, gain: 0.7),
      Track('bajo', Inst.bass, bassLine(chords, 'R:3 5:3')),
      Track.drums('batería', drums, gain: 0.45),
    ],
  );
}
