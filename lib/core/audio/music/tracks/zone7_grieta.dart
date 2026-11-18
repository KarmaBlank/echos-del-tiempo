import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Zona 7 · Grieta Ígnea.
///
/// Clima: caliente y pesado, el suelo late. Un bordón grave (Mi + Si en
/// una cuadrada muy filtrada) que no se mueve nunca, un ostinato de bajo
/// que machaca el Mi con el Fa frigio encima, bombo legüero y aro en
/// cada compás y "metales" de pulso en golpes secos. La ocarina canta
/// lento y alto, como aire que tiembla sobre la lava; en B la zampoña la
/// dobla una 8va abajo (lo épico-andino) y entran los toms.
///
/// Mi frigio con la tercera mayor sobre la tónica (frigio dominante: Mi
/// mayor, Fa mayor, Re m, Sol#), 88 bpm, 4/4, 16 compases (≈ 44 s).
///
/// Forma: A (1–8) Mi Mi Fa Mi Re m Fa Mi Mi, ocarina sobre el bordón y
/// el ostinato; B (9–16) La m Fa Sol Fa Re m Fa Mi Mi, más alto, zampoña
/// en octavas, toms, redoble y platillo para volver.
///
/// Original: no cita ni imita de cerca ninguna melodía existente.
Song zone7Grieta() {
  const a = 'E E F E Dm F E E';
  const b = 'Am F G F Dm F E E';
  final chA = ch(a, 16);
  final chB = ch(b, 16);
  final chords = '$chA $chB';

  final themeA = join([
    bar('E5:8 F5:4 G#5:4'),
    bar('B5:12 A5:4'),
    bar('C6:6 B5:2 A5:4 F5:4'),
    bar('G#5:12 .:4'),
    bar('A5:6 F5:2 D5:4 F5:4'),
    bar('G5:4 A5:4 C6:6 B5:2'),
    bar('B5:6 A5:2 G#5:4 F5:4'),
    bar('E5:12 .:4'),
  ]);
  final themeB = join([
    bar('A5:6 B5:2 C6:4 E6:4'),
    bar('D6:8 C6:4 A5:4'),
    bar('B5:6 D6:2 B5:4 G5:4'),
    bar('A5:8 C6:4 F5:4'),
    bar('F5:4 A5:4 D6:8'),
    bar('C6:6 A5:2 F5:4 A5:4'),
    bar('G#5:6 A5:2 B5:4 D6:4'),
    bar('C6:2 B5:2 A5:2 G#5:2 F5:4 E5:4'),
  ]);
  final melody = '$themeA $themeB';

  // Ostinato de Mi frigio; sobre otros acordes se mueve con la
  // fundamental (bassLine) pero con el mismo ritmo.
  final ostinato = bar('E2:2 E2:1 E2:1 E3:2 E2:2 F2:2 E2:2 G2:2 F2:2');
  final bass = [
    for (final c in '$a $b'.split(' '))
      c == 'E'
          ? ostinato
          : bassLine('$c:16', 'R:2 R:1 R:1 8:2 R:2 b:2 R:2 3:2 b:2'),
  ].join(' ');

  final groove = bar('b+k:4 a:2 b:2 s:4 b:2 a:2', drums: true);
  final grooveB = bar('b+k:2 t:2 a:2 b:2 s+k:2 t:2 T:2 t:2', drums: true);
  final drums = join([
    rep(groove, 7),
    bar('b+k:4 a:2 b:2 s:2 s:1 s:1 T:2 t:2', drums: true),
    bar('b+k+c:2 t:2 a:2 b:2 s+k:2 t:2 T:2 t:2', drums: true),
    rep(grooveB, 6),
    bar('t:2 t:2 T:2 T:2 s:1 s:1 s:1 s:1 b+c:4', drums: true),
  ]);

  return Song(
    id: 'zone7',
    title: 'Grieta Ígnea',
    bpm: 88,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.35), melody),
      Track('zampoña', Inst.zampona, '.:128 ${shift(themeB, -12)}'),
      Track('bordón', Inst.pad.copyWith(volume: 0.07, lowpass: 900),
          rep('E2+B2:64', 4)),
      Track('metales', Inst.brass,
          comp(chords, 'x:2 .:6 x:2 .:2 x:2 .:2', center: 55, count: 3),
          gain: 0.8),
      Track('bajo', Inst.bassStaccato.copyWith(volume: 0.28), bass),
      Track.drums('bombo', drums, gain: 0.5),
    ],
  );
}

