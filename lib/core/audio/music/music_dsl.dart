/// Ayudas para escribir partituras: cifrados, arpegios, bajos y
/// compases validados. Todo devuelve texto en la notación de
/// `music_score.dart` (docs/specs/music.md § 2).
library;

import 'music_score.dart';

/// Un acorde cifrado (`Dm`, `F#m7`, `D/C`, `Gmaj7`, `Asus4`).
class Chord {
  const Chord(this.root, this.intervals, this.bass);

  /// Clase de altura (0 = do) de la fundamental y del bajo.
  final int root;
  final int bass;

  /// Intervalos (semitonos) desde la fundamental.
  final List<int> intervals;

  static const _qualities = <String, List<int>>{
    '': [0, 4, 7],
    'm': [0, 3, 7],
    '7': [0, 4, 7, 10],
    'm7': [0, 3, 7, 10],
    'maj7': [0, 4, 7, 11],
    'sus2': [0, 2, 7],
    'sus4': [0, 5, 7],
    'dim': [0, 3, 6],
    'aug': [0, 4, 8],
    '5': [0, 7],
    'add9': [0, 4, 7, 14],
    'madd9': [0, 3, 7, 14],
    '7b9': [0, 4, 7, 10, 13],
  };

  static final _re = RegExp(r'^([A-G][#b]?)([a-z0-9]*)(?:/([A-G][#b]?))?$');

  static Chord parse(String name) {
    final m = _re.firstMatch(name);
    final quality = m == null ? null : _qualities[m.group(2)];
    if (m == null || quality == null) {
      throw FormatException('acorde desconocido', name);
    }
    final root = noteToMidi('${m.group(1)}0')! % 12;
    final slash = m.group(3);
    return Chord(
        root, quality, slash == null ? root : noteToMidi('${slash}0')! % 12);
  }

  /// Notas del acorde (todas las octavas) más cercanas a [center],
  /// [count] de ellas, de grave a agudo: conducción de voces suave.
  List<int> voiced(int center, int count) {
    final all = <int>{
      for (var oct = 1; oct <= 8; oct++)
        for (final i in intervals) 12 * oct + root + i,
    }.toList()
      ..sort((a, b) {
        final d = (a - center).abs().compareTo((b - center).abs());
        return d != 0 ? d : a.compareTo(b);
      });
    return all.take(count).toList()..sort();
  }
}

/// `'Dm Bb F C'` con [steps] pasos cada uno → `'Dm:16 Bb:16 F:16 C:16'`.
String ch(String names, int steps) => names
    .split(RegExp(r'\s+'))
    .where((s) => s.isNotEmpty)
    .map((s) => '$s:$steps')
    .join(' ');

/// Acordes de un cifrado `'Dm:16 Bb:16'` (`.:n` = sin acorde).
List<(Chord?, int)> parseChords(String chords) => [
      for (final t in chords.split(RegExp(r'\s+')))
        if (t.isNotEmpty && t != '|')
          () {
            final i = t.lastIndexOf(':');
            if (i <= 0) throw FormatException('falta la duración', t);
            final name = t.substring(0, i);
            final n = int.parse(t.substring(i + 1));
            return (name == '.' ? null : Chord.parse(name), n);
          }(),
    ];

/// Tokens de ritmo `x`, `.`, `-` con duración opcional (`x:2`).
List<(String, int)> _rhythm(String rhythm) => [
      for (final t in rhythm.split(RegExp(r'\s+')))
        if (t.isNotEmpty && t != '|')
          () {
            final i = t.lastIndexOf(':');
            return i <= 0
                ? (t, 1)
                : (t.substring(0, i), int.parse(t.substring(i + 1)));
          }(),
    ];

/// Recorre [rhythm] en bucle durante cada acorde de [chords] y escribe
/// [hit] en cada `x` (con el índice de golpe dentro del acorde), silencio
/// en `.` y liga en `-`.
String _perChord(String chords, String rhythm,
    String Function(Chord chord, int hitIndex) hit) {
  final r = _rhythm(rhythm);
  final out = <String>[];
  for (final (chord, steps) in parseChords(chords)) {
    if (chord == null) {
      out.add('.:$steps');
      continue;
    }
    var pos = 0, ri = 0, hits = 0;
    while (pos < steps) {
      final (kind, len) = r[ri++ % r.length];
      final l = len < steps - pos ? len : steps - pos;
      switch (kind) {
        case 'x':
          out.add('${hit(chord, hits++)}:$l');
        case '.':
          out.add('.:$l');
        case '-':
          out.add('-:$l');
        default:
          throw FormatException('ritmo desconocido', kind);
      }
      pos += l;
    }
  }
  return out.join(' ');
}

/// Arpegio: en cada `x` del [rhythm] la nota siguiente de [shape] sobre
/// el acorde voiceado cerca de [center] con [count] notas (un índice
/// ≥ count sube de octava).
String arp(String chords,
    {int center = 64,
    int count = 3,
    List<int> shape = const [0, 1, 2, 1],
    String rhythm = 'x'}) {
  return _perChord(chords, rhythm, (c, i) {
    final tones = c.voiced(center, count);
    final k = shape[i % shape.length];
    return midiToNote(tones[k % tones.length] + 12 * (k ~/ tones.length));
  });
}

/// Acordes / díadas con ritmo: en cada `x` suenan juntas las [count]
/// notas del acorde más cercanas a [center].
String comp(String chords, String rhythm, {int center = 64, int count = 2}) =>
    _perChord(chords, rhythm,
        (c, _) => c.voiced(center, count).map(midiToNote).join('+'));

/// Línea de bajo: [pattern] se repite desde el principio de cada acorde.
/// Tokens (con `:n` opcional): `R`/`1` bajo (o nota de la barra), `3`
/// tercera, `5` quinta, `7` séptima (b7 si el acorde no la tiene), `8`
/// octava, `4` cuarta, `6` sexta, `L` quinta abajo, `b` semitono abajo,
/// `w` tono abajo, `.` silencio, `-` liga.
String bassLine(String chords, String pattern, {int octave = 2}) {
  final p = _rhythm(pattern);
  final out = <String>[];
  for (final (chord, steps) in parseChords(chords)) {
    if (chord == null) {
      out.add('.:$steps');
      continue;
    }
    final base = 12 * (octave + 1);
    final bass = base + chord.bass;
    final root = base + chord.root;
    final iv = chord.intervals;
    var pos = 0, pi = 0;
    while (pos < steps) {
      final (kind, len) = p[pi++ % p.length];
      final l = len < steps - pos ? len : steps - pos;
      final int? midi = switch (kind) {
        'R' || '1' => bass,
        '3' => root + iv[1],
        '5' => root + (iv.length > 2 ? iv[2] : iv.last),
        '7' => root + (iv.length > 3 ? iv[3] : 10),
        '8' => bass + 12,
        '4' => bass + 5,
        '6' => bass + 9,
        'L' => bass - 5,
        'b' => bass - 1,
        'w' => bass - 2,
        '.' || '-' => null,
        _ => throw FormatException('bajo desconocido', kind),
      };
      out.add(midi == null ? '$kind:$l' : '${midiToNote(midi)}:$l');
      pos += l;
    }
  }
  return out.join(' ');
}

/// Un compás (o frase) de [steps] pasos: lanza [ArgumentError] si no
/// mide eso (atrapa errores de conteo al componer).
String bar(String s, {int steps = 16, bool drums = false}) {
  final n = parseScore(s, drums: drums).steps;
  if (n != steps) {
    throw ArgumentError('el compás mide $n pasos, no $steps: "$s"');
  }
  return s;
}

/// [s] repetido [n] veces.
String rep(String s, int n) => List.filled(n, s).join(' ');

/// Une frases.
String join(List<String> parts) => parts.join(' ');
