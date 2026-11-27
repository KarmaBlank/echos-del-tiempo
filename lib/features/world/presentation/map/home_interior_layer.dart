import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/rules/home_interior_rules.dart';
import '../../../combat/presentation/sprite_catalog.dart';

/// Draws the player house interior (player_house.md § 2) under the
/// actors: the room sprite (`items.vida_home_room`: plank floor, walls,
/// window, beds, rug, door). The image comes from the sprite manifest via
/// [icon]; without it (tests, a missing file) it falls back to flat 8-bit
/// shapes.
class HomeInteriorLayer {
  HomeInteriorLayer(this.icon);

  /// Life icon by id and category (`GameSprites.lifeIcon`).
  final ui.Image? Function(String id, String category) icon;

  static const _ts = 16.0;
  static const _plank = Color(0xFF8A5A32);
  static const _wall = Color(0xFF5C3A20);
  static const _bed = Color(0xFFB04A4A);
  static const _pillow = Color(0xFFF0E0B8);
  static const _door = Color(0xFF2E1C10);

  final Paint _p = Paint();

  void _rect(Canvas c, double x, double y, double w, double h, Color col) =>
      c.drawRect(Rect.fromLTWH(x, y, w, h), _p..color = col);

  void drawRoom(Canvas c) {
    if (icon('home_room', '') case final room?) {
      c.drawImageRect(
          room,
          Rect.fromLTWH(0, 0, room.width.toDouble(), room.height.toDouble()),
          Rect.fromLTWH(0, 0, room.width.toDouble(), room.height.toDouble()),
          SpriteCatalog.pixelPaint());
      return;
    }
    const rows = HomeInteriorRules.rows;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        _rect(c, x * _ts, y * _ts, _ts, _ts,
            rows[y][x] == '#' ? _wall : _plank);
      }
    }
    for (final (bx, by) in HomeInteriorRules.bedTiles) {
      _rect(c, bx * _ts + 1, by * _ts + 1, _ts - 2, _ts * 2 - 2, _bed);
      _rect(c, bx * _ts + 3, by * _ts + 2, _ts - 6, 5, _pillow);
    }
    final (dx, dy) = HomeInteriorRules.door;
    _rect(c, dx * _ts, dy * _ts, _ts * 2, _ts, _door);
  }
}
