import '../../../game_engine/data/biomes_catalog.dart';
import '../../../game_engine/models/game_session.dart';

/// Where the other players are (free_movement.md § 4.1): destination key
/// (`pueblo`, biome id or `m:<missionId>`) to their names. Uses the local
/// instance (players here) plus `GameSession.away` (everyone else);
/// companions and the local player are skipped.
Map<String, List<String>> playersByPlace(GameSession s, String? localId) {
  final out = <String, List<String>>{};
  void add(String key, String name) {
    if (key.isEmpty) return;
    out.putIfAbsent(key, () => []).add(name);
  }

  final here = placeKeyOf(s);
  for (final p in s.playerList) {
    if (p.isCompanion || p.id == localId) continue;
    add(here, p.name);
  }
  for (final a in s.away) {
    if (a.id == localId) continue;
    add(a.placeId, a.name);
  }
  return out;
}

/// Destination key of the instance [s] (same rule as the host's
/// `WorldEngine.placeId`).
String placeKeyOf(GameSession s) {
  if (s.tutorial != null) return '';
  final id = s.mission?.missionId ?? s.vote?.missionId ?? s.prep?.missionId;
  if (id != null) return missionPlaceKey(id);
  return s.place ?? kPueblo;
}

/// Key of a mission / zone dungeon destination.
String missionPlaceKey(String missionId) => 'm:$missionId';
