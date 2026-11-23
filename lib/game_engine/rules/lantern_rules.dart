import 'dart:math' as math;

import '../models/game_map.dart';
import 'mulberry32.dart';
import 'zone_generators.dart';

/// Faroles de las mazmorras oscuras (lighting.md § 5.5). Función pura del
/// piso y su semilla; con su propia tirada para no cambiar el resto.
abstract final class LanternRules {
  /// Tiles caminables del piso por farol.
  static const area = 160;
  static const minCount = 2, maxCount = 12;

  /// Distancia mínima entre faroles (tiles).
  static const gap = 12.0;

  /// Distancia mínima a la llegada, las escaleras y los otros PdI.
  static const clearance = 3;

  /// Id del farol [k] del piso [floor] (los otros PdI usan los primeros).
  static int idOf(int floor, int k) => floor * 100 + 99 - k;

  /// Dónde van los faroles de [g] (coordenadas del piso), con la semilla
  /// del piso [seed].
  static List<(int, int)> place(FloorGen g, int seed) {
    final rows = g.rows;
    final h = rows.length, w = rows.first.length;
    String at(int x, int y) =>
        x >= 0 && y >= 0 && x < w && y < h ? rows[y][x] : Tile.wall;
    bool open(String c) => Tile.isWalkable(c) && c != Tile.voidTile;

    var walk = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (open(at(x, y))) walk++;
      }
    }
    final want = (walk ~/ area).clamp(minCount, maxCount);

    final keep = <(int, int)>[
      g.spawn,
      if (g.stairsDown case final s?) s,
      if (g.stairsUp case final s?) s,
      for (final p in g.pois) (p.tx, p.ty),
      ...g.chestSpots,
      ...g.chestMarks,
      ...g.eliteMarks,
    ];
    final noGo = [
      TileRect(g.arena.x - 1, g.arena.y - 1, g.arena.w + 2, g.arena.h + 2),
      ...g.vaults,
    ];
    bool inRect(TileRect q, int x, int y) =>
        x >= q.x && y >= q.y && x < q.x + q.w && y < q.y + q.h;

    final cand = <(int, int)>[];
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        if (at(x, y) != Tile.floor) continue;
        // Los 8 vecinos caminables: un sólido ahí no corta ningún paso.
        var ok = true;
        for (var dy = -1; dy <= 1 && ok; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if ((dx != 0 || dy != 0) && !open(at(x + dx, y + dy))) {
              ok = false;
              break;
            }
          }
        }
        if (!ok || noGo.any((q) => inRect(q, x, y))) continue;
        if (keep.any((k) =>
            math.max((k.$1 - x).abs(), (k.$2 - y).abs()) < clearance)) {
          continue;
        }
        cand.add((x, y));
      }
    }
    final r = mulberry32((seed ^ 0x1A7E) | 0);
    for (var i = cand.length - 1; i > 0; i--) {
      final j = (r() * (i + 1)).floor();
      final t = cand[i];
      cand[i] = cand[j];
      cand[j] = t;
    }
    final out = <(int, int)>[];
    for (final c in cand) {
      if (out.length >= want) break;
      if (out.any((o) {
        final dx = o.$1 - c.$1, dy = o.$2 - c.$2;
        return dx * dx + dy * dy < gap * gap;
      })) {
        continue;
      }
      out.add(c);
    }
    return out;
  }
}
