import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_shaft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_fishing.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/waystone_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Generated biome regions (docs/specs/biome_regions.md).
void main() {
  const seeds = [0, 1, 7, 42, 1234, 99991, 314159, 2718281];
  TuningDef rt() => tuning(TuningId.regions);

  tearDown(() => BiomeRegions.bind(0));

  /// Steps from the spawn to every walkable tile (-1 = unreachable).
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

  /// A walkable neighbour of (x, y) is reachable.
  bool touchable(List<List<int>> d, int x, int y) {
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (ny < 0 || nx < 0 || ny >= d.length || nx >= d[0].length) continue;
      if (d[ny][nx] >= 0) return true;
    }
    return false;
  }

  test('the layout is deterministic per (biome, world seed)', () {
    for (final seed in seeds.take(4)) {
      BiomeRegions.bind(seed);
      final a = {for (final id in kBiomeBases.keys) id: biomeLayout(id)!};
      BiomeRegions.bind(seed + 1);
      BiomeRegions.bind(seed);
      for (final id in kBiomeBases.keys) {
        final b = biomeLayout(id)!;
        expect(identical(a[id], b), isFalse, reason: 'cache was rebuilt');
        expect(b.rows(const {}), a[id]!.rows(const {}), reason: '$id $seed');
        expect(b.forage, a[id]!.forage);
        expect(b.waystones, a[id]!.waystones);
        expect(b.npc.tile, a[id]!.npc.tile);
      }
    }
    BiomeRegions.bind(1);
    final x = biomeLayout(kBosque)!.rows(const {});
    BiomeRegions.bind(2);
    expect(biomeLayout(kBosque)!.rows(const {}), isNot(x),
        reason: 'another world, another region');
  });

  test('the main path is reachable and short', () {
    for (final seed in seeds) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        final d = stepsFrom(lay);
        final rows = lay.rows(const {});
        final sx = (lay.spawn.x / 16).floor(), sy = (lay.spawn.y / 16).floor();
        expect(Tile.isWalkable(rows[sy][sx]), isTrue);
        for (final (zone, x, y) in lay.entrances) {
          final steps = d[y + 1][x];
          expect(steps, greaterThanOrEqualTo(0),
              reason: '${lay.id}/$seed zone $zone');
          expect(steps, lessThanOrEqualTo(rt().i('mainPathMax')),
              reason: '${lay.id}/$seed zone $zone: $steps steps');
        }
        for (final (zone, x, y) in lay.ecoPortals) {
          expect(d[y + 1][x], inInclusiveRange(0, rt().i('mainPathMax')),
              reason: '${lay.id}/$seed echo portal $zone');
        }
      }
    }
  });

  test('every lake, mine, waystone, forage spot, camp and event spot is '
      'reachable', () {
    for (final seed in seeds) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        final d = stepsFrom(lay);
        final why = '${lay.id}/$seed';
        expect(lay.lakes, isNotEmpty, reason: why);
        for (final l in lay.lakes) {
          expect(d[l.approach.$2][l.approach.$1], greaterThanOrEqualTo(0),
              reason: '$why lake ${l.variant}');
        }
        expect(lay.mines.length, 2, reason: why);
        for (final (x, y) in lay.mines) {
          expect(d[y + 1][x], greaterThanOrEqualTo(0), reason: '$why mine');
        }
        expect(lay.waystones.first.site, WaystoneSite.entrance, reason: why);
        for (final w in lay.waystones) {
          expect(d[w.ay][w.ax], greaterThanOrEqualTo(0),
              reason: '$why waystone ${w.site}');
        }
        for (final f in lay.forage) {
          expect(touchable(d, f.x, f.y), isTrue, reason: '$why forage $f');
        }
        final (nx, ny) = lay.npc.tile;
        expect(d[ny][nx], greaterThanOrEqualTo(0), reason: '$why camp');
        expect(lay.eventSpots, isNotEmpty, reason: why);
        for (final (x, y) in lay.eventSpots) {
          expect(d[y][x], greaterThanOrEqualTo(0), reason: '$why event');
        }
        for (final (x, y) in lay.fisherWalk) {
          expect(d[y][x], greaterThanOrEqualTo(0), reason: '$why fisher');
        }
      }
    }
  });

  test('lake variants generate valid fishing spots', () {
    final seen = <LakeVariant>{};
    for (final seed in seeds) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        final m = MapGenerator.biome(lay);
        final d = stepsFrom(lay);
        final why = '${lay.id}/$seed';
        for (final l in lay.lakes) {
          seen.add(l.variant);
          expect(l.docks, isNotEmpty, reason: why);
          expect(m.tileAt(l.docks.first.$1, l.docks.first.$2), Tile.fishing);
          // Fishing from the approach: water right next to it.
          final (ax, ay) = l.approach;
          expect(
              FishingCast.castDir(m, (ax + 0.5) * 16, (ay + 0.5) * 16, 0, 1),
              isNotNull,
              reason: '$why ${l.variant}');
          if (l.variant == LakeVariant.cave) {
            expect(l.cave, isNotNull);
            final (cx, cy, _, _) = l.ellipse;
            expect(lay.isIndoor(cx.round(), cy.round()), isTrue);
            expect(m.rows.join().contains(Tile.rock), isTrue);
          }
          if (l.variant == LakeVariant.glowShore) {
            expect(m.rows.join().contains(Tile.glowPlant), isTrue,
                reason: why);
          }
        }
        // The shiny "better catch" water is always fishable from ground
        // you can reach (fishing.md § 11).
        for (var day = 1; day <= 6; day++) {
          final s = FishingCast.hiddenSpot(m, lay.id, day)!;
          expect(m.tileAt(s.$1, s.$2), Tile.water);
          expect(touchable(d, s.$1, s.$2), isTrue,
              reason: '$why day $day $s');
        }
      }
    }
    expect(seen, LakeVariant.values.toSet());
  });

  test('a one-sided lake is fishable only from its open arc', () {
    for (final seed in seeds) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        for (final l in lay.lakes) {
          if (l.variant != LakeVariant.glowShore) continue;
          final rows = lay.rows(const {});
          final d = stepsFrom(lay);
          final (cx, cy, rx, ry) = l.ellipse;
          // Reachable shore tiles all sit on the approach side.
          final side = l.approach.$1 < cx ? -1 : 1;
          for (var y = 0; y < BiomeLayout.height; y++) {
            for (var x = 0; x < BiomeLayout.width; x++) {
              if (rows[y][x] != Tile.water) continue;
              if ((x - cx).abs() > rx + 1 || (y - cy).abs() > ry + 1) continue;
              if (!touchable(d, x, y)) continue;
              expect((x - cx) * side, greaterThan(-1.5),
                  reason: '${lay.id}/$seed shore ($x, $y)');
            }
          }
        }
      }
    }
  });

  test('waystones: activate one, then fast travel between active ones', () {
    BiomeRegions.bind(0);
    final e = sessionEngine(zones: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = e.addPlayer(s, 'p1', newProfile('Beto', 'mago'))!.state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    final lay = bosqueLayout;
    final lake = lay.waystones
        .indexWhere((w) => w.site == WaystoneSite.lake);
    expect(lake, greaterThan(0));
    final w0 = lay.waystones[0], wl = lay.waystones[lake];
    // Not active yet: cannot travel there from the entrance.
    s = moveTo(e, s, 'p0', (w0.ax + 0.5) * 16, (w0.ay + 0.5) * 16);
    expect(e.apply(s, 'p0', WaystoneAction(0, to: lake)), isNull);
    // Far from it: cannot activate it.
    expect(e.apply(s, 'p0', WaystoneAction(lake)), isNull);
    s = moveTo(e, s, 'p0', (wl.ax + 0.5) * 16, (wl.ay + 0.5) * 16);
    s = act(e, s, 'p0', WaystoneAction(lake));
    expect(WaystoneRules.isActive(s.town, 'Ana', lay, lake), isTrue);
    expect(WaystoneRules.isActive(s.town, 'Beto', lay, lake), isFalse,
        reason: 'per player');
    // Persisted with the world.
    final back = TownState.fromJson(s.town.toJson());
    expect(WaystoneRules.isActive(back, 'Ana', lay, lake), isTrue);
    // Travel from the entrance stone to the lake: only Ana moves.
    s = moveTo(e, s, 'p0', (w0.ax + 0.5) * 16, (w0.ay + 0.5) * 16);
    final beto = (s.players['p1']!.x, s.players['p1']!.y);
    s = act(e, s, 'p0', WaystoneAction(0, to: lake));
    final a = WaystoneRules.arrival(lay, lake);
    expect((s.players['p0']!.x, s.players['p0']!.y), (a.x, a.y));
    expect((s.players['p1']!.x, s.players['p1']!.y), beto);
    expect(WorldRules.collides(e.mapFor(s), a.x, a.y), isFalse);
    // And back: the entrance stone is always active.
    expect(e.apply(s, 'p0', WaystoneAction(lake, to: lake)), isNull,
        reason: 'already here');
    s = act(e, s, 'p0', WaystoneAction(lake, to: 0));
    final b0 = WaystoneRules.arrival(lay, 0);
    expect((s.players['p0']!.x, s.players['p0']!.y), (b0.x, b0.y));
  });

  test('forage regrows only out of view', () {
    BiomeRegions.bind(0);
    final lay = bosqueLayout;
    final f = lay.forage.first;
    final at = ((f.x + 0.5) * 16, (f.y + 0.5) * 16);
    var town = BiomeRules.pick(const TownState(), lay.id, 0, 0);
    final due = BiomeRules.t.d('forageRespawnSec') + 1;
    // Watched when it is due: stays bare a while longer.
    town = BiomeRules.holdInView(town, lay.id, lay.forage, [at], due);
    expect(BiomeRules.picked(town, lay.id, due), contains(0));
    expect(BiomeRules.regrowIn(town, lay.id, 0, due),
        closeTo(tuning(TuningId.regions).d('forageRecheckSec'), 1));
    // Still watched after the recheck: still bare.
    final t2 = due + tuning(TuningId.regions).d('forageRecheckSec') + 1;
    town = BiomeRules.holdInView(town, lay.id, lay.forage, [at], t2);
    expect(BiomeRules.picked(town, lay.id, t2), contains(0));
    // Nobody near: it regrows and leaves the map.
    final far = (at.$1 + 2000, at.$2);
    final t3 = t2 + 60;
    town = BiomeRules.holdInView(town, lay.id, lay.forage, [far], t3);
    expect(BiomeRules.picked(town, lay.id, t3), isEmpty);
    expect(town.wild, isEmpty);
    // Walking up to a regrown bush later never hides it again.
    final same = BiomeRules.holdInView(town, lay.id, lay.forage, [at], t3);
    expect(identical(same, town), isTrue);
  });

  test('seasonal forage gives the product of the season; seed bushes give '
      'seeds and favour the wild-only ones', () {
    var n = 0.0;
    double r() => (n += 0.0137) % 1;
    for (final season in Season.values) {
      final g = BiomeRules.forageSpot(r, kForageSeasonal, kForestSeeds,
          season: season);
      expect(g.item, kSeasonalForage[season.index]);
      expect(kCrops[g.item]!.biome, kWildBiome);
    }
    final counts = <String, int>{};
    for (var i = 0; i < 2000; i++) {
      final g = BiomeRules.forageSpot(r, kForageSeedBush, kForestSeeds);
      expect(g.item, isNull);
      counts[g.seed!] = (counts[g.seed] ?? 0) + 1;
    }
    // seta_reloj (weight .05) is 4x more likely than from a plain bush.
    expect(counts['seta_reloj']! / 2000, greaterThan(0.1));
    final bloom = BiomeRules.forageSpot(r, kForageEchoBloom, kForestSeeds);
    expect(bloom.item, 'flor_eco');
    expect(BiomeRules.respawnOf(kForageEchoBloom),
        greaterThan(BiomeRules.respawnOf(0)));
  });

  test('seasonal forage in the room follows the world season', () {
    BiomeRegions.bind(0);
    final e = sessionEngine(zones: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    final lay = bosqueLayout;
    final i = lay.forage.indexWhere((f) => f.kind == kForageSeasonal);
    expect(i, greaterThanOrEqualTo(0));
    final f = lay.forage[i];
    s = moveTo(e, s, 'p0', (f.x + 0.5) * 16, (f.y + 0.5) * 16 + 14);
    s = act(e, s, 'p0', ForageAction(i));
    final farm = s.players['p0']!.profile.life.farm;
    // Day 0 (no clock) counts as spring.
    expect(farm.cropCount(cropKey('brote_primavera', CropQuality.normal)), 1);
  });

  test('light shafts fall only where there are openings', () {
    BiomeRegions.bind(0);
    GameMap room(String theme) => GameMap(
          width: 30,
          height: 20,
          rows: [
            for (var y = 0; y < 20; y++)
              y == 0 || y == 19
                  ? Tile.wall * 30
                  : '${Tile.wall}${Tile.floor * 28}${Tile.wall}'
          ],
          theme: theme,
          spawn: const WorldPoint(40, 40),
        );
    for (final theme in kLightShaftThemes.keys) {
      expect(LightShaftRules.shafts(room(theme)), isNotEmpty, reason: theme);
    }
    for (final theme in ['laberinto', 'corazon', 'mina_abismo', 'pradera']) {
      expect(kLightShaftThemes.containsKey(theme), isFalse);
      expect(LightShaftRules.shafts(room(theme)), isEmpty, reason: theme);
      expect(LightShaftRules.hasOpenings(room(theme)), isFalse);
    }
    // Shafts never sit against a wall.
    final m = room('cavernas');
    for (final (x, y) in LightShaftRules.shafts(m)) {
      expect(x > 1 && y > 1 && x < 28 && y < 18, isTrue);
    }
    // Region cave lakes: skylights only where the biome has openings.
    for (final seed in seeds) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        final caves = lay.lakes.where((l) => l.cave != null);
        if (!lay.base.style.caveOpenings) {
          expect(lay.skylights, isEmpty, reason: '${lay.id}/$seed');
        } else if (caves.isNotEmpty) {
          // Optional: at most caveSkylightsMax per cavern (§ 7.2.1).
          expect(lay.skylights.length,
              lessThanOrEqualTo(caves.length * rt().i('caveSkylightsMax')),
              reason: '${lay.id}/$seed');
        } else {
          expect(lay.skylights, isEmpty, reason: '${lay.id}/$seed');
        }
      }
    }
    // Cached per map.
    expect(identical(LightShaftRules.shafts(m), LightShaftRules.shafts(m)),
        isTrue);
  });

  test('cloud shadows thicken with rain and vanish at night', () {
    final clear = LightShaftRules.cloudCover('despejado', 0);
    expect(LightShaftRules.cloudCover('lluvia', 0), greaterThan(clear));
    expect(LightShaftRules.cloudCover('tormenta', 0),
        greaterThan(LightShaftRules.cloudCover('lluvia', 0)));
    expect(LightShaftRules.cloudCover('tormenta', 0.8), 0);
    expect(LightShaftRules.cloudCount(0), 0);
    expect(LightShaftRules.cloudCount(1), greaterThan(
        LightShaftRules.cloudCount(clear)));
  });
}
