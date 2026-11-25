import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_discovery_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Dungeon map discovery (docs/specs/biome_exploration.md § 11.8).
void main() {
  PlayerProfile hero(String name) => zoneProgression
      .normalize(PlayerProfile(name: name, classId: 'guerrero', level: 10))
      .copyWith(unlockedZone: 10);

  ({SessionEngine e, GameSession s, GameMap map}) start(
      {int players = 1, int seed = 500000000}) {
    final e = sessionEngine(zones: true, seed: seed);
    final s = inField(e, kZones.first.missionId!,
        profiles: [for (var i = 0; i < players; i++) hero('J$i')]);
    return (e: e, s: s, map: e.mapFor(s));
  }

  bool inStart(GameMap map, int tx, int ty) {
    final w = DungeonDiscoveryRules.cols(map);
    if (tx < 0 || ty < 0 || tx >= map.width || ty >= map.height) return false;
    return DungeonDiscoveryRules.startCells(map)[(ty ~/ 4) * w + tx ~/ 4] != 0;
  }

  /// A walkable tile of floor [f] outside the start area.
  (int, int) farTile(GameMap map, MapFloor f) {
    final b = f.bounds;
    for (var y = b.y + 1; y < b.y + b.h - 1; y++) {
      for (var x = b.x + 1; x < b.x + b.w - 1; x++) {
        if (inStart(map, x, y)) continue;
        // Its whole reveal circle must be outside the start area too.
        final r = DungeonDiscoveryRules.t.d('dungeonMapRevealRadius').ceil();
        if (inStart(map, x + r + 4, y) ||
            inStart(map, x - r - 4, y) ||
            inStart(map, x, y + r + 4) ||
            inStart(map, x, y - r - 4)) {
          continue;
        }
        if (WorldRules.collides(map, x * 16 + 8.0, y * 16 + 8.0,
            blockVoid: true)) {
          continue;
        }
        return (x, y);
      }
    }
    throw StateError('no far tile');
  }

  test('on arrival only the arrival and the goals are known', () {
    final (:e, :s, :map) = start();
    final m = s.mission!;
    final f = map.floor(0)!;
    final goals = DungeonDiscoveryRules.goals(map, 0);
    expect(goals, isNotEmpty, reason: 'floor 0 has stairs or the boss');
    for (final g in goals) {
      expect(DungeonDiscoveryRules.knownTile(m, map, g.x, g.y), isTrue,
          reason: 'goals are always visible');
    }
    expect(
        DungeonDiscoveryRules.knownTile(
            m, map, (f.spawn.x / 16).floor(), (f.spawn.y / 16).floor()),
        isTrue);
    // Most of the floor is still unknown.
    final known = DungeonDiscoveryRules.known(m, map);
    final w = DungeonDiscoveryRules.cols(map);
    var cells = 0, k = 0;
    for (var cy = f.bounds.y ~/ 4; cy < (f.bounds.y + f.bounds.h) ~/ 4; cy++) {
      for (var cx = f.bounds.x ~/ 4;
          cx < (f.bounds.x + f.bounds.w) ~/ 4;
          cx++) {
        cells++;
        if (known[cy * w + cx] != 0) k++;
      }
    }
    expect(k / cells, lessThan(0.5));
    final (fx, fy) = farTile(map, f);
    expect(DungeonDiscoveryRules.knownTile(m, map, fx, fy), isFalse);
    expect(e, isNotNull);
  });

  test('walking reveals around the player and bumps the revision', () {
    var (:e, :s, :map) = start();
    final (fx, fy) = farTile(map, map.floor(0)!);
    final rev = s.mission!.discoveryRev;
    s = moveTo(e, s, 'p0', fx * 16 + 8.0, fy * 16 + 8.0);
    s = e.tick(s, 0.05).state;
    expect(DungeonDiscoveryRules.knownTile(s.mission!, map, fx, fy), isTrue);
    expect(s.mission!.discoveryRev, greaterThan(rev));
    final again = s.mission!.discoveryRev;
    s = e.tick(s, 0.05).state;
    expect(s.mission!.discoveryRev, again, reason: 'standing still');
  });

  test('secrets stay hidden until their cell is discovered', () {
    // A seed whose first floor has a secret room out of the start area.
    final zone = kZones.first;
    late int seed;
    late MapPoi secret;
    for (seed = 1;; seed++) {
      final map = MapGenerator.zone(zone, seed);
      final hit = map
          .floor(0)!
          .pois
          .where((p) => p.kind == PoiKind.secret && !inStart(map, p.tx, p.ty));
      if (hit.isNotEmpty) {
        secret = hit.first;
        break;
      }
      if (seed > 4000) fail('no seed with a hidden secret');
    }
    final (:e, :s, :map) = start(seed: seed);
    final m = s.mission!;
    expect(
        DungeonDiscoveryRules.knownTile(m, map, secret.tx, secret.ty), isFalse);
    DungeonDiscoveryRules.reveal(
        m, map, [(secret.tx * 16 + 8.0, secret.ty * 16 + 8.0)]);
    expect(
        DungeonDiscoveryRules.knownTile(m, map, secret.tx, secret.ty), isTrue);
    expect(e, isNotNull);
  });

  test('co-op: the client sees the cells another player discovered', () {
    var (:e, :s, :map) = start(players: 2);
    final (fx, fy) = farTile(map, map.floor(0)!);
    s = moveTo(e, s, 'p1', fx * 16 + 8.0, fy * 16 + 8.0);
    s = e.tick(s, 0.05).state;
    // The room snapshot carries it.
    const j = SessionJson();
    final client = j.fromJson(j.toJson(s, profiles: true));
    final cm = client.mission!;
    expect(DungeonDiscoveryRules.knownTile(cm, map, fx, fy), isTrue);
    expect(cm.discoveryRev, s.mission!.discoveryRev);
    expect(DungeonDiscoveryRules.known(cm, map),
        DungeonDiscoveryRules.known(s.mission!, map));
  });

  test('persistent dungeon keeps the discovered map', () {
    (WorldEngine, SessionWorld) world({TownState? town}) {
      final we = WorldEngine(sessionEngine(freeMovement: true, zones: true));
      final w = we.create(we.engine
          .setWorld(we.engine.create(), 'w1', 'Mundo', town: town)
          .state);
      we.addPlayer(w, 'p0', hero('Ana'));
      expect(we.apply(w, 'p0', const ProposeMissionAction('m1')), isNotNull);
      return (we, w);
    }

    final (we, w) = world();
    final s = w.sessionOf('p0')!;
    final map = we.engine.mapFor(s);
    final f = map.floor(0)!;
    final (fx, fy) = farTile(map, f);
    DungeonDiscoveryRules.reveal(
        s.mission!, map, [(fx * 16 + 8.0, fy * 16 + 8.0)]);
    final d = w.roomOf('p0')!;
    final room = w.rooms[d]!.copy()..mission!.floor = 0;
    room.players['p0']!
      ..x = f.spawn.x
      ..y = f.spawn.y;
    w.rooms[d] = room;
    expect(we.apply(w, 'p0', const LeaveDungeonAction()), isNotNull);
    final town = TownState.fromJson(w.town.town.toJson());
    final (_, w2) = world(town: town);
    final back = w2.sessionOf('p0')!.mission!;
    expect(DungeonDiscoveryRules.knownTile(back, map, fx, fy), isTrue);
  });

  test('one-off runs keep it in the run only', () {
    var (:e, :s, :map) = start();
    s = e.tick(s, 0.05).state;
    expect(s.mission!.discovery.contains(1), isTrue,
        reason: 'the party revealed its arrival');
    expect(s.town.discovery, isEmpty);
    expect(map, isNotNull);
    expect(e, isNotNull);
  });
}
