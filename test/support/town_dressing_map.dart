import 'package:echos_del_tiempo/game_engine/models/game_map.dart';

/// A 26x14 town: a cross of paths, a fountain in the middle and six
/// 2x2 houses (renown_town_growth.md § 9, dressing tests and previews).
GameMap dressingTestMap() {
  const w = 26, h = 14;
  final g = [for (var y = 0; y < h; y++) List.filled(w, Tile.grass)];
  for (var x = 0; x < w; x++) {
    g[7][x] = Tile.path;
  }
  for (var y = 0; y < h; y++) {
    g[y][12] = Tile.path;
  }
  for (final (x, y) in const [(12, 6), (13, 6), (12, 7), (13, 7)]) {
    g[y][x] = Tile.fountain;
  }
  for (final (hx, hy) in const [
    (3, 2), (8, 2), (17, 2), (21, 2), (4, 10), (19, 10)
  ]) {
    for (final (dx, dy) in const [(0, 0), (1, 0), (0, 1), (1, 1)]) {
      g[hy + dy][hx + dx] = Tile.house;
    }
  }
  g[3][24] = Tile.tree;
  return GameMap(
      width: w,
      height: h,
      rows: [for (final r in g) r.join()],
      theme: 'pueblo',
      spawn: const WorldPoint(1, 7),
      lobby: true);
}
