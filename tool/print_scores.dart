// Imprime la melodía (voz ocarina) de cada pieza del catálogo de música
// como partitura de texto: una nota por casilla, `-` sostiene, `.` es
// silencio, `|` separa compases. Uso:
//   dart run tool/print_scores.dart > docs/partituras.md
import 'package:echos_del_tiempo/core/audio/music/music_catalog.dart';
import 'package:echos_del_tiempo/core/audio/music/music_score.dart';

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

void main() {
  final out = StringBuffer()
    ..writeln('# Partituras — Ecos del Tiempo')
    ..writeln()
    ..writeln('Melodía principal (voz ocarina) de cada pieza. Cada casilla es '
        'un tiempo de la grilla indicada; `-` sostiene la nota anterior, '
        '`.` es silencio y `|` separa compases. Generado con '
        '`dart run tool/print_scores.dart`.')
    ..writeln();

  for (final song in kMusicCatalog.values) {
    final lead = song.tracks.firstWhere(
      (t) => t.instrument.voice.name == 'ocarina',
      orElse: () => song.tracks.firstWhere((t) => !t.isDrums),
    );
    final barSteps = song.stepsPerBeat * song.beatsPerBar;
    var g = barSteps;
    for (final e in lead.events) {
      g = _gcd(g, e.start);
      g = _gcd(g, e.length);
    }
    if (g == 0) g = 1;

    // Una casilla por grilla.
    final cells = List<String>.filled(lead.steps ~/ g, '.');
    for (final e in lead.events) {
      final i = e.start ~/ g;
      final name = midiToNote(e.midi!);
      cells[i] = cells[i] == '.' || cells[i] == '-' ? name : '${cells[i]}+$name';
      for (var k = 1; k < e.length ~/ g; k++) {
        if (i + k < cells.length && cells[i + k] == '.') cells[i + k] = '-';
      }
    }

    final perBar = barSteps ~/ g;
    final bars = <String>[
      for (var b = 0; b < cells.length; b += perBar)
        cells.sublist(b, (b + perBar).clamp(0, cells.length)).join(' '),
    ];
    final meter = song.stepsPerBeat == 3
        ? '${song.beatsPerBar * 3}/8'
        : '${song.beatsPerBar}/4';
    final unitDiv = song.stepsPerBeat == 3 ? 8 * 3 ~/ 3 : 4 * song.stepsPerBeat;
    final unit = '1/${unitDiv ~/ g}';

    out
      ..writeln('## ${song.title} (`${song.id}`)')
      ..writeln()
      ..writeln('${song.bpm.toStringAsFixed(0)} bpm · $meter · '
          '${bars.length} compases · cada casilla = $unit'
          '${song.loop ? ' · se repite en bucle' : ' · jingle'}')
      ..writeln()
      ..writeln('```');
    for (var b = 0; b < bars.length; b += 4) {
      final end = (b + 4).clamp(0, bars.length);
      out
        ..writeln('[Compases ${b + 1}-$end]')
        ..writeln(bars.sublist(b, end).join(' | '));
    }
    out
      ..writeln('```')
      ..writeln();
  }
  // ignore: avoid_print
  print(out);
}
