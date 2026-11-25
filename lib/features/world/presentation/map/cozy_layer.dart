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

  /// The raft sprite [raft] at (x, y) (centre) with the decorations of
  /// [life]: paint tint, roof above and lantern at the corner.
  void drawRaft(Canvas c, ui.Image raft, double x, double y, double bob,
      LifeSkills? life) {
    final paint = life == null ? null : CozyRules.paintOf(life);
    final p = SpriteCatalog.pixelPaint();
    if (paint != null) {
      p.colorFilter = ui.ColorFilter.mode(
          CozyPalette.paints[paint % CozyPalette.paints.length],
          BlendMode.modulate);
    }
    _img(c, raft, Rect.fromLTWH(x - ts / 2, y - ts / 2 + bob, ts, ts), p);
    // With a roof the lantern hangs from its post ([drawRaftRoof]).
    if (life == null || CozyRules.hasRoof(life)) return;
    if (CozyRules.hasLantern(life)) {
      if (icon('raft_lantern') case final im?) {
        _img(c, im, Rect.fromLTWH(x + 2, y - ts + 2 + bob, ts / 2, ts / 2),
            SpriteCatalog.pixelPaint());
      }
    }
  }

  /// The roof of the raft centred on (x, y), drawn after the rider so
  /// they sit under it. The sprite is 16 x 32: the slab on top and two
  /// posts that stand on the deck's front corners, so roof and deck read
  /// as one object; the lantern hangs from the right post.
  void drawRaftRoof(
      Canvas c, double x, double y, double bob, LifeSkills? life) {
    if (life == null || !CozyRules.hasRoof(life)) return;
    if (icon('raft_roof') case final im?) {
      _img(c, im, Rect.fromLTWH(x - ts / 2, y + 5 - ts * 2 + bob, ts, ts * 2),
          SpriteCatalog.pixelPaint());
    }
    if (CozyRules.hasLantern(life)) {
      if (icon('raft_lantern') case final im?) {
        _img(c, im, Rect.fromLTWH(x + 3, y - 18 + bob, ts / 2, ts / 2),
            SpriteCatalog.pixelPaint());
      }
    }
  }

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
