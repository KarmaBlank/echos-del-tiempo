import 'package:echos_del_tiempo/core/audio/music/music_catalog.dart';
import 'package:echos_del_tiempo/core/audio/music/music_score.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_music.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:flutter_test/flutter_test.dart';

String _sig(Song s) => [for (final t in s.tracks) t.signature].join('\n');

void main() {
  group('ocarina lead is playable on a 12-hole alto C ocarina', () {
    for (final song in kMusicCatalog.values) {
      test(song.id, () {
        final lead = song.tracks.first;
        int? last;
        for (final e in lead.events) {
          final m = e.midi;
          if (m == null) continue;
          final p = m + lead.instrument.transpose;
          // A4 (69) .. F6 (89).
          expect(p, inInclusiveRange(69, 89),
              reason: '${song.id} @${e.start}: ${midiToNote(p)}');
          if (last != null) {
            expect((p - last).abs(), lessThanOrEqualTo(19),
                reason: '${song.id} @${e.start}: leap');
          }
          last = p;
        }
      });
    }
  });

  test('battle variant is deterministic per seed and covers all three', () {
    final seen = <String>{};
    for (var seed = 0; seed < 50; seed++) {
      final a = MusicSelector.battleVariant(seed);
      expect(MusicSelector.battleVariant(seed), a);
      expect(Music.battles, contains(a));
      expect(MusicSelector.isBattleTrack(a), isTrue);
      expect(
          MusicSelector.trackFor(mode: SessionMode.battle, battleSeed: seed),
          a);
      seen.add(a);
    }
    expect(seen, Music.battles.toSet());
  });

  test('each biome has its own boss arrangement of the shared melody', () {
    final boss = kMusicCatalog[Music.boss]!;
    final sigs = <String>{_sig(boss)};
    for (final z in Music.biomeZones) {
      final s = kMusicCatalog[Music.zoneBoss(z)]!;
      expect(sigs.add(_sig(s)), isTrue, reason: s.id);
      // Same ocarina melody, different arrangement.
      expect(s.tracks.first.events, boss.tracks.first.events, reason: s.id);
      expect(MusicSelector.isBattleTrack(s.id), isTrue);
      expect(
          MusicSelector.trackFor(mode: SessionMode.battle, boss: true, zone: z),
          s.id);
    }
    expect(
        MusicSelector.trackFor(mode: SessionMode.battle, boss: true, zone: 1),
        Music.boss);
  });

  test('dungeon variant differs from the biome lobby theme', () {
    for (final z in Music.biomeZones) {
      final lobby = kMusicCatalog[Music.zone(z)]!;
      final dungeon = kMusicCatalog[Music.dungeon(z)]!;
      expect(_sig(dungeon), isNot(_sig(lobby)), reason: '$z');
      expect(dungeon.bpm, greaterThan(lobby.bpm));
      expect(dungeon.tracks.length, greaterThan(lobby.tracks.length));
      expect(MusicSelector.trackFor(mode: SessionMode.field, zone: z),
          Music.dungeon(z));
    }
    expect(MusicSelector.trackFor(mode: SessionMode.field, zone: 1),
        Music.zone(1));
  });

  test('a biome exterior plays its biome theme', () {
    expect(MusicSelector.trackFor(mode: SessionMode.lobby, place: 'bosque'),
        Music.zone(2));
    expect(MusicSelector.trackFor(mode: SessionMode.lobby, place: 'grieta'),
        Music.zone(7));
    expect(MusicSelector.trackFor(mode: SessionMode.lobby), Music.town);
  });
}
