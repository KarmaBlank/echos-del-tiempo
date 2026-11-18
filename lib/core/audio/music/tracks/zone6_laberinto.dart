import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Zona 6 · Laberinto Temporal.
///
/// Clima: desorientador y mecánico, pasillos que se repiten y un reloj
/// que no marca la hora bien. La ocarina canta y una zampoña con eco la
/// imita **en canon** dos compases después y una 8va abajo (el eco del
/// laberinto: la Hechicera del Eco). El tic-tac va en 3+3+2 contra el
/// 4/4 y los engranajes (pulso 12.5 %) giran de a 3 notas sobre una
/// grilla de 4: nunca coinciden del todo.
///
/// Sol menor con toques de **tonos enteros**: Mi♭ aumentado (Si natural
/// contra el Si♭ de la tonalidad) y un B donde la armonía es solo
/// acordes aumentados (Do aum / Re aum, escala de tonos enteros: no hay
/// tónica). 116 bpm, 4/4, 20 compases (≈ 41 s).
///
/// Forma: A (1–8) ciclo de 2 compases Sol m | Mi♭ aum Re7, canon
/// circular; B (9–16) tonos enteros Do aum | Re aum, canon circular;
/// C (17–20) Do m Re7 Mi♭ aum Re7: la zampoña solo contesta y el Re7
/// devuelve a Sol m.
///
/// Original: no cita ni imita de cerca ninguna melodía existente.
Song zone6Laberinto() {
  const a = 'Gm:16 Ebaug:8 D7:8';
  final chA = rep(a, 4);
  final chB = rep('Caug:16 Daug:16', 4);
  const chC = 'Cm:16 D7:16 Ebaug:16 D7:16';
  final chords = '$chA $chB $chC';

  final barsA = [
    bar('G5:6 A5:2 Bb5:4 D6:4'),
    bar('B5:6 G5:2 F#5:4 A5:4'),
    bar('G5:4 Bb5:4 D6:6 C6:2'),
    bar('B5:4 Eb6:4 D6:4 C6:2 A5:2'),
    bar('Bb5:6 A5:2 G5:4 D5:4'),
    bar('Eb5:4 G5:4 F#5:6 A5:2'),
    bar('G5:3 A5:3 Bb5:2 C6:3 Bb5:3 A5:2'), // 3+3+2, como el reloj
    bar('B5:4 G5:4 A5:6 F#5:2'),
  ];
  // Tonos enteros: Do Re Mi Fa# Sol# La#.
  final barsB = [
    bar('E5:4 G#5:4 C6:8'),
    bar('A#5:4 F#5:4 D5:8'),
    bar('C5:2 D5:2 E5:2 F#5:2 G#5:8'),
    bar('A#5:6 G#5:2 F#5:8'),
    bar('E6:4 C6:4 G#5:4 E5:4'),
    bar('D6:4 A#5:4 F#5:4 D5:4'),
    bar('E5:3 F#5:3 G#5:2 A#5:3 G#5:3 E5:2'),
    bar('F#5:12 .:4'),
  ];
  final barsC = [
    bar('C6:6 Bb5:2 G5:4 Eb5:4'),
    bar('F#5:6 A5:2 C6:4 A5:4'),
    bar('B5:4 G5:4 Eb5:4 G5:4'),
    bar('F#5:8 D5:4 A4:4'),
  ];
  final melody = join([...barsA, ...barsB, ...barsC]);

  // Canon circular a 2 compases dentro de cada parte: como la armonía se
  // repite cada 2 compases, la imitación siempre cae sobre el mismo
  // acorde que el original.
  List<String> canon(List<String> bars) =>
      [...bars.sublist(bars.length - 2), ...bars.sublist(0, bars.length - 2)];
  final echo = join([
    shift(join(canon(barsA)), -12),
    shift(join(canon(barsB)), -12),
    bar('.:8 G4:4 Eb4:4'),
    bar('.:8 A4:4 F#4:4'),
    bar('.:8 B4:4 G4:4'),
    bar('.:8 C5:4 A4:4'),
  ]);

  final tick = bar('k+r:3 q:3 r:2 r:3 k+q:3 r:2', drums: true);
  final tickLight = bar('r:3 q:3 r:2 r:3 q:3 r:2', drums: true);
  final drums = join([
    rep(tick, 7),
    bar('k+r:3 q:3 r:2 s:2 s:2 T:2 t:2', drums: true),
    rep(join([tickLight, tick]), 4),
    tick,
    tick,
    tick,
    bar('k+r:2 q:2 s+r:2 q:2 k+r:2 q:2 s+r:1 r:1 q:1 q:1', drums: true),
  ]);

  return Song(
    id: 'zone6',
    title: 'Laberinto Temporal',
    bpm: 116,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('eco', Inst.zamponaEcho.copyWith(volume: 0.16, echoSteps: 3), echo),
      Track('engranajes', Inst.arp,
          arp(chords, center: 67, count: 3, shape: const [0, 2, 1]),
          gain: 0.7),
      Track('colchón', Inst.pad, comp(chords, 'x:16', center: 60, count: 3)),
      Track('bajo', Inst.bassStaccato,
          bassLine(chords, 'R:3 8:3 R:2 5:3 R:3 b:2')),
      Track.drums('reloj', drums, gain: 0.55),
    ],
  );
}
