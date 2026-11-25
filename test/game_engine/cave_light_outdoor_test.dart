import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_shaft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression (v0.49.9): at night a spot of open grass in a biome
/// exterior lit up "like a cave". The Cavernas exterior theme was flagged
/// with hashed light-shaft openings (meant for roofed maps), so shaft
/// lights sat on open ground. Cave light only belongs under a roof.
void main() {
  tearDown(() => BiomeRegions.bind(0));

  test('biome exteriors: shafts and cave light only under the roof '
      '(seeds 0-11, every biome)', () {
    const open = {Tile.grass, Tile.path, Tile.tree};
    for (var seed = 0; seed < 12; seed++) {
      BiomeRegions.bind(seed);
      for (final b in kBiomes) {
        final lay = biomeLayout(b.id);
        if (lay == null) continue;
        final map = MapGenerator.biome(lay);
        for (final (x, y) in LightShaftRules.shafts(map)) {
          expect(lay.isIndoor(x, y), isTrue,
              reason: 'seed $seed ${b.id}: shaft on open ground at ($x, $y)');
        }
        // The carried light is boosted where isIndoor: never on open,
        // roofless ground.
        for (var y = 0; y < map.height; y++) {
          for (var x = 0; x < map.width; x++) {
            if (!lay.isIndoor(x, y)) continue;
            expect(open.contains(map.tileAt(x, y)), isFalse,
                reason: 'seed $seed ${b.id}: roofed open tile at ($x, $y)');
          }
        }
      }
    }
  });
}
