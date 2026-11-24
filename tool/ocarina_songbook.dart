// Generates docs/specs/ocarina_songbook.md from the music catalog: the
// ocarina lead of every track, bar by bar, for a 12-hole alto C ocarina.
//
// Regenerate:  dart run tool/ocarina_songbook.dart
// (test/core/audio/ocarina_songbook_test.dart fails if it is stale).
import 'dart:io';

import 'package:echos_del_tiempo/core/audio/music/music_catalog.dart';
import 'package:echos_del_tiempo/core/audio/music/music_score.dart';

const songbookPath = 'docs/specs/ocarina_songbook.md';

/// Mood, key and display name of each track (keep in step with the
/// comments in lib/core/audio/music/tracks/*.dart).
const kSongMoods = <String, (String key, String mood)>{
  'title': ('D dorian', 'Epic folk opening: the journey begins.'),
  'town': ('D mixolydian', 'Calm and homely, a gentle 3/4 dance by the hearth.'),
  'fishing': ('G major', 'Quiet afternoon by the water.'),
  'townNight': ('D mixolydian', 'The town after dark, slow and hushed.'),
  'overworld': ('G major', 'The open road, wistful and wide.'),
  'zone1': ('F major', 'Meadow: bright and open.'),
  'zone2': ('D major (lydian touch)', 'Forest: enchanted, tranquil, small lights between trees.'),
  'zone2.dungeon': ('D minor', 'Forest depths: the same song gone dark, a pulse underneath.'),
  'zone3': ('A minor', 'Ruins: ancient and melancholic.'),
  'zone3.dungeon': ('A phrygian', 'Ruins depths: older and heavier.'),
  'zone4': ('B minor', 'Caverns: cold and echoing.'),
  'zone4.dungeon': ('B phrygian', 'Caverns depths: frozen and pressing.'),
  'zone5': ('C minor', 'Fortress: stern walls.'),
  'zone6': ('G minor (whole-tone touches)', 'Labyrinth: turning corridors.'),
  'zone7': ('E phrygian dominant', 'Rift: heat, danger and tension.'),
  'zone7.dungeon': ('E locrian color', 'Rift depths: the ground about to break.'),
  'zone8': ('F minor', 'Graveyard: quiet mourning.'),
  'zone9': ('A lydian', 'Abyss: eerie, floating over nothing.'),
  'zone9.dungeon': ('A (altered)', 'Abyss depths: wrong and weightless.'),
  'zone10': ('D minor', 'Heart of Time: the end of the road.'),
  'battle': ('E minor', 'Battle I: driving and bright.'),
  'battle2': ('A dorian', 'Battle II: a quick skirmish on the road.'),
  'battle3': ('D minor', 'Battle III: a proud stand against something larger.'),
  'boss': ('D phrygian', 'Boss: great danger.'),
  'boss.zone2': ('D phrygian', 'Boss, forest arrangement: airy, harp and chimes.'),
  'boss.zone3': ('D phrygian', 'Boss, ruins arrangement: solemn horn.'),
  'boss.zone4': ('D phrygian', 'Boss, caverns arrangement: icy echo.'),
  'boss.zone7': ('D phrygian', 'Boss, rift arrangement: fast and driving.'),
  'boss.zone9': ('D phrygian', 'Boss, abyss arrangement: eerie drone.'),
  'bossFinal': ('D minor', 'Final boss.'),
  'bossAbyss': ('E phrygian', 'Abyss lords.'),
  'bossSecret': ('C minor', 'The hidden boss.'),
  'jingle.victory': ('C major', 'Victory fanfare.'),
  'jingle.defeat': ('A minor', 'Defeat.'),
  'jingle.levelUp': ('D major', 'Level up.'),
  'jingle.zoneUnlocked': ('E-flat lydian', 'A new place opens.'),
  'jingle.ascension': ('D minor to D major', 'Ascension.'),
};

/// 12-hole alto C ocarina note names, from the lowest note up.
const kFingering = <String, String>{
  'A4': 'low A (subhole note)',
  'A#4': 'low A#, accidental: half-hole or alternate fingering (see your ocarina chart)',
  'B4': 'low B (subhole note)',
  'C5': 'low C (all main holes closed)',
  'C#5': 'C#, accidental: half-hole or alternate fingering (see your ocarina chart)',
  'D5': 'D',
  'D#5': 'D#, accidental: half-hole or alternate fingering (see your ocarina chart)',
  'E5': 'E',
  'F5': 'F',
  'F#5': 'F#, accidental: half-hole or alternate fingering (see your ocarina chart)',
  'G5': 'G',
  'G#5': 'G#, accidental: half-hole or alternate fingering (see your ocarina chart)',
  'A5': 'A',
  'A#5': 'A# / Bb, accidental: half-hole or alternate fingering (see your ocarina chart)',
  'B5': 'B',
  'C6': 'high C (thumb note)',
  'C#6': 'high C#, accidental: half-hole or alternate fingering (see your ocarina chart)',
  'D6': 'high D (thumb note)',
  'D#6': 'high D#, accidental: half-hole or alternate fingering (see your ocarina chart)',
  'E6': 'high E (thumb note)',
  'F6': 'high F (top note)',
};

String _note(int midi) => midiToNote(midi);

/// The lead of [song] as text: one line per bar, `note/steps`.
String leadBars(Song song) {
  final lead = song.tracks.first;
  final per = song.stepsPerBar;
  final bars = List.generate(song.bars, (_) => <String>[]);
  var pos = 0;
  void emit(String token, int len) {
    // Split across bar lines.
    while (len > 0) {
      final b = pos ~/ per;
      final room = per - pos % per;
      final l = len < room ? len : room;
      if (b < bars.length) bars[b].add('$token/$l');
      pos += l;
      len -= l;
      token = token == 'rest' ? 'rest' : '~$token';
    }
  }

  final starts = <int>{};
  for (final e in lead.events) {
    final m = e.midi;
    if (m == null || starts.contains(e.start)) continue;
    starts.add(e.start);
    if (e.start > pos) emit('rest', e.start - pos);
    emit(_note(m + lead.instrument.transpose), e.length);
  }
  if (pos < song.steps) emit('rest', song.steps - pos);
  return [
    for (var i = 0; i < bars.length; i++)
      '${(i + 1).toString().padLeft(3)} | ${bars[i].join(' ')} |',
  ].join('\n');
}

String buildSongbook() {
  final out = StringBuffer()
    ..writeln('# Ocarina songbook (12-hole alto C)')
    ..writeln()
    ..writeln('Generated from the scores by `tool/ocarina_songbook.dart`; do '
        'not edit by hand. Regenerate with')
    ..writeln('`dart run tool/ocarina_songbook.dart` (the test '
        '`test/core/audio/ocarina_songbook_test.dart` fails when it is '
        'stale).')
    ..writeln()
    ..writeln('Every lead stays within A4–F6 (the range of a 12-hole alto C '
        'ocarina), and no leap is wider than an octave and a fifth '
        '(`test/core/audio/music_variants_test.dart`).')
    ..writeln()
    ..writeln('Notation: `note/steps`, one line per bar. A step is a '
        'sixteenth note in 4/4 (16 steps per bar), an eighth in 3/4 '
        '(6 per bar) and a triplet eighth in 6/8 / 12/8. `~` ties the '
        'note from the previous bar; `rest` is a breath.')
    ..writeln()
    ..writeln('## Fingering reference')
    ..writeln()
    ..writeln('| Note | 12-hole alto C |')
    ..writeln('|---|---|');
  for (final e in kFingering.entries) {
    out.writeln('| ${e.key} | ${e.value} |');
  }
  for (final song in kMusicCatalog.values) {
    final (key, mood) = kSongMoods[song.id] ?? ('', '');
    final lead = song.tracks.first;
    final used = <int>{
      for (final e in lead.events)
        if (e.midi != null) e.midi! + lead.instrument.transpose,
    }.toList()
      ..sort();
    out
      ..writeln()
      ..writeln('## ${song.title} (`${song.id}`)')
      ..writeln()
      ..writeln('- Mood: $mood')
      ..writeln('- Key: $key')
      ..writeln('- Tempo: ${song.bpm.toStringAsFixed(0)} bpm, '
          '${song.beatsPerBar} beats per bar, ${song.bars} bars')
      ..writeln('- Notes used: ${[
        for (final m in used) '${_note(m)} (${kFingering[_note(m)] ?? '?'})',
      ].join(', ')}')
      ..writeln()
      ..writeln('```')
      ..writeln(leadBars(song))
      ..writeln('```');
  }
  return out.toString();
}

void main() {
  File(songbookPath).writeAsStringSync(buildSongbook());
  stdout.writeln('wrote $songbookPath');
}
