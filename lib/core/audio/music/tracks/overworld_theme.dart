import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Mapa del mundo.
///
/// Clima: campo tranquilo, cálido y sin apuro; la alegría tranquila de
/// salir a caminar por los prados de casa. La ocarina canta como un
/// silbato de lata, por grados conjuntos y con adornos leves, sobre un
/// arpa en corcheas y un colchón tibio. Sol mayor (jónico), 72 bpm
/// (negra con punto), 6/8, grilla de semicorcheas (6 pasos por pulso),
/// 34 compases (56.7 s). Lo andino queda en toques: un charango que
/// puntea (no rasguea) en la B y la A'' y una zampoña que contesta al
/// final de las frases.
///
/// Forma: intro (1–2) arpa y colchón; A (3–10) tema que baja por grados
/// desde el Re y vuelve al Sol; A' (11–18) igual al empezar, después
/// sube y cierra en el Sol agudo, con cuerdas; B (19–26) casera y suave,
/// más grave, por Mi menor y La menor, semicadencia en Re con la
/// respuesta de la zampoña; A'' (27–34) el tema de A' con todo (cuerdas,
/// charango punteado, pandero).
///
/// Original: no cita ni parafrasea ninguna melodía, ritmo ni armonía
/// existentes: solo se toma el clima pastoral.
Song overworldTheme() {
  const intro = 'G G';
  const a = 'G C G D G C D G';
  const a2 = 'G C G D Em C D G';
  const b = 'Em C G D C G Am D';
  final chI = ch(intro, 12);
  final chA = ch(a, 12);
  final chA2 = ch(a2, 12);
  final chB = ch(b, 12);
  final chords = '$chI $chA $chA2 $chB $chA2';

  // Compás de 6/8 = 12 pasos (corchea 2, negra 4, negra con punto 6).
  String m(String s) => bar(s, steps: 12);
  final head = [
    m('D5:4 C5:2 B4:4 A4:2'),
    m('E5:4 D5:2 C5:4 E5:2'),
    m('D5:6 B4:4 G4:2'),
    m('B4:1 A4:11'), // adorno leve
  ];
  final themeA = join([
    ...head,
    m('D5:4 C5:2 B4:4 A4:2'),
    m('E5:4 G5:2 E5:4 C5:2'),
    m('A4:4 B4:2 C5:4 A4:2'),
    m('A4:1 G4:11'),
  ]);
  final themeA2 = join([
    ...head,
    m('G5:4 F#5:2 E5:4 B4:2'),
    m('C5:4 D5:2 E5:4 G5:2'),
    m('F#5:4 E5:2 D5:6'),
    m('A5:1 G5:11'),
  ]);
  final themeB = join([
    m('B4:4 C5:2 B4:4 G4:2'),
    m('C5:4 B4:2 A4:6'),
    m('B4:4 C5:2 D5:6'),
    m('E5:4 D5:2 A4:6'),
    m('G5:6 E5:4 C5:2'),
    m('B4:4 D5:2 G5:6'),
    m('C5:1 B4:3 A4:2 C5:4 E5:2'),
    m('D5:6 .:6'),
  ]);
  final melody = join(['.:24', themeA, themeA2, themeB, themeA2]);

  // Zampoña: solo contesta al final de A y de B (lleva al Re del tema).
  final zampona = join([
    '.:24',
    '.:84',
    m('.:6 D5:2 E5:2 F#5:2'),
    '.:96',
    '.:84',
    m('.:6 A4:2 B4:2 C5:2'),
    '.:96',
  ]);

  // Cuerdas tibias (pulso con ataque lento): la nota de arriba del
  // acorde, tenida, en A' y A''.
  const strings = Instrument(
    voice: Voice.pulse25,
    volume: 0.06,
    attack: 0.3,
    decay: 0.4,
    sustain: 0.75,
    release: 0.4,
    gate: 0.97,
    lowpass: 1500,
    vibratoRate: 4.5,
    vibratoDepth: 0.004,
    vibratoDelay: 0.3,
  );
  final cuerdas = join([
    '.:120',
    comp(chA2, 'x:12', center: 69, count: 1),
    '.:96',
    comp(chA2, 'x:12', center: 69, count: 1),
  ]);

  // Charango punteado (una cuerda por vez, sin rasgueo) en B y A''.
  final charango = join([
    '.:216',
    arp('$chB $chA2', center: 76, count: 3, shape: const [0, 1, 2, 1],
        rhythm: 'x:2 .:1 x:1 x:2 x:2 .:2 x:2'),
  ]);

  // Pandero (tambor de marco) liviano: nada en la intro y la A.
  final drums = join([
    '.:120',
    rep(bar('t:6 t:4 t:2', steps: 12, drums: true), 8),
    rep(bar('t:12', steps: 12, drums: true), 8),
    rep(bar('t:6 t:4 t:2', steps: 12, drums: true), 8),
  ]);

  return Song(
    id: 'overworld',
    title: 'Mapa del mundo',
    bpm: 72,
    stepsPerBeat: 6,
    beatsPerBar: 2,
    tracks: [
      Track('ocarina', Inst.ocarina, melody),
      Track('zampoña', Inst.zampona, zampona, gain: 0.8),
      Track('arpa', Inst.arp,
          arp(chords, center: 62, count: 4, shape: const [0, 1, 2, 3, 2, 1],
              rhythm: 'x:2')),
      Track('colchón', Inst.pad, comp(chords, 'x:12', center: 60, count: 3)),
      Track('cuerdas', strings, cuerdas),
      Track('charango', Inst.charango.copyWith(strum: 0, volume: 0.06),
          charango),
      Track('bajo', Inst.bass.copyWith(volume: 0.2),
          bassLine(chords, 'R:6 5:6')),
      Track.drums('pandero', drums, gain: 0.35),
    ],
  );
}
