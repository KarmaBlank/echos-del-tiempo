import '../data/biomes_catalog.dart' show kPueblo;
import '../data/world_events_catalog.dart' show kWorldEvents;
import '../models/custom_npc.dart';
import '../models/world_save.dart';
import 'npc_talk_rules.dart';
import 'sky_rules.dart';
import 'world_event_rules.dart';

/// A data-made NPC standing somewhere now: its def and its feet (pixels).
typedef CustomNpcSpot = ({CustomNpcDef def, double x, double y});

/// Where the data-made NPCs are (docs/specs/npc_editor.md § 6.2). Pure:
/// everything comes from the town state, the room's place and the world
/// clock, so every peer sees the same.
abstract final class CustomNpcRules {
  static const tile = 16.0;

  /// The biome of a mine place (`mine:<biome>:<i>`), or `null`.
  static String? mineBiome(String? place) {
    if (place == null || !place.startsWith('mine:')) return null;
    final parts = place.split(':');
    return parts.length >= 2 ? parts[1] : null;
  }

  /// Out at this hour ([TalkTime] of its def).
  static bool timeOk(CustomNpcDef d, TownState s) =>
      NpcTalkRules.timeOk(d.time, night: SkyRules.isNight(s.sky));

  /// Invited to town (only [CustomNpcDef.invitable] biome NPCs).
  static bool invited(CustomNpcDef d, TownState s) =>
      d.invitable && s.resident(d.id).invited;

  /// Everyone standing in [place] (`null` = the town) now.
  static List<CustomNpcSpot> here(TownState s, String? place,
      {Map<String, CustomNpcDef>? defs}) {
    final out = <CustomNpcSpot>[];
    final mine = mineBiome(place);
    for (final d in (defs ?? kCustomNpcs).values) {
      if (!timeOk(d, s)) continue;
      ({CustomNpcDef def, double x, double y}) at(int tx, int ty) =>
          (def: d, x: (tx + 0.5) * tile, y: (ty + 0.5) * tile);
      switch (d.spawn) {
        case CustomNpcSpawn.town:
          if (place == null) out.add(at(d.x, d.y));
        case CustomNpcSpawn.biome:
          final home = invited(d, s) ? null : d.place;
          if (place == home) out.add(at(d.x, d.y));
        case CustomNpcSpawn.mine:
          if (mine != null && (d.place.isEmpty || d.place == mine)) {
            out.add(at(d.x, d.y));
          }
        case CustomNpcSpawn.event:
          if (mine != null) break;
          for (final a in s.events.at(place ?? kPueblo)) {
            if (a.def != d.place) continue;
            if (kWorldEvents.def(a.def) == null) continue;
            final spot = WorldEventRules.spot(s, a);
            if (spot == null) continue;
            out.add((
              def: d,
              x: spot.$1 + d.x * tile,
              y: spot.$2 + d.y * tile,
            ));
          }
      }
    }
    return out;
  }

  /// INVITAR (topic action): a biome NPC with [CustomNpcDef.invitable],
  /// in its biome, moves to town. `null` if it cannot.
  static TownState? invite(TownState s, String id, String? place) {
    final d = kCustomNpcs[id];
    if (d == null || !d.invitable || d.spawn != CustomNpcSpawn.biome) {
      return null;
    }
    if (place != d.place || s.resident(id).invited) return null;
    final r = s.resident(id).copyWith(invited: true);
    return s.copyWith(residents: {...s.residents, id: r});
  }
}
