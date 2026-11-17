import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Zona 3 · Ruinas Cronales.
///
/// Clima: antiguo y mecánico, un reloj enorme que sigue andando entre
/// piedras rotas. La percusión es un tic-tac en corcheas (pulso agudo /
/// triángulo grave), el arpegio de pulso gira como engranajes en
/// semicorcheas y el bajo marca corcheas cortas. La ocarina canta una
/// melodía solemne en La menor armónica (Sol sostenido: sabor arcaico).
/// La menor, 104 bpm, 4/4, 20 compases (≈ 46 s): A (1–8), B (9–16) y
/// un puente de 4 que vuelve por Mi.
Song zone3Ruinas() {
  const a = 'Am E Am G F Dm E E';
  const b = 'F G Em Am Dm E7 Am E';
  const c = 'F E Dm E7';
  final chords = ch('$a $b $c', 16);

  final melody = join([
    // A
    bar('A4:4 C5:4 E5:6 D5:2'),
    bar('B4:8 G#4:8'),
    bar('A4:4 C5:4 E5:4 A5:4'),
    bar('G5:6 F5:2 D5:8'),
    bar('F5:6 E5:2 C5:4 A4:4'),
    bar('D5:4 F5:4 A5:8'),
    bar('G#5:6 F5:2 E5:4 D5:4'),
    bar('E5:12 .:4'),
    // B
    bar('A5:6 G5:2 F5:4 C5:4'),
    bar('B4:6 D5:2 G5:8'),
    bar('E5:6 G5:2 B5:4 G5:4'),
    bar('A5:12 .:4'),
    bar('F5:6 E5:2 D5:4 A4:4'),
    bar('G#4:4 B4:4 D5:4 E5:4'),
    bar('C5:6 B4:2 A4:8'),
    bar('B4:6 C5:2 D5:4 G#4:4'),
    // Puente
    bar('A5:8 F5:8'),
    bar('G#5:8 E5:8'),
    bar('F5:8 D5:4 A4:4'),
    bar('E5:4 G#4:4 B4:4 D5:4'),
  ]);

  final clock = bar('k+r:2 q:2 r:2 q:2 r:2 q:2 r:2 q:2', drums: true);
  final clockSnare = bar('k+r:2 q:2 r:2 q:2 s+r:2 q:2 r:2 q:2', drums: true);
  final drums = join([
    rep(clock, 8),
    rep(clockSnare, 7),
    bar('k+r:2 q:2 r:2 q:2 s:2 s:2 T:2 t:2', drums: true),
    rep(clock, 3),
    bar('k+r:2 q:2 r:2 q:2 r:1 r:1 q:1 q:1 r:1 r:1 q:1 q:1', drums: true),
  ]);

  return Song(
    id: 'zone3',
    title: 'Ruinas Cronales',
    bpm: 104,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('engranajes', Inst.arp,
          arp(chords, center: 64, count: 3, shape: const [0, 2, 1, 2]),
          gain: 0.75),
      Track('bajo', Inst.bassStaccato, bassLine(chords, 'R:2 .:2 R:2 .:2 5:2 .:2 R:2 .:2')),
      Track.drums('reloj', drums, gain: 0.6),
    ],
  );
}
