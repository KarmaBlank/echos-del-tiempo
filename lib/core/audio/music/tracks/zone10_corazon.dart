import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Zona 10 · Corazón del Tiempo.
///
/// Clima: solemne y ominoso, el centro de todo late. La ocarina **cita
/// el tema del título** ("Ecos del Tiempo", autocita): la cabeza Re–Mi–Fa
/// en corta–larga, el giro Mi–Do–Re, el grupeto de quena y la bajada a
/// la sensible; pero en Re menor natural (Si♭) y con el Mi♭ napolitano en
/// la armonía, así el tema de la leyenda suena ahora amenazado.
///
/// La tensión crece en tres capas a lo largo del bucle: A (1–8) solemne,
/// un latido de bombo legüero (lub-dub) por compás, bajo en redondas y
/// un colchón de órgano; B (9–16) el tema sube, la zampoña lo dobla una
/// 8va abajo, el latido se duplica, el reloj (tic) marca negras y el
/// bajo pasa a negras; C (17–20) clímax: la cabeza del tema en la 8va
/// aguda (y transformada: Mi♭ en lugar de Mi), arpegio en semicorcheas,
/// bajo en corcheas, redoble y quintas de metal hasta La 7(♭9) y La.
///
/// Re menor (eólico, con Mi♭ napolitano y La mayor de dominante), 76 bpm,
/// 4/4, 20 compases (≈ 63 s).
///
/// Original: el único material citado es el del propio tema del título.
Song zone10Corazon() {
  const a = 'Dm Bb Gm A Dm Eb Gm A';
  const b = 'Dm Bb Gm Eb Dm Bb Eb A';
  const c = 'Gm Eb A7b9 A';
  final chA = ch(a, 16);
  final chB = ch(b, 16);
  final chC = ch(c, 16);
  final chords = '$chA $chB $chC';

  final themeA = join([
    bar('D5:6 E5:2 F5:8'), // cabeza del título
    bar('E5:6 C5:2 D5:8'), // su giro Mi–Do–Re
    bar('Bb4:4 D5:4 G5:8'),
    bar('F5:2 E5:6 C#5:8'), // corta–larga
    bar('D5:6 E5:2 F5:8'),
    bar('G5:1 F5:1 G5:6 Bb5:8'), // grupeto de quena
    bar('A5:2 G5:6 F5:4 D5:4'),
    bar('E5:12 .:4'),
  ]);
  final themeB = join([
    bar('A5:6 Bb5:2 A5:8'),
    bar('D6:6 C6:2 Bb5:8'),
    bar('G5:4 Bb5:4 D6:8'),
    bar('Eb6:6 D6:2 Bb5:4 G5:4'),
    bar('F5:6 G5:2 A5:8'),
    bar('Bb5:1 A5:1 Bb5:6 D6:8'),
    bar('G5:6 Bb5:2 Eb6:8'),
    bar('C#6:12 .:4'),
  ]);
  final themeC = join([
    bar('D6:6 E6:2 F6:8'), // la cabeza, una 8va arriba
    bar('Eb6:6 C6:2 D6:8'), // el giro, con Mi♭
    bar('Bb5:4 A5:4 G5:4 E5:4'),
    bar('C#5:4 E5:4 A5:8'),
  ]);
  final melody = join([themeA, themeB, themeC]);

  final heart = bar('b:3 b:13', drums: true);
  final heart2 = bar('b:3 b:5 b:3 b:5', drums: true);
  final drums = join([
    rep(heart, 8),
    rep(heart2, 8),
    bar('b+c:3 b:5 b:3 b:5', drums: true),
    rep(bar('b:3 b:3 t:2 b:3 b:3 t:2', drums: true), 2),
    bar('s:1 s:1 s:1 s:1 s:1 s:1 s:1 s:1 T:2 T:2 t:2 t:2', drums: true),
  ]);
  final clock = join([
    '.:128',
    rep(bar('r:4 q:4 r:4 q:4', drums: true), 8),
    rep(bar('r:2 q:2 r:2 q:2 r:2 q:2 r:2 q:2', drums: true), 4),
  ]);

  return Song(
    id: 'zone10',
    title: 'Corazón del Tiempo',
    bpm: 76,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.36), melody),
      Track('zampoña', Inst.zampona,
          '.:128 ${shift(themeB, -12)} ${shift(themeC, -12)}'),
      Track('órgano', Inst.pad.copyWith(volume: 0.06, lowpass: 1500),
          comp(chords, 'x:16', center: 55, count: 3)),
      Track('arpa', Inst.arp, '.:256 ${arp(chC, center: 62, count: 3, shape: const [0, 1, 2, 3, 2, 1])}',
          gain: 0.8),
      Track('metal', Inst.brass,
          '.:256 ${comp(chC, 'x:4 x:4 x:8', center: 57, count: 2)}',
          gain: 0.75),
      Track('bajo', Inst.bass.copyWith(volume: 0.21),
          '${bassLine(chA, 'R:16')} ${bassLine(chB, 'R:4')} '
          '${bassLine(chC, 'R:2 R:2 8:2 R:2 R:2 R:2 8:2 5:2')}'),
      Track.drums('latido', drums, gain: 0.55),
      Track.drums('reloj', clock, gain: 0.9),
    ],
  );
}
