import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/ambient_life_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/region_light_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_shaft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Frame budget of the region light (docs/specs/biome_regions.md § 7.3):
/// only the view is drawn, the static parts are cached, and a frame stays
/// well under budget even with every effect on.
void main() {
  tearDown(() => BiomeRegions.bind(0));

  /// A seed whose forest has a cave lake (shafts + cave shade).
  BiomeLayout caveForest() {
    for (var seed = 0; seed < 400; seed++) {
      BiomeRegions.bind(seed);
      final lay = biomeLayout(kBosque)!;
      if (lay.skylights.isNotEmpty) return lay;
    }
    fail('no cave lake in 400 seeds');
  }

  test('a frame of clouds + cave shade + shafts + critters is cheap', () {
    final lay = caveForest();
    final map = MapGenerator.biome(lay);
    final light = RegionLightLayer();
    final life = AmbientLifeLayer();
    final cave = lay.lakes.firstWhere((l) => l.cave != null).ellipse;
    // A 1280 × 720 view (zoom 2: 640 × 360 px of world) over the cave.
    final view = Rect.fromCenter(
        center: Offset(cave.$1 * 16, cave.$2 * 16), width: 640, height: 360);

    void frame(double t) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      life.draw(c, view, t, CritterKind.butterfly);
      light.drawClouds(c, view, t, LightShaftRules.cloudCover('tormenta', 0),
          map.width * 16.0, map.height * 16.0);
      light.drawCaveShade(c, lay, 0.6);
      light.drawShafts(c, map, view, t);
      rec.endRecording().dispose();
    }

    for (var i = 0; i < 30; i++) {
      frame(i / 60); // warm-up
    }
    final sw = Stopwatch()..start();
    const frames = 600;
    for (var i = 0; i < frames; i++) {
      frame(1 + i / 60);
    }
    sw.stop();
    final perFrame = sw.elapsedMicroseconds / frames;
    // ignore: avoid_print
    print('region light: ${perFrame.toStringAsFixed(1)} µs/frame, '
        '${light.lastShafts} shafts, ${life.last} critters');
    // Recording only (no raster): generous for slow CI, still catches an
    // accidental per-tile or per-frame rebuild.
    expect(perFrame, lessThan(1500));
    // The cave shade picture is built once per layout, never per frame.
    expect(light.shadeBuilds, 1);
    // Only what is visible: the view sees the shafts of this cave.
    expect(light.lastShafts, inInclusiveRange(1, lay.skylights.length));
    // Critters scale with the view, not the map.
    expect(life.last, lessThanOrEqualTo((640 / 96 + 1) * (360 / 96 + 1)));
    light.dispose();
  });

  test('shafts outside the view are skipped and the list is reused', () {
    final lay = caveForest();
    final map = MapGenerator.biome(lay);
    final light = RegionLightLayer();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    // Far corner of the map with no cave.
    light.drawShafts(c, map, const Rect.fromLTWH(-2000, -2000, 100, 100), 0);
    expect(light.lastShafts, 0);
    rec.endRecording().dispose();
    // The shaft list of a map is computed once.
    expect(identical(LightShaftRules.shafts(map), LightShaftRules.shafts(map)),
        isTrue);
  });

  test('a dungeon-sized map: shafts cost scales with the view', () {
    final rows = [
      for (var y = 0; y < 200; y++)
        y == 0 || y == 199 ? '#' * 300 : '#${'.' * 298}#'
    ];
    final map = MapGenerator.biome(biomeLayout(kBosque)!);
    expect(map.width, BiomeLayout.width);
    final big = GameMap(
        width: 300,
        height: 200,
        rows: rows,
        theme: 'cavernas',
        spawn: const WorldPoint(40, 40));
    final all = LightShaftRules.shafts(big).length;
    expect(all, greaterThan(100));
    final light = RegionLightLayer();
    final rec = ui.PictureRecorder();
    light.drawShafts(Canvas(rec), big, const Rect.fromLTWH(0, 0, 640, 360), 0);
    rec.endRecording().dispose();
    expect(light.lastShafts, lessThan(all ~/ 10));
  });
}
