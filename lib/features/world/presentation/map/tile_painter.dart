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
    // El mapa del mundo: el pueblo con el estilo del lobby, el resto al
    // aire libre (worldgen.md § 7.6).
    if (themeId == 'mundo') {
      lobby = inTown(tx, ty);
      if (lobby) themeId = 'lobby';
    }
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
      // Bosque: hojas secas sueltas.
      if (themeId == 'bosque' && h % 7 == 0) {
        _rect(c, const Color(0xFF8A6A32), px + jsShiftMod(h, 6, 12).abs() + 2,
            py + jsShiftMod(h, 10, 12).abs() + 2, 2, 1);
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
        // Fortaleza: losas con junta.
        if (themeId == 'fortaleza') {
          _rect(c, const Color(0x33000000), px, py + ts - 1, ts, 1);
          _rect(c, const Color(0x33000000),
              px + ((tx + ty).isEven ? 7 : 0), py, 1, ts);
        }
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
          case 'mundo':
            _tree(c, th, px, py, h);
          case 'bosque':
            _forestWall(c, th, px, py, h);
          case 'cavernas':
            _iceWall(c, th, px, py, h);
          case 'fortaleza':
            _brickWall(c, th, px, py, ty, h);
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
        // Hielo: placas brillantes quietas sobre el agua cian.
        if (themeId == 'cavernas' && h % 3 == 0) {
          _rect(c, const Color(0x55DFF9FF), px + jsShiftMod(h, 5, 9).abs() + 1,
              py + jsShiftMod(h, 9, 9).abs() + 1, 5, 3);
        }
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
      case Tile.grass:
        _grass(c, th, px, py, h);
      case Tile.tree:
        _grass(c, th, px, py, h);
        _tree(c, th, px, py, h);
      case Tile.rock:
        _grass(c, th, px, py, h);
        _rock(c, th, px, py, h);
      case Tile.stairsDown:
        floor();
        _stairsDown(c, th, px, py);
      case Tile.stairsUp:
        floor();
        _stairsUp(c, th, px, py);
      case Tile.vaultFloor:
        floor();
        // Borde dorado tenue: las baldosas de la bóveda forman una grilla.
        _rect(c, const Color(0x40FFD166), px, py, ts, 1);
        _rect(c, const Color(0x40FFD166), px, py, 1, ts);
        _rect(c, const Color(0x22000000), px + 1, py + ts - 1, ts - 1, 1);
        if (h % 7 == 0) {
          _rect(c, const Color(0x66FFD166), px + 7, py + 7, 2, 2);
        }
      default:
        final zone = Tile.entranceZone(ch);
        if (zone != null) {
          // Base de la entrada; el arco lo dibuja [entrance] encima.
          _grass(c, th, px, py, h);
          _rect(c, const Color(0xFF44474F), px, py + 4, ts, ts - 4);
          _rect(c, const Color(0xFF6B6F7A), px + 1, py + 4, ts - 2, 2);
        } else {
          // Tile desconocido: magenta, para que se note en las pruebas.
          _rect(c, const Color(0xFFFF00FF), px, py, ts, ts);
        }
    }
  }

  /// Todos los códigos que [draw] sabe dibujar (los de entrada `0`..`9`
  /// incluidos). Ver worldgen.md § 7.6.
  static bool handles(String ch) =>
      const {
        Tile.floor,
        Tile.path,
        Tile.wall,
        Tile.water,
        Tile.gate,
        Tile.merchant,
        Tile.armory,
        Tile.counter,
        Tile.grass,
        Tile.tree,
        Tile.rock,
        Tile.stairsDown,
        Tile.stairsUp,
        Tile.vaultFloor,
      }.contains(ch) ||
      Tile.entranceZone(ch) != null;

  // ------------------------------------------------------------------
  // Mundo
  // ------------------------------------------------------------------

  /// Pasto: verde claro con matas y alguna flor (sin cuadriculado).
  void _grass(Canvas c, MapTheme th, double px, double py, int h) {
    _rect(c, th.grass, px, py, ts, ts);
    if (h % 3 == 0) {
      final x = px + jsShiftMod(h, 3, 11).abs() + 2,
          y = py + jsShiftMod(h, 7, 10).abs() + 3;
      _rect(c, th.grass2, x, y, 1, 3);
      _rect(c, th.grass2, x + 2, y - 1, 1, 4);
      _rect(c, th.grass2, x + 4, y + 1, 1, 2);
    }
    if (h % 5 == 0) {
      _rect(c, th.grass2, px + jsShiftMod(h, 11, 13).abs(),
          py + jsShiftMod(h, 15, 13).abs(), 2, 2);
    }
    if (h % 17 == 0) {
      _rect(c, h % 2 == 0 ? const Color(0xFFFFD166) : const Color(0xFFFF8FA3),
          px + jsShiftMod(h, 5, 12).abs() + 2,
          py + jsShiftMod(h, 13, 12).abs() + 2, 2, 2);
    }
  }

  /// Árbol redondo (como el `#` de pradera) con los colores del tema.
  void _tree(Canvas c, MapTheme th, double px, double py, int h) {
    _rect(c, th.trunk, px + 6, py + 10, 4, 6);
    _circle(c, th.tree, px + 8, py + 7, 8);
    _circle(c, th.tree2, px + 6, py + 5, 4);
    if (h % 4 == 0) _rect(c, const Color(0x33000000), px + 10, py + 9, 3, 2);
  }

  /// Roca / montaña gris con nieve arriba.
  void _rock(Canvas c, MapTheme th, double px, double py, int h) {
    final shift = (h % 3 - 1).toDouble();
    _paint.color = th.rock;
    c.drawPath(
        Path()
          ..moveTo(px + 8 + shift, py)
          ..lineTo(px + 16, py + 15)
          ..lineTo(px, py + 15)
          ..close(),
        _paint);
    _paint.color = th.rock2;
    c.drawPath(
        Path()
          ..moveTo(px + 8 + shift, py)
          ..lineTo(px + 8 + shift, py + 15)
          ..lineTo(px, py + 15)
          ..close(),
        _paint);
    _paint.color = const Color(0xFFE8F0FF);
    c.drawPath(
        Path()
          ..moveTo(px + 8 + shift, py)
          ..lineTo(px + 11 + shift, py + 5)
          ..lineTo(px + 8 + shift, py + 4)
          ..lineTo(px + 5 + shift, py + 5)
          ..close(),
        _paint);
    _rect(c, const Color(0x44000000), px, py + 15, ts, 1);
  }

  /// Arco de piedra de la entrada a la zona [zone], de 32 × 40 px con la
  /// base en el borde de abajo del tile de la entrada ([tx], [ty]). Lo
  /// dibuja `MapGame` encima de los tiles (sobresale del tile). Abierta:
  /// portal del color de la zona que late; bloqueada o próximamente:
  /// interior oscuro con candado.
  void entrance(Canvas c, int tx, int ty, int zone,
      {required bool open, required double t}) {
    const stone = Color(0xFF8A8E9A),
        stoneMid = Color(0xFF6B6F7A),
        stoneDark = Color(0xFF44474F);
    final cx = tx * ts + 8, by = ty * ts + ts;
    final left = cx - 16, top = by - 40;
    // Sombra y escalón.
    _rect(c, const Color(0x55000000), left - 1, by - 2, 34, 3);
    _rect(c, stoneDark, left, by - 4, 32, 4);
    _rect(c, stoneMid, left, by - 4, 32, 1);
    // Pilares.
    for (final x in [left + 2, left + 23]) {
      _rect(c, stoneDark, x, top + 6, 7, 30);
      _rect(c, stone, x, top + 6, 5, 30);
      for (var y = top + 12; y < by - 4; y += 7) {
        _rect(c, stoneDark, x, y, 7, 1);
      }
    }
    // Interior.
    final ix = left + 9, iy = top + 8, iw = 14.0, ih = by - 4 - iy;
    if (open) {
      final col = zoneColor(zone);
      final a = (0.55 + 0.25 * math.sin(t / 220 + zone)).clamp(0.0, 1.0);
      _rect(c, const Color(0xFF101018), ix, iy, iw, ih);
      _rect(c, col.withValues(alpha: a), ix, iy, iw, ih);
      _rect(c, col.withValues(alpha: 0.35), ix + 3, iy + 3, iw - 6, ih - 6);
      // Chispas que suben.
      for (var i = 0; i < 3; i++) {
        final q = ((t / 900 + i / 3 + zone * 0.17) % 1.0);
        _rect(c, const Color(0xCCFFFFFF), ix + 2 + ((i * 5 + zone) % 10),
            iy + ih - 2 - q * (ih - 4), 1, 2);
      }
    } else {
      _rect(c, const Color(0xFF1C1E25), ix, iy, iw, ih);
      _rect(c, const Color(0xFF2A2D36), ix, iy, iw, 2);
      // Candado.
      final lx = cx - 4, ly = iy + ih / 2 - 4;
      _rect(c, kLockedZoneColor, lx + 1, ly - 4, 6, 1);
      _rect(c, kLockedZoneColor, lx, ly - 3, 1, 4);
      _rect(c, kLockedZoneColor, lx + 7, ly - 3, 1, 4);
      _rect(c, const Color(0xFFB0B3BC), lx - 1, ly + 1, 10, 8);
      _rect(c, const Color(0xFF1C1E25), lx + 3, ly + 3, 2, 3);
    }
    // Dintel con piedra clave.
    _rect(c, stoneDark, left - 2, top, 36, 8);
    _rect(c, stone, left - 2, top, 36, 6);
    _rect(c, stoneMid, left - 2, top + 5, 36, 1);
    _rect(c, stoneDark, cx - 4, top - 2, 8, 9);
    _rect(c, open ? zoneColor(zone) : kLockedZoneColor, cx - 2, top, 4, 4);
  }

  // ------------------------------------------------------------------
  // Muros de las zonas
  // ------------------------------------------------------------------

  /// Bosque: árboles densos; pino o copa redonda según el hash.
  void _forestWall(Canvas c, MapTheme th, double px, double py, int h) {
    _rect(c, const Color(0xFF0E2A14), px, py, ts, ts);
    if (h % 3 != 0) {
      _rect(c, th.trunk, px + 7, py + 12, 2, 4);
      _paint.color = th.wall;
      c.drawPath(
          Path()
            ..moveTo(px + 8, py)
            ..lineTo(px + 15, py + 13)
            ..lineTo(px + 1, py + 13)
            ..close(),
          _paint);
      _paint.color = th.wall2;
      c.drawPath(
          Path()
            ..moveTo(px + 8, py + 1)
            ..lineTo(px + 11, py + 7)
            ..lineTo(px + 5, py + 7)
            ..close(),
          _paint);
    } else {
      _rect(c, th.trunk, px + 6, py + 11, 4, 5);
      _circle(c, th.wall, px + 8, py + 7, 8);
      _circle(c, th.wall2, px + 6, py + 5, 3);
      _rect(c, const Color(0x55000000), px + 9, py + 10, 4, 2);
    }
  }

  /// Cavernas: roca helada con facetas y cristales de hielo.
  void _iceWall(Canvas c, MapTheme th, double px, double py, int h) {
    _rect(c, th.wall, px, py, ts, ts);
    _rect(c, th.rock2, px + jsShiftMod(h, 3, 8).abs(),
        py + jsShiftMod(h, 6, 8).abs() + 2, 6, 4);
    _rect(c, th.rock, px + jsShiftMod(h, 9, 9).abs(),
        py + jsShiftMod(h, 12, 6).abs() + 8, 7, 3);
    if (h % 4 == 0) {
      final x = px + jsShiftMod(h, 5, 10).abs() + 3;
      _paint.color = th.wall2;
      c.drawPath(
          Path()
            ..moveTo(x, py + 2)
            ..lineTo(x + 2, py + 9)
            ..lineTo(x - 2, py + 9)
            ..close(),
          _paint);
      _rect(c, const Color(0xCCFFFFFF), x - 1, py + 5, 1, 2);
    }
  }

  /// Fortaleza: ladrillo oscuro con juntas desfasadas por fila.
  void _brickWall(
      Canvas c, MapTheme th, double px, double py, int ty, int h) {
    _rect(c, th.wall, px, py, ts, ts);
    const mortar = Color(0xFF15121A);
    final top = th.wall2.withValues(alpha: 0.35);
    for (var r = 0; r < 4; r++) {
      final y = py + r * 4;
      _rect(c, mortar, px, y + 3, ts, 1);
      final off = (r + ty).isEven ? 0.0 : 4.0;
      _rect(c, mortar, px + off + 3, y, 1, 3);
      _rect(c, mortar, px + off + 11, y, 1, 3);
      _rect(c, top, px, y, ts, 1);
    }
    if (h % 9 == 0) _rect(c, const Color(0xFF3E5A3A), px + 2, py + 13, 4, 2);
    if (h % 7 == 0) _rect(c, const Color(0xAA000000), px + 9, py + 5, 1, 5);
  }

  // ------------------------------------------------------------------
  // Escaleras
  // ------------------------------------------------------------------

  /// `>`: agujero oscuro con peldaños que bajan.
  void _stairsDown(Canvas c, MapTheme th, double px, double py) {
    _rect(c, th.wall2, px + 1, py + 1, 14, 14);
    _rect(c, const Color(0xFF07070C), px + 2, py + 2, 12, 12);
    const steps = [Color(0xFF8A8A96), Color(0xFF5E5E6A), Color(0xFF3A3A44)];
    for (var i = 0; i < steps.length; i++) {
      _rect(c, steps[i], px + 3 + i, py + 3 + i * 3, 10 - i * 2.0, 2);
    }
    _rect(c, const Color(0xFFFFD166), px + 7, py + 12, 2, 1);
  }

  /// `<`: peldaños claros que suben.
  void _stairsUp(Canvas c, MapTheme th, double px, double py) {
    const steps = [
      Color(0xFFDDE0E8),
      Color(0xFFC2C6D0),
      Color(0xFFA6AAB6),
      Color(0xFF8A8E9A),
    ];
    for (var i = 0; i < steps.length; i++) {
      final y = py + 2 + i * 3;
      _rect(c, steps[i], px + 2, y, 12, 3);
      _rect(c, const Color(0x55000000), px + 2, y + 2, 12, 1);
    }
    _rect(c, th.wall2, px + 1, py + 1, 1, 14);
    _rect(c, th.wall2, px + 14, py + 1, 1, 14);
  }
}
