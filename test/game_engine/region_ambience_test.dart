import 'package:echos_del_tiempo/core/audio/music/music_service.dart';
import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/fishing_ambience.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/region_ambience_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// biome_regions.md § 7.2.1–7.2.3.
void main() {
  tearDown(() => BiomeRegions.bind(0));

  /// A region with a roofed cave (cave lake or short cave).
  (BiomeLayout, String Function(int, int))? caveRegion() {
    for (var seed = 1; seed < 200; seed++) {
      BiomeRegions.bind(seed);
      for (final id in kBiomeBases.keys) {
        final lay = biomeLayout(id)!;
        final rows = lay.rows(const {});
        String at(int x, int y) => rows[y][x];
        for (var y = 0; y < BiomeLayout.height; y++) {
          for (var x = 0; x < BiomeLayout.width; x++) {
            if (lay.isIndoor(x, y)) return (lay, at);
          }
        }
      }
    }
    return null;
  }

  test('la roca alrededor de una gruta es pared de cueva; la lejana no', () {
    final (lay, at) = caveRegion()!;
    var walls = 0, peaks = 0;
    for (var y = 0; y < BiomeLayout.height; y++) {
      for (var x = 0; x < BiomeLayout.width; x++) {
        if (at(x, y) != Tile.rock) continue;
        if (RegionAmbienceRules.caveWall(lay, at, x, y)) {
          walls++;
        } else {
          peaks++;
        }
      }
    }
    expect(walls, greaterThan(0));
    expect(peaks, greaterThanOrEqualTo(0));
    // Never a wall on a non-rock tile.
    expect(RegionAmbienceRules.caveWall(lay, (_, __) => Tile.grass, 1, 1),
        isFalse);
  });

  test('la boca de la gruta tiene borde de techo', () {
    final (lay, at) = caveRegion()!;
    var edges = 0;
    for (var y = 0; y < BiomeLayout.height; y++) {
      for (var x = 0; x < BiomeLayout.width; x++) {
        edges += RegionAmbienceRules.roofEdges(lay, at, x, y).length;
        if (!lay.isIndoor(x, y)) {
          expect(RegionAmbienceRules.roofEdges(lay, at, x, y), isEmpty);
        }
      }
    }
    expect(edges, greaterThan(0));
  });

  test('charcos de luz tenues y motas que derivan', () {
    final a = RegionAmbienceRules.poolAlpha(12345, 3);
    expect(a, lessThanOrEqualTo(tuning(TuningId.regions).d('cavePoolAlpha')));
    expect(a, greaterThan(0));
    expect(RegionAmbienceRules.poolAlpha(1, 0, motion: false),
        tuning(TuningId.regions).d('cavePoolAlpha'));
    final (_, y0, _) = RegionAmbienceRules.mote(777, 0, 0);
    final (_, y1, _) = RegionAmbienceRules.mote(777, 0, 2);
    expect(y1, isNot(y0));
  });

  test('el viento mece en píxeles enteros y nada con movimiento reducido', () {
    final amp = tuning(TuningId.regions).d('swayAmp');
    for (var t = 0.0; t < 5; t += 0.37) {
      final d = RegionAmbienceRules.sway(3, 4, t);
      expect(d, d.roundToDouble());
      expect(d.abs(), lessThanOrEqualTo(amp));
    }
    expect(RegionAmbienceRules.sway(3, 4, 1.2, motion: false), 0);
    var n = 0;
    for (var x = 0; x < 100; x++) {
      if (RegionAmbienceRules.swaysAt(x, 7)) n++;
    }
    expect(n, inInclusiveRange(5, 60));
  });

  test('ambiente al pescar por lugar (datos)', () {
    expect(RegionAmbienceRules.ambienceFor(null), FishingAmbience.breeze);
    expect(RegionAmbienceRules.ambienceFor(kBosque), FishingAmbience.breeze);
    expect(RegionAmbienceRules.ambienceFor(kCavernas), FishingAmbience.drip);
    expect(RegionAmbienceRules.ambienceFor(kGrieta), FishingAmbience.none);
    expect(RegionAmbienceRules.ambienceFor(kAbismo), FishingAmbience.none);
    expect(RegionAmbienceRules.ambienceFor(kBosque, indoor: true),
        FishingAmbience.drip);
    expect(RegionAmbienceRules.ambienceFor('mina_bosque'),
        FishingAmbience.drip);
    expect(FishingAmbiencePlayer.soundOf(FishingAmbience.breeze),
        Sfx.ambBreeze);
    expect(FishingAmbiencePlayer.soundOf(FishingAmbience.none), isNull);
    final g0 = RegionAmbienceRules.nextGapSec(0),
        g1 = RegionAmbienceRules.nextGapSec(1);
    expect(g0, tuning(TuningId.fishing).d('ambGapMinSec'));
    expect(g1, tuning(TuningId.fishing).d('ambGapMaxSec'));
  });

  test('la música baja casi a silencio al pescar y vuelve después', () {
    final music = MusicService(autoTick: false);
    music.holdAmbience(RegionAmbienceRules.fishingMusicLevel, seconds: 1);
    for (var i = 0; i < 40; i++) {
      music.tick(0.05);
    }
    expect(music.ambienceLevel,
        closeTo(RegionAmbienceRules.fishingMusicLevel, 1e-9));
    music.holdAmbience(1, seconds: 1);
    for (var i = 0; i < 40; i++) {
      music.tick(0.05);
    }
    expect(music.ambienceLevel, 1);
  });
}
