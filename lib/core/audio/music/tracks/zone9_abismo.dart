import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Zona 9 · Abismo del Tiempo.
///
/// Clima: inmenso y flotando, islas sueltas sobre un vacío sin fondo.
/// La ocarina canta notas largas con un eco largo (3 repeticiones a una
/// corchea con punto, casi una reverberación), un colchón de ataque muy
/// lento con acordes suspendidos, cuerdas tibias que sostienen la nota
/// de arriba, campanitas como estrellas lejanas y el bajo en redondas.
/// Sin batería: solo un platillo suave que "respira" cada 4 compases.
///
/// La lidio (Re sostenido: el Si mayor sobre el pedal de La, II/I, es el
/// color que flota), 76 bpm, 4/4, 16 compases (≈ 51 s).
///
/// Forma: A (1–8) La sus2 Si/La La maj7 Si/La Do#m7 Si Mi sus4 Mi;
/// B (9–16) Fa#m7 Mi sus2 La maj7 Si/La Fa#m7 Do#m7 Si sus4 Si: el II
/// mayor del final vuelve al La sus2 sin cadencia (nunca "aterriza").
///
/// Original: no cita ni imita de cerca ninguna melodía existente.
Song zone9Abismo() {
  const a = 'Asus2 B/A Amaj7 B/A C#m7 B Esus4 E';
  const b = 'F#m7 Esus2 Amaj7 B/A F#m7 C#m7 Bsus4 B';
  final chords = ch('$a $b', 16);

  final melody = join([
    // A
    bar('E5:8 B5:8'),
    bar('D#6:12 C#6:4'),
    bar('G#5:16'),
    bar('F#5:4 D#5:4 B5:8'),
    bar('E5:6 G#5:2 B5:8'),
    bar('D#6:8 C#6:4 B5:4'),
    bar('A5:12 B5:4'),
    bar('G#5:12 .:4'),
    // B
    bar('C#6:8 A5:4 E5:4'),
    bar('F#5:8 B5:8'),
    bar('G#5:6 A5:2 C#6:8'),
    bar('D#6:16'),
    bar('E6:8 C#6:4 A5:4'),
    bar('B5:8 G#5:4 E5:4'),
    bar('E5:8 F#5:8'),
    bar('D#5:12 .:4'),
  ]);

  final breath = join([
    bar('c:16', drums: true),
    '.:48',
  ]);

  return Song(
    id: 'zone9',
    title: 'Abismo del Tiempo',
    bpm: 76,
    tracks: [
      Track('ocarina',
          Inst.ocarinaEcho.copyWith(
              release: 0.3, echoSteps: 6, echoGain: 0.45, vibratoDepth: 0.005),
          melody),
      Track('colchón',
          Inst.pad.copyWith(volume: 0.06, attack: 0.9, release: 1.2),
          comp(chords, 'x:16', center: 60, count: 3)),
      Track('cuerdas',
          const Instrument(
            voice: Voice.pulse25,
            volume: 0.04,
            attack: 0.6,
            decay: 0.4,
            sustain: 0.8,
            release: 0.8,
            lowpass: 2400,
          ),
          comp(chords, 'x:16', center: 69, count: 1)),
      Track('estrellas', Inst.chime.copyWith(volume: 0.07, echoSteps: 6, echoGain: 0.5),
          arp(chords, center: 88, count: 4, shape: const [3, 1, 2, 0],
              rhythm: '.:4 x:2 .:6 x:2 .:2')),
      Track('bajo', Inst.bass.copyWith(volume: 0.18, release: 0.3),
          bassLine(chords, 'R:16')),
      Track.drums('aire', rep(breath, 4), gain: 0.5),
    ],
  );
}
