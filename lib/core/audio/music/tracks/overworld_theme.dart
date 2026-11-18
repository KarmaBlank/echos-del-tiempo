import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Mapa del mundo.
///
/// Clima: salir de viaje. Paso de caminata con el balanceo del huayno
/// (semicorchea + corchea con punto, "ta-taka" del charango y del
/// bombo), esperanzado y con sensación de distancia: zampoñas que
/// llaman y responden con eco a lo lejos. Sol mixolidio (el Fa mayor,
/// VII grado, le da el aire épico de leyenda y la cadencia Fa → Sol)
/// que se va a su relativa Mi menor pentatónica en la B, como en la
/// música andina. 104 bpm, 2/4, 44 compases (50.8 s). Grilla de fusas
/// (8 pasos por negra) para los adornos de quena.
///
/// Forma: intro (1–4) charango, bombo y la llamada de una zampoña
/// lejana; A (5–20) tema de viaje de la ocarina en dos frases de 8
/// (semicadencia en Re, cierre Fa → Sol); B (21–28) Mi menor, la
/// ocarina canta un compás y la zampoña le contesta el siguiente
/// (hoquetus de sikus), con arpa y chajchas; A' (29–44) el tema otra
/// vez, más grande: sikus doblándolo una octava abajo, arpa y rasgueo
/// lleno.
///
/// Original: no cita ni imita de cerca ninguna melodía existente.
Song overworldTheme() {
  const intro = 'G F G G';
  const a = 'G G C G F F G D G G C Em C F G G';
  const b = 'Em D Em D C G D Em';
  final chI = ch(intro, 16);
  final chA = ch(a, 16);
  final chB = ch(b, 16);

  // Compás de 2/4 = 16 pasos (negra 8, corchea 4, semicorchea 2).
  String m(String s) => bar(s);
  final themeA = join([
    m('D5:2 G5:6 A5:4 B5:4'),
    m('A5:2 G5:6 D5:8'),
    m('E5:4 G5:4 A5:2 C6:6'),
    m('B5:1 A5:1 G5:14'), // grupeto de quena
    m('F5:2 A5:6 C6:4 A5:4'), // Fa natural: mixolidio
    m('G5:2 F5:6 D5:8'),
    m('D5:2 G5:6 B5:4 A5:4'),
    m('A5:1 G5:1 A5:14'),
    m('D5:2 G5:6 A5:4 B5:4'),
    m('A5:2 G5:6 D5:8'),
    m('E5:4 G5:4 A5:2 C6:6'),
    m('D6:1 B5:7 G5:4 E5:4'),
    m('G5:2 E5:6 D5:4 E5:4'),
    m('F5:2 A5:6 C6:8'),
    m('A5:2 B5:6 D6:4 B5:4'),
    m('C6:1 B5:1 A5:2 G5:12'),
  ]);
  // B: la ocarina pregunta, la zampoña contesta (hoquetus).
  final themeB = join([
    m('B5:2 A5:2 G5:4 E5:8'),
    m('.:16'),
    m('G5:2 A5:2 B5:4 D6:2 B5:6'),
    m('.:16'),
    m('G5:2 E5:6 G5:2 A5:6'),
    m('B5:2 A5:2 G5:2 D5:2 G5:8'),
    m('A5:2 B5:2 A5:2 F#5:2 D5:8'),
    m('F#5:1 E5:15'),
  ]);
  final melody = join(['.:64', themeA, themeB, themeA]);

  final call = join([
    // Intro: la llamada lejana.
    m('D5:2 G5:14'),
    m('.:8 F5:2 C5:6'),
    m('D5:2 G5:6 B5:2 A5:6'),
    m('G5:8 .:8'),
    '.:256',
    // B: respuestas.
    m('.:16'),
    m('D5:2 E5:2 D5:4 A4:8'),
    m('.:16'),
    m('F#5:2 E5:2 D5:4 B4:4 A4:4'),
    '.:64',
    '.:256',
  ]);
  final sikus = join(['.:64', '.:256', '.:128', shift(themeA, -12)]);

  const huayno = 'x:4 x:2 x:2 x:4 x:2 x:2';
  final drums = join([
    rep(bar('b:4 a:2 a:2 b:4 a:4', drums: true), 4),
    rep(bar('b:4 a:2 a:2 b:4 a:4', drums: true), 15),
    bar('b:4 a:2 a:2 b:2 b:2 b:2 b:2', drums: true),
    rep(bar('b:6 a:2 b:4 a:2 a:2', drums: true), 7),
    bar('b:2 b:2 b:2 b:2 a:2 a:2 b:4', drums: true),
    bar('b+c:4 a:2 a:2 b:4 a:4', drums: true),
    rep(bar('b:4 a:2 a:2 b:4 a:4', drums: true), 14),
    bar('b:4 a:2 a:2 b:2 b:2 a:2 a:2', drums: true),
  ]);
  final rattle = join([
    '.:320',
    rep(bar('h:4 h:2 h:2 h:4 h:2 h:2', drums: true), 24),
  ]);

  return Song(
    id: 'overworld',
    title: 'Mapa del mundo',
    bpm: 104,
    stepsPerBeat: 8,
    beatsPerBar: 2,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('zampoña', Inst.zamponaEcho, call),
      Track('sikus', Inst.zampona, sikus, gain: 0.9),
      Track('charango', Inst.charango,
          '${comp(chI, huayno, center: 71, count: 4)} '
          '${comp('$chA $chB $chA', huayno, center: 71, count: 4)}'),
      Track('arpa', Inst.arp,
          '.:320 '
          '${arp('$chB $chA', center: 64, count: 4, shape: const [0, 1, 2, 3, 4, 3, 2, 1], rhythm: 'x:2')}',
          gain: 0.8),
      Track('colchón', Inst.pad,
          '.:64 ${comp('$chA $chB $chA', 'x:16', center: 60, count: 3)}'),
      Track('bajo', Inst.bass.copyWith(volume: 0.19),
          '.:32 ${bassLine(ch('G G', 16), 'R:6 5:2 8:4 5:4')} '
          '${bassLine('$chA $chB $chA', 'R:6 5:2 8:4 5:4')}'),
      Track.drums('bombo', drums, gain: 0.55),
      Track.drums('chajchas', rattle, gain: 0.9),
    ],
  );
}
