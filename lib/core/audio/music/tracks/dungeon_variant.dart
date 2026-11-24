import '../instruments.dart';
import '../music_dsl.dart';
import '../music_score.dart';

/// Dungeon arrangement of a biome theme (docs/specs/music.md § 4.3).
///
/// The ocarina keeps the very same playable melody (same register); the
/// danger comes from the accompaniment:
///
/// - **mode shift**: every note whose interval above [tonic] (pitch
///   class) is in [flatten] goes down a semitone, in every pitched
///   track, so the whole piece turns minor / darker together;
/// - **lower accompaniment**: the non-lead, non-bass pitched tracks go
///   down an octave;
/// - **pulsing bass**: the lowest track is re-articulated in eighth
///   notes (an ostinato on the same roots);
/// - **heartbeat drums**: a kick on every beat with a low tom answer;
/// - **faster**: [tempo] × the lobby bpm.
Song dungeonVariant(
  Song lobby, {
  required String id,
  required String title,
  required int tonic,
  Set<int> flatten = const {},
  double tempo = 1.12,
}) {
  int mode(int m) => flatten.contains((m - tonic) % 12) ? m - 1 : m;

  final pitched = [
    for (final t in lobby.tracks.skip(1))
      if (!t.isDrums) t,
  ];
  Track? bass;
  var lowest = 1 << 30;
  for (final t in pitched) {
    final notes = [for (final e in t.events) if (e.midi != null) e.midi!];
    if (notes.isEmpty) continue;
    final avg = notes.reduce((a, b) => a + b) ~/ notes.length;
    if (avg < lowest) {
      lowest = avg;
      bass = t;
    }
  }

  final lead = lobby.tracks.first.mapped(pitch: mode);
  final tracks = <Track>[lead];
  for (final t in lobby.tracks.skip(1)) {
    if (t.isDrums) {
      tracks.add(t.mapped(gain: t.gain * 0.8));
    } else if (identical(t, bass)) {
      tracks.add(t.mapped(pitch: mode));
    } else {
      tracks.add(t.mapped(pitch: (m) => mode(m) - 12));
    }
  }

  // Pulsing bass: each bass note becomes eighth notes on the same pitch.
  if (bass != null) {
    final pulse = StringBuffer();
    var pos = 0;
    final eighth = lobby.stepsPerBeat >= 4 ? lobby.stepsPerBeat ~/ 2 : 1;
    for (final e in bass.events) {
      if (e.midi == null || e.start < pos) continue;
      if (e.start > pos) pulse.write('.:${e.start - pos} ');
      var left = e.length;
      while (left > 0) {
        final l = left < eighth ? left : eighth;
        pulse.write('${midiToNote(mode(e.midi!))}:$l ');
        left -= l;
      }
      pos = e.start + e.length;
    }
    if (pos < lobby.steps) pulse.write('.:${lobby.steps - pos}');
    tracks.add(Track('pulse', Inst.bassStaccato.copyWith(volume: 0.12),
        pulse.toString().trim()));
  }

  // Heartbeat: kick on every beat, low tom on the off-beat of the last.
  final spb = lobby.stepsPerBeat;
  final beats = [
    for (var i = 0; i < lobby.beatsPerBar; i++)
      i == lobby.beatsPerBar - 1 && spb > 1
          ? 'k:${spb - spb ~/ 2} t:${spb ~/ 2}'
          : 'k:$spb',
  ].join(' ');
  tracks.add(Track.drums(
      'heartbeat',
      rep(bar(beats, steps: lobby.stepsPerBar, drums: true), lobby.bars),
      gain: 0.45));

  return Song(
    id: id,
    title: title,
    bpm: lobby.bpm * tempo,
    stepsPerBeat: lobby.stepsPerBeat,
    beatsPerBar: lobby.beatsPerBar,
    tracks: tracks,
  );
}
