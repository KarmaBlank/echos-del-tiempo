import 'dart:math' as math;
import 'dart:ui';

import '../../../../game_engine/models/game_map.dart';
import 'map_themes.dart';

/// `drawTile` del prototipo (líneas 964-988). Dibuja un tile de 16 px en
/// (px, py) del lienzo virtual. Ver docs/specs/exploration.md § "Tiles".
class TilePainter {
  TilePainter();

  static const ts = 16.0;

  final _paint = Paint()..isAntiAlias = false;

  /// Hash por tile `((tx*73856093)^(ty*19349663))>>>0` con la aritmética
  /// de 32 bits de JS (sin signo).
  static int tileHash(int tx, int ty) =>
      ((tx * 73856093).toSigned(32) ^ (ty * 19349663).toSigned(32)) &
      0xFFFFFFFF;

  /// `(h >> n) % m` de JS: `>>` trabaja sobre el int32 con signo y `%`
  /// conserva el signo del dividendo.
  static int jsShiftMod(int h, int n, int m) =>
      (h.toSigned(32) >> n).remainder(m);

  void _rect(Canvas c, Color color, double x, double y, double w, double h) {
    _paint.color = color;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _paint);
  }

  void _circle(Canvas c, Color color, double x, double y, double r) {
    _paint.color = color;
    c.drawCircle(Offset(x, y), r, _paint);
  }

  void draw(
    Canvas c,
    String ch,
    double px,
    double py,
    String themeId,
    int tx,
    int ty, {
    required double t,
    required bool gateOpen,
    required bool lobby,
  }) {
    final th = mapTheme(themeId);
    final h = tileHash(tx, ty);

    void floor() {
      _rect(c, th.ground, px, py, ts, ts);
      if (lobby) {
        if ((tx + ty) % 2 == 0) _rect(c, th.ground2, px, py, ts, ts);
        _rect(c, const Color(0x08FFFFFF), px, py, ts, 1);
        return;
      }
      if (h % 3 == 0) {
        _rect(c, th.ground2, px + jsShiftMod(h, 3, 12),
            py + jsShiftMod(h, 7, 12), 2, 2);
      }
      if (h % 5 == 0) {
        _rect(c, th.ground2, px + jsShiftMod(h, 11, 13),
            py + jsShiftMod(h, 15, 13), 1, 3);
      }
    }

    switch (ch) {
      case Tile.floor:
        floor();
      case Tile.path:
        _rect(c, th.path, px, py, ts, ts);
        if (h % 2 == 0) {
          _rect(c, th.path2, px + jsShiftMod(h, 4, 13),
              py + jsShiftMod(h, 9, 13), 2, 2);
        }
        if (lobby) _rect(c, const Color(0x33FFD166), px, py, ts, 1);
      case Tile.wall:
        if (lobby) {
          _rect(c, th.wall, px, py, ts, ts);
          _rect(c, th.wall2, px, py + ts - 4, ts, 2);
          if (ty == 0 && tx % 4 == 0) {
            _rect(c, const Color(0x5548DBFB), px + 5, py + 3, 6, 8);
          }
          return;
        }
        floor();
        switch (themeId) {
          case 'pradera':
            _rect(c, const Color(0xFF4A2F1A), px + 6, py + 10, 4, 6);
            _circle(c, th.wall, px + 8, py + 7, 8);
            _circle(c, th.wall2, px + 6, py + 5, 4);
          case 'ruinas':
            _rect(c, th.wall, px + 1, py + 1, ts - 2, ts - 1);
            _rect(c, th.wall2, px + 1, py + 1, ts - 2, 3);
            _rect(c, const Color(0x55000000), px + 1, py + 8, ts - 2, 1);
            _rect(c, const Color(0x55000000), px + (h % 2 != 0 ? 5 : 10),
                py + 4, 1, 4);
          default:
            _rect(c, th.wall, px, py, ts, ts);
            _paint.color = th.wall2;
            c.drawPath(
                Path()
                  ..moveTo(px + 8, py + 1)
                  ..lineTo(px + 12, py + 13)
                  ..lineTo(px + 4, py + 13)
                  ..close(),
                _paint);
            _rect(c, const Color(0x55FFFFFF), px + 7, py + 4, 1, 6);
        }
      case Tile.water:
        _rect(c, th.water, px, py, ts, ts);
        final o = (t / 250 + tx).floor() % 4;
        _rect(c, const Color(0x40FFFFFF), px + o * 3, py + 4 + (ty % 2) * 6,
            5, 1);
      case Tile.gate:
        if (gateOpen) {
          _rect(c, th.path, px, py, ts, ts);
        } else {
          floor();
          final a = (0.5 + 0.3 * math.sin(t / 120 + ty)).clamp(0.0, 1.0);
          final bar = Color.fromRGBO(255, 71, 87, a);
          for (var i = 2; i < ts; i += 5) {
            _rect(c, bar, px + i, py, 2, ts);
          }
        }
      case Tile.merchant:
        floor();
        _rect(c, const Color(0xFF6B4423), px, py + 6, ts, ts - 6);
        _rect(c, const Color(0xFFC08A4A), px, py + 6, ts, 3);
        for (var i = 0; i < 4; i++) {
          _rect(c, i.isOdd ? const Color(0xFFFFFFFF) : const Color(0xFFE74C3C),
              px + i * 4, py - 2, 4, 5);
        }
        _rect(c, const Color(0xFF8A5A2B), px + (tx.isOdd ? ts - 2 : 0), py - 2,
            2, 9);
        if (tx.isEven) {
          _rect(c, const Color(0xFFFF6B81), px + 4, py + 3, 3, 3);
          _rect(c, const Color(0xFF74B9FF), px + 9, py + 3, 3, 3);
        }
      case Tile.armory:
        floor();
        _rect(c, const Color(0xFF3D3D4A), px, py + 3, ts, ts - 3);
        _rect(c, const Color(0xFF8395A7), px, py + 3, ts, 4);
        if (tx.isOdd) {
          _rect(c, const Color(0xFFDFE6E9), px + 7, py - 6, 2, 10);
        } else {
          _rect(c, const Color(0xFF8A5A2B), px + 7, py - 6, 1, 10);
          _rect(c, const Color(0xFFFF7B29), px + 6, py - 8, 3, 3);
        }
      case Tile.counter:
        floor();
        _rect(c, const Color(0xFF6B4423), px, py + 3, ts, ts - 3);
        _rect(c, const Color(0xFFC08A4A), px, py + 3, ts, 4);
        if (tx == 12 || tx == 13) {
          _rect(c, const Color(0xFF48DBFB), px + 4, py - 4, 8, 6);
        }
    }
  }
}
