import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/mine_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/world_events_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/waystone_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/wild_loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_event_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Biome exploration v2 (docs/specs/biome_exploration.md).
void main() {
  const seeds = [0, 1, 7, 42, 1234, 99991];
  tearDown(() => BiomeRegions.bind(0));

  bool inFront(int x, int y) =>
      x >= BiomeLayout.frontX &&
      x < BiomeLayout.frontX + BiomeLayout.frontW &&
      y >= BiomeLayout.frontY;

  List<List<int>> stepsFrom(BiomeLayout lay) {
    final rows = lay.rows(const {});
    final d = [
      for (var y = 0; y < BiomeLayout.height; y++)
        List.filled(BiomeLayout.width, -1)
    ];
    final sx = (lay.spawn.x / 16).floor(), sy = (lay.spawn.y / 16).floor();
    final q = <(int, int)>[(sx, sy)];
    d[sy][sx] = 0;
    for (var i = 0; i < q.length; i++) {
      final (x, y) = q[i];
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= BiomeLayout.width) continue;
        if (ny >= BiomeLayout.height || d[ny][nx] >= 0) continue;
        if (!Tile.isWalkable(rows[ny][nx])) continue;
        d[ny][nx] = d[y][x] + 1;
        q.add((nx, ny));
      }
    }
    return d;
  }

  bool touchable(List<List<int>> d, int x, int y) {
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (ny < 0 || nx < 0 || ny >= d.length || nx >= d[0].length) continue;
      if (d[ny][nx] >= 0) return true;
    }
    return false;
  }

  test('the canvas is big, the front stays bottom-center and short', () {
    expect(BiomeLayout.width * BiomeLayout.height,
        greaterThan(60 * 34 * 6));
    for (final seed in seeds) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        expect(lay.rows(const {}).length, BiomeLayout.height);
        expect(lay.rows(const {}).first.length, BiomeLayout.width);
        // The portals stay in the front, next to the arrival.
        for (final (_, x, y) in lay.ecoPortals) {
          expect(inFront(x, y), isTrue, reason: '${lay.id} $seed');
        }
        final d = stepsFrom(lay);
        for (final (_, x, y) in lay.ecoPortals) {
          expect(touchable(d, x, y), isTrue);
        }
      }
    }
  });

  test('wilds: many sections of several kinds, all reachable', () {
    for (final seed in seeds) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        final why = '${lay.id} seed $seed';
        expect(lay.sections.length, greaterThanOrEqualTo(15), reason: why);
        expect(lay.sections.map((s) => s.kind).toSet().length,
            greaterThanOrEqualTo(3),
            reason: why);
        final d = stepsFrom(lay);
        // Far away: the wilds reach well beyond the front.
        var far = 0;
        for (final row in d) {
          for (final v in row) {
            if (v > far) far = v;
          }
        }
        expect(far, greaterThan(120), reason: why);
        for (final s in lay.sections) {
          if (s.kind == WildKind.cavern || s.kind == WildKind.giantLake) {
            continue;
          }
          expect(d[s.y][s.x], greaterThanOrEqualTo(0), reason: '$why $s');
        }
        for (final (x, y) in [...lay.chestSpots, ...lay.shrines]) {
          expect(touchable(d, x, y), isTrue, reason: '$why ($x, $y)');
        }
        for (final (x, y) in lay.exploreSpots) {
          expect(d[y][x], greaterThanOrEqualTo(0), reason: why);
          expect(inFront(x, y), isFalse);
        }
        for (final f in lay.forage) {
          expect(touchable(d, f.x, f.y), isTrue, reason: why);
        }
        // Every cavern is under a roof.
        for (final (cx, cy, _, _) in lay.caverns) {
          expect(lay.isIndoor(cx.round(), cy.round()), isTrue, reason: why);
        }
      }
    }
  });

  test('a giant lake shows up in some worlds and is much bigger', () {
    var giants = 0;
    for (var seed = 0; seed < 30; seed++) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        if (!lay.sections.any((s) => s.kind == WildKind.giantLake)) continue;
        giants++;
        final big = lay.lakes.map((l) => l.ellipse.$3).reduce(
            (a, b) => a > b ? a : b);
        expect(big, greaterThanOrEqualTo(7));
      }
    }
    expect(giants, greaterThan(10));
  });

  test('mines: 1 to 3, one by the portals, the others deep', () {
    for (final seed in seeds) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        final why = '${lay.id} seed $seed';
        final m = lay.mines;
        expect(m.length, inInclusiveRange(1, 3), reason: why);
        expect(m.where((p) => inFront(p.$1, p.$2)).length, 1, reason: why);
        final rows = lay.rows(const {});
        final d = stepsFrom(lay);
        for (final (x, y) in m) {
          expect(rows[y][x], Tile.mineEntrance);
          expect(touchable(d, x, y), isTrue, reason: '$why ($x, $y)');
        }
      }
    }
  });

  test('waystones stand at the points of interest, deep ones included', () {
    for (final seed in seeds) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        final why = '${lay.id} seed $seed';
        final ws = lay.waystones;
        expect(ws.first.site, WaystoneSite.entrance);
        // Every mine, shrine and cavern has its stone.
        for (var i = 0; i < lay.mines.length; i++) {
          expect(
              ws.any((w) => w.site == WaystoneSite.mine && w.ref == i), isTrue,
              reason: '$why mine $i');
        }
        expect(ws.where((w) => w.site == WaystoneSite.shrine).length,
            lay.shrines.length,
            reason: why);
        expect(ws.where((w) => w.site == WaystoneSite.cavern).length,
            greaterThanOrEqualTo(lay.caverns.length - 1),
            reason: why);
        expect(ws.where((w) => !inFront(w.x, w.y)).length,
            greaterThanOrEqualTo(5),
            reason: why);
        final d = stepsFrom(lay);
        for (final w in ws) {
          expect(d[w.ay][w.ax], greaterThanOrEqualTo(0), reason: '$why $w');
        }
      }
    }
  });

  test('waystones are discovered on touch', () {
    BiomeRegions.bind(0);
    final e = sessionEngine(zones: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    final lay = bosqueLayout;
    final deep = lay.waystones.indexWhere((w) => w.site != WaystoneSite.entrance);
    final w = lay.waystones[deep];
    expect(WaystoneRules.isActive(s.town, 'Ana', lay, deep), isFalse);
    s = moveTo(e, s, 'p0', (w.ax + 0.5) * 16, (w.ay + 0.5) * 16);
    s = wait(e, s, 0.2);
    expect(WaystoneRules.isActive(s.town, 'Ana', lay, deep), isTrue);
  });

  test('exploration content is seeded per biome and day', () {
    final cfg = kWorldEventsDefaults;
    final a = WorldEventRules.exploreRoll(77, 12, cfg);
    final b = WorldEventRules.exploreRoll(77, 12, cfg);
    expect([for (final x in a) '${x.def}@${x.biome}'],
        [for (final x in b) '${x.def}@${x.biome}']);
    expect(a, isNotEmpty);
    // Over a few days every kind shows up, in several biomes.
    final kinds = <String>{}, biomes = <String>{};
    for (var day = 1; day < 40; day++) {
      for (final x in WorldEventRules.exploreRoll(77, day, cfg)) {
        kinds.add(x.def);
        biomes.add(x.biome);
        // A def stands in one biome per day (its uid is def@day).
      }
      final ids = [
        for (final x in WorldEventRules.exploreRoll(77, day, cfg)) x.def
      ];
      expect(ids.toSet().length, ids.length);
    }
    expect(kinds, containsAll(['explore_elite', 'explore_merchant',
        'explore_traveler']));
    expect(biomes.length, greaterThanOrEqualTo(3));
    // Deep actors never enter the general roll.
    for (var day = 1; day < 60; day++) {
      for (final x in WorldEventRules.roll(77, day, cfg)) {
        expect(x.def.startsWith('explore_'), isFalse);
      }
    }
  });

  test('deep actors stand deep; the elite fights a biome elite', () {
    BiomeRegions.bind(3);
    final cfg = kWorldEventsDefaults;
    final (st, started) =
        WorldEventRules.onDay(const WorldEventsState(), 4, cfg);
    expect(started, isNotEmpty);
    final town = TownState(events: st);
    for (final a in started) {
      final d = cfg.def(a.def)!;
      if (!WorldEventRules.isDeep(d)) continue;
      final p = WorldEventRules.spot(town, a, cfg)!;
      final lay = biomeLayout(a.biome)!;
      final tx = (p.$1 / 16).floor(), ty = (p.$2 / 16).floor();
      expect(lay.exploreSpots, contains((tx, ty)));
    }
    final elite = cfg.def('explore_elite')!;
    for (final b in kBiomeBases.keys) {
      final r = WorldEventRules.duel(elite, b);
      expect(r, isNotNull, reason: b);
      expect(kEnemies.containsKey(r!.bossId), isTrue);
    }
  });

  test('chests and shrines: once per player per day', () {
    BiomeRegions.bind(0);
    late BiomeLayout lay;
    for (var seed = 0; seed < 50; seed++) {
      BiomeRegions.bind(seed);
      lay = bosqueLayout;
      if (lay.chestSpots.isNotEmpty && lay.shrines.isNotEmpty) break;
    }
    final e = sessionEngine(zones: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    final (cx, cy) = lay.chestSpots.first;
    // Far: nothing.
    expect(e.apply(s, 'p0', const WildLootAction(0)), isNull);
    final map = e.mapFor(s);
    (double, double)? beside(int x, int y) {
      for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
        if (Tile.isWalkable(map.tileAt(x + dx, y + dy))) {
          return ((x + dx + 0.5) * 16, (y + dy + 0.5) * 16);
        }
      }
      return null;
    }

    final at = beside(cx, cy)!;
    s = moveTo(e, s, 'p0', at.$1, at.$2);
    final gold = s.players['p0']!.profile.credits;
    s = act(e, s, 'p0', const WildLootAction(0));
    expect(s.players['p0']!.profile.credits, greaterThan(gold));
    expect(WildLootRules.taken(s.town, 'Ana', lay.id, 0), isTrue);
    expect(e.apply(s, 'p0', const WildLootAction(0)), isNull,
        reason: 'once a day');
    expect(map.tileAt(cx, cy), MineTile.chest);
    final (sx, sy) = lay.shrines.first;
    final at2 = beside(sx, sy)!;
    s = moveTo(e, s, 'p0', at2.$1, at2.$2);
    s = act(e, s, 'p0', const WildLootAction(0, shrine: true));
    expect(
        WildLootRules.taken(s.town, 'Ana', lay.id, 0, shrine: true), isTrue);
    // Wire round trip.
    final j = ActionJson.toJson(const WildLootAction(2, shrine: true));
    final back = ActionJson.fromJson(j) as WildLootAction;
    expect((back.i, back.shrine), (2, true));
  });

  test('old worlds drop the layout-indexed state on load', () {
    const old = TownState(
        waystones: {'Ana|bosque:3'}, wild: {'bosque:2': 50}, daily: {'x:1': 1});
    final m = BiomeRegions.migrate(old);
    expect(m.layoutVersion, BiomeLayout.version);
    expect(m.waystones, isEmpty);
    expect(m.wild, isEmpty);
    expect(m.daily, old.daily, reason: 'everything else stays');
    expect(identical(BiomeRegions.migrate(m), m), isTrue);
    final back = TownState.fromJson(m.toJson());
    expect(back.layoutVersion, BiomeLayout.version);
    // The engine migrates on setWorld.
    final e = sessionEngine(zones: true);
    final s = e.setWorld(e.create(), 'w', 'W', town: old).state;
    expect(s.town.layoutVersion, BiomeLayout.version);
    expect(s.town.waystones, isEmpty);
  });

  test('inside a cave the carried light and the wisp shine by day', () {
    expect(
        LightRules.wispActive(toggled: true, outdoor: true, night: false),
        isFalse);
    expect(
        LightRules.wispActive(
            toggled: true, outdoor: true, night: false, cave: true),
        isTrue);
  });
}
