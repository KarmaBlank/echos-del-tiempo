import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/models/game_session.dart' show SessionPlayer;
import '../../../../game_engine/data/farming_catalog.dart' show parseCropKey;
import '../../../../game_engine/rules/shop_interior_rules.dart';
import '../../../combat/presentation/sprite_catalog.dart';

/// Draws the shop interior (player_shop.md § 6) over its tiles: plank
/// floor, walls with shelves, the exit door and one counter per player
/// with their name and what they have on sale as small icons. 8-bit
/// flat colours; item icons come from the sprite manifest via [icon].
class ShopInteriorLayer {
  ShopInteriorLayer(this.icon);

  /// Life icon by id and category (`GameSprites.lifeIcon`).
  final ui.Image? Function(String id, String category) icon;

  static const _ts = 16.0;
  static const _plank = Color(0xFF8A5A32);
  static const _plankDark = Color(0xFF6E4426);
  static const _wall = Color(0xFF5C3A20);
  static const _wallTop = Color(0xFF3A2414);
  static const _shelf = Color(0xFF9C6A3C);
  static const _counter = Color(0xFFB07A44);
  static const _counterTop = Color(0xFFD9A066);
  static const _outline = Color(0xFF1A1420);
  static const _door = Color(0xFF2E1C10);
  static const _rug = Color(0xFF8A3A3A);
  static const _goods = [
    Color(0xFF3A6A9A),
    Color(0xFFA83A3A),
    Color(0xFFE0C060),
    Color(0xFF4E8A4A),
  ];

  final Paint _p = Paint();

  void _rect(Canvas c, double x, double y, double w, double h, Color col) =>
      c.drawRect(Rect.fromLTWH(x, y, w, h), _p..color = col);

  /// (icon id, category) of a stall cell (`fish:` / `crop:` / `ore:`).
  static (String, String)? iconOf(String cell) {
    final i = cell.indexOf(':');
    if (i < 0) return null;
    final kind = cell.substring(0, i), id = cell.substring(i + 1);
    return switch (kind) {
      'fish' => (id, 'pescado'),
      'crop' => parseCropKey(id) == null
          ? null
          : ('cosecha_${parseCropKey(id)!.$1.id}', 'cosecha'),
      'ore' => ('mat_$id', 'herramienta'),
      _ => null,
    };
  }

  /// Floor, walls, shelves and door (under the actors).
  void drawRoom(Canvas c) {
    const rows = ShopInteriorRules.rows;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final px = x * _ts, py = y * _ts;
        if (rows[y][x] == '#') {
          _rect(c, px, py, _ts, _ts, _wall);
          _rect(c, px, py, _ts, 3, _wallTop);
        } else {
          _rect(c, px, py, _ts, _ts, _plank);
          // Staggered plank seams.
          _rect(c, px, py + 7, _ts, 1, _plankDark);
          _rect(c, px, py + 15, _ts, 1, _plankDark);
          _rect(c, px + (y.isEven ? 3 : 11), py, 1, 7, _plankDark);
          _rect(c, px + (y.isEven ? 11 : 3), py + 8, 1, 7, _plankDark);
        }
      }
    }
    // Rug from the door to the middle.
    _rect(c, 7 * _ts + 2, 4 * _ts, 2 * _ts - 4, 6 * _ts, _rug);
    // Shelves on the back wall, with goods.
    for (final sx in [1, 11]) {
      final x0 = sx * _ts, y0 = 1 * _ts;
      _rect(c, x0, y0, 4 * _ts, _ts, _shelf);
      for (var k = 0; k < 2; k++) {
        _rect(c, x0, y0 + 3 + k * 7, 4 * _ts, 1, _outline);
        for (var g = 0; g < 8; g++) {
          _rect(c, x0 + 3 + g * 7.5, y0 + k * 7, 4, 3,
              _goods[(g + k + sx) % _goods.length]);
        }
      }
    }
    // Exit door.
    final (dx, dy) = ShopInteriorRules.door;
    _rect(c, dx * _ts + 4, dy * _ts, 2 * _ts - 8, _ts, _door);
    _rect(c, dx * _ts + 4, dy * _ts, 2 * _ts - 8, 2, _counterTop);
  }

  /// Counters with the owner's name and listings. [label] draws a world
  /// label (text, x, y, colour, size).
  void drawCounters(
      Canvas c,
      Map<String, SessionPlayer> players,
      String freeLabel,
      void Function(String, double, double, Color, double) label) {
    final owners = ShopInteriorRules.owners(players.values);
    for (var i = 0; i < ShopInteriorRules.counters; i++) {
      final (tx, ty) = ShopInteriorRules.counterTiles[i];
      final x0 = tx * _ts, y0 = ty * _ts;
      _rect(c, x0 - 1, y0 - 1, 2 * _ts + 2, _ts + 2, _outline);
      _rect(c, x0, y0, 2 * _ts, _ts, _counter);
      _rect(c, x0, y0, 2 * _ts, 5, _counterTop);
      final o = i < owners.length ? players[owners[i]] : null;
      label(o?.name.toUpperCase() ?? freeLabel, x0 + _ts, y0 + _ts + 7,
          o == null ? const Color(0xFF8A8F9A) : const Color(0xFFFFE9A8), 6);
      if (o == null) continue;
      final ls = o.profile.life.stall.listings;
      for (var k = 0; k < ls.length && k < 4; k++) {
        final key = iconOf(ls[k].cell);
        final im = key == null ? null : icon(key.$1, key.$2);
        final r = Rect.fromLTWH(x0 + 1 + k * 7.5, y0 - 4, 7, 7);
        if (im == null) {
          _rect(c, r.left + 1, r.top + 2, 5, 4, _goods[k % _goods.length]);
          continue;
        }
        c.drawImageRect(
            im,
            Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
            r,
            SpriteCatalog.pixelPaint());
      }
    }
  }
}
