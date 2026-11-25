import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Light of a dark mine full of torches (mining_smithing.md § 1.6): the
/// map (and so the cached steady light) only changes when a tile or a
/// torch does; a frame only adds the carried light.
void main() {
  test('mina con muchas antorchas: mapa estable y luz barata', () {
    final lvl = MiningRules.level(MiningRules.placeOf(kBosque, 0),
        worldId: 'w1')!;
    // A torch every few floor tiles.
    final torches = <int>{};
    for (var y = 0; y < lvl.height; y++) {
      for (var x = 0; x < lvl.width; x++) {
        if (lvl.at(x, y) == '.' && (x * 7 + y * 3) % 9 == 0) {
          torches.add(lvl.idx(x, y));
        }
      }
    }
    final st = MineLevelState(torches: torches);
    final map = MiningRules.mapOf(lvl, st);
    // Same state: the very same map (the light layer keys on map.rows).
    expect(identical(MiningRules.mapOf(lvl, st), map), isTrue);
    // A torch more: a new map, so the light is rebuilt once.
    final more = st.copyWith(torches: {...torches, lvl.idx(lvl.spawn.$1, lvl.spawn.$2)});
    expect(identical(MiningRules.mapOf(lvl, more).rows, map.rows), isFalse);

    (double, double, double) tint(String _) => (1, 0.8, 0.6);
    final block = LightRules.blockOf(map);
    final fixed = LightRules.tileEmitters(map, 0, 0, map.width, map.height,
        dark: false, biome: true);
    expect(fixed.length, greaterThanOrEqualTo(torches.length ~/ 2));
    final sw = Stopwatch()..start();
    final steady = LightGrid(0, 0, map.width, map.height, sub: 2);
    LightRules.accumulate(steady, fixed, block, tint);
    final build = sw.elapsedMicroseconds;
    final out = LightGrid(0, 0, map.width, map.height, sub: 2);
    final moving = [
      for (var i = 0; i < 4; i++)
        LightSource(lvl.spawn.$1 + i * 1.0, lvl.spawn.$2 + 0.5,
            kLightDefs[LightId.minero]!),
    ];
    sw.reset();
    const frames = 100;
    for (var f = 0; f < frames; f++) {
      out.copyFrom(steady);
      LightRules.accumulate(out, moving, block, tint);
    }
    final perFrame = sw.elapsedMicroseconds / frames;
    // ignore: avoid_print
    print('mina: ${fixed.length} antorchas, recálculo ${build / 1000} ms, '
        'por cuadro ${(perFrame / 1000).toStringAsFixed(3)} ms');
    expect(perFrame, lessThan(4000));
    expect(build, lessThan(200000)); // cold JIT, whole level
  });
}
