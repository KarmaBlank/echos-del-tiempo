import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Jefe secreto del Abismo · Eco Primordial (v0.8,
/// docs/specs/abyss_bosses.md § 4; music.md § 4).
///
/// Clima: lo más difícil del juego, todos los elementos a la vez. Do
/// menor con acordes aumentados y el tritono (Fa#) como color, y una
/// sección por "elemento" que cambia la textura cada 8 compases:
///
/// - **Origen (1–8)**: la ocarina sola en el agudo sobre el bajo en
///   negras y un pulso de bombo; acordes aumentados que no resuelven.
/// - **Reflejo (9–16)**: la melodía se repite un compás después a la
///   octava (eco), el riff entra en semicorcheas.
/// - **Primordial (17–32)**: el tema en disminución con la batería a
///   doble bombo, el metal en quintas y el bajo galopando; termina en Sol
///   para volver al principio.
///
/// Do menor, 156 bpm, 4/4, 32 compases (≈ 49 s). Original.
Song secretBossTheme() {
  const origen = 'Cm Abaug Cm F#dim Cm Abaug G G7';
  const reflejo = 'Cm Eb Abaug G Fm Ab G7b9 G';
  const p1 = 'Cm Db Cm Db Abaug G Cm G';
  const p2 = 'Fm F#dim Cm Abaug Db C Gsus4 G7';
  final first = ch(origen, 16);
  final rest = ch('$reflejo $p1 $p2', 16);

  final melody = join([
    // Origen
    bar('C6:12 D6:2 Eb6:2'),
    bar('E6:16'),
    bar('G6:8 Eb6:8'),
    bar('F#6:12 Eb6:4'),
    bar('C6:6 D6:2 Eb6:8'),
    bar('E6:6 C6:2 G#5:8'),
    bar('G5:8 B5:8'),
    bar('D6:8 F6:8'),
    // Reflejo
    bar('Eb6:6 D6:2 C6:4 G5:4'),
    bar('Bb5:6 G5:2 Eb6:8'),
    bar('C6:4 E6:4 G#6:8'),
    bar('G6:6 F6:2 D6:8'),
    bar('Ab5:6 C6:2 F6:8'),
    bar('Eb6:6 C6:2 Ab5:8'),
    bar('G5:4 B5:4 D6:4 Ab6:4'),
    bar('G6:16'),
    // Primordial (disminución)
    bar('C6:3 D6:1 Eb6:4 C6:3 Db6:1 Eb6:4'),
    bar('F6:6 Ab6:2 Db6:8'),
    bar('C6:3 Bb5:1 G5:4 Eb5:3 D5:1 C5:4'),
    bar('Db5:4 F5:4 Ab5:4 Db6:4'),
    bar('C6:6 E6:2 G#6:8'),
    bar('B5:6 D6:2 G6:8'),
    bar('Eb6:3 F6:1 G6:4 C7:8'),
    bar('B6:4 G6:4 D6:4 B5:4'),
    bar('Ab5:3 C6:1 F6:4 Ab6:8'),
    bar('F#6:6 Eb6:2 C6:8'),
    bar('G6:3 F6:1 Eb6:4 C6:4 G5:4'),
    bar('C6:4 E6:4 G#6:8'),
    bar('Db6:3 C6:1 Ab5:4 F5:4 Db5:4'),
    bar('C5:4 E5:4 G5:4 C6:4'),
    bar('G5:8 C6:4 D6:4'),
    bar('F6:4 D6:4 B5:4 G5:4'),
  ]);

  final pulse = bar('k:4 h:4 k:4 h:4', drums: true);
  final pulse2 = bar('k:4 h:4 k:2 k:2 s:4', drums: true);
  final beat = bar('k:1 k:1 h:2 s:2 h:1 k:1 k:1 k:1 h:2 s:2 h:2', drums: true);
  final beat2 = bar('k:1 k:1 h:2 s:2 k:1 k:1 k:1 k:1 s:1 k:1 s:2 o:2', drums: true);
  final fill = bar('s:1 s:1 s:1 s:1 T:1 T:1 T:1 T:1 t:1 t:1 t:1 t:1 s:1 s:1 s:1 s:1', drums: true);
  final crash = bar('c+k:1 k:1 h:2 s:2 h:1 k:1 k:1 k:1 h:2 s:2 h:2', drums: true);
  final drums = join([
    bar('c+k:4 h:4 k:4 h:4', drums: true), pulse, pulse, pulse2, pulse, pulse, pulse2, fill,
    crash, beat, beat2, beat, beat, beat2, beat, fill,
    crash, beat, beat2, beat, beat, beat2, beat, fill,
    crash, beat, beat2, beat, beat, beat2, beat2, fill,
  ]);

  return Song(
    id: 'bossSecret',
    title: 'Eco Primordial',
    bpm: 156,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.36, attack: 0.02), melody),
      Track('doble', Inst.leadDouble.copyWith(volume: 0.06), melody),
      Track('riff', Inst.harmony,
          '${comp(first, 'x:8 x:8', center: 60, count: 3)} '
          '${arp(rest, center: 57, count: 3, shape: const [0, 2, 1, 2, 0, 1, 2, 1])}'),
      Track('metal', Inst.brass,
          '${comp(ch('$origen $reflejo', 16), 'x:12 .:4', center: 55, count: 2)} '
          '${comp(ch('$p1 $p2', 16), 'x:6 x:2 x:8', center: 55, count: 2)}',
          gain: 0.7),
      Track('bajo', Inst.bassStaccato,
          '${bassLine(first, 'R:4 R:4 5:4 R:4')} '
          '${bassLine(rest, 'R:2 R:1 R:1 8:2 R:2 5:2 R:2 8:2 5:2')}'),
      Track.drums('batería', drums, gain: 0.7),
    ],
  );
}
