import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Zona 8 · Cementerio de Eras.
///
/// Clima: melancólico y escaso, lápidas de épocas que nadie recuerda.
/// Un vals lento y quieto: la ocarina canta frases cortas que se apagan,
/// campanitas sueltas (dos por compás, con eco), un colchón bajo, el
/// bajo en notas de compás entero y un bombo legüero lejano cada dos
/// compases, como una campana de duelo. Una zampoña con eco contesta al
/// final de cada frase.
///
/// Fa menor natural (eólico: Re♭ y Mi♭; la dominante es Do m, salvo un
/// Do mayor en la cadencia del B), 66 bpm, 3/4, 20 compases (≈ 55 s).
///
/// Forma: A (1–8) Fa m Re♭ Si♭m Do m Fa m La♭ Mi♭ Fa m; B (9–16) Re♭ La♭
/// Si♭m Fa m Re♭ Mi♭ Do sus4 Do, sube al La♭ agudo; coda (17–20) Fa m
/// Re♭ Si♭m Do m, baja y queda en Do para volver a empezar.
///
/// Original: no cita ni imita de cerca ninguna melodía existente.
Song zone8Cementerio() {
  const a = 'Fm Db Bbm Cm Fm Ab Eb Fm';
  const b = 'Db Ab Bbm Fm Db Eb Csus4 C';
  const coda = 'Fm Db Bbm Cm';
  final chords = ch('$a $b $coda', 12);

  // Compás de 3/4 = 12 pasos (negra 4).
  String m(String s) => bar(s, steps: 12);
  final melody = join([
    // A
    m('C5:8 Db5:2 C5:2'),
    m('Ab4:12'),
    m('Bb4:4 Db5:4 F5:4'),
    m('Eb5:9 .:3'),
    m('F5:6 Eb5:3 Db5:3'),
    m('C5:8 Eb5:4'),
    m('Bb4:6 G4:3 Bb4:3'),
    m('F4:6 .:6'),
    // B
    m('.:3 Ab5:6 F5:3'),
    m('Eb5:9 C5:3'),
    m('Db5:6 F5:3 Bb5:3'),
    m('Ab5:12'),
    m('F5:4 Eb5:4 Db5:4'),
    m('Eb5:6 G5:3 Bb5:3'),
    m('Ab5:6 G5:3 F5:3'),
    m('E5:6 .:6'),
    // Coda
    m('C5:6 Db5:3 C5:3'),
    m('Ab4:6 Bb4:3 C5:3'),
    m('Db5:6 C5:3 Bb4:3'),
    m('C5:6 .:6'),
  ]);

  // Respuestas de la zampoña en los silencios de la ocarina.
  final answers = join([
    '.:84', m('.:6 C5:3 F4:3'),
    '.:84', m('.:6 G4:3 C5:3'),
    '.:36', m('.:6 Eb5:3 C5:3'),
  ]);

  final toll = bar('b:12 .:12', steps: 24, drums: true);

  return Song(
    id: 'zone8',
    title: 'Cementerio de Eras',
    bpm: 66,
    beatsPerBar: 3,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(release: 0.18), melody),
      Track('zampoña', Inst.zamponaEcho, answers),
      Track('campanas', Inst.chime,
          arp(chords, center: 84, count: 3, shape: const [2, 0],
              rhythm: 'x:2 .:4 x:2 .:4')),
      Track('colchón', Inst.pad.copyWith(volume: 0.055),
          comp(chords, 'x:12', center: 58, count: 3)),
      Track('bajo', Inst.bass.copyWith(volume: 0.18), bassLine(chords, 'R:12')),
      Track.drums('campana de duelo', rep(toll, 10), gain: 0.4),
    ],
  );
}
