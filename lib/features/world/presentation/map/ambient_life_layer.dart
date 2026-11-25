import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/rules/light_shaft_rules.dart';
import 'map_themes.dart';

/// Ambient critters of a biome region (docs/specs/biome_regions.md § 6):
/// butterflies, sparks, frost motes, embers or echo wisps. Cheap: one
/// candidate per 96 px cell of the view (fixed in the world, so they do
/// not follow the camera), a few rects each, reused paints, no state.
class AmbientLifeLayer {
  static const cell = 96.0;
  static const _wing = Rect.fromLTWH(-2, -1, 2, 2);
  static const _wing2 = Rect.fromLTWH(0, -1, 2, 2);
  static const _dot = Rect.fromLTWH(0, 0, 1, 1);
  static const _body = Rect.fromLTWH(-0.5, -1, 1, 2);

  final List<Paint> _paints = [
    for (final c in RegionPalette.critters) Paint()..color = c
  ];
  final List<Paint> _faint = [
    for (final c in RegionPalette.critters)
      Paint()..color = c.withValues(alpha: 0.45)
  ];

  /// Critters drawn last frame (perf test).
  int last = 0;

  /// Draws the critters of [kind] in [view] at time [t] (s). [density]
  /// is the particle setting (0 = none); [night] dims day critters.
  void draw(Canvas c, Rect view, double t, CritterKind kind,
      {double density = 1, bool night = false}) {
    last = 0;
    if (density <= 0) return;
    final every = density >= 1 ? 3 : 5;
    final paint = _paints[kind.index], faint = _faint[kind.index];
    final cx0 = (view.left / cell).floor(), cy0 = (view.top / cell).floor();
    final cx1 = (view.right / cell).ceil(), cy1 = (view.bottom / cell).ceil();
    for (var cy = cy0; cy < cy1; cy++) {
      for (var cx = cx0; cx < cx1; cx++) {
        final h = LightShaftRules.hash(cx + 911, cy + 577);
        if (h % every != 0) continue;
        final bx = cx * cell + (h >> 3) % cell;
        final by = cy * cell + (h >> 10) % cell;
        final ph = (h >> 17) % 628 / 100;
        double x, y;
        switch (kind) {
          case CritterKind.butterfly:
            if (night) continue;
            x = bx + math.sin(t * 0.7 + ph) * 18;
            y = by + math.sin(t * 1.3 + ph * 2) * 8;
            c.save();
            c.translate(x, y);
            final flap = (t * 8 + ph).floor().isEven;
            c.drawRect(flap ? _wing : _dot, paint);
            c.drawRect(flap ? _wing2 : _dot, paint);
            c.restore();
          case CritterKind.sparkMote ||
                CritterKind.frostMote ||
                CritterKind.ember:
            // Rising specks that loop over 6 s.
            final f = (t / 6 + ph / 6.28) % 1.0;
            x = bx + math.sin(t * 1.1 + ph) * 6;
            y = by + 20 - f * 40;
            c.save();
            c.translate(x, y);
            c.drawRect(_dot, f < 0.7 ? paint : faint);
            if (kind == CritterKind.ember) c.drawRect(_body, faint);
            c.restore();
          case CritterKind.echoWisp:
            x = bx + math.cos(t * 0.5 + ph) * 14;
            y = by + math.sin(t * 0.5 + ph) * 7;
            c.save();
            c.translate(x, y);
            c.drawRect(_wing, faint);
            c.drawRect(_dot, paint);
            c.restore();
        }
        last++;
      }
    }
  }
}
