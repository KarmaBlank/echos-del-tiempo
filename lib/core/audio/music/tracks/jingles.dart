import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Jingle de victoria.
///
/// Fanfarria corta y alegre: la ocarina sube por el acorde de Do, gira
/// sobre Fa y Sol y se queda arriba en el Do agudo; metales de pulso en
/// golpes y redoble con platillo al final. Do mayor, 140 bpm, 3 compases
/// (≈ 5 s), sin bucle.
Song victoryJingle() {
  const chords = 'C:16 F:8 G:8 C:16';
  return Song(
    id: 'jingle.victory',
    title: 'Victoria',
    bpm: 140,
    loop: false,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.36),
          join([
            bar('G5:2 C5:2 E5:2 G5:4 F5:2 E5:2 F5:2'),
            bar('A5:4 G5:2 E5:2 D5:2 E5:2 G5:4'),
            bar('C6:14 .:2'),
          ])),
      Track('metales', Inst.brass,
          comp(chords, 'x:2 .:2 x:1 .:1 x:2 .:8', center: 67, count: 3)),
      Track('bajo', Inst.bass, bassLine(chords, 'R:4 5:4 8:4 5:4')),
      Track.drums('batería',
          join([
            bar('k:2 s:2 h:2 s:2 k:2 s:2 h:2 s:2', drums: true),
            bar('k:2 s:2 h:2 s:2 s:1 s:1 s:1 s:1 T:2 t:2', drums: true),
            bar('c+k:16', drums: true),
          ]),
          gain: 0.6),
    ],
  );
}

/// Jingle de derrota.
///
/// Línea que baja despacio sobre La menor y Fa, y termina en Mi
/// (dominante sin resolver: queda en suspenso). La menor, 76 bpm, 2
/// compases (≈ 6 s), sin bucle.
Song defeatJingle() {
  const chords = 'Am:16 F:8 E:8';
  return Song(
    id: 'jingle.defeat',
    title: 'Derrota',
    bpm: 76,
    loop: false,
    tracks: [
      Track('ocarina', Inst.ocarinaEcho,
          join([
            bar('E5:6 D5:2 C5:4 B4:4'),
            bar('C5:4 B4:4 A4:8'),
          ])),
      Track('colchón', Inst.pad.copyWith(volume: 0.07),
          comp(chords, 'x:16', center: 60, count: 3)),
      Track('bajo', Inst.bass, bassLine(chords, 'R:16')),
    ],
  );
}

/// Jingle de subida de nivel.
///
/// Arpegio rápido que sube por Re mayor, toca Sol y La y se posa en el
/// Re agudo. Re mayor, 160 bpm, 24 pasos (≈ 2.3 s), sin bucle.
Song levelUpJingle() {
  const chords = 'D:6 G:4 A:6 D:8';
  return Song(
    id: 'jingle.levelUp',
    title: 'Subida de nivel',
    bpm: 160,
    loop: false,
    tracks: [
      Track('ocarina', Inst.ocarina.copyWith(volume: 0.36, attack: 0.015),
          bar('A4:1 D5:1 F#5:1 A5:1 G5:1 B5:1 D6:2 C#6:2 E6:2 D6:8 .:4',
              steps: 24)),
      Track('chispas', Inst.arp,
          arp(chords, center: 74, count: 3, shape: const [0, 1, 2])),
      Track('bajo', Inst.bass, bassLine(chords, 'R:2 8:2 5:2')),
    ],
  );
}

/// Jingle de ascensión (docs/specs/ascension.md § 5).
///
/// Revelación solemne: acordes que suben por Re menor → Si♭ → Do → Re
/// mayor (tercera de picardía), la ocarina asciende hasta el La agudo y
/// se queda; campanitas y redoble final. 104 bpm, 3 compases (≈ 6.9 s),
/// sin bucle.
Song ascensionJingle() {
  const chords = 'Dm:8 Bb:8 C:8 D:24';
  return Song(
    id: 'jingle.ascension',
    title: 'Ascensión',
    bpm: 104,
    loop: false,
    tracks: [
      Track('ocarina', Inst.ocarinaEcho,
          join([
            bar('D5:4 F5:4 Bb4:4 D5:4'),
            bar('E5:4 G5:4 F#5:8'),
            bar('A5:12 .:4'),
          ])),
      Track('colchón', Inst.pad.copyWith(volume: 0.08),
          comp(chords, 'x:8', center: 62, count: 3)),
      Track('campanitas', Inst.chime,
          arp(chords, center: 86, count: 3, shape: const [0, 1, 2], rhythm: 'x:4')),
      Track('bajo', Inst.bass, bassLine(chords, 'R:8')),
      Track.drums('batería',
          join([
            bar('k:8 .:8', drums: true),
            bar('k:8 s:2 s:2 s:2 s:2', drums: true),
            bar('c+k:16', drums: true),
          ]),
          gain: 0.5),
    ],
  );
}

/// Jingle de zona desbloqueada.
///
/// Revelación: la ocarina sube por Mi♭ con el La natural (cuarta
/// aumentada, lidio) y llega al Mi♭ agudo; arpegio de pulso que brilla
/// y campanitas. Mi♭ mayor lidio, 96 bpm, 2 compases (5 s), sin bucle.
Song zoneUnlockedJingle() {
  const chords = 'Eb:8 F/Eb:8 Ab:8 Eb:8';
  return Song(
    id: 'jingle.zoneUnlocked',
    title: 'Zona desbloqueada',
    bpm: 96,
    loop: false,
    tracks: [
      Track('ocarina', Inst.ocarinaEcho,
          join([
            bar('Bb4:2 Eb5:2 G5:2 A5:6 Bb5:4'),
            bar('C6:4 D6:4 Eb6:8'),
          ])),
      Track('brillo', Inst.arp,
          arp(chords, center: 70, count: 4, shape: const [0, 1, 2, 3])),
      Track('campanitas', Inst.chime,
          arp(chords, center: 87, count: 3, shape: const [2, 0], rhythm: 'x:4')),
      Track('bajo', Inst.bass, bassLine(chords, 'R:8')),
    ],
  );
}
