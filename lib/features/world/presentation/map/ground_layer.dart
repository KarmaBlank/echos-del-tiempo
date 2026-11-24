import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/rules/weather_rules.dart';
import 'map_themes.dart';

/// Seasonal and weather marks on the ground (weather_seasons.md § 6.3):
/// frost / snow in winter, puddles while it rains, leaves in autumn and
/// flowers in spring, over the same base tiles. Only in the town and the
/// outdoor biome lobbies whose climate turns them on; never in dungeons,
/// caves or on hot ground. Cheap: one tint rect plus a few colored
/// points per visible ground tile, written into buffers allocated once.
class MapGroundLayer {
  static const ts = 16.0;

  /// Points per color buffer (enough for a full screen of tiles).
  static const maxPoints = 4096;

  final _a = Float32List(maxPoints * 2);
  final _b = Float32List(maxPoints * 2);
  static final _pa = Paint()
    ..isAntiAlias = false
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.square;
  static final _pb = Paint()
    ..isAntiAlias = false
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.square;
  static final _tint = Paint()..isAntiAlias = false;

  /// Which overlay applies now (`null` = none), from the biome's climate,
  /// the season and the weather on screen.
  static GroundMark? markFor(
      {required bool lobby,
      required String? place,
      required Season season,
      required Weather weather}) {
    if (!lobby) return null;
    final fx = climateOf(place).groundShown;
    if (weather.wet && fx.puddles) return GroundMark.puddles;
    if (season == Season.winter && fx.snow) return GroundMark.snow;
    if (season == Season.autumn && fx.leaves) return GroundMark.leaves;
    if (season == Season.spring && fx.flowers) return GroundMark.flowers;
    return null;
  }

  static bool _ground(String t) =>
      t == Tile.grass || t == Tile.floor || t == Tile.path;

  static int _hash(int x, int y) {
    var h = x * 374761393 + y * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  /// Fills [a] and [b] with the points of [mark] for the ground tiles in
  /// [view] (px of the world); returns how many of each. Pure.
  static (int, int) fill(GameMap map, Rect view, GroundMark mark,
      Float32List a, Float32List b) {
    var na = 0, nb = 0;
    final capA = a.length ~/ 2, capB = b.length ~/ 2;
    final x0 = (view.left / ts).floor().clamp(0, map.width - 1);
    final y0 = (view.top / ts).floor().clamp(0, map.height - 1);
    final x1 = (view.right / ts).ceil().clamp(0, map.width - 1);
    final y1 = (view.bottom / ts).ceil().clamp(0, map.height - 1);
    void add(Float32List buf, int n, double x, double y) {
      buf[n * 2] = x;
      buf[n * 2 + 1] = y;
    }

    final (every, pa, pb) = switch (mark) {
      GroundMark.snow => (2, 3, 0),
      GroundMark.puddles => (9, 4, 0),
      GroundMark.leaves => (4, 1, 1),
      GroundMark.flowers => (6, 1, 1),
    };
    for (var ty = y0; ty <= y1; ty++) {
      final row = map.rows[ty];
      for (var tx = x0; tx <= x1; tx++) {
        if (!_ground(row[tx])) continue;
        final h = _hash(tx, ty);
        if (h % every != 0) continue;
        final bx = tx * ts, by = ty * ts;
        for (var k = 0; k < pa && na < capA; k++) {
          final hk = h >> (4 + k * 5);
          final ox = mark == GroundMark.puddles
              ? 6 + (h >> 8) % 4 + (k & 1)
              : (hk % 14) + 1.0;
          final oy = mark == GroundMark.puddles
              ? 8 + (h >> 12) % 4 + (k >> 1)
              : ((hk >> 3) % 14) + 1.0;
          add(a, na++, bx + ox, by + oy);
        }
        for (var k = 0; k < pb && nb < capB; k++) {
          final hk = h >> (12 + k * 5);
          add(b, nb++, bx + (hk % 14) + 1, by + ((hk >> 4) % 14) + 1);
        }
      }
    }
    return (na, nb);
  }

  Float32List? _va, _vb;
  int _na = -1, _nb = -1;

  void draw(Canvas c, GameMap map, Rect view, GroundMark? mark) {
    if (mark == null) return;
    final (tint, ca, cb) = switch (mark) {
      GroundMark.snow => (GroundPalette.snowTint, GroundPalette.frost, GroundPalette.frost),
      GroundMark.puddles => (GroundPalette.wetTint, GroundPalette.puddle, GroundPalette.puddle),
      GroundMark.leaves => (null, GroundPalette.leaf, GroundPalette.leafDark),
      GroundMark.flowers => (null, GroundPalette.petal, GroundPalette.petalAlt),
    };
    if (tint != null) {
      _tint.color = tint;
      c.drawRect(view, _tint);
    }
    final (na, nb) = fill(map, view, mark, _a, _b);
    if (na > 0) {
      if (na != _na || _va == null) {
        _na = na;
        _va = Float32List.sublistView(_a, 0, na * 2);
      }
      _pa.color = ca;
      c.drawRawPoints(ui.PointMode.points, _va!, _pa);
    }
    if (nb > 0) {
      if (nb != _nb || _vb == null) {
        _nb = nb;
        _vb = Float32List.sublistView(_b, 0, nb * 2);
      }
      _pb.color = cb;
      c.drawRawPoints(ui.PointMode.points, _vb!, _pb);
    }
  }
}

enum GroundMark { snow, puddles, leaves, flowers }
