import 'package:echos_del_tiempo/features/world/presentation/map/mine_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/mine_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/mine_work_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lvl =
      MiningRules.level(MiningRules.placeOf(kBosque, 0, 0), worldId: 'w1')!;
  const st = MineLevelState();

  test('hiddenVeins: only sealed veins inside the radius', () {
    expect(MineWorkRules.hiddenVeins(lvl, st, 10, 10, 0), isEmpty);
    final (sx, sy) = lvl.station;
    final all = MineWorkRules.hiddenVeins(
        lvl, st, lvl.width / 2, lvl.height / 2, 999);
    expect(all, isNotEmpty);
    for (final (x, y) in all) {
      expect(MineTile.veins, contains(MiningRules.tileAt(lvl, st, x, y)));
      for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        expect(Tile.isWalkable(MiningRules.tileAt(lvl, st, x + dx, y + dy)),
            isFalse);
      }
    }
    final near = MineWorkRules.hiddenVeins(lvl, st, sx + 0.5, sy + 0.5, 4);
    for (final (x, y) in near) {
      final dx = x + 0.5 - (sx + 0.5), dy = y + 0.5 - (sy + 0.5);
      expect(dx * dx + dy * dy, lessThanOrEqualTo(16));
    }
  });

  test('sparkle is intermittent and the tile list is cached', () {
    var on = 0;
    for (var t = 0.0; t < 14000; t += 50) {
      if (MineLayer.sparkleOn(3, 7, t)) on++;
    }
    expect(on, greaterThan(0));
    expect(on, lessThan(280 * 0.3));
    final layer = MineLayer();
    final a = layer.detectTiles(lvl, st, 20.2, 20.2, 6);
    final b = layer.detectTiles(lvl, st, 20.7, 20.9, 6);
    expect(identical(a, b), isTrue);
  });
}
