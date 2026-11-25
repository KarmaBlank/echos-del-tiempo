import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/cozy_catalog.dart';
import '../../../../game_engine/models/life_skills.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/cozy_rules.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import 'map_themes.dart';

/// Cozy life art on the map (docs/specs/cozy_life.md): fireflies at
/// night by the water, raft decorations and farm decorations. Sprites
/// come from the manifest (`items.vida_<id>`) through [icon].
class CozyLayer {
  CozyLayer(this.icon);

  /// Life icon by id (`GameSprites.lifeIcon`), `null` while loading.
  final ui.Image? Function(String id) icon;

  static const ts = 16.0;

  /// Up to `cozyFireflies` fireflies drifting around ([cx], [cy]) px; [t]
  /// in ms. Deterministic per index: no state.
  void drawFireflies(Canvas c, double cx, double cy, num t, {int? count}) {
    final n = count ?? CozyRules.fireflies;
    if (n <= 0) return;
    final sec = t / 1000;
    final dot = Paint()..color = CozyPalette.firefly;
    final glow = Paint()..color = CozyPalette.fireflyGlow;
    for (var i = 0; i < n; i++) {
      final ph = i * 1.7;
      final x = cx +
          math.sin(sec * 0.31 + ph) * (28 + (i % 4) * 9) +
          math.sin(sec * 0.9 + ph * 2) * 4;
      final y = cy -
          6 +
          math.cos(sec * 0.27 + ph * 1.3) * (16 + (i % 3) * 7) +
          math.sin(sec * 1.3 + ph) * 3;
      // Slow blink: some are dark at any time.
      final on = math.sin(sec * 1.1 + ph * 3);
      if (on < -0.2) continue;
      final px = x.roundToDouble(), py = y.roundToDouble();
      c.drawRect(Rect.fromLTWH(px - 1, py - 1, 3, 3), glow);
      c.drawRect(Rect.fromLTWH(px, py, 1, 1), dot);
    }
  }

  /// The raft deck [raft] (32 x 16, two tiles wide) centred on (x, y),
  /// tinted with the wood colour or the paint of [life]. The sprite is
  /// drawn in light neutral shades and tinted with `modulate`, so a
  /// painted raft keeps the paint's hue (blue stays blue). Without an
  /// awning the lantern sits at the deck's corner.
  void drawRaft(Canvas c, ui.Image raft, double x, double y, double bob,
      LifeSkills? life) {
    _img(c, raft, Rect.fromLTWH(x - ts, y - ts / 2 + bob, ts * 2, ts),
        _tint(_paint(life) ?? CozyPalette.wood));
    if (life == null || CozyRules.hasRoof(life)) return;
    if (CozyRules.hasLantern(life)) {
      if (icon('raft_lantern') case final im?) {
        _img(c, im, Rect.fromLTWH(x + 6, y - ts + 1 + bob, ts / 2, ts / 2),
            SpriteCatalog.pixelPaint());
      }
    }
  }

  /// The two short posts of the awning, standing on the deck's back
  /// edge. Drawn before the rider (they are behind them).
  void drawRaftPosts(
      Canvas c, double x, double y, double bob, LifeSkills? life) {
    if (life == null || !CozyRules.hasRoof(life)) return;
    if (icon('raft_posts') case final im?) {
      _img(c, im, Rect.fromLTWH(x - ts, y - 23 + bob, ts * 2, 17),
          SpriteCatalog.pixelPaint());
    }
  }

  /// The awning of the raft centred on (x, y): a flat cloth canopy just
  /// above a standing rider's head, on [drawRaftPosts], with the lantern
  /// hanging from the right post. Drawn after the rider.
  void drawRaftRoof(
      Canvas c, double x, double y, double bob, LifeSkills? life) {
    if (life == null || !CozyRules.hasRoof(life)) return;
    if (icon('raft_roof') case final im?) {
      _img(c, im, Rect.fromLTWH(x - ts, y - 28 + bob, ts * 2, 6),
          _tint(_paint(life) ?? CozyPalette.cloth));
    }
    if (CozyRules.hasLantern(life)) {
      if (icon('raft_lantern') case final im?) {
        _img(c, im, Rect.fromLTWH(x + 9, y - 22 + bob, ts / 2, ts / 2),
            SpriteCatalog.pixelPaint());
      }
    }
  }

  /// The crate a rider seated at (px, py) (the hero's anchor) sits on,
  /// with its small contact shadow; [dir] < 0 mirrors it. Drawn before
  /// the hero.
  void drawRaftSeat(Canvas c, double px, double py, int dir) {
    final x = px.roundToDouble(), y = py.roundToDouble();
    final left = dir < 0 ? x - 4 : x - 6;
    c.drawOval(Rect.fromLTWH(left, y + 4, 10, 2),
        Paint()..color = CozyPalette.seatShadow);
    if (icon('raft_seat') case final im?) {
      _img(c, im, Rect.fromLTWH(left, y - 1, 10, 6), SpriteCatalog.pixelPaint());
    }
  }

  static Color? _paint(LifeSkills? life) {
    final i = life == null ? null : CozyRules.paintOf(life);
    return i == null ? null : CozyPalette.paints[i % CozyPalette.paints.length];
  }

  static Paint _tint(Color color) => SpriteCatalog.pixelPaint()
    ..colorFilter = ui.ColorFilter.mode(color, BlendMode.modulate);

  /// Farm decorations of [town] (map origin [ox], [oy] in tiles).
  void drawDecor(Canvas c, TownState town, int ox, int oy) {
    for (final (id, x, y) in town.decor) {
      final d = kFarmDecos[id];
      if (d == null) continue;
      final im = icon(d.sprite);
      if (im == null) continue;
      _img(c, im, Rect.fromLTWH((x + ox) * ts, (y + oy) * ts, ts, ts),
          SpriteCatalog.pixelPaint());
    }
  }

  static void _img(Canvas c, ui.Image im, Rect dst, Paint p) => c.drawImageRect(
      im,
      Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
      dst,
      p);
}
