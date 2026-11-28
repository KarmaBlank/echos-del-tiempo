import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../core/procedural/item_icons.dart' show ItemIconImages;
import '../../../../game_engine/data/home_furniture_catalog.dart';
import '../../../../game_engine/models/home_layout.dart';
import '../../../../game_engine/rules/home_interior_rules.dart';
import '../../../../game_engine/rules/sky_rules.dart';
import '../../../combat/presentation/sprite_catalog.dart';

/// The ghost of EDITAR CASA (player_house.md § 8.3): [id] with its
/// corner on ([x], [y]); green if [ok], red if not.
typedef HomeGhost = ({String id, int x, int y, bool ok});

/// Draws the player house interior (player_house.md § 2 and § 8) under
/// the actors: floor and wall materials (`items.vida_home_<floor|wall>`,
/// 16 x 16 tiles) with the wall paint, the daylight of the windows, every
/// piece of furniture (`items.vida_home_<id>`), the weapons on the racks,
/// the ALIJO tag of the stash chest and the EDITAR CASA ghost. Images
/// come from the sprite manifest via [icon]; without them (tests, a
/// missing file) it falls back to flat 8-bit shapes.
class HomeInteriorLayer {
  HomeInteriorLayer(this.icon);

  /// Life icon by id and category (`GameSprites.lifeIcon`).
  final ui.Image? Function(String id, String category) icon;

  static const _ts = 16.0;
  static const _plank = Color(0xFF8A5A32);
  static const _wall = Color(0xFF5C3A20);
  static const _door = Color(0xFF2E1C10);
  static const _furniture = Color(0xFFB07A44);
  static const _sun = Color(0xFFFFF0C0);

  final Paint _p = Paint();

  void _rect(Canvas c, double x, double y, double w, double h, Color col) =>
      c.drawRect(Rect.fromLTWH(x, y, w, h), _p..color = col);

  void _img(Canvas c, ui.Image im, double x, double y, [Paint? p]) =>
      c.drawImageRect(
          im,
          Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
          Rect.fromLTWH(x, y, im.width.toDouble(), im.height.toDouble()),
          p ?? SpriteCatalog.pixelPaint());

  /// Floor, walls, door, daylight and furniture (under the actors).
  /// [weaponShape]: the icon shape key of a weapon uid on a rack.
  void drawRoom(Canvas c,
      {HomeLayout layout = kDefaultHomeLayout,
      SkyState? sky,
      String? Function(String uid)? weaponShape,
      String? stashLabel,
      HomeGhost? ghost,
      int? selected}) {
    _surfaces(c, layout);
    if (sky != null) _daylight(c, layout, sky);
    final pieces = [...layout.pieces]..sort((a, b) {
        final da = furniture(a.id), db = furniture(b.id);
        // Rugs first, then wall pieces, then the rest by their bottom.
        int rank(FurnitureDef? d) =>
            d == null ? 0 : (d.walkable ? 0 : (d.onWall ? 1 : 2));
        final r = rank(da).compareTo(rank(db));
        if (r != 0) return r;
        return (a.y + (da?.h ?? 1)).compareTo(b.y + (db?.h ?? 1));
      });
    for (final p in pieces) {
      final d = furniture(p.id);
      if (d == null) continue;
      _piece(c, d, p.x, p.y);
      if (d.kind == FurnitureKind.rack && weaponShape != null) {
        _rack(c, p, weaponShape);
      }
      if (d.kind == FurnitureKind.chest && stashLabel != null) {
        _tag(c, stashLabel, (p.x + 0.5) * _ts, (p.y + 1) * _ts - 3);
      }
      if (p.uid == selected) {
        c.drawRect(
            Rect.fromLTWH(p.x * _ts, p.y * _ts, d.w * _ts, d.h * _ts)
                .deflate(0.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0xFFFFFFFF));
      }
    }
    if (ghost != null) _ghost(c, ghost);
  }

  void _surfaces(Canvas c, HomeLayout l) {
    final floor = icon(homeSurface(l.floor)?.sprite ?? '', '');
    final wall = icon(homeSurface(l.wall)?.sprite ?? '', '');
    final paint = kHomePaints[l.paint.clamp(0, kHomePaints.length - 1)];
    const rows = HomeInteriorRules.shell;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final isWall = rows[y][x] == '#';
        final im = isWall ? wall : floor;
        if (im != null) {
          _img(c, im, x * _ts, y * _ts);
        } else {
          _rect(c, x * _ts, y * _ts, _ts, _ts, isWall ? _wall : _plank);
        }
        if (isWall && l.paint != 0) {
          c.drawRect(
              Rect.fromLTWH(x * _ts, y * _ts, _ts, _ts),
              Paint()
                ..color = Color(0xFF000000 | paint)
                ..blendMode = BlendMode.multiply);
        }
      }
    }
    // Shadow at the foot of the back wall and the door gap.
    _rect(c, _ts, _ts, (rows.first.length - 2) * _ts, 3,
        const Color(0x602A1810));
    final (dx, dy) = HomeInteriorRules.door;
    _rect(c, dx * _ts, dy * _ts, _ts * 2, _ts, _door);
  }

  void _daylight(Canvas c, HomeLayout l, SkyState sky) {
    for (final r in HomeInteriorRules.daylight(l, sky)) {
      final rect = Rect.fromLTWH(r.x * _ts, r.y * _ts, r.w * _ts, r.h * _ts);
      c.drawRect(rect,
          Paint()..color = _sun.withValues(alpha: (0.28 * r.a).clamp(0, 1)));
      c.drawRect(rect.deflate(3),
          Paint()..color = _sun.withValues(alpha: (0.18 * r.a).clamp(0, 1)));
    }
  }

  void _piece(Canvas c, FurnitureDef d, int x, int y, [Paint? p]) {
    final im = icon(d.sprite, '');
    if (im != null) {
      // Bottom-left on the footprint: tall pieces grow upward.
      _img(c, im, x * _ts, (y + d.h) * _ts - im.height, p);
      return;
    }
    _rect(c, x * _ts + 1, y * _ts + 1, d.w * _ts - 2, d.h * _ts - 2,
        _furniture.withValues(alpha: p == null ? 1 : 0.6));
  }

  void _rack(Canvas c, HomePiece p, String? Function(String uid) shape) {
    for (var i = 0; i < p.weapons.length && i < 3; i++) {
      final key = shape(p.weapons[i]);
      final im = key == null ? null : ItemIconImages.base(key);
      if (im == null) continue;
      _img(c, im, p.x * _ts + i * 10.0 - 2, p.y * _ts - 10);
    }
  }

  void _tag(Canvas c, String text, double cx, double y) {
    final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: const TextStyle(
                color: Color(0xFFFFE9A8), fontSize: 5, height: 1)),
        textDirection: TextDirection.ltr)
      ..layout();
    final r = Rect.fromCenter(
        center: Offset(cx, y), width: tp.width + 4, height: tp.height + 2);
    _rect(c, r.left, r.top, r.width, r.height, const Color(0xCC1A1420));
    tp.paint(c, Offset(r.left + 2, r.top + 1));
  }

  void _ghost(Canvas c, HomeGhost g) {
    final d = furniture(g.id);
    if (d == null) return;
    _piece(c, d, g.x, g.y,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6));
    c.drawRect(
        Rect.fromLTWH(g.x * _ts, g.y * _ts, d.w * _ts, d.h * _ts),
        Paint()
          ..color = (g.ok ? const Color(0xFF4CD137) : const Color(0xFFE84118))
              .withValues(alpha: 0.35));
  }
}
