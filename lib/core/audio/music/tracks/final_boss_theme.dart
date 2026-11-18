import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Jefe final · Devorador de Eras.
///
/// Clima: épico e intenso, la pelea por el tiempo mismo. Dos secciones
/// que se sienten como las dos fases del Devorador:
///
/// - **Fase 1 (1–16), épica**: el **tema del título** (autocita)
///   transformado en himno de batalla: la cabeza Re–Mi–Fa en corta–larga
///   y sus giros en Re menor, sobre charango rasgueado en semicorcheas,
///   bombo legüero + bombo de batería, quintas de metal y el bajo
///   galopando. Re m Si♭ Do Re m · Re m Si♭ Sol m La · Re m Fa Do Sol m ·
///   Si♭ Do La La (semicadencia).
/// - **Fase 2 (17–32), desatada**: el mismo tema en **disminución** (la
///   mitad de largo) y **mutando**: a la segunda vez la cabeza ya dice
///   Re–Mi♭–Fa (frigio) y la armonía se parte entre Re m y Mi♭, Si♭ y La,
///   La 7(♭9). El riff de pulso martilla semicorcheas, la batería pasa a
///   doble bombo y el charango calla: queda solo la pelea. Termina en La
///   para volver a la fase 1.
///
/// Re menor (eólico; frigio en la fase 2), 160 bpm, 4/4, 32 compases
/// (48 s). Es una variante del tema de jefe (`boss`): misma plantilla de
/// riff + doble + bajo staccato + batería, con el tema del título encima.
///
/// Original: el único material citado es el del propio tema del título.
Song finalBossTheme() {
  const p1 = 'Dm Bb C Dm Dm Bb Gm A Dm F C Gm Bb C A A';
  const p2 = 'Dm Eb Dm Eb Bb A Bb A Gm Eb A7b9 Dm Gm Eb A A';
  final ch1 = ch(p1, 16);
  final ch2 = ch(p2, 16);

  final phase1 = join([
    bar('D5:6 E5:2 F5:8'), // cabeza del título
    bar('G5:2 F5:6 D5:8'),
    bar('E5:4 G5:4 C6:8'),
    bar('D6:6 C6:2 A5:8'),
    bar('D5:6 E5:2 F5:8'),
    bar('Bb5:6 A5:2 F5:8'),
    bar('G5:4 Bb5:4 D6:4 C6:4'),
    bar('C#6:12 A5:4'),
    bar('D6:6 E6:2 F6:8'), // la cabeza, una 8va arriba
    bar('C6:6 A5:2 F5:8'),
    bar('G5:6 E5:2 C6:8'),
    bar('Bb5:6 A5:2 G5:8'),
    bar('F5:4 Bb5:4 D6:8'),
    bar('E6:4 D6:4 C6:4 G5:4'),
    bar('E5:4 A5:4 C#6:8'),
    bar('E6:8 C#6:4 A5:4'),
  ]);
  final phase2 = join([
    bar('D5:3 E5:1 F5:4 D5:3 Eb5:1 F5:4'), // disminución; muta a Mi♭
    bar('G5:6 Bb5:2 Eb6:8'),
    bar('D6:3 C6:1 A5:4 F5:3 E5:1 D5:4'),
    bar('Eb5:4 G5:4 Bb5:4 Eb6:4'),
    bar('D6:6 C6:2 Bb5:4 F5:4'),
    bar('C#6:6 A5:2 E5:8'),
    bar('F5:3 G5:1 Bb5:4 D6:8'),
    bar('C#6:4 E6:4 A5:8'),
    bar('G5:3 A5:1 Bb5:4 D6:8'),
    bar('Eb6:6 D6:2 Bb5:8'),
    bar('Bb5:3 A5:1 G5:4 E5:4 C#5:4'),
    bar('D5:3 Eb5:1 F5:4 A5:8'),
    bar('Bb5:3 A5:1 G5:4 D6:8'),
    bar('Eb6:3 D6:1 C6:4 Bb5:4 G5:4'),
    bar('A5:3 Bb5:1 A5:4 G5:4 E5:4'),
    bar('C#5:4 E5:4 A5:4 C#6:4'),
  ]);
  final melody = '$phase1 $phase2';

  // Fase 1: bombo legüero + kit, a medio tiempo. Fase 2: doble bombo.
  final epic = bar('b+k:2 h:2 a:2 h:2 s:2 h:2 b:2 a:2', drums: true);
  final epic2 = bar('b+k:2 h:2 a:2 b:2 s:2 h:2 b+k:2 s:2', drums: true);
  final fill1 = bar('s:2 s:2 T:2 T:2 t:2 t:2 s:1 s:1 s:1 s:1', drums: true);
  final beat = bar('k:1 k:1 h:2 s:2 h:1 k:1 k:1 k:1 h:2 s:2 h:2', drums: true);
  final beat2 = bar('k:1 k:1 h:2 s:2 k:1 k:1 k:1 k:1 s:1 k:1 s:2 o:2', drums: true);
  final fill2 = bar('s:1 s:1 s:1 s:1 T:1 T:1 T:1 T:1 t:1 t:1 t:1 t:1 s:1 s:1 s:1 s:1', drums: true);
  final crash = bar('c+k:1 k:1 h:2 s:2 h:1 k:1 k:1 k:1 h:2 s:2 h:2', drums: true);
  final drums = join([
    bar('b+k+c:2 h:2 a:2 h:2 s:2 h:2 b:2 a:2', drums: true),
    epic, epic, epic2, epic, epic, epic2, fill1,
    bar('b+k+c:2 h:2 a:2 h:2 s:2 h:2 b:2 a:2', drums: true),
    epic, epic, epic2, epic, epic2, epic2, fill1,
    crash, beat, beat2, beat, beat, beat2, beat, fill2,
    crash, beat, beat2, beat, beat, beat2, beat2, fill2,
  ]);

  return Song(
    id: 'bossFinal',
    title: 'Devorador de Eras',
    bpm: 160,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.36, attack: 0.02), melody),
      Track('doble', Inst.leadDouble.copyWith(volume: 0.06), melody),
      Track('charango', Inst.charango.copyWith(volume: 0.04),
          '${comp(ch1, 'x:2 x:2 x:2 x:2', center: 69, count: 4)} .:256'),
      Track('riff', Inst.harmony,
          '${arp(ch1, center: 57, count: 3, shape: const [0, 2, 1, 2], rhythm: 'x:2')} '
          '${arp(ch2, center: 57, count: 3, shape: const [0, 0, 2, 0, 1, 0, 2, 1])}'),
      Track('metal', Inst.brass,
          '${comp(ch1, 'x:6 x:2 x:8', center: 57, count: 2)} '
          '${comp(ch2, 'x:2 .:2 x:2 .:2 x:2 .:6', center: 57, count: 2)}',
          gain: 0.8),
      Track('bajo', Inst.bassStaccato,
          '${bassLine(ch1, 'R:2 R:1 R:1 8:2 R:2 5:2 R:2 8:2 5:2')} '
          '${bassLine(ch2, 'R:2 R:2 8:2 R:2 b:2 R:2 8:2 5:2')}'),
      Track.drums('batería', drums, gain: 0.6),
    ],
  );
}
