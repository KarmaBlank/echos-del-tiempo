import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Título · "Ecos del Tiempo".
///
/// Clima: épico-pastoral con alma andina. Una canción lenta de quena
/// (yaraví) que la ocarina canta sola sobre un arpa, y que después se
/// vuelve heroica con charango rasgueado, bombo legüero y zampoñas.
/// Re dórico (Re menor con Si natural: el Sol mayor del IV es el color
/// "de leyenda"), 80 bpm, 3/4, 26 compases (58.5 s). Grilla de fusas
/// (8 pasos por negra) para los adornos de quena (apoyaturas y
/// grupetos de un paso).
///
/// Forma: A (1–8) tierna, ocarina + arpa + bombo suave, cadencia
/// plagal Sol → Re m; A' (9–16) el mismo tema más grande: zampoñas que
/// lo doblan una octava abajo, charango, colchón, y queda abierto en
/// La sus4; B (17–24) heroica: saltos por arpegios de Fa y Sol mayor
/// hasta el Re agudo, rasgueo lleno y "metal" de pulso, semicadencia en
/// La sus4; coda (25–26) la ocarina baja por la pentatónica y la
/// zampoña responde (hoquetus) dejando La para volver a empezar.
///
/// Original: no cita ni imita de cerca ninguna melodía existente.
Song titleTheme() {
  const a = 'Dm Csus2 F G Dm Am G Dm';
  const a2 = 'Dm Csus2 F G Dm Am G Asus4';
  const b = 'F C Dm G F C G Asus4';
  const coda = 'Dsus2 Dm';
  final chA = ch(a, 24);
  final chA2 = ch(a2, 24);
  final chB = ch(b, 24);
  final chCoda = ch(coda, 24);
  final chords = '$chA $chA2 $chB $chCoda';

  // Compás de 3/4 = 24 pasos (negra 8, corchea 4, semicorchea 2).
  String m(String s) => bar(s, steps: 24);
  final phrase = [
    m('D5:12 E5:4 F5:8'),
    m('G5:1 E5:11 C5:4 D5:8'), // apoyatura de quena
    m('A4:8 C5:8 F5:8'),
    m('E5:2 D5:6 B4:16'), // corta–larga (huayno), Si dórico
    m('D5:12 E5:4 F5:8'),
    m('A5:1 G5:1 A5:6 C6:8 A5:8'), // grupeto
    m('G5:2 F5:6 E5:4 D5:4 B4:8'),
  ];
  final themeA = join([...phrase, m('C5:1 D5:23')]);
  final themeA2 = join([...phrase, m('E5:16 .:8')]);
  final themeB = join([
    m('C5:4 F5:4 A5:16'),
    m('G5:2 E5:6 G5:8 C6:8'),
    m('D6:1 A5:15 F5:4 D5:4'),
    m('D5:4 G5:4 B5:16'),
    m('C6:12 A5:4 F5:8'),
    m('G5:2 E5:6 C5:8 E5:8'),
    m('D5:4 G5:4 B5:8 A5:4 G5:4'),
    m('B5:1 A5:23'),
  ]);
  final melody = join([
    themeA,
    themeA2,
    themeB,
    m('.:8 A5:2 G5:2 F5:2 E5:2 D5:8'),
    m('.:24'),
  ]);

  // Zampoñas: callan en A, doblan el tema una 8va abajo en A' (sikus),
  // sostienen una nota del acorde en B y responden en la coda.
  final zampona = join([
    '.:192',
    shift(themeA2, -12),
    comp(chB, 'x:16 x:8', center: 65, count: 1),
    m('.:24'),
    m('.:4 E5:2 D5:2 C5:2 A4:14'),
  ]);

  // Charango: entra en A' con un rasgueo de yaraví y se llena en B.
  final charango = join([
    '.:192',
    comp(chA2, 'x:8 x:4 x:4 x:8', center: 72, count: 4),
    comp(chB, 'x:4 x:2 x:2 x:4 x:4 x:4 x:4', center: 72, count: 4),
    comp(chCoda, 'x:24', center: 72, count: 4),
  ]);

  // "Metal" de pulso (cuerno heroico) solo en B: quintas abiertas.
  final horn = join([
    '.:384',
    comp(chB, 'x:16 x:8', center: 57, count: 2),
    '.:48',
  ]);

  final drums = join([
    // A: un golpe de bombo por compás.
    rep(bar('b:24', steps: 24, drums: true), 7),
    bar('b:16 a:4 a:4', steps: 24, drums: true),
    // A'
    rep(bar('b:8 a:8 a:8', steps: 24, drums: true), 7),
    bar('b:8 b:4 b:4 a:4 a:4', steps: 24, drums: true),
    // B (platillo al entrar)
    bar('b+c:8 a:4 b:4 a:8', steps: 24, drums: true),
    rep(bar('b:8 a:4 b:4 a:8', steps: 24, drums: true), 6),
    bar('b:8 b:4 b:4 a:4 a:4', steps: 24, drums: true),
    // Coda
    bar('b:24', steps: 24, drums: true),
    bar('b:16 a:4 a:4', steps: 24, drums: true),
  ]);

  // Chajchas (sonajero de pezuñas) en B.
  final rattle = join([
    '.:384',
    rep(bar('h:4 h:2 h:2 h:4 h:4 h:4 h:4', steps: 24, drums: true), 8),
    '.:48',
  ]);

  return Song(
    id: 'title',
    title: 'Ecos del Tiempo',
    bpm: 80,
    stepsPerBeat: 8,
    beatsPerBar: 3,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('zampoña', Inst.zampona, zampona),
      Track('arpa', Inst.arp,
          '${arp(chA, center: 62, count: 4, shape: const [0, 1, 2, 3, 2, 1], rhythm: 'x:4')} '
          '${arp('$chA2 $chB $chCoda', center: 62, count: 4, shape: const [0, 1, 2, 3, 4, 3, 2, 1, 2, 3, 2, 1], rhythm: 'x:2')}',
          gain: 0.9),
      Track('charango', Inst.charango, charango),
      Track('metal', Inst.brass, horn, gain: 0.8),
      Track('colchón', Inst.pad, comp(chords, 'x:24', center: 57, count: 3)),
      Track('bajo', Inst.bass.copyWith(volume: 0.19),
          '${bassLine(chA, 'R:24')} ${bassLine(chA2, 'R:16 5:8')} '
          '${bassLine(chB, 'R:8 5:8 8:8')} ${bassLine(chCoda, 'R:24')}'),
      Track.drums('bombo', drums, gain: 0.55),
      Track.drums('chajchas', rattle, gain: 0.9),
    ],
  );
}
