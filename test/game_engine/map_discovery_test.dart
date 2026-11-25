import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_discovery_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Overworld map discovery (docs/specs/biome_exploration.md § 11).
void main() {
  setUp(() => BiomeRegions.bind(0));
  tearDown(() => BiomeRegions.bind(0));

  test('on arrival only the arrival and the goals are known', () {
    final lay = bosqueLayout;
    const town = TownState();
    // Every goal (2 portals + 2 Ecos) is known from the start.
    final goals = [
      for (final m in MapDiscoveryRules.marks(lay))
        if (m.goal) m
    ];
    expect(goals.where((m) => m.kind == OverworldMarkKind.portal).length, 2);
    expect(goals.where((m) => m.kind == OverworldMarkKind.echo).length, 2);
    for (final m in goals) {
      expect(MapDiscoveryRules.knownTile(town, lay, m.x, m.y), isTrue);
    }
    expect(
        MapDiscoveryRules.knownTile(town, lay, (lay.spawn.x / 16).floor(),
            (lay.spawn.y / 16).floor()),
        isTrue);
    // Most of the region is still unknown.
    final known = MapDiscoveryRules.known(town, lay);
    final share = known.where((b) => b != 0).length / known.length;
    expect(share, lessThan(0.2));
    // The far corners are unknown.
    expect(MapDiscoveryRules.knownTile(town, lay, 2, 2), isFalse);
  });

  test('walking reveals around the player; same instance when nothing new',
      () {
    final lay = bosqueLayout;
    const town = TownState();
    final r = MapDiscoveryRules.t.d('mapRevealRadius');
    expect(MapDiscoveryRules.knownTile(town, lay, 20, 20), isFalse);
    final next = MapDiscoveryRules.reveal(town, lay, [(20.5 * 16, 20.5 * 16)]);
    expect(identical(next, town), isFalse);
    expect(MapDiscoveryRules.knownTile(next, lay, 20, 20), isTrue);
    // Out of the radius: still unknown.
    expect(
        MapDiscoveryRules.knownTile(next, lay, 20 + r.ceil() + 8, 20), isFalse);
    // Standing still: nothing new, same instance.
    final again = MapDiscoveryRules.reveal(next, lay, [(20.5 * 16, 20.5 * 16)]);
    expect(identical(again, next), isTrue);
  });

  test('saved with the world and round-trips; room snapshot only the '
      'current biome', () {
    final lay = bosqueLayout;
    var town = MapDiscoveryRules.reveal(
        const TownState(), lay, [(30.0 * 16, 30.0 * 16)]);
    town = town.copyWith(discovery: {...town.discovery, 'other': '1,1,AA=='});
    final back = TownState.fromJson(town.toJson());
    expect(back.discovery, town.discovery);
    expect(MapDiscoveryRules.knownTile(back, lay, 30, 30), isTrue);
    final room = town.farmJson(place: lay.id, allMaps: false);
    expect((room['md'] as Map).keys, [lay.id]);
    expect(town.farmJson(allMaps: false).containsKey('md'), isFalse);
  });

  test('a stale or broken value is ignored', () {
    final lay = bosqueLayout;
    final town = TownState(discovery: {lay.id: '3,3,AAAA'});
    expect(MapDiscoveryRules.knownTile(town, lay, 2, 2), isFalse);
  });

  test('layout version migration drops the discovery', () {
    const town = TownState(discovery: {kBosque: 'x'}, layoutVersion: 1);
    expect(BiomeRegions.migrate(town).discovery, isEmpty);
  });

  test('host reveals while the party walks; clients get it in the state', () {
    final e = sessionEngine(zones: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    final lay = bosqueLayout;
    expect(MapDiscoveryRules.knownTile(s.town, lay, 75, 40), isFalse);
    s = moveTo(e, s, 'p0', 75.5 * 16, 40.5 * 16);
    s = wait(e, s, 0.2);
    expect(MapDiscoveryRules.knownTile(s.town, lay, 75, 40), isTrue);
    final codec = SessionJson(e.catalog);
    final client = codec.fromJson(codec.toJson(s));
    expect(client.town.discovery.keys, [kBosque]);
    expect(MapDiscoveryRules.knownTile(client.town, lay, 75, 40), isTrue);
  });
}
