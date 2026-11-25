import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/town_dressing_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/rules/town_dressing_rules.dart';
import 'tile_painter.dart';

/// Muted palette for the town dressing: worn wood, cold stone, faded
/// cloth, warm but low lantern light (renown_town_growth.md § 5.2, § 6.4).
abstract final class DressingPalette {
  static const gravel = Color(0xFF8C8578);
  static const gravelDark = Color(0xFF6B655B);
  static const cobble = Color(0xFF7A7670);
  static const cobbleEdge = Color(0xFF55524D);
  static const plaza = Color(0xFF8E8A82);
  static const wood = Color(0xFF6B4A32);
  static const woodDark = Color(0xFF4A3322);
  static const stone = Color(0xFF7F7C78);
  static const stoneDark = Color(0xFF5A5854);
  static const water = Color(0xFF3E5A6E);
  static const paper = Color(0xFFCFC3A6);
  static const iron = Color(0xFF3B3A3E);
  static const glow = Color(0xFFF2C56B);
  static const cloth = [
    Color(0xFF8E3B3B), Color(0xFF3F6B5A), Color(0xFFB59A4A), Color(0xFF4B5C8A),
  ];
  static const flame = Color(0xFFE88A3A);
  static const flameCore = Color(0xFFF6D27A);
  static const ember = Color(0xFF5A2E22);
  static const crowd = [
    Color(0xFF6E5A4A), Color(0xFF4F5E6E), Color(0xFF6A4F5E), Color(0xFF5E6A4F),
  ];
  static const skin = Color(0xFFC9A383);
}

/// Draws the tier and event dressing of the town. The static parts are
/// recorded once into two pictures (ground and overhead) per map and
/// dressing; per frame only the few animated bits are drawn.
class TownDressingLayer {
  static const ts = TilePainter.ts;

  GameMap? _map;
  TownDressing? _dressing;
  (int, int)? _origin;
  TownDressingLayout layout = const TownDressingLayout();
  ui.Picture? _ground, _overhead;

  /// Number of times the static pictures were rebuilt (perf tests).
  int rebuilds = 0;

  void _ensure(GameMap map, TownDressing d, (int, int) origin) {
    if (identical(map, _map) && d == _dressing && origin == _origin &&
        _ground != null) {
      return;
    }
    _map = map;
    _dressing = d;
    _origin = origin;
    rebuilds++;
    layout = TownDressingRules.layout(map, d, ox: origin.$1, oy: origin.$2);
    _ground?.dispose();
    _overhead?.dispose();
    var rec = ui.PictureRecorder();
    _paintGround(Canvas(rec), map, d, origin);
    _ground = rec.endRecording();
    rec = ui.PictureRecorder();
    _paintOverhead(Canvas(rec), d);
    _overhead = rec.endRecording();
  }

  static void _r(Canvas c, Color col, double x, double y, double w, double h) =>
      c.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = col);

  static int _hash(int x, int y) {
    var h = x * 374761393 + y * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  void _paintGround(Canvas c, GameMap map, TownDressing d, (int, int) o) {
    final x1 = math.min(map.width, o.$1 + 26), y1 = math.min(map.height, o.$2 + 14);
    // Path material (§ 5.2): dirt is the base tile; gravel and cobble on top.
    if (d.tier.path != PathMaterial.dirt) {
      for (var y = math.max(0, o.$2); y < y1; y++) {
        for (var x = math.max(0, o.$1); x < x1; x++) {
          if (map.tileAt(x, y) != Tile.path) continue;
          final px = x * ts, py = y * ts, h = _hash(x, y);
          if (d.tier.path == PathMaterial.gravel) {
            for (var k = 0; k < 6; k++) {
              final v = (h >> (k * 4)) & 0xff;
              _r(c, k.isEven ? DressingPalette.gravel : DressingPalette.gravelDark,
                  px + (v % 14) + 1, py + ((v >> 3) % 14) + 1, 2, 1);
            }
          } else {
            _r(c, DressingPalette.cobbleEdge, px, py, ts, ts);
            final shift = y.isEven ? 0.0 : 4.0;
            for (var r = 0; r < 2; r++) {
              for (var k = -1; k < 2; k++) {
                final sx = px + k * 8 + shift + (r.isOdd ? 4 : 0);
                final l = math.max(px, sx + 1), rr = math.min(px + ts, sx + 8);
                if (rr > l) {
                  _r(c, DressingPalette.cobble, l, py + r * 8 + 1, rr - l, 6);
                }
              }
            }
          }
        }
      }
    }
    for (final (x, y) in layout.plaza) {
      final px = x * ts, py = y * ts;
      if (map.tileAt(x, y) == Tile.fountain) continue;
      _r(c, DressingPalette.cobbleEdge, px, py, ts, ts);
      _r(c, DressingPalette.plaza, px + 1, py + 1, 6, 6);
      _r(c, DressingPalette.plaza, px + 9, py + 1, 6, 6);
      _r(c, DressingPalette.plaza, px + 1, py + 9, 6, 6);
      _r(c, DressingPalette.plaza, px + 9, py + 9, 6, 6);
    }
    for (final (x, y) in layout.fences) {
      final px = x * ts, py = y * ts;
      _r(c, DressingPalette.woodDark, px + 2, py + 6, 2, 9);
      _r(c, DressingPalette.woodDark, px + 12, py + 6, 2, 9);
      _r(c, DressingPalette.wood, px, py + 8, ts, 2);
      _r(c, DressingPalette.wood, px, py + 12, ts, 2);
    }
    for (final (x, y) in layout.lamps) {
      final px = x * ts, py = y * ts;
      _r(c, DressingPalette.iron, px + 7, py + 3, 2, 12);
      _r(c, DressingPalette.iron, px + 5, py + 14, 6, 2);
      _r(c, DressingPalette.iron, px + 5, py + 1, 6, 1);
      _r(c, DressingPalette.stoneDark, px + 6, py + 2, 4, 3);
    }
    for (final (x, y) in layout.banners) {
      final px = x * ts, py = y * ts;
      _r(c, DressingPalette.woodDark, px + 7, py - 6, 2, 21);
      final col = DressingPalette.cloth[_hash(x, y) % DressingPalette.cloth.length];
      _r(c, col, px + 9, py - 5, 5, 9);
      _r(c, col, px + 9, py + 4, 2, 2);
      _r(c, col, px + 12, py + 4, 2, 2);
    }
    if (layout.well case (final x, final y)) {
      final px = x * ts, py = y * ts;
      _r(c, DressingPalette.stoneDark, px + 2, py + 8, 12, 7);
      _r(c, DressingPalette.stone, px + 3, py + 8, 10, 5);
      _r(c, DressingPalette.water, px + 5, py + 9, 6, 2);
      _r(c, DressingPalette.woodDark, px + 2, py + 1, 2, 8);
      _r(c, DressingPalette.woodDark, px + 12, py + 1, 2, 8);
      _r(c, DressingPalette.wood, px + 1, py, 14, 2);
    }
    if (layout.board case (final x, final y)) {
      final px = x * ts, py = y * ts;
      _r(c, DressingPalette.woodDark, px + 3, py + 8, 2, 7);
      _r(c, DressingPalette.woodDark, px + 11, py + 8, 2, 7);
      _r(c, DressingPalette.wood, px + 1, py + 2, 14, 8);
      _r(c, DressingPalette.paper, px + 3, py + 3, 4, 4);
      _r(c, DressingPalette.paper, px + 9, py + 4, 4, 5);
    }
    final ev = d.event;
    if (ev == null) return;
    for (final (i, (x, y)) in layout.stalls.indexed) {
      final px = x * ts, py = y * ts;
      final col = DressingPalette.cloth[i % DressingPalette.cloth.length];
      _r(c, DressingPalette.woodDark, px + 1, py + 2, 2, 13);
      _r(c, DressingPalette.woodDark, px + 29, py + 2, 2, 13);
      for (var k = 0; k < 8; k++) {
        _r(c, k.isEven ? col : DressingPalette.paper, px + k * 4, py, 4, 4);
      }
      _r(c, DressingPalette.wood, px + 1, py + 9, 30, 4);
      _r(c, DressingPalette.cloth[(i + 2) % 4], px + 6, py + 7, 3, 2);
      _r(c, DressingPalette.paper, px + 14, py + 7, 3, 2);
      _r(c, DressingPalette.cloth[(i + 1) % 4], px + 22, py + 7, 3, 2);
    }
    if (layout.centre case (final x, final y)) {
      final px = x * ts, py = y * ts;
      if (ev.centerpiece == EventCenterpiece.stage) {
        _r(c, DressingPalette.woodDark, px, py + 6, 32, 9);
        _r(c, DressingPalette.wood, px, py + 4, 32, 4);
        for (var k = 0; k < 4; k++) {
          _r(c, DressingPalette.wood, px + 2 + k * 8, py + 9, 4, 1);
        }
        _r(c, DressingPalette.woodDark, px + 1, py - 10, 2, 14);
        _r(c, DressingPalette.woodDark, px + 29, py - 10, 2, 14);
      } else {
        // Ring of stones and stacked logs; the flame is animated.
        for (var k = 0; k < 6; k++) {
          _r(c, DressingPalette.stoneDark, px + 6 + k * 4, py + 12, 3, 3);
        }
        _r(c, DressingPalette.woodDark, px + 9, py + 9, 14, 3);
        _r(c, DressingPalette.wood, px + 11, py + 7, 10, 2);
        _r(c, DressingPalette.ember, px + 12, py + 9, 8, 2);
      }
    }
  }

  void _paintOverhead(Canvas c, TownDressing d) {
    // Roof trim (§ 5.2): chimney, ridge, weathervane by tier.
    final v = d.tier.roofVariant;
    if (v > 0) {
      for (final (x, y) in layout.roofs) {
        final px = x * ts, py = y * ts;
        _r(c, DressingPalette.stoneDark, px + 20, py - 4, 4, 7);
        _r(c, DressingPalette.stone, px + 19, py - 5, 6, 2);
        if (v >= 2) _r(c, DressingPalette.woodDark, px + 4, py - 1, 24, 1);
        if (v >= 3) {
          _r(c, DressingPalette.iron, px + 9, py - 9, 1, 8);
          _r(c, DressingPalette.iron, px + 7, py - 9, 5, 1);
          _r(c, DressingPalette.iron, px + 10, py - 8, 2, 2);
        }
      }
    }
    // Garland strings: a sagging line of pixels with cloth pennants.
    for (final (i, (a, b)) in layout.garlands.indexed) {
      final ax = a.$1 * ts + 8.0, ay = a.$2 * ts + 2.0;
      final bx = b.$1 * ts + 8.0, by = b.$2 * ts + 2.0;
      final len = math.max((bx - ax).abs(), (by - ay).abs());
      final n = math.max(2, (len / 2).floor());
      for (var k = 0; k <= n; k++) {
        final f = k / n;
        final x = ax + (bx - ax) * f;
        final y = ay + (by - ay) * f + math.sin(f * math.pi) * len * 0.12;
        _r(c, DressingPalette.woodDark, x.floorToDouble(), y.floorToDouble(), 1, 1);
        if (k % 4 == 2) {
          final col = DressingPalette.cloth[(k ~/ 4 + i) % DressingPalette.cloth.length];
          _r(c, col, x.floorToDouble() - 1, y.floorToDouble() + 1, 3, 2);
          _r(c, col, x.floorToDouble(), y.floorToDouble() + 3, 1, 1);
        }
      }
    }
  }

  /// Lantern spots along the garlands (glow at night), in pixels.
  List<Offset> garlandLanterns() => [
        for (final (a, b) in layout.garlands)
          for (final f in const [0.33, 0.66])
            Offset(
                a.$1 * ts + 8.0 + (b.$1 - a.$1) * ts * f,
                a.$2 * ts + 2.0 + (b.$2 - a.$2) * ts * f +
                    math.sin(f * math.pi) *
                        math.max((b.$1 - a.$1).abs(), (b.$2 - a.$2).abs()) *
                        ts * 0.12)
      ];

  /// Under the actors: paths, fences, lamps, well, stalls, centrepiece,
  /// plus the animated flame and crowd. [secs] = 0 with reduce motion.
  void drawGround(Canvas c, GameMap map, TownDressing d, (int, int) origin,
      double secs, {required bool night}) {
    _ensure(map, d, origin);
    c.drawPicture(_ground!);
    if (night) {
      for (final (x, y) in layout.lamps) {
        _r(c, DressingPalette.glow, x * ts + 6, y * ts + 2, 4, 3);
      }
    }
    final ev = d.event;
    if (ev == null) return;
    if (layout.centre case (final x, final y)
        when ev.centerpiece == EventCenterpiece.bonfire) {
      final px = x * ts, py = y * ts;
      final f = (secs * 8).floor();
      for (var k = 0; k < 3; k++) {
        final hgt = 5 + ((_hash(f, k) % 4)).toDouble();
        _r(c, DressingPalette.flame, px + 11 + k * 4, py + 9 - hgt, 3, hgt);
      }
      _r(c, DressingPalette.flameCore, px + 14, py + 5, 4, 4);
    }
    if (layout.centre case (final x, final y)
        when ev.centerpiece == EventCenterpiece.stage) {
      final px = x * ts, py = y * ts;
      final sway = (math.sin(secs * 2) * 1.5).roundToDouble();
      _r(c, DressingPalette.cloth[0], px + 3, py - 10, 6 + sway, 5);
      _r(c, DressingPalette.cloth[2], px + 23 - sway, py - 10, 6 + sway, 5);
    }
    for (final (i, (x, y)) in layout.crowd.indexed) {
      final phase = _hash(x, y) % 7;
      final bob = ((secs * 3 + phase) % 2 < 1) ? 0.0 : -1.0;
      final px = x * ts + 4 + (_hash(y, x) % 6), py = y * ts + 3 + bob;
      final col = DressingPalette.crowd[i % DressingPalette.crowd.length];
      _r(c, col, px, py + 5, 5, 7);
      _r(c, DressingPalette.skin, px + 1, py + 1, 3, 4);
      _r(c, DressingPalette.iron, px + 1, py + 12, 1, 2);
      _r(c, DressingPalette.iron, px + 3, py + 12, 1, 2);
      // Every third one raises an arm now and then (cheering).
      if (i % 3 == 0 && bob < 0) _r(c, DressingPalette.skin, px + 5, py + 2, 1, 3);
    }
  }

  /// Over the actors: roof trim and garlands (lanterns lit at night).
  void drawOverhead(Canvas c, TownDressing d, {required bool night}) {
    if (_overhead == null || d != _dressing) return;
    c.drawPicture(_overhead!);
    if (!night || d.event == null) return;
    final glow = Paint()..color = DressingPalette.glow.withValues(alpha: 0.25);
    for (final o in garlandLanterns()) {
      c.drawRect(Rect.fromLTWH(o.dx - 3, o.dy - 1, 6, 6), glow);
      _r(c, DressingPalette.glow, o.dx - 1, o.dy + 1, 2, 2);
    }
  }

  /// Sky lanterns (§ 6.4): only at night during the event; they rise
  /// from the centre and loop. Above the night tint so they glow.
  void drawSky(Canvas c, TownDressing d, double secs, {required bool night}) {
    final ev = d.event;
    if (!night || ev == null || ev.skyLanterns == 0) return;
    final (cx, cy) = layout.centre ?? layout.roofs.firstOrNull ?? (13, 7);
    final glow = Paint()..color = DressingPalette.glow.withValues(alpha: 0.3);
    for (var i = 0; i < ev.skyLanterns; i++) {
      final h = _hash(i, 31);
      final life = 12.0 + h % 8;
      final p = ((secs + h % 97) % life) / life;
      final x = cx * ts + 16 + ((h >> 4) % 160 - 80) + math.sin(secs * 0.6 + i) * 4;
      final y = cy * ts - p * 180 - (h >> 9) % 40;
      final a = (p < 0.85 ? 1.0 : (1 - p) / 0.15).clamp(0.0, 1.0);
      c.drawRect(Rect.fromLTWH(x.floorToDouble() - 2, y.floorToDouble() - 2, 7, 8),
          Paint()..color = glow.color.withValues(alpha: 0.3 * a));
      _r(c, DressingPalette.glow.withValues(alpha: a), x.floorToDouble(),
          y.floorToDouble(), 3, 4);
      _r(c, DressingPalette.flame.withValues(alpha: a), x.floorToDouble() + 1,
          y.floorToDouble() + 3, 1, 1);
    }
  }
}
